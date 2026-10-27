with
    reporting_dates as (
        select *
        from {{ref('reporting_dates')}}
    )

select distinct
    try_to_date(reporting_date) as reporting_date
from reporting_dates
