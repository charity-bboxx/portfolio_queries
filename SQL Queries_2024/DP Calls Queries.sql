-- extract data of customers who made their downpayment the previous day
select distinct 
	c.unique_account_id,
	c.customer_active_start_date::DATE as InstallationDate,
	cpd.customer_name,
	c.customer_preferred_language,
	cpd.customer_phone_1,
	cpd.customer_phone_2,
	cpd.customer_birth_date,
	cpd.customer_national_id_number,
	cpd.customer_national_id_type,
	o.shop_region,
	o.shop_name,
	c.sales_person,
	c.current_customer_status,
	c.current_payment_status,
	c.down_payment_paid_date::DATE
from kenya.customer as c
	left join kenya.customer_personal_details as cpd on 
		c.customer_id = cpd.customer_id
	left join kenya.organisation as o on
		c.organisation_id = o.organisation_id
where 
	c.ngu = 'Kenya'
	and cast(c.down_payment_paid_date as date) = current_date - 1