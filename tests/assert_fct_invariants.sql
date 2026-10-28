-- Invariants of fct_agreement_daily. Returns the rows that break any of them.
--   * balance measures are never negative;
--   * total_due never exceeds total_scheduled, so arrears never exceed what remains to be paid;
--   * an agreement is either in credit or has something left to pay, never both;
--   * credit_balance - remaining_scheduled_amount = total_paid - total_scheduled (exact);
--   * the DPD flags follow dpd, and dpd > 0 only when there are arrears beyond the 0.01 tolerance.
with
    fct_agreement_daily as (
        select *
        from {{ref('fct_agreement_daily')}}
    )

select *
from fct_agreement_daily
where arrears_amount < 0
    or remaining_scheduled_amount < 0
    or credit_balance < 0
    or total_due > total_scheduled + 0.01
    or arrears_amount > remaining_scheduled_amount
    or (credit_balance > 0 and remaining_scheduled_amount > 0)
    or credit_balance - remaining_scheduled_amount <> total_paid - total_scheduled
    or dpd < 0
    or dpd7_flag <> (dpd >= 7)
    or dpd30_flag <> (dpd >= 30)
    or (dpd30_flag and not dpd7_flag)
    or (dpd > 0 and arrears_amount <= 0.01)
