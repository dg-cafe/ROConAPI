# ROConAPI
RocOn 2025 API Class Scripts.


QualysETL Initialization 

Login to linux-api-scan Virtual Machine Tab

Execute in terminal
# Step 1) Initialize QualysETL and Snowflake snowsql client
cd $HOME;curl -s -L https://raw.githubusercontent.com/dg-cafe/ROConAPI/main/setup.sh -o /dev/stdout | bash 

# Step 2) Setup QualysETL API UserId and API Password.
$HOME/scripts/setup/generate_qualysetl_env.sh
$HOME/scripts/setup/test_qualysetl_login.sh                     # If this command hangs, ctrl-c and rerun as your subscription may be spinning up.

# Step 3) If Successful Login, Run ETL Host List Detection
$HOME/scripts/run/run_etl_host_list_detection.sh

# Step 4) Monitor Process ETL Host List Detection
$HOME/scripts/run/run_htop.sh

# Step 5) Monitor Log
 tail -f /opt/qetl/users/ubuntu/qetl_home/log/host_list_detection.log
