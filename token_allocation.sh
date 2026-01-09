// rayscript: fill StackBlitz "New User Token Allocation" form and set expiry one month later

(function () {
  // Helper: parse "YYYY-MM-DD HH:mm:ss UTC" into Date in UTC
  function parseUtcDateTime(str) {
    // Expect: 2025-12-16 17:10:15 UTC
    const m = str.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) UTC$/);
    if (!m) return null;
    const [_, y, mon, d, h, min, s] = m.map(Number);
    // Date.UTC uses 0-based month
    return new Date(Date.UTC(y, mon - 1, d, h, min, s));
  }

  // Helper: format Date back to "YYYY-MM-DD HH:mm:ss UTC"
  function formatUtcDateTime(dt) {
    const pad = (n) => String(n).padStart(2, '0');
    const y = dt.getUTCFullYear();
    const mon = pad(dt.getUTCMonth() + 1);
    const d = pad(dt.getUTCDate());
    const h = pad(dt.getUTCHours());
    const min = pad(dt.getUTCMinutes());
    const s = pad(dt.getUTCSeconds());
    return `${y}-${mon}-${d} ${h}:${min}:${s} UTC`;
  }

  // Helper: add one calendar month, clamping day if necessary
  function addOneMonthUTC(dt) {
    const y = dt.getUTCFullYear();
    const m = dt.getUTCMonth();
    const d = dt.getUTCDate();
    const h = dt.getUTCHours();
    const min = dt.getUTCMinutes();
    const s = dt.getUTCSeconds();

    // Move to next month, clamp day to last day of that month
    const targetMonth = m + 1;
    // Start with day 1 of next month, then compute last day
    const startNextMonth = new Date(Date.UTC(y, targetMonth, 1, h, min, s));
    const lastDayNextMonth = new Date(Date.UTC(y, targetMonth + 1, 0, h, min, s)).getUTCDate();
    const clampedDay = Math.min(d, lastDayNextMonth);

    return new Date(Date.UTC(y, targetMonth, clampedDay, h, min, s));
  }

  function byXPath(xp) {
    return document.evaluate(xp, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  }

  const userEl = byXPath("//*[@id='user_token_allocation_user_id']");
  const labelEl = byXPath("//*[@id='user_token_allocation_label']");
  const tokensEl = byXPath("//*[@id='user_token_allocation_tokens']");
  const startsEl = byXPath("//*[@id='user_token_allocation_starts_at']");
  const expiresEl = byXPath("//*[@id='user_token_allocation_expires_at']");

  if (!userEl || !labelEl || !tokensEl || !startsEl || !expiresEl) {
    console.warn("Some fields were not found. Check XPaths.");
    return;
  }

  // Use page-provided values when present
  const userVal = "jorrit@stackblitz.com"; // Visible on page header
  const labelVal = "monthly allocation";
  const tokensVal = "1000000";

  userEl.value = userVal;
  userEl.dispatchEvent(new Event('input', { bubbles: true }));
  userEl.dispatchEvent(new Event('change', { bubbles: true }));

  labelEl.value = labelVal;
  labelEl.dispatchEvent(new Event('input', { bubbles: true }));
  labelEl.dispatchEvent(new Event('change', { bubbles: true }));

  tokensEl.value = tokensVal;
  tokensEl.dispatchEvent(new Event('input', { bubbles: true }));
  tokensEl.dispatchEvent(new Event('change', { bubbles: true }));

  const startsStr = startsEl.value;
  const startsDt = parseUtcDateTime(startsStr);
  if (!startsDt) {
    console.warn("Starts at field has unexpected format:", startsStr);
    return;
  }

  const expiresDt = addOneMonthUTC(startsDt);
  const expiresStr = formatUtcDateTime(expiresDt);

  expiresEl.value = expiresStr;
  expiresEl.dispatchEvent(new Event('input', { bubbles: true }));
  expiresEl.dispatchEvent(new Event('change', { bubbles: true }));

  console.log("Filled form with expiry one month after start:", { startsStr, expiresStr });
})();
