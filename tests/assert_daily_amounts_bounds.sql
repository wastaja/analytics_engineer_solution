-- Amounts are never negative and installments due can never exceed the whole schedule
-- (0.01 tolerance). Returns the offending rows.
with
    int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

select *
from int_agreement_daily_amounts
where total_due < 0
    or total_paid < 0
    or total_scheduled < 0
    or total_due > total_scheduled + 0.01
