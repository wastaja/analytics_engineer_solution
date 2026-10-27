with
    schedule as (
        select *
        from {{ref('schedule')}}
    )

    , typed as (
        select
            {{clean_text('installment_id')}} as installment_id
            , {{clean_text('agreement_id')}} as agreement_id
            , try_to_date(due_date) as due_date
            , try_to_number(due_amount, 18, 2) as due_amount
            , try_to_timestamp_ntz(updated_at) as updated_at
        from schedule
    )

    , hashed as (
        select *
            , md5(concat_ws('|',
                coalesce(installment_id::string, '')
                , coalesce(agreement_id::string, '')
                , coalesce(due_date::string, '')
                , coalesce(due_amount::string, '')
                , coalesce(updated_at::string, '')
            )) as row_hash
        from typed
    )

    -- rn = 1 is the latest version of the key. The hash range within (key, updated_at)
    -- tells exact duplicates (one hash) from conflicts (same timestamp, different content).
    , ranked as (
        select *
            , row_number() over (partition by installment_id order by updated_at desc, row_hash) as rn
            , min(row_hash) over (partition by installment_id, updated_at) as min_hash_at_ts
            , max(row_hash) over (partition by installment_id, updated_at) as max_hash_at_ts
        from hashed
    )

select
    * exclude (rn, min_hash_at_ts, max_hash_at_ts)
    , (min_hash_at_ts <> max_hash_at_ts) as is_conflicting_version
from ranked
where rn = 1
