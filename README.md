# Obsidian Task Automations

Lightweight macOS automations for [Obsidian](https://obsidian.md/) daily notes. No plugins to install, no Electron apps running in the background — just two bash scripts and macOS LaunchAgents.

**Zero manual task management.** Tasks carry forward automatically, sort themselves by urgency, and recurring tasks regenerate on completion. You open Obsidian and start working.

## What It Does

| Automation | Schedule | What Happens |
|---|---|---|
| **Daily Note Creation** | 6:00 AM | Creates today's `YYYY-MM-DD.md`, carries over pending tasks, regenerates completed recurring tasks, generates weekly summary on Sundays |
| **Task Sorting** | Every 30 min | Categorizes tasks into Overdue / Today / Upcoming sections, sorts by due date, pushes completed tasks to the bottom |

## Features

- **Automatic task carry-forward** — Pending tasks move to today's note every morning
- **Categorical sorting** — Tasks auto-organize into `### Overdue`, `### Today`, and `### Upcoming` sections
- **Recurring tasks** — `🔁 every day/week/month/Monday` regenerates with the next due date when completed
- **Metadata tracking** — `🆕 YYYY-MM-DD` stamps when a task was first carried forward
- **Weekly summaries** — Auto-generated every Sunday with completed tasks and overdue count
- **Structured notes** — Clean `# Date` / `## Tasks` / `## Notes` format
- **Idempotent** — Scripts only write when content actually changes (no unnecessary iCloud syncs)
- **`--force` recovery** — Re-populate today's note if something went wrong

## Task Format

Works with the [Obsidian Tasks plugin](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji format:

```markdown
- [ ] 📅 2026-02-20 — Buy groceries
- [ ] 📅 2026-02-22 — Submit report 🔁 every week
- [x] 📅 2026-02-19 — Fix login bug ✅ 2026-02-20
```

### Daily Note Structure

```markdown
# 2026-02-23

## Tasks

### Overdue

- [ ] 📅 2026-02-20 — Buy groceries 🆕 2026-02-21

### Today

- [ ] 📅 2026-02-23 — Review PR

### Upcoming

- [ ] 📅 2026-02-25 — Submit report 🔁 every week

- [x] 📅 2026-02-22 — Deploy hotfix ✅ 2026-02-23

## Notes

Free writing space — not touched by automation.
```

## Requirements

- **macOS** (uses `launchd` for scheduling and BSD `date -j` for date parsing)
- **Obsidian** with daily notes in a dedicated folder
- **Full Disk Access** for `/bin/bash` (required for `launchd` to access iCloud Drive — see [Troubleshooting](#troubleshooting))
- [Tasks plugin](https://github.com/obsidian-tasks-group/obsidian-tasks) (optional but recommended for emoji-format due dates)

## Installation

```bash
git clone https://github.com/narenkatakam/obsidian-task-automations.git
cd obsidian-task-automations
```

### 1. Configure your vault path

Edit `config.sh` and set `VAULT_DIR` to your daily notes folder:

```bash
# macOS with iCloud sync:
VAULT_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault/Daily Notes"

# macOS local vault:
VAULT_DIR="$HOME/ObsidianVault/Daily Notes"
```

You can also set `WEEKLY_DIR` for where weekly summaries are stored (defaults to a `Weekly Summaries` folder alongside your vault).

### 2. Grant Full Disk Access to /bin/bash

This is **required** for the automations to access your vault when running in the background via `launchd`.

1. Open **System Settings > Privacy & Security > Full Disk Access**
2. Click **+**
3. Press **Cmd+Shift+G** and type `/bin/bash`
4. Enable the toggle

> Without this, scripts will work from your terminal but fail silently when run by `launchd`. The scripts detect this and log clear error messages.

### 3. Run the installer

```bash
./install.sh
```

This will:
- Make scripts executable
- Create two LaunchAgents in `~/Library/LaunchAgents/`
- Load them immediately

### 4. Test it

```bash
# Create today's note (carries over pending tasks)
bash obsidian-daily-create.sh

# Sort tasks in today's note
bash obsidian-task-sort.sh

# Force re-create today's note (even if it exists)
bash obsidian-daily-create.sh --force

# Check logs
tail -20 ~/Library/Logs/obsidian-automation.log
```

## How It Works

### Daily Note Creation (`obsidian-daily-create.sh`)

Runs at 6:00 AM every day.

1. Checks if today's note already has content — **skips** if so (use `--force` to override)
2. Walks backwards up to 14 days to find the most recent previous note (handles weekends, vacations, gaps)
3. Extracts all pending tasks (`- [ ] ...`) and stamps them with `🆕 YYYY-MM-DD` on first carry-forward
4. Scans for completed recurring tasks (`- [x] ... 🔁 ...`) and regenerates them with the next due date
5. Writes today's note with structured format: `# Date` / `## Tasks` / `## Notes`
6. On **Sundays**, generates a weekly summary in the `Weekly Summaries/` folder

### Recurring Tasks

Add `🔁` followed by a pattern to any task:

| Pattern | Example | Next Due Date |
|---|---|---|
| `🔁 every day` | Daily standup | Tomorrow |
| `🔁 every week` | Weekly review | +7 days |
| `🔁 every month` | Monthly report | +1 month |
| `🔁 every Monday` | Sprint planning | Next Monday |

Recurring tasks regenerate **only when completed**. If a recurring task stays incomplete, it carries forward as-is (no duplicates).

### Task Sorting (`obsidian-task-sort.sh`)

Runs every 30 minutes.

1. Reads today's note and parses the `## Tasks` section
2. Categorizes pending tasks by comparing due dates to today:
   - **Overdue** — due date < today (oldest first)
   - **Today** — due date = today
   - **Upcoming** — due date > today or no date (nearest first)
3. Sorts completed tasks by completion date (most recent first)
4. Inserts `### Overdue`, `### Today`, `### Upcoming` section headers
5. Preserves non-task content (notes, horizontal rules, etc.)
6. **Only writes if something changed** — prevents unnecessary iCloud sync triggers

### Weekly Summary

Generated automatically every Sunday. Stored in `Weekly Summaries/` folder.

```markdown
# Weekly Summary — 2026-W08

**Week:** 2026-02-16 (Mon) to 2026-02-22 (Sun)

## Completed Tasks

### 2026-02-16

- [x] 📅 2026-02-16 — Deploy v2.0 ✅ 2026-02-16

### 2026-02-18

- [x] 📅 2026-02-18 — Write docs ✅ 2026-02-18

## Overdue Count

**2 task(s)** still overdue at end of week
```

## Uninstalling

```bash
./uninstall.sh
```

Removes the LaunchAgents. Scripts and config remain in the folder.

## File Structure

```
obsidian-task-automations/
├── config.sh                  # Your vault path and settings
├── obsidian-daily-create.sh   # Daily note creation + carry-forward + recurring
├── obsidian-task-sort.sh      # Categorical task sorting
├── install.sh                 # One-command installer (creates LaunchAgents)
├── uninstall.sh               # Clean removal of LaunchAgents
├── docs/
│   ├── changelog.md           # Version history
│   └── lessons.md             # Debugging notes and macOS gotchas
├── LICENSE                    # MIT
└── README.md
```

## Troubleshooting

### Scripts work in terminal but fail under launchd

**Cause:** Your terminal app (Terminal.app, iTerm) has Full Disk Access. `launchd` runs `/bin/bash` directly, which doesn't inherit those permissions.

**Fix:** Grant `/bin/bash` Full Disk Access (see [Installation step 2](#2-grant-full-disk-access-to-binbash)).

**How to debug:**
```bash
# Check stderr logs
cat ~/Library/Logs/obsidian-daily-stderr.log
cat ~/Library/Logs/obsidian-sort-stderr.log

# Check main log
cat ~/Library/Logs/obsidian-automation.log

# Check if agents are loaded and their last exit code
launchctl list | grep obsidian
```

### Today's note was created empty

The 6 AM run couldn't read the previous note (FDA issue). After granting Full Disk Access:

```bash
bash obsidian-daily-create.sh --force
```

### Why not osascript?

Early versions wrapped file operations in `osascript -e "do shell script \"...\""`. This is unnecessary — bash has direct access to iCloud Drive at `~/Library/Mobile Documents/`. The osascript layer causes:
- Multi-layer escaping breaks with `set -u`
- `launchd`-invoked `osascript` has restricted sandbox permissions

Direct bash is simpler, faster, and works reliably from both terminal and `launchd`.

For more debugging details, see [docs/lessons.md](docs/lessons.md).

## Recommended Obsidian Plugins

These automations work standalone, but pair well with:

- **[Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)** — emoji-style task management with due dates and completion tracking
- **[Calendar](https://github.com/liamcain/obsidian-calendar-plugin)** — sidebar calendar that creates/opens daily notes on click
- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — query and aggregate tasks across your entire vault

## License

MIT
