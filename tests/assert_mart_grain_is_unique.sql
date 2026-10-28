-- mart_portfolio_daily must have one row per reporting date, country, product and currency.
-- Returns the combinations that appear more than once.
with
    mart_portfolio_daily as (
        select *
        from {{ref('mart_portfolio_daily')}}
    )

select
    reporting_date
    , country
    , product
    , currency
    , count(*) as row_count
from mart_portfolio_daily
group by reporting_date, country, product, currency
having count(*) > 1
