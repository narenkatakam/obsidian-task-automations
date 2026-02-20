# Changelog

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
