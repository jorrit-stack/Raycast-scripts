#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bolt-admin
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Placeholder" }

# Documentation:
# @raycast.description bolt-admin-email-lookup
# @raycast.author jorrit_harmamny
# @raycast.authorURL https://raycast.com/jorrit_harmamny


email="$1"
encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$email")
url="https://stackblitz.com/admin/users?q%5Bby_email_address%5D=${encoded}&commit=Filter&order=id_desc"
open "$url"