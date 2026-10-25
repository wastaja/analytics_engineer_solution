# Data dictionary

CSV encoding: UTF-8; separator: comma; header present. All raw seed fields may initially be loaded as strings. Blank fields mean missing values. Timestamps have no timezone and are used only to order record versions.

| File | Business key | Fields |
|---|---|---|
| agreements.csv | agreement_id | customer_id (customers can hold multiple agreements), country (KE/UG after trim/uppercase), product (PHONES/BODA after trim/uppercase), currency (KES/UGX), origination_date (ISO date), principal_amount (decimal; descriptive only), updated_at (ISO timestamp) |
| schedule.csv | installment_id | agreement_id, due_date (ISO date), due_amount (decimal), updated_at |
| payments.csv | payment_id | agreement_id, payment_date (ISO date), amount (decimal), status (POSTED/PENDING/REVERSED), updated_at |
| reporting_dates.csv | reporting_date | ISO date, 2026-01-01 through 2026-06-30 inclusive |

There are 60 valid agreements, six installments per agreement, and multiple source rows for some keys. IDs are strings. Country determines currency in this dataset; do not convert amounts. All agreements originate on 2026-01-01. Status reflects latest extract state. Payments are agreement-level; no installment allocation is supplied.

Minimum fact fields: agreement_id, reporting_date, customer_id, country, product, currency, total_due, total_paid, total_scheduled, arrears_amount, remaining_scheduled_amount, credit_balance, dpd, dpd7_flag, dpd30_flag. Decimal fields should use NUMBER(18,2) or a justified fixed-point equivalent.
