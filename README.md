# Raycast Scripts

Custom Raycast commands to speed up common support/admin flows (StackBlitz admin, Bolt rate limits, token resets) and a few utilities.

## Prerequisites

- macOS with Raycast installed
- jq for pretty JSON (optional, recommended): `brew install jq`
- Accessibility permissions for Raycast and your browser (System Settings → Privacy & Security → Accessibility)
- To let scripts read page text from Chromium browsers, enable in the browser:
  - “Allow JavaScript from Apple Events” (Chrome: Preferences → Privacy & Security → Site Settings → Additional permissions)

Supported browsers for browser‑automation steps: Google Chrome, Brave, Microsoft Edge, Arc, Chromium, Dia.

## Common Workflow (Admin)

1) Use `bolt-admin.sh` to open StackBlitz admin filtered by user ID or email.
2) Run `copy-user-id-from-browser.sh` to copy the UserID from the visible page.
   - Works with: JS read, selected row, or fallback “copy all page text”.
3) Run `user-admin-actions.sh` to:
   - Show rate limits (via your signed‑in browser),
   - Open rate limits page,
   - Reset tokens (Monthly or All), with pre and post views.

## Script Catalog

### copy-user-id-from-browser.sh
- Raycast: Copy UserID from Admin Page
- Purpose: Extract numeric UserID from the frontmost Chromium-based admin page and copy to clipboard.
- How it works:
  - Tries to read URL/title/text via Apple Events (JS). If disabled, it falls back to selection or full page copy.
  - Extracts ID using URL patterns, “ID” context, or first 6+ digit number.
- Output: Prints detected browser, page info, and copies the ID.
- Post menu: Show/Open rate limits, Reset Tokens (Monthly/All) with pre/post rate limit views.

### user-admin-actions.sh
- Raycast: User Admin Actions
- Purpose: Use clipboard (or argument) UserID to manage rate limits and resets.
- Options:
  - Show Rate Limits: opens JSON in signed‑in browser and pretty‑prints it in Raycast.
  - Open Rate Limits: opens `https://bolt.new/api/rate-limits/<id>`.
  - Reset Tokens: prompts Monthly or All, confirms, opens pre view, executes reset endpoint (`/reset/<id>/month` or `/reset/<id>/all`), then opens post view.

### bolt-admin.sh
- Raycast: bolt-admin
- Purpose: Open StackBlitz Admin filtered by numeric ID or email.
- Usage: Provide UserID or Email; it auto‑detects and opens the correct admin URL.

### open-user-url.js
- Raycast: Open Bolt Rate Limits
- Purpose: Open Bolt API rate limits for the clipboard user ID.
- Usage: Copy UserID → Run → Opens `https://bolt.new/api/rate-limits/{id}`.

### token-snippet.sh
- Raycast: Show Rate Limits
- Purpose: Fetch and pretty‑print a user’s rate limits.
- Modes:
  - default: pretty print with `jq` (requires auth if run via browser; direct curl requires network auth context).
  - `browser`: open the rate limits page in browser.

### reset_tokens.sh
- Raycast: Reset Tokens
- Purpose: Open monthly or all‑tokens reset pages for a given UserID.
- Usage: Arg1: UserID, Arg2: `monthly` or `all`.

### show-snippet.js
- Raycast: Show Snippet Pretty
- Purpose: Pretty-print a JSON snippet file, replacing `{clipboard}` placeholders with clipboard contents.
- Usage: Provide optional path; falls back to default snippet JSON.

### copy-email-to-copilot.sh / copy-email-to-gemini.sh / copilot.js / gemini.js
- Purpose: Email→AI utilities for Copilot/Gemini workflows.
- Usage: Follow on‑screen prompts or read script headers.

### reply_bolt_support.sh
- Purpose: Helper for replying to Bolt support.

### url-encode-email.sh
- Purpose: URL-encode an email string (handy for admin URLs).

### localhost.sh / test.sh / mailbox_with_mail.sh
- Misc utilities; see script headers for exact behavior.

## Troubleshooting

- “Could not find a numeric UserID on the current page”
  - Select the table row containing the ID and run again, or
  - Enable “Allow JavaScript from Apple Events”, or
  - Ensure the admin Users page actually contains a numeric ID in the visible text.

- “Could not read JSON from the browser” (Show Rate Limits)
  - Enable “Allow JavaScript from Apple Events”, or use “Open Rate Limits”.

- Nothing happens when opening tabs
  - Check default browser is supported and running. Grant Accessibility permissions to Raycast and the browser.

## Notes

- All scripts are designed to keep the UserID in your clipboard so they compose well.
- The reset flows intentionally show pre and post rate‑limit pages for quick visual confirmation.
