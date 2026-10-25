select distinct
    try_to_date(reporting_date) as reporting_date
from {{ ref('reporting_dates') }}
