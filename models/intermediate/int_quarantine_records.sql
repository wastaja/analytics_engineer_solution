-- Single place where validation rules live. Every staging row is checked once:
--   * a rejected row gets its reject_reason and excluded_from_metrics = true;
--   * a row flagged as a conflicting version stays in the metrics (excluded_from_metrics = false)
--     and is listed for review only.
-- The *_valid / *_eligible models are defined as "staging rows not rejected here", so the rules
-- cannot drift between the quarantine and the models that feed the metrics.
-- Accepted domain values mirror the accepted_values tests in staging/schema.yml.
with
    stg_agreements as (
        select *
        from {{ref('stg_agreements')}}
    )

    , stg_schedule as (
        select * 
        from {{ref('stg_schedule')}}
    )

    , stg_payments as (
        select *
        from {{ref('stg_payments')}}
    )

    , agreements_checked as (
        select
            agreement_id
            , customer_id
            , country
            , product
            , currency
            , origination_date
            , principal_amount
            , updated_at
            , row_hash
            , is_conflicting_version
            , case
                when agreement_id is null
                    or customer_id is null
                    or country is null
                    or product is null
                    or currency is null
                    or origination_date is null
                    then 'MISSING_REQUIRED_FIELD'
                when country not in ('KE', 'UG')
                    or product not in ('PHONES', 'BODA')
                    or currency not in ('KES', 'UGX')
                    then 'INVALID_DOMAIN_VALUE' 
                when (country = 'KE' and currency <> 'KES')
                    or (country = 'UG' and currency <> 'UGX')
                    then 'COUNTRY_CURRENCY_MISMATCH'
            end as reject_reason
        from stg_agreements
    )

    -- one row per agreement_id (unique after staging), so joining it to child rows does not fan out
    , valid_agreements as (
        select agreement_id, currency
        from agreements_checked
        where reject_reason is null
    )

    , schedule_checked as (
        select
            s.installment_id
            , s.agreement_id
            , s.due_amount
            , s.updated_at
            , s.row_hash
            , s.is_conflicting_version
            , a.currency as agreement_currency
            , case
                when s.installment_id is null
                    or s.agreement_id is null
                    or s.due_date is null
                    or s.due_amount is null
                    then 'MISSING_REQUIRED_FIELD'
                when a.agreement_id is null then 'ORPHAN_INSTALLMENT' 
                when s.due_amount <= 0 then 'NON_POSITIVE_AMOUNT'
            end as reject_reason
        from stg_schedule as s
        left join valid_agreements as a
            on a.agreement_id = s.agreement_id
    )

    , payments_checked as (
        select
            p.payment_id
            , p.agreement_id
            , p.amount
            , p.updated_at
            , p.row_hash
            , p.is_conflicting_version
            , a.currency as agreement_currency
            , case
                when p.payment_id is null
                    or p.agreement_id is null
                    or p.payment_date is null
                    or p.amount is null
                    or p.status is null
                    then 'MISSING_REQUIRED_FIELD'
                when p.status not in ('POSTED', 'PENDING', 'REVERSED') then 'INVALID_STATUS'
                when a.agreement_id is null then 'ORPHAN_PAYMENT'
                when p.amount <= 0 then 'NON_POSITIVE_AMOUNT'
            end as reject_reason
        from stg_payments as p
        left join valid_agreements as a
            on a.agreement_id = p.agreement_id
    )

    -- agreements.amount is principal_amount (descriptive only); the currency of a row whose
    -- agreement is unknown cannot be determined and is reported as UNKNOWN.
    , all_checked as (
        select
            'agreements' as source_table
            , agreement_id as record_key
            , row_hash
            , agreement_id
            , principal_amount as amount
            , coalesce(currency, 'UNKNOWN') as currency
            , reject_reason
            , is_conflicting_version
            , updated_at
        from agreements_checked

        union all

        select
            'schedule'
            , installment_id
            , row_hash
            , agreement_id
            , due_amount
            , coalesce(agreement_currency, 'UNKNOWN')
            , reject_reason
            , is_conflicting_version
            , updated_at
        from schedule_checked

        union all

        select
            'payments'
            , payment_id
            , row_hash
            , agreement_id
            , amount
            , coalesce(agreement_currency, 'UNKNOWN')
            , reject_reason
            , is_conflicting_version
            , updated_at
        from payments_checked
    )

select
    source_table
    , record_key
    , row_hash
    , agreement_id
    , amount
    , currency
    , reject_reason as reason
    , true as excluded_from_metrics
    , updated_at
from all_checked
where reject_reason is not null

union all

select
    source_table
    , record_key
    , row_hash
    , agreement_id
    , amount
    , currency
    , 'CONFLICTING_VERSION' as reason
    , false as excluded_from_metrics
    , updated_at
from all_checked
where is_conflicting_version
