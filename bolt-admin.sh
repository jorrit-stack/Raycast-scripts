#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bolt-admin
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "UserID or Email" }

# Documentation:
# @raycast.description bolt-admin-email-lookup
# @raycast.author jorrit_harmamny
# @raycast.authorURL https://raycast.com/jorrit_harmamny

input="$1"

if [[ "$input" =~ ^[0-9]+$ ]]; then
  # If input is only digits, treat as ID
  url="https://stackblitz.com/admin/users?q%5Bid_eq%5D=${input}&commit=Filter&order=id_desc"
else
  # Otherwise, treat as email
  encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$input")
  url="https://stackblitz.com/admin/users?q%5Bby_email_address%5D=${encoded}&commit=Filter&order=id_desc"
fi

open "$url"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
COPY_USER_ID_SCRIPT="$SCRIPT_DIR/copy-user-id-from-browser.sh"

# Give the browser time to load, then retry extraction a few times if needed.
attempts=0
max_attempts=4
sleep_between=1.5

if [[ -x "$COPY_USER_ID_SCRIPT" ]]; then
  sleep "$sleep_between"
  while (( attempts < max_attempts )); do
    "$COPY_USER_ID_SCRIPT"
    status=$?
    if (( status == 0 )); then
      exit 0
    fi
    (( attempts++ ))
    if (( status != 2 || attempts == max_attempts )); then
      echo "copy-user-id-from-browser.sh failed with status $status" >&2
      exit $status
    fi
    sleep "$sleep_between"
  done
else
  echo "Warning: copy-user-id-from-browser.sh not found or not executable at $COPY_USER_ID_SCRIPT" >&2
fi