{{ config(materialized='table') }}

-- MART (agg): rollup per marketing objective (funnel stage) across all
-- platforms. Powers the "Spend by Objective" donut. Ratios pre-computed
-- (SUM/SUM); spend share is ready to plot directly.

with fct as (
    select * from {{ ref('fct_ad_performance') }}
),

dim as (
    select campaign_key, campaign_objective from {{ ref('dim_campaign') }}
),

joined as (
    select
        f.*,
        d.campaign_objective
    from fct f
    join dim d on f.campaign_key = d.campaign_key
),

rolled as (
    select
        campaign_objective,
        sum(impressions)        as impressions,
        sum(clicks)             as clicks,
        sum(spend)              as spend,
        sum(conversions)        as conversions,
        sum(conversion_value)   as conversion_value
    from joined
    group by campaign_objective
)

select
    campaign_objective,
    impressions,
    clicks,
    spend,
    conversions,
    conversion_value,
    {{ safe_divide('clicks', 'impressions') }}        as ctr,
    {{ safe_divide('spend', 'conversions') }}         as cpa,
    {{ safe_divide('conversion_value', 'spend') }}    as roas,
    {{ safe_divide('spend', 'sum(spend) over ()') }}  as spend_pct_of_total
from rolled
