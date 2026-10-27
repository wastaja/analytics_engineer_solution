with
    payments as (
        select *
        from {{ref('payments')}}
    )

    , typed as (
        select
            {{clean_text('payment_id')}} as payment_id
            , {{clean_text('agreement_id')}} as agreement_id
            , try_to_date(payment_date) as payment_date
            , try_to_number(amount, 18, 2) as amount
            , {{clean_text('status')}} as status
            , try_to_timestamp_ntz(updated_at) as updated_at
        from payments
    )

    , hashed as (
        select *
            , md5(concat_ws('|',
                coalesce(payment_id::string, '')
                , coalesce(agreement_id::string, '')
                , coalesce(payment_date::string, '')
                , coalesce(amount::string, '')
                , coalesce(status::string, '')
                , coalesce(updated_at::string, '')
            )) as row_hash
        from typed
    )

    -- rn = 1 is the latest version of the key. The hash range within (key, updated_at)
    -- tells exact duplicates (one hash) from conflicts (same timestamp, different content).
    , ranked as (
        select *
            , row_number() over (partition by payment_id order by updated_at desc, row_hash) as rn
            , min(row_hash) over (partition by payment_id, updated_at) as min_hash_at_ts
            , max(row_hash) over (partition by payment_id, updated_at) as max_hash_at_ts
        from hashed
    )

select
    * exclude (rn, min_hash_at_ts, max_hash_at_ts)
    , (min_hash_at_ts <> max_hash_at_ts) as is_conflicting_version
from ranked
where rn = 1
