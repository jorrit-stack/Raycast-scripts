import type { BrowserPageContent } from "./browsers";

const URL_ID_REGEX =
  /\/users\/(\d{1,10})|[?&](?:id|user_id)=([0-9]{1,10})|\/admin\/users\/(\d{1,10})/i;
const CONTEXT_REGEX =
  /(ID:|user.?id|user.?number|uid|^\d{1,10}$)[:#\s]*([0-9]{1,10})|\bid[:#\s]*([0-9]{1,10})/gim;

export type ExtractionResult = {
  userId: string;
  source: string;
};

export function extractUserId(content: BrowserPageContent): ExtractionResult | null {
  const fromUrl = matchFromUrl(content.url) ?? matchFromUrl(content.title);
  if (fromUrl) {
    return { userId: fromUrl, source: "URL or title" };
  }

  const fromContext = matchFromContext(content.text);
  if (fromContext) {
    return { userId: fromContext, source: "Page context" };
  }

  const fromTable = matchFromTable(content.text);
  if (fromTable) {
    return { userId: fromTable, source: "Table rows" };
  }

  const fallback = matchGenericNumber(content.text);
  if (fallback) {
    return { userId: fallback, source: "Generic numeric fallback" };
  }

  return null;
}

function matchFromUrl(value: string): string | null {
  if (!value) return null;
  const match = URL_ID_REGEX.exec(value);
  URL_ID_REGEX.lastIndex = 0;
  if (!match) return null;
  return match.slice(1).find(Boolean) ?? null;
}

function matchFromContext(text: string): string | null {
  if (!text) return null;
  let match: RegExpExecArray | null = null;
  while ((match = CONTEXT_REGEX.exec(text))) {
    const candidate = match.slice(2).find(Boolean);
    if (candidate) {
      CONTEXT_REGEX.lastIndex = 0;
      return candidate;
    }
  }
  CONTEXT_REGEX.lastIndex = 0;
  return null;
}

function matchFromTable(text: string): string | null {
  if (!text) return null;
  const lines = text.split(/\r?\n/).map((line) => line.trim());
  const monthPrefixes = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

  type Candidate = { score: number; index: number; userId: string };
  const candidates: Candidate[] = [];

  lines.forEach((line, index) => {
    if (!line) return;
    const match = line.match(/^(\d{1,10})\b(.*)$/);
    if (!match) return;
    const [, userId, rest] = match;
    const trimmedRest = rest.trim();
    if (!trimmedRest) return;
    const lower = trimmedRest.toLowerCase();
    if (monthPrefixes.some((prefix) => lower.startsWith(prefix))) return;

    let score = 1;
    if (/\b(sentry|username|email|view|@)\b/.test(lower)) score += 3;
    if (lines[index + 1] && lines[index + 1].includes("@")) score += 2;
    if (lines[index + 1] && /view/i.test(lines[index + 1])) score += 1;
    if (lines[index + 2] && /view/i.test(lines[index + 2])) score += 1;

    candidates.push({ score, index, userId });
  });

  if (!candidates.length) return null;
  candidates.sort((a, b) => b.score - a.score || a.index - b.index);
  return candidates[0].userId;
}

function matchGenericNumber(text: string): string | null {
  if (!text) return null;
  const matches = text.match(/\b\d{4,}\b/g);
  if (!matches) return null;
  for (const candidate of matches) {
    const num = Number(candidate);
    if (num >= 1000 && (num < 1900 || num > 2100)) {
      return candidate;
    }
  }
  return null;
}

