#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Open Bolt Rate Limits
// @raycast.mode silent
// @raycast.icon 🚀
// Documentation:
// @raycast.description Open Bolt API rate limits page for user ID from clipboard
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrith_harmamny

const { execSync } = require("child_process");

// Template URL with {clipboard} placeholder
const templateUrl = "https://bolt.new/api/rate-limits/{clipboard}";

// Get clipboard contents (user ID)
let clipboard = "";
try {
  clipboard = execSync("pbpaste").toString().trim();
} catch {
  clipboard = "";
}

if (!clipboard) {
  console.error("Clipboard is empty. Copy a user ID first.");
  process.exit(1);
}

// Replace {clipboard} in URL
const url = templateUrl.replace("{clipboard}", encodeURIComponent(clipboard));

// Open the URL in the default browser
execSync(`open "${url}"`);

console.log(`Opened: ${url}`);