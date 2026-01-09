#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Org User Rate Limits
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 👥
# @raycast.argument1 { "type": "text", "placeholder": "UserID" }
# @raycast.argument2 { "type": "text", "placeholder": "OrgID (empty = extract from page)", "optional": true }

# Documentation:
# @raycast.description Open org user rate limits page. Extracts org ID from admin page if not provided.
# @raycast.author Jorrit Harmamny

set -euo pipefail

USERID="$1"
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
    page_html=$(printf "%s" "$content" | awk '/^---HTML---$/{f=1; next} f{print}')
    
    # Try to extract org ID from page
    TMP_EXTRACT=$(mktemp)
    cat > "$TMP_EXTRACT" <<'PYEOF'
import sys
import re

content = sys.stdin.read()

# Strategy 1: Extract from URL (most reliable)
url_match = re.search(r'/admin/organizations?/(\d+)', content)
if url_match:
    print(url_match.group(1))
    sys.exit(0)

# Strategy 2: Look for org links in HTML
html_match = re.search(r'/admin/organizations?/(\d+)', content)
if html_match:
    print(html_match.group(1))
    sys.exit(0)

# Strategy 3: Parse Organizations table on user detail page
lines = [ln.strip() for ln in content.splitlines()]
for line in lines:
    if '\t' in line:
        parts = line.split('\t')
        for part in parts:
            match = re.search(r'/admin/organizations?/(\d+)', part)
            if match:
                print(match.group(1))
                sys.exit(0)
PYEOF
    
    extracted_org_id=$(printf "%s\n%s" "$page_url" "$page_text" "$page_html" | python3 "$TMP_EXTRACT" 2>/dev/null || true)
    rm -f "$TMP_EXTRACT"
    
    if [[ -n "$extracted_org_id" ]]; then
      ORGID="$extracted_org_id"
      echo "Extracted Org ID: $ORGID"
    fi
  fi
fi

# If still no org ID, prompt for it
if [[ -z "$ORGID" ]]; then
  ORGID=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Enter Organization ID:" with title "Org Rate Limits" default answer "" buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
set orgId to text returned of result
return orgId
APPLESCRIPT
  ) || exit 1
fi

# Validate inputs
if [[ ! "$USERID" =~ ^[0-9]+$ ]]; then
  echo "Error: UserID must be numeric"
  exit 1
fi

if [[ ! "$ORGID" =~ ^[0-9]+$ ]]; then
  echo "Error: OrgID must be numeric"
  exit 1
fi

URL="https://bolt.new/api/rate-limits/org/$ORGID/$USERID"

echo "Opening org rate limits for User $USERID in Org $ORGID"
open "$URL"
