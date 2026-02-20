# Obsidian Task Automations

Lightweight macOS automations for [Obsidian](https://obsidian.md/) daily notes. No plugins to install, no Electron apps running in the background — just two bash scripts and macOS LaunchAgents.

## What It Does

| Automation | Schedule | What Happens |
|---|---|---|
| **Daily Note Creation** | 6:00 AM | Creates today's `YYYY-MM-DD.md` note and carries over all pending tasks from the previous day |
| **Task Sorting** | Every 30 min | Sorts pending tasks by due date (earliest first). Pushes completed tasks to the bottom (most recent completion first) |

Works with the [Obsidian Tasks plugin](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji format:

```markdown
- [ ] 📅 2026-02-20 - Buy groceries
- [ ] 📅 2026-02-22 - Submit report
- [x] 📅 2026-02-19 - Fix login bug ✅ 2026-02-20
```

**Before sorting:**
```
- [ ] 📅 2026-02-22 - Submit report
- [x] 📅 2026-02-19 - Fix login bug ✅ 2026-02-20
- [ ] 📅 2026-02-20 - Buy groceries
- [ ] Review PR (no date)
```

**After sorting:**
```
- [ ] 📅 2026-02-20 - Buy groceries
- [ ] 📅 2026-02-22 - Submit report
- [ ] Review PR (no date)
- [x] 📅 2026-02-19 - Fix login bug ✅ 2026-02-20
```

Non-task content (meeting notes, headings, horizontal rules) below your tasks is preserved untouched.

## Requirements

- macOS (uses `launchd` for scheduling and `date -j` for date parsing)
- Obsidian with daily notes in a dedicated folder (e.g., `Daily Notes/`)
- [Tasks plugin](https://github.com/obsidian-tasks-group/obsidian-tasks) configured with emoji format (optional but recommended)

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

### 2. Run the installer

```bash
./install.sh
```

This will:
- Make scripts executable
- Create two LaunchAgents in `~/Library/LaunchAgents/`
- Load them immediately

### 3. Test it

```bash
# Create today's note (if it doesn't exist)
bash obsidian-daily-create.sh

# Sort tasks in today's note
bash obsidian-task-sort.sh

# Check the log
tail -10 ~/Library/Logs/obsidian-automation.log
```

## How It Works

### Daily Note Creation (`obsidian-daily-create.sh`)

1. Checks if today's note (`YYYY-MM-DD.md`) already exists — skips if so
2. Finds the most recent previous date-named note (handles weekends/gaps)
3. Extracts all pending tasks (`- [ ] ...`) from that note
4. Writes them into today's new note

### Task Sorting (`obsidian-task-sort.sh`)

1. Reads today's note
2. Separates lines into three buckets: pending (`- [ ]`), completed (`- [x]`), everything else
3. Sorts pending by `📅 YYYY-MM-DD` ascending (tasks without dates go last)
4. Sorts completed by `✅ YYYY-MM-DD` descending (most recently completed first)
5. Reassembles: sorted pending, then completed, then other content
6. Only writes back if something actually changed (idempotent)

### Why Not osascript?

Early versions wrapped file operations in `osascript -e "do shell script \"...\""` to "bypass iCloud sandbox restrictions." This is unnecessary — bash has direct access to iCloud Drive files at `~/Library/Mobile Documents/`. The osascript layer actually *causes* problems:

- Multi-layer escaping breaks with `set -u` (unbound variable errors)
- `launchd`-invoked `osascript` has restricted sandbox permissions, causing "Operation not permitted" on iCloud files

Direct bash access is simpler, faster, and works reliably from both terminal and `launchd`.

## Uninstalling

```bash
./uninstall.sh
```

Removes the LaunchAgents. Scripts and config stay in the folder.

## File Structure

```
obsidian-task-automations/
├── config.sh                  # Your vault path and settings
├── obsidian-daily-create.sh   # Daily note creation script
├── obsidian-task-sort.sh      # Task sorting script
├── install.sh                 # Installer (creates LaunchAgents)
├── uninstall.sh               # Uninstaller
├── docs/
│   ├── changelog.md           # What changed and when
│   └── lessons.md             # Debugging notes and gotchas
├── LICENSE
└── README.md
```

## Recommended Obsidian Plugins

These automations work standalone, but pair well with:

- **[Calendar](https://github.com/liamcain/obsidian-calendar-plugin)** — sidebar calendar that creates/opens daily notes on click
- **[Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)** — emoji-style task management with due dates and auto-completion dates
- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — query tasks across notes

## License

MIT
