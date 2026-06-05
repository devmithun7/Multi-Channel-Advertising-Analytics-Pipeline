"""
Export the dbt marts to CSV files for Tableau Public.

Tableau Public cannot connect live to a cloud warehouse, so we materialize the
gold-layer marts to flat files that Tableau Public can ingest directly.

Usage:
    # From Snowflake (after `dbt build`):
    python export_marts.py

Reads the same env vars used by profiles.yml.
"""
import os
from pathlib import Path

MARTS = [
    "fct_ad_performance",
    "dim_date",
    "dim_platform",
    "dim_campaign",
    "agg_overall",
    "agg_platform",
    "agg_platform_day",
    "agg_campaign",
    "agg_objective",
]
OUT_DIR = Path("exports")


def export_snowflake():
    import snowflake.connector
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "MULTICHANNEL_ADS"),
        schema="MARTS",
    )
    for m in MARTS:
        cur = con.cursor()
        cur.execute(f"select * from marts.{m}")
        df = cur.fetch_pandas_all()
        path = OUT_DIR / f"{m}.csv"
        df.to_csv(path, index=False)
        print(f"  wrote {path}  ({len(df)} rows)")
    con.close()


if __name__ == "__main__":
    OUT_DIR.mkdir(exist_ok=True)
    print(f"Exporting marts from snowflake -> {OUT_DIR}/")
    export_snowflake()
    print("Done.")
