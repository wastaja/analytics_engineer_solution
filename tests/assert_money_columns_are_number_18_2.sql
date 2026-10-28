-- Precision check on the built marts: every money column must be NUMBER(18,2) in the warehouse.
-- Returns the columns with a different precision or scale.
{% set money_columns = {
    'fct_agreement_daily': ['total_due', 'total_paid', 'total_scheduled', 'arrears_amount', 'remaining_scheduled_amount', 'credit_balance']
    , 'mart_portfolio_daily': ['total_due', 'total_paid', 'arrears_amount', 'remaining_scheduled_amount', 'credit_balance']
} %}

{% for model_name, columns in money_columns.items() %}
select
    table_name
    , column_name
    , numeric_precision
    , numeric_scale
from {{ref(model_name).database}}.information_schema.columns
where table_schema = upper('{{ref(model_name).schema}}')
    and table_name = upper('{{ref(model_name).identifier}}')
    and column_name in ({% for c in columns %}'{{c | upper}}'{{ ', ' if not loop.last }}{% endfor %})
    and (numeric_precision <> 18 or numeric_scale <> 2)
{{ 'union all' if not loop.last }}
{% endfor %}
