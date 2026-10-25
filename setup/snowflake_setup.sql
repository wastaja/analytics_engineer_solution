-- One-off Snowflake setup for the dbt service user (key-pair auth).
-- Run in a worksheet as ACCOUNTADMIN. Replace the placeholder public key (no BEGIN/END lines).
-- Generate keys locally (outside the repo):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ~/.snowflake/dbt_service_key.p8 -nocrypt
--   openssl rsa -in ~/.snowflake/dbt_service_key.p8 -pubout -out ~/.snowflake/dbt_service_key.pub
use role accountadmin;

create role if not exists dbt_role;

create warehouse if not exists dbt_wh
  warehouse_size = 'XSMALL'
  auto_suspend = 60
  auto_resume = true
  initially_suspended = true;

create database if not exists ae_task;
create schema if not exists ae_task.dbt_dev;

grant usage, operate on warehouse dbt_wh to role dbt_role;
grant all on database ae_task to role dbt_role;
grant all on all schemas in database ae_task to role dbt_role;
grant all on future schemas in database ae_task to role dbt_role;

create user if not exists dbt_service
  type = service
  default_role = dbt_role
  default_warehouse = dbt_wh
  default_namespace = ae_task.dbt_dev
  rsa_public_key = '<PUBLIC_KEY>';

grant role dbt_role to user dbt_service;

-- Read-only role for consumers (Power BI / Excel): SELECT on the marts schema only.
-- No access to seeds, staging or intermediate. The marts schema is created by dbt
-- (<target schema>_marts); create it here only so the grants can be applied up front.
create role if not exists dbt_reader;
create schema if not exists ae_task.dbt_dev_marts;

grant usage on warehouse dbt_wh to role dbt_reader;
grant usage on database ae_task to role dbt_reader;
grant usage on schema ae_task.dbt_dev_marts to role dbt_reader;
grant select on all tables in schema ae_task.dbt_dev_marts to role dbt_reader;
grant select on future tables in schema ae_task.dbt_dev_marts to role dbt_reader;
