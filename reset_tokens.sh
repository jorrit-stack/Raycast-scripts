#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Reset Tokens
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.argument1 { "type": "text", "placeholder": "UserID from clipboard" }
# @raycast.argument2 { "type": "text", "placeholder": "Type: monthly or all" }

# Documentation:
# @raycast.description Reset monthly tokens or all tokens for a user
# @raycast.author Jorrit Harmamny
# @raycast.authorURL https://raycast.com/jorrit_harmamny6493459

USERID="$1"
TYPE="$2"

if [[ "$TYPE" == "monthly" ]]; then
    echo "Opening monthly tokens reset for UserID: $USERID"
    open "https://bolt.new/api/rate-limits/$USERID"
elif [[ "$TYPE" == "all" ]]; then
    echo "Opening all tokens reset (including rollovers) for UserID: $USERID"
    open "https://bolt.new/api/rate-limits/reset/$USERID/all"
else
    echo "Invalid type. Please enter 'monthly' or 'all'."
fi