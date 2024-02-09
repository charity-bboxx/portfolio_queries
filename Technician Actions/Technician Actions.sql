with product as 
(
select 
		r.unique_account_id,
		LISTAGG(distinct(r.product_name),',') AS product_name
	from kenya.rp_retail_sales as r
	where product_name not like '%Flexx 12%'
	group by 1
)
select 
	action_date::date,
	p.unique_account_id, 
	p.product_name,
	t.job_title,
	actions.technician_name,
	actions.username,
	actions.action_type,
	look.region,
	look.shop,
	actions.current_system as "Contol Unit Type",
	look.tv_customer,
	look.current_payment_status,
	look.current_client_status,
	case
		when action_type = 'Repossessions' then 1
		else 0
	end as repos,
	case
		when action_type = 'Fulfillments' then 1
		else 0
	end as installs,
	case
		when actions.action_date::date = current_date - 1 then 1
		else 0
	end as previous_day_actions,
	case
		when last_day(action_date::date) >= current_date
		and action_type = 'Repossessions' then 1
		else 0
	end as current_month_repo,
	case
		when last_day(action_date::date) >= current_date
		and action_type = 'Fulfillments' then 1
		else 0
	end as current_month_installs
from
	kenya.rp_retail_installs_repos_actions as actions
left join kenya.rp_portfolio_customer_lookup as look 
		on
	actions.unique_customer_id = look.unique_customer_id
left join kenya.ke_employee t on
	t.employee_email = actions.username
	left join product as p on 
	p.unique_account_id = actions.unique_customer_id 
where
    -- change dates here
	actions.action_date::date between '2023-12-01' and '2023-12-13'
	--and '2023-10-31'
	and technician_name not like '%Mabonga%'
	and action_type not like 'Replacement' 

	
