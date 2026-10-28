-- The fact must have exactly the rows of the spine: no join may drop or multiply an
-- agreement-date. Returns the keys present on one side only.
with
    int_agreement_dates as (
        select *
        from {{ref('int_agreement_dates')}}
    )

    , fct_agreement_daily as (
        select *
        from {{ref('fct_agreement_daily')}}
    )

select
    coalesce(s.agreement_date_key, f.agreement_date_key) as agreement_date_key
    , s.agreement_date_key is null as missing_in_spine
    , f.agreement_date_key is null as missing_in_fact
from int_agreement_dates as s
    full outer join fct_agreement_daily as f
        on f.agreement_date_key = s.agreement_date_key
where s.agreement_date_key is null
    or f.agreement_date_key is null
