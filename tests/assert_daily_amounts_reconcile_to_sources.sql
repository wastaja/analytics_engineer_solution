-- On the last reporting date the daily measures must equal plain sums over the source models,
-- computed by a different path and per currency. Catches double counting through joins and
-- payments dated after the last reporting date leaking into total_paid. Returns the currencies
-- that do not reconcile. Amounts are fixed-point NUMBER(18,2), so they are compared exactly.
with
    int_agreement_dates as (
        select *
        from {{ref('int_agreement_dates')}}
    )

    , int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , int_schedule_valid as (
        select *
        from {{ref('int_schedule_valid')}}
    )

    , int_payments_eligible as (
        select *
        from {{ref('int_payments_eligible')}}
    )

    , last_date as (
        select max(reporting_date) as reporting_date
        from int_agreement_dates
    )

    , agreements_on_last_date as (
        select
            d.agreement_id
            , d.currency
        from int_agreement_dates as d
        inner join last_date as l
            on l.reporting_date = d.reporting_date
    )

    , from_daily as (
        select
            d.currency
            , sum(a.total_due) as total_due
            , sum(a.total_paid) as total_paid
            , sum(a.total_scheduled) as total_scheduled
        from int_agreement_daily_amounts as a
        inner join int_agreement_dates as d
            on d.agreement_date_key = a.agreement_date_key
        inner join last_date as l
            on l.reporting_date = a.reporting_date
        group by d.currency
    )

    , schedule_from_source as (
        select
            a.currency
            , sum(case when i.due_date <= l.reporting_date then i.due_amount else 0 end) as total_due
            , sum(i.due_amount) as total_scheduled
        from int_schedule_valid as i
        inner join agreements_on_last_date as a
            on a.agreement_id = i.agreement_id
        cross join last_date as l
        group by a.currency
    )

    , paid_from_source as (
        select
            a.currency
            , sum(p.amount) as total_paid
        from int_payments_eligible as p
        inner join agreements_on_last_date as a
            on a.agreement_id = p.agreement_id
        cross join last_date as l
        where p.payment_date <= l.reporting_date
        group by a.currency
    )

select
    f.currency
    , f.total_due
    , s.total_due as source_total_due
    , f.total_paid
    , p.total_paid as source_total_paid
    , f.total_scheduled
    , s.total_scheduled as source_total_scheduled
from from_daily as f
left join schedule_from_source as s
    on s.currency = f.currency
left join paid_from_source as p
    on p.currency = f.currency
where f.total_due <> coalesce(s.total_due, 0)
    or f.total_paid <> coalesce(p.total_paid, 0)
    or f.total_scheduled <> coalesce(s.total_scheduled, 0)
