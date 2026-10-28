-- Grain: one row per agreement and reporting date (same as int_agreement_dates).
-- Each measure is aggregated to the spine grain on its own and only then joined one-to-one,
-- so no amount is ever multiplied by another join.
--   total_due       - installments with due_date <= reporting_date
--   total_paid      - eligible payments with payment_date <= reporting_date (a payment on the
--                     reporting date counts; payments after the last reporting date never match)
--   total_scheduled - all installments of the agreement, including future ones
with
    int_agreement_dates as (
        select *
        from {{ref('int_agreement_dates')}}
    )

    , int_schedule_valid as (
        select *
        from {{ref('int_schedule_valid')}}
    )

    , int_payments_eligible as (
        select *
        from {{ref('int_payments_eligible')}}
    )

    , due as (
        select
            d.agreement_date_key
            , coalesce(sum(i.due_amount), 0) as total_due
        from int_agreement_dates as d
            left join int_schedule_valid as i
                on i.agreement_id = d.agreement_id
                and i.due_date <= d.reporting_date
        group by d.agreement_date_key
    )

    -- payments are summed to agreement and day first, so the range join below
    -- cannot count a payment more than once per reporting date
    , payments_daily as (
        select
            agreement_id
            , payment_date
            , sum(amount) as amount
        from int_payments_eligible
        group by agreement_id, payment_date
    )

    , paid as (
        select
            d.agreement_date_key
            , coalesce(sum(p.amount), 0) as total_paid
        from int_agreement_dates as d
            left join payments_daily as p
                on p.agreement_id = d.agreement_id
                and p.payment_date <= d.reporting_date
        group by d.agreement_date_key
    )

    , scheduled as (
        select
            agreement_id
            , sum(due_amount) as total_scheduled
        from int_schedule_valid
        group by agreement_id
    )

select
    d.agreement_date_key
    , d.agreement_id
    , d.reporting_date
    , due.total_due::number(18, 2) as total_due
    , paid.total_paid::number(18, 2) as total_paid
    , coalesce(scheduled.total_scheduled, 0)::number(18, 2) as total_scheduled
from int_agreement_dates as d
    left join due
        on due.agreement_date_key = d.agreement_date_key
    left join paid
        on paid.agreement_date_key = d.agreement_date_key
    left join scheduled
        on scheduled.agreement_id = d.agreement_id
