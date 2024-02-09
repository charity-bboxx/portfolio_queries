--payment per customer. excludes bonuses
select payments.sales_order_id,
    SUM(amount) as AmountPaid
from kenya.payment AS payments
WHERE payments.processing_status = 'posted'
    and payments.is_void = FALSE
    AND payments.payment_utc_timestamp::DATE >= '20231214' --<-- enter the start date
    AND payments.payment_utc_timestamp::DATE <= current_date --<-- enter the end date
    and payments.third_party_payment_ref_id not like '%BONUS%'
GROUP BY payments.sales_order_id