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
	), 
	
dps as (
	select 
		LAST_DAY(rrs.downpayment_date) as TransactionMonth,
		case 
			when 
				rrs.current_system = 'nuovopay'
			then 'Connect'
			when 
				rrs.current_system = 'offline_token'
			then 'Flexx'
			else 'bPower'
		end as ProductCategory,  
		SUM(rrs.downpayment) as TotalDPs
	from kenya.rp_retail_sales rrs
	where 
		rrs.downpayment_date >= '20220101'
		and rrs.current_hardware_type <> 'not yet installed'
		and rrs.downpayment_date < CURRENT_DATE 
		--and rrs.unique_account_id = 'BXCK70260679'
	group by 
		TransactionMonth,
		ProductCategory
		),  
	
cash_collected as (
	select 
		LAST_DAY(ap.transaction_date::DATE) as TransactionMonth, 
		ac.ProductCategory, 
		SUM(ap.amount) as CashCollected
	from accounts_category ac
		left join src_odoo13_kenya.account_payment ap 
			on ac.unique_account_id = ap.payg_account_id 
	where 
		ap.transaction_date::DATE >= '20220101'
		and ap.state = 'posted'
		and ap.transaction_date::DATE < CURRENT_DATE 
		--and rrs.unique_account_id = 'BXCK70260679'
	group by 
		TransactionMonth,
		ac.ProductCategory
	) ,
	
cash_expected as (
	select 
		LAST_DAY(dcs.date_timestamp::DATE) as TransactionMonth,
		ac.ProductCategory,
		SUM(	
			case 
				when 
					dcs.consecutive_late_days < 60
					AND (dcs.date_timestamp::DATE - c.customer_active_start_date::DATE) > 7
				then dcs.daily_rate 
				else 0
			end ) as CashExpected
	from accounts_category ac 
		left join kenya.daily_customer_snapshot dcs 
			on ac.account_id = dcs.account_id 
		left join kenya.customer c 
			on ac.account_id = c.account_id 
	where 
		dcs.date_timestamp::DATE >= '20220101'
		and dcs.date_timestamp::DATE < CURRENT_DATE 
		--and rrs.unique_account_id = 'BXCK70260679'
	group by 
		TransactionMonth,
		ac.ProductCategory
		) 
		
select 
	cash_expected.ProductCategory,
	cash_expected.TransactionMonth, 
	cash_collected.CashCollected,
	cash_expected.CashExpected,
	dps.TotalDPs
from cash_expected 
	left join cash_collected 
		on cash_expected.TransactionMonth = cash_collected.TransactionMonth
			and cash_expected.ProductCategory = cash_collected.ProductCategory
	left join dps 
		on cash_expected.TransactionMonth = dps.TransactionMonth
			and cash_expected.ProductCategory = dps.ProductCategory
	