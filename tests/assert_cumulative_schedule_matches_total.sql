-- The running total of the last installment of an agreement must equal its total_scheduled.
-- Returns the agreements where the two paths disagree.
with
    int_schedule_cumulative as (
        select *
        from {{ref('int_schedule_cumulative')}}
    )

    , int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , last_cumulative as (
        select
            agreement_id
            , max(cum_scheduled) as max_cum_scheduled
        from int_schedule_cumulative
        group by agreement_id
    )

    , scheduled as (
        select distinct
            agreement_id
            , total_scheduled
        from int_agreement_daily_amounts
    )

select
    l.agreement_id
    , l.max_cum_scheduled
    , s.total_scheduled
from last_cumulative as l
    inner join scheduled as s
        on s.agreement_id = l.agreement_id
where l.max_cum_scheduled <> s.total_scheduled
