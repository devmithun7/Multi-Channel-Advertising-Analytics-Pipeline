{{ config(materialized='view') }}

-- STAGING: TikTok. Rename to conformed names, cast types, tag platform.
-- TikTok reports spend as "cost" and carries rich video + social engagement.

with source as (
    select * from {{ ref('raw_tiktok_ads') }}
),

renamed as (
    select
        cast('tiktok' as varchar)          as platform,
        cast(date as date)                 as ad_date,

        cast(campaign_id as varchar)       as campaign_id,
        cast(campaign_name as varchar)     as campaign_name,
        cast(adgroup_id as varchar)        as ad_group_id,
        cast(adgroup_name as varchar)      as ad_group_name,

        cast(impressions as bigint)        as impressions,
        cast(clicks as bigint)             as clicks,
        cast(cost as double)               as spend,
        cast(conversions as bigint)        as conversions,

        -- TikTok-specific video + social engagement metrics
        cast(video_views as bigint)        as video_views,
        cast(video_watch_25 as bigint)     as video_watch_25,
        cast(video_watch_50 as bigint)     as video_watch_50,
        cast(video_watch_75 as bigint)     as video_watch_75,
        cast(video_watch_100 as bigint)    as video_watch_100,
        cast(likes as bigint)              as likes,
        cast(shares as bigint)             as shares,
        cast(comments as bigint)           as comments
    from source
)

select * from renamed
