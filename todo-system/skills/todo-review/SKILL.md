---
name: todo-review
description: |
  Review and prioritize todos, show roadmap, and manage _INDEX overflow. This skill should be used when reviewing todos, checking status, showing what's on the plate, viewing the roadmap, prioritizing work, deciding what to work on next, or checking for index overflow. It should NOT be used for creating, editing, or deleting todos — use todo-manage for that. Trigger on: "review my todos", "what's on my plate", "todo status", "show roadmap", "todo:review", "what should I work on next", "what's next", "prioritize", "what's left to do", "open items", "todo review", "check overflow", "how's my backlog".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Todo Review

Read-only review of `_INDEX` files and optional `roadmap.md` overflow archives. Present prioritized status, roadmap views, and overflow management recommendations.

This skill never creates or modifies todos — that is `todo-manage`'s responsibility. The sole exception is overflow management (Workflow C), which restructures the _INDEX/roadmap split.

## Paths

```
<scope>/.claude/prompts/todos/_INDEX       # main manifest
<scope>/.claude/prompts/todos/roadmap.md   # overflow archive (optional)
<scope>/.claude/prompts/todos/todos.config.md  # config overrides (optional)
```

**Scopes to check (both, always):**
- **Project:** `<project-root>/.claude/prompts/todos/_INDEX`
- **Global:** `~/.claude/prompts/todos/_INDEX`

## _INDEX Format Summary

The `_INDEX` file uses a fixed four-section layout with a summary blockquote:

```markdown
# Todos — <scope>

> **Items:** N open, M done (last 7 days)
> **Last updated:** YYYY-MM-DDTHH:MM:SSZ
> **Overflow:** false

## Now        ← P1, blocking / must-do-today
## Soon       ← P2, this week
## Later      ← P3, backlog
## Done (last 7 days)
```

Each item follows this format:
```markdown
- [ ] **P1** Title `added:YYYY-MM-DD` `prompt:category/slug.md`
  One-line context.
```

For the full specification, consult `${CLAUDE_PLUGIN_ROOT}/skills/todo-manage/references/index-format.md`.

---

## Workflow A: Status Overview

**Trigger:** "what's on my plate", "todo status", "open items", "review my todos"

### Steps

1. **Detect scope.** Glob for `_INDEX` at both project and global paths. Record which exist.
2. **Read all found `_INDEX` files.** Parse the summary blockquote and each urgency section.
3. **Compute staleness.** For each open item, compare `added:` date to today. Flag items older than 7 days as stale.
4. **Detect state-transition candidates.** Items whose context line contains conditional language ("blocked on", "fires when", "after X lands") — flag these as potentially actionable if surrounding session context suggests the condition may now be met.
5. **Present the status table** (see Presentation Format below).
6. **If both scopes exist,** present them under separate `## Status — <scope>` headers.

### Staleness Indicators

| Age | Indicator |
|-----|-----------|
| 0–7 days | (none) |
| 8–14 days | `[stale]` after title |
| 15–30 days | `[stale!]` after title |
| 31+ days | `[stale!!]` after title |

Apply indicators only in the status table, never modify the `_INDEX` file.

---

## Workflow B: Roadmap View

**Trigger:** "show roadmap", "full roadmap", "what's the big picture", "completion stats"

### Steps

1. **Read `_INDEX`** at both scopes.
2. **Read `roadmap.md`** if it exists (overflow archive for Later + Done).
3. **Merge items** into a unified view across all urgency buckets.
4. **Compute stats:**
   - Total open items (Now + Soon + Later)
   - Total done items (from Done section, count only last 7 days)
   - Completion rate: `done_7d / (done_7d + open) * 100`
   - Items per urgency bucket
5. **Present the full roadmap** — all items, grouped by urgency, with stats summary.
6. **Suggest re-prioritization** when:
   - Now has more than 5 items → "Now is overloaded — consider demoting non-blocking items to Soon."
   - Later has more than 20 items → "Later is bloated — consider pruning or archiving stale items."

### Roadmap Output Format

```
## Roadmap — <scope>

### Now (N items)
[items]

### Soon (N items)
[items]

### Later (N items)
[items]

---
**Open:** N · **Done (7d):** M · **Completion rate:** X%
**Velocity:** M items/week
```

---

## Workflow C: Overflow Management

**Trigger:** "check overflow", "index too big", "clean up todos", "manage overflow"

This is the only workflow that may modify files.

### Steps

1. **Read `_INDEX`.** Count open items and total lines.
2. **Read config overrides** from `todos.config.md` if it exists. Defaults:
   - `max_items: 50`
   - `max_lines: 200`
   - `stale_roadmap_days: 30`
3. **Evaluate thresholds:**

#### Over threshold (split needed)

When open items exceed `max_items` or total lines exceed `max_lines`:

1. Confirm with the user before modifying.
2. Move `## Later` and `## Done (last 7 days)` sections to `roadmap.md`.
3. Replace those sections in `_INDEX` with:
   ```markdown
   ## Later & Done

   See [roadmap.md](roadmap.md) for backlog and completed items.
   ```
4. Update the summary blockquote: set `Overflow: true`.
5. Recount and update item counts.

#### Under threshold with stale roadmap (consolidation candidate)

When under threshold AND `roadmap.md` exists AND `roadmap.md` has not been modified in `stale_roadmap_days`:

1. Offer to merge `roadmap.md` back into `_INDEX`.
2. If accepted: move Later and Done sections back, delete `roadmap.md`, set `Overflow: false`.

#### Under threshold, no roadmap

No action needed. Report "Index is within limits."

---

## Presentation Format

When showing status (Workflow A), use this table:

```
## Status — <scope>

| # | P | Title | Category | Added | Stale | Prompt |
|---|---|-------|----------|-------|-------|--------|
| 1 | P1 | Fix auth | infrastructure | 2026-05-01 | [stale!] | Yes |
| 2 | P2 | User export | features | 2026-05-08 | | Yes |
| 3 | P3 | Update ally | comms | 2026-05-05 | [stale] | No |

**Now:** 1 · **Soon:** 1 · **Later:** 1 · **Done (7d):** 2
```

Rules for the table:
- Sort by priority (P1 first), then by `added:` date ascending (oldest first within same priority).
- **Prompt** column: "Yes" if `prompt:` field is present, "No" otherwise.
- **Category** column: prefer the `### Category` subheader the item sits under; fall back to the `prompt:` path prefix if no subheader.
- **Stale** column: staleness indicator per the table in Workflow A, or blank if under 8 days.

---

## Quick Reference

### Invocation Examples

- "Review my todos" → Workflow A (status overview)
- "What should I work on next?" → Workflow A, then recommend the top P1 item
- "Show the roadmap" → Workflow B
- "Is my index getting too big?" → Workflow C
- "Prioritize my work" → Workflow A with explicit recommendation of ordering

### What This Skill Reads

| File | Purpose |
|------|---------|
| `<scope>/.claude/prompts/todos/_INDEX` | Main todo manifest |
| `<scope>/.claude/prompts/todos/roadmap.md` | Overflow archive |
| `<scope>/.claude/prompts/todos/todos.config.md` | Threshold overrides |

### What This Skill Does NOT Do

- Create new todos (use `todo-manage`)
- Edit todo content, priority, or urgency (use `todo-manage`)
- Create or modify prompt files (use `todo-manage`)
- Delete individual items

---

## Edge Cases

- **Empty `_INDEX`:** Report "No todos found at <scope>." Skip the table.
- **Missing `_INDEX` at both scopes:** Report "No _INDEX files found. Use todo-manage to create your first todo."
- **Malformed items:** Skip items that lack a checkbox or priority tag. Note count of skipped items at the bottom: "N items skipped (malformed)."
- **State-transition items:** When context line contains "blocked on", "fires when", "fires after", or "state-transition" — flag with a note: "Condition may be actionable — verify manually."
