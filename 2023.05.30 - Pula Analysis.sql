with customer_info as (	
	select 
		customer_id, 
		unique_customer_id,
		customer_active_start_date::DATE as InstallationDate,
		region, 
		shop, 
		territory, 
		current_hardware_type,
		esf_customer,
		current_client_status, 
		current_payment_status, 
		customer_active_end_date::DATE as CustomerEndDate
	from rp_portfolio_customer_lookup rpcl 
	where 
		country = 'Kenya'
		)
	,
	
pre_insurance as (
	select 
		customer_id, 
		COUNT(distinct daily_customer_snapshot_id) as DaysActive,
		SUM(
			case 
				when 
					consecutive_late_days = 0 
					and enable_status not in ('pending_enabled', 'pending_disabled')
				then 1 
				else 0
			end) as DaysSwitchedOn
	from daily_customer_snapshot dcs
	where 
		date_timestamp::DATE <= '20220930'
		and date_timestamp::DATE >= '20220701'
	group by 
		customer_id 
		)
	, 

mid_insurance as (
	select 
		customer_id, 
		COUNT(distinct daily_customer_snapshot_id) as DaysActive,
		SUM(
			case 
				when 
					consecutive_late_days = 0 
					and enable_status not in ('pending_enabled', 'pending_disabled')
				then 1 
				else 0
			end) as DaysSwitchedOn
	from daily_customer_snapshot dcs
	where 
		date_timestamp::DATE <= '20221230'
		and date_timestamp::DATE >= '20221001'
	group by 
		customer_id 
		)
	, 
	
post_insurance as (
	select 
		customer_id, 
		COUNT(distinct daily_customer_snapshot_id) as DaysActive,
		SUM(
			case 
				when 
					consecutive_late_days = 0 
					and enable_status not in ('pending_enabled', 'pending_disabled')
				then 1 
				else 0
			end) as DaysSwitchedOn
	from daily_customer_snapshot dcs
	where 
		date_timestamp::DATE <= '20230302'
		and date_timestamp::DATE >= '20230101'
	group by 
		customer_id 
		)
		
select 
	customer_info.*, 
	pre_insurance.DaysActive as DaysActive_Pre,
	pre_insurance.DaysSwitchedOn as DaysOn_Pre,
	mid_insurance.DaysActive as DaysActive_Mid,
	mid_insurance.DaysSwitchedOn as DaysOn_Mid,
	post_insurance.DaysActive as DaysActive_Post,
	post_insurance.DaysSwitchedOn as DaysOn_Post
from customer_info 
	left join pre_insurance 
		on customer_info.customer_id = pre_insurance.customer_id 
	left join mid_insurance 
		on customer_info.customer_id = mid_insurance.customer_id
	left join post_insurance 
		on customer_info.customer_id = post_insurance.customer_id 