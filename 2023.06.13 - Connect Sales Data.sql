select 
	rrs.unique_account_id, 
	rrs.downpayment_date,
	rrs.install_date,
	cpd.customer_name, 
	cpd.customer_phone_1, 
	cpd.customer_birth_date,
	c.customer_gender, 
	rrs.region, 
	rrs.shop, 
	sa.sales_agent_name, 
	sa.sales_agent_bboxx_id, 
	rrs.current_contract_status, 
	rrs.product_name, 
	rrs.product_type, 
	rrs.product_category, 
	rrs.current_hardware_type, 
	rrs.current_system, 
	rrs.downpayment, 
	rrs.credit_price,
	case 
		when 
			rrs.product_name like '%A03%' 
		then 'Samsung A03 Core'
		when 
			rrs.product_name like '%A13%' 
		then 'Samsung A13'	
		else 'Other'
	end as PhoneType
from kenya.rp_retail_sales rrs
	left join kenya.customer_personal_details cpd 
		on rrs.account_id = cpd.account_id 
	left join kenya.sales_agent sa 
		on rrs.sign_up_sales_agent_id = sa.sales_agent_id 
	left join kenya.customer c
		on rrs.account_id = c.account_id 
where 
	rrs.product_category = 'CONNECT'