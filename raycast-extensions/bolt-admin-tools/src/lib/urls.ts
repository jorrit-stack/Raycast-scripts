const STACKBLITZ_ADMIN_BASE =
  "https://stackblitz.com/admin/users?commit=Filter&order=id_desc";

export function buildAdminUrl(identifier: string) {
  const trimmed = identifier.trim();
  if (!trimmed) return STACKBLITZ_ADMIN_BASE;
  const isNumeric = /^\d+$/.test(trimmed);
  return isNumeric
    ? `${STACKBLITZ_ADMIN_BASE}&q%5Bid_eq%5D=${encodeURIComponent(trimmed)}`
    : `${STACKBLITZ_ADMIN_BASE}&q%5Bby_email_address%5D=${encodeURIComponent(trimmed)}`;
}

export function buildRateLimitsUrl(userId: string) {
  return `https://bolt.new/api/rate-limits/${encodeURIComponent(userId)}`;
}

