#!/bin/bash
# obsidian-task-sort.sh
# Sorts tasks in today's daily note into categorical sections:
#   Overdue (oldest first) → Today → Upcoming (nearest first) → Completed (most recent first)
# Preserves structured format (## Tasks / ## Notes) and non-task content.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TODAY=$(date "+%Y-%m-%d")
TODAY_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 00:00:00" "+%s")
TODAY_FILE="$VAULT_DIR/$TODAY.md"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [task-sort] $1" >> "$LOG"
}

# --- FDA check: verify we can access the vault directory ---
if ! ls "$VAULT_DIR" >/dev/null 2>&1; then
  log "ERROR: Cannot access vault directory — likely missing Full Disk Access for /bin/bash"
  exit 1
fi

# Check if today's note exists
if [ ! -f "$TODAY_FILE" ]; then
  log "Today's note does not exist: $TODAY.md — skipping"
  exit 0
fi

# Verify we can read the file
if ! head -1 "$TODAY_FILE" >/dev/null 2>&1; then
  log "ERROR: Cannot read $TODAY.md — Operation not permitted (grant FDA to /bin/bash)"
  exit 1
fi

# Read today's note
CONTENT=$(cat "$TODAY_FILE")

if [ -z "$CONTENT" ]; then
  log "Today's note is empty — skipping"
  exit 0
fi

# --- Parse structured format ---
# Detect if file has ## Tasks / ## Notes structure
HAS_STRUCTURE=false
if echo "$CONTENT" | grep -q '^## Tasks'; then
  HAS_STRUCTURE=true
fi

TASKS_CONTENT=""
NOTES_CONTENT=""
HEADER_LINE=""

if [ "$HAS_STRUCTURE" = true ]; then
  # Extract the title line (# YYYY-MM-DD)
  HEADER_LINE=$(echo "$CONTENT" | grep -E '^# [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1) || true

  # Extract content between ## Tasks and ## Notes
  TASKS_CONTENT=$(echo "$CONTENT" | awk '
    /^## Tasks/ { in_tasks=1; next }
    /^## Notes/ { in_tasks=0; next }
    in_tasks { print }
  ')

  # Extract content after ## Notes
  NOTES_CONTENT=$(echo "$CONTENT" | awk '
    /^## Notes/ { in_notes=1; next }
    in_notes { print }
  ')
else
  # Legacy format: treat entire content as tasks, will wrap in structure
  TASKS_CONTENT="$CONTENT"
  HEADER_LINE="# $TODAY"
  log "Legacy format detected — will migrate to structured format"
fi

# --- Separate tasks by type ---
PENDING_TASKS=""
COMPLETED_TASKS=""
OTHER_LINES=""

while IFS= read -r line; do
  if echo "$line" | grep -qE '^\- \[ \] '; then
    PENDING_TASKS="${PENDING_TASKS}${line}"$'\n'
  elif echo "$line" | grep -qE '^\- \[x\] '; then
    COMPLETED_TASKS="${COMPLETED_TASKS}${line}"$'\n'
  elif echo "$line" | grep -qE '^### (Overdue|Today|Upcoming)$'; then
    # Skip existing category headers — we'll regenerate them
    :
  elif [ -n "$line" ]; then
    OTHER_LINES="${OTHER_LINES}${line}"$'\n'
  fi
done <<< "$TASKS_CONTENT"

# --- Extract due date timestamp for sorting ---
get_due_timestamp() {
  local line="$1"
  local d
  d=$(echo "$line" | grep -oE '📅 [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') || true
  if [ -n "$d" ]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$d 00:00:00" "+%s" 2>/dev/null || echo "9999999999"
  else
    echo "9999999999"
  fi
}

# --- Extract done date timestamp for sorting ---
get_done_timestamp() {
  local line="$1"
  local d
  d=$(echo "$line" | grep -oE '✅ [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') || true
  if [ -n "$d" ]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$d 00:00:00" "+%s" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# --- Categorize and sort pending tasks ---
OVERDUE=""
TODAY_BUCKET=""
UPCOMING=""

if [ -n "$PENDING_TASKS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ts=$(get_due_timestamp "$line")
    if [ "$ts" = "9999999999" ]; then
      # No date — treat as upcoming
      UPCOMING="${UPCOMING}${ts}	${line}"$'\n'
    elif [ "$ts" -lt "$TODAY_TS" ]; then
      OVERDUE="${OVERDUE}${ts}	${line}"$'\n'
    elif [ "$ts" -eq "$TODAY_TS" ]; then
      TODAY_BUCKET="${TODAY_BUCKET}${ts}	${line}"$'\n'
    else
      UPCOMING="${UPCOMING}${ts}	${line}"$'\n'
    fi
  done <<< "$PENDING_TASKS"
fi

# Sort each bucket
SORTED_OVERDUE=""
if [ -n "$OVERDUE" ]; then
  SORTED_OVERDUE=$(echo -n "$OVERDUE" | sort -t$'\t' -k1,1n | cut -f2-)
fi

SORTED_TODAY=""
if [ -n "$TODAY_BUCKET" ]; then
  SORTED_TODAY=$(echo -n "$TODAY_BUCKET" | cut -f2-)
fi

SORTED_UPCOMING=""
if [ -n "$UPCOMING" ]; then
  SORTED_UPCOMING=$(echo -n "$UPCOMING" | sort -t$'\t' -k1,1n | cut -f2-)
fi

# --- Sort completed tasks by done date descending ---
SORTED_COMPLETED=""
if [ -n "$COMPLETED_TASKS" ]; then
  TAGGED=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ts=$(get_done_timestamp "$line")
    TAGGED="${TAGGED}${ts}	${line}"$'\n'
  done <<< "$COMPLETED_TASKS"
  SORTED_COMPLETED=$(echo -n "$TAGGED" | sort -t$'\t' -k1,1rn | cut -f2-)
fi

# --- Assemble the Tasks section with categorical headers ---
TASKS_ASSEMBLED=""

if [ -n "$SORTED_OVERDUE" ]; then
  TASKS_ASSEMBLED+="### Overdue"$'\n'$'\n'"$SORTED_OVERDUE"$'\n'$'\n'
fi

if [ -n "$SORTED_TODAY" ]; then
  TASKS_ASSEMBLED+="### Today"$'\n'$'\n'"$SORTED_TODAY"$'\n'$'\n'
fi

if [ -n "$SORTED_UPCOMING" ]; then
  TASKS_ASSEMBLED+="### Upcoming"$'\n'$'\n'"$SORTED_UPCOMING"$'\n'$'\n'
fi

if [ -n "$SORTED_COMPLETED" ]; then
  TASKS_ASSEMBLED+="$SORTED_COMPLETED"$'\n'
fi

# Trim trailing newlines from tasks section
TASKS_ASSEMBLED=$(echo -n "$TASKS_ASSEMBLED" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

# --- Strip leading/trailing blank lines from other content in tasks section ---
OTHER_TRIMMED=""
if [ -n "$OTHER_LINES" ]; then
  OTHER_TRIMMED=$(echo -n "$OTHER_LINES" | awk '
    NF { found=1 }
    { lines[NR]=$0 }
    END {
      for (i=1; i<=NR; i++) if (lines[i] ~ /[^ \t]/) { first=i; break }
      for (i=NR; i>=1; i--) if (lines[i] ~ /[^ \t]/) { last=i; break }
      if (first && last) for (i=first; i<=last; i++) print lines[i]
    }
  ')
fi

# Add other lines after tasks if any
if [ -n "$OTHER_TRIMMED" ]; then
  if [ -n "$TASKS_ASSEMBLED" ]; then
    TASKS_ASSEMBLED="${TASKS_ASSEMBLED}"$'\n'$'\n'"$OTHER_TRIMMED"
  else
    TASKS_ASSEMBLED="$OTHER_TRIMMED"
  fi
fi

# --- Reassemble the full note ---
NEW_CONTENT="${HEADER_LINE}"$'\n'$'\n'"## Tasks"$'\n'$'\n'
if [ -n "$TASKS_ASSEMBLED" ]; then
  NEW_CONTENT+="${TASKS_ASSEMBLED}"$'\n'
fi
NEW_CONTENT+=$'\n'"## Notes"$'\n'
if [ -n "$NOTES_CONTENT" ]; then
  NEW_CONTENT+=$'\n'"$NOTES_CONTENT"
else
  NEW_CONTENT+=""
fi

# --- Only write if content changed (compare normalized — strip trailing blanks) ---
normalize() {
  echo "$1" | awk '
    { lines[NR]=$0 }
    END {
      for (i=NR; i>=1; i--) if (lines[i] ~ /[^ \t]/) { last=i; break }
      for (i=1; i<=last; i++) print lines[i]
    }
  '
}

ORIGINAL_NORMALIZED=$(normalize "$CONTENT")
NEW_NORMALIZED=$(normalize "$NEW_CONTENT")

if [ "$ORIGINAL_NORMALIZED" = "$NEW_NORMALIZED" ]; then
  log "No changes needed for $TODAY.md"
  exit 0
fi

# Write back directly
echo "$NEW_CONTENT" > "$TODAY_FILE"

log "Sorted tasks in $TODAY.md"
