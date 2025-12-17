#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Allocate Tokens
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 💰
# @raycast.argument1 { "type": "text", "placeholder": "Username (empty = from admin page)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Token amount", "optional": true }
# @raycast.argument3 { "type": "text", "placeholder": "Reason", "optional": true }

# Documentation:
# @raycast.description Allocate custom tokens for a user. Extracts username from admin page if not provided.
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
        set pageText to ""
        set htmlContent to ""
        try
          if appName is not "Arc" and appName is not "Dia" then
            set pageText to execute theTab javascript "
              try {
                const text = document.body.innerText || '';
                const html = document.documentElement.innerHTML || '';
                return text + '\\n---HTML---\\n' + html;
              } catch(e) {
                return (document.body.innerText || '') + '\\n---HTML---\\n';
              }
            "
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

# Try to get username from admin page if not provided
USERNAME="${1:-}"
if [[ -z "$USERNAME" ]]; then
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
    # Extract text and HTML from content
    full_content=$(printf "%s" "$content" | awk 'f{print} /^---TEXT---$/{f=1}')
    page_text=$(printf "%s" "$full_content" | awk '/^---HTML---$/{exit} {print}')
    page_html=$(printf "%s" "$full_content" | awk '/^---HTML---$/{f=1; next} f{print}')
    
    # Try to extract username from page text and HTML
    # Common patterns: username on StackBlitz admin pages
    extracted_username=$(printf "%s\n%s" "$page_text" "$page_html" | python3 - <<'PY' || true
import sys
import re

text = sys.stdin.read()
lines = [ln.strip() for ln in text.splitlines()]

# Strategy 1: Look for email addresses and extract username part
for line in lines:
    email_match = re.search(r'\b([a-zA-Z0-9._-]+)@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}\b', line)
    if email_match:
        username = email_match.group(1)
        # Skip common non-username emails
        if username.lower() not in ['admin', 'support', 'noreply', 'no-reply', 'info', 'mail', 'email']:
            if len(username) > 1 and len(username) < 50:
                print(username)
                sys.exit(0)

# Strategy 2: Look for "User:" or "Username:" patterns in text
for line in lines:
    user_match = re.search(r'(?:User|Username)[:\s]+([a-zA-Z0-9._-]+)', line, re.IGNORECASE)
    if user_match:
        username = user_match.group(1).strip()
        if len(username) > 1 and len(username) < 50:
            print(username)
            sys.exit(0)

# Strategy 3: Look in HTML for input fields with username values
html_match = re.search(r'(?:value|placeholder|data-user)=["\']([a-zA-Z0-9._-]+)["\']', text, re.IGNORECASE)
if html_match:
    username = html_match.group(1)
    if len(username) > 1 and len(username) < 50 and '@' not in username:
        print(username)
        sys.exit(0)

# Strategy 4: Look for common admin table patterns where username is in a column
# Pattern: ID followed by username in tab-separated or space-separated table format
for line in lines:
    # Check if line contains both a number (ID) and an email
    if re.search(r'\d{4,}') and '@' in line:
        # Try tab-separated format first (most common in admin tables)
        parts = line.split('\t')
        for i, part in enumerate(parts):
            if '@' in part:
                # Email found, username should be the part before it
                if i > 0:
                    username = parts[i-1].strip()
                    # Validate username
                    if username and re.match(r'^[a-zA-Z0-9._-]{2,50}$', username):
                        if username.lower() not in ['sentry', 'traces', 'replays', 'view', 'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december']:
                            print(username)
                            sys.exit(0)
        
        # Try space-separated format
        parts = line.split()
        for i, part in enumerate(parts):
            if '@' in part:
                if i > 0:
                    username = parts[i-1].strip()
                    if username and re.match(r'^[a-zA-Z0-9._-]{2,50}$', username):
                        if username.lower() not in ['sentry', 'traces', 'replays', 'view']:
                            print(username)
                            sys.exit(0)

# Strategy 5: Look for text that appears in header/navigation (often username)
# Common pattern: username appears alone on a line or near "Dashboard", "Admin", etc.
prev_line = ""
for i, line in enumerate(lines):
    lower_line = line.lower()
    if any(word in lower_line for word in ['dashboard', 'admin', 'logout', 'profile']):
        # Check nearby lines for potential username
        if i + 1 < len(lines):
            candidate = lines[i + 1].strip()
            if re.match(r'^[a-zA-Z0-9._-]{2,50}$', candidate) and '@' not in candidate:
                print(candidate)
                sys.exit(0)
PY
    )
    
    if [[ -n "$extracted_username" ]]; then
      USERNAME="$extracted_username"
      echo "Extracted username from admin page: $USERNAME"
    fi
  fi
fi

# If still no username, prompt for it
if [[ -z "$USERNAME" ]]; then
  USERNAME=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Enter username (e.g., jorrit):" with title "Allocate Tokens" default answer "" buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
set username to text returned of result
return username
APPLESCRIPT
  ) || exit 1
fi

# Get token amount if not provided
TOKEN_AMOUNT="${2:-}"
if [[ -z "$TOKEN_AMOUNT" ]]; then
  TOKEN_AMOUNT=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Enter token amount:" with title "Allocate Tokens" default answer "1000000" buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
set amount to text returned of result
return amount
APPLESCRIPT
  ) || exit 1
fi

# Get reason if not provided
REASON="${3:-}"
if [[ -z "$REASON" ]]; then
  REASON=$(/usr/bin/osascript <<APPLESCRIPT
tell application "System Events" to activate
display dialog "Enter reason for token allocation:" with title "Allocate Tokens" default answer "" buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
set reason to text returned of result
return reason
APPLESCRIPT
  ) || exit 1
fi

# Format reason: lowercase and replace spaces/special chars with hyphens
FORMATTED_REASON=$(echo "$REASON" | python3 <<'PYEOF'
import sys
import re
text = sys.stdin.read().strip()
# Convert to lowercase
text = text.lower()
# Replace spaces and underscores with hyphens
text = re.sub(r'[\s_]+', '-', text)
# Remove any non-alphanumeric except hyphens
text = re.sub(r'[^a-z0-9-]', '', text)
# Replace multiple hyphens with single hyphen
text = re.sub(r'-+', '-', text)
# Remove leading/trailing hyphens
text = text.strip('-')
print(text)
PYEOF
)

echo "Username: $USERNAME"
echo "Token amount: $TOKEN_AMOUNT"
echo "Reason: $REASON"
echo "Formatted label: $FORMATTED_REASON"

# Open the token allocation page
ALLOCATION_URL="https://stackblitz.com/admin/user_token_allocations/new"
open "$ALLOCATION_URL"

# Wait for page to load
sleep 2

# Inject JavaScript to fill the form
app=$(echo "${BROWSERS[@]}" | awk '{print $1}')  # Use first available browser
for browser in "${BROWSERS[@]}"; do
  if /usr/bin/osascript -e "application \"$browser\" is running" >/dev/null 2>&1; then
    app="$browser"
    break
  fi
done

# Escape variables for use in JavaScript strings using Python (safer than sed)
escape_js_string() {
  printf '%s' "$1" | python3 <<'PYEOF' | sed 's/^"//;s/"$//'
import sys
import json
text = sys.stdin.read().strip()
print(json.dumps(text))
PYEOF
}

ESCAPED_USERNAME=$(escape_js_string "${USERNAME:-}")
ESCAPED_LABEL=$(escape_js_string "${FORMATTED_REASON:-}")
ESCAPED_TOKENS=$(escape_js_string "${TOKEN_AMOUNT:-}")

# Build the JavaScript code as a here-doc, then escape it for AppleScript
JS_CODE=$(cat <<'JS_EOF'
(function() {
  function parseUtcDateTime(str) {
    const m = str.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) UTC$/);
    if (!m) return null;
    const [_, y, mon, d, h, min, s] = m.map(Number);
    return new Date(Date.UTC(y, mon - 1, d, h, min, s));
  }
  
  function formatUtcDateTime(dt) {
    const pad = (n) => String(n).padStart(2, '0');
    const y = dt.getUTCFullYear();
    const mon = pad(dt.getUTCMonth() + 1);
    const d = pad(dt.getUTCDate());
    const h = pad(dt.getUTCHours());
    const min = pad(dt.getUTCMinutes());
    const s = pad(dt.getUTCSeconds());
    return y + '-' + mon + '-' + d + ' ' + h + ':' + min + ':' + s + ' UTC';
  }
  
  function addOneMonthUTC(dt) {
    const y = dt.getUTCFullYear();
    const m = dt.getUTCMonth();
    const d = dt.getUTCDate();
    const h = dt.getUTCHours();
    const min = dt.getUTCMinutes();
    const s = dt.getUTCSeconds();
    const targetMonth = m + 1;
    const startNextMonth = new Date(Date.UTC(y, targetMonth, 1, h, min, s));
    const lastDayNextMonth = new Date(Date.UTC(y, targetMonth + 1, 0, h, min, s)).getUTCDate();
    const clampedDay = Math.min(d, lastDayNextMonth);
    return new Date(Date.UTC(y, targetMonth, clampedDay, h, min, s));
  }
  
  function byXPath(xp) {
    return document.evaluate(xp, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  }
  
  const userEl = byXPath("//*[@id='user_token_allocation_user_id']");
  const labelEl = byXPath("//*[@id='user_token_allocation_label']");
  const tokensEl = byXPath("//*[@id='user_token_allocation_tokens']");
  const startsEl = byXPath("//*[@id='user_token_allocation_starts_at']");
  const expiresEl = byXPath("//*[@id='user_token_allocation_expires_at']");
  
  if (!userEl || !labelEl || !tokensEl || !startsEl || !expiresEl) {
    console.warn('Some fields were not found. Waiting...');
    return 'ERROR: Fields not found';
  }
  
  const userVal = 'USERNAME_PLACEHOLDER';
  const labelVal = 'LABEL_PLACEHOLDER';
  const tokensVal = 'TOKENS_PLACEHOLDER';
  
  userEl.value = userVal;
  userEl.dispatchEvent(new Event('input', { bubbles: true }));
  userEl.dispatchEvent(new Event('change', { bubbles: true }));
  
  labelEl.value = labelVal;
  labelEl.dispatchEvent(new Event('input', { bubbles: true }));
  labelEl.dispatchEvent(new Event('change', { bubbles: true }));
  
  tokensEl.value = tokensVal;
  tokensEl.dispatchEvent(new Event('input', { bubbles: true }));
  tokensEl.dispatchEvent(new Event('change', { bubbles: true }));
  
  const startsStr = startsEl.value;
  const startsDt = parseUtcDateTime(startsStr);
  if (startsDt) {
    const expiresDt = addOneMonthUTC(startsDt);
    const expiresStr = formatUtcDateTime(expiresDt);
    expiresEl.value = expiresStr;
    expiresEl.dispatchEvent(new Event('input', { bubbles: true }));
    expiresEl.dispatchEvent(new Event('change', { bubbles: true }));
    return 'SUCCESS: Form filled';
  } else {
    return 'ERROR: Could not parse start date';
  }
})();
JS_EOF
)

# Replace placeholders and write directly to temp file
TMP_JS=$(mktemp)
TMP_TEMPLATE=$(mktemp)
TMP_PY=$(mktemp)
printf '%s' "$JS_CODE" > "$TMP_TEMPLATE"
cat > "$TMP_PY" <<'PYEOF'
import sys
import os
tmp_template = sys.argv[1]
tmp_js = sys.argv[2]
escaped_username = sys.argv[3]
escaped_label = sys.argv[4]
escaped_tokens = sys.argv[5]

with open(tmp_template, 'r') as f:
    js_template = f.read()
js_template = js_template.replace('USERNAME_PLACEHOLDER', escaped_username)
js_template = js_template.replace('LABEL_PLACEHOLDER', escaped_label)
js_template = js_template.replace('TOKENS_PLACEHOLDER', escaped_tokens)
with open(tmp_js, 'w') as f:
    f.write(js_template)
PYEOF
python3 "$TMP_PY" "$TMP_TEMPLATE" "$TMP_JS" "$ESCAPED_USERNAME" "$ESCAPED_LABEL" "$ESCAPED_TOKENS"
rm -f "$TMP_TEMPLATE" "$TMP_PY"

# Write AppleScript to temp file to avoid quoting issues
TMP_APPLESCRIPT=$(mktemp)
cat > "$TMP_APPLESCRIPT" <<'APPLESCRIPT_EOF'
tell application APP_PLACEHOLDER
  activate
  delay 1
  
  -- Wait for page to be ready
  set maxTries to 20
  repeat with i from 1 to maxTries
    try
      set theWindow to front window
      set theTab to active tab of theWindow
      set url to URL of theTab
      if url contains "user_token_allocations/new" then
        set state to execute theTab javascript "document.readyState"
        if state is "complete" then exit repeat
      end if
    end try
    delay 0.3
  end repeat
  
  -- Fill the form
  set theWindow to front window
  set theTab to active tab of theWindow
  
  -- Read JavaScript from temporary file
  set jsFile to POSIX file "TMP_JS_PLACEHOLDER"
  set fillScript to read jsFile as «class utf8»
  
  try
    set result to execute theTab javascript fillScript
    return result
  on error errMsg
    return "ERROR: " & errMsg as string
  end try
end tell
APPLESCRIPT_EOF
# Replace placeholders with actual values using a temp Python script
TMP_APPLESCRIPT_FINAL=$(mktemp)
TMP_REPLACE_SCRIPT=$(mktemp)
cat > "$TMP_REPLACE_SCRIPT" <<'PYREPLACE'
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
content = content.replace('APP_PLACEHOLDER', sys.argv[2])
content = content.replace('TMP_JS_PLACEHOLDER', sys.argv[3])
with open(sys.argv[4], 'w') as f:
    f.write(content)
PYREPLACE
python3 "$TMP_REPLACE_SCRIPT" "$TMP_APPLESCRIPT" "$app" "$TMP_JS" "$TMP_APPLESCRIPT_FINAL"
rm -f "$TMP_REPLACE_SCRIPT"
/usr/bin/osascript "$TMP_APPLESCRIPT_FINAL"
rm -f "$TMP_APPLESCRIPT" "$TMP_APPLESCRIPT_FINAL"

# Clean up temporary file
rm -f "$TMP_JS"

echo ""
echo "Form filled successfully!"
echo "Please review and submit the form."

