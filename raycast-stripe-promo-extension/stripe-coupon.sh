#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stripe Promo Code Checker
# @raycast.mode fullOutput
# @raycast.packageName Stripe Tools

# Optional parameters:
# @raycast.icon 💳
# @raycast.argument1 { "type": "text", "placeholder": "Promo Code" }

PROMO_CODE="$1"
KEYCHAIN_SERVICE="raycast-stripe-api"
KEYCHAIN_ACCOUNT="stripe-api-key"

# Retrieve API key from keychain
API_KEY=$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)

if [ -z "$API_KEY" ]; then
    echo "❌ No API key found in Keychain."
    echo ""
    echo "To store your Stripe API key securely, run this command in Terminal:"
    echo "security add-generic-password -a '$KEYCHAIN_ACCOUNT' -s '$KEYCHAIN_SERVICE' -w 'YOUR_API_KEY_HERE'"
    echo ""
    exit 1
fi

echo "🔍 Searching for: $PROMO_CODE"
echo ""

# Fetch promotion code
PROMO_CODE_UPPER=$(echo "$PROMO_CODE" | tr '[:lower:]' '[:upper:]')
RESULT=$(curl -s "https://api.stripe.com/v1/promotion_codes?code=$PROMO_CODE_UPPER&limit=100" \
    -u "$API_KEY:")

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "$RESULT"
    exit 0
fi

# Filter for exact match
EXACT_MATCH=$(echo "$RESULT" | jq --arg code "$PROMO_CODE_UPPER" '[.data[] | select(.code == $code)] | .[0]')

if [ "$EXACT_MATCH" = "null" ] || [ -z "$EXACT_MATCH" ]; then
    echo "❌ Promo code '$PROMO_CODE' not found"
    exit 1
fi

# Extract coupon ID from .promotion.coupon
COUPON_ID=$(echo "$EXACT_MATCH" | jq -r '.promotion.coupon // empty')

# Fetch full coupon details if we have a coupon ID
if [ ! -z "$COUPON_ID" ] && [ "$COUPON_ID" != "null" ]; then
    COUPON_DATA=$(curl -s "https://api.stripe.com/v1/coupons/$COUPON_ID" \
        -u "$API_KEY:")
    
    # Check if coupon fetch was successful
    if echo "$COUPON_DATA" | jq -e '.id' > /dev/null 2>&1; then
        # Add coupon data to the promotion code object
        EXACT_MATCH=$(echo "$EXACT_MATCH" | jq --argjson coupon "$COUPON_DATA" '. + {coupon: $coupon}')
    fi
fi

# Display the results with better formatting
echo "$EXACT_MATCH" | jq -r '
    "╭─────────────────────────────────────────╮",
    "│  PROMOTION CODE DETAILS                 │",
    "╰─────────────────────────────────────────╯",
    "",
    "  Code:        \(.code)",
    "  ID:          \(.id)",
    "  Status:      \(if .active then "✅ Active" else "❌ Inactive" end)",
    "  Redeemed:    \(.times_redeemed)/\(if .max_redemptions then (.max_redemptions | tostring) else "∞" end)",
    "  Expires:     \(if .expires_at then (.expires_at | strftime("%B %d, %Y")) else "No expiration" end)",
    "",
    "╭─────────────────────────────────────────╮",
    "│  COUPON DETAILS                         │",
    "╰─────────────────────────────────────────╯",
    "",
    "  Coupon ID:   \(.coupon.id // "N/A")",
    (if .coupon.amount_off then "  Discount:    $\((.coupon.amount_off / 100) | tostring) off" elif .coupon.percent_off then "  Discount:    \(.coupon.percent_off)% off" else "  Discount:    N/A" end),
    "  Duration:    \(.coupon.duration // "N/A")\(if .coupon.duration_in_months then " (\(.coupon.duration_in_months) months)" else "" end)",
    "  Valid:       \(if .coupon.valid then "✅ Yes" else "❌ No" end)",
    (if .coupon.times_redeemed then "  Total Uses:  \(.coupon.times_redeemed | tostring)" else "" end),
    ""
'