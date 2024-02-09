select distinct 
	customer.unique_account_id, 
	customer.customer_active_start_date::DATE as InstallationDate,
	customer_personal_details.customer_name,
	customer.customer_preferred_language,
	customer_personal_details.customer_phone_1, 
	customer_personal_details.customer_phone_2,
	customer_personal_details.customer_birth_date,
	customer_personal_details.customer_national_id_number, 
	customer_personal_details.customer_national_id_type,
	organisation.shop_region,
	organisation.shop_name,
	customer.sales_person, 
	customer.current_customer_status, 
	customer.current_payment_status,
	customer.down_payment_paid_date::DATE
from customer 
	left join customer_personal_details
		on customer.customer_id = customer_personal_details.customer_id 
	left join organisation 
		on customer.organisation_id = organisation.organisation_id 
where 
	customer.ngu = 'Kenya'
	and customer_active_start_date::date >= '20231201'