with
    typed as (
        select
            upper(trim(installment_id)) as installment_id
            , upper(trim(agreement_id)) as agreement_id
            , try_to_date(due_date) as due_date
            , try_to_number(due_amount, 18, 2) as due_amount
            , try_to_timestamp_ntz(updated_at) as updated_at
        from {{ ref('schedule') }}
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

select *
from hashed
qualify
    row_number() over (partition by installment_id order by updated_at desc, row_hash) = 1
