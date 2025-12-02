import { execa } from "execa";

export const CHROMIUM_BROWSERS = [
  "Google Chrome",
  "Brave Browser",
  "Microsoft Edge",
  "Arc",
  "Chromium",
  "Dia",
] as const;

export type BrowserName = (typeof CHROMIUM_BROWSERS)[number];

export type BrowserPageContent = {
  browser: BrowserName;
  url: string;
  title: string;
  text: string;
};

const TITLE_MARK = "---TITLE---";
const TEXT_MARK = "---TEXT---";

export async function getPageContent(browser: BrowserName): Promise<BrowserPageContent | null> {
  const script = `
on run argv
  set appName to item 1 of argv
  try
    using terms from application "Google Chrome"
      tell application appName
        if (count of windows) is 0 then error "No windows"
        set theWindow to front window
        set theTab to active tab of theWindow
        set pageURL to URL of theTab
        set pageTitle to title of theTab
        set pageText to ""
        try
          if appName is "Arc" or appName is "Dia" then
            set pageText to ""
          else
            set pageText to execute theTab javascript "
              try {
                const text = [];
                document.querySelectorAll('tr').forEach(row => {
                  const cells = row.querySelectorAll('td');
                  if (cells.length > 0) {
                    const firstCell = cells[0].textContent.trim();
                    if (/^\\d{1,10}$/.test(firstCell)) {
                      text.push('ID:' + firstCell);
                    }
                  }
                });
                document.querySelectorAll('[data-user-id], [data-id]').forEach(el => {
                  const uid = el.getAttribute('data-user-id') || el.getAttribute('data-id');
                  if (uid && /^\\d{1,10}$/.test(uid)) text.push('ID:' + uid);
                });
                if (text.length === 0) {
                  text.push(document.body.innerText || '');
                }
                text.join('\\n');
              } catch (e) {
                document.body.innerText || '';
              }
            "
            if pageText is missing value then set pageText to ""
          end if
        end try
        return pageURL & "\\n${TITLE_MARK}\\n" & pageTitle & "\\n${TEXT_MARK}\\n" & pageText
      end tell
    end using terms from
  on error errMsg
    return "ERROR: " & errMsg
  end try
end run`;

  try {
    const { stdout } = await execa("osascript", ["-", browser], { input: script });
    if (!stdout || stdout.startsWith("ERROR:")) {
      return null;
    }

    const titleIndex = stdout.indexOf(TITLE_MARK);
    const textIndex = stdout.indexOf(TEXT_MARK);
    if (titleIndex === -1 || textIndex === -1) {
      return null;
    }

    const url = stdout.slice(0, titleIndex).trim();
    const title = stdout.slice(titleIndex + TITLE_MARK.length, textIndex).trim();
    const text = stdout.slice(textIndex + TEXT_MARK.length).trim();

    return { browser, url, title, text };
  } catch {
    return null;
  }
}

export async function captureActiveTabContent(): Promise<BrowserPageContent | null> {
  for (const browser of CHROMIUM_BROWSERS) {
    const content = await getPageContent(browser);
    if (content) {
      return content;
    }
  }
  return null;
}

