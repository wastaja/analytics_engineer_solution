-- The due installments form a prefix of the FIFO order, so an unpaid due installment exists
-- exactly when total_due exceeds total_paid by more than the 0.01 tolerance. Checks that DPD
-- agrees with the amounts, and that DPD is never negative. Returns the offending rows.
with
    int_agreement_daily_amounts as (
        select *
        from {{ref('int_agreement_daily_amounts')}}
    )

    , int_agreement_daily_dpd as (
        select *
        from {{ref('int_agreement_daily_dpd')}}
    )

select
    a.agreement_date_key
    , a.total_due
    , a.total_paid
    , d.oldest_unpaid_due_date
    , d.dpd
from int_agreement_daily_amounts as a
    inner join int_agreement_daily_dpd as d
        on d.agreement_date_key = a.agreement_date_key
where d.dpd < 0
    or (a.total_due > a.total_paid + 0.01 and d.oldest_unpaid_due_date is null)
    or (a.total_due <= a.total_paid + 0.01 and d.oldest_unpaid_due_date is not null)
    or (d.oldest_unpaid_due_date is null and d.dpd <> 0)
