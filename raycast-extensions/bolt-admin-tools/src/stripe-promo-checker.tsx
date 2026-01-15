import { Action, ActionPanel, Clipboard, Detail, Form, Icon, Preferences, Toast, showToast } from "@raycast/api";
import { useEffect, useState } from "react";

type FormValues = {
  promoCode: string;
};

type PromotionCode = {
  id: string;
  code: string;
  active: boolean;
  times_redeemed: number;
  max_redemptions: number | null;
  expires_at: number | null;
  promotion: {
    coupon: string;
  };
  coupon?: Coupon;
};

type Coupon = {
  id: string;
  amount_off: number | null;
  percent_off: number | null;
  duration: string;
  duration_in_months: number | null;
  valid: boolean;
  times_redeemed: number | null;
};

type CheckState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: PromotionCode }
  | { status: "error"; error: string };

async function fetchPromotionCode(apiKey: string, code: string): Promise<PromotionCode> {
  const upperCode = code.toUpperCase();
  const response = await fetch(`https://api.stripe.com/v1/promotion_codes?code=${encodeURIComponent(upperCode)}&limit=100`, {
    headers: {
      Authorization: `Basic ${Buffer.from(`${apiKey}:`).toString("base64")}`,
    },
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Stripe API error: ${response.status} ${error}`);
  }

  const result = await response.json();
  const exactMatch = result.data?.find((pc: PromotionCode) => pc.code === upperCode);

  if (!exactMatch) {
    throw new Error(`Promo code '${code}' not found`);
  }

  // Fetch coupon details if available
  if (exactMatch.promotion?.coupon) {
    try {
      const couponResponse = await fetch(`https://api.stripe.com/v1/coupons/${exactMatch.promotion.coupon}`, {
        headers: {
          Authorization: `Basic ${Buffer.from(`${apiKey}:`).toString("base64")}`,
        },
      });

      if (couponResponse.ok) {
        exactMatch.coupon = await couponResponse.json();
      }
    } catch (error) {
      // Continue without coupon details if fetch fails
      console.error("Failed to fetch coupon details:", error);
    }
  }

  return exactMatch;
}

function formatDate(timestamp: number | null): string {
  if (!timestamp) return "No expiration";
  return new Date(timestamp * 1000).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

function formatPromoDetails(data: PromotionCode): string {
  const lines: string[] = [];

  lines.push("## Promotion Code Details");
  lines.push("");
  lines.push(`**Code:** \`${data.code}\``);
  lines.push(`**ID:** \`${data.id}\``);
  lines.push(`**Status:** ${data.active ? "✅ Active" : "❌ Inactive"}`);
  lines.push(
    `**Redeemed:** ${data.times_redeemed}/${data.max_redemptions ? data.max_redemptions.toString() : "∞"}`
  );
  lines.push(`**Expires:** ${formatDate(data.expires_at)}`);
  lines.push("");

  if (data.coupon) {
    lines.push("## Coupon Details");
    lines.push("");
    lines.push(`**Coupon ID:** \`${data.coupon.id}\``);

    if (data.coupon.amount_off) {
      lines.push(`**Discount:** $${(data.coupon.amount_off / 100).toFixed(2)} off`);
    } else if (data.coupon.percent_off) {
      lines.push(`**Discount:** ${data.coupon.percent_off}% off`);
    } else {
      lines.push("**Discount:** N/A");
    }

    const durationText =
      data.coupon.duration +
      (data.coupon.duration_in_months ? ` (${data.coupon.duration_in_months} months)` : "");
    lines.push(`**Duration:** ${durationText}`);
    lines.push(`**Valid:** ${data.coupon.valid ? "✅ Yes" : "❌ No"}`);

    if (data.coupon.times_redeemed !== null) {
      lines.push(`**Total Uses:** ${data.coupon.times_redeemed}`);
    }
  } else {
    lines.push("## Coupon Details");
    lines.push("");
    lines.push("_No coupon details available_");
  }

  return lines.join("\n");
}

export default function Command() {
  const [state, setState] = useState<CheckState>({ status: "idle" });
  const [promoCode, setPromoCode] = useState("");

  useEffect(() => {
    async function bootstrapFromClipboard() {
      try {
        const text = await Clipboard.readText();
        if (text && text.trim()) {
          setPromoCode(text.trim());
        }
      } catch {
        // ignore clipboard errors
      }
    }
    void bootstrapFromClipboard();
  }, []);

  async function handleSubmit(values: FormValues) {
    const code = values.promoCode.trim();
    if (!code) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Enter a promo code",
      });
      return;
    }

    setState({ status: "loading" });

    try {
      const { value: apiKey } = await Preferences.get("stripeApiKey");
      if (!apiKey || typeof apiKey !== "string") {
        throw new Error(
          "No API key found. Please set your Stripe API key in Raycast preferences (⌘,)."
        );
      }

      const data = await fetchPromotionCode(apiKey, code);
      setState({ status: "success", data });
      await showToast({
        style: Toast.Style.Success,
        title: "Promo code found",
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      setState({ status: "error", error: message });
      await showToast({
        style: Toast.Style.Failure,
        title: "Failed to check promo code",
        message,
      });
    }
  }

  if (state.status === "idle" || state.status === "loading") {
    return (
      <Form
        navigationTitle="Stripe Promo Code Checker"
        actions={
          <ActionPanel>
            <Action.SubmitForm
              title="Check Promo Code"
              icon={Icon.MagnifyingGlass}
              onSubmit={handleSubmit}
            />
          </ActionPanel>
        }
      >
        <Form.Description text="Enter a Stripe promotion code to check its details and associated coupon information." />
        <Form.TextField
          id="promoCode"
          title="Promo Code"
          placeholder="e.g. SUMMER2024"
          value={promoCode}
          onChange={setPromoCode}
          autoFocus
        />
        {state.status === "loading" && (
          <Form.Description text="🔍 Checking promo code..." />
        )}
      </Form>
    );
  }

  if (state.status === "error") {
    return (
      <Detail
        markdown={`# Error ❌\n\n${state.error}\n\n${
          state.error.includes("API key")
            ? "Please set your Stripe API key in Raycast preferences (⌘,)."
            : "Please check the promo code and try again."
        }`}
        actions={
          <ActionPanel>
            <Action
              title="Retry"
              icon={Icon.ArrowClockwise}
              onAction={() => setState({ status: "idle" })}
            />
          </ActionPanel>
        }
      />
    );
  }

  const markdown = `# Promo Code: ${state.data.code}\n\n${formatPromoDetails(state.data)}`;

  return (
    <Detail
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard title="Copy Promo Code" content={state.data.code} />
          <Action.CopyToClipboard title="Copy Promotion ID" content={state.data.id} />
          {state.data.coupon && (
            <Action.CopyToClipboard title="Copy Coupon ID" content={state.data.coupon.id} />
          )}
          <Action
            title="Check Another Code"
            icon={Icon.ArrowClockwise}
            onAction={() => {
              setState({ status: "idle" });
              setPromoCode("");
            }}
          />
        </ActionPanel>
      }
    />
  );
}
