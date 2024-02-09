--Get 6 month collection rate
--Remove downpayments fron new sales

with downpayments as 
	(
	select 
		customer_id,
		unique_account_id,
		downpayment_date::date,
		total_downpayment
	from kenya.rp_retail_sales 
	where 
		downpayment_date::date >= CURRENT_DATE - INTERVAL '6 MONTH'
	),
	
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
		--and customer.unique_account_id = 'BXCK00010444'
	GROUP BY
		payments.payg_account_id,
		downpayments.total_downpayment  
	),

active as 
	(
	select 
		today.date_timestamp::date as activity_date,
		today.customer_id,
		customer.unique_account_id,
		today.consecutive_late_days,
		today.daily_rate,
		customer.customer_active_end_date,
		customer.customer_active_start_date::text::date as installation_date,
		LEAST(((CURRENT_DATE - (customer.customer_active_start_date::DATE + 7))::BIGINT), 180) AS days_expected
	from kenya.agg_dcs_today as today 
	left join kenya.customer as customer   
		on customer.customer_id = today.customer_id 
	),
	
collection_rate as 
	(
	select
		active.activity_date,
		active.customer_id,
		active.unique_account_id,
		active.daily_rate,
		active.customer_active_end_date,
		look.shop,
		look.region,
		active.installation_date,
		active.consecutive_late_days,
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
-----------------old query------------
last_30_day_CR AS 
(
	SELECT 
		payments.payg_account_id,
		sum(amount) AS payments
	FROM src_odoo13_kenya.account_payment AS payments 
	WHERE 
		payments.state = 'posted'
		AND payments.transaction_date::TEXT::DATE BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE
	GROUP BY 
		payments.payg_account_id  
	),
	
dataset as 
	(
	select
		collection_rate.customer_id,
		collection_rate.unique_account_id,
		collection_rate.daily_rate,
		collection_rate.shop,
		collection_rate.region, 
		collection_rate.six_month_collection_rate,
		collection_rate.customer_active_end_date,
		last_30_day_CR.payments / nullif((collection_rate.daily_rate * 30),0) as last_30_day_CR,
		collection_rate.consecutive_late_days, 
		    CASE 
		      WHEN collection_rate .installation_date + 30  > collection_rate.activity_date
		        THEN 'New Customer'
		      ELSE 'Older Customer'
		      end as customer_age_tag
	from collection_rate as collection_rate 
		left join last_30_day_CR as last_30_day_CR  
			on last_30_day_CR.payg_account_id = collection_rate.unique_account_id 
	where collection_rate.row_numbers = 1
	),
completedata as 
	(
	select
		*,
		 CASE 
		      WHEN 
		            dataset.consecutive_late_days >= 0    
		            AND dataset.consecutive_late_days < 30
		            AND 
		            (
		            dataset.six_month_collection_rate >= 0.66667
		            or (dataset.six_month_collection_rate < 0.66667 AND dataset.last_30_day_CR >= 0.6667)
		            )
		            AND dataset.customer_age_tag = 'Older Customer'
		      THEN 'Good Payer'  
		      WHEN 
		            (dataset.six_month_collection_rate < 0.66667
		            and dataset.consecutive_late_days < 30
		            and dataset.last_30_day_CR < 0.6667
		            )
		            or 
		            (
		            dataset.six_month_collection_rate < 0.66667
		            and dataset.consecutive_late_days < 30
		            and dataset.last_30_day_CR is null
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
		    END AS CustomerSegment
	from dataset as dataset
	),

data_with_bonuses AS (
  SELECT 
    *,
    CASE 
        WHEN 
            CustomerSegment = 'Good Payer'
        THEN 1.0 * daily_rate
        ELSE 0 
    END AS GoodPayerReward,
    CASE 
        WHEN 
            CustomerSegment = 'Slow Payer_Locked Rewards'
        THEN 1.0 * daily_rate
        ELSE 0 
    END AS SlowPayerLockedRewards,
    CASE 
        WHEN 
            CustomerSegment = 'Late_30-59'
       THEN -7 * daily_rate
       ELSE 0 
    END AS LatePenalty,
    CASE 
      WHEN 
        CustomerSegment = 'Defaulted_60-119' 
      THEN -14 * daily_rate
      ELSE 0
    END AS DefaulterPenalty
  FROM completedata
 	 ),
  customer_categories as (
    SELECT 
      *,
      LatePenalty + DefaulterPenalty AS total_penalty,
      GoodPayerReward + LatePenalty + DefaulterPenalty AS actual_bonus,
      CASE 
        WHEN 
            GoodPayerReward > 0 
        THEN 1
        ELSE 0 
      END AS GoodPayerStatus,
      CASE 
        WHEN 
            SlowPayerLockedRewards > 0 
          THEN 1
        ELSE 0 
      END AS SlowPayerStatus,
      CASE 
        WHEN 
            LatePenalty < 0 
         THEN 1
        ELSE 0 
      END AS LateStatus,
      CASE 
        WHEN 
            DefaulterPenalty < 0 
        then 1
        else 0
      END AS DefaulterStatus
    FROM data_with_bonuses
    )
    , 
eligible_status as (
    select 
        customer_categories.*,
        case 
            when 
                GoodPayerStatus = 1 
            then 1 
            when 
                SlowPayerStatus = 1
            then 1
            when 
                LateStatus = 1
            then 1
            when 
                DefaulterStatus = 1
            then 1
            else 0 
        end as EligibleStatus
    from customer_categories 
    )
select 
    eligible_status.*,
    case 
        when 
            EligibleStatus = 1
        then 1.0*daily_rate 
        else 0
    end as MaxBonusAmount,
    case 
        when 
            consecutive_late_days >8
            and consecutive_late_days <30
        then 1
        else 0
    end as PrePenaltyStatus,
    case 
        when 
            consecutive_late_days >8
            and consecutive_late_days <30
        then -7*daily_rate
        else 0
    end as PrePenaltyPotentialPenalty 
from eligible_status
 --limit 5 


--------------------------------------------------------------------



