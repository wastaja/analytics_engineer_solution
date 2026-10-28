-- total_due and total_paid are cumulative, so they can never decrease from one reporting date
-- to the next, and total_scheduled is constant per agreement. Returns the offending rows.
with
    int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , with_previous as (
        select
            *
            , lag(total_due) over (partition by agreement_id order by reporting_date) as previous_total_due
            , lag(total_paid) over (partition by agreement_id order by reporting_date) as previous_total_paid
            , lag(total_scheduled) over (partition by agreement_id order by reporting_date) as previous_total_scheduled
        from int_agreement_daily_amounts
    )

select *
from with_previous
where total_due < previous_total_due
    or total_paid < previous_total_paid
    or total_scheduled <> previous_total_scheduled
