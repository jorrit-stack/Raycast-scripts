#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Ask CX Agent
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Prompt" }
# @raycast.argument2 { "type": "text", "placeholder": "Project ID (optional)", "optional": true }
# @raycast.argument3 { "type": "text", "placeholder": "User ID (optional)", "optional": true }

PROMPT="$1"
PROJECT_ID="$2"
USER_ID="$3"

# 1) Find or pick the Codespace for cx-agent.
# This filters codespaces whose repository is stackblitz/cx-agent and takes the first.
CODESPACE_NAME=$(gh codespace list --json name,repository --jq '.[] | select(.repository=="stackblitz/cx-agent") | .name' | head -n 1)

if [ -z "$CODESPACE_NAME" ]; then
  echo "No Codespace found for stackblitz/cx-agent. Create one from https://github.com/stackblitz/cx-agent in your browser first."
  exit 1
fi

# Check state and start if not available
STATE=$(gh codespace list --json name,repository,state --jq '.[] | select(.repository=="stackblitz/cx-agent") | .state' | head -n 1)

if [ "$STATE" != "Available" ]; then
  gh codespace start "$CODESPACE_NAME"
fi

# 2) Build the message we want to send to `claude`
MSG="$PROMPT"
if [ -n "$PROJECT_ID" ]; then
  MSG="$MSG\n\nprojectId: $PROJECT_ID"
fi
if [ -n "$USER_ID" ]; then
  MSG="$MSG\n\nuserId: $USER_ID"
fi

# 3) Run claude inside the Codespace (non-interactive)
# Assumes `claude` is on PATH in the Codespace and that cx-agent repo is the workspace.
gh codespace ssh -c "cd /workspaces/cx-agent && echo \"$MSG\" | claude" "$CODESPACE_NAME"
