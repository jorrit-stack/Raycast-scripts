#!/usr/bin/env node

// Dependencies:
// This script requires the following software to be installed:
// - `node` https://nodejs.org
// - `chrome-cli` https://github.com/prasmussen/chrome-cli
// Install via homebrew: `brew install node chrome-cli`

// This script needs to run JavaScript in your browser, which requires your permission.
// To do so, open Chrome and find the menu bar item:
// View > Developer > Allow JavaScript from Apple Events

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Ask Gemini
// @raycast.mode silent
// @raycast.packageName Gemini

// Optional parameters:
// @raycast.icon 🥽
// @raycast.argument1 { "type": "text", "placeholder": "Selected Text", "optional": true }
// @raycast.argument2 { "type": "text", "placeholder": "Prompt"}

// Documentation:
// @raycast.description Open Gemini in Chrome Browser and submit a prompt with optional selected text as context
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrit_harmamny


const { execSync } = require("child_process");

const prompt = process.argv[3] || "";
const selectedText = process.argv[2] || "";

const finalPrompt = selectedText && selectedText.trim() !== ""
  ? `<file_content>${selectedText}</file_content>\n\n${prompt}`
  : prompt;

// Copy prompt to clipboard for convenience
require("child_process").execSync(`echo "${finalPrompt.replace(/"/g, '\\"')}" | pbcopy`);

// Open Gemini in the default browser
require("child_process").execSync('open "https://gemini.google.com/app"');

console.log("Prompt copied to clipboard. Paste it into Gemini.");
process.exit(0);

