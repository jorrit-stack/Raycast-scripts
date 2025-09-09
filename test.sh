#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Search Front Conversations
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📧
# @raycast.argument1 { "type": "text", "placeholder": "Search term" }

# Documentation:
# @raycast.description Search Front conversations by subject
# @raycast.author Your Name

FRONT_API_TOKEN="your_front_api_token"
SEARCH_TERM="$1"

curl -s -H "Authorization: Bearer $FRONT_API_TOKEN" \
  "https://api2.frontapp.com/conversations?q=$SEARCH_TERM" | jq .

  # Example: Get conversation details by ID
curl -s -H "Authorization: Bearer $FRONT_API_TOKEN" \
  "https://api2.frontapp.com/conversations/90194786129" | jq .