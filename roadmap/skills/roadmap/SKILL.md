---
name: roadmap
description: "Project-level roadmap management — scaffold, track, and archive feature roadmaps in .claude/roadmap/."
argument-hint: "[init|add <feature> [item...]|view|done <feature> [item-keyword]|archive <feature>]"
when_to_use: "Triggers on: 'roadmap', 'feature backlog', 'what features are planned', 'project roadmap', 'track features', 'what am I working on in this project', 'feature status', 'add a feature', 'archive feature'. Not for session-level todos (use global todos). Not for one-off tasks (use TaskCreate)."
---

# Roadmap

Manages a `.claude/roadmap/` directory in the current project with an index file and per-feature roadmap files.

## Directory Structure

```
{repo}/.claude/roadmap/
├── ROADMAP.md              # Index — project context + feature list with @references
├── {feature-slug}.md       # Per-feature roadmap (kebab-case)
└── _archive/               # Completed/abandoned features
```

## Routing

Parse `$ARGUMENTS`. Split on first space: first token is CMD, remainder is ARG.

| CMD | Handler |
|---|---|
| _(empty)_ or `view` | [View](#view) |
| `init` | [Init](#init) — ARG is optional project name |
| `add` | [Add](#add) — ARG is `<feature-slug>` or `<feature-slug> <item-title...>` |
| `done` | [Done](#done) — ARG is `<feature-slug>` or `<feature-slug> <item-keyword...>` |
| `archive` | [Archive](#archive) — ARG is `<feature-slug>` |

If CMD doesn't match any handler, treat the entire `$ARGUMENTS` as a natural-language request and infer the closest command. When ambiguous, show the usage table above and ask for clarification.

---

## View

Display the current roadmap status. This is the default when no arguments are given.

1. Read `.claude/roadmap/ROADMAP.md`. If not found, report "No roadmap initialized. Run `/roadmap init` to get started." and stop.
2. For each feature in the index (identified by `###` headings and their `_File:_` reference):
   - Skip features with status `archived`
   - Read the feature file at `.claude/roadmap/<slug>.md`. If the file doesn't exist, display `[missing]` for that feature and continue.
   - Count items in each section (Backlog, In Progress, Done)
3. Display a formatted summary:

```
## {Project Name} — Roadmap

| Feature | Status | Backlog | In Progress | Done |
|---------|--------|---------|-------------|------|
| {name}  | {st}   | N       | N           | N    |

### {Feature Name} — `{status}`
**In Progress:**
- {item title}
**Backlog (top 3):**
- {item title} `priority:high`
```

Show in-progress items fully. Show top 3 backlog items sorted by priority (high > medium > low). Omit empty sections.

---

## Init

Scaffold `.claude/roadmap/` for the current project. Idempotent.

### Steps

1. **Check existing:** If `.claude/roadmap/ROADMAP.md` already exists, report "Roadmap already initialized" and run [View](#view). Stop.

2. **Detect project name:**
   - Parse first H1 heading from `CLAUDE.md` (e.g., `# CP Delivery Engine` -> "CP Delivery Engine")
   - Fallback: `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)`
   - Fallback: ARG if provided

3. **Detect project context:**
   - Extract the first paragraph after the H1 heading from CLAUDE.md, if present
   - Fallback: `"TODO: describe what this system does and who it serves."`

4. **Create directories:**
   ```bash
   mkdir -p .claude/roadmap/_archive
   ```

5. **Create ROADMAP.md** using Write tool with this template:

   ```markdown
   # Roadmap — {project-name}

   ## Context
   {context paragraph}

   ## Features

   _No features yet. Run `/roadmap add <feature-slug>` to add one._
   ```

6. **Wire into CLAUDE.md:**
   - If CLAUDE.md does not exist, create a minimal one: `# {project-name}\n\n{context paragraph}\n`
   - Read CLAUDE.md
   - If the string `@.claude/roadmap/ROADMAP.md` is NOT present, append this line at the very end: `@.claude/roadmap/ROADMAP.md`
   - Do not modify any existing content beyond the append

7. **Add to .gitignore:**
   - Read `.gitignore` (create if absent)
   - If `.claude/roadmap/` is NOT already in the file, append:
     ```
     # Project roadmap (personal — remove this line to share with team)
     .claude/roadmap/
     ```

8. Report what was created/wired.

---

## Add

Parse ARG: first token is `<feature-slug>`, remainder (if any) is `<rest>`.

If ARG is empty, report: "Usage: `/roadmap add <feature-slug>` to create a feature, or `/roadmap add <feature-slug> <item title>` to add an item." and stop.

### Decide mode

- If `.claude/roadmap/<feature-slug>.md` **exists** AND `<rest>` is non-empty: **Add Item** mode
- If `.claude/roadmap/<feature-slug>.md` **exists** AND `<rest>` is empty: report "Feature already exists. To add an item: `/roadmap add <feature-slug> <item title>`" and stop.
- If `.claude/roadmap/<feature-slug>.md` **does not exist**: **Add Feature** mode (use `<rest>` as the goal if provided)

### Add Feature

1. Normalise slug to kebab-case: lowercase, replace spaces and underscores with hyphens, strip non-alphanumeric except hyphens. Reject reserved slugs: `init`, `add`, `done`, `view`, `archive`, `status`, `start`, `help`. Report "'{slug}' is a reserved command name — choose a different slug." and stop.
2. Derive display name: convert slug to Title Case (`delivery-ui` -> `Delivery UI`).
3. Determine goal: use `<rest>` if provided, otherwise ask the user for a one-line goal.
4. **Create feature file** at `.claude/roadmap/<feature-slug>.md`:

   ```markdown
   # {Display Name}

   ## Goal
   {goal}

   ## Status: planning
   Branch: _(not started)_ | Worktree: _(none)_

   ## Backlog

   ## In Progress

   ## Done
   ```

5. **Update ROADMAP.md index:**
   - Read ROADMAP.md
   - Remove the placeholder line `_No features yet...` if present
   - Find the `## Features` section
   - Count existing feature entries (### headings under Features) to get next number N
   - Append after the last feature entry (or directly after `## Features` if none):

     ```markdown
     ### N. {Display Name} — `planning`
     {goal}
     _File: `.claude/roadmap/{feature-slug}.md`_
     ```

6. Report what was created.

### Add Item

1. Read `.claude/roadmap/<feature-slug>.md`
2. Find the `## Backlog` section
3. Insert a new item at the end of the Backlog section (before the next `##` heading):

   ```markdown
   - [ ] **{rest}** `priority:medium` `added:{YYYY-MM-DD}`
   ```

   Use today's date. Default priority is `medium`.

4. Report what was added.

---

## Done

Parse ARG: first token is `<feature-slug>`, remainder (if any) is `<item-keyword>`.

If ARG is empty, report: "Usage: `/roadmap done <feature-slug>` to mark a feature shipped, or `/roadmap done <feature-slug> <keyword>` to mark an item done." and stop.

Validate `.claude/roadmap/<feature-slug>.md` exists. If not, list available features and stop.

### Mode 1: Mark Item Done (when `<item-keyword>` is provided)

1. Read `.claude/roadmap/<feature-slug>.md`
2. Search the `## Backlog` and `## In Progress` sections for a checkbox line (`- [ ]`) whose bold title contains `<item-keyword>` (case-insensitive substring match).
3. If no match: list all unchecked items and report "No item matching '{keyword}' found."
4. If multiple matches: list them and ask which one.
5. If exactly one match:
   - Remove the matched line (and its indented context line below, if any) from its current section
   - Add to the `## Done` section: `- [x] **{original title}** \`completed:{YYYY-MM-DD}\``
   - Use Edit tool for surgical replacement
6. Report what was marked done.

### Mode 2: Mark Feature Shipped (when `<item-keyword>` is empty)

1. Read `.claude/roadmap/<feature-slug>.md`
2. Change `## Status: {old}` to `## Status: shipped`
3. Read `ROADMAP.md`, find the matching feature entry, change its status tag from `` `{old}` `` to `` `shipped` ``
4. Report.

---

## Archive

Move a completed or abandoned feature to `_archive/`.

1. Validate `.claude/roadmap/<feature-slug>.md` exists. If not, list available features and stop.
2. Ensure `_archive/` directory exists: `mkdir -p .claude/roadmap/_archive`
3. Move the file:
   ```bash
   mv .claude/roadmap/<feature-slug>.md .claude/roadmap/_archive/
   ```
4. Update ROADMAP.md:
   - Change the feature's status tag to `` `archived` ``
5. Report what was archived.

---

## Conventions

- **Slugs** are kebab-case, matching branch/worktree names where possible
- **Statuses:** `planning` | `in-progress` | `shipped` | `on-hold` | `archived`
- **Priorities:** `high` | `medium` | `low`
- **Dates** use `YYYY-MM-DD` format, always absolute (never relative)
- Feature numbers in the index are sequential but don't need to be contiguous after archival
- The `_archive/` directory preserves feature history for reference
