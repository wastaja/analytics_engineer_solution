-- Grain: one row per reporting date, country, product and currency.
-- Currencies are never mixed (no FX): currency is part of the grain.
-- agreement_count is the denominator of the DPD rates: all agreements present on that date,
-- including fully paid ones and ones with DPD 0.
-- Balance measures are sums of the per-agreement values from fct_agreement_daily, e.g. an
-- overpaid agreement adds to credit_balance and does not offset another agreement's arrears.
with
    fct_agreement_daily as (
        select *
        from {{ref('fct_agreement_daily')}}
    )

    , aggregated as (
        select
            reporting_date
            , country
            , product
            , currency
            , count(*) as agreement_count
            , sum(total_due) as total_due
            , sum(total_paid) as total_paid
            , sum(arrears_amount) as arrears_amount
            , sum(remaining_scheduled_amount) as remaining_scheduled_amount
            , sum(credit_balance) as credit_balance
            , count_if(dpd7_flag) as dpd7_count
            , count_if(dpd30_flag) as dpd30_count
        from fct_agreement_daily
        group by reporting_date, country, product, currency
    )

select
    reporting_date
    , country
    , product
    , currency
    , agreement_count
    , total_due::number(18, 2) as total_due
    , total_paid::number(18, 2) as total_paid
    , arrears_amount::number(18, 2) as arrears_amount
    , remaining_scheduled_amount::number(18, 2) as remaining_scheduled_amount
    , credit_balance::number(18, 2) as credit_balance
    , dpd7_count
    , dpd30_count
    , (dpd7_count / agreement_count)::number(9, 4) as dpd7_rate
    , (dpd30_count / agreement_count)::number(9, 4) as dpd30_rate
from aggregated
