import { Action, ActionPanel, Clipboard, Form, Icon, Toast, open, showHUD, showToast } from "@raycast/api";
import { useEffect, useState } from "react";

type FormValues = {
  identifier: string;
};

const STACKBLITZ_ADMIN_BASE = "https://stackblitz.com/admin/users?commit=Filter&order=id_desc";

export default function Command() {
  const [identifier, setIdentifier] = useState("");

  useEffect(() => {
    async function bootstrapFromClipboard() {
      try {
        const text = await Clipboard.readText();
        if (!text) return;
        const trimmed = text.trim();
        if (!trimmed) return;
        // Only prefill if clipboard looks like an ID or email
        if (/^\d+$/.test(trimmed) || trimmed.includes("@")) {
          setIdentifier(trimmed);
        }
      } catch {
        // ignore clipboard errors; command still works
      }
    }
    void bootstrapFromClipboard();
  }, []);

  async function handleSubmit(values: FormValues) {
    const input = values.identifier.trim();
    if (!input) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Enter a user ID or email address",
      });
      return;
    }

    const isNumeric = /^\d+$/.test(input);
    const url = isNumeric
      ? `${STACKBLITZ_ADMIN_BASE}&q%5Bid_eq%5D=${encodeURIComponent(input)}`
      : `${STACKBLITZ_ADMIN_BASE}&q%5Bby_email_address%5D=${encodeURIComponent(input)}`;

    await open(url);
    await showHUD(`Opened admin for ${isNumeric ? `ID ${input}` : input}`);
  }

  return (
    <Form
      navigationTitle="Open Bolt Admin User"
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Open in Browser" icon={Icon.Globe} onSubmit={handleSubmit} />
          <Action.CopyToClipboard title="Copy Admin URL" icon={Icon.Clipboard} content={buildPreviewURL(identifier)} />
        </ActionPanel>
      }
    >
      <Form.Description text="Jump directly to a StackBlitz admin user page by ID or e-mail." />
      <Form.TextField
        id="identifier"
        title="User ID or Email"
        placeholder="e.g. 1805475 or jorrit@joy-ict.nl"
        value={identifier}
        onChange={setIdentifier}
        autoFocus
      />
    </Form>
  );
}

function buildPreviewURL(input: string) {
  const trimmed = input.trim();
  if (!trimmed) {
    return STACKBLITZ_ADMIN_BASE;
  }
  const isNumeric = /^\d+$/.test(trimmed);
  return isNumeric
    ? `${STACKBLITZ_ADMIN_BASE}&q%5Bid_eq%5D=${encodeURIComponent(trimmed)}`
    : `${STACKBLITZ_ADMIN_BASE}&q%5Bby_email_address%5D=${encodeURIComponent(trimmed)}`;
}
