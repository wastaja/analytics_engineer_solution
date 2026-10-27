-- Staging agreements that were not rejected in int_quarantine_records.
with
    stg_agreements as (
        select *
        from {{ref('stg_agreements')}}
    )

    , int_quarantine_records as (
        select *
        from {{ref('int_quarantine_records')}}
    )

select a.*
from stg_agreements as a
where not exists (
    select 1
    from int_quarantine_records as q
    where q.source_table = 'agreements'
        and q.row_hash = a.row_hash
        and q.excluded_from_metrics
)
