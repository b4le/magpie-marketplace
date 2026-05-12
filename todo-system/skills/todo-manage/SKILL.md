---
name: todo-manage
description: |
  Add, update, complete, and capture todo items with paired session-launch prompts. Use when adding a todo, updating a todo, marking a todo done, creating a todo prompt, capturing deferred work, parking something for later, deferring items, tracking followups, capturing next steps, reprioritizing, or at session end to record unfinished work. Trigger on: "add a todo", "create a todo", "capture this", "park this for later", "defer this", "followup needed", "next steps", "track this", "todo:add", "I should remember to", "we need to", "mark as done", "complete the todo", "bump to P1", "reprioritize", "update the todo".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Agent
---

# Todo Management

Manage structured todo items with paired session-launch prompts. Each todo lives in an `_INDEX` manifest organized by urgency and category, with optional prompt files that give a fresh session full context to execute the work.

## Core Concepts

- **_INDEX** -- central manifest of all todos for a scope. See @references/index-format.md for the full format specification.
- **Session-launch prompt** -- a point-in-time artifact with 7 fixed sections that gives a fresh session everything it needs. See @references/prompt-template.md for format and naming conventions.
- **Gates** -- four modular controls (worktree, specialist-routing, parallelization, review-gate) that govern how prompts execute. See @references/gate-configuration.md for values, precedence, and injected steps.
- **Scope** -- project-level (`<project>/.claude/prompts/todos/`) or root-level (`~/.claude/prompts/todos/`).

---

## Workflow A: Add a Todo

### A1. Determine Scope

```
Is scope explicitly stated?
├─ "root" / "global" / "home"  → ~/.claude/prompts/todos/
├─ "project" / project name    → <project>/.claude/prompts/todos/
└─ Not stated
   ├─ CWD is in a git repo or has .claude/  → project scope (use git root)
   ├─ No project context                    → root scope
   └─ Ambiguous                             → ask user via AskUserQuestion
```

### A2. Read or Create _INDEX

1. Check for `<scope>/.claude/prompts/todos/_INDEX`.
2. If absent, create the directory tree and a new _INDEX with the header template.
   - Use the scope name (project directory name or `home`) in the H1 title.
   - Initialize counts to `0 open, 0 done`.
   - Set `Overflow: false`.
3. If present, read the full file.

Header template:

```markdown
# Todos — <scope-name>

> **Items:** 0 open, 0 done (last 7 days)
> **Last updated:** <ISO-8601 timestamp>
> **Overflow:** false

## Now
## Soon
## Later
## Done (last 7 days)
```

### A3. Determine Category

Infer category from the todo content (e.g., "fix CI pipeline" implies `infrastructure`). If ambiguous, ask user via AskUserQuestion. Check existing categories by listing subdirectories of `todos/`.

Category directory rules:
- First prompt in a category sits flat: `todos/slug.md`
- Second prompt in the same category triggers folder creation: move the first file into `todos/category/`, add the second alongside it.
- Discover categories from the filesystem, not a registry.

### A4. Determine Priority

| Priority | Urgency bucket | Meaning |
|----------|---------------|---------|
| **P1** | `## Now` | Blocking or must-do-today |
| **P2** | `## Soon` | This week, not blocking |
| **P3** | `## Later` | Backlog, no deadline pressure |

If unclear, ask user. Default to P2 when context suggests moderate urgency.

### A5. Check for Duplicates

Search the _INDEX for an existing entry with matching title or semantically equivalent content. If found, update the existing entry (priority, context, urgency bucket) rather than adding a duplicate.

### A6. Write _INDEX Entry

Insert the entry under the correct urgency bucket and category subheader.

Entry format:

```markdown
- [ ] **P2** Title `added:YYYY-MM-DD` `prompt:category/slug.md`
  One-line context describing what this todo is about.
```

Omit `prompt:` for trivial/inline tasks that need no session prompt.

### A7. Determine Prompt Necessity

A todo is **non-trivial** (needs a prompt) when any of these apply:
- Requires reading specific files before acting
- Has multiple steps or dependencies
- Involves domain knowledge a fresh session would lack
- Has guardrails, constraints, or tone requirements
- Touches 3+ files or crosses module boundaries

Trivial todos (single-step, obvious, no context needed) skip prompt creation.

### A8. Dispatch Prompt Writer

For non-trivial todos, dispatch the `prompt-writer` agent with these parameters:
- **title** -- the todo title
- **description** -- the one-line context plus any additional detail from the user
- **scope** -- absolute path to the todos directory
- **category** -- category name (or empty if uncategorized)
- **deadline** -- date or trigger condition (if any)
- **relevant_files** -- absolute paths the prompt's "Read First" section should reference
- **gate_overrides** -- any per-prompt gate values that differ from project defaults

The agent writes the prompt file to `<scope>/.claude/prompts/todos/<category>/<slug>.md` using the scaffold template at `templates/prompt-scaffold.md` and returns the relative path.

Append `prompt:<relative-path>` to the _INDEX entry after the agent returns.

### A9. Update Summary

Recalculate the blockquote:
- Count open items (unchecked `- [ ]` entries)
- Count done items from last 7 days (entries with `completed:` date within 7 days)
- Set `Last updated` to current ISO-8601 timestamp
- Set `Overflow` to `true` if >50 open items or >200 total lines

If overflow triggers, split `## Later` and `## Done` into `roadmap.md` per the overflow rules in @references/index-format.md.

---

## Workflow B: Update a Todo

### B1. Find Entry

Read _INDEX. Match by title (case-insensitive substring match). If multiple matches, present options via AskUserQuestion.

### B2. Apply Update

| Action | Steps |
|--------|-------|
| **Reprioritize** | Change `**P1**`/`**P2**`/`**P3**` tag. Move entry to the correct urgency bucket. |
| **Update context** | Edit the indented context line below the entry. |
| **Move bucket** | Cut entry from current section, paste under target section's category subheader. |
| **Mark done** | Change `- [ ]` to `- [x]`. Add `completed:YYYY-MM-DD`. Move to `## Done (last 7 days)`. |
| **Delete** | Remove entry entirely. Only when user explicitly requests deletion. |

### B3. Prune Stale Done Items

On any write, scan `## Done (last 7 days)` for entries with `completed:` older than 7 days. Remove them.

### B4. Update Summary

Recalculate the blockquote (same as A9).

---

## Workflow C: Batch Capture (Session-End)

For capturing multiple deferred items at once, typically at session end or from a Stop hook.

### C1. Collect Items

Receive a list of deferred items from:
- A Stop hook payload
- Manual user request ("capture these next steps")
- Session review identifying unfinished work

### C2. Present for Confirmation

Display the item list to the user via AskUserQuestion:

```
Captured N items for todo tracking:
1. [P2] Title — one-line context
2. [P1] Title — one-line context
...
Confirm, edit, or remove items? (enter to confirm all)
```

Allow the user to adjust priorities, remove items, or edit titles/context.

### C3. Determine Scope and Category

For each confirmed item:
1. Apply the scope detection tree from A1 (batch items default to the session's active scope).
2. Infer category from content (A3).
3. Assign priority (A4).

### C4. Write All Entries

Read the _INDEX once. Write all entries in a single edit pass. Group entries by urgency bucket and category.

### C5. Fan-Out Prompt Writers

Identify which items are non-trivial (A7 criteria). For multiple non-trivial items, dispatch N `prompt-writer` agents in parallel -- one agent per todo, following the fan-out pattern:

- One agent per work item
- No shared files between agents (each writes to its own path)
- Fixed pipeline per agent: read context, write prompt, return path
- Cap at 5 concurrent agents

After all agents return, append `prompt:<path>` references to the corresponding _INDEX entries.

### C6. Update Summary

Recalculate the blockquote (same as A9).

---

## Scope Detection (Compact Reference)

```
Explicit "root/global"?     → ~/.claude/prompts/todos/
Explicit "project"?         → <project>/.claude/prompts/todos/
CWD in git repo?            → <git-root>/.claude/prompts/todos/
CWD has .claude/?           → <cwd>/.claude/prompts/todos/
None of the above?          → ~/.claude/prompts/todos/
Still ambiguous?            → AskUserQuestion
```

## _INDEX Entry Format (Quick Reference)

```markdown
- [ ] **P2** Title `added:YYYY-MM-DD` `prompt:category/slug.md`
  One-line context.
```

- Checkbox: `- [ ]` open, `- [x]` done
- Priority: `**P1**`, `**P2**`, `**P3**`
- `added:` -- always present, ISO date
- `prompt:` -- relative to `todos/`, absent for trivial tasks
- `completed:` -- on done items only, ISO date
- Context line -- always present, indented 2 spaces

## Prompt File Naming

```
<topic-slug>[-YYYY-MM-DD].md
```

- **Date-sensitive** (fires on/before a date): include date. Example: `offer-deadline-2026-05-15.md`
- **State-transition** (fires after an event): omit date. Example: `post-acceptance-followup.md`
- Slugs: short, kebab-case, reference recipient/topic/action.

## Gate Defaults

When no `todos.config.md` exists, hardcoded defaults apply:

```yaml
worktree: skip
specialist-routing: false
parallelization: none
review-gate: none
```

Per-prompt `### Gates` blocks override project config. Project config overrides root config. See @references/gate-configuration.md for the full precedence table and injected step mappings.

## Invocation Examples

| User says | Workflow | Notes |
|-----------|----------|-------|
| "Add a todo to fix the auth bug" | A | Infer project scope, category from content |
| "Park this for later" | A | P3, current scope |
| "Create a todo with a prompt for the migration" | A | Non-trivial, dispatch prompt-writer |
| "Mark the auth bug todo as done" | B | Find by title, mark complete |
| "Bump the migration todo to P1" | B | Reprioritize + move bucket |
| "Capture these next steps" | C | Batch capture, confirm with user |
| "What's left to do?" | B (read-only) | Read _INDEX, display summary |
| "I should remember to update the API docs" | A | Natural language trigger |
| "We need to fix the flaky test" | A | Natural language trigger |

---

## Validation Checklist

Run after every write operation:

- [ ] _INDEX exists at correct scope path
- [ ] _INDEX has valid structure: H1 title, blockquote summary, four urgency sections
- [ ] Entry is in the correct urgency bucket for its priority
- [ ] Category subheader exists under the urgency section (if categorized)
- [ ] Category folder exists on disk (if 2+ prompts share a category)
- [ ] Prompt file exists and has all 7 sections (if `prompt:` reference present)
- [ ] `prompt:` path in _INDEX resolves to an actual file
- [ ] Summary blockquote counts match actual item counts
- [ ] `Last updated` timestamp is current
- [ ] No duplicate entries (same title appearing twice)
- [ ] Done items older than 7 days are pruned
- [ ] Overflow flag is correct (>50 open or >200 lines)

---

## References

Detailed format specifications (load as needed):

- **@references/index-format.md** -- _INDEX structure, entry format, overflow handling, category conventions, deduplication rules, complete example
- **@references/prompt-template.md** -- the 7-section prompt format, file naming, gates extension, freshness convention, complete example
- **@references/gate-configuration.md** -- the four gates (worktree, specialist-routing, parallelization, review-gate), per-project config format, precedence rules, injected step mappings

Scaffold template for prompt creation:

- **templates/prompt-scaffold.md** -- blank prompt template with all 7 sections and placeholder comments
