{{ config(materialized='view') }}

-- INTERMEDIATE: union the three platforms into one conformed schema.
-- Shared columns line up 1:1; platform-specific columns are filled with
-- typed NULLs on the platforms that do not report them. This is the single
-- source of truth that the marts build on.

with facebook as (
    select
        platform,
        ad_date,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        impressions,
        clicks,
        spend,
        conversions,
        cast(null as double)   as conversion_value,
        video_views,
        reach,
        frequency,
        engagement_rate,
        cast(null as bigint)   as video_watch_25,
        cast(null as bigint)   as video_watch_50,
        cast(null as bigint)   as video_watch_75,
        cast(null as bigint)   as video_watch_100,
        cast(null as bigint)   as likes,
        cast(null as bigint)   as shares,
        cast(null as bigint)   as comments,
        cast(null as bigint)   as quality_score,
        cast(null as double)   as search_impression_share
    from {{ ref('stg_facebook_ads') }}
),

google as (
    select
        platform,
        ad_date,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        impressions,
        clicks,
        spend,
        conversions,
        conversion_value,
        cast(null as bigint)   as video_views,
        cast(null as bigint)   as reach,
        cast(null as double)   as frequency,
        cast(null as double)   as engagement_rate,
        cast(null as bigint)   as video_watch_25,
        cast(null as bigint)   as video_watch_50,
        cast(null as bigint)   as video_watch_75,
        cast(null as bigint)   as video_watch_100,
        cast(null as bigint)   as likes,
        cast(null as bigint)   as shares,
        cast(null as bigint)   as comments,
        quality_score,
        search_impression_share
    from {{ ref('stg_google_ads') }}
),

tiktok as (
    select
        platform,
        ad_date,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        impressions,
        clicks,
        spend,
        conversions,
        cast(null as double)   as conversion_value,
        video_views,
        cast(null as bigint)   as reach,
        cast(null as double)   as frequency,
        cast(null as double)   as engagement_rate,
        video_watch_25,
        video_watch_50,
        video_watch_75,
        video_watch_100,
        likes,
        shares,
        comments,
        cast(null as bigint)   as quality_score,
        cast(null as double)   as search_impression_share
    from {{ ref('stg_tiktok_ads') }}
),

unioned as (
    select * from facebook
    union all
    select * from google
    union all
    select * from tiktok
)

select * from unioned
