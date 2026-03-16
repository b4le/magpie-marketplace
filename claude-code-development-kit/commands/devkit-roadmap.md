---
name: devkit-roadmap
description: List all dev kit expansion roadmap items with status, priority, and theme
argument-hint: "[--p0] [--status <status>] [--theme <name>]"
allowed-tools:
  - Read
  - Grep
user-invocable: true
version: 1.0.0
---

Display the dev kit expansion roadmap in a scannable format.

Read the roadmap file:
@${CLAUDE_PLUGIN_ROOT}/docs/roadmap.md

Parse the roadmap and present a summary table with these columns:

| ID | Item | Theme | Type | Priority | Status |
|----|------|-------|------|----------|--------|

Extract each item from the `## Roadmap Summary` table at the bottom of the file.

After the table, show:
- Count of items by status (planned/in-progress/complete)
- Count of items by priority (P0/P1/P2)
- A reminder: `Run /devkit-investigate <ID> to see the full investigation prompt for any item.`

## Arguments

Optional filters passed via `$ARGUMENTS`:

| Flag | Example | Effect |
|------|---------|--------|
| `--p0` or `--priority P0` | `/devkit-roadmap --p0` | Show only P0 priority items |
| `--status <value>` | `/devkit-roadmap --status in-progress` | Filter by status (planned/in-progress/complete) |
| `--theme <name>` | `/devkit-roadmap --theme Security` | Filter to items in a named theme |

If `$ARGUMENTS` includes `--p0` or `--priority P0`, filter to show only P0 items.
If `$ARGUMENTS` includes `--status in-progress`, filter to that status.
If `$ARGUMENTS` includes `--theme <name>`, filter to items in that theme.
