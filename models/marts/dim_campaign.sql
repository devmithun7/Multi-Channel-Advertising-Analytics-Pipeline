{{ config(materialized='table') }}

-- MART: one row per campaign. Adds a derived marketing objective inferred
-- from the campaign name (heuristic) so cross-platform campaigns can be
-- grouped by funnel stage in the dashboard.

with unified as (
    select * from {{ ref('int_ads_unified') }}
),

campaigns as (
    select
        platform,
        campaign_id,
        max(campaign_name)                  as campaign_name,
        count(distinct ad_group_id)         as ad_group_count,
        min(ad_date)                        as first_active_date,
        max(ad_date)                        as last_active_date,
        sum(spend)                          as total_spend,
        sum(conversions)                    as total_conversions
    from unified
    group by platform, campaign_id
)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }} as campaign_key,
    {{ dbt_utils.generate_surrogate_key(['platform']) }}                as platform_key,
    platform,
    campaign_id,
    campaign_name,
    case
        when lower(campaign_name) like '%retarget%'
          or lower(campaign_name) like '%remarket%'
          or lower(campaign_name) like '%conversion%'
          or lower(campaign_name) like '%shopping%'        then 'Conversion'
        when lower(campaign_name) like '%video%'
          or lower(campaign_name) like '%influencer%'
          or lower(campaign_name) like '%collab%'          then 'Engagement'
        when lower(campaign_name) like '%aware%'
          or lower(campaign_name) like '%brand%'           then 'Awareness'
        when lower(campaign_name) like '%traffic%'
          or lower(campaign_name) like '%search%'
          or lower(campaign_name) like '%generic%'
          or lower(campaign_name) like '%drive%'           then 'Traffic'
        else 'Other'
    end                                                    as campaign_objective,
    ad_group_count,
    first_active_date,
    last_active_date,
    total_spend,
    total_conversions
from campaigns
