{{ config(materialized='table') }}

-- MART: campaign-level rollup across the full period, joined to the campaign
-- dimension for objective/funnel grouping. Ratio metrics use sum/sum.

with fct as (
    select * from {{ ref('fct_ad_performance') }}
),

dim as (
    select * from {{ ref('dim_campaign') }}
),

rolled as (
    select
        campaign_key,
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
    group by campaign_key
)

select
    r.campaign_key,
    d.platform_key,
    d.platform,
    d.campaign_id,
    d.campaign_name,
    d.campaign_objective,
    d.ad_group_count,
    r.impressions,
    r.clicks,
    r.spend,
    r.conversions,
    r.conversion_value,
    r.video_views,
    r.social_engagements,

    -- efficiency (ratios recomputed from summed components)
    {{ safe_divide('r.clicks', 'r.impressions') }}        as ctr,
    {{ safe_divide('r.spend', 'r.clicks') }}              as cpc,
    {{ safe_divide('r.spend', 'r.impressions') }} * 1000  as cpm,
    {{ safe_divide('r.conversions', 'r.clicks') }}        as cvr,
    {{ safe_divide('r.spend', 'r.conversions') }}         as cpa,
    {{ safe_divide('r.conversion_value', 'r.spend') }}    as roas,

    -- revenue efficiency (Google only)
    {{ safe_divide('r.conversion_value', 'r.conversions') }} as aov,
    {{ safe_divide('r.conversion_value', 'r.clicks') }}      as revenue_per_click,

    -- video / engagement
    {{ safe_divide('r.spend', 'r.video_views') }}            as cpv,
    {{ safe_divide('r.video_views', 'r.impressions') }}      as vtr,
    {{ safe_divide('r.video_watch_25', 'r.impressions') }}   as hook_rate,
    {{ safe_divide('r.video_watch_100', 'r.video_watch_25') }} as hold_rate,
    {{ safe_divide('r.video_watch_100', 'r.video_views') }}  as video_completion_rate,
    {{ safe_divide('r.social_engagements', 'r.impressions') }} as social_engagement_rate,

    -- budget allocation: this campaign's share of total spend across all campaigns
    {{ safe_divide('r.spend', 'sum(r.spend) over ()') }}     as spend_pct_of_total
from rolled r
join dim d on r.campaign_key = d.campaign_key
