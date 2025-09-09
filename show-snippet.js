#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Show Snippet Pretty
// @raycast.mode fullOutput
// @raycast.icon 📝
// @raycast.argument1 { "type": "text", "placeholder": "Snippet JSON file path", "optional": true }
// Documentation:
// @raycast.description Pretty-print a JSON snippet file, replacing {clipboard} with clipboard contents
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrit_harmamny

const fs = require("fs");
const { execSync } = require("child_process");
const path = require("path");

// Get file path from argument or use default
const filePath = process.argv[2] || path.join(__dirname, "Snippets 2025-07-30 18.37.11.json");

// Get clipboard contents
let clipboard = "";
try {
  clipboard = execSync("pbpaste").toString().trim();
} catch {
  clipboard = "";
}

// Read and parse JSON
let data;
try {
  const raw = fs.readFileSync(filePath, "utf8");
  data = JSON.parse(raw);
} catch (e) {
  console.error("Failed to read or parse JSON file:", e.message);
  process.exit(1);
}

// Replace {clipboard} in all string values
function replaceClipboard(obj) {
  if (typeof obj === "string") {
    return obj.replace(/\{clipboard\}/g, clipboard);
  } else if (Array.isArray(obj)) {
    return obj.map(replaceClipboard);
  } else if (typeof obj === "object" && obj !== null) {
    const out = {};
    for (const key in obj) {
      out[key] = replaceClipboard(obj[key]);
    }
    return out;
  }
  return obj;
}

const replaced = replaceClipboard(data);

// Pretty print
console.log(JSON.stringify(replaced, null, 2));