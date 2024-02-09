--select* from kenya.agg_dcs_today limit 5

with sales_details AS (
SELECT
	DISTINCT   
    sales.unique_account_id,
	sales.sales_person,
	agent.username,
    agent.sales_agent_bboxx_id,
	agent.sales_agent_name,
	agent.sales_agent_mobile
FROM
	kenya.rp_retail_sales as sales
	left join 
	kenya.sales_agent as agent on   
	agent.sales_agent_id = sales.sign_up_sales_agent_id
    where sales.sale_type = 'install'
    and sales.sales_order_id = sales.unique_account_id	
    --and sales.unique_account_id= 'BXCK00000131'
    )
SELECT
today.date_timestamp::date as activity_date,
c.unique_account_id,
details.customer_name,
sales_details.sales_person,
details.customer_phone_1,
details.customer_phone_2,
details.customer_home_address as nearest_landmark,
details.home_address_2,
details.home_address_3,
details.home_address_5,
details.home_address_4,
today.daily_rate,
filters.shop,
today.consecutive_late_days,
CASE        
            WHEN today.consecutive_late_days BETWEEN 15 AND 29 THEN '2. PAR 1 -30'
            WHEN today.consecutive_late_days BETWEEN 30 AND 59 THEN '3. PAR  30 -60'
            WHEN today.consecutive_late_days BETWEEN 60 AND 120 THEN '4. PAR 60 -120'
            WHEN today.consecutive_late_days > 90 THEN '5. PAR 120+'
        END AS PAR_bucket,
        row_number() over 
        (
		partition by c.customer_id
		) as related_accounts
 from kenya.agg_dcs_today  as today
  LEFT JOIN
 kenya.customer_personal_details as details on 
details.account_id = today.account_id LEFT JOIN
kenya.customer as c on c.account_id = details.account_id 
left join kenya.rp_portfolio_customer_lookup as filters on 
filters.account_id = today.account_id
left join sales_details as sales_details on 
sales_details.unique_account_id = c.unique_account_id
where today.consecutive_late_days  BETWEEN 15 AND 120
