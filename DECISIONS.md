# Decisions

## Duplicates and conflicting versions (staging)

Each staging model keeps one row per business key, chosen by the latest `updated_at`. Keys and text fields are normalized (`trim`/`upper`, empty string to NULL) and types are cast before ranking, so that ` a001` and `A001` are the same key.

- **Exact duplicates** (same key, same `updated_at`, same content, e.g. installment `A001-1`) collapse to one row.
- **Ties** on `updated_at` are broken by `row_hash`, an MD5 of all business columns (NULL-safe, because `concat_ws` returns NULL in Snowflake if any argument is NULL). The pick is therefore deterministic and does not depend on row order.
- **Conflicts** (same key and `updated_at`, different content) are flagged, not silently resolved. Each staging model exposes `is_conflicting_version`, true when the latest `updated_at` of a key has more than one distinct `row_hash`. The row kept is still the deterministic pick above, so metrics stay reproducible, but the key is marked for review. Conflicts among older, already superseded versions are irrelevant and not flagged.
- The flag is tested with severity `warn` (the build is not blocked in dev); before certifying the mart I would raise it to `error`. The data owner of the source system decides which version is correct. The raw extract contains no such conflicts, so the tests are green; the flag and tie-break logic are covered by dbt unit tests with mocked conflicting inputs (`models/staging/unit_tests.yml`).
- Flagged keys are meant to be listed in the quarantine model as informational rows (reason `CONFLICTING_VERSION`) while remaining in the metrics.
- Deduplication happens before any status filter, so a latest `REVERSED` payment overrides an earlier `POSTED` version of the same `payment_id`.

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
