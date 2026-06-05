{{ config(materialized='view') }}

-- STAGING: Facebook. Rename to conformed column names, cast types,
-- tag the platform. Facebook calls an ad group an "ad set".

with source as (
    select * from {{ ref('raw_facebook_ads') }}
),

renamed as (
    select
        cast('facebook' as varchar)        as platform,
        cast(date as date)                 as ad_date,

        cast(campaign_id as varchar)       as campaign_id,
        cast(campaign_name as varchar)     as campaign_name,
        cast(ad_set_id as varchar)         as ad_group_id,
        cast(ad_set_name as varchar)       as ad_group_name,

        cast(impressions as bigint)        as impressions,
        cast(clicks as bigint)             as clicks,
        cast(spend as double)              as spend,
        cast(conversions as bigint)        as conversions,

        -- Facebook-specific engagement metrics
        cast(video_views as bigint)        as video_views,
        cast(reach as bigint)              as reach,
        cast(frequency as double)          as frequency,
        cast(engagement_rate as double)    as engagement_rate
    from source
)

select * from renamed
