{#
    Normalizes a text column: trim, uppercase, and turn empty strings into NULL
    (blank source fields mean missing values).
#}
{% macro clean_text(column_name) %}
    nullif(upper(trim({{ column_name }})), '')
{% endmacro %}
