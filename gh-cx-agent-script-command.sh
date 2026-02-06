#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Paste prompt into terminal
# @raycast.mode silent

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Prompt" }

PROMPT="$1"

osascript <<EOF
tell application "System Events"
  keystroke "claude " & quoted form of "$PROMPT"
  key code 36 -- Return
end tell
EOF
