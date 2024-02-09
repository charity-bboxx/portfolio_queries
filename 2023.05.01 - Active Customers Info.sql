with contract_details as (	
	select 
		distinct dcs.customer_id,
		dcs.account_id, 
		rpcl.unique_customer_id, 
		rpcl.customer_active_start_date as InstallationDate,
		c.down_payment_paid_date, 
		cpd.customer_name, 
		cpd.customer_phone_1, 
		cpd.customer_phone_2, 
		rpcl.region, 
		rpcl.shop, 
		rpcl.sales_agent_names,
		rpcl.current_hardware_type, 
		rpcl.control_unit_serial_number,
		rpcl.downpayment, 
		dcs.daily_rate as dcs_dailyrate, 
		rpcl.daily_rate as rpcl_daily_rate,
		rpcl.total_contract_value, 
		rpcl.tv_customer, 
		c.current_customer_status, 
		c.current_payment_status,
		c.current_enable_status, 
		c.current_customer_status, 
		dcs.expiry_timestamp::DATE as ExpiryDate,
		dcs.consecutive_late_days
	from kenya.daily_customer_snapshot dcs 
		left join kenya.customer c 
			on dcs.account_id = c.account_id
		left join kenya.rp_portfolio_customer_lookup rpcl 
			on dcs.account_id = rpcl.account_id  
		left join kenya.customer_personal_details cpd 
			on dcs.account_id = cpd.account_id  
	where 
		dcs.date_timestamp::DATE = CURRENT_DATE --<--- enter the specific date here
		and c.current_customer_status = 'active'
		)
	, 
	
total_paid_to_date as (
	select 
		p.payg_account_id as AccountID, 
		SUM(p.amount) as TotalPaidToDate
	from src_odoo13_kenya.account_payment as p
	where 
		p.state = 'posted'
		and p.transaction_date::DATE <= CURRENT_DATE --<--- enter the specific date here
	group by 
		p.payg_account_id
		) 
	, 
	
total_paid_six_months as (
	select 
		p.payg_account_id as AccountID, 
		SUM(p.amount) as TotalPaid
	from src_odoo13_kenya.account_payment as p
	where 
		p.state = 'posted'
		and p.transaction_date::DATE >= current_date - 180 --<--- enter the specific date here
	group by 
		p.payg_account_id
		)
	, 
	
lifetime_ur  as (
	select 
		account_id, 
		SUM(
			case 
				when 
					payment_status = 'normal'
				then 1
				else 0
			end ) as DaysInNormalStatus,
		SUM(
			case 
				when 
					payment_status = 'normal'
					and enable_status not in ('pending_enabled', 'pending_disabled')
				then 1
				else 0
			end ) as DaysInNormalStatusExcPending,
		SUM(
			case 
				when 
					expiry_timestamp::DATE >= date_timestamp::DATE 
				then 1 
				else 0 
			end ) as DaysInNormalExpiry, 
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
		dcs.date_timestamp::DATE <= CURRENT_DATE --<--- enter the specific date here
	group by 
		dcs.account_id 
		)
	, 
	
last_six_mo_ur as (
	select 
		account_id, 
		SUM(
			case 
				when 
					payment_status = 'normal'
				then 1
				else 0
			end ) as DaysInNormalStatus,
		SUM(
			case 
				when 
					payment_status = 'normal'
					and enable_status not in ('pending_enabled', 'pending_disabled')
				then 1
				else 0
			end ) as DaysInNormalStatusExcPending,
		SUM(
			case 
				when 
					expiry_timestamp::DATE >= date_timestamp::DATE 
				then 1 
				else 0 
			end ) as DaysInNormalExpiry, 
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
		dcs.date_timestamp::DATE >= CURRENT_DATE - 180 --<--- enter the specific date here
	group by 
		dcs.account_id 
		)

select 
	contract_details.*,
	total_paid_to_date.TotalPaidToDate,
	total_paid_six_months.TotalPaid as TotalPaidLast6Months,
	contract_details.total_contract_value - total_paid_to_date.TotalPaidToDate as OutstandingBalance,
	case 
		when 
			contract_details.rpcl_daily_rate in (15,14.46)
		then 1 
		else 0 
	end as esf_only_customer, 
	lifetime_ur.DaysInNormalStatusExcPending as DaysNormal_Lifetime, 
	lifetime_ur.DaysActive as DaysActive_Lifetime, 
	last_six_mo_ur.DaysInNormalStatusExcPending as DaysNormal_SixMo, 
	last_six_mo_ur.DaysActive as DaysActive_SixMo
from contract_details 
	left join total_paid_to_date 
		on contract_details.unique_customer_id = total_paid_to_date.AccountID
	left join total_paid_six_months
		on contract_details.unique_customer_id = total_paid_six_months.AccountID
	left join lifetime_ur 
		on contract_details.account_id = lifetime_ur.account_id 
	left join last_six_mo_ur
		on contract_details.account_id = last_six_mo_ur.account_id		
--where 
	--contract_details.unique_customer_id = 'BXCK00166241'