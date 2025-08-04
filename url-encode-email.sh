#!/bin/bas#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title URL Encode and Open Stackblitz User
# @raycast.mode silent
# @raycast.argument1 { "type": "text", "placeholder": "Email address" }

email="$1"
encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$email")
url="https://stackblitz.com/admin/users?q%5Bby_email_address%5D=${encoded}&commit=Filter&order=id_desc"
open "$url"