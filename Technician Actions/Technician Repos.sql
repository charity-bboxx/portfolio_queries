--technician repos 
select c.account_id,
    c.unique_account_id,
    c.customer_active_end_date,
    c.current_customer_status,
    r.repossession_status,
    t.username,
    t.technician_name,
    t.record_source,
    o.shop_name,
    o.shop_region
from kenya.customer c
    left join kenya.repossession r on c.account_id = r.account_id
    left join kenya.technician t on r.technician_id = t.technician_id
    left join kenya.organisation o on o.organisation_id = c.organisation_id
where c.customer_active_end_date is not null
    and c.current_customer_status = 'repo'
    and c.customer_active_end_date >= '2024-01-01'
    and r.repossession_status = 'done';