{{ config(materialized='table') }}

-- MART: the unified daily ad-performance fact. One conformed row per
-- platform x date x campaign x ad group, enriched with the standard
-- cross-channel efficiency metrics computed consistently for every platform.
-- This is the "one big table" that powers the Tableau dashboard.

with unified as (
    select * from {{ ref('int_ads_unified') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'ad_date', 'campaign_id', 'ad_group_id']) }} as ad_performance_key,

    -- foreign keys to conformed dimensions (star schema)
    cast(to_char(ad_date, 'YYYYMMDD') as integer)               as date_key,
    {{ dbt_utils.generate_surrogate_key(['platform']) }}        as platform_key,
    {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }} as campaign_key,

    -- degenerate dimension (ad group has no dimension table of its own)
    ad_group_id,
    ad_group_name,

    -- core conformed metrics (present on every platform)
    impressions,
    clicks,
    spend,
    conversions,

    -- revenue (Google only; NULL elsewhere)
    conversion_value,

    -- derived efficiency metrics (consistent definitions across platforms)
    {{ safe_divide('clicks', 'impressions') }}                  as ctr,
    {{ safe_divide('spend', 'clicks') }}                        as cpc,
    {{ safe_divide('spend', 'impressions') }} * 1000            as cpm,
    {{ safe_divide('conversions', 'clicks') }}                  as cvr,
    {{ safe_divide('spend', 'conversions') }}                   as cpa,
    {{ safe_divide('conversion_value', 'spend') }}              as roas,

    -- revenue efficiency (Google only; NULL elsewhere)
    {{ safe_divide('conversion_value', 'conversions') }}        as aov,
    {{ safe_divide('conversion_value', 'clicks') }}             as revenue_per_click,

    -- video / creative metrics (video platforms; NULL where not reported)
    video_views,
    {{ safe_divide('spend', 'video_views') }}                   as cpv,
    {{ safe_divide('video_views', 'impressions') }}             as vtr,
    {{ safe_divide('video_watch_25', 'impressions') }}          as hook_rate,
    {{ safe_divide('video_watch_100', 'video_watch_25') }}      as hold_rate,
    {{ safe_divide('video_watch_25', 'video_views') }}          as video_watch_25_rate,
    {{ safe_divide('video_watch_50', 'video_views') }}          as video_watch_50_rate,
    {{ safe_divide('video_watch_75', 'video_views') }}          as video_watch_75_rate,
    {{ safe_divide('video_watch_100', 'video_views') }}         as video_completion_rate,

    -- engagement metrics (platform-specific, NULL where not reported)
    reach,
    frequency,
    engagement_rate,
    {{ safe_divide('coalesce(likes, 0) + coalesce(shares, 0) + coalesce(comments, 0)', 'impressions') }} as social_engagement_rate,
    video_watch_25,
    video_watch_50,
    video_watch_75,
    video_watch_100,
    likes,
    shares,
    comments,
    coalesce(likes, 0) + coalesce(shares, 0) + coalesce(comments, 0) as social_engagements,

    -- platform quality signals (Google only)
    quality_score,
    search_impression_share

from unified
