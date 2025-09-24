#!/usr/bin/bash
set -euo pipefail

###############################################################################
# Configuration (env overrides supported)
###############################################################################
GITHUB_FILE="${GITHUB_FILE:-my-archive.tgz}"
USERNAME="${USERNAME:-dg-cafe}"
GITHUB_TOKEN="${GITHUB_TOKEN:-notset}"
BRANCH="${BRANCH:-main}"
GITHUB_MESSAGE="${GITHUB_MESSAGE:-}"   # optional; action-specific default if empty
GITHUB_PATH="${GITHUB_PATH:-}"         # optional; for 'list' action

REPO="ROConAPI"
API_BASE="https://api.github.com/repos/$USERNAME/$REPO"

###############################################################################
# Helpers
###############################################################################
function usage() {
    echo "Usage: $0 {upload|download|delete|list}"
    echo
    echo "Environment variables:"
    echo "  USERNAME        GitHub username (default: dg-cafe)"
    echo "  GITHUB_TOKEN    Fine-grained PAT (required)"
    echo "  BRANCH          Branch name (default: main)"
    echo "  GITHUB_FILE     File to upload/download/delete (default: my-archive.tgz)"
    echo "  GITHUB_MESSAGE  Optional commit message (default varies by action)"
    echo "  GITHUB_PATH     Path for 'list' (default: repo root)"
    exit 1
}

function require_token() {
    if [ "${GITHUB_TOKEN}" = "notset" ] || [ -z "${GITHUB_TOKEN}" ]; then
        echo "Error: GITHUB_TOKEN is not set"
        exit 1
    fi
}

function require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required. Install with: sudo apt update && sudo apt install -y jq"
        exit 1
    fi
}

function api_get() {
    # $1: URL
    curl -s -u "$USERNAME:$GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -L "$1"
}

function api_put() {
    # $1: URL, stdin: JSON body
    curl -s -X PUT -u "$USERNAME:$GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$1" -d @-
}

function api_delete() {
    # $1: URL, stdin: JSON body
    curl -s -X DELETE -u "$USERNAME:$GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$1" -d @-
}

function get_file_sha() {
    # echoes SHA for $GITHUB_FILE on $BRANCH (empty if missing)
    api_get "$API_BASE/contents/$GITHUB_FILE?ref=$BRANCH" | jq -r '.sha // empty'
}

###############################################################################
# Actions
###############################################################################
function upload_file() {
    if [ ! -f "$GITHUB_FILE" ]; then
        echo "Error: local file '$GITHUB_FILE' not found"
        exit 1
    fi

    echo "Uploading $GITHUB_FILE to $USERNAME/$REPO on branch $BRANCH..."

    local existing_sha
    existing_sha="$(get_file_sha || true)"

    local content
    content="$(base64 -w 0 "$GITHUB_FILE")"

    local message
    message="${GITHUB_MESSAGE:-Upload $GITHUB_FILE via curl}"

    if [ -n "$existing_sha" ]; then
        api_put "$API_BASE/contents/$GITHUB_FILE" <<EOF
{
  "message": "$message",
  "content": "$content",
  "sha": "$existing_sha",
  "branch": "$BRANCH"
}
EOF
    else
        api_put "$API_BASE/contents/$GITHUB_FILE" <<EOF
{
  "message": "$message",
  "content": "$content",
  "branch": "$BRANCH"
}
EOF
    fi

    echo "Upload complete."
}

function download_file() {
    echo "Downloading $GITHUB_FILE from $USERNAME/$REPO on branch $BRANCH..."
    api_get "$API_BASE/contents/$GITHUB_FILE?ref=$BRANCH" \
        | jq -r '.content' | base64 -d > "$GITHUB_FILE"
    echo "Download complete. File saved as $GITHUB_FILE"
}

function delete_file() {
    echo "Deleting $GITHUB_FILE from $USERNAME/$REPO on branch $BRANCH..."

    local sha
    sha="$(get_file_sha)"

    if [ -z "$sha" ] || [ "$sha" = "null" ]; then
        echo "Error: File '$GITHUB_FILE' does not exist on branch '$BRANCH'."
        exit 1
    fi

    local message
    message="${GITHUB_MESSAGE:-Delete $GITHUB_FILE via curl}"

    api_delete "$API_BASE/contents/$GITHUB_FILE" <<EOF
{
  "message": "$message",
  "sha": "$sha",
  "branch": "$BRANCH"
}
EOF

    echo "Delete complete."
}

function list_path() {
    local url_path="$API_BASE/contents"
    if [ -n "$GITHUB_PATH" ]; then
        local clean_path="${GITHUB_PATH#/}"
        url_path="$url_path/$clean_path"
    fi

    echo "Listing path '${GITHUB_PATH:-/}' in $USERNAME/$REPO on branch $BRANCH..."
    api_get "$url_path?ref=$BRANCH" | jq -r '
      if type=="array" then
        (["type","path","size"] | @tsv),
        (.[] | [ .type, .path, ( .size // 0 ) ] | @tsv)
      else
        (["type","path","size"] | @tsv),
        ([ .type, .path, ( .size // 0 ) ] | @tsv)
      end
    '
}

###############################################################################
# Main
###############################################################################
function main() {
    if [ $# -ne 1 ]; then
        usage
    fi

    local action="$1"
    require_token
    require_jq

    case "$action" in
        upload)   upload_file ;;
        download) download_file ;;
        delete)   delete_file ;;
        list)     list_path ;;
        *)        usage ;;
    esac
}

main "$@"

