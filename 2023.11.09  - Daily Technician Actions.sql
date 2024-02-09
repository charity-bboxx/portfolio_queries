select 
	action_date::date,
	actions.unique_customer_id, 
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
where
	actions.action_date::date >= '2023-11-01'
	--and '2023-10-31'
	and technician_name not like '%Mabonga%'
