-- Invariants of mart_portfolio_daily. Returns the rows that break any of them.
--   * counts are consistent: dpd30 <= dpd7 <= agreement_count, and agreement_count > 0;
--   * rates are between 0 and 1 and equal count / agreement_count up to the 4-decimal rounding;
--   * balance measures are never negative and arrears never exceed what remains to be paid.
with
    mart_portfolio_daily as (
        select *
        from {{ref('mart_portfolio_daily')}}
    )

select *
from mart_portfolio_daily
where agreement_count <= 0
    or dpd7_count > agreement_count
    or dpd30_count > dpd7_count
    or dpd7_count < 0
    or dpd7_rate not between 0 and 1
    or dpd30_rate not between 0 and 1
    or abs(dpd7_rate - dpd7_count / agreement_count) > 0.00005
    or abs(dpd30_rate - dpd30_count / agreement_count) > 0.00005
    or total_due < 0
    or total_paid < 0
    or arrears_amount < 0
    or remaining_scheduled_amount < 0
    or credit_balance < 0
    or arrears_amount > remaining_scheduled_amount
