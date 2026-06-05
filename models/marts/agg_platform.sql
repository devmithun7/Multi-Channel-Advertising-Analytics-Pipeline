{{ config(materialized='table') }}

-- MART (agg): full-period rollup per platform (3 rows). Powers the platform
-- comparison bars and the CPA-vs-CTR scatter. All ratios are pre-computed
-- (SUM/SUM) so no calculated fields are needed in the BI layer.

with fct as (
    select * from {{ ref('fct_ad_performance') }}
),

rolled as (
    select
        platform_key,
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
    group by platform_key
)

select
    r.platform_key,
    p.platform,
    p.platform_category,
    p.is_video_platform,
    p.reports_revenue,
    r.impressions,
    r.clicks,
    r.spend,
    r.conversions,
    r.conversion_value,
    r.video_views,
    r.social_engagements,

    -- efficiency (SUM/SUM)
    {{ safe_divide('r.clicks', 'r.impressions') }}        as ctr,
    {{ safe_divide('r.spend', 'r.clicks') }}              as cpc,
    {{ safe_divide('r.spend', 'r.impressions') }} * 1000  as cpm,
    {{ safe_divide('r.conversions', 'r.clicks') }}        as cvr,
    {{ safe_divide('r.spend', 'r.conversions') }}         as cpa,
    {{ safe_divide('r.conversion_value', 'r.spend') }}    as roas,
    {{ safe_divide('r.conversion_value', 'r.conversions') }} as aov,

    -- video / engagement
    {{ safe_divide('r.spend', 'r.video_views') }}            as cpv,
    {{ safe_divide('r.video_views', 'r.impressions') }}      as vtr,
    {{ safe_divide('r.video_watch_25', 'r.impressions') }}   as hook_rate,
    {{ safe_divide('r.video_watch_100', 'r.video_watch_25') }} as hold_rate,
    {{ safe_divide('r.video_watch_100', 'r.video_views') }}  as video_completion_rate,
    {{ safe_divide('r.social_engagements', 'r.impressions') }} as social_engagement_rate,

    -- budget allocation: this platform's share of total spend
    {{ safe_divide('r.spend', 'sum(r.spend) over ()') }}     as spend_pct_of_total
from rolled r
join {{ ref('dim_platform') }} p
    on r.platform_key = p.platform_key
