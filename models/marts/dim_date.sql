{{ config(materialized='table') }}

-- DIM: calendar dimension. One row per date present in the data, with the
-- usual date-part attributes so the fact can be sliced by week/weekend/etc.
-- without recomputing date math in the BI layer. date_key is a smart integer
-- key (YYYYMMDD) that the fact carries as its foreign key.

with dates as (
    select distinct ad_date from {{ ref('int_ads_unified') }}
)

select
    cast(to_char(ad_date, 'YYYYMMDD') as integer)                        as date_key,
    ad_date                                                              as full_date,
    year(ad_date)                                                        as year,
    quarter(ad_date)                                                     as quarter,
    month(ad_date)                                                       as month,
    monthname(ad_date)                                                   as month_name,
    weekofyear(ad_date)                                                  as week_of_year,
    dayofmonth(ad_date)                                                  as day_of_month,
    dayofweek(ad_date)                                                   as day_of_week,
    dayname(ad_date)                                                     as day_name,
    case when dayname(ad_date) in ('Sat', 'Sun') then true else false end as is_weekend
from dates
