#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Front Email Search
# @raycast.mode silent
# Optional parameters:
# @raycast.icon :mailbox_with_mail:
# Documentation:
# @raycast.description Opens Front workspace search using clipboard email
# @raycast.author tyler
# @raycast.authorURL https://github.com/tbrei
email=$(pbpaste)
encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$email'''))")
# Replace with your actual teammate ID and a valid thread ID (any real one works)
teammate_id="[ENTER HERE]"
thread_id="[ENTER HERE]"
url="https://app.frontapp.com/inboxes/teammates/${teammate_id}/inbox/all/${thread_id}/search/workspace/${encoded}/0"
open "$url"