{{ config(materialized='table') }}

-- DIM: advertising platform. One row per channel with descriptive attributes
-- used to group/segment the fact (e.g. search vs social, which channels carry
-- revenue). platform_key is the surrogate the fact joins on.

with platforms as (
    select distinct platform from {{ ref('int_ads_unified') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['platform']) }}  as platform_key,
    platform,
    case platform
        when 'google'   then 'Search'
        when 'facebook' then 'Social'
        when 'tiktok'   then 'Social'
    end                                                   as platform_category,
    case when platform in ('facebook', 'tiktok') then true else false end as is_video_platform,
    case when platform = 'google' then true else false end               as reports_revenue
from platforms
