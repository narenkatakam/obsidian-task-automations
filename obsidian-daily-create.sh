#!/bin/bash
# obsidian-daily-create.sh
# Creates today's daily note and carries over pending tasks from the most recent previous note.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TODAY=$(date "+%Y-%m-%d")
TODAY_FILE="$VAULT_DIR/$TODAY.md"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [daily-create] $1" >> "$LOG"
}

# Check if today's note already exists
if [ -f "$TODAY_FILE" ]; then
  log "Today's note already exists: $TODAY.md — skipping"
  exit 0
fi

# Find the most recent previous date-based note (handles gaps/weekends)
# Only match YYYY-MM-DD.md files, skip non-date files
PREV_FILE=""
for f in "$VAULT_DIR"/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)
  if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$base" < "$TODAY" ]]; then
    if [ -z "$PREV_FILE" ] || [[ "$base" > "$(basename "$PREV_FILE" .md)" ]]; then
      PREV_FILE="$f"
    fi
  fi
done

PENDING_TASKS=""
if [ -n "$PREV_FILE" ]; then
  PREV_NAME=$(basename "$PREV_FILE" .md)
  log "Found previous note: $PREV_NAME"

  # Extract pending tasks (lines starting with - [ ])
  PENDING_TASKS=$(grep -E '^\- \[ \]' "$PREV_FILE" || true)

  if [ -n "$PENDING_TASKS" ]; then
    TASK_COUNT=$(echo "$PENDING_TASKS" | wc -l | tr -d ' ')
    log "Carrying over $TASK_COUNT pending task(s) from $PREV_NAME"
  else
    log "No pending tasks to carry over from $PREV_NAME"
  fi
else
  log "No previous note found"
fi

# Write today's note
if [ -n "$PENDING_TASKS" ]; then
  echo "$PENDING_TASKS" > "$TODAY_FILE"
else
  touch "$TODAY_FILE"
fi

log "Created today's note: $TODAY.md"
