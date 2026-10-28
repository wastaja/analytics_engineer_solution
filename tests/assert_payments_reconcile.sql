-- Every staging payment must land in exactly one bucket: eligible, quarantined or excluded by
-- status. Returns a row (test fails) if counts or amounts do not add up. Amounts are
-- fixed-point NUMBER(18,2), so they are compared exactly.
with
    stg_payments as (
        select *
        from {{ref('stg_payments')}}
    )

    , int_payments_eligible as (
        select *
        from {{ref('int_payments_eligible')}}
    )

    , dq_excluded_summary as (
        select *
        from {{ref('dq_excluded_summary')}}
    )

    , totals as (
        select count(*) as payment_count, sum(amount) as payment_amount
        from stg_payments
    )

    , eligible as (
        select count(*) as payment_count, coalesce(sum(amount), 0) as payment_amount
        from int_payments_eligible
    )

    , excluded as (
        select coalesce(sum(record_count), 0) as payment_count, coalesce(sum(total_amount), 0) as payment_amount
        from dq_excluded_summary
        where source_table = 'payments'
    )

select
    totals.payment_count as stg_count
    , eligible.payment_count + excluded.payment_count as bucket_count
    , totals.payment_amount as stg_amount
    , eligible.payment_amount + excluded.payment_amount as bucket_amount
from totals
cross join eligible
cross join excluded
where totals.payment_count <> eligible.payment_count + excluded.payment_count
    or totals.payment_amount <> eligible.payment_amount + excluded.payment_amount
