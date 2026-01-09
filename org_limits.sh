how easy would it be te create a script (preferably for raycast) that after getting to this page, clicks the ID (in this case 3379271) and then on the next page finds the orginisation clicks that id and then opens all "token stats" for every org user.

Great idea—this is very scriptable. Since this Admin UI looks like a standard server-rendered ActiveAdmin page, we can automate it reliably with a browser automation tool. For Raycast, the cleanest approach is to use a Node-based script that Raycast runs via a Script Command or a Raycast Extension, and drive the browser with Playwright. This avoids brittle “click at screen coordinates” and works regardless of window position.

Plan

1. Navigate and click the User ID on the Users page

- Load the Users page (you’ll already be there) and click the link in the ID column (e.g., 3379271).

2. On the user detail page, find the organization link and click it

- Locate the organization section on the user page (ActiveAdmin typically shows associations as links). Click the organization ID/link.

3. On the organization page, open Token Stats for every org user

- Go to the org’s Users tab/list.

- For each user row, click a “Token Stats” link or open the user page and then open Token Stats.

- Open each in a new tab and bring them forward or keep them backgrounded.

4. Wire into Raycast

- Add this as a Raycast Script Command or build a Raycast extension command.

- Optionally accept parameters: user ID, org ID, environment, etc.

Below is a complete Playwright script you can run directly, and then integrate with Raycast. It assumes:

- You’re already authenticated (we’ll reuse a stored browser context).

- The page structure matches what you showed: the Users page with an ID link, then a user details page containing an organization link, then an org page listing users with “Token Stats” available.

- Environment base URL is passed in.

If the org users’ “Token Stats” links are not directly in the table, the script will click into each user and then find “Token Stats” there.

Node.js script using Playwright// filename: open_token_stats.js

// Usage:

//   1) Install deps: npm i playwright

//   2) Run: node open_token_stats.js --baseUrl=https://stackblitz.com --userId=3379271

//

// This script automates:

// - On the Users index, clicks the given user ID link

// - On the user detail page, finds and clicks the organization link

// - On the organization page, opens all "Token Stats" pages for every org user in new tabs

//

// Notes:

// - Uses a persistent Chromium context so your logged-in session can be reused.

// - If you’re not logged in in the saved profile, log in once manually and rerun.

// - Adjust selectors if your ActiveAdmin theme differs.

const { chromium } = require('playwright');

function getArg(name, defaultValue = undefined) {

  const arg = process.argv.find((a) => a.startsWith(`--${name}=`));

  if (!arg) return defaultValue;

  return arg.split('=')[1];

}

(async () => {

  const baseUrl = getArg('baseUrl');

  const userId = getArg('userId');

  if (!baseUrl) {

    console.error('Missing --baseUrl. Example: --baseUrl=https://stackblitz.com');

    process.exit(1);

  }

  if (!userId) {

    console.error('Missing --userId. Example: --userId=3379271');

    process.exit(1);

  }

  // Use a persistent profile so we can reuse login cookies

  const userDataDir = `${process.cwd()}/.playwright-profile`;

  const browser = await chromium.launchPersistentContext(userDataDir, {

    headless: false, // show the browser for easier debugging

    viewport: { width: 1280, height: 900 },

  });

  const page = await browser.newPage();

  // Helper: robust click by text, preferring exact match

  async function clickLinkWithText(page, text) {

    // Try exact match first

    const exact = page.getByRole('link', { name: text, exact: true });

    if (await exact.count()) {

      await exact.first().click();

      return;

    }

    // Fallback: partial text match via locator

    const partial = page.locator(`a:has-text("${text}")`);

    if (await partial.count()) {

      await partial.first().click();

      return;

    }

    throw new Error(`Link with text "${text}" not found`);

  }

  // 1) Navigate to Users page (Manage → Users). If you already have the URL, go directly.

  // You can also pass a full users index URL with filters via --usersUrl for reliability.

  const usersUrl = `${baseUrl}/admin/users`; // Adjust if your admin path differs

  await page.goto(usersUrl, { waitUntil: 'domcontentloaded' });

  // Wait for the Users table to render; ActiveAdmin usually has a table with headers

  await page.waitForSelector('table', { timeout: 15000 });

  // 2) Click the ID link (e.g., "3379271"). We’ll search for an anchor with that text.

  await clickLinkWithText(page, String(userId));

  // 3) On the user detail page, find the organization link.

  // Common ActiveAdmin structure:

  // - Panel or attributes table listing Organization with a linked name/ID

  // We try a few strategies:

  let orgLinkFound = false;

  // Strategy A: Find a panel/section labeled "Organization" then click the first link inside it

  const orgSection = page.locator('section, div, .panel, .attributes_table').filter({

    has: page.locator('h3,h2,h1:has-text("Organization"), .panel h3:has-text("Organization")'),

  });

  if (await orgSection.count()) {

    const linkInSection = orgSection.first().locator('a');

    if (await linkInSection.count()) {

      await linkInSection.first().click();

      orgLinkFound = true;

    }

  }

  // Strategy B: If the above didn’t find it, click the first link that looks like an org page

  if (!orgLinkFound) {

    const possibleOrgLinks = page.locator('a').filter({

      hasNotText: 'View',

    });

    const count = await possibleOrgLinks.count();

    for (let i = 0; i < count; i++) {

      const a = possibleOrgLinks.nth(i);

      const href = await a.getAttribute('href');

      const text = await a.innerText().catch(() => '');

      if (href && /\/admin\/organizations?\//i.test(href)) {

        await a.click();

        orgLinkFound = true;

        break;

      }

      // Fallback heuristic: link text contains "Organization" or looks like an org ID

      if (/organization/i.test(text)) {

        await a.click();

        orgLinkFound = true;

        break;

      }

    }

  }

  if (!orgLinkFound) {

    throw new Error('Failed to locate organization link on the user detail page.');

  }

  // 4) On the organization page, open Token Stats for every org user.

  // We need to locate the list/table of users within the org.

  await page.waitForLoadState('domcontentloaded');

  await page.waitForSelector('table', { timeout: 15000 });

  // Try to find a table that likely represents organization users.

  // Heuristics: headers containing Username/Email/Name/Id

  const tables = page.locator('table');

  const tableCount = await tables.count();

  let usersTableIndex = -1;

  for (let i = 0; i < tableCount; i++) {

    const tbl = tables.nth(i);

    const headerText = await tbl.locator('thead').innerText().catch(() => '');

    if (/username|email|name|id/i.test(headerText)) {

      usersTableIndex = i;

      break;

    }

  }

  if (usersTableIndex === -1) {

    // If we can’t uniquely identify the users table, just pick the first table as fallback

    usersTableIndex = 0;

  }

  const usersTable = tables.nth(usersTableIndex);

  // Find all rows in tbody

  const rows = usersTable.locator('tbody tr');

  const rowCount = await rows.count();

  if (rowCount === 0) {

    console.warn('No user rows found in organization page.');

  }

  // For each row:

  // - If there is a "Token Stats" link directly, open in new tab

  // - Otherwise, click user link to visit the user page, then find "Token Stats" and open it

  const context = page.context();

  for (let i = 0; i < rowCount; i++) {

    const row = rows.nth(i);

    // Try direct Token Stats link in the row

    const tokenLink = row.locator('a:has-text("Token Stats")');

    if (await tokenLink.count()) {

      const href = await tokenLink.first().getAttribute('href');

      if (href) {

        // Open in a new tab

        const newPage = await context.newPage();

        await newPage.goto(new URL(href, baseUrl).toString(), { waitUntil: 'domcontentloaded' });

        continue;

      }

    }

    // Otherwise, open the user page from this row (e.g., click the ID or Username link)

    // Prefer ID link first, else username/email link

    const idLink = row.locator('a').filter({

      hasText: /^[0-9]+$/ // anchor text looks like a number

    }).first();

    let userPageLink = idLink;

    if (!(await idLink.count())) {

      // Pick first anchor in the row as fallback

      userPageLink = row.locator('a').first();

    }

    if (await userPageLink.count()) {

      const href = await userPageLink.getAttribute('href');

      if (href) {

        const userPage = await context.newPage();

        await userPage.goto(new URL(href, baseUrl).toString(), { waitUntil: 'domcontentloaded' });

        // On the user page, open Token Stats

        const userTokenLink = userPage.locator('a:has-text("Token Stats")');

        if (await userTokenLink.count()) {

          const userTokenHref = await userTokenLink.first().getAttribute('href');

          if (userTokenHref) {

            const tokenPage = await context.newPage();

            await tokenPage.goto(new URL(userTokenHref, baseUrl).toString(), { waitUntil: 'domcontentloaded' });

          } else {

            console.warn('Token Stats link found but missing href on user page.');

          }

        } else {

          console.warn('Token Stats link not found on user page.');

        }

      } else {

        console.warn('User link missing href in org users row.');

      }

    } else {

      console.warn('No clickable user link in org users row.');

    }

  }

  // Keep browser open so you can view the opened tabs.

  // Press Ctrl+C to exit or close the browser manually.

  console.log('Done opening Token Stats pages for org users.');

})();

Raycast integration options

- Script Command:

 ▫ Create a script command that invokes Node with this file, pass ‎⁠--baseUrl⁠ and ‎⁠--userId⁠ from Raycast input.

 ▫ In Raycast, set “Required parameters” to userId, and maybe baseUrl if you switch environments.

- Raycast extension (Node-based):

 ▫ Use the Raycast API to create a command that calls this script or embeds the Playwright steps directly.

 ▫ Show a form to input user ID, then run automation.

Security and reliability notes

- Do not hardcode cookies or tokens. Use Playwright persistent context so your login session is reused safely.

- If your admin path is not at /admin/users, adjust ‎⁠usersUrl⁠.

- Selectors may differ; if “Token Stats” is a button instead of a link, change to ‎⁠page.getByRole('button', { name: 'Token Stats' })⁠.

- If the org detail page uses tabs (e.g., Users tab), add a click for that tab before scanning rows.

- If your environment requires SSO re-auth, the first run will stop at the login page; log in once and rerun.

If you can share the exact HTML of:

- The user detail page’s organization section

- The organization page where the users list and Token Stats live
I can tailor selectors to be bulletproof and shorten the heuristics.

// Click ID link in the users table (works for any visible numeric ID link)
(function() {
  const idText = '3379271'; // Change if needed
  const link = Array.from(document.querySelectorAll('a'))
    .find(a => a.textContent.trim() === idText);
  if (!link) {
    console.error('User ID link not found:', idText);
    return;
  }
  console.log('Clicking user ID link:', link);
  link.click();
})();

can we test it out now in the browser?

Yes—if you’re on this StackBlitz Admin page right now, we can automate it in your local browser using a small userscript run from the console to validate selectors and flow before we wire it to Raycast/Playwright.

Quick plan

1. Click the current user ID in the table (3379271).

2. On the user detail page, find and click the organization link.

3. On the org page, find all users and open each user’s “Token Stats” in new tabs.

Run this snippet in the browser console on each page to step through. It’s defensive against minor DOM differences.

Step 1: On the Users index page, click the ID link// Click ID link in the users table (works for any visible numeric ID link)

(function() {

  const idText = '3379271'; // Change if needed

  const link = Array.from(document.querySelectorAll('a'))

    .find(a => a.textContent.trim() === idText);

  if (!link) {

    console.error('User ID link not found:', idText);

    return;

  }

  console.log('Clicking user ID link:', link);

  link.click();

})();

Step 2: On the user detail page, click the organization link// Finds an organization section/link and clicks it.

// Run this after the user detail page has loaded.

(function() {

  // Heuristic: look for links to /admin/organizations/...

  const orgLink = Array.from(document.querySelectorAll('a'))

    .find(a => {

      const href = a.getAttribute('href') || '';

      const text = a.textContent.toLowerCase();

      return /\/admin\/organizations?\//i.test(href) || text.includes('organization');

    });

  if (!orgLink) {

    console.error('Organization link not found on user detail page.');

    return;

  }

  console.log('Clicking organization link:', orgLink);

  orgLink.click();

})();

Step 3: On the organization page, open Token Stats for every org user// On the organization page, open "Token Stats" for each user.

// If the "Token Stats" link isn’t in the table row, it will open each user page and then try to find "Token Stats" there.

(function() {

  function absolute(url) {

    try {

      return new URL(url, location.origin).toString();

    } catch {

      return url;

    }

  }

  const tables = Array.from(document.querySelectorAll('table'));

  if (tables.length === 0) {

    console.error('No tables found on organization page.');

    return;

  }

  // Prefer a table with typical user headers

  let usersTable = tables.find(tbl => {

    const headText = (tbl.querySelector('thead')?.textContent || '').toLowerCase();

    return /username|email|name|id/.test(headText);

  }) || tables[0];

  const rows = Array.from(usersTable.querySelectorAll('tbody tr'));

  if (rows.length === 0) {

    console.warn('No user rows found in organization table.');

  }

  let opened = 0;

  rows.forEach((row) => {

    // Case A: direct "Token Stats" link in row

    const tokenLink = Array.from(row.querySelectorAll('a'))

      .find(a => a.textContent.trim().toLowerCase() === 'token stats' || a.textContent.toLowerCase().includes('token stats'));

    if (tokenLink && tokenLink.href) {

      const url = absolute(tokenLink.getAttribute('href'));

      window.open(url, '_blank');

      opened++;

      return;

    }

    // Case B: open user page and then token stats from there

    const userLink = Array.from(row.querySelectorAll('a')).find(a => {

      const text = a.textContent.trim();

      const href = a.getAttribute('href') || '';

      // Prefer numeric ID link, else any link that looks like a user page

      return /^[0-9]+$/.test(text) || /\/admin\/users\//i.test(href);

    });

    if (userLink && userLink.href) {

      // Open the user page in a new tab first

      const userUrl = absolute(userLink.getAttribute('href'));

      const w = window.open(userUrl, '_blank');

      // Best effort: once the new tab loads, find Token Stats and open it.

      // Note: cross-window scripting is allowed since same-origin; if new tab runs quickly, this should work.

      const tryOpenTokenStats = () => {

        try {

          const doc = w.document;

          if (!doc) return setTimeout(tryOpenTokenStats, 500);

          const tokenA = Array.from(doc.querySelectorAll('a'))

            .find(a => (a.textContent || '').toLowerCase().includes('token stats'));

          if (tokenA && tokenA.href) {

            w.open(absolute(tokenA.getAttribute('href')), '_blank');

            opened++;

            return;

          } else {

            // If not found yet, wait and retry a few times

            setTimeout(tryOpenTokenStats, 500);

          }

        } catch (e) {

          // If the document isn’t ready yet, retry

          setTimeout(tryOpenTokenStats, 500);

        }

      };

      // Start polling for the token stats link

      setTimeout(tryOpenTokenStats, 800);

    } else {

      console.warn('No user link found in row:', row);

    }

  });

  console.log('Requested opening Token Stats tabs. Rows processed:', rows.length, 'Direct/indirect opened:', opened);

})();

If those work end-to-end, we can translate the same DOM strategies into the Playwright script for Raycast. If any selector fails on your org/user pages, copy the HTML of the relevant section and I’ll adjust the targeting to be exact and stable.

this is the second page where you can see 2 orgs in this case where wexinc is the one I want to look into

Got it. On this user page, click the wexinc org and then open token stats for all its members with a small console snippet.

Step 1: Click the wexinc org
Run in the console here:(function() {

  const link = Array.from(document.querySelectorAll('a')).find(a => a.textContent.trim() === 'wexinc');

  if (!link) { console.error('wexinc org link not found'); return; }

  link.click();

})();

Step 2: On the wexinc org page, open “Token Stats” for every org user
Run after the org page loads:(function() {

  function abs(u) { try { return new URL(u, location.origin).toString(); } catch { return u; } }

  const tables = Array.from(document.querySelectorAll('table'));

  if (!tables.length) { console.error('No tables found'); return; }

  // Pick the users table by headers

  const usersTable = tables.find(t => {

    const h = (t.querySelector('thead')?.textContent || '').toLowerCase();

    return /username|email|name|id/.test(h);

  }) || tables[0];

  const rows = Array.from(usersTable.querySelectorAll('tbody tr'));

  if (!rows.length) { console.warn('No user rows found'); }

  let opened = 0;

  rows.forEach(row => {

    // Direct Token Stats in row

    const tokenLink = Array.from(row.querySelectorAll('a'))

      .find(a => (a.textContent || '').toLowerCase().includes('token stats'));

    if (tokenLink?.getAttribute('href')) {

      window.open(abs(tokenLink.getAttribute('href')), '_blank'); opened++; return;

    }

    // Otherwise open user page, then its Token Stats

    const userLink = Array.from(row.querySelectorAll('a')).find(a => {

      const txt = a.textContent.trim();

      const href = a.getAttribute('href') || '';

      return /^[0-9]+$/.test(txt) || /\/admin\/users\//i.test(href);

    });

    if (userLink?.getAttribute('href')) {

      const up = window.open(abs(userLink.getAttribute('href')), '_blank');

      const poll = () => {

        try {

          const doc = up.document;

          if (!doc) return setTimeout(poll, 500);

          const tl = Array.from(doc.querySelectorAll('a'))

            .find(a => (a.textContent || '').toLowerCase().includes('token stats'));

          if (tl?.getAttribute('href')) {

            up.open(abs(tl.getAttribute('href')), '_blank'); opened++; return;

          }

          setTimeout(poll, 500);

        } catch { setTimeout(poll, 500); }

      };

      setTimeout(poll, 800);

    }

  });

  console.log('Opened token stats tabs:', opened, 'rows:', rows.length);

})();

This mirrors what we’ll later automate in Raycast/Playwright and should work against ActiveAdmin’s structure you shared.

Makes sense. Let’s make the console script detect all organizations on the user page, show a chooser, and then proceed with the selected org. It will:

- Parse the “Organizations” table on the user page.

- Show a lightweight selection dialog listing all orgs with their IDs and roles.

- Navigate to the chosen org.

- On the org page, open Token Stats for every org member.

Run this on the user detail page first. It will handle any org names, not just wexinc.// Run on the USER detail page (the page that shows the "Organizations" table).

// 1) It will list all orgs and let you choose which one to open.

// 2) It will navigate to that org page.

// 3) On the org page, it will open "Token Stats" for every org member in new tabs.

//

// Notes:

// - Uses a custom chooser overlay for better UX than prompt().

// - Falls back to prompt() if overlay injection fails.

// - Safe for ActiveAdmin pages; selectors based on the table you pasted.

(function() {

  // Helpers

  function abs(u) { try { return new URL(u, location.origin).toString(); } catch { return u; } }

  function byText(el, text) { return (el.textContent || '').trim() === text; }

  // Extract organizations from the "Organizations" section table

  function getOrganizationsFromUserPage() {

    const tables = Array.from(document.querySelectorAll('table'));

    // Find the orgs table by header row containing Organization column

    const orgsTable = tables.find(t => {

      const head = t.querySelector('thead');

      if (!head) return false;

      const headers = Array.from(head.querySelectorAll('th')).map(th => (th.textContent || '').toLowerCase().trim());

      return headers.includes('organization') || headers.includes('org') || headers.includes('actions');

    });

    if (!orgsTable) return [];

    const rows = Array.from(orgsTable.querySelectorAll('tbody tr'));

    return rows.map(row => {

      const cells = Array.from(row.querySelectorAll('td'));

      // Expected structure (based on your page):

      // Id | Organization | Email | Role | Status | Tier | Deleted At | Actions

      const idCell = cells[0];

      const orgCell = cells[1];

      const actionsCell = cells[cells.length - 1];

      const idText = idCell ? idCell.textContent.trim() : '';

      const orgLink = orgCell ? orgCell.querySelector('a') : null;

      const orgName = orgLink ? orgLink.textContent.trim() : (orgCell ? orgCell.textContent.trim() : '');

      const orgHref = orgLink ? orgLink.getAttribute('href') : null;

      // Actions may include "View token stats" for this membership

      const actionLinks = actionsCell ? Array.from(actionsCell.querySelectorAll('a')) : [];

      const viewTokenStatsLink = actionLinks.find(a => (a.textContent || '').toLowerCase().includes('view token stats'));

      const viewTokenStatsHref = viewTokenStatsLink ? viewTokenStatsLink.getAttribute('href') : null;

      const roleCell = cells[3];

      const role = roleCell ? roleCell.textContent.trim() : '';

      return {

        idText,

        orgName,

        orgHref,

        viewTokenStatsHref,

        role

      };

    }).filter(o => o.orgHref);

  }

  // Chooser UI (overlay)

  function showChooser(options) {

    return new Promise((resolve) => {

      try {

        const overlay = document.createElement('div');

        overlay.style.position = 'fixed';

        overlay.style.inset = '0';

        overlay.style.background = 'rgba(0,0,0,0.4)';

        overlay.style.zIndex = '99999';

        overlay.style.display = 'flex';

        overlay.style.alignItems = 'center';

        overlay.style.justifyContent = 'center';

        const panel = document.createElement('div');

        panel.style.background = '#fff';

        panel.style.color = '#111';

        panel.style.borderRadius = '8px';

        panel.style.boxShadow = '0 10px 30px rgba(0,0,0,0.3)';

        panel.style.minWidth = '420px';

        panel.style.maxWidth = '720px';

        panel.style.maxHeight = '70vh';

        panel.style.overflow = 'auto';

        panel.style.fontFamily = 'system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif';

        const title = document.createElement('div');

        title.textContent = 'Choose an Organization';

        title.style.fontSize = '18px';

        title.style.fontWeight = '600';

        title.style.padding = '16px';

        title.style.borderBottom = '1px solid #eee';

        const list = document.createElement('div');

        options.forEach((opt, idx) => {

          const item = document.createElement('button');

          item.type = 'button';

          item.style.display = 'flex';

          item.style.alignItems = 'center';

          item.style.justifyContent = 'space-between';

          item.style.width = '100%';

          item.style.textAlign = 'left';

          item.style.padding = '12px 16px';

          item.style.border = 'none';

          item.style.background = 'transparent';

          item.style.cursor = 'pointer';

          item.onmouseenter = () => item.style.background = '#f7f7f7';

          item.onmouseleave = () => item.style.background = 'transparent';

          const left = document.createElement('div');

          left.innerHTML = `<strong>${opt.orgName}</strong> <span style="color:#666">• ID ${opt.idText}${opt.role ? ' • ' + opt.role : ''}</span>`;

          const right = document.createElement('div');

          right.style.color = '#666';

          right.style.fontSize = '12px';

          right.textContent = opt.viewTokenStatsHref ? 'Token stats link available' : 'Token stats via user pages';

          item.appendChild(left);

          item.appendChild(right);

          item.addEventListener('click', () => {

            document.body.removeChild(overlay);

            resolve(opt);

          });

          list.appendChild(item);

          if (idx < options.length - 1) {

            const hr = document.createElement('div');

            hr.style.height = '1px';

            hr.style.background = '#eee';

            list.appendChild(hr);

          }

        });

        const footer = document.createElement('div');

        footer.style.display = 'flex';

        footer.style.justifyContent = 'flex-end';

        footer.style.gap = '8px';

        footer.style.padding = '12px 16px';

        footer.style.borderTop = '1px solid #eee';

        const cancelBtn = document.createElement('button');

        cancelBtn.type = 'button';

        cancelBtn.textContent = 'Cancel';

        cancelBtn.style.padding = '8px 12px';

        cancelBtn.style.border = '1px solid #ddd';

        cancelBtn.style.borderRadius = '6px';

        cancelBtn.style.background = '#fafafa';

        cancelBtn.addEventListener('click', () => {

          document.body.removeChild(overlay);

          resolve(null);

        });

        footer.appendChild(cancelBtn);

        panel.appendChild(title);

        panel.appendChild(list);

        panel.appendChild(footer);

        overlay.appendChild(panel);

        document.body.appendChild(overlay);

      } catch (e) {

        console.warn('Overlay failed, falling back to prompt()', e);

        const names = options.map((o, i) => `${i + 1}) ${o.orgName} (ID ${o.idText}${o.role ? ' • ' + o.role : ''})`).join('\n');

        const idx = parseInt(prompt(`Choose organization:\n${names}\n\nEnter number:`) || '', 10);

        resolve(options[idx - 1] || null);

      }

    });

  }

  async function openTokenStatsForOrgUsers(orgUrl) {

    // Navigate to org page

    location.assign(abs(orgUrl));

    // Wait until table(s) present

    const waitTables = async () => {

      for (let i = 0; i < 40; i++) {

        if (document.querySelectorAll('table').length) return true;

        await new Promise(r => setTimeout(r, 250));

      }

      return false;

    };

    const ok = await waitTables();

    if (!ok) {

      console.error('Organization page tables not found.');

      return;

    }

    const tables = Array.from(document.querySelectorAll('table'));

    const usersTable = tables.find(t => {

      const headText = (t.querySelector('thead')?.textContent || '').toLowerCase();

      return /username|email|name|id/.test(headText);

    }) || tables[0];

    const rows = Array.from(usersTable.querySelectorAll('tbody tr'));

    if (!rows.length) {

      console.warn('No user rows found in org users table.');

    }

    let opened = 0;

    rows.forEach(row => {

      const tokenLink = Array.from(row.querySelectorAll('a'))

        .find(a => (a.textContent || '').toLowerCase().includes('token stats'));

      if (tokenLink?.getAttribute('href')) {

        window.open(abs(tokenLink.getAttribute('href')), '_blank');

        opened++;

        return;

      }

      const userLink = Array.from(row.querySelectorAll('a')).find(a => {

        const txt = a.textContent.trim();

        const href = a.getAttribute('href') || '';

        return /^[0-9]+$/.test(txt) || /\/admin\/users\//i.test(href);

      });

      if (userLink?.getAttribute('href')) {

        const up = window.open(abs(userLink.getAttribute('href')), '_blank');

        const poll = () => {

          try {

            const doc = up.document;

            if (!doc) return setTimeout(poll, 500);

            const tl = Array.from(doc.querySelectorAll('a'))

              .find(a => (a.textContent || '').toLowerCase().includes('token stats'));

            if (tl?.getAttribute('href')) {

              up.open(abs(tl.getAttribute('href')), '_blank');

              opened++;

              return;

            }

            setTimeout(poll, 500);

          } catch { setTimeout(poll, 500); }

        };

        setTimeout(poll, 800);

      }

    });

    console.log('Requested opening Token Stats tabs:', opened, 'rows:', rows.length);

  }

  // Main

  const orgs = getOrganizationsFromUserPage();

  if (!orgs.length) {

    console.error('No organizations found in the Organizations table on this user page.');

    return;

  }

  showChooser(orgs).then(chosen => {

    if (!chosen) { console.log('Selection cancelled.'); return; }

    if (!chosen.orgHref) { console.error('Chosen organization has no link.'); return; }

    // Navigate and process

    openTokenStatsForOrgUsers(chosen.orgHref);

  });

})();

Once this works for you, I can port the exact selection logic and selectors into the Playwright/Raycast script, including:

- Listing orgs for the given user.

- Raycast form dropdown to choose org.

- Opening token stats in new tabs or collecting them.


and here you have organisation members and their view token stats

Perfect. Since the Organization Members table already includes “View token stats” per member, we can do this in one shot from the org page.

Run this in the browser console on the organization page that shows the Organization Members table. It will:

- Find the members table

- Open every “View token stats” link in new background tabs

- Optionally filter by role or email domain if you want

// Open "View token stats" for all org members shown in the Organization Members table.

// Run on the Organization page (the one listing members with "View token stats").

//

// Options: tweak these if you want to filter who to open for

const OPTIONS = {

  // 'any' | 'member' | 'admin'

  roleFilter: 'any',

  // e.g., '@wexinc.com' to only open for that domain, or '' for no filter

  emailDomainFilter: '',

  // Limit how many to open. Set null for all.

  maxOpen: null,

  // Delay between opening tabs (ms), to avoid popup blocking

  openDelayMs: 150,

};

(function() {

  function abs(u) { try { return new URL(u, location.origin).toString(); } catch { return u; } }

  // Find the Organization Members table by matching headers

  const tables = Array.from(document.querySelectorAll('table'));

  const membersTable = tables.find(t => {

    const head = t.querySelector('thead');

    const headers = Array.from(head?.querySelectorAll('th') || []).map(th => (th.textContent || '').toLowerCase().trim());

    return headers.includes('user') && headers.includes('actions');

  }) || tables.find(t => {

    const headText = (t.querySelector('thead')?.textContent || '').toLowerCase();

    return /organization members|user|actions/.test(headText);

  });

  if (!membersTable) {

    console.error('Organization Members table not found.');

    return;

  }

  const rows = Array.from(membersTable.querySelectorAll('tbody tr'));

  if (!rows.length) {

    console.warn('No rows found in Organization Members table.');

    return;

  }

  // Build a list of eligible "View token stats" hrefs based on filters

  const items = rows.map(row => {

    const cells = Array.from(row.querySelectorAll('td'));

    const userCell = cells[1];

    const emailCell = cells[2];

    const roleCell = cells[3];

    const actionsCell = cells[cells.length - 1];

    const email = (emailCell?.textContent || '').trim().toLowerCase();

    const role = (roleCell?.textContent || '').trim().toLowerCase();

    const tokenLink = Array.from(actionsCell?.querySelectorAll('a') || [])

      .find(a => (a.textContent || '').toLowerCase().includes('view token stats'));

    const href = tokenLink?.getAttribute('href') || null;

    return { email, role, href };

  }).filter(item => !!item.href)

    .filter(item => {

      if (OPTIONS.roleFilter !== 'any' && item.role !== OPTIONS.roleFilter) return false;

      if (OPTIONS.emailDomainFilter && !item.email.endsWith(OPTIONS.emailDomainFilter.toLowerCase())) return false;

      return true;

    });

  if (!items.length) {

    console.warn('No matching members with "View token stats" after filters.');

    return;

  }

  const toOpen = OPTIONS.maxOpen ? items.slice(0, OPTIONS.maxOpen) : items;

  let opened = 0;

  function openNext(i) {

    if (i >= toOpen.length) {

      console.log(`Done. Opened ${opened} token stats tabs.`);

      return;

    }

    const url = abs(toOpen[i].href);

    // Opening with a small delay helps avoid popup blockers

    window.open(url, '_blank');

    opened++;

    setTimeout(() => openNext(i + 1), OPTIONS.openDelayMs);

  }

  console.log(`Opening ${toOpen.length} "View token stats" tabs...`);

  openNext(0);

})();

Notes and tweaks:

- To open only Admins: set roleFilter to ‘admin’.

- To open only members with @wexinc.com emails: set emailDomainFilter to ‘@wexinc.com’.

- If your browser blocks too many popups, increase openDelayMs or set maxOpen to a smaller number and rerun for the next batch.