with defaulters_list as (
	select 
		dcs.account_id, 
		rpcl.unique_customer_id, 
		rpcl.customer_active_start_date::DATE as InstallationDate,
		rpcl.region, 
		rpcl.shop,
		rpcl.current_hardware_type, 
		rpcl.daily_rate, 
		dcs.customer_status as CustomerStatusInMay, 
		dcs.payment_status as PaymentStatusinMay, 
		dcs.consecutive_late_days as ConsecDaysinMay, 
		dcs.expiry_timestamp::DATE as ExpiryDateinMay
	from kenya.daily_customer_snapshot dcs 
		left join kenya.rp_portfolio_customer_lookup rpcl 
			on dcs.account_id = rpcl.account_id 
	where 
		dcs.date_timestamp::DATE = '20230531'
		and dcs.payment_status = 'default'
		),
		
total_paid as (
	select 
		p.payg_account_id, 
		SUM(p.amount) as TotalPaid
	from src_odoo13_kenya.account_payment as p
	where 
		p.state = 'posted'
		and p.transaction_date::DATE >= '20230531'
	group by 
		p.payg_account_id
		) 
		
select 
	defaulters_list.*, 
	rpcl.current_client_status, 
	rpcl.current_payment_status, 
	rpcl.expiry_date::DATE as ExpiryDate,
	rpcl.consecutive_days_expired,
	total_paid.TotalPaid
from defaulters_list 
	left join total_paid 
		on defaulters_list.unique_customer_id = total_paid.payg_account_id
	left join kenya.rp_portfolio_customer_lookup rpcl 
		on defaulters_list.account_id = rpcl.account_id 
