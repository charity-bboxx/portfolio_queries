--Get 6 month collection rate
--Remove downpayments fron new sales
--Check weird scenerios;
     --Customer start_date earlier than downpayment date
	 --Daily rate is 0 or null
	 --Inactive customers showing as active
     --Expected cash is 0 
--CTE to get downpayments
with downpayments as 
	(
	select 
		customer_id,
		unique_account_id,
		sum(total_downpayment) as total_downpayment
	from kenya.rp_retail_sales 
	where 
		downpayment_date::date >= CURRENT_DATE - INTERVAL '6 MONTH'
        group by 1,2
        
	),
	
	--CTE to get customer repayments

payments as 
	(
	select
		payments.payg_account_id,
	    SUM(amount) - coalesce(downpayments.total_downpayment,0) AS repayments, 
		downpayments.total_downpayment 
	from src_odoo13_kenya.account_payment AS payments
		left join downpayments as downpayments 
			on downpayments.unique_account_id = payments.payg_account_id 
		left join kenya.customer as customer 
			on customer.unique_account_id = payments.payg_account_id 
	WHERE
		payments.state = 'posted'
		AND payments.transaction_date >= CURRENT_DATE - INTERVAL '6 MONTH'
		--and customer.unique_account_id = 'BXCK67854266'
	GROUP BY
		payments.payg_account_id,
		downpayments.total_downpayment  
	),

sales_details AS (
SELECT
	DISTINCT 
    sales.unique_account_id,
	sales.sales_person,
	agent.username,
	agent.sales_agent_name,
	agent.sales_agent_mobile
FROM
	kenya.rp_retail_sales as sales
	left join 
	kenya.sales_agent as agent on   
	agent.sales_agent_id = sales.sign_up_sales_agent_id
    where sales.sale_type = 'install'
    and sales.sales_order_id = sales.unique_account_id	
    --and sales.unique_account_id= 'BXCK00000131'

      ),

active as 
	(
	select 
		today.date_timestamp::date as activity_date,
		today.customer_id,
		details.customer_name,
		details.customer_phone_1,
        details.customer_phone_2,
		details.home_address_4 AS locations,
        details.home_address_3 AS constituency,
		customer.location_customer_met_latitude,
		customer.location_customer_met_longitude,
		customer.location_customer_met_accuracy,
		customer.unique_account_id,
		today.consecutive_late_days,
		today.daily_rate,
	    sales_details.sales_agent_name,
		sales_details.sales_person,
		sales_details.sales_agent_mobile,
		customer.customer_active_end_date,
		customer.customer_active_start_date::text::date as installation_date,
		LEAST(((CURRENT_DATE - (customer.customer_active_start_date::DATE + 7))::BIGINT), 180) AS days_expected
	from kenya.agg_dcs_today as today 
	left join kenya.customer as customer   
		on customer.account_id = today.account_id
		left join  sales_details as sales_details on 
		sales_details.unique_account_id = customer.unique_account_id
		 left join kenya.customer_personal_details as details on 
	     details.account_id = customer.account_id
	where customer.customer_final_status is null
	),
	--CTE 
	
	
collection_rate as 
	(
	select
		active.activity_date,
		active.customer_id,
		active.customer_name,
		active.customer_phone_1,
		active.customer_phone_2,
		active.locations,
		active.constituency,
		active.unique_account_id,
		active.location_customer_met_latitude,
		active.location_customer_met_longitude,
		active.location_customer_met_accuracy,
		active.daily_rate,
		active.customer_active_end_date,
		active.sales_person,
		active.sales_agent_mobile,
		active.sales_agent_name,
		look.shop,
		look.region,
		active.installation_date,
		active.consecutive_late_days,
		active.days_expected,
		coalesce(repayments.repayments,0) as six_month_repayments,
		repayments.repayments/ nullif((active.days_expected* active.daily_rate),0) as six_month_collection_rate,
		row_number() over 
		(
		partition by active.unique_account_id
		) as row_numbers
	from active as active
		left join payments as repayments  
			on repayments.payg_account_id = active.unique_account_id
		left join kenya.rp_portfolio_customer_lookup as look  
			on look.customer_id = active.customer_id 
	--limit 5
	),

last_30_downpayments as 
	(
	select 
		customer_id,
		unique_account_id,
		sum(total_downpayment) as total_downpayment
	from kenya.rp_retail_sales 
	where 
		downpayment_date::date between current_date -7  and CURRENT_DATE - 1
        group by 1,2
	),

last_7_day_CR AS 
(
	SELECT 
		payments.payg_account_id,
		sum(amount) - (coalesce(last_30_downpayments.total_downpayment,0)) AS payments
	FROM src_odoo13_kenya.account_payment AS payments 
	left join last_30_downpayments as last_30_downpayments on 
	last_30_downpayments.unique_account_id = payments.payg_account_id
	WHERE 
		payments.state = 'posted'
        and payments.transaction_reference not like '%BONUS%'
		AND payments.transaction_date::TEXT::DATE between  current_date -7  and  CURRENT_DATE -1
	GROUP BY 
		payments.payg_account_id,
		last_30_downpayments.total_downpayment 
	),
	
dataset as 
	(
	select
	    collection_rate.activity_date as last_refresh_date,
	    current_date - 7 ||' to '||  current_date - 1 as period_,
		collection_rate.region, 
		collection_rate.shop,
		collection_rate.unique_account_id,
		collection_rate.customer_name,
		collection_rate.customer_phone_1,
		collection_rate.customer_phone_2,
		collection_rate.locations as ward,
		collection_rate.location_customer_met_latitude,
		collection_rate.location_customer_met_longitude,
		case when 
		 collection_rate.daily_rate in( 15,14.46)
		 then 1 else 0 end as ESF_only_status,
		collection_rate.sales_agent_name,
		upper(substring (collection_rate.sales_person,0,7)) as Agent_id,
		0 as agent_status,
		coalesce(last_7_day_CR.payments,0) / nullif((collection_rate.daily_rate * 7),0) as last_7_day_CR,
		0 as technician_name,
		collection_rate.daily_rate,
		collection_rate.consecutive_late_days,
		collection_rate.sales_agent_mobile::TEXT as sales_agent_mobile,
		coalesce(collection_rate.six_month_collection_rate,0) as six_month_collection_rate, 
		collection_rate.installation_date,
		--collection_rate.six_month_repayments,
		last_7_day_CR.payments as cash_collected,
		collection_rate.days_expected,
		    CASE 
		      WHEN collection_rate.installation_date + 8  > collection_rate.activity_date
		        THEN 'New Customer'
		      ELSE 'Older Customer'
		      end as customer_age_tag
	from collection_rate as collection_rate 
		left join last_7_day_CR as last_7_day_CR  
			on last_7_day_CR.payg_account_id = collection_rate.unique_account_id 
	where collection_rate.row_numbers = 1
	)
	select
		*,
	 7 * daily_rate as total_expected_cash,
	 case 
	 when  
	 dataset.consecutive_late_days >= 0    
	 AND dataset.consecutive_late_days < 30
	 then 1
	 else 0
	  end as PAR_0_29,
	  case 
	 when  
	 dataset.consecutive_late_days >= 30    
	 AND dataset.consecutive_late_days < 59
	 then 1
	 else 0
	  end as PAR_30_59,
	    case 
	 when  
	 dataset.consecutive_late_days >= 60    
	 AND dataset.consecutive_late_days < 120
	 then 1
	 else 0
	  end as PAR_60_119,
  case 
	 when  
	 dataset.consecutive_late_days > 120    
	 then 1
	 else 0
	  end as PAR_120,
		 CASE 
		      WHEN 
		            dataset.consecutive_late_days >= 0    
		            AND dataset.consecutive_late_days < 30
		            AND 
		            (
		            dataset.six_month_collection_rate >= 0.66667
		            or 
                        (
                        dataset.six_month_collection_rate < 0.66667 
                        AND dataset.last_7_day_CR >= 0.6667
                        )
		            )
		            AND dataset.customer_age_tag = 'Older Customer'
		      THEN 'Good Payer'  
		      WHEN 
		            (dataset.six_month_collection_rate < 0.66667
		            and dataset.consecutive_late_days < 30
		            and dataset.last_7_day_CR < 0.6667
					and dataset.customer_age_tag = 'Older Customer'
		            )
		            or 
		            (
		            dataset.six_month_collection_rate < 0.66667
		            and dataset.consecutive_late_days < 30
					and dataset.customer_age_tag = 'Older Customer'
		            and dataset.last_7_day_CR is null
		            )
		      then 'Slow Payer_Locked Rewards'
		      when 
		            dataset.consecutive_late_days >= 30
		            AND dataset.consecutive_late_days < 60
		            AND dataset.customer_age_tag = 'Older Customer' 
		      THEN 'Late_30-59'
		      WHEN 
		            dataset.consecutive_late_days >= 60
		            AND dataset.consecutive_late_days < 120
		            AND dataset.customer_age_tag = 'Older Customer'
		      THEN 'Defaulted_60-119'  
		      WHEN 
		            dataset.consecutive_late_days >= 120
		            AND dataset.customer_age_tag = 'Older Customer'
		      THEN 'Legacy Customer'
		      WHEN 
		            dataset.customer_age_tag = 'New Customer' 
		      THEN  'New Customers'      
		      ELSE 'Unaccounted for bucket'
		    END AS CustomerSegment,
			case 
	   when dataset.consecutive_late_days between 0 and 119
	    and dataset.customer_age_tag = 'Older Customer' 
		then 1
		else 0 
		end as eligible
	from dataset as dataset