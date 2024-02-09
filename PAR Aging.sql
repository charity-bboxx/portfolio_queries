
--WITH Customer_Life_Time_Value AS (
--  SELECT 
--    customer_id,
--    SUM(product.total_value * product.quantity) AS TotalLoanValue
--  FROM customer_product AS product 
--  WHERE 
--    product.quantity > 0 AND 
--    product.is_void = FALSE 
--  GROUP BY 
--    customer_id
--)

SELECT 
  rp_pm_filter_view.country AS "Country",
  dcs.calendar_id::TEXT::DATE AS "Activity Month",
  COUNT(DISTINCT rp_pm_filter_view.customer_id) AS "Portfolio Size",
  CASE
   WHEN 
     dcs.consecutive_late_days <= 0 
     THEN '0. PAR_0 (Not PAR)'
   WHEN
     dcs.consecutive_late_days >= 1
     AND dcs.consecutive_late_days <= 30
     THEN  '1. PAR 1 to 30 days'
   WHEN
     dcs.consecutive_late_days >= 31
     AND dcs.consecutive_late_days <= 60
     THEN  '2. PAR 31 to 60 days'
   WHEN
     dcs.consecutive_late_days >= 61
     AND dcs.consecutive_late_days <= 90
     THEN  '3. PAR 61 to 90 days'
   WHEN 
     dcs.consecutive_late_days >= 91
     THEN  '4. PAR > 90'        
   ELSE '5. PAR_Edge_Cases'  -- usually not many so just set to < PAR 0, but worth checking how many are in this bucket before sending query output.
  END AS "PAR Category",
  --SUM(loan_value.TotalLoanValue)/103.45 AS "Contract Lifetime Value ($)",
  SUM(dcs.total_due_to_date) AS "Total Period Invoices (KES)",
  SUM(dcs.total_paid_to_date) AS "Total Paid To-Date (KES)",
  SUM(dcs.balance) AS "Total Period Balance (KES)"
  --(SUM(loan_value.TotalLoanValue) + SUM(dcs.total_paid_to_date))/103.45 AS "Contract Lifetime Balance ($)",
FROM dcs_last_day_of_month AS dcs
  LEFT JOIN rp_pm_filter_view AS rp_pm_filter_view 
    ON dcs.customer_id = rp_pm_filter_view.customer_id     
--  LEFT JOIN Customer_Life_Time_Value AS loan_value
--    ON loan_value.customer_id = dcs.customer_id 
WHERE
  dcs.calendar_id::TEXT::DATE = '2022-03-31' -- Date to Change Every Time of Update
  AND rp_pm_filter_view.country = 'Kenya'
GROUP BY 
  country,
  "Activity Month",
  "PAR Category"
  