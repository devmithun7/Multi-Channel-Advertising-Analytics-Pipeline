"""One-time: ensure the warehouse and database exist before dbt builds.
Reads the same env vars as profiles.yml. Run: uv run python snowflake/setup_objects.py
"""
import os
import snowflake.connector

con = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
)
cur = con.cursor()
cur.execute(
    "create warehouse if not exists compute_wh "
    "with warehouse_size='xsmall' auto_suspend=60 auto_resume=true "
    "initially_suspended=true"
)
cur.execute("create database if not exists multichannel_ads")
print("warehouse + database ready")
con.close()
