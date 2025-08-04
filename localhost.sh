#!/bin/bash

# Required parameters:

# @raycast.schemaVersion 1

# @raycast.title Localhost Vite

# @raycast.mode silent

# Optional parameters:
# @raycast.icon 😶‍🌫️
# @raycast.packageName vite-local

# Documentation:
# @raycast.description open a Vite development server
# @raycast.author jorrit_harmamny
# @raycast.authorURL https://raycast.com/jorrit_harmamny

osascript -e 'tell application "Arc" to activate' -e 'tell application "System Events" to keystroke "n" using {command down}' -e 'delay 0.5' -e 'tell application "Arc" to open location "http://localhost:5173"' && osascript -e 'tell application "System Events" to keystroke "f" using {command down, control down}'
