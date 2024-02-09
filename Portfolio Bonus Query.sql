--select * from kenya.agg_dcs_today limit 5 
with downpayments as (
	select customer_id,
		unique_account_id,
		sum(total_downpayment) as total_downpayment
	from kenya.rp_retail_sales
	where downpayment_date::date >= CURRENT_DATE - INTERVAL '6 MONTH'
	group by 1,
		2
),
payments as (
	select payments.payg_account_id,
		SUM(amount) - coalesce(downpayments.total_downpayment, 0) AS repayments,
		downpayments.total_downpayment
	from src_odoo13_kenya.account_payment AS payments
		left join downpayments as downpayments on downpayments.unique_account_id = payments.payg_account_id
		left join kenya.customer as customer on customer.unique_account_id = payments.payg_account_id
	WHERE payments.state = 'posted'
		AND payments.transaction_date >= CURRENT_DATE - INTERVAL '6 MONTH' --and customer.unique_account_id = 'BXCK67854266'
	GROUP BY payments.payg_account_id,
		downpayments.total_downpayment
),
sales_details AS (
	SELECT DISTINCT sales.unique_account_id,
		sales.sales_person,
		agent.username,
		agent.sales_agent_name,
		agent.sales_agent_mobile
	FROM kenya.rp_retail_sales as sales
		left join kenya.sales_agent as agent on upper(agent.sales_agent_bboxx_id) = upper(substring (sales.sales_person, 0, 7))
	where sales.sale_type = 'install'
		and sales.sales_order_id = sales.unique_account_id
),
last_phon as (
	select p.payg_account_id,
		max(p.transaction_date::date) as date_
	from src_odoo13_kenya.account_payment p
	group by 1
),
last_phone as (
	select p.payg_account_id,
		l.date_,
		LISTAGG(distinct(p.payer_identifier), ',') AS payer_identifier
	from last_phon l
		left join src_odoo13_kenya.account_payment p on l.payg_account_id = p.payg_account_id
	where l.date_ = p.transaction_date::date
	group by 1,
		2
),
active as (
	select today.date_timestamp::date as activity_date,
		today.account_id,
		details.customer_name,
		details.customer_phone_1,
		details.customer_phone_2,
		last_phone.payer_identifier as last_payment_phone,
		details.customer_home_address as nearest_landmark,
		details.home_address_4 AS locations,
		details.home_address_3 AS constituency,
		customer.unique_account_id,
		today.consecutive_late_days,
		today.expiry_timestamp::date as expiry_date,
		today.daily_rate,
		sales_details.sales_agent_name,
		sales_details.sales_person,
		sales_details.sales_agent_mobile,
		customer.customer_active_end_date,
		customer.customer_active_start_date::text::date as installation_date,
		LEAST(
			(
				(
					CURRENT_DATE - (customer.customer_active_start_date::DATE + 7)
				)::BIGINT
			),
			180
		) AS days_expected
	from kenya.agg_dcs_today as today
		left join kenya.customer as customer on customer.account_id = today.account_id
		left join sales_details as sales_details on sales_details.unique_account_id = customer.unique_account_id
		left join kenya.customer_personal_details as details on details.account_id = customer.account_id
		left join last_phone as last_phone on last_phone.payg_account_id = customer.unique_account_id
	where customer.customer_final_status is null --and today.date_timestamp::date = current_date
		and upper(details.customer_name) not like '%OPTED%'
),
collection_rate as (
	select active.activity_date,
		active.account_id,
		active.customer_name,
		active.customer_phone_1,
		active.customer_phone_2,
		active.last_payment_phone,
		active.nearest_landmark,
		active.locations,
		active.constituency,
		active.unique_account_id,
		active.daily_rate,
		active.customer_active_end_date,
		active.sales_person,
		active.sales_agent_mobile,
		active.sales_agent_name,
		look.current_hardware_type,
		look.shop,
		look.region,
		active.installation_date,
		active.consecutive_late_days,
		active.days_expected,
		active.expiry_date,
		look.tv_customer,
		coalesce(repayments.repayments, 0) as six_month_repayments,
		repayments.repayments / nullif((active.days_expected * active.daily_rate), 0) as six_month_collection_rate,
		row_number() over (partition by active.unique_account_id) as row_numbers
	from active as active
		left join payments as repayments on repayments.payg_account_id = active.unique_account_id
		left join kenya.rp_portfolio_customer_lookup as look on look.account_id = active.account_id
),
last_30_downpayments as (
	select customer_id,
		unique_account_id,
		sum(total_downpayment) as total_downpayment
	from kenya.rp_retail_sales
	where downpayment_date::date >= CURRENT_DATE - INTERVAL '1 MONTH'
	group by 1,
		2
),
last_30_day_CR AS (
	SELECT payments.payg_account_id,
		sum(amount) - (
			coalesce(last_30_downpayments.total_downpayment, 0)
		) AS payments
	FROM src_odoo13_kenya.account_payment AS payments
		left join last_30_downpayments as last_30_downpayments on last_30_downpayments.unique_account_id = payments.payg_account_id
	WHERE payments.state = 'posted'
		AND payments.transaction_date::TEXT::DATE BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE
	GROUP BY payments.payg_account_id,
		last_30_downpayments.total_downpayment
),
dataset as (
	select collection_rate.account_id,
		collection_rate.unique_account_id,
		collection_rate.customer_name,
		collection_rate.customer_phone_1,
		collection_rate.customer_phone_2,
		collection_rate.last_payment_phone,
		collection_rate.nearest_landmark,
		collection_rate.locations,
		collection_rate.constituency,
		collection_rate.daily_rate,
		collection_rate.current_hardware_type,
		collection_rate.shop,
		collection_rate.region,
		collection_rate.sales_agent_name,
		collection_rate.sales_person,
		collection_rate.sales_agent_mobile::TEXT as sales_agent_mobile,
		upper(substring (collection_rate.sales_person, 0, 7)) as Agent_id,
		coalesce(collection_rate.six_month_collection_rate, 0) as six_month_collection_rate,
		collection_rate.customer_active_end_date,
		collection_rate.installation_date,
		collection_rate.six_month_repayments,
		last_30_day_CR.payments as last_30_day_repayments,
		collection_rate.days_expected,
		coalesce(last_30_day_CR.payments, 0) / nullif((collection_rate.daily_rate * 30), 0) as last_30_day_CR,
		collection_rate.consecutive_late_days,
		collection_rate.expiry_date,
		collection_rate.tv_customer,
		CASE
			WHEN collection_rate.installation_date + 8 > collection_rate.activity_date THEN 'New Customer'
			ELSE 'Older Customer'
		end as customer_age_tag
	from collection_rate as collection_rate
		left join last_30_day_CR as last_30_day_CR on last_30_day_CR.payg_account_id = collection_rate.unique_account_id
),
completedata as (
	select *,
		CASE
			WHEN dataset.consecutive_late_days >= 0
			AND dataset.consecutive_late_days < 30
			AND (
				dataset.six_month_collection_rate >= 0.66667
				or (
					dataset.six_month_collection_rate < 0.66667
					AND dataset.last_30_day_CR >= 0.6667
				)
			)
			AND dataset.customer_age_tag = 'Older Customer' THEN 'Good Payer'
			WHEN (
				dataset.six_month_collection_rate < 0.66667
				and dataset.consecutive_late_days < 30
				and dataset.last_30_day_CR < 0.6667
				and dataset.customer_age_tag = 'Older Customer'
			)
			or (
				dataset.six_month_collection_rate < 0.66667
				and dataset.consecutive_late_days < 30
				and dataset.customer_age_tag = 'Older Customer'
				and dataset.last_30_day_CR is null
			) then 'Slow Payer_Locked Rewards'
			when dataset.consecutive_late_days >= 30
			AND dataset.consecutive_late_days < 60
			AND dataset.customer_age_tag = 'Older Customer' THEN 'Late_30-59'
			WHEN dataset.consecutive_late_days >= 60
			AND dataset.consecutive_late_days < 120
			AND dataset.customer_age_tag = 'Older Customer' THEN 'Defaulted_60-119'
			WHEN dataset.consecutive_late_days >= 120
			AND dataset.customer_age_tag = 'Older Customer' THEN 'Legacy Customer'
			WHEN dataset.customer_age_tag = 'New Customer' THEN 'New Customers'
			ELSE 'Unaccounted for bucket'
		END AS CustomerSegment
	from dataset as dataset
),
data_with_bonuses AS (
	SELECT *,
		CASE
			WHEN CustomerSegment = 'Good Payer' THEN 1.0 * daily_rate
			ELSE 0
		END AS GoodPayerReward,
		CASE
			WHEN CustomerSegment = 'Slow Payer_Locked Rewards' THEN 1.0 * daily_rate
			ELSE 0
		END AS SlowPayerLockedRewards,
		CASE
			WHEN CustomerSegment = 'Late_30-59' THEN -7 * daily_rate
			ELSE 0
		END AS LatePenalty,
		CASE
			WHEN CustomerSegment = 'Defaulted_60-119' THEN -14 * daily_rate
			ELSE 0
		END AS DefaulterPenalty
	FROM completedata
),
customer_categories as (
	SELECT *,
		LatePenalty + DefaulterPenalty AS total_penalty,
		GoodPayerReward + LatePenalty + DefaulterPenalty AS actual_bonus,
		CASE
			WHEN GoodPayerReward > 0 THEN 1
			ELSE 0
		END AS GoodPayerStatus,
		CASE
			WHEN SlowPayerLockedRewards > 0 THEN 1
			ELSE 0
		END AS SlowPayerStatus,
		CASE
			WHEN LatePenalty < 0 THEN 1
			ELSE 0
		END AS LateStatus,
		CASE
			WHEN DefaulterPenalty < 0 then 1
			else 0
		END AS DefaulterStatus
	FROM data_with_bonuses
),
eligible_status as (
	select customer_categories.*,
		case
			when GoodPayerStatus = 1 then 1
			when SlowPayerStatus = 1 then 1
			when LateStatus = 1 then 1
			when DefaulterStatus = 1 then 1
			else 0
		end as EligibleStatus
	from customer_categories
)
select eligible_status.*,
	case
		when EligibleStatus = 1 then 1.0 * daily_rate
		else 0
	end as MaxBonusAmount,
	case
		when consecutive_late_days > 8
		and consecutive_late_days < 30 then 1
		else 0
	end as PrePenaltyStatus,
	case
		when consecutive_late_days > 8
		and consecutive_late_days < 30 then -7 * daily_rate
		else 0
	end as PrePenaltyPotentialPenalty
from eligible_status --limit 5