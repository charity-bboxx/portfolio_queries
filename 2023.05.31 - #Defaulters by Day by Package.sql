select 
	date_timestamp::DATE as ActivityDate,
	rpcl.current_hardware_type,
	count(daily_customer_snapshot_id) as NumberOfDefaulters
from kenya.daily_customer_snapshot dcs 
	left join kenya.rp_portfolio_customer_lookup rpcl 
		on dcs.account_id = rpcl.account_id 
where 
	dcs.date_timestamp::DATE >= '20230501'
	and dcs.payment_status = 'default'
group by 
	ActivityDate,
	rpcl.current_hardware_type
	
	
	
select 
	date_timestamp::DATE as ActivityDate,
	case 
		when 
			rpcl.daily_rate in (15,14.46) 
		then 1 
		else 0
	end as esf, 
	count(daily_customer_snapshot_id) as NumberOfDefaulters
from kenya.daily_customer_snapshot dcs 
	left join kenya.rp_portfolio_customer_lookup rpcl 
		on dcs.account_id = rpcl.account_id 
where 
	dcs.date_timestamp::DATE >= '20230501'
	and dcs.payment_status = 'default'
group by 
	ActivityDate,
	esf
	
	
	
