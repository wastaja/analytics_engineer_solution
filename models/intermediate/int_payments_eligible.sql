-- Payments that count towards portfolio metrics: latest version is POSTED and the payment
-- was not rejected in int_quarantine_records (known agreement, positive amount).
-- Status is filtered here, after deduplication in staging, so a latest REVERSED payment
-- contributes nothing at any reporting date. Payments dated after the last reporting
-- date stay in this model; they simply never fall into a reporting date.
with
    stg_payments as (
        select *
        from {{ref('stg_payments')}}
    )

    , int_agreements_valid as (
        select *
        from {{ref('int_agreements_valid')}}
    )

    , int_quarantine_records as (
        select *
        from {{ref('int_quarantine_records')}}
    )

select
    p.payment_id
    , p.agreement_id
    , p.payment_date
    , p.amount
    , a.currency
    , p.updated_at
    , p.row_hash
from stg_payments as p
    inner join int_agreements_valid as a
        on a.agreement_id = p.agreement_id
where
    p.status = 'POSTED'
    and not exists (
        select 1
        from int_quarantine_records as q
        where q.source_table = 'payments'
            and q.row_hash = p.row_hash
            and q.excluded_from_metrics
    )
