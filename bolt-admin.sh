#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bolt-admin
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "UserID or Email" }

# Documentation:
# @raycast.description bolt-admin-email-lookup
# @raycast.author jorrit_harmamny
# @raycast.authorURL https://raycast.com/jorrit_harmamny

input="$1"

if [[ "$input" =~ ^[0-9]+$ ]]; then
  # If input is only digits, treat as ID
  url="https://stackblitz.com/admin/users?q%5Bid_eq%5D=${brian@bowtaifitness.com3394367&commit=Filter&order=id_desc"
else
  # Otherwise, treat as email
  encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$input")
  url="https://stackblitz.com/admin/users?q%5Bby_email_address%5D=${encoded}&commit=Filter&order=id_desc"
fi

open "$url"