#!/usr/bin/env node

// Raycast metadata (can also be used directly via `node notion.js ...`)
// @raycast.schemaVersion 1
// @raycast.title Ask Notion AI
// @raycast.mode silent
// @raycast.packageName Notion
// @raycast.icon 📓
// @raycast.argument1 { "type": "text", "placeholder": "Selected Text", "optional": true }
// @raycast.argument2 { "type": "text", "placeholder": "Prompt" }
// @raycast.description Open Notion (web) and submit a prompt to Notion AI with optional selected text as context

const { execSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

function sh(cmd, opts = {}) {
  return execSync(cmd, { stdio: "pipe", encoding: "utf8", ...opts });
}

// Args: 2 = selected text, 3 = prompt, 4 = recipient name
const prompt = process.argv[3] || "";
const selectedText = process.argv[2] || "";
const recipientName = process.argv[4] || "";

// Optional Bolt support profile via env var
const useBoltSupport = process.env.BOLT_SUPPORT === "1";

// Support guidelines tailored for Notion + internal links behavior
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
  "You may see internal-only links (for example Linear, Slack, Google Drive, Notion, or other internal tools). Use these only to understand context.",
  "Do not include or reference these internal links or tools directly in the customer-facing email.",
  "If information comes from internal links, summarize it in your own words instead of exposing the URLs or tool names.",
  "For external links in the email, you may only link to https://support.bolt.new.",
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

// Target Notion URL; allow override via env var
const NOTION_URL = process.env.NOTION_URL || "https://www.notion.so/";

// Open Notion in Chrome, preferring chrome-cli if available
try {
  sh(`chrome-cli open "${NOTION_URL}"`);
} catch (e) {
  sh(`open -a "Google Chrome" "${NOTION_URL}"`);
}

// AppleScript: activate Chrome, open Notion AI chat (Cmd+J), then paste.
// We intentionally do NOT auto-press Return so you can review/edit before sending.
const appleScript = `
tell application "Google Chrome" to activate
delay 1.2
tell application "System Events"
  keystroke "j" using {command down}
  delay 0.8
  keystroke "v" using {command down}
end tell
`;

// Write AppleScript to a temp file to avoid shell escaping issues
const tmpScriptPath = path.join(os.tmpdir(), `notion_ai_autopaste_${Date.now()}.applescript`);
try {
  fs.writeFileSync(tmpScriptPath, appleScript, { encoding: "utf8" });
  execSync(`osascript "${tmpScriptPath}"`, { stdio: "inherit" });
  console.log("Prompt pasted into Notion AI.");
} catch (e) {
  console.warn("Auto-paste failed; prompt is in clipboard. Paste manually in Notion (Cmd+V).");
  console.warn(e.message);
} finally {
  try { fs.unlinkSync(tmpScriptPath); } catch (_) {}
}

process.exit(0);


