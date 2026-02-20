# Lessons & Gotchas

Debugging notes for anyone running into issues with these automations.

## osascript Is Not the Answer for iCloud File Access

**Problem:** Scripts using `osascript -e "do shell script \"cat '...'\"` to read iCloud files fail when invoked by `launchd`.

**Why:** Two separate issues:
1. Multi-layer escaping (`bash → osascript → do shell script → bash`) makes variable references fragile. `$var` inside a double-quoted osascript string gets parsed by the outer bash shell, not the inner one. With `set -u`, unbound variables crash the script.
2. When `launchd` invokes `osascript`, it runs in a more restricted macOS sandbox than an interactive terminal. The `osascript` process doesn't inherit Full Disk Access, so it can't read iCloud Drive files.

**Fix:** Use direct bash file operations. `cat`, `test -f`, `ls`, `cp`, and `touch` all work on iCloud Drive paths (`~/Library/Mobile Documents/...`) from both terminal and `launchd`. No wrapper needed.

**Rule:** Never use `osascript "do shell script"` for simple file operations on macOS. It adds complexity and breaks permissions.

## launchd vs Terminal Permissions

**Problem:** Scripts work in terminal but fail under `launchd`.

**Why:** Your terminal app (Terminal.app, iTerm, etc.) has Full Disk Access granted in System Settings. When you run a script from the terminal, it inherits those permissions. `launchd` does not — it runs with a more limited permission set.

**How to debug:**
1. Check stderr log: `cat ~/Library/Logs/<label>-stderr.log`
2. Check exit code: `launchctl list | grep <label>` (column 2 is the exit code)
3. Run the script manually to compare: `bash /path/to/script.sh`

## Date-Named File Filtering

**Problem:** Folder may contain non-date files (e.g., `Quick Tips.md`) alongside `YYYY-MM-DD.md` notes.

**Fix:** When scanning for previous notes, filter with a regex:
```bash
if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  # This is a date-named file
fi
```

## Idempotency

The sort script normalizes and compares content before writing. This prevents:
- Unnecessary iCloud sync triggers
- Obsidian reload flicker
- File modification timestamp churn

If nothing changed, it does nothing.
