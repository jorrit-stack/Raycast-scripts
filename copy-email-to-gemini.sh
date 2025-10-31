#!/bin/zsh

# @raycast.schemaVersion 1
# @raycast.title Reply with AI (Gemini)
# @raycast.mode silent
# @raycast.icon ✉️
# @raycast.packageName Gemini
# @raycast.currentDirectoryPath /Users/jorritharmamny/Documents/Raycast-scripts
# @raycast.needsConfirmation false
# @raycast.argument1 { "type": "text", "placeholder": "Instructions (tone, key points, language)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Recipient name (optional)", "optional": true }

instructions="$1"
recipient_name="$2"

# Read email content from clipboard
email_content=$(pbpaste)

if [ -z "$email_content" ]; then
  echo "Clipboard is empty. Copy the email content first." >&2
  exit 1
fi

# Delegate to existing Gemini launcher which copies the composed prompt and opens Gemini
node ./gemini.js "$email_content" "$instructions" "$recipient_name"

echo "Prepared reply context for Gemini (prompt copied)."


