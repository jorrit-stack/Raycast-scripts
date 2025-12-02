import { Action, ActionPanel, Clipboard, Detail, Icon, Toast, showHUD, showToast } from "@raycast/api";
import { useEffect, useState } from "react";
import { captureActiveTabContent } from "./lib/browsers";
import { extractUserId } from "./lib/user-id";
import { buildAdminUrl, buildRateLimitsUrl } from "./lib/urls";

type CaptureState =
  | { status: "loading" }
  | { status: "success"; userId: string; source: string; url: string; title: string; browser: string }
  | { status: "error"; error: string };

export default function Command() {
  const [state, setState] = useState<CaptureState>({ status: "loading" });

  useEffect(() => {
    void runCapture();
  }, []);

  async function runCapture() {
    setState({ status: "loading" });
    try {
      const content = await captureActiveTabContent();
      if (!content) {
        setState({
          status: "error",
          error:
            "No supported Chromium-based browser with an active admin tab was found. Make sure Chrome/Arc/Dia is open to stackblitz.com.",
        });
        return;
      }

      const extraction = extractUserId(content);
      if (!extraction) {
        setState({
          status: "error",
          error:
            "Could not find a numeric User ID on the current page. Try focusing the table row and ensure 'Allow JavaScript from Apple Events' is enabled in your browser.",
        });
        return;
      }

      await Clipboard.copy(extraction.userId);
      await showHUD(`Copied User ID ${extraction.userId}`);

      setState({
        status: "success",
        userId: extraction.userId,
        source: extraction.source,
        url: content.url,
        title: content.title,
        browser: content.browser,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      setState({ status: "error", error: message });
      await showToast({ style: Toast.Style.Failure, title: "Capture failed", message });
    }
  }

  if (state.status === "loading") {
    return <Detail isLoading markdown="Attempting to capture User ID from active Chromium browser…" />;
  }

  if (state.status === "error") {
    return (
      <Detail
        markdown={`# Capture Failed ❌\n\n${state.error}\n\n- Ensure a supported browser is active (Chrome, Brave, Edge, Arc, Chromium, Dia).\n- Open a StackBlitz admin page filtered to the user.\n- In Chrome-based browsers, enable “Allow JavaScript from Apple Events” in Developer settings.\n- Then rerun this command.`}
        actions={
          <ActionPanel>
            <Action title="Retry" icon={Icon.ArrowClockwise} onAction={() => void runCapture()} />
          </ActionPanel>
        }
      />
    );
  }

  const adminUrl = buildAdminUrl(state.userId);
  const rateLimitsUrl = buildRateLimitsUrl(state.userId);

  const markdown = `# User ID Captured ✅

- **User ID:** \`${state.userId}\`
- **Detected via:** ${state.source}
- **Browser:** ${state.browser}
- **Page:** [${state.title}](${state.url})
`;

  return (
    <Detail
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard title="Copy User ID" content={state.userId} />
          <Action title="Re-run Capture" icon={Icon.ArrowClockwise} onAction={() => void runCapture()} />
          <Action.OpenInBrowser title="Open StackBlitz Admin" url={adminUrl} />
          <Action.OpenInBrowser title="Open Bolt Rate Limits" url={rateLimitsUrl} />
          <Action
            title="Copy Rate Limits URL"
            icon={Icon.Clipboard}
            onAction={async () => {
              await Clipboard.copy(rateLimitsUrl);
              await showToast({ style: Toast.Style.Success, title: "Copied rate-limits URL" });
            }}
          />
        </ActionPanel>
      }
    />
  );
}

