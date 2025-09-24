#!/usr/bin/env bash
# First Time Setup - Pre-create directory /opt/qetl
# Login as user that will execute qetl_manage_user
sudo mkdir /opt/qetl    
sudo chown $USER:$USER /opt/qetl  # Note: If special group, update $USER:[your group] here before executing.
sudo apt update
sudo apt install -y python3-venv python3-pip sqlite3 sqlitebrowser jq pv
