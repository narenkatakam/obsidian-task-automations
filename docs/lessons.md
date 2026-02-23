# Lessons & Gotchas

Debugging notes for anyone running into issues with these automations on macOS.

## Full Disk Access (FDA) Is Required for launchd + iCloud Drive

**Problem:** Scripts run by `launchd` cannot access `~/Library/Mobile Documents/` (iCloud Drive). Directory listing globs return nothing. File reads (`cat`, `grep`) get `Operation not permitted`.

**Why:** macOS requires processes to have Full Disk Access (FDA) to access iCloud Drive. Terminal.app has FDA (granted in System Settings), so scripts work manually. But `launchd` invokes `/bin/bash` directly, and `/bin/bash` doesn't have FDA by default.

**Symptoms:**
- `daily-create` logs "No previous note found" even though yesterday's note exists
- `task-sort` stderr shows `cat: .../file.md: Operation not permitted`
- Today's note is created but empty (no tasks carried over)
- Scripts work perfectly when run manually from terminal

**Fix:** Grant `/bin/bash` Full Disk Access:
1. System Settings > Privacy & Security > Full Disk Access
2. Click the + button
3. Press Cmd+Shift+G and type `/bin/bash`
4. Enable the toggle

**Resilience:** The `daily-create` script now uses computed dates instead of directory globs — it checks `yesterday.md`, then day-before, etc. (up to 14 days back). This avoids the directory listing step, but file reads still require FDA. The scripts detect FDA failures at startup and log clear instructions.

## osascript Is Not the Answer for iCloud File Access

**Problem:** Scripts using `osascript -e "do shell script \"cat '...'\"` to read iCloud files fail when invoked by `launchd`.

**Why:** Two separate issues:
1. Multi-layer escaping (`bash > osascript > do shell script > bash`) makes variable references fragile. `$var` inside a double-quoted osascript string gets parsed by the outer bash shell, not the inner one. With `set -u`, unbound variables crash the script.
2. When `launchd` invokes `osascript`, it runs in a more restricted macOS sandbox than an interactive terminal.

**Rule:** Never use `osascript "do shell script"` for simple file operations on macOS. It adds complexity and breaks permissions.

## launchd vs Terminal Permissions

**Problem:** Scripts work in terminal but fail under `launchd`.

**Why:** Your terminal app (Terminal.app, iTerm, etc.) has Full Disk Access granted in System Settings. When you run a script from the terminal, it inherits those permissions. `launchd` does not — it runs `/bin/bash` which has its own (absent) FDA entry.

**How to debug:**
1. Check stderr log: `cat ~/Library/Logs/obsidian-daily-stderr.log` or `obsidian-sort-stderr.log`
2. Check main log: `cat ~/Library/Logs/obsidian-automation.log`
3. Check exit code: `launchctl list | grep obsidian` (column 2 is the last exit code)
4. Run the script manually to compare: `bash /path/to/script.sh`

## Never Use Globs for Previous Note Discovery

**Problem:** `for f in "$VAULT_DIR"/*.md` requires directory listing permission, which fails under `launchd` without FDA.

**Fix:** Use computed-date approach — check `YYYY-MM-DD.md` for yesterday, day before, etc.:
```bash
for i in $(seq 1 14); do
  PREV_DATE=$(date -j -v-"${i}d" "+%Y-%m-%d")
  CANDIDATE="$VAULT_DIR/$PREV_DATE.md"
  [ -f "$CANDIDATE" ] && PREV_FILE="$CANDIDATE" && break
done
```

This also inherently avoids non-date files (e.g., `Quick Tips.md`) since we only ever look for `YYYY-MM-DD.md` filenames.

## Always Normalize macOS date to Midnight

**Problem:** `date -j -f "%Y-%m-%d" "2026-02-21" "+%s"` fills in the **current** hour:minute:second for unspecified time fields. Two calls made seconds apart produce different timestamps, breaking equality comparisons.

**Fix:** Always specify `00:00:00` explicitly for date-only comparisons:
```bash
# WRONG — timestamp includes current time, non-deterministic
date -j -f "%Y-%m-%d" "$d" "+%s"

# RIGHT — always midnight, safe for comparisons
date -j -f "%Y-%m-%d %H:%M:%S" "$d 00:00:00" "+%s"
```

This is critical for the task sort script which compares due dates against today to categorize tasks as overdue/today/upcoming.

## Idempotency

The sort script normalizes and compares content before writing. This prevents:
- Unnecessary iCloud sync triggers
- Obsidian reload flicker
- File modification timestamp churn

If nothing changed, it does nothing.

## --force Flag for Recovery

The `daily-create` script accepts `--force` to re-populate today's note even if it already exists. This is useful when:
- The 6 AM run created an empty note (FDA issue)
- You want to manually re-trigger carry-forward after fixing permissions
- You need to regenerate tasks after making changes to the previous day's note
