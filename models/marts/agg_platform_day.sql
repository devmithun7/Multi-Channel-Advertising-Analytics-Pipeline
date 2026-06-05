{{ config(materialized='table') }}

-- MART: platform x day rollup. Ratio metrics are recomputed from summed
-- components (sum/sum), which is the correct way to aggregate rates -- never
-- average daily CTR/CPC/ROAS values.

with fct as (
    select * from {{ ref('fct_ad_performance') }}
),

rolled as (
    select
        platform_key,
        date_key,
        sum(impressions)        as impressions,
        sum(clicks)             as clicks,
        sum(spend)              as spend,
        sum(conversions)        as conversions,
        sum(conversion_value)   as conversion_value,
        sum(video_views)        as video_views,
        sum(video_watch_25)     as video_watch_25,
        sum(video_watch_100)    as video_watch_100,
        sum(social_engagements) as social_engagements
    from fct
    group by platform_key, date_key
)

select
    r.platform_key,
    r.date_key,
    p.platform,
    dd.full_date                                      as ad_date,
    impressions,
    clicks,
    spend,
    conversions,
    conversion_value,
    video_views,
    social_engagements,

    -- efficiency (ratios recomputed from summed components)
    {{ safe_divide('clicks', 'impressions') }}        as ctr,
    {{ safe_divide('spend', 'clicks') }}              as cpc,
    {{ safe_divide('spend', 'impressions') }} * 1000  as cpm,
    {{ safe_divide('conversions', 'clicks') }}        as cvr,
    {{ safe_divide('spend', 'conversions') }}         as cpa,
    {{ safe_divide('conversion_value', 'spend') }}    as roas,

    -- revenue efficiency (Google only)
    {{ safe_divide('conversion_value', 'conversions') }} as aov,
    {{ safe_divide('conversion_value', 'clicks') }}      as revenue_per_click,

    -- video / engagement
    {{ safe_divide('spend', 'video_views') }}            as cpv,
    {{ safe_divide('video_views', 'impressions') }}      as vtr,
    {{ safe_divide('video_watch_25', 'impressions') }}   as hook_rate,
    {{ safe_divide('video_watch_100', 'video_watch_25') }} as hold_rate,
    {{ safe_divide('video_watch_100', 'video_views') }}  as video_completion_rate,
    {{ safe_divide('social_engagements', 'impressions') }} as social_engagement_rate,

    -- budget allocation: this row's share of that day's total spend
    {{ safe_divide('spend', 'sum(spend) over (partition by r.date_key)') }} as spend_pct_of_day
from rolled r
join {{ ref('dim_platform') }} p on r.platform_key = p.platform_key
join {{ ref('dim_date') }} dd     on r.date_key = dd.date_key
