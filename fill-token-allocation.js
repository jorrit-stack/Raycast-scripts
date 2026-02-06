#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Fill Token Allocation Form
// @raycast.mode fullOutput
// @raycast.packageName Admin Tools
// @raycast.icon 🎫
// @raycast.argument1 { "type": "text", "placeholder": "Token amount in millions (1-200)", "optional": false }
//
// Documentation:
// @raycast.description Generate token allocation form data. Gets username from clipboard, uses current UTC time, calculates expires at (+2 months)
// @raycast.author jorrit_harmamny
// @raycast.authorURL https://raycast.com/jorrit_harmamny

const { execSync } = require('child_process');

function addMonths(dateStr, months) {
  const dateMatch = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+UTC$/);
  if (!dateMatch) return null;
  
  const [, year, month, day, hours, minutes, seconds] = dateMatch;
  const date = new Date(`${year}-${month}-${day}T${hours}:${minutes}:${seconds}Z`);
  date.setMonth(date.getMonth() + months);
  return date.toISOString().replace('T', ' ').replace(/\.\d{3}Z/, ' UTC');
}

function formatTokens(num) {
  const n = parseInt(num);
  if (n >= 1000000) {
    return (n / 1000000).toFixed(0) + 'M';
  }
  return num;
}

try {
  const tokenInput = process.argv[2];
  
  // Generate current UTC date/time in format: YYYY-MM-DD HH:MM:SS UTC
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const day = String(now.getUTCDate()).padStart(2, '0');
  const hours = String(now.getUTCHours()).padStart(2, '0');
  const minutes = String(now.getUTCMinutes()).padStart(2, '0');
  const seconds = String(now.getUTCSeconds()).padStart(2, '0');
  const startsAt = `${year}-${month}-${day} ${hours}:${minutes}:${seconds} UTC`;
  
  // Convert millions to actual token count
  const tokenMillions = parseInt(tokenInput);
  if (isNaN(tokenMillions) || tokenMillions < 1 || tokenMillions > 200) {
    console.log('❌ Token amount must be between 1 and 200 million');
    process.exit(1);
  }
  
  const tokenAmount = tokenMillions * 1000000;
  
  // Get username from clipboard
  const username = execSync('pbpaste', { encoding: 'utf-8' }).trim();
  if (!username) {
    console.log('❌ Clipboard is empty (copy username first)');
    process.exit(1);
  }
  
  // Calculate expires at (+2 months)
  const expiresAt = addMonths(startsAt, 2);
  if (!expiresAt) {
    console.log('❌ Invalid date format for "Starts at"');
    process.exit(1);
  }
  
  // Copy all values to clipboard as a formatted list
  const formData = `User: ${username}
Label: support-tokens
Tokens: ${tokenAmount}
Starts at: ${startsAt}
Expires at: ${expiresAt}`;
  
  execSync('pbcopy', { input: formData });
  
  console.log('✅ Form values ready!');
  console.log('');
  console.log(`User:        ${username}`);
  console.log(`Label:       support-tokens`);
  console.log(`Tokens:      ${tokenAmount} (${formatTokens(tokenAmount)})`);
  console.log(`Starts at:   ${startsAt}`);
  console.log(`Expires at:  ${expiresAt}`);
  console.log('');
  console.log('📋 All values copied to clipboard');
} catch (error) {
  console.log(`❌ ${error.message}`);
}
