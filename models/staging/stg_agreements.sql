with 
    typed as (
        select
            upper(trim(agreement_id)) as agreement_id
            , upper(trim(customer_id)) as customer_id
            , upper(trim(country)) as country
            , upper(trim(product)) as product
            , upper(trim(currency)) as currency
            , try_to_date(origination_date) as origination_date
            , try_to_number(principal_amount, 18, 2) as principal_amount
            , try_to_timestamp_ntz(updated_at) as updated_at
        from {{ ref('agreements') }}
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
    
select *
from hashed
qualify 
    row_number() over (partition by agreement_id order by updated_at desc, row_hash) = 1