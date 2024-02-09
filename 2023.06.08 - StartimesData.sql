with startimes_clients as (
	select 
		rrs.account_id,
		rrs.unique_account_id, 
		rrs.downpayment_date, 
		rrs.install_date,
		cpd.customer_name, 
		cpd.customer_phone_1, 
		cpd.customer_phone_2,
		cpd.customer_national_id_number, 
		cpd.home_address_1, 
		rrs.product_name,
		rrs.sale_type,
		rrs.downpayment,
		rrs.credit_price as DailyRate
	from kenya.rp_retail_sales rrs 
		left join kenya.customer_personal_details cpd
			on rrs.account_id = cpd.account_id 
	where 
		rrs.product_name like '%Star%' 
	), 
	
total_paid_april as (
	select 
		p.payg_account_id as AccountID, 
		SUM(p.amount) as TotalPaid
	from src_odoo13_kenya.account_payment as p
	where 
		p.state = 'posted'
		and p.transaction_date::DATE >= '20230401' --<--- enter the specific date here
		and p.transaction_date::DATE <= '20230430'
	group by 
		p.payg_account_id
		)
	, 
	
days_on_april as (
	select 
		account_id, 
		SUM(
		case 
			when 
				consecutive_late_days = 0 
			then 1 
			else 0 
		end ) as DaysInNormalConsecDays, 
		COUNT(distinct daily_customer_snapshot_id) as DaysActive
	from kenya.daily_customer_snapshot dcs
	where 
		dcs.date_timestamp::DATE >= '20230401' --<--- enter the specific date here
		and dcs.date_timestamp::DATE <= '20230430' 
	group by 
		dcs.account_id 
		)
	, 
	
total_paid_may as (
	select 
		p.payg_account_id as AccountID, 
		SUM(p.amount) as TotalPaid
	from src_odoo13_kenya.account_payment as p
	where 
		p.state = 'posted'
		and p.transaction_date::DATE >= '20230501' --<--- enter the specific date here
		and p.transaction_date::DATE <= '20230531'
	group by 
		p.payg_account_id
		)
	, 
	
days_on_may as (
	select 
		account_id, 
		SUM(
		case 
			when 
				consecutive_late_days = 0 
			then 1 
			else 0 
		end ) as DaysInNormalConsecDays, 
		COUNT(distinct daily_customer_snapshot_id) as DaysActive
	from kenya.daily_customer_snapshot dcs
	where 
		dcs.date_timestamp::DATE >= '20230501' --<--- enter the specific date here
		and dcs.date_timestamp::DATE <= '20230531' 
	group by 
		dcs.account_id 
		)
		
select 
	startimes_clients.*, 
	total_paid_april.TotalPaid as TotalPaidInApril, 
	days_on_april.DaysActive as DaysActiveApril,
	days_on_april.DaysInNormalConsecDays as DaysOnApril,
	total_paid_may.TotalPaid as TotalPaidInMay, 
	days_on_may.DaysActive as DaysActiveMay,
	days_on_may.DaysInNormalConsecDays as DaysOnMay
from startimes_clients
	left join total_paid_april
		on startimes_clients.unique_account_id = total_paid_april.AccountID
	left join days_on_april 
		on startimes_clients.account_id = days_on_april.account_id
	left join total_paid_may
		on startimes_clients.unique_account_id = total_paid_may.AccountID
	left join days_on_may 
		on startimes_clients.account_id = days_on_may.account_id