#!/bin/bash
# obsidian-daily-create.sh
# Creates today's daily note and carries over pending tasks from the most recent previous note.
# Features: structured format, metadata injection, recurring task handling, weekly summary.
#
# Usage:
#   ./obsidian-daily-create.sh           # Normal run (skips if today's note has content)
#   ./obsidian-daily-create.sh --force   # Re-create today's note even if it exists

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TODAY=$(date "+%Y-%m-%d")
TODAY_FILE="$VAULT_DIR/$TODAY.md"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [daily-create] $1" >> "$LOG"
}

# --- FDA check: verify we can access the vault directory ---
if ! ls "$VAULT_DIR" >/dev/null 2>&1; then
  log "ERROR: Cannot access vault directory — likely missing Full Disk Access for /bin/bash"
  log "FIX: System Settings > Privacy & Security > Full Disk Access > add /bin/bash"
  echo "ERROR: Cannot access $VAULT_DIR" >&2
  echo "Grant Full Disk Access to /bin/bash in System Settings > Privacy & Security" >&2
  exit 1
fi

# Skip if today's note already has content (unless --force)
if [ -f "$TODAY_FILE" ] && [ "$FORCE" = false ]; then
  FILE_SIZE=$(wc -c < "$TODAY_FILE" | tr -d ' ')
  if [ "$FILE_SIZE" -gt 0 ]; then
    log "Today's note already has content ($FILE_SIZE bytes): $TODAY.md — skipping"
    exit 0
  fi
  # File exists but is empty — proceed to populate it
  log "Today's note exists but is empty — will populate with carried-over tasks"
fi

# --- Find previous note using computed dates (no glob needed) ---
# Walk backwards up to 14 days to find the most recent note with content
PREV_FILE=""
for i in $(seq 1 14); do
  PREV_DATE=$(date -j -v-"${i}d" "+%Y-%m-%d" 2>/dev/null) || continue
  CANDIDATE="$VAULT_DIR/$PREV_DATE.md"
  if [ -f "$CANDIDATE" ]; then
    # Verify we can actually read it
    if head -1 "$CANDIDATE" >/dev/null 2>&1; then
      PREV_FILE="$CANDIDATE"
      break
    else
      log "WARNING: Found $PREV_DATE.md but cannot read it (FDA issue?)"
    fi
  fi
done

# --- Extract pending tasks with metadata injection ---
PENDING_TASKS=""
RECURRING_REGENERATED=""

if [ -n "$PREV_FILE" ]; then
  PREV_NAME=$(basename "$PREV_FILE" .md)
  log "Found previous note: $PREV_NAME"

  # Extract pending tasks with metadata injection
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | grep -qE '🆕'; then
      # Already has creation metadata — carry forward as-is
      PENDING_TASKS="${PENDING_TASKS}${line}"$'\n'
    else
      # First carry-forward: stamp with previous note's date as creation date
      PENDING_TASKS="${PENDING_TASKS}${line} 🆕 ${PREV_NAME}"$'\n'
    fi
  done < <(grep -E '^\- \[ \]' "$PREV_FILE" 2>/dev/null || true)

  if [ -n "$PENDING_TASKS" ]; then
    TASK_COUNT=$(echo -n "$PENDING_TASKS" | grep -c '^\- \[ \]' || true)
    log "Carrying over $TASK_COUNT pending task(s) from $PREV_NAME"
  else
    log "No pending tasks to carry over from $PREV_NAME"
  fi

  # --- Recurring task handling ---
  # Scan previous note for completed tasks with 🔁 marker
  # Only regenerate if the task was completed (- [x])
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Extract the recurrence pattern (text after 🔁, before any other emoji)
    RECUR_PATTERN=$(echo "$line" | grep -oE '🔁 [a-zA-Z ]+' | sed 's/^🔁 //' | sed 's/ *$//')

    # Strip completion markers to rebuild as pending task
    # Remove "- [x] " prefix, replace with "- [ ] "
    NEW_TASK=$(echo "$line" | sed 's/^\- \[x\] /- [ ] /')
    # Remove the completion date (✅ YYYY-MM-DD)
    NEW_TASK=$(echo "$NEW_TASK" | sed -E 's/ ✅ [0-9]{4}-[0-9]{2}-[0-9]{2}//')
    # Remove old creation metadata (will get fresh one)
    NEW_TASK=$(echo "$NEW_TASK" | sed -E 's/ 🆕 [0-9]{4}-[0-9]{2}-[0-9]{2}//')

    # Calculate next due date based on pattern
    NEXT_DUE=""
    case "$RECUR_PATTERN" in
      "every day")
        NEXT_DUE=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY" "+%Y-%m-%d" 2>/dev/null) || true
        ;;
      "every week")
        NEXT_DUE=$(date -j -v+7d -f "%Y-%m-%d" "$TODAY" "+%Y-%m-%d" 2>/dev/null) || true
        ;;
      "every month")
        NEXT_DUE=$(date -j -v+1m -f "%Y-%m-%d" "$TODAY" "+%Y-%m-%d" 2>/dev/null) || true
        ;;
      "every Monday"|"every Tuesday"|"every Wednesday"|"every Thursday"|"every Friday"|"every Saturday"|"every Sunday")
        # Calculate next occurrence of the specified weekday
        TARGET_DAY=$(echo "$RECUR_PATTERN" | sed 's/every //')
        case "$TARGET_DAY" in
          Monday)    VFLAG="-v+monday" ;;
          Tuesday)   VFLAG="-v+tuesday" ;;
          Wednesday) VFLAG="-v+wednesday" ;;
          Thursday)  VFLAG="-v+thursday" ;;
          Friday)    VFLAG="-v+friday" ;;
          Saturday)  VFLAG="-v+saturday" ;;
          Sunday)    VFLAG="-v+sunday" ;;
        esac
        NEXT_DUE=$(date -j "$VFLAG" -f "%Y-%m-%d" "$TODAY" "+%Y-%m-%d" 2>/dev/null) || true
        ;;
      *)
        # Unknown pattern — default to +7 days
        log "WARNING: Unknown recurrence pattern '$RECUR_PATTERN' — defaulting to weekly"
        NEXT_DUE=$(date -j -v+7d -f "%Y-%m-%d" "$TODAY" "+%Y-%m-%d" 2>/dev/null) || true
        ;;
    esac

    if [ -n "$NEXT_DUE" ]; then
      # Update the due date in the task
      NEW_TASK=$(echo "$NEW_TASK" | sed -E "s/📅 [0-9]{4}-[0-9]{2}-[0-9]{2}/📅 $NEXT_DUE/")
      # Add creation metadata
      NEW_TASK="${NEW_TASK} 🆕 ${TODAY}"

      # Dedup: check if a task with same description already exists in pending
      TASK_DESC=$(echo "$NEW_TASK" | sed -E 's/^- \[ \] 📅 [0-9]{4}-[0-9]{2}-[0-9]{2} [—-] //' | sed -E 's/ 🔁.*$//' | sed -E 's/ 🆕.*$//')
      if echo "$PENDING_TASKS" | grep -qF -- "$TASK_DESC"; then
        log "Skipping duplicate recurring task: $TASK_DESC"
      else
        RECURRING_REGENERATED="${RECURRING_REGENERATED}${NEW_TASK}"$'\n'
        log "Regenerated recurring task ($RECUR_PATTERN): $TASK_DESC → due $NEXT_DUE"
      fi
    fi
  done < <(grep -E '^\- \[x\].*🔁' "$PREV_FILE" 2>/dev/null || true)
else
  log "No previous note found in the last 14 days"
fi

# Combine pending + regenerated recurring tasks
ALL_TASKS="${PENDING_TASKS}${RECURRING_REGENERATED}"
# Remove trailing newline
ALL_TASKS=$(echo -n "$ALL_TASKS" | sed '/^$/d')

# --- Write today's note with structured format ---
{
  echo "# $TODAY"
  echo ""
  echo "## Tasks"
  echo ""
  if [ -n "$ALL_TASKS" ]; then
    echo "$ALL_TASKS"
  fi
  echo ""
  echo "## Notes"
  echo ""
} > "$TODAY_FILE"

log "Created today's note: $TODAY.md"

# --- Weekly summary (Sunday only) ---
DAY_OF_WEEK=$(date "+%u")  # 1=Monday, 7=Sunday
if [ "$DAY_OF_WEEK" -eq 7 ]; then
  log "Today is Sunday — generating weekly summary"

  WEEK_NUM=$(date "+%Y-W%V")
  mkdir -p "$WEEKLY_DIR"
  SUMMARY_FILE="$WEEKLY_DIR/Weekly Summary — $WEEK_NUM.md"

  # Skip if summary already exists (idempotent)
  if [ -f "$SUMMARY_FILE" ]; then
    log "Weekly summary already exists: $WEEK_NUM — skipping"
  else
    # Calculate Monday of this week (6 days ago from Sunday)
    MONDAY=$(date -j -v-6d "+%Y-%m-%d")

    # Collect completed tasks from Mon–Sun
    COMPLETED_THIS_WEEK=""
    for i in $(seq 6 -1 0); do
      CHECK_DATE=$(date -j -v-"${i}d" "+%Y-%m-%d")
      CHECK_FILE="$VAULT_DIR/$CHECK_DATE.md"
      if [ -f "$CHECK_FILE" ]; then
        DAILY_COMPLETED=$(grep -E '^\- \[x\]' "$CHECK_FILE" 2>/dev/null || true)
        if [ -n "$DAILY_COMPLETED" ]; then
          COMPLETED_THIS_WEEK="${COMPLETED_THIS_WEEK}### $CHECK_DATE"$'\n'$'\n'"$DAILY_COMPLETED"$'\n'$'\n'
        fi
      fi
    done

    # Count overdue tasks from today's note
    OVERDUE_COUNT=0
    if [ -f "$TODAY_FILE" ]; then
      TODAY_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 00:00:00" "+%s" 2>/dev/null) || true
      while IFS= read -r line; do
        DUE_DATE=$(echo "$line" | grep -oE '📅 [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') || true
        if [ -n "$DUE_DATE" ]; then
          DUE_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DUE_DATE 00:00:00" "+%s" 2>/dev/null) || continue
          if [ "$DUE_TS" -lt "$TODAY_TS" ]; then
            OVERDUE_COUNT=$((OVERDUE_COUNT + 1))
          fi
        fi
      done < <(grep -E '^\- \[ \]' "$TODAY_FILE" 2>/dev/null || true)
    fi

    # Write summary
    {
      echo "# Weekly Summary — $WEEK_NUM"
      echo ""
      echo "**Week:** $MONDAY (Mon) to $TODAY (Sun)"
      echo ""
      echo "## Completed Tasks"
      echo ""
      if [ -n "$COMPLETED_THIS_WEEK" ]; then
        echo "$COMPLETED_THIS_WEEK"
      else
        echo "*No tasks completed this week*"
        echo ""
      fi
      echo "## Overdue Count"
      echo ""
      echo "**$OVERDUE_COUNT task(s)** still overdue at end of week"
    } > "$SUMMARY_FILE"

    log "Weekly summary created: Weekly Summary — $WEEK_NUM.md"
  fi
fi
