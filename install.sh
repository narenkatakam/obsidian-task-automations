#!/bin/bash
# install.sh — Sets up Obsidian Task Automations on macOS
#
# Usage:
#   cd obsidian-automations
#   ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL_DAILY="com.narenkatakam.obsidian-daily"
LABEL_SORT="com.narenkatakam.obsidian-sort"

echo "=== Obsidian Task Automations — Installer ==="
echo ""

# Step 1: Verify config
if [ ! -f "$SCRIPT_DIR/config.sh" ]; then
  echo "ERROR: config.sh not found. Copy config.sh.example to config.sh and edit it."
  exit 1
fi

source "$SCRIPT_DIR/config.sh"

if [ ! -d "$VAULT_DIR" ]; then
  echo "ERROR: VAULT_DIR does not exist: $VAULT_DIR"
  echo "Edit config.sh and set the correct path to your Obsidian daily notes folder."
  exit 1
fi

echo "Vault directory: $VAULT_DIR"
echo "Log file: $LOG"
echo ""

# Step 2: Check Full Disk Access
echo "Checking Full Disk Access..."
if ls "$VAULT_DIR" >/dev/null 2>&1; then
  echo "  ✓ Current session can access vault directory"
else
  echo "  ✗ Cannot access vault directory from this session"
fi

echo ""
echo "  ⚠  IMPORTANT: /bin/bash must have Full Disk Access for launchd to work."
echo "     System Settings > Privacy & Security > Full Disk Access > add /bin/bash"
echo "     (Press Cmd+Shift+G in the file picker and type /bin/bash)"
echo ""

# Step 3: Make scripts executable
chmod +x "$SCRIPT_DIR/obsidian-daily-create.sh"
chmod +x "$SCRIPT_DIR/obsidian-task-sort.sh"
echo "Scripts made executable."

# Step 4: Create LaunchAgent for daily note creation (runs at 6 AM)
DAILY_PLIST="$HOME/Library/LaunchAgents/${LABEL_DAILY}.plist"
cat > "$DAILY_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL_DAILY}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>${SCRIPT_DIR}/obsidian-daily-create.sh</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>6</integer>
		<key>Minute</key>
		<integer>0</integer>
	</dict>
	<key>StandardOutPath</key>
	<string>${HOME}/Library/Logs/obsidian-daily-stdout.log</string>
	<key>StandardErrorPath</key>
	<string>${HOME}/Library/Logs/obsidian-daily-stderr.log</string>
</dict>
</plist>
EOF

echo "Created LaunchAgent: $DAILY_PLIST"

# Step 5: Create LaunchAgent for task sorting (runs every 30 minutes)
SORT_PLIST="$HOME/Library/LaunchAgents/${LABEL_SORT}.plist"
cat > "$SORT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL_SORT}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>${SCRIPT_DIR}/obsidian-task-sort.sh</string>
	</array>
	<key>StartInterval</key>
	<integer>1800</integer>
	<key>StandardOutPath</key>
	<string>${HOME}/Library/Logs/obsidian-sort-stdout.log</string>
	<key>StandardErrorPath</key>
	<string>${HOME}/Library/Logs/obsidian-sort-stderr.log</string>
</dict>
</plist>
EOF

echo "Created LaunchAgent: $SORT_PLIST"

# Step 6: Load agents
launchctl unload "$DAILY_PLIST" 2>/dev/null || true
launchctl unload "$SORT_PLIST" 2>/dev/null || true
launchctl load "$DAILY_PLIST"
launchctl load "$SORT_PLIST"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "  Daily note creation:  runs at 6:00 AM"
echo "  Task sorting:         runs every 30 minutes"
echo ""
echo "  Logs: $LOG"
echo ""
echo "  To test now:  bash obsidian-daily-create.sh && bash obsidian-task-sort.sh"
echo "  To uninstall: bash uninstall.sh"
echo ""
echo "  REMINDER: Grant Full Disk Access to /bin/bash if not done already."
