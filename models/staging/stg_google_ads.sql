{{ config(materialized='view') }}

-- STAGING: Google. Rename to conformed names, cast types, tag platform.
-- Google reports spend as "cost" and is the only source with revenue
-- (conversion_value).

with source as (
    select * from {{ ref('raw_google_ads') }}
),

renamed as (
    select
        cast('google' as varchar)              as platform,
        cast(date as date)                     as ad_date,

        cast(campaign_id as varchar)           as campaign_id,
        cast(campaign_name as varchar)         as campaign_name,
        cast(ad_group_id as varchar)           as ad_group_id,
        cast(ad_group_name as varchar)         as ad_group_name,

        cast(impressions as bigint)            as impressions,
        cast(clicks as bigint)                 as clicks,
        cast(cost as double)                   as spend,
        cast(conversions as bigint)            as conversions,

        -- Google-specific metrics
        cast(conversion_value as double)       as conversion_value,
        cast(quality_score as bigint)          as quality_score,
        cast(search_impression_share as double) as search_impression_share
    from source
)

select * from renamed
