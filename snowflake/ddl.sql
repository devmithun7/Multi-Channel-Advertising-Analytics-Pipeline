-- =====================================================================
-- Multi-Channel Advertising Analytics — Snowflake DDL (setup + RAW only)
-- =====================================================================
-- This script provisions Snowflake STRUCTURE and lands the raw CSVs:
--
--   1. Creates the warehouse and database.
--   2. Creates the schemas for every pipeline layer
--      (raw / staging / intermediate / marts).
--   3. Creates the three RAW landing tables (one per source platform),
--      with columns matching each CSV header exactly.
--   4. Loads the 3 CSVs into RAW via a file format + stage + COPY INTO.
--
-- It deliberately STOPS at the raw layer. All transformations — the
-- conformed staging views, the UNION into one model, and the marts with
-- their calculated metrics (CTR / CPC / CPM / CVR / CPA / ROAS) — are
-- owned by dbt, so the business logic lives in exactly one place:
--
--   uv run dbt run --profiles-dir .
--
-- (dbt builds staging -> intermediate -> marts on top of these RAW tables
--  and into the staging/intermediate/marts schemas created below.)
-- =====================================================================


-- =====================================================================
-- 1. Warehouse + database
-- =====================================================================
create warehouse if not exists compute_wh
    with warehouse_size = 'xsmall'
         auto_suspend = 60
         auto_resume = true
         initially_suspended = true;

create database if not exists multichannel_ads;

use database multichannel_ads;
use warehouse compute_wh;


-- =====================================================================
-- 2. Schemas — one per pipeline layer (dbt materializes into these)
-- =====================================================================
create schema if not exists raw;           -- source CSVs, landed unchanged
create schema if not exists staging;        -- dbt: renamed/cast, one view per source
create schema if not exists intermediate;   -- dbt: conformed UNION ALL
create schema if not exists marts;          -- dbt: business-ready fact/dim/aggregates


-- =====================================================================
-- 3. RAW landing tables — columns match each source CSV header exactly
-- =====================================================================

-- 01_facebook_ads.csv
create or replace table raw.raw_facebook_ads (
    date            date,
    campaign_id     varchar,
    campaign_name   varchar,
    ad_set_id       varchar,
    ad_set_name     varchar,
    impressions     number(38,0),
    clicks          number(38,0),
    spend           number(18,4),
    conversions     number(38,0),
    video_views     number(38,0),
    engagement_rate float,
    reach           number(38,0),
    frequency       float
);

-- 02_google_ads.csv
create or replace table raw.raw_google_ads (
    date                    date,
    campaign_id             varchar,
    campaign_name           varchar,
    ad_group_id             varchar,
    ad_group_name           varchar,
    impressions             number(38,0),
    clicks                  number(38,0),
    cost                    number(18,4),
    conversions             number(38,0),
    conversion_value        number(18,4),
    ctr                     float,
    avg_cpc                 float,
    quality_score           number(38,0),
    search_impression_share float
);

-- 03_tiktok_ads.csv
create or replace table raw.raw_tiktok_ads (
    date            date,
    campaign_id     varchar,
    campaign_name   varchar,
    adgroup_id      varchar,
    adgroup_name    varchar,
    impressions     number(38,0),
    clicks          number(38,0),
    cost            number(18,4),
    conversions     number(38,0),
    video_views     number(38,0),
    video_watch_25  number(38,0),
    video_watch_50  number(38,0),
    video_watch_75  number(38,0),
    video_watch_100 number(38,0),
    likes           number(38,0),
    shares          number(38,0),
    comments        number(38,0)
);


-- =====================================================================
-- 4. Load the CSVs into RAW
-- =====================================================================
-- A CSV file format that skips the header row and treats empty strings as NULL.
create or replace file format raw.ff_csv
    type = 'csv'
    field_delimiter = ','
    skip_header = 1
    field_optionally_enclosed_by = '"'
    null_if = ('', 'NULL', 'null')
    empty_field_as_null = true;

-- Internal stage to upload the local CSV files to.
create stage if not exists raw.ads_stage file_format = raw.ff_csv;

-- ---------------------------------------------------------------------
-- Upload the files from your machine to the stage. PUT is a SnowSQL /
-- driver command (it does NOT run in the Snowsight worksheet UI). From a
-- terminal with SnowSQL configured, run:
--
--   snowsql -q "PUT file://seeds/raw_facebook_ads.csv @multichannel_ads.raw.ads_stage AUTO_COMPRESS=TRUE"
--   snowsql -q "PUT file://seeds/raw_google_ads.csv   @multichannel_ads.raw.ads_stage AUTO_COMPRESS=TRUE"
--   snowsql -q "PUT file://seeds/raw_tiktok_ads.csv   @multichannel_ads.raw.ads_stage AUTO_COMPRESS=TRUE"
--
-- (In Snowsight you can instead use Data > Add Data > Load files into a
--  stage, then run the COPY INTO statements below.)
-- ---------------------------------------------------------------------

copy into raw.raw_facebook_ads
    from @raw.ads_stage/raw_facebook_ads.csv
    file_format = raw.ff_csv
    on_error = 'abort_statement';

copy into raw.raw_google_ads
    from @raw.ads_stage/raw_google_ads.csv
    file_format = raw.ff_csv
    on_error = 'abort_statement';

copy into raw.raw_tiktok_ads
    from @raw.ads_stage/raw_tiktok_ads.csv
    file_format = raw.ff_csv
    on_error = 'abort_statement';


-- =====================================================================
-- 5. Validate the raw load (optional)
-- =====================================================================
-- select count(*) from raw.raw_facebook_ads;   -- expect 110
-- select count(*) from raw.raw_google_ads;     -- expect 110
-- select count(*) from raw.raw_tiktok_ads;     -- expect 110

-- Next: build staging -> intermediate -> marts with dbt:
--   uv run dbt run  --profiles-dir .
--   uv run dbt test --profiles-dir .
