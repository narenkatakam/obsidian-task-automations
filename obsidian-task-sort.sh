#!/bin/bash
# obsidian-task-sort.sh
# Sorts tasks in today's daily note: pending (by due date asc) then completed (by done date desc).
# Non-task content is preserved below the sorted tasks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TODAY=$(date "+%Y-%m-%d")
TODAY_FILE="$VAULT_DIR/$TODAY.md"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [task-sort] $1" >> "$LOG"
}

# Check if today's note exists
if [ ! -f "$TODAY_FILE" ]; then
  log "Today's note does not exist: $TODAY.md — skipping"
  exit 0
fi

# Read today's note
CONTENT=$(cat "$TODAY_FILE")

if [ -z "$CONTENT" ]; then
  log "Today's note is empty — skipping"
  exit 0
fi

# Separate into pending tasks, completed tasks, and other content
PENDING_TASKS=""
COMPLETED_TASKS=""
OTHER_CONTENT=""

while IFS= read -r line; do
  if echo "$line" | grep -qE '^\- \[ \] '; then
    PENDING_TASKS="${PENDING_TASKS}${line}"$'\n'
  elif echo "$line" | grep -qE '^\- \[x\] '; then
    COMPLETED_TASKS="${COMPLETED_TASKS}${line}"$'\n'
  else
    OTHER_CONTENT="${OTHER_CONTENT}${line}"$'\n'
  fi
done <<< "$CONTENT"

# Extract due date timestamp for sorting
get_due_timestamp() {
  local line="$1"
  local d
  d=$(echo "$line" | grep -oE '📅 [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') || true
  if [ -n "$d" ]; then
    date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null || echo "9999999999"
  else
    echo "9999999999"
  fi
}

# Extract done date timestamp for sorting
get_done_timestamp() {
  local line="$1"
  local d
  d=$(echo "$line" | grep -oE '✅ [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') || true
  if [ -n "$d" ]; then
    date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Sort pending tasks by due date ascending (no date goes last)
SORTED_PENDING=""
if [ -n "$PENDING_TASKS" ]; then
  TAGGED=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ts=$(get_due_timestamp "$line")
    TAGGED="${TAGGED}${ts}	${line}"$'\n'
  done <<< "$PENDING_TASKS"
  SORTED_PENDING=$(echo -n "$TAGGED" | sort -t$'\t' -k1,1n | cut -f2-)
fi

# Sort completed tasks by completion date descending (most recent first)
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

# Strip leading and trailing blank lines from other content
OTHER_TRIMMED=$(echo -n "$OTHER_CONTENT" | awk '
  NF { found=1 }
  { lines[NR]=$0 }
  END {
    for (i=1; i<=NR; i++) if (lines[i] ~ /[^ \t]/) { first=i; break }
    for (i=NR; i>=1; i--) if (lines[i] ~ /[^ \t]/) { last=i; break }
    if (first && last) for (i=first; i<=last; i++) print lines[i]
  }
')

# Reassemble: sorted pending, sorted completed, blank line, other content
NEW_CONTENT=""
if [ -n "$SORTED_PENDING" ]; then
  NEW_CONTENT="${SORTED_PENDING}"
fi
if [ -n "$SORTED_COMPLETED" ]; then
  if [ -n "$NEW_CONTENT" ]; then
    NEW_CONTENT="${NEW_CONTENT}"$'\n'"${SORTED_COMPLETED}"
  else
    NEW_CONTENT="${SORTED_COMPLETED}"
  fi
fi
if [ -n "$OTHER_TRIMMED" ]; then
  if [ -n "$NEW_CONTENT" ]; then
    NEW_CONTENT="${NEW_CONTENT}"$'\n'$'\n'"${OTHER_TRIMMED}"
  else
    NEW_CONTENT="${OTHER_TRIMMED}"
  fi
fi

# Only write if content changed (compare normalized — strip trailing blanks)
ORIGINAL_NORMALIZED=$(echo "$CONTENT" | awk '
  { lines[NR]=$0 }
  END {
    for (i=NR; i>=1; i--) if (lines[i] ~ /[^ \t]/) { last=i; break }
    for (i=1; i<=last; i++) print lines[i]
  }
')
NEW_NORMALIZED=$(echo "$NEW_CONTENT" | awk '
  { lines[NR]=$0 }
  END {
    for (i=NR; i>=1; i--) if (lines[i] ~ /[^ \t]/) { last=i; break }
    for (i=1; i<=last; i++) print lines[i]
  }
')

if [ "$ORIGINAL_NORMALIZED" = "$NEW_NORMALIZED" ]; then
  log "No changes needed for $TODAY.md"
  exit 0
fi

# Write back directly
echo "$NEW_CONTENT" > "$TODAY_FILE"

log "Sorted tasks in $TODAY.md"
