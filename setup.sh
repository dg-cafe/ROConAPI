#!/bin/bash

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
SNOWSQL_VERSION="snowsql-1.4.5-linux_x86_64.bash"
QUALYSETL_TARBALL_URL="https://raw.githubusercontent.com/dg-cafe/ROConAPI/main/qualysetl-scripts.tgz"
SNOWSQL_BASE_URL="https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.4/linux_x86_64"

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

fetch_qualysetl_scripts() {
  # Download and extract the QualysETL helper scripts into $HOME
  cd "$HOME"
  curl -s -L "$QUALYSETL_TARBALL_URL" -o /dev/stdout | tar xzvf -
}

run_qualysetl_installer() {
  # Execute the QualysETL installer that was unpacked by the tarball
  cd "$HOME/scripts/setup"
  ./install_qualysetl.sh
}

download_snowsql_installer() {
  # Fetch the SnowSQL installer script
  curl -O "${SNOWSQL_BASE_URL}/${SNOWSQL_VERSION}"
}

make_snowsql_executable() {
  # Mark the SnowSQL installer as executable
  chmod +x "$SNOWSQL_VERSION"
}

run_snowsql_installer_accept_defaults() {
  # Pipe an empty line to accept defaults during installation
  SNOWSQL_DEST=$HOME/bin SNOWSQL_LOGIN_SHELL=$HOME/.profile bash $HOME/scripts/setup/$SNOWSQL_VERSION
}

final_echo() {
  # Preserve the trailing echo from the original script
  echo
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main() {
  fetch_qualysetl_scripts
  run_qualysetl_installer
  download_snowsql_installer
  make_snowsql_executable
  run_snowsql_installer_accept_defaults
  final_echo
}

main "$@"

