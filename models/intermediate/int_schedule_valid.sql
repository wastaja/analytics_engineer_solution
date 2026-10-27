-- Staging installments that were not rejected in int_quarantine_records
-- (known agreement, positive amount). The latest schedule is used for every reporting date.
with
    stg_schedule as (
        select *
        from {{ref('stg_schedule')}}
    )

    , int_quarantine_records as (
        select *
        from {{ref('int_quarantine_records')}}
    )

select s.*
from stg_schedule as s
where not exists (
    select 1
    from int_quarantine_records as q
    where q.source_table = 'schedule'
        and q.row_hash = s.row_hash
        and q.excluded_from_metrics
)
