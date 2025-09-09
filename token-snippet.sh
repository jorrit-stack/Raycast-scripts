#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Show Rate Limits
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📝
# @raycast.argument1 { "type": "text", "placeholder": "UserID" }
# @raycast.argument2 { "type": "text", "placeholder": "Mode: pretty or browser", "optional": true }

# Documentation:
# @raycast.description Show or open rate limits for a user
# @raycast.author Jorrit Harmamny

USERID="$1"
MODE="$2"

URL="https://bolt.new/api/rate-limits/$USERID"

if [[ "$MODE" == "browser" ]]; then
    open "$URL"
    exit 0
fi

if ! command -v jq &> /dev/null; then
    echo "jq is required for pretty-printing JSON. Install with: brew install jq"
    exit 1
fi

echo "Fetching rate limits for UserID: $USERID"
JSON=$(curl -s "$URL")

if [[ -z "$JSON" ]]; then
    echo "No data returned. Check UserID or network."
    exit 1
fi

echo "$JSON" | jq .

# Optionally, extract some key stats:
echo ""
echo "Token usage today: $(echo "$JSON" | jq '.tokenStats.totalToday')"
echo "Token usage this month: $(echo "$JSON" | jq '.tokenStats.totalThisMonth')"
echo "Max per day: $(echo "$JSON" | jq '.tokenStats.maxPerDay')"
echo "Max per month: $(echo "$JSON" | jq '.tokenStats.maxPerMonth')"