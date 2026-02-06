#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start CX Agent Codespace
# @raycast.mode silent

# Find the Codespace for cx-agent.
CODESPACE_NAME=$(gh codespace list --json name,repository --jq '.[] | select(.repository=="stackblitz/cx-agent") | .name' | head -n 1)

if [ -z "$CODESPACE_NAME" ]; then
  echo "No Codespace found for stackblitz/cx-agent. Create one from https://github.com/stackblitz/cx-agent in your browser first."
  exit 1
fi

# Check state
STATE=$(gh codespace list --json name,repository,state --jq '.[] | select(.repository=="stackblitz/cx-agent") | .state' | head -n 1)

if [ "$STATE" != "Available" ]; then
  gh codespace start "$CODESPACE_NAME"
fi