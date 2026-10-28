# Decisions

Short record of the design choices behind the Credit Portfolio Mart. Run instructions and versions are in [README.md](README.md); metric definitions are the ones supplied in [docs/TASK.md](docs/TASK.md).

## Grain

| Model | Grain | Rows in this extract |
|---|---|---|
| `fct_agreement_daily` | one row per valid agreement and reporting date, from origination through 2026-06-30 | 60 agreements x 181 dates = 10,860 |
| `mart_portfolio_daily` | one row per reporting date, country, product and currency | 181 dates x 4 segments = 724 |

- The unique key of the fact is `agreement_date_key` (`agreement_id|YYYY-MM-DD`), built once in `int_agreement_dates` (the spine) and used to join every daily measure back one-to-one.
- Currency is part of the mart grain. No FX is supplied, so amounts in different currencies are never summed together.
- Balance measures (`arrears_amount`, `remaining_scheduled_amount`, `credit_balance`) are computed per agreement and then summed in the mart. They are not recomputed from summed totals, so an overpaid agreement never offsets another agreement's arrears.
- DPD rates use `agreement_count` as denominator: every agreement present on that date, including fully paid ones.

## Latest state versus point-in-time

The inputs are a latest-state extract (`updated_at` orders versions, it is not a change log). The mart is therefore **restated historical reporting**, as the task defines it:

- the latest schedule version is applied to every reporting date;
- the latest payment version is applied to every reporting date, so a latest `REVERSED` payment contributes zero everywhere;
- what the portfolio looked like *as it was known* on a past date cannot be reconstructed, and the numbers of a past date can change when the source is corrected.

If as-known-at-the-time reporting were needed, the source would have to provide history (or dbt snapshots would have to be taken from the first load on) and the daily facts would be versioned by load date.

## Duplicates and conflicting versions (staging)

Each staging model keeps one row per business key, chosen by the latest `updated_at`. Keys and text fields are normalized (`trim`/`upper`, empty string to NULL) and types are cast before ranking, so that ` a001` and `A001` are the same key.

- **Exact duplicates** (same key, same `updated_at`, same content, e.g. installment `A001-1`) collapse to one row.
- **Ties** on `updated_at` are broken by `row_hash`, an MD5 of all business columns (NULL-safe, because `concat_ws` returns NULL in Snowflake if any argument is NULL). The pick is therefore deterministic and does not depend on row order.
- **Conflicts** (same key and `updated_at`, different content) are flagged, not silently resolved. Each staging model exposes `is_conflicting_version`, true when the latest `updated_at` of a key has more than one distinct `row_hash`. The row kept is still the deterministic pick above, so metrics stay reproducible, but the key is marked for review. Conflicts among older, already superseded versions are irrelevant and not flagged.
- The flag is tested with severity `warn` (the build is not blocked in dev); before certifying the mart I would raise it to `error`. The data owner of the source system decides which version is correct. The raw extract contains no such conflicts, so the tests are green; the flag and tie-break logic are covered by dbt unit tests with mocked conflicting inputs (`models/staging/unit_tests.yml`).
- Flagged keys are listed in the quarantine model as informational rows (reason `CONFLICTING_VERSION`, `excluded_from_metrics = false`) while remaining in the metrics.
- Deduplication happens before any status filter, so a latest `REVERSED` payment overrides an earlier `POSTED` version of the same `payment_id`.

## Rejected records

All validation rules live in one model, `int_quarantine_records`. Every other model that needs "good" rows (`int_agreements_valid`, `int_schedule_valid`, `int_payments_eligible`) is defined as *staging rows that are not rejected there*, so the rules cannot drift apart.

| Reason | Applies to | Rule |
|---|---|---|
| `MISSING_REQUIRED_FIELD` | all | a key or a required field is NULL |
| `INVALID_DOMAIN_VALUE` | agreements | country, product or currency outside the accepted values |
| `COUNTRY_CURRENCY_MISMATCH` | agreements | KE must use KES and UG must use UGX |
| `ORPHAN_INSTALLMENT` | schedule | agreement unknown or itself rejected |
| `ORPHAN_PAYMENT` | payments | agreement unknown or itself rejected |
| `INVALID_STATUS` | payments | status outside POSTED / PENDING / REVERSED |
| `NON_POSITIVE_AMOUNT` | schedule, payments | amount <= 0 |
| `CONFLICTING_VERSION` | all | informational only, row stays in the metrics |

- A rejected agreement orphans its installments and payments automatically, because children are validated against the *valid* agreements.
- `PENDING` and `REVERSED` payments are valid data that is simply not eligible. They are not quarantined; they are reported as `STATUS_EXCLUDED`.
- `dq_excluded_summary` reports excluded record counts and amounts per source table, reason and currency. A row whose agreement is unknown has no determinable currency and is reported as `UNKNOWN`.
- In this extract: 1 quarantined row (orphan payment `P-BAD`, 20.25, currency `UNKNOWN`) and 2 status-excluded payments (`P-PENDING` 500.25 KES, `P-REVERSE` 250.50 KES). The payment `P-FUTURE` (dated 2026-07-01) is valid and eligible, but it falls after the last reporting date and so never enters a daily total.
- Nothing is dropped silently: a singular test checks that eligible payments plus the excluded ones reconcile, by count and amount, to `stg_payments`.

## Join cardinality

No amount is ever multiplied by a join. The rules used:

- Every daily measure is aggregated to the spine grain **on its own** and joined back to the spine one-to-one on `agreement_date_key` (`int_agreement_daily_amounts`, `int_agreement_daily_dpd`, `fct_agreement_daily`). The fact is joined with `left join`, so a missing match would surface as NULL and fail `not_null` instead of silently shrinking the table.
- Payments are summed to agreement and day *before* the range join (`payment_date <= reporting_date`), so a payment cannot be counted twice for a date.
- The FIFO join (installments whose cumulative amount is not covered) is one-to-many by design, but only `min(due_date)` is taken from it and no amount is summed.
- Validity checks use `NOT EXISTS`, which cannot add rows.
- Tests: `assert_fct_grain_matches_spine` (the fact has exactly the rows of the spine), `assert_mart_grain_is_unique`, `assert_mart_reconciles_to_fct` (every mart measure equals the sum from the fact), and reconciliation of the last-date totals to the sources.

## Money, tolerance and edge cases

- Money is `NUMBER(18,2)` from staging to the marts; inputs are never rounded to whole units. A test reads `information_schema` and fails if any money column of the marts has a different precision or scale.
- The 0.01 tolerance is applied only where the business definition asks for it: the FIFO test of whether an installment is covered (`cumulative scheduled > total_paid + 0.01`). Everything else is exact. Reconciliation tests compare with `<>` and not with a tolerance, because fixed-point sums have no rounding noise and a tolerance would hide a one-cent error.
- DPD rates are rounded to 4 decimals (`NUMBER(9,4)`).
- Numerical edge cases covered by unit tests with hand-computed expectations: 999.99 covers an installment and 999.98 does not; an installment due today has DPD 0; DPD 6/7 and 29/30 flag boundaries; exactly paid, overpaid and partially paid agreements; several payments on one day; a payment after the window; an agreement without payments; zero, negative and missing amounts; the smallest positive amount (0.01); 1/3 and 2/3 rate rounding; small decimals (0.10 + 0.20 + 0.01) summed exactly.

## Schemas and access

Each dbt layer is built into its own schema; only the marts schema is meant for consumers.

| Layer | Materialization | Schema (dev) | Access |
|---|---|---|---|
| seeds (raw) | table | `DBT_DEV` | dbt role only |
| staging | view | `DBT_DEV_STAGING` | dbt role only |
| intermediate | view | `DBT_DEV_INTERMEDIATE` | dbt role only |
| marts | table | `DBT_DEV_MARTS` | dbt role, plus a read-only role |

- Layer schemas are set with `+schema` in `dbt_project.yml`. With dbt's default `generate_schema_name`, the layer name is appended to the target schema, so dev and CI builds stay isolated from production.
- In production I would override `generate_schema_name` so schemas are named `STAGING`, `INTERMEDIATE` and `MARTS` without the target prefix. This is not implemented here.
- Power BI and Excel read the marts through a `DBT_READER` role that has `SELECT` on the marts schema only (including future tables) and no access to raw, staging or intermediate data. The role is created in `setup/snowflake_setup.sql`; no consumer users are provisioned in this exercise.
- dbt connects as a Snowflake service user with key-pair authentication, so no password is stored anywhere; the private key stays outside the repository.

## Materializations

| Layer | Used here | Why, and what I would change at scale |
|---|---|---|
| staging | view | Cheap, always reflects the latest seeds. Heavy windowing on a large raw table would justify a table or an incremental model. |
| intermediate | view | Small data, and views keep the logic inspectable. At scale `int_agreement_daily_amounts` and `int_agreement_daily_dpd` (agreements x dates) would become incremental tables. |
| marts | table | Consumers should never trigger the computation; a table gives stable performance and a clean permission boundary. |

Alternative noted for scale: `total_paid` could be computed with a window function over a payments-by-day calendar instead of the range join; at 10,860 rows the range join is simpler to read and verify.

## Late data and incremental backfills

Not implemented; this is the strategy I would follow.

- Metrics are cumulative, so a late or corrected record changes **every later date of its agreement**, not just one date. A date-based incremental filter ("process only new dates") would therefore be wrong.
- Incremental unit: the **agreement**. Each run finds agreements with a source `updated_at` newer than the last run, and rebuilds all their dates from the earliest affected `payment_date` / `due_date` onward (`incremental_strategy: delete+insert` or `merge`, `unique_key = agreement_date_key`). A schedule change affects all dates of the agreement, so the agreement is rebuilt in full. New reporting dates are appended for every agreement.
- The mart is cheap to aggregate; it can be rebuilt for the affected dates or fully.
- A change of a metric definition or a backfill of history is a `--full-refresh` of the facts, run in a staging schema and compared with the published mart before it replaces it.
- Because the reporting is restated, a late payment changes already published history. Consumers must be told this explicitly; if the business needs frozen history, published daily snapshots would be stored separately.
- Monitoring: source freshness on `updated_at`, and an alert when `dq_excluded_summary` grows or a new reason appears.

## Ownership and certification

| Concern | Owner |
|---|---|
| Business definitions (due, paid, arrears, remaining scheduled, credit balance, FIFO, DPD, tolerance, denominators) | Credit Risk, as business definitions owner. Any change is a pull request they approve. |
| Correctness of source data; deciding the right version of a conflicting record and what to do with quarantined rows | Owner of the source (loan servicing) system |
| Implementation, tests, documentation, deployment, access control | Analytics Engineering |
| Dashboards and workbooks | Consumers. They read the marts and do not re-implement logic in Power BI or Excel. |

Certification gate for the mart (the models carry `meta.certification: candidate` until it is passed):

1. Change goes through a pull request; CI builds everything into an isolated schema with `dbt build` (unit tests, data tests, singular tests).
2. The conflicting-version test is raised from `warn` to `error`.
3. `dq_excluded_summary` is reviewed: every excluded count and amount is explained, and nothing unexpected appeared.
4. The business definitions owner approves any definition change; the reviewer confirms documentation and lineage (`dbt docs generate`) are updated.
5. After merge, a scheduled production job builds the marts into the `MARTS` schema; `meta.certification` becomes `certified`; Power BI and Excel connect only to that schema through the read-only role. Breaking changes to columns are announced and versioned.

This submission is a **candidate**, not a certified dataset: CI, production schemas, a scheduled job and the conflict test at `error` are not set up.

## Unfinished work and known limitations

- No CI pipeline, production schema override, incremental models, freshness monitoring or model contracts; they are described above, not built.
- Execution was against a Snowflake trial account only. No other adapter was used, so there are no dialect differences to document, but some syntax is Snowflake-specific (`try_to_number`, `count_if`, `select * exclude`, `is distinct from`).
- Correctness rests on hand-computed unit tests, reconciliation tests and invariants. There is no independent recomputation of the whole pipeline outside dbt.
- The extract contains no same-timestamp conflicts and only one quarantined row; the other rules are exercised by unit tests with mocked data, not by the real data.

## AI use

I used an AI assistant (Claude Code, Anthropic) during this exercise for design discussion, drafting and reviewing SQL, tests and documentation. I reviewed the code and ran it against Snowflake myself, and I can explain every model and test. The final decisions in this document are mine.
