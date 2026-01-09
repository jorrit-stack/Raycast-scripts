#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Org Token Stats
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📊
# @raycast.argument1 { "type": "text", "placeholder": "UserID (to find org)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "OrgID (empty = extract from page)", "optional": true }

# Documentation:
# @raycast.description Opens token stats for all users in an organization. Extracts org ID from admin page.
# @raycast.author Jorrit Harmamny

set -euo pipefail

USERID="${1:-}"
ORGID="${2:-}"

# Prefer these browsers in order if multiple are running
BROWSERS=(
  "Google Chrome"
  "Brave Browser"
  "Microsoft Edge"
  "Arc"
  "Chromium"
  "Dia"
)

get_page_text() {
  local app_name="$1"
  /usr/bin/osascript - "$app_name" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  try
    using terms from application "Google Chrome"
      tell application appName
        if (count of windows) is 0 then error "No windows"
        set theTab to active tab of front window
        set pageURL to URL of theTab
        set pageTitle to title of theTab
        set pageText to ""
        try
          if appName is not "Arc" and appName is not "Dia" then
            set pageText to execute theTab javascript "document.body.innerText || ''"
            if pageText is missing value then set pageText to ""
          end if
        end try
        return pageURL & "\n---TITLE---\n" & pageTitle & "\n---TEXT---\n" & pageText
      end tell
    end using terms from
  on error errMsg
    return "ERROR: " & errMsg
  end try
end run
APPLESCRIPT
}

# Try to extract org ID from admin page if not provided
if [[ -z "$ORGID" ]]; then
  running_app=""
  content=""
  
  for app in "${BROWSERS[@]}"; do
    result=$(get_page_text "$app") || true
    if [[ "$result" != ERROR:* ]]; then
      running_app="$app"
      content="$result"
      break
    fi
  done
  
  if [[ -n "$running_app" && -n "$content" ]]; then
    page_url=$(printf "%s" "$content" | awk 'NR==1{print; exit}')
    page_text=$(printf "%s" "$content" | awk 'f{print} /^---TEXT---$/{f=1}')
    
    # Extract org ID from URL or page
    extracted_org_id=$(printf "%s\n%s" "$page_url" "$page_text" | python3 - <<'PY' || true
import sys
import re

content = sys.stdin.read()

# Strategy 1: Extract from URL (most reliable)
url_match = re.search(r'/admin/organizations?/(\d+)', content)
if url_match:
    print(url_match.group(1))
    sys.exit(0)

# Strategy 2: Look for org links in content
html_match = re.search(r'/admin/organizations?/(\d+)', content)
if html_match:
    print(html_match.group(1))
    sys.exit(0)
PY
    )
    
    if [[ -n "$extracted_org_id" ]]; then
      ORGID="$extracted_org_id"
      echo "Extracted Org ID from admin page: $ORGID"
    fi
  fi
fi

# If still no org ID, prompt for it
if [[ -z "$ORGID" ]]; then
  ORGID=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Enter Organization ID:" with title "Open Org Token Stats" default answer "" buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
set orgId to text returned of result
return orgId
APPLESCRIPT
  ) || exit 1
fi

# Validate org ID
if [[ ! "$ORGID" =~ ^[0-9]+$ ]]; then
  echo "Error: OrgID must be numeric"
  exit 1
fi

# If user ID provided, open that user's org rate limits
if [[ -n "$USERID" && "$USERID" =~ ^[0-9]+$ ]]; then
  URL="https://bolt.new/api/rate-limits/org/$ORGID/$USERID"
  echo "Opening org rate limits for User $USERID in Org $ORGID"
  open "$URL"
else
  # Open the organization page in admin to see all users
  ORG_URL="https://stackblitz.com/admin/organizations/$ORGID"
  echo "Opening organization page: $ORG_URL"
  echo "You can then run the browser console script from org_limits.sh to open all token stats"
  open "$ORG_URL"
fi

