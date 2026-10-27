-- Records kept out of the portfolio metrics, with counts and amounts by currency.
--   QUARANTINED     - invalid rows (e.g. orphan payments); amount is the row's own amount.
--   STATUS_EXCLUDED - valid payments whose latest status is not POSTED (PENDING, REVERSED).
-- Currencies are never mixed; a row whose agreement is unknown is reported as UNKNOWN.
with
    int_quarantine_records as (
        select *
        from {{ref('int_quarantine_records')}}
    )

    , stg_payments as (
        select *
        from {{ref('stg_payments')}}
    )

    , int_agreements_valid as (
        select *
        from {{ref('int_agreements_valid')}}
    )

    , quarantined as (
        select
            'QUARANTINED' as exclusion_type
            , source_table
            , reason
            , currency
            , count(*) as record_count
            , sum(amount) as total_amount
        from int_quarantine_records
        where excluded_from_metrics
        group by 1, 2, 3, 4
    )

    , status_excluded as (
        select
            'STATUS_EXCLUDED' as exclusion_type
            , 'payments' as source_table
            , 'STATUS_' || p.status as reason
            , a.currency
            , count(*) as record_count
            , sum(p.amount) as total_amount
        from stg_payments as p
        inner join int_agreements_valid as a
            on a.agreement_id = p.agreement_id
        where p.status <> 'POSTED'
            and not exists (
                select 1
                from int_quarantine_records as q
                where q.source_table = 'payments'
                    and q.row_hash = p.row_hash
                    and q.excluded_from_metrics
            )
        group by 1, 2, 3, 4
    )

select
    exclusion_type
    , source_table
    , reason
    , currency
    , record_count
    , total_amount::number(18, 2) as total_amount
from quarantined

union all

select
    exclusion_type
    , source_table
    , reason
    , currency
    , record_count
    , total_amount::number(18, 2) as total_amount
from status_excluded
