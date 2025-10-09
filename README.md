# ROConAPI
ROCon 2025 API Class Scripts.

# 🧩 QualysETL Initialization & Snowflake Load Guide

This guide walks you through initializing **QualysETL** and loading results into **Snowflake**.  
Follow each step carefully in sequence.



---

## ⚙️ QualysETL Initialization

**Login:**  
Open the `linux-api-scan` Virtual Machine tab.

**Execute in terminal:**

```bash
###############################################################################
# QualysETL Initialization
###############################################################################

# Step 1) Initialize QualysETL and Snowflake snowsql client
cd $HOME; curl -s -L https://raw.githubusercontent.com/dg-cafe/ROConAPI/main/setup.sh -o /dev/stdout | bash 

# Step 2) Setup QualysETL API UserId and API Password.
$HOME/scripts/setup/generate_qualysetl_env.sh
$HOME/scripts/setup/test_qualysetl_login.sh                     # If this command hangs, ctrl-c and rerun as your subscription may be spinning up.

# Step 3) If Successful Login, Run ETL Host List Detection
$HOME/scripts/run/run_etl_host_list_detection.sh

# Step 4) Monitor Process ETL Host List Detection
$HOME/scripts/run/run_htop.sh

# Step 5) Monitor Log
tail -f /opt/qetl/users/ubuntu/qetl_home/log/host_list_detection.log


###############################################################################
# Snowflake Load - After Setting up Free Trial of Snowflake at https://www.snowflake.com
###############################################################################

# Step 1) Create snowsql env - use your account identity, username, password from snowflake setup.
$HOME/scripts/setup/generate_snowsql_env.sh

# Step 2) Create QETL database in Snowflake
$HOME/scripts/run/snowflake-loader/run_create_db.sh

# Step 3) Load Snowflake with etl_host_list_detection data.
$HOME/scripts/run/load_snowflake_etl_host_list_detection.sh
