with
    typed as (
        select
            upper(trim(payment_id)) as payment_id
            , upper(trim(agreement_id)) as agreement_id
            , try_to_date(payment_date) as payment_date
            , try_to_number(amount, 18, 2) as amount
            , upper(trim(status)) as status
            , try_to_timestamp_ntz(updated_at) as updated_at
        from {{ ref('payments') }}
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

select *
from hashed
qualify
    row_number() over (partition by payment_id order by updated_at desc, row_hash) = 1
