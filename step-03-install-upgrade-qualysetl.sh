
#!/usr/bin/env bash
# Login as user that will execute qetl_manage_user
# Install Application in Python Virtual Environment /opt/qetl/qetl_venv
# Exit if in a Python virtual environment
[ -n "$VIRTUAL_ENV" ] && { echo "Please deactivate the virtual environment and rerun this script."; exit 1; }
python3 -m venv ~/qetl_venv_tmp || { echo "Could not create virtual environment. Determine issue with python3 -m venv ~/qetl_venv_tmp and rerun this script."; exit 1; }
source ~/qetl_venv_tmp/bin/activate            
python3 -m pip install --upgrade qualysetl 
deactivate
~/qetl_venv_tmp/bin/qetl_setup_python_venv /opt/qetl
echo "Follow instructions output from qetl_setup_python_venv"
