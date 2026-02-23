#!/bin/bash
# uninstall.sh — Removes Obsidian Task Automations LaunchAgents

set -euo pipefail

LABEL_PREFIX="com.narenkatakam.obsidian"

echo "=== Uninstalling Obsidian Task Automations ==="

for agent in daily sort; do
  PLIST="$HOME/Library/LaunchAgents/${LABEL_PREFIX}-${agent}.plist"
  if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Removed: $PLIST"
  fi
done

echo ""
echo "LaunchAgents removed. Scripts and config are still in this folder."
echo "To fully remove, delete this directory."
