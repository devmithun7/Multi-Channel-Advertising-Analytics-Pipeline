# Multi-Channel Advertising Analytics Pipeline

> Unify raw advertising data from **Facebook**, **Google Ads**, and **TikTok** into a single, tested, dimensional data model on **Snowflake** — transformed with **dbt** and visualized in a one-page **Tableau** dashboard built for real marketing decisions.

**Tech stack:** Snowflake · dbt (dbt-snowflake) · dbt_utils · Python (uv) · Tableau Public

**🔗 Live dashboard:** [View on Tableau Public](https://public.tableau.com/app/profile/dev.mithunisvar/viz/MarketingAnalytics_17806394670810/Dashboard1)

---

## Table of contents
1. [What this project does](#1-what-this-project-does)
2. [Architecture](#2-architecture)
3. [The unified data model (star schema)](#3-the-unified-data-model-star-schema)
4. [KPIs & feature engineering](#4-kpis--feature-engineering)
5. [Data quality & testing](#5-data-quality--testing)
6. [Repository structure](#6-repository-structure)
7. [Quickstart — run it yourself](#7-quickstart--run-it-yourself)
8. [The Tableau dashboard](#8-the-tableau-dashboard)
9. [Headline insights](#9-headline-insights)
10. [Documentation & deliverables](#10-documentation--deliverables)

---

## 1. What this project does

Every ad platform reports differently — Facebook talks in *reach* and *frequency*,
TikTok in *video views* and *social engagement*, Google in *revenue* and *quality
score* — with different column names, metric definitions, and currencies for
"spend." This project **conforms all three into one trustworthy model** so they can
be compared apples-to-apples, then surfaces the result as an executive dashboard.

The pipeline:

1. **Lands** the three raw CSVs in Snowflake, untouched.
2. **Cleans & standardizes** each source (rename, cast, tag platform) in dbt staging.
3. **Unifies** them into one conformed table via `UNION ALL`, with honest typed `NULL`s where a platform doesn't report a metric.
4. **Models** a star schema (one fact + three dimensions) and pre-aggregated rollups.
5. **Tests** every layer with 100+ automated checks, including real business rules.
6. **Exports** the marts to CSV for a one-page Tableau dashboard.

---

## 2. Architecture

```
   Raw CSVs                 dbt on Snowflake                              BI
 ┌───────────┐      ┌───────────────────────────────────────────┐   ┌────────────┐
 │ 01_fb.csv │─┐    │  RAW            landed as-is              │   │  Tableau   │
 │ 02_goog.. │─┼──► │   raw_facebook_ads / raw_google_ads /     │   │  Public    │
 │ 03_tik..  │─┘    │   raw_tiktok_ads                          │   │ (1-page    │
 └───────────┘      │                                           │   │  dashboard)│
                    │  STAGING        rename, cast, +platform   │   └─────▲──────┘
                    │   stg_facebook_ads / stg_google_ads /     │         │
                    │   stg_tiktok_ads                          │   exports/*.csv
                    │                                           │         │
                    │  INTERMEDIATE   conform + UNION ALL       │         │
                    │   int_ads_unified                         │─────────┘
                    │                                           │
                    │  MARTS          star schema + aggregates  │
                    │   fct_ad_performance  (the unified table) │
                    │   dim_date / dim_platform / dim_campaign  │
                    │   agg_overall / agg_platform /            │
                    │   agg_platform_day / agg_campaign /       │
                    │   agg_objective                           │
                    └───────────────────────────────────────────┘
```

**Why these layers**

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| Raw | `raw` | table | Land the 3 source files unchanged — an auditable source of truth. |
| Staging | `staging` | view | One model per source: rename to conformed columns, cast types, add `platform`, standardize `cost` → `spend`. No business logic. |
| Intermediate | `intermediate` | view | `UNION ALL` the three platforms into one schema; fill platform-specific metrics with typed `NULL`s. |
| Marts | `marts` | table | Business-ready star schema with all derived KPIs, conformed dimensions, and pre-aggregated rollups. |

---

## 3. The unified data model (star schema)

The marts form a **star schema**: one base fact surrounded by three conformed
dimensions, plus a set of aggregate (rollup) facts that power the dashboard tiles.

```
                 dim_date              dim_platform
                      \                   /
                       \                 /
                        fct_ad_performance ───── dim_campaign
                       (grain: platform × date × campaign × ad group)
                                 │
        ┌──────────────┬─────────┼──────────┬───────────────┐
   agg_overall    agg_platform  agg_platform_day  agg_campaign  agg_objective
   (1-row KPIs)   (per channel) (channel × day)   (per campaign)(per objective)
```

`fct_ad_performance` is the **unified table** the assignment asks for. It carries
**surrogate foreign keys** to the dimensions rather than denormalized attributes.

### Fact — `fct_ad_performance`
Grain: one row per **platform × date × campaign × ad group**, per day.

| Group | Columns |
|-------|---------|
| Surrogate key | `ad_performance_key` |
| Foreign keys | `date_key` → `dim_date`, `platform_key` → `dim_platform`, `campaign_key` → `dim_campaign` |
| Degenerate dim | `ad_group_id`, `ad_group_name` |
| Core measures (all platforms) | `impressions`, `clicks`, `spend`, `conversions` |
| Revenue *(Google only)* | `conversion_value` |
| Derived efficiency | `ctr`, `cpc`, `cpm`, `cvr`, `cpa`, `roas` |
| Revenue efficiency *(Google)* | `aov`, `revenue_per_click` |
| Video / creative *(TikTok)* | `cpv`, `vtr`, `hook_rate`, `hold_rate`, `video_watch_25/50/75_rate`, `video_completion_rate` |
| Engagement | `reach`, `frequency`, `engagement_rate`, `social_engagement_rate`, `video_views`, `video_watch_25/50/75/100`, `likes`, `shares`, `comments`, `social_engagements` |
| Quality *(Google)* | `quality_score`, `search_impression_share` |

### Dimensions
| Dim | Key | Notable attributes |
|---|---|---|
| `dim_date` | `date_key` (YYYYMMDD) | `full_date`, `year`, `quarter`, `month`, `month_name`, `week_of_year`, `day_of_week`, `day_name`, `is_weekend` |
| `dim_platform` | `platform_key` | `platform`, `platform_category` (Search/Social), `is_video_platform`, `reports_revenue` |
| `dim_campaign` | `campaign_key` | `platform_key`, `platform`, `campaign_id`, `campaign_name`, `campaign_objective` (funnel stage), `ad_group_count`, active-date span |

### Aggregate facts (pre-computed for the BI layer)
| Table | Grain | Built for |
|---|---|---|
| `agg_overall` | 1 row (whole account) | KPI scorecards — `total_spend`, `total_conversions`, `total_revenue`, `blended_cpa`, `blended_ctr/cpc/roas`, `google_roas` |
| `agg_platform` | per platform | Platform comparison bars + CPA-vs-CTR scatter |
| `agg_platform_day` | platform × day | Daily spend trend line |
| `agg_campaign` | per campaign | Campaign highlight table |
| `agg_objective` | per objective | Spend-by-objective donut |

All ratio metrics in the aggregates are recomputed as `SUM(numerator) / SUM(denominator)`
at the table's grain (never averaged from per-row ratios), and carry a
**budget-allocation share** (`spend_pct_of_total` / `spend_pct_of_day`).

### Column mapping across sources
| Concept | Facebook | Google | TikTok | Unified |
|---|---|---|---|---|
| ad group id | `ad_set_id` | `ad_group_id` | `adgroup_id` | `ad_group_id` |
| spend | `spend` | `cost` | `cost` | `spend` |
| revenue | — | `conversion_value` | — | `conversion_value` |

---

## 4. KPIs & feature engineering

All ratios are defined **once, consistently, for every platform**, using a NULL-safe
`safe_divide` macro (returns `NULL` instead of erroring on a zero/NULL denominator).

| KPI | Formula | Notes |
|---|---|---|
| CTR | `clicks / impressions` | All platforms |
| CPC | `spend / clicks` | All platforms |
| CPM | `spend / impressions × 1000` | All platforms |
| CVR | `conversions / clicks` | All platforms |
| CPA | `spend / conversions` | All platforms |
| ROAS | `conversion_value / spend` | Google only |
| AOV | `conversion_value / conversions` | Google only |
| Revenue per click | `conversion_value / clicks` | Google only |
| CPV | `spend / video_views` | TikTok |
| VTR | `video_views / impressions` | TikTok |
| Hook rate | `video_watch_25 / impressions` | Creative hook strength |
| Hold rate | `video_watch_100 / video_watch_25` | Retention |
| Video completion rate | `video_watch_100 / video_views` | TikTok |
| Social engagement rate | `(likes + shares + comments) / impressions` | Conformed |
| Blended CPA / CTR / CPC / ROAS | `SUM(x) / SUM(y)` | Account-wide (in `agg_overall`) |

> A full data dictionary of every metric — definition, formula, source columns,
> and platform availability — is generated to **`KPI_Metadata.xlsx`** by
> `build_metadata.py`.

---

## 5. Data quality & testing

Trust is enforced with **100+ automated dbt tests** that run on every build
(`dbt build` reports 111 data tests). Categories:

- **Grain uniqueness** — `unique_combination_of_columns` at staging, intermediate, and the fact grain (no duplicate platform × date × campaign × ad group).
- **Not-null** — keys and core measures.
- **Accepted values** — `platform` ∈ {facebook, google, tiktok}; `campaign_objective` ∈ {Awareness, Traffic, Conversion, Engagement, Other}.
- **Accepted ranges** — spend/counts ≥ 0; rates ∈ [0, 1]; `quality_score` ∈ [1, 10].
- **Referential integrity** — every fact foreign key has a `relationships` test to its dimension.
- **Business-rule tests** (`expression_is_true`) — the data must obey real advertising logic:
  - `clicks ≤ impressions`
  - `conversions ≤ clicks`
  - `video_views ≤ impressions` and `reach ≤ impressions`
  - `video_watch_25 ≤ video_views`
  - video quartiles decrease monotonically: `25% ≥ 50% ≥ 75% ≥ 100%`

If any check fails, the build fails — so every number on the dashboard is validated
before it's ever exported.

---

## 6. Repository structure

```
multichannel-ads-pipeline/
├── pyproject.toml            # uv-managed deps (dbt-snowflake, snowflake-connector, pandas)
├── uv.lock                   # pinned, reproducible lockfile
├── .python-version           # Python 3.12
├── dbt_project.yml           # project config + per-layer materializations/schemas
├── packages.yml              # dbt_utils
├── profiles.yml              # Snowflake target
├── load-env.ps1              # load .env Snowflake creds into the shell
├── snowflake/
│   ├── ddl.sql               # warehouse/db/schemas + RAW tables + CSV load
│   └── setup_objects.py      # one-time warehouse/db bootstrap
├── seeds/                    # RAW layer: the 3 source CSVs + tests
│   ├── raw_facebook_ads.csv
│   ├── raw_google_ads.csv
│   ├── raw_tiktok_ads.csv
│   └── _seeds.yml
├── models/
│   ├── staging/              # stg_facebook/google/tiktok_ads.sql + _staging.yml
│   ├── intermediate/         # int_ads_unified.sql + _intermediate.yml
│   └── marts/                # fct_, dim_, agg_*.sql + _marts.yml
├── macros/                   # generate_schema_name, safe_divide
├── export_marts.py           # dump marts -> exports/*.csv for Tableau
├── build_metadata.py         # generate KPI_Metadata.xlsx data dictionary
├── exports/                  # Tableau-ready CSVs (generated)
├── KPI_Metadata.xlsx         # KPI data dictionary (generated)
├── DASHBOARD_TEMPLATE.md     # exact build spec for the Tableau dashboard
└── VIDEO_SCRIPT.md           # narration script for the walkthrough video
```

---

## 7. Quickstart — run it yourself

### Prerequisites
- A [Snowflake](https://signup.snowflake.com/) account (free trial works)
- [uv](https://docs.astral.sh/uv/) for Python dependency management

### 7.1 Configure Snowflake credentials
Create a `.env` file (gitignored) and load it:
```powershell
# .env
SNOWFLAKE_ACCOUNT=ab12345.us-east-1
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=ACCOUNTADMIN
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=MULTICHANNEL_ADS
SNOWFLAKE_SCHEMA=PUBLIC
```
```powershell
. .\load-env.ps1                         # load creds into this shell
uv run python snowflake/setup_objects.py # ensure warehouse + database exist
```

### 7.2 Build & test the pipeline
```bash
uv sync                       # install pinned deps into .venv
uv run dbt deps               # install dbt_utils
uv run dbt seed               # load the 3 CSVs into RAW
uv run dbt run                # build staging → intermediate → marts
uv run dbt test               # run all 100+ data-quality tests
# or all at once:
uv run dbt build
```
Result: schemas `RAW`, `STAGING`, `INTERMEDIATE`, `MARTS` in `MULTICHANNEL_ADS`,
with `MARTS.FCT_AD_PERFORMANCE` as the unified table.

### 7.3 Export marts for Tableau
```bash
uv run python export_marts.py     # writes exports/*.csv
```

> **DDL alternative:** `snowflake/ddl.sql` provisions Snowflake structure and loads
> the RAW tables via `COPY INTO` for teams who prefer to handle ingestion outside
> of dbt. dbt then builds everything from staging up.

---

## 8. The Tableau dashboard

**▶ Live dashboard:** [Marketing Analytics — Multi-Channel Performance (Tableau Public)](https://public.tableau.com/app/profile/dev.mithunisvar/viz/MarketingAnalytics_17806394670810/Dashboard1)

Tableau Public can't connect live to a warehouse, so the dashboard reads the
exported CSVs. For zero calculated fields, each widget connects to the matching
pre-aggregated table:

| Widget | Data source | What it answers |
|---|---|---|
| KPI scorecards | `agg_overall.csv` | Headline health: spend, conversions, blended CPA, revenue, Google ROAS |
| Spend vs Conversions by Platform | `agg_platform.csv` | Where budget goes vs. what it produces |
| Channel Efficiency (CPA vs CTR scatter) | `agg_platform.csv` | Which channel is most efficient |
| Daily Spend Trend | `agg_platform_day.csv` | Pacing over the month |
| Campaign Performance (highlight table) | `agg_campaign.csv` | Best/worst campaigns by ROAS |
| Spend by Objective (donut) | `agg_objective.csv` | Budget split across the funnel |

A full build spec — exact numbers, colors, fonts, and layout — is in
**`DASHBOARD_TEMPLATE.md`**.

> **Tip:** if you connect the `fct + dims` model instead, define ratios as
> `SUM(x)/SUM(y)` calculated fields (e.g. CTR = `SUM([clicks])/SUM([impressions])`),
> never as an average of the per-row ratio column.

---

## 9. Headline insights

*(Facebook · Google · TikTok — Jan 1–30, 2024)*

| Platform | Spend | Conversions | CTR | CPA | Revenue | ROAS |
|---|---|---|---|---|---|---|
| **TikTok** | $74,267 | 6,750 | 1.61% | $11.00 | n/a | n/a |
| **Google** | $37,686 | 4,218 | 1.90% | $8.93 | $210,900 | **5.6×** |
| **Facebook** | $18,292 | 2,395 | 1.96% | **$7.64** | n/a | n/a |
| **Total** | **$130,245** | **13,363** | — | $9.75 (blended) | $210,900 | — |

- **TikTok** absorbs **57% of spend** and drives the most volume, but at the
  **highest CPA ($11)** — and reports **no revenue**, so its true ROI is a blind spot.
- **Google** is the only revenue-attributed channel: blended **ROAS 5.6×**, led by
  brand search (**9.8×**) and shopping (**7.9×**); generic search lags (**2.0×**).
- **Facebook** is the **most cost-efficient** (lowest CPA, highest CTR) — a candidate
  to scale.
- **Recommendation:** shift budget from TikTok's expensive volume toward Facebook's
  efficiency and Google's high-ROAS brand terms.

---


### Assumptions & notes
- **Revenue is only available from Google** (`conversion_value`); ROAS is left `NULL`
  for Facebook/TikTok rather than fabricated. A blended ROAS would require an agreed
  revenue-per-conversion assumption for the other channels — intentionally not invented.
- `spend` unifies Facebook's `spend` and Google/TikTok's `cost`.
- `campaign_objective` in `dim_campaign` is a **heuristic** derived from campaign-name keywords.
- All three sources are at the same daily ad-group grain.
