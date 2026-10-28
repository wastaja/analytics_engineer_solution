-- Grain: one row per agreement and reporting date (same as int_agreement_dates).
-- FIFO: payments are applied to installments ordered by due_date, then installment_id.
-- The oldest unpaid due installment is the first installment that is due on the reporting
-- date and whose cumulative scheduled amount exceeds total_paid by more than 0.01.
-- cum_scheduled never decreases along that order, so the installments that qualify form a
-- tail of the list and min(due_date) over them is the due date of the first one.
-- dpd = days from that due date to the reporting date (an installment due today has DPD 0);
-- 0 when no due installment is unpaid.
-- The join below multiplies rows (one per qualifying installment), but only min(due_date) is
-- taken from it and no amount is summed, so it cannot inflate any measure.
with
    int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , int_schedule_cumulative as (
        select *
        from {{ref('int_schedule_cumulative')}}
    )

    , oldest_unpaid as (
        select
            a.agreement_date_key
            , min(c.due_date) as oldest_unpaid_due_date
        from int_agreement_daily_amounts as a
            left join int_schedule_cumulative as c
                on c.agreement_id = a.agreement_id
                and c.due_date <= a.reporting_date
                and c.cum_scheduled > a.total_paid + 0.01
        group by a.agreement_date_key
    )

select
    a.agreement_date_key
    , a.agreement_id
    , a.reporting_date
    , o.oldest_unpaid_due_date
    , coalesce(greatest(datediff('day', o.oldest_unpaid_due_date, a.reporting_date), 0), 0) as dpd
from int_agreement_daily_amounts as a
    left join oldest_unpaid as o
        on o.agreement_date_key = a.agreement_date_key
