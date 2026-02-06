#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Add 2 Months to Clipboard Date
// @raycast.mode silent
// @raycast.packageName Date Utils
// @raycast.icon 📅
// Documentation:
// @raycast.description Add 2 months to a date in clipboard (format: YYYY-MM-DD HH:MM:SS UTC)
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrit_harmamny

const { execSync } = require('child_process');

function addMonths(date, months) {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
}

try {
  const clipboardContent = execSync('pbpaste', { encoding: 'utf-8' }).trim();
  
  // Parse custom format: "2026-02-06 13:53:18 UTC"
  const dateMatch = clipboardContent.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+UTC$/);
  
  let date;
  if (dateMatch) {
    // Parse the matched format
    const [, year, month, day, hours, minutes, seconds] = dateMatch;
    date = new Date(`${year}-${month}-${day}T${hours}:${minutes}:${seconds}Z`);
  } else {
    // Fallback: try to parse as-is
    date = new Date(clipboardContent);
  }
  
  if (isNaN(date.getTime())) {
    console.log("❌ Not a valid date format");
    process.exit(1);
  }
  
  const newDate = addMonths(date, 2);
  const result = newDate.toISOString().replace('T', ' ').replace(/\.\d{3}Z/, ' UTC');
  
  execSync('pbcopy', { input: result });
  console.log(`✅ Copied: ${result}`);
} catch (error) {
  console.log(`❌ ${error.message}`);
}