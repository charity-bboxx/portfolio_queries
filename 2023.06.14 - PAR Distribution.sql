with accounts as (
	select 
	rrs.account_id, 
	rrs.unique_account_id, 
	rrs.current_system,
	SUM(rrs.downpayment) as DP, 
	SUM(rrs.credit_price) as DailyRate
from kenya.rp_retail_sales rrs 
where 
	rrs.current_hardware_type <> 'not yet installed'
	and rrs.install_date >= '20220901'
	--and rrs.account_id = '053240fd9d096a6e05be3db49401ab03'
group by 
	rrs.account_id, 
	rrs.unique_account_id,  
	rrs.current_system
	),

accounts_category as (
	select 
		accounts.*, 
		case 
			when 
				accounts.current_system = 'nuovopay'
			then 'Connect'
			when 
				accounts.current_system = 'offline_token'
			then 'Flexx'
			else 'bPower'
		end as ProductCategory
	from accounts 
	) 
	
select 
	LAST_DAY(dcs.date_timestamp::DATE) as ActivityMonth,
	ac.ProductCategory,
	case 
		when 
			dcs.consecutive_late_days <= 0 
		then 'PAR_0'
		when 
			dcs.consecutive_late_days <= 30
		then 'PAR_0 - 30'
		when 
			dcs.consecutive_late_days <= 60 
		then 'PAR_30 - 60'
		when 
			dcs.consecutive_late_days <= 120 
		then 'PAR_60 - 120'
		when
			dcs.consecutive_late_days > 120
		then 'PAR_120+'
	end as PAR_Category,
	COUNT(dcs.account_id) as NumberOfAccounts
from accounts_category ac 
	left join kenya.daily_customer_snapshot dcs 
		on ac.account_id = dcs.account_id 
	left join kenya.customer c 
		on ac.account_id = c.account_id 
where 
	dcs.date_timestamp::DATE >= '20230101'
	and (dcs.date_timestamp::DATE = LAST_DAY(dcs.date_timestamp::DATE)
		or dcs.date_timestamp::DATE = CURRENT_DATE)
group by 
	ActivityMonth,
	ac.ProductCategory,
	PAR_Category