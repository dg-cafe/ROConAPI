#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Defaults (overridable via env or CLI)
###############################################################################
SWAPFILE="${SWAPFILE:-/swapfile}"
SWAP_SIZE_G="${SWAP_SIZE_G:-4}"   # GiB
FSTAB="/etc/fstab"
FSTAB_BAK="/etc/fstab.bak"

###############################################################################
# Usage / Args
###############################################################################
function usage() {
  cat <<EOF
Usage: sudo $0 [-p /path/to/swapfile] [-s SIZE_GIB] [-h]

Creates a swap file only if no swap is currently active.
If swap already exists, prints active swap size (GiB) and exits 0.

Options:
  -p PATH   Swapfile path (default: ${SWAPFILE})
  -s SIZE   Swapfile size in GiB (default: ${SWAP_SIZE_G})
  -h        Show this help

Environment overrides:
  SWAPFILE=/path/to/file
  SWAP_SIZE_G=<integer GiB>
EOF
}

function parse_args() {
  while getopts ":p:s:h" opt; do
      case "$opt" in
            p) SWAPFILE="$OPTARG" ;;
          s) SWAP_SIZE_G="$OPTARG" ;;
        h) usage; exit 0 ;;
      *) usage; exit 1 ;;
          esac
    done
    }

    ###############################################################################
    # Helpers
    ###############################################################################
    function require_root() {
      if [[ $EUID -ne 0 ]]; then
          echo "Please run this script as root or with sudo."
      exit 1
        fi
}

function bytes_to_gib() {
  # $1: bytes
    awk -v b="${1:-0}" 'BEGIN { printf "%.2f", b/1024/1024/1024 }'
    }

    function total_active_swap_bytes() {
      # /proc/swaps: size is in KiB; sum and convert to bytes
        if [[ -r /proc/swaps ]]; then
    awk 'NR>1 {sum += $3 * 1024} END {print sum+0}' /proc/swaps
      else
          swapon --show --bytes --noheadings --output SIZE 2>/dev/null | awk '{s+=$1} END{print s+0}'
    fi
    }

    function is_any_swap_active() {
      local total
        total="$(total_active_swap_bytes)"
  [[ "${total:-0}" -gt 0 ]]
  }

  function swapfile_active_bytes() {
    # Returns bytes for this SWAPFILE if active, else 0
      if [[ -r /proc/swaps ]]; then
          awk -v f="$SWAPFILE" 'NR>1 && $1==f {print $3*1024; found=1} END{if(!found) print 0}' /proc/swaps
    else
        echo 0
  fi
  }

  ###############################################################################
  # OS Compatibility
  ###############################################################################
  OS_ID=""
  OS_VERSION_ID=""
  OS_ID_LIKE=""
  SUPPORTED_OS="false"
  ON_RHEL_SELINUX_ENFORCING="false"
  OS_PRETTY_NAME=""

  function detect_os() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
    . /etc/os-release
        OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
    OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID $OS_VERSION_ID}"
      else
          OS_ID="$(uname -s)"
      OS_VERSION_ID="$(uname -r)"
          OS_PRETTY_NAME="${OS_ID} ${OS_VERSION_ID}"
    fi
    }

    function is_supported_ubuntu() {
      [[ "$OS_ID" = "ubuntu" ]] || return 1
        local major="${OS_VERSION_ID%%.*}"
  [[ "$major" = "20" || "$major" = "22" || "$major" = "24" ]]
  }

  function is_supported_rhel_family() {
    # RHEL-family check: ID rhel/almalinux/rocky/centos stream variants etc.
      if [[ "$OS_ID" =~ ^(rhel|redhat|rocky|almalinux|centos|centos_stream)$ ]] || [[ "$OS_ID_LIKE" =~ rhel ]]; then
          local major="${OS_VERSION_ID%%.*}"
      [[ "$major" = "8" || "$major" = "9" || "$major" = "10" ]]
        else
    return 1
      fi
      }

      function is_supported_amazon() {
        [[ "$OS_ID" = "amzn" && "$OS_VERSION_ID" = "2023" ]]
}

function check_os_compatibility() {
  detect_os

    if is_supported_ubuntu || is_supported_rhel_family || is_supported_amazon; then
        SUPPORTED_OS="true"
  else
      SUPPORTED_OS="false"
        fi

  # If RHEL-family and SELinux Enforcing, flag it so we can print required commands.
    if is_supported_rhel_family && command -v getenforce >/dev/null 2>&1; then
        if [[ "$(getenforce 2>/dev/null || echo Permissive)" = "Enforcing" ]]; then
      ON_RHEL_SELINUX_ENFORCING="true"
          fi
    fi

      if [[ "$SUPPORTED_OS" != "true" ]]; then
          echo "Warning: Detected OS '${OS_PRETTY_NAME}' is not in the supported list:"
      echo "  - Ubuntu 20.04 / 22.04 / 24.04"
          echo "  - Red Hat Enterprise Linux 8 / 9 / 10 (and compatible)"
      echo "  - Amazon Linux 2023"
          read -r -p "Do you want to continue anyway? [y/N]: " ans
      case "$ans" in
            y|Y) echo "Continuing on an unsupported OS at your own risk." ;;
          *)   echo "Exiting."; exit 1 ;;
      esac
        fi

  if [[ "$ON_RHEL_SELINUX_ENFORCING" = "true" ]]; then
      echo "Detected RHEL-family with SELinux in Enforcing mode."
          echo "Before enabling swap, you must set the correct SELinux context. Run:"
      echo "  chcon --type=swapfile_t \"$SWAPFILE\""
          echo "  # Optionally restore default context if defined:"
      echo "  restorecon -v \"$SWAPFILE\""
          echo "If you encounter denials, check 'ausearch -m avc -ts recent' or /var/log/audit/audit.log"
      echo "and retry after applying the correct context."
        fi
}

###############################################################################
# Swapfile workflow
###############################################################################
function ensure_swapfile_created() {
  if [[ -e "$SWAPFILE" ]]; then
      echo "Note: $SWAPFILE already exists."
          return
    fi

      echo "Creating ${SWAP_SIZE_G} GiB swap file at $SWAPFILE ..."
        if ! fallocate -l "${SWAP_SIZE_G}G" "$SWAPFILE" 2>/dev/null; then
    echo "fallocate failed; falling back to dd."
        dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_SIZE_G*1024)) status=progress
  fi
  }

  function set_swapfile_permissions() {
    chmod 600 "$SWAPFILE"
    }

    function format_swapfile() {
      echo "Formatting $SWAPFILE as swap ..."
        mkswap "$SWAPFILE" >/dev/null
}

function activate_swapfile() {
  echo "Activating swap ..."
    swapon "$SWAPFILE"
    }

    function ensure_fstab_entry() {
      # Avoid duplicate entries
        if ! grep -qE "^[[:space:]]*$(printf '%q' "$SWAPFILE")[[:space:]]+" "$FSTAB"; then
    echo "Backing up $FSTAB to $FSTAB_BAK ..."
        cp "$FSTAB" "$FSTAB_BAK"
    echo "$SWAPFILE none swap sw 0 0" >> "$FSTAB"
      fi
      }

      function report_active_and_exit() {
        local bytes gib
  bytes="$(total_active_swap_bytes)"
    gib="$(bytes_to_gib "$bytes")"
      echo "Swap already enabled: ${gib} GiB active. No changes needed."
        exit 0
}

###############################################################################
# Main
###############################################################################
function main() {
  parse_args "$@"
    require_root
      check_os_compatibility

        # Exit 0 if any swap already active
  if is_any_swap_active; then
      report_active_and_exit
        fi

  # Defensive: if the target swapfile is already active, do nothing
    local sf_bytes
      sf_bytes="$(swapfile_active_bytes)"
        if [[ "${sf_bytes:-0}" -gt 0 ]]; then
    local gib
        gib="$(bytes_to_gib "$sf_bytes")"
    echo "Swapfile $SWAPFILE is already active: ${gib} GiB. No changes needed."
        exit 0
  fi

    # Proceed with creation/activation
      ensure_swapfile_created
        set_swapfile_permissions

  # On RHEL SELinux Enforcing, we already printed the commands the user must run.
    # We still attempt to proceed; if SELinux blocks, the user can apply the context and re-run.
      format_swapfile
        activate_swapfile
  ensure_fstab_entry

    # Final status
      local total bytes_gib
        total="$(total_active_swap_bytes)"
  bytes_gib="$(bytes_to_gib "$total")"
    echo "Swap enabled: ${bytes_gib} GiB. Verify with: swapon --show"
    }

    main "$@"

