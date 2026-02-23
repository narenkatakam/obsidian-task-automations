# Changelog

## 2026-02-23 — v2.0

### Added
- **Categorical sorting** — Tasks now sort into `### Overdue`, `### Today`, and `### Upcoming` sections instead of a flat list
- **Metadata injection** — Tasks stamped with `🆕 YYYY-MM-DD` on first carry-forward, preserved on subsequent carries
- **Recurring task handling** — `🔁 every day/week/month/Monday-Sunday` patterns; regenerates next occurrence only when previous is completed
- **Weekly summary** — Auto-generates `Weekly Summary — YYYY-WW.md` in a separate folder every Sunday with completed tasks and overdue count
- **Structured note format** — Notes now use `# Date` / `## Tasks` / `## Notes` sections
- **`--force` flag** — `obsidian-daily-create.sh --force` re-populates today's note even if it already has content
- **FDA detection** — Both scripts check for Full Disk Access at startup and log clear error messages if iCloud Drive is inaccessible
- **Computed-date previous note discovery** — Walks backwards up to 14 days checking `YYYY-MM-DD.md` directly (no directory glob needed)
- **`WEEKLY_DIR` config** — Configurable weekly summary output directory in `config.sh`

### Changed
- Task sorting now uses timestamp comparison normalized to midnight (fixes edge cases with same-day comparisons)
- Previous note lookup no longer requires directory listing permission (works even without FDA for the directory glob step)
- Sort script handles both structured (`## Tasks` / `## Notes`) and legacy (flat) note formats
- Comprehensive README rewrite with full feature documentation

### Fixed
- Date comparison bug: `date -j -f "%Y-%m-%d"` fills in current time for unspecified fields, causing two calls seconds apart to produce different timestamps. Now always normalizes to midnight with `"$d 00:00:00"`.

## 2026-02-20 — v1.0

### Fixed
- **Daily-create script crash:** Removed `osascript` wrappers that caused unbound variable errors (`$f`, `$base`) when invoked by `launchd` with `set -u` enabled
- **Task-sort "Operation not permitted":** Removed `osascript` wrappers that caused macOS sandbox permission failures when `launchd` invoked `osascript` to access iCloud Drive files

### Added
- `config.sh` — Centralized configuration (vault path, log location)
- `install.sh` — One-command setup that creates LaunchAgents automatically
- `uninstall.sh` — Clean removal of LaunchAgents
- Date-pattern filtering to skip non-date files (e.g., `Quick Tips.md`) when finding previous notes

### Changed
- Scripts now use direct bash file access instead of `osascript "do shell script"` wrappers
- Scripts source `config.sh` via `SCRIPT_DIR` for portability

## 2026-02-19 — v0.1 (Initial)

### Added
- `obsidian-daily-create.sh` — Creates daily notes with pending task carryover
- `obsidian-task-sort.sh` — Sorts tasks by due date, pushes completed to bottom
- LaunchAgent plists for scheduled execution (6 AM daily + every 30 min)
