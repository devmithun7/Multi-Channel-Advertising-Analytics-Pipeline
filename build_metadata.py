"""
Build an Excel KPI / metric data dictionary for the multichannel-ads-pipeline.

Documents every metric in the marts layer: its definition, how it is calculated
(formula), the source columns it derives from, the table it lives in, and which
platforms report it.

Run:
    uv run --with openpyxl python build_metadata.py

Output:
    KPI_Metadata.xlsx
"""
from pathlib import Path
import pandas as pd

OUT = Path("KPI_Metadata.xlsx")

# NOTE on division: all ratio metrics use the safe_divide macro, which returns
# NULL when the denominator is 0 or NULL (avoids divide-by-zero errors).

# ---------------------------------------------------------------------------
# fct_ad_performance — grain: platform x date x campaign x ad group (one day)
# ---------------------------------------------------------------------------
fact = [
    # --- keys / identifiers ---
    ("ad_performance_key", "Key", "Surrogate primary key of the fact (one row per platform x date x campaign x ad group).",
     "MD5 hash of (platform, ad_date, campaign_id, ad_group_id)", "platform, ad_date, campaign_id, ad_group_id", "All"),
    ("date_key", "Foreign key", "FK to dim_date. Calendar day of the activity as a YYYYMMDD integer.",
     "CAST(TO_CHAR(ad_date,'YYYYMMDD') AS INTEGER)", "ad_date", "All"),
    ("platform_key", "Foreign key", "FK to dim_platform (advertising channel).",
     "MD5 hash of (platform)", "platform", "All"),
    ("campaign_key", "Foreign key", "FK to dim_campaign.",
     "MD5 hash of (platform, campaign_id)", "platform, campaign_id", "All"),
    ("ad_group_id", "Degenerate dimension", "Ad-group / ad-set identifier (no dimension table of its own).",
     "Pass-through", "ad_group_id", "All"),
    ("ad_group_name", "Degenerate dimension", "Ad-group / ad-set name.",
     "Pass-through", "ad_group_name", "All"),

    # --- base additive measures ---
    ("impressions", "Base measure (additive)", "Number of times ads were shown.",
     "Pass-through (sum at grain)", "impressions", "All"),
    ("clicks", "Base measure (additive)", "Number of clicks on the ads.",
     "Pass-through", "clicks", "All"),
    ("spend", "Base measure (additive)", "Advertising cost in USD.",
     "Pass-through", "spend", "All"),
    ("conversions", "Base measure (additive)", "Number of conversions (purchases / sign-ups).",
     "Pass-through", "conversions", "All"),
    ("conversion_value", "Base measure (additive)", "Revenue attributed to conversions. Tracked by Google only; NULL elsewhere.",
     "Pass-through", "conversion_value", "Google"),
    ("video_views", "Base measure (additive)", "Number of video views.",
     "Pass-through", "video_views", "TikTok (video)"),
    ("video_watch_25", "Base measure (additive)", "Views that reached 25% of the video.",
     "Pass-through", "video_watch_25", "TikTok"),
    ("video_watch_50", "Base measure (additive)", "Views that reached 50% of the video.",
     "Pass-through", "video_watch_50", "TikTok"),
    ("video_watch_75", "Base measure (additive)", "Views that reached 75% of the video.",
     "Pass-through", "video_watch_75", "TikTok"),
    ("video_watch_100", "Base measure (additive)", "Views that reached 100% (completed) the video.",
     "Pass-through", "video_watch_100", "TikTok"),
    ("likes", "Base measure (additive)", "Social likes.", "Pass-through", "likes", "TikTok / Facebook"),
    ("shares", "Base measure (additive)", "Social shares.", "Pass-through", "shares", "TikTok / Facebook"),
    ("comments", "Base measure (additive)", "Social comments.", "Pass-through", "comments", "TikTok / Facebook"),
    ("social_engagements", "Derived measure (additive)", "Total social interactions (likes + shares + comments).",
     "COALESCE(likes,0) + COALESCE(shares,0) + COALESCE(comments,0)", "likes, shares, comments", "TikTok / Facebook"),
    ("reach", "Base measure", "Unique users reached.", "Pass-through", "reach", "Facebook"),
    ("frequency", "Base measure (non-additive)", "Average impressions per reached user.",
     "Pass-through", "frequency", "Facebook"),
    ("engagement_rate", "Base measure (ratio, non-additive)", "Platform-reported engagement rate.",
     "Pass-through", "engagement_rate", "TikTok"),
    ("quality_score", "Base measure (non-additive)", "Google ad quality score (1-10).",
     "Pass-through", "quality_score", "Google"),
    ("search_impression_share", "Base measure (ratio, non-additive)", "Share of eligible search impressions won.",
     "Pass-through", "search_impression_share", "Google"),

    # --- derived efficiency ratios ---
    ("ctr", "Derived ratio", "Click-through rate: clicks per impression.",
     "clicks / impressions", "clicks, impressions", "All"),
    ("cpc", "Derived ratio", "Cost per click.",
     "spend / clicks", "spend, clicks", "All"),
    ("cpm", "Derived ratio", "Cost per 1,000 impressions.",
     "spend / impressions * 1000", "spend, impressions", "All"),
    ("cvr", "Derived ratio", "Conversion rate: conversions per click.",
     "conversions / clicks", "conversions, clicks", "All"),
    ("cpa", "Derived ratio", "Cost per acquisition (per conversion).",
     "spend / conversions", "spend, conversions", "All"),
    ("roas", "Derived ratio", "Return on ad spend: revenue per $1 spent.",
     "conversion_value / spend", "conversion_value, spend", "Google"),
    ("aov", "Derived ratio", "Average order value: revenue per conversion.",
     "conversion_value / conversions", "conversion_value, conversions", "Google"),
    ("revenue_per_click", "Derived ratio", "Revenue generated per click.",
     "conversion_value / clicks", "conversion_value, clicks", "Google"),

    # --- video / creative ratios ---
    ("cpv", "Derived ratio", "Cost per video view.",
     "spend / video_views", "spend, video_views", "TikTok"),
    ("vtr", "Derived ratio", "View-through rate: video views per impression.",
     "video_views / impressions", "video_views, impressions", "TikTok"),
    ("hook_rate", "Derived ratio", "Share of impressions that reached 25% of the video (creative hook strength).",
     "video_watch_25 / impressions", "video_watch_25, impressions", "TikTok"),
    ("hold_rate", "Derived ratio", "Share of 25%-viewers who completed the video (retention).",
     "video_watch_100 / video_watch_25", "video_watch_100, video_watch_25", "TikTok"),
    ("video_watch_25_rate", "Derived ratio", "25% quartile completion of total video views.",
     "video_watch_25 / video_views", "video_watch_25, video_views", "TikTok"),
    ("video_watch_50_rate", "Derived ratio", "50% quartile completion of total video views.",
     "video_watch_50 / video_views", "video_watch_50, video_views", "TikTok"),
    ("video_watch_75_rate", "Derived ratio", "75% quartile completion of total video views.",
     "video_watch_75 / video_views", "video_watch_75, video_views", "TikTok"),
    ("video_completion_rate", "Derived ratio", "Full completion rate of total video views.",
     "video_watch_100 / video_views", "video_watch_100, video_views", "TikTok"),
    ("social_engagement_rate", "Derived ratio", "Conformed engagement rate: social interactions per impression.",
     "(likes + shares + comments) / impressions", "likes, shares, comments, impressions", "TikTok / Facebook"),
]

# ---------------------------------------------------------------------------
# Aggregate / blended marts
# ---------------------------------------------------------------------------
aggs = [
    ("total_spend", "agg_overall", "Blended total", "Total spend across all platforms.",
     "SUM(spend)", "spend"),
    ("total_conversions", "agg_overall", "Blended total", "Total conversions across all platforms.",
     "SUM(conversions)", "conversions"),
    ("total_revenue", "agg_overall", "Blended total", "Total tracked revenue (Google only).",
     "SUM(conversion_value)", "conversion_value"),
    ("blended_cpa", "agg_overall", "Blended ratio", "Account-wide cost per acquisition.",
     "SUM(spend) / SUM(conversions)", "spend, conversions"),
    ("blended_ctr", "agg_overall", "Blended ratio", "Account-wide click-through rate.",
     "SUM(clicks) / SUM(impressions)", "clicks, impressions"),
    ("blended_cpc", "agg_overall", "Blended ratio", "Account-wide cost per click.",
     "SUM(spend) / SUM(clicks)", "spend, clicks"),
    ("blended_roas", "agg_overall", "Blended ratio", "Account-wide return on ad spend (revenue / all spend).",
     "SUM(conversion_value) / SUM(spend)", "conversion_value, spend"),
    ("google_roas", "agg_overall", "Blended ratio", "ROAS for Google only (revenue / Google spend).",
     "SUM(CASE WHEN platform='google' THEN conversion_value END) / SUM(CASE WHEN platform='google' THEN spend END)",
     "conversion_value, spend, platform"),
    ("spend_pct_of_total", "agg_platform / agg_campaign / agg_objective", "Allocation share",
     "Share of total spend taken by this platform / campaign / objective.",
     "spend / SUM(spend) OVER ()", "spend"),
    ("spend_pct_of_day", "agg_platform_day", "Allocation share",
     "Share of a given day's total spend taken by this platform.",
     "spend / SUM(spend) OVER (PARTITION BY date_key)", "spend, date_key"),
]

# For source/base columns the value is taken directly from the source column,
# so show the source column itself as the formula rather than "Pass-through".
fact = [
    (name, typ, defn, (src if formula.startswith("Pass-through") else formula), src, plat)
    for (name, typ, defn, formula, src, plat) in fact
]

fact_df = pd.DataFrame(
    fact,
    columns=["KPI / Column", "Type", "Definition", "Formula", "Source Column(s)", "Platform Availability"],
)
fact_df.insert(1, "Table", "fct_ad_performance")

agg_df = pd.DataFrame(
    aggs,
    columns=["KPI / Column", "Table", "Type", "Definition", "Formula", "Source Column(s)"],
)
agg_df["Platform Availability"] = "All (blended)"

cols = ["KPI / Column", "Table", "Type", "Definition", "Formula", "Source Column(s)", "Platform Availability"]
fact_df = fact_df[cols]
agg_df = agg_df[cols]
all_df = pd.concat([fact_df, agg_df], ignore_index=True)

notes = pd.DataFrame({
    "Topic": [
        "Grain (fct_ad_performance)",
        "Division safety",
        "NULL revenue metrics",
        "Additivity",
        "Source of base columns",
        "Platform availability",
    ],
    "Note": [
        "One row per platform x date x campaign x ad group (one calendar day).",
        "All ratios use safe_divide(): returns NULL when the denominator is 0 or NULL.",
        "Revenue metrics (conversion_value, roas, aov, revenue_per_click) are NULL for Facebook/TikTok because only Google tracks revenue.",
        "Only base measures (impressions, clicks, spend, conversions, conversion_value, video_*, likes/shares/comments) are additive and safe to SUM. Ratios must be recomputed as SUM(numerator)/SUM(denominator).",
        "Base columns originate in the raw platform tables, conformed in stg_* models and unioned in int_ads_unified before landing in fct_ad_performance.",
        "Indicates which platform(s) populate the metric; others are NULL.",
    ],
})

with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
    all_df.to_excel(xl, sheet_name="KPI Dictionary", index=False)
    fact_df.to_excel(xl, sheet_name="fct_ad_performance", index=False)
    agg_df.to_excel(xl, sheet_name="Aggregate & Blended", index=False)
    notes.to_excel(xl, sheet_name="Notes", index=False)

    # widen columns for readability
    for ws in xl.book.worksheets:
        widths = {1: 26, 2: 34, 3: 26, 4: 60, 5: 70, 6: 40, 7: 22}
        for idx, w in widths.items():
            col = ws.cell(row=1, column=idx).column_letter
            ws.column_dimensions[col].width = w

print(f"Wrote {OUT.resolve()}  ({len(all_df)} metrics documented)")
