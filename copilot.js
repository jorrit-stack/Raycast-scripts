#!/usr/bin/env node

// @raycast.schemaVersion 1
// @raycast.title Ask Copilot
// @raycast.mode silent
// @raycast.packageName Copilot
// @raycast.icon 🤖
// @raycast.argument1 { "type": "text", "placeholder": "Selected Text", "optional": true }
// @raycast.argument2 { "type": "text", "placeholder": "Prompt" }
// @raycast.description Open Microsoft Copilot in Chrome and submit a prompt with optional selected text as context

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
const useCopilotApp = process.env.COPILOT_APP === "1";
const useBoltSupport = process.env.BOLT_SUPPORT === "1";

// Common rules
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

// Optional Bolt support profile (match Gemini guidance exactly)
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

const baseBlock = commonRules.join("\n");
const mergedInstructions = (() => {
  if (!useBoltSupport) {
    if (prompt && prompt.trim() !== "") return [baseBlock, prompt].filter(Boolean).join("\n\n");
    return baseBlock;
  }
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

let appleScript = "";

if (useCopilotApp) {
  // Use the macOS Copilot app; just activate and paste into current chat
  try {
    // Prefer explicit path if available
    const explicitPath = "/System/Volumes/Data/Applications/Copilot.app";
    try {
      sh(`open -a "${explicitPath}"`);
    } catch (_) {
      // Fall back to common app names
      try { sh('open -a "Copilot"'); } catch (__) {
        try { sh('open -a "Microsoft Copilot"'); } catch (___) {
          // Try by bundle id as last resort
          try { sh('open -b com.microsoft.copilot'); } catch (____) {}
        }
      }
    }
  } catch (e) {
    console.error("Failed to open Microsoft Copilot app:", e.message);
  }
  appleScript = `
try
  tell application "Copilot" to activate
on error
  try
    tell application "Microsoft Copilot" to activate
  on error
    try
      tell application id "com.microsoft.copilot" to activate
    on error
      -- If all fails, do nothing; System Events will still paste to frontmost app if any
    end try
  end try
end try
delay 1.0
tell application "System Events" to keystroke "v" using {command down}
delay 0.2
tell application "System Events" to key code 36
`;
} else {
  // Web flow (Chrome). This may open a new tab; acceptable for web usage.
  try {
    sh('open -a "Google Chrome"');
  } catch (e) {
    console.error("Failed to open Google Chrome:", e.message);
  }
  const COPILOT_URL = "https://copilot.microsoft.com/";
  try {
    sh(`chrome-cli open "${COPILOT_URL}"`);
  } catch (e) {
    sh(`open -a "Google Chrome" "${COPILOT_URL}"`);
  }
  appleScript = `
tell application "Google Chrome" to activate
delay 1.0
tell application "System Events" to keystroke "v" using {command down}
delay 0.3
tell application "System Events" to key code 36
`;
}

const tmpScriptPath = path.join(os.tmpdir(), `copilot_autopaste_${Date.now()}.applescript`);
try {
  fs.writeFileSync(tmpScriptPath, appleScript, { encoding: "utf8" });
  execSync(`osascript "${tmpScriptPath}"`, { stdio: "inherit" });
  console.log("Prompt pasted into Copilot.");
} catch (e) {
  console.warn("Auto-paste failed; prompt is in clipboard. Paste manually (Cmd+V).");
  console.warn(e.message);
} finally {
  try { fs.unlinkSync(tmpScriptPath); } catch (_) {}
}

process.exit(0);


