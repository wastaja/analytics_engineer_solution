# Analytics Engineering Task — Credit Portfolio Mart

Build a tested, documented reporting mart using **Snowflake SQL and dbt**. All inputs are synthetic. This is a recruitment exercise, not production work.

## Context and scope
Business has supplied the metric definitions below. Your responsibility is to implement them consistently, make data-quality issues visible, and explain how the mart becomes a certified reporting dataset. Do not redesign credit policy or invent a production DPD definition.

**Timebox: 4–6 hours.** Stop at six hours and describe unfinished work. Core correctness matters more than optional features. No paid Snowflake account is required: submit Snowflake SQL and a dbt project; local execution with another adapter is welcome if dialect differences are documented. We will validate Snowflake compatibility during review.

## Inputs
Use the four CSV files in `data/`. `DATA_DICTIONARY.md` describes their fields. They contain record updates, exact duplicates, a reversed payment, pending and future payments, an orphan payment, overpayment, and amounts with decimals. `updated_at` represents a latest-state extract, not a complete historical change log.

## Required work
1. Create dbt staging models that standardize fields, preserve money as fixed-point decimals, and select the latest record per business key. Resolve exact duplicates deterministically. Explain a policy for conflicting records with the same key and timestamp; flag them rather than silently choosing an arbitrary value.
2. Validate relationships and quarantine invalid rows in a queryable model with a reason. Exclude orphan payments from portfolio metrics. Report excluded record counts and amounts by currency.
3. Build reusable intermediate models and `fct_agreement_daily`, one row per agreement and reporting date, from origination through 2026-06-30 inclusive. Compute the supplied metrics below without multiplying amounts through joins.
4. Build `mart_portfolio_daily`, grouped by date, country, product, and currency, with agreement count, total due, total paid, arrears, remaining scheduled amount, credit balance, DPD 7+ count, and DPD 30+ count. Add DPD rates with a clear denominator. Keep currencies separate; no FX is supplied.
5. Add dbt tests for keys, relationships, accepted values, precision, metric invariants, and several numerical edge cases. Include model/column documentation, lineage, run instructions, and a short architecture note explaining ownership and certification.

## Supplied business definitions
These definitions deliberately simplify lending accounting. Do not include fees, interest accrual, write-offs, or principal accounting.

- Treat all dates as calendar dates; a payment on the reporting date counts.
- Deduplicate the entire latest-state extract before filtering by payment date. Keep only latest payments with status POSTED. A latest REVERSED payment contributes zero at every reporting date. This is **restated historical reporting**, not an as-known-at-the-time reconstruction.
- Use the latest schedule record per installment for all reporting dates. Historical schedule versions cannot be reconstructed from these inputs.
- `total_due`: sum of scheduled amounts with due_date <= reporting_date.
- `total_paid`: sum of eligible payment amounts with payment_date <= reporting_date.
- `arrears_amount = greatest(total_due - total_paid, 0)`.
- `total_scheduled`: sum of all installments, including future ones.
- `remaining_scheduled_amount = greatest(total_scheduled - total_paid, 0)`; this is not outstanding principal.
- `credit_balance = greatest(total_paid - total_scheduled, 0)`.
- Allocate payments FIFO against installments ordered by due_date, then installment_id. The oldest unpaid due installment is the first due installment whose cumulative scheduled amount exceeds total_paid by more than 0.01. `dpd` is days from that installment's due_date to reporting_date, floored at zero; zero when none exists. Thus an unpaid installment due today has DPD 0.
- `dpd7_flag = dpd >= 7`; `dpd30_flag = dpd >= 30`. Portfolio DPD rates use all agreements present that day as denominator, including fully paid agreements.
- Monetary output uses two decimals; comparisons allow 0.01 tolerance. Never round inputs to whole currency units.

## Deliverables
Submit a private repository or ZIP containing your dbt project, SQL, tests, generated sample output, run instructions, and a concise `DECISIONS.md`. Include exact dependency versions and whether execution was performed. Do not include credentials, account identifiers, or real customer data.

In `DECISIONS.md`, cover grain, latest-state versus point-in-time limitations, rejected records, join cardinality, proposed staging/intermediate/mart materializations, and how you would handle late data and incremental backfills. Explain who owns business definitions and how Analytics Engineering tests and publishes the approved mart for Power BI/Excel.

## Evaluation
SQL and metric correctness 35%; data quality and tests 25%; dbt architecture and documentation 20%; reproducibility 10%; production reasoning and communication 10%. A transparent partial submission is preferable to hidden assumptions. AI tools are allowed; disclose their use and be ready to explain your code.

## Optional stretch (no penalty for omission)
Propose an incremental strategy, a CI pipeline that builds in an isolated schema, access controls for certified marts, and freshness monitoring. Do not spend the core timebox provisioning infrastructure.

## Starter and setup
`starter/` contains configuration templates and empty model directories, not a solution. Copy data into your project's seeds folder. Configure the target schema yourself. The profile uses environment variables; never commit secrets. Install a mutually compatible, pinned dbt-core/dbt-snowflake pair, then run `dbt debug`, `dbt seed`, `dbt build`, and `dbt docs generate`. Record the actual versions and commands in your submission.

See `PUBLISHING.md` for repository/Pages publication instructions for the hiring team.
