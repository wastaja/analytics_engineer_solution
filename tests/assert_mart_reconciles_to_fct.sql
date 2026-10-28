-- Every measure of the mart, summed over country and product, must equal the same measure
-- computed straight from the fact for the same date and currency (exact comparison).
-- Returns the date/currency combinations that do not reconcile.
with
    fct_agreement_daily as (
        select *
        from {{ref('fct_agreement_daily')}}
    )

    , mart_portfolio_daily as (
        select *
        from {{ref('mart_portfolio_daily')}}
    )

    , fct_totals as (
        select
            reporting_date
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
        group by reporting_date, currency
    )

    , mart_totals as (
        select
            reporting_date
            , currency
            , sum(agreement_count) as agreement_count
            , sum(total_due) as total_due
            , sum(total_paid) as total_paid
            , sum(arrears_amount) as arrears_amount
            , sum(remaining_scheduled_amount) as remaining_scheduled_amount
            , sum(credit_balance) as credit_balance
            , sum(dpd7_count) as dpd7_count
            , sum(dpd30_count) as dpd30_count
        from mart_portfolio_daily
        group by reporting_date, currency
    )

select
    coalesce(f.reporting_date, m.reporting_date) as reporting_date
    , coalesce(f.currency, m.currency) as currency
from fct_totals as f
    full outer join mart_totals as m
        on m.reporting_date = f.reporting_date
        and m.currency = f.currency
where f.reporting_date is null
    or m.reporting_date is null
    or f.agreement_count is distinct from m.agreement_count
    or f.total_due is distinct from m.total_due
    or f.total_paid is distinct from m.total_paid
    or f.arrears_amount is distinct from m.arrears_amount
    or f.remaining_scheduled_amount is distinct from m.remaining_scheduled_amount
    or f.credit_balance is distinct from m.credit_balance
    or f.dpd7_count is distinct from m.dpd7_count
    or f.dpd30_count is distinct from m.dpd30_count
