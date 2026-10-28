-- Grain: one row per valid agreement and reporting date, from the origination date through
-- the last reporting date (the reporting_dates calendar ends on 2026-06-30). This is the spine
-- every daily measure is attached to, one-to-one.
with
    int_agreements_valid as (
        select *
        from {{ref('int_agreements_valid')}}
    )

    , stg_reporting_dates as (
        select *
        from {{ref('stg_reporting_dates')}}
    )

select
    a.agreement_id || '|' || to_char(d.reporting_date, 'YYYY-MM-DD') as agreement_date_key
    , a.agreement_id
    , d.reporting_date
    , a.customer_id
    , a.country
    , a.product
    , a.currency
from int_agreements_valid as a
    inner join stg_reporting_dates as d
        on d.reporting_date >= a.origination_date
