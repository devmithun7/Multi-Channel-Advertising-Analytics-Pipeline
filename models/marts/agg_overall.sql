{{ config(materialized='table') }}

-- MART (agg): single-row KPI summary for the dashboard scorecards. Every
-- headline number is pre-computed here so the BI layer needs no calculated
-- fields -- just drop the column on a tile. Blended ratios use SUM/SUM.

with fct as (
    select * from {{ ref('fct_ad_performance') }}
),

joined as (
    select
        f.*,
        p.platform
    from fct f
    join {{ ref('dim_platform') }} p
        on f.platform_key = p.platform_key
)

select
    sum(spend)                                                  as total_spend,
    sum(conversions)                                            as total_conversions,
    sum(impressions)                                            as total_impressions,
    sum(clicks)                                                 as total_clicks,
    sum(conversion_value)                                       as total_revenue,
    {{ safe_divide('sum(spend)', 'sum(conversions)') }}         as blended_cpa,
    {{ safe_divide('sum(clicks)', 'sum(impressions)') }}        as blended_ctr,
    {{ safe_divide('sum(spend)', 'sum(clicks)') }}              as blended_cpc,
    {{ safe_divide("sum(case when platform = 'google' then conversion_value else 0 end)",
                   "sum(case when platform = 'google' then spend else 0 end)") }} as google_roas,
    {{ safe_divide('sum(conversion_value)', 'sum(spend)') }}    as blended_roas
from joined
