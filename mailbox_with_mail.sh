#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Front Email Search
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📬
# @raycast.argument1 { "type": "text", "placeholder": "Email (leave blank for clipboard)", "optional": true }

# Documentation:
# @raycast.description Opens Front workspace search using clipboard or pasted email
# @raycast.author tyler
# @raycast.authorURL https://github.com/tbrei

input="$1"
if [[ -z "$input" ]]; then
  email=$(pbpaste)
else
  email="$input"
fi

encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$email")
team_id="4808209"
url="https://app.frontapp.com/inboxes/teams/${team_id}/search/workspace/${encoded}/0"
open "$url"