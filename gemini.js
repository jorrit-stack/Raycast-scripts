#!/usr/bin/env node
// filename: ask-gemini.js

// Dependencies:
// - node (https://nodejs.org)
// - chrome-cli (https://github.com/prasmussen/chrome-cli) via Homebrew: brew install chrome-cli
//
// macOS permissions (REQUIRED):
// - System Settings > Privacy & Security > Accessibility:
//   - Enable for: Terminal (if running via terminal), Raycast (if running via Raycast), and "Google Chrome"
// - System Settings > Privacy & Security > Automation:
//   - Allow your calling app (Terminal/Raycast) to control "Google Chrome" and "System Events"
// Chrome setting (REQUIRED):
// - In Chrome: View > Developer > Allow JavaScript from Apple Events (older versions) or enable "Allow Apple Events from JavaScript"
//   If that menu isn't visible, it's typically gated behind chrome://flags; otherwise the DOM injection below uses AppleScript "do JavaScript" without needing that flag.
//
// Raycast parameters:
// @raycast.schemaVersion 1
// @raycast.title Ask Gemini
// @raycast.mode silent
// @raycast.packageName Gemini
// @raycast.icon 🥽
// @raycast.argument1 { "type": "text", "placeholder": "Selected Text", "optional": true }
// @raycast.argument2 { "type": "text", "placeholder": "Prompt"}
// @raycast.description Open Gemini in Chrome Browser and submit a prompt with optional selected text as context
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrit_harmamny

const { execSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

function sh(cmd, opts = {}) {
  return execSync(cmd, { stdio: "pipe", encoding: "utf8", ...opts });
}

const prompt = process.argv[3] || "";
const selectedText = process.argv[2] || "";
const recipientName = process.argv[4] || "";

// Optional Bolt support profile via env var
const useBoltSupport = process.env.BOLT_SUPPORT === "1";
const boltGuidelines = [
  "You are a bolt.new support agent.",
  "Your task is to draft a clear, professional email reply to the customer.",
  "Prefer answers aligned with the official docs: https://support.bolt.new",
  "If uncertain, consult and cite relevant pages from https://support.bolt.new.",
  "Show empathy: acknowledge the user's situation and reassure we're here to help.",
  "Assume the user is non-technical: avoid jargon and explain steps simply.",
  "Prefer solutions using Bolt's interface, prompts, or built-in features rather than code changes.",
  "If code is unavoidable, provide clear, minimal, step-by-step guidance or link to docs.",
  "Offer short, actionable steps (bulleted if helpful). Keep it concise.",
  "Do not use emojis.",
  "Do not use em dashes (—); use a regular hyphen (-) instead.",
].join("\n");

// Common rules applied always
const commonRules = [];
if (recipientName && recipientName.trim() !== "") {
  commonRules.push(
    `If the email context doesn't include a recipient name, address them by name: ${recipientName}. Start with a friendly greeting using their name (for example: "Hi ${recipientName},").`
  );
} else {
  commonRules.push(
    'If you do not know the customer name, start with a generic friendly greeting such as "Hi there,".'
  );
}
commonRules.push(
  "You may end the email with a short generic closing (for example: Best, Best regards, or similar) but do not include my name in the closing, as my email client will add my signature automatically."
);

const baseBlock = commonRules.join("\n");

const mergedInstructions = (() => {
  if (!useBoltSupport) {
    if (prompt && prompt.trim() !== "") return [baseBlock, prompt].filter(Boolean).join("\n\n");
    return baseBlock;
  }
  // Bolt profile
  const withBolt = [baseBlock, boltGuidelines].filter(Boolean).join("\n");
  if (prompt && prompt.trim() !== "") return `${withBolt}\n\nAdditional instructions from user:\n${prompt}`;
  return withBolt;
})();

const finalPrompt =
  selectedText && selectedText.trim() !== ""
    ? `Context (from email):\n\n${selectedText}\n\nInstructions:\n${mergedInstructions || ""}`
    : `Instructions:\n${mergedInstructions || ""}`;

// Copy prompt to clipboard
try {
  sh(`printf %s "${finalPrompt.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}" | pbcopy`);
} catch (e) {
  console.error("Failed to copy to clipboard:", e.message);
}

// Ensure Chrome is running
try {
  sh('open -a "Google Chrome"');
} catch (e) {
  console.error("Failed to open Google Chrome:", e.message);
}

// Open Gemini in Chrome explicitly via chrome-cli (uses existing window)
try {
  // If chrome-cli is not installed, this will throw
  sh('chrome-cli open "https://gemini.google.com/app"');
} catch (e) {
  // Fallback: use `open` if chrome-cli isn't available
  sh('open -a "Google Chrome" "https://gemini.google.com/app"');
}

// AppleScript: activate Chrome and paste (keep it simple to avoid syntax issues)
const appleScript = `
tell application "Google Chrome" to activate
delay 0.9
tell application "System Events" to keystroke "v" using {command down}
delay 0.2
tell application "System Events" to key code 36 -- press Return to submit
`;

// Write AppleScript to a temp file to avoid shell escaping issues
const tmpScriptPath = path.join(os.tmpdir(), `gemini_autopaste_${Date.now()}.applescript`);
try {
  fs.writeFileSync(tmpScriptPath, appleScript, { encoding: "utf8" });
  execSync(`osascript "${tmpScriptPath}"`, { stdio: "inherit" });
  console.log("Prompt pasted into Gemini.");
} catch (e) {
  console.warn("Auto-paste failed; prompt is in clipboard. Paste manually (Cmd+V).");
  console.warn(e.message);
} finally {
  try { fs.unlinkSync(tmpScriptPath); } catch (_) {}
}

process.exit(0);
