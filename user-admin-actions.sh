#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title User Admin Actions
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🧭
# @raycast.argument1 { "type": "text", "placeholder": "UserID (empty = clipboard)", "optional": true }

# Documentation:
# @raycast.description Use the clipboard (or argument) UserID to view/open rate limits or reset tokens via your signed-in browser.
# @raycast.author Jorrit Harmamny

set -euo pipefail

INPUT_ID="${1:-}"
if [[ -z "$INPUT_ID" ]]; then
  USERID=$(pbpaste | tr -d '\n' | grep -Eo '^\d{4,}$' || true)
else
  USERID="$INPUT_ID"
fi

if [[ -z "${USERID:-}" ]]; then
  echo "Clipboard doesn't look like a numeric UserID. Provide it as an argument or copy it first."
  exit 1
fi

# Prefer these browsers in order if multiple are installed
BROWSERS=(
  "Google Chrome"
  "Brave Browser"
  "Microsoft Edge"
  "Arc"
  "Chromium"
  "Dia"
)

pick_browser() {
  for app in "${BROWSERS[@]}"; do
    if /usr/bin/osascript -e "application \"$app\" is running" >/dev/null 2>&1; then
      echo "$app"
      return 0
    fi
  done
  # Fallback to Chrome even if not running; we'll open it
  echo "Google Chrome"
}

open_and_read_json() {
  local app_name="$1"
  local url="$2"
  /usr/bin/osascript <<APPLESCRIPT
try
  set targetURL to "$url"
  tell application "$app_name"
    activate
    if (count of windows) is 0 then make new window
    set theWindow to front window
    set theTab to make new tab at the end of tabs of theWindow with properties {URL:targetURL}
    delay 0.5
    set maxTries to 40
    repeat with i from 1 to maxTries
      try
        set state to execute theTab javascript "document.readyState"
        if state is "complete" then exit repeat
      end try
      delay 0.25
    end repeat
    set bodyText to ""
    try
      set bodyText to execute theTab javascript "document.body.innerText"
      if bodyText is missing value then set bodyText to ""
    end try
    return bodyText
  end tell
on error errMsg
  return "ERROR: " & errMsg
end try
APPLESCRIPT
}

menu_choice=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
set options to {"Show Rate Limits", "Open Rate Limits", "Reset Tokens"}
set sel to choose from list options with title "Bolt Admin" with prompt "UserID: $USERID — Choose an action:" OK button name "OK" cancel button name "Cancel" default items {"Show Rate Limits"}
if sel is false then return "Cancel"
return item 1 of sel
APPLESCRIPT
) || true

case "$menu_choice" in
  "Show Rate Limits")
    app=$(pick_browser)
    echo "Using browser: $app"
    json_text=$(open_and_read_json "$app" "https://bolt.new/api/rate-limits/$USERID") || true
    if [[ "$json_text" == ERROR:* || -z "$json_text" ]]; then
      echo "Could not read JSON from the browser."
      echo "Tip: Enable 'Allow JavaScript from Apple Events' in $app, or choose 'Open Rate Limits'."
      exit 0
    fi
    if command -v jq >/dev/null 2>&1; then
      echo "$json_text" | jq .
      echo "\nToken usage today: $(echo "$json_text" | jq '.tokenStats.totalToday')"
      echo "Token usage this month: $(echo "$json_text" | jq '.tokenStats.totalThisMonth')"
      echo "Max per day: $(echo "$json_text" | jq '.tokenStats.maxPerDay')"
      echo "Max per month: $(echo "$json_text" | jq '.tokenStats.maxPerMonth')"
    else
      echo "$json_text"
      echo "\nInstall jq for pretty printing: brew install jq"
    fi
    ;;
  "Open Rate Limits")
    open "https://bolt.new/api/rate-limits/$USERID"
    ;;
  "Reset Tokens")
    # Open pre-view immediately when user chooses Reset Tokens
    open "https://bolt.new/api/rate-limits/$USERID"
    sleep 0.8
    reset_choice=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Choose token reset type for $USERID" with title "Reset Tokens" buttons {"Cancel", "All", "Monthly"} default button "Monthly" cancel button "Cancel"
set btn to button returned of result
return btn
APPLESCRIPT
    ) || true
    case "$reset_choice" in
      "Monthly")
        confirm=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Confirm monthly token reset for $USERID?" with title "Confirm Reset" buttons {"Cancel", "Confirm"} default button "Confirm" cancel button "Cancel"
set btn to button returned of result
return btn
APPLESCRIPT
        ) || true
        if [[ "$confirm" == "Confirm" ]]; then
          # Open before
          open "https://bolt.new/api/rate-limits/$USERID"
          sleep 0.8
          # Perform monthly reset via endpoint
          open "https://bolt.new/api/rate-limits/reset/$USERID/month"
          echo "Opened MONTHLY token reset endpoint."
          # Open after
          sleep 1
          open "https://bolt.new/api/rate-limits/$USERID"
          echo "Opened rate limits (post)."
        else
          echo "Cancelled."
        fi
        ;;
      "All")
        confirm=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Confirm ALL token reset (including rollovers) for $USERID?" with title "Confirm Reset" buttons {"Cancel", "Confirm"} default button "Confirm" cancel button "Cancel"
set btn to button returned of result
return btn
APPLESCRIPT
        ) || true
        if [[ "$confirm" == "Confirm" ]]; then
          # Open before
          open "https://bolt.new/api/rate-limits/$USERID"
          sleep 0.8
          # Perform reset (all)
          open "https://bolt.new/api/rate-limits/reset/$USERID/all"
          echo "Opened ALL token reset page."
          # Open after
          sleep 1
          open "https://bolt.new/api/rate-limits/$USERID"
          echo "Opened rate limits (post)."
        else
          echo "Cancelled."
        fi
        ;;
      *)
        echo "Cancelled."
        ;;
    esac
    ;;
  *)
    ;;
esac


