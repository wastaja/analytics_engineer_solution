-- Grain: one row per valid agreement and reporting date (same as int_agreement_dates).
-- The three intermediate models share the grain and are joined one-to-one on agreement_date_key,
-- so nothing here can multiply a row or an amount. Left joins are used on purpose: a missing
-- match would show up as NULL and fail the not_null tests instead of silently dropping a row.
-- Balance measures are derived per agreement, so they must be summed (never recomputed from
-- summed totals) in any aggregate built on top of this table:
--   arrears_amount             = greatest(total_due - total_paid, 0)
--   remaining_scheduled_amount = greatest(total_scheduled - total_paid, 0)
--   credit_balance             = greatest(total_paid - total_scheduled, 0)
-- dpd7_flag / dpd30_flag: DPD of at least 7 / 30 days.
with
    int_agreement_dates as (
        select *
        from {{ref('int_agreement_dates')}}
    )

    , int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , int_agreement_daily_dpd as (
        select *
        from {{ref('int_agreement_daily_dpd')}}
    )

select
    d.agreement_date_key
    , d.agreement_id
    , d.reporting_date
    , d.customer_id
    , d.country
    , d.product
    , d.currency
    , a.total_due
    , a.total_paid
    , a.total_scheduled
    , greatest(a.total_due - a.total_paid, 0)::number(18, 2) as arrears_amount
    , greatest(a.total_scheduled - a.total_paid, 0)::number(18, 2) as remaining_scheduled_amount
    , greatest(a.total_paid - a.total_scheduled, 0)::number(18, 2) as credit_balance
    , p.oldest_unpaid_due_date
    , p.dpd
    , p.dpd >= 7 as dpd7_flag
    , p.dpd >= 30 as dpd30_flag
from int_agreement_dates as d
    left join int_agreement_daily_amounts as a
        on a.agreement_date_key = d.agreement_date_key
    left join int_agreement_daily_dpd as p
        on p.agreement_date_key = d.agreement_date_key
