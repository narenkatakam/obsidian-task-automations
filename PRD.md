# PRODUCT REQUIREMENTS DOCUMENT (PRD)

## Project: Obsidian Frictionless Daily Execution Engine

Version: 1.0 Owner: User Environment: Obsidian + iCloud + Calendar
Plugin + Tasks Plugin + Templater

------------------------------------------------------------------------

# 1. Objective

Automate daily task carry-forward and execution workflow inside Obsidian
with near-zero manual intervention while preserving historical integrity
and ensuring iCloud-safe operations.

Phase 1 Focus: Build a frictionless execution engine. Analytics and
second-brain expansion are future phases.

------------------------------------------------------------------------

# 2. Core Principles

1.  Vault = source of truth\
2.  Daily notes = execution lens\
3.  History is immutable\
4.  Automation must be non-destructive\
5.  Sorting must support real-world execution\
6.  System must function fully offline\
7.  Pure Obsidian implementation (no external cron/services)

------------------------------------------------------------------------

# 3. User Workflow (Target State)

When user opens Obsidian on a new day:

1.  Today's note auto-creates (if not exists)

2.  Pending tasks from most recent previous daily note are extracted

3.  Only incomplete tasks are carried forward

4.  Recurring tasks regenerate only if previous instance was completed

5.  Tasks are auto-tagged with metadata

6.  Tasks are sorted:

    -   Overdue (oldest overdue first)
    -   Today
    -   Upcoming (nearest due first)

7.  Weekly summary auto-generates every Sunday with:

    -   Completed tasks
    -   Overdue count

Zero manual copying.

------------------------------------------------------------------------

# 4. Functional Requirements

## 4.1 Daily Note Auto-Creation

Trigger: - On vault open OR daily note open

Behavior: - If today's daily note does not exist → create - If exists →
do nothing

Skip-day logic: - Do NOT create notes for missed days - Only create
current day note

------------------------------------------------------------------------

## 4.2 Task Extraction Logic

Source: - Most recent previous daily note that exists

Extraction Rules: - Select all tasks matching: - `- [ ]` - Has due
date - Ignore: - `- [x]` - Completed tasks - Free text

Do NOT: - Modify previous note - Change timestamps - Change due dates

------------------------------------------------------------------------

## 4.3 Metadata Injection

When carrying forward tasks, append:

• Creation timestamp (original retained)\
• Auto context tags (if missing)\
• Priority tag (optional future enhancement)

Example:

    - [ ] 2026-02-25 Prepare stakeholder deck  
      #project/PCLM #deepwork  
      🆕 Created: 2026-02-21

If metadata already exists → do not duplicate.

------------------------------------------------------------------------

## 4.4 Sorting Logic

Tasks must render in this order:

1️⃣ Overdue\
Due date \< today\
Sorted oldest overdue first

2️⃣ Today\
Due date == today

3️⃣ Upcoming\
Due date \> today\
Sorted nearest due first

Sorting must occur dynamically at note generation. No manual sorting
required.

------------------------------------------------------------------------

## 4.5 Recurring Task Handling

Recurring tasks regenerate only when:

-   Previous instance is marked complete

If recurring task remains incomplete: - Do NOT generate next occurrence

------------------------------------------------------------------------

## 4.6 Weekly Summary (Sunday Only)

Trigger: - When Sunday daily note opens

Create new note:

`Weekly Summary – YYYY-WW`

Include:

## Completed Tasks

List of all completed tasks from Mon--Sun

## Overdue Count

Number of tasks still overdue at end of week

------------------------------------------------------------------------

# 5. Non-Functional Requirements

## 5.1 Non-Destructive Integrity

Automation may: - Create new notes - Read previous notes - Insert
content in new note

Automation may NOT: - Edit previous notes - Rewrite due dates - Modify
completed tasks - Alter recurring definitions

------------------------------------------------------------------------

## 5.2 Sync Safety

Must: - Avoid simultaneous note rewriting - Avoid modifying same file
twice - Avoid background auto-save conflicts

All automation occurs only when note is opened.

------------------------------------------------------------------------

## 5.3 Performance

Execution must: - Complete in \<2 seconds - Not block UI - Not duplicate
tasks

------------------------------------------------------------------------

# 6. Edge Cases

  Case                               Expected Behavior
  ---------------------------------- ---------------------------
  Open vault twice                   No duplicate tasks
  Yesterday had no tasks             Create empty task section
  All tasks completed yesterday      Today note starts clean
  Recurring task incomplete          No new instance generated
  Multiple vault openings same day   No re-execution
  iCloud delay                       No destructive edits

------------------------------------------------------------------------

# 7. Task Lifecycle Model

State 1: Created\
State 2: Carried Forward\
State 3: Completed\
State 4: Archived (implicit via history)

Tasks never mutate retroactively.

------------------------------------------------------------------------

# 8. Data Model (Daily Note Structure)

    # YYYY-MM-DD

    ## Tasks

    <auto-generated block>

    ## Notes

    <free writing space>

Tasks must remain in structured section only.

------------------------------------------------------------------------

# 9. Plugins Required

Mandatory: - Calendar - Tasks - Templater

Optional (future): - Dataview (for weekly summary formatting)

------------------------------------------------------------------------

# 10. Future Enhancements (Not Phase 1)

• Task analytics dashboard\
• Velocity tracking\
• Execution capacity metrics\
• Energy tagging\
• Strategic vs Tactical dashboards\
• Auto workload balancing\
• AI-assisted prioritization\
• Second brain integration

------------------------------------------------------------------------

# 11. Success Criteria

System is successful when:

-   User never manually copies tasks again
-   No duplicate tasks occur
-   No historical note is modified
-   Sorting always matches execution logic
-   Weekly summary generates automatically
-   iPhone widget reflects today's pending tasks within 5 seconds
