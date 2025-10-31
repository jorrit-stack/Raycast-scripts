#!/bin/zsh

# @raycast.schemaVersion 1
# @raycast.title Reply (Bolt Support)
# @raycast.mode silent
# @raycast.icon 🧷
# @raycast.packageName Gemini
# @raycast.currentDirectoryPath /Users/jorritharmamny/Documents/Raycast-scripts
# @raycast.needsConfirmation false
# @raycast.argument1 { "type": "text", "placeholder": "Additional instructions (tone, specifics)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Recipient name (optional)", "optional": true }

instructions="$1"
recipient_name="$2"
email_content=$(pbpaste)

if [ -z "$email_content" ]; then
  echo "Clipboard is empty. Copy the email content first." >&2
  exit 1
fi

# Enable Bolt support profile and delegate to launcher
export BOLT_SUPPORT=1
node ./gemini.js "$email_content" "$instructions" "$recipient_name"

echo "Prepared Bolt support reply for Gemini."


