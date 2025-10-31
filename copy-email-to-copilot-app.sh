#!/bin/zsh

# @raycast.schemaVersion 1
# @raycast.title Reply with AI (Copilot App)
# @raycast.mode silent
# @raycast.icon 🤖
# @raycast.packageName Copilot
# @raycast.currentDirectoryPath /Users/jorritharmamny/Documents/Raycast-scripts
# @raycast.needsConfirmation false
# @raycast.argument1 { "type": "text", "placeholder": "Instructions (tone, key points, language)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Recipient name (optional)", "optional": true }

instructions="$1"
recipient_name="$2"

email_content=$(pbpaste)

if [ -z "$email_content" ]; then
  echo "Clipboard is empty. Copy the email content first." >&2
  exit 1
fi

export COPILOT_APP=1
node ./copilot.js "$email_content" "$instructions" "$recipient_name"

echo "Prepared reply in Copilot app (appended to current chat)."


