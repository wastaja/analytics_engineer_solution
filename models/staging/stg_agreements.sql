with
    agreements as (
        select *
        from {{ref('agreements')}}
    )

    , typed as (
        select
            {{clean_text('agreement_id')}} as agreement_id
            , {{clean_text('customer_id')}} as customer_id
            , {{clean_text('country')}} as country
            , {{clean_text('product')}} as product
            , {{clean_text('currency')}} as currency
            , try_to_date(origination_date) as origination_date
            , try_to_number(principal_amount, 18, 2) as principal_amount
            , try_to_timestamp_ntz(updated_at) as updated_at
        from agreements
    )

    , hashed as (
        select *
            , md5(concat_ws('|',
                coalesce(agreement_id::string, '')
                , coalesce(customer_id::string, '')
                , coalesce(country::string, '')
                , coalesce(product::string, '')
                , coalesce(currency::string, '')
                , coalesce(origination_date::string, '')
                , coalesce(principal_amount::string, '')
                , coalesce(updated_at::string, '')
            )) as row_hash
        from typed
    )

    -- rn = 1 is the latest version of the key. The hash range within (key, updated_at)
    -- tells exact duplicates (one hash) from conflicts (same timestamp, different content).
    , ranked as (
        select *
            , row_number() over (partition by agreement_id order by updated_at desc, row_hash) as rn
            , min(row_hash) over (partition by agreement_id, updated_at) as min_hash_at_ts
            , max(row_hash) over (partition by agreement_id, updated_at) as max_hash_at_ts
        from hashed
    )

select
    * exclude (rn, min_hash_at_ts, max_hash_at_ts)
    , (min_hash_at_ts <> max_hash_at_ts) as is_conflicting_version
from ranked
where rn = 1
