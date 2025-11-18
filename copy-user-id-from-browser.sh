#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Copy UserID from Admin Page
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🆔

# Documentation:
# @raycast.description Extract the numeric UserID from the currently open admin page in a Chromium-based browser and copy it to the clipboard.
# @raycast.author Jorrit Harmamny

set -euo pipefail

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
        -- Enhanced JavaScript extraction
        set pageText to ""
        try
          -- Arc and Dia don't support execute javascript directly
          if appName is "Arc" or appName is "Dia" then
            -- For Arc/Dia, we'll rely on selection-based extraction
            set pageText to ""
          else
            -- Chrome, Brave, Edge, Chromium support execute javascript
            set pageText to execute theTab javascript "
              try {
                const text = [];
                // Get all table rows
                document.querySelectorAll('tr').forEach(row => {
                  const cells = row.querySelectorAll('td');
                  if (cells.length > 0) {
                    // First cell in row might be the ID
                    const firstCell = cells[0].textContent.trim();
                    if (/^\\d{4,}$/.test(firstCell)) {
                      text.push('ID:' + firstCell);
                    }
                  }
                });
                // Also try data attributes
                document.querySelectorAll('[data-user-id], [data-id]').forEach(el => {
                  const uid = el.getAttribute('data-user-id') || el.getAttribute('data-id');
                  if (uid && /^\\d{4,}$/.test(uid)) text.push('ID:' + uid);
                });
                // Get text content of the whole body as fallback
                if (text.length === 0) {
                  text.push(document.body.innerText);
                }
                text.join('\\n');
              } catch(e) {
                document.body.innerText || '';
              }
            "
            if pageText is missing value then set pageText to ""
          end if
        end try
        return pageURL & "\n---TITLE---\n" & pageTitle & "\n---TEXT---\n" & pageText
      end tell
    end using terms from
  on error errMsg number errNum
    return "ERROR: " & errMsg
  end try
end run
APPLESCRIPT
}

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

if [[ -z "$running_app" || -z "$content" ]]; then
  echo "No supported Chromium-based browser found with an open page."
  exit 1
fi

page_url=$(printf "%s" "$content" | awk 'NR==1{print; exit}')
page_title=$(printf "%s" "$content" | awk '/^---TITLE---$/{getline; print; exit}')
page_text=$(printf "%s" "$content" | awk 'f{print} /^---TEXT---$/{f=1}')

echo "Debug: Using browser: $running_app" >&2

# Try several extraction strategies:
# 1) From URL paths and query parameters
from_url=$(printf "%s\n%s\n" "$page_url" "$page_title" | grep -Eo '/users/([0-9]{4,})|[?&]id=([0-9]{4,})|/admin/users/([0-9]{4,})|user_id=([0-9]{4,})' | grep -Eo '[0-9]{4,}' | head -n1 || true)

# 2) From page text with expanded patterns (including our ID: prefix)
from_context=$(printf "%s" "$page_text" | grep -Eio '(ID:|user.?id|user.?number|uid|^[0-9]{6,}$)[:#\s]*[0-9]{4,}|\bid[:#\s]*[0-9]{4,}' | grep -Eo '[0-9]{4,}' | head -n1 || true)

# 2b) Try to extract from title if it contains "User ID" or similar
from_title=$(printf "%s" "$page_title" | grep -Eio 'user.?id[:#\s]*[0-9]{4,}' | grep -Eo '[0-9]{4,}' | head -n1 || true)

# Debug with more context
echo "Debug: Extraction attempts:" >&2
echo "URL extraction attempt: '$from_url'" >&2
echo "Context extraction attempt: '$from_context'" >&2
echo "Full URL: $page_url" >&2
echo "Page text length: $(echo "$page_text" | wc -c) bytes" >&2
echo "Page text sample:" >&2
printf "%s" "$page_text" | head -c 500 >&2
echo >&2

# 3) Fallback: Try to find any number that looks like a user ID (4+ digits)
from_bigint=$(printf "%s" "$page_text" | grep -Eo '\b[0-9]{4,}\b' | head -n1 || true)

# 4) If page text was empty, try selection copy
from_selection=""
if [[ -z "$from_url" && -z "$from_context" && -z "$from_bigint" ]]; then
  if [[ -z "$page_text" ]]; then
    echo "Attempting clipboard selection method..." >&2
    sel=$(\
      /usr/bin/osascript - "$running_app" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  tell application "System Events"
    tell process appName
      set frontmost to true
      keystroke "c" using {command down}
    end tell
  end tell
  delay 0.2
  return "OK"
end run
APPLESCRIPT
    ) || true
    if [[ "$sel" == OK ]]; then
      from_selection=$(pbpaste | grep -Eo '\b[0-9]{4,}\b' | head -n1 || true)
      echo "Selection content: $(pbpaste | head -c 50)..." >&2
    fi
  fi
fi

USERID=""
if [[ -n "$from_url" ]]; then
  USERID="$from_url"
elif [[ -n "$from_title" ]]; then
  USERID="$from_title"
elif [[ -n "$from_context" ]]; then
  USERID="$from_context"
elif [[ -n "$from_bigint" ]]; then
  USERID="$from_bigint"
elif [[ -n "$from_selection" ]]; then
  USERID="$from_selection"
fi

if [[ -z "$USERID" ]]; then
  echo "Could not find a numeric UserID on the current page."
  echo "URL: $page_url"
  echo "Title: $page_title"
  if [[ -z "$page_text" ]]; then
    echo "Trying fallback: copy entire page text..."
    all_copy=$(\
      /usr/bin/osascript - "$running_app" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  try
    using terms from application "Google Chrome"
      tell application appName to activate
    end using terms from
    tell application "System Events"
      keystroke "a" using {command down}
      delay 0.05
      keystroke "c" using {command down}
    end tell
    delay 0.2
    return "OK"
  on error errMsg
    return "ERROR: " & errMsg
  end try
end run
APPLESCRIPT
    ) || true
    if [[ "$all_copy" == OK ]]; then
      # For StackBlitz admin pages, look for IDs at the start of a line (table format)
      # or after common patterns like "Id" headers
      clipboard_content=$(pbpaste)
      
      echo "Clipboard content sample (first 500 chars):" >&2
      echo "$clipboard_content" | head -c 500 >&2
      echo >&2
      
      # Try multiple extraction strategies
      # 1. ID in table format (number followed by tabs/spaces and other fields)
      candidate=$(echo "$clipboard_content" | grep -E '^[0-9]{4,}[[:space:]]' | grep -Eo '^[0-9]{4,}' | head -n1 || true)
      
      # 2. ID after "Id" column header in table
      if [[ -z "$candidate" ]]; then
        candidate=$(echo "$clipboard_content" | grep -A 3 -E '^Id[[:space:]]' | grep -Eo '^[0-9]{4,}' | head -n1 || true)
      fi
      
      # 3. Look for lines with email and extract any digits before/after
      if [[ -z "$candidate" ]]; then
        # Find line with email, then look for 4+ digit number on same or adjacent lines
        email_line=$(echo "$clipboard_content" | grep -n '@' | head -n1 | cut -d: -f1)
        if [[ -n "$email_line" ]]; then
          # Get context around email line (5 lines before and after)
          candidate=$(echo "$clipboard_content" | sed -n "$((email_line-5)),$((email_line+5))p" | grep -Eo '\b[0-9]{4,}\b' | head -n1 || true)
        fi
      fi
      
      # 4. Try to find number-email pattern in a single line
      if [[ -z "$candidate" ]]; then
        candidate=$(echo "$clipboard_content" | grep -E '[0-9]{4,}.*@' | grep -Eo '\b[0-9]{4,}\b' | head -n1 || true)
      fi
      
      # 5. Fallback: just find any 4+ digit number (but skip common false positives like years)
      if [[ -z "$candidate" ]]; then
        candidate=$(echo "$clipboard_content" | grep -Eo '\b[0-9]{5,}\b' | head -n1 || true)
      fi
      
      echo "Clipboard extraction result: '$candidate'" >&2
      
      if [[ -n "$candidate" ]]; then
        USERID="$candidate"
      fi
    fi
    if [[ -z "$USERID" ]]; then
      echo "Tip: Enable 'Allow JavaScript from Apple Events' in your browser's Developer settings, or select the row with the numeric ID and rerun."
      exit 2
    fi
  else
    exit 2
  fi
fi

printf "%s" "$USERID" | pbcopy

echo "Detected browser: $running_app"
echo "Page: $page_title"
echo "URL: $page_url"
echo "Copied UserID to clipboard: $USERID"

# Post-action menu with rate limits and token reset options
menu_choice=$(/usr/bin/osascript -e 'tell application "System Events" to activate' \
  -e "display dialog \"UserID: ${USERID}\n\nWhat would you like to do?\" with title \"Bolt Admin\" buttons {\"Cancel\", \"Reset Tokens\", \"Rate Limits\"} default button \"Rate Limits\" cancel button \"Cancel\"" \
  -e 'return button returned of result')

case "$menu_choice" in
  "Rate Limits")
    # Open rate limits page (requires authentication)
    open "https://bolt.new/api/rate-limits/$USERID"
    ;;
    
  "Reset Tokens")
    # First open the current rate limits page
    open "https://bolt.new/api/rate-limits/$USERID"
    sleep 0.8
    
    reset_choice=$(/usr/bin/osascript -e 'tell application "System Events" to activate' \
      -e "display dialog \"Choose token reset type for ${USERID}\" with title \"Reset Tokens\" buttons {\"Cancel\", \"All\", \"Monthly\"} default button \"Monthly\" cancel button \"Cancel\"" \
      -e 'return button returned of result')
    
    case "$reset_choice" in
      "Monthly")
        confirm=$(/usr/bin/osascript -e 'tell application "System Events" to activate' \
          -e "display dialog \"Confirm monthly token reset for ${USERID}?\" with title \"Confirm Reset\" buttons {\"Cancel\", \"Confirm\"} default button \"Confirm\" cancel button \"Cancel\"" \
          -e 'return button returned of result')
        
        if [[ "$confirm" == "Confirm" ]]; then
          # Reset monthly tokens
          open "https://bolt.new/api/rate-limits/reset/$USERID/month"
          echo "Opened monthly token reset endpoint."
          sleep 1
          # Show updated rate limits
          open "https://bolt.new/api/rate-limits/$USERID"
        else
          echo "Cancelled."
        fi
        ;;
        
      "All")
        confirm=$(/usr/bin/osascript -e 'tell application "System Events" to activate' \
          -e "display dialog \"Confirm ALL token reset (including rollovers) for ${USERID}?\" with title \"Confirm Reset\" buttons {\"Cancel\", \"Confirm\"} default button \"Confirm\" cancel button \"Cancel\"" \
          -e 'return button returned of result')
        
        if [[ "$confirm" == "Confirm" ]]; then
          # Reset all tokens
          open "https://bolt.new/api/rate-limits/reset/$USERID/all"
          echo "Opened ALL token reset endpoint."
          sleep 1
          # Show updated rate limits
          open "https://bolt.new/api/rate-limits/$USERID"
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
    # Cancel or closed dialog
    ;;
esac


