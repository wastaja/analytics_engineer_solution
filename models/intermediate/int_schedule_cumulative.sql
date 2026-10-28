-- Grain: one row per installment. cum_scheduled is the running total of scheduled amounts per
-- agreement in FIFO order (due_date, then installment_id). Payments are agreement-level in the
-- source, so this running total is what lets them be applied oldest-first to installments:
-- an installment is fully paid once total_paid reaches its cum_scheduled.
with
    int_schedule_valid as (
        select *
        from {{ref('int_schedule_valid')}}
    )

select
    installment_id
    , agreement_id
    , due_date
    , due_amount
    , sum(due_amount) over (partition by agreement_id order by due_date, installment_id rows between unbounded preceding and current row)::number(18, 2) as cum_scheduled
from int_schedule_valid
