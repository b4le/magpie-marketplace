# _INDEX File Format

The `_INDEX` file is the central manifest of all todos for a given scope. One exists per scope (project root or home directory).

## Location

```
<scope>/.claude/prompts/todos/_INDEX
```

- **Project scope:** `<project-root>/.claude/prompts/todos/_INDEX`
- **Global scope:** `~/.claude/prompts/todos/_INDEX`

The file has no `.md` extension. It is pure markdown with no YAML frontmatter.

## Structure

The file uses a fixed four-section layout: urgency groups first, categories second.

```
# Todos — <scope name>

> **Items:** N open, M done (last 7 days)
> **Last updated:** YYYY-MM-DDTHH:MM:SSZ
> **Overflow:** false

## Now
## Soon
## Later
## Done (last 7 days)
```

### Urgency Groups

| Section | Priority tag | Meaning |
|---------|-------------|---------|
| `## Now` | `**P1**` | Blocking or must-do-today |
| `## Soon` | `**P2**` | This week, not blocking |
| `## Later` | `**P3**` | Backlog, no deadline pressure |
| `## Done (last 7 days)` | n/a | Completed items, auto-pruned after 7 days |

### Categories

Within each urgency group, items are grouped under `### Category` subheaders. Categories correspond to flat subdirectories of `todos/` and are created on demand by listing the directory.

For cross-project items at global scope, use `### Category (project-name)` subheaders.

### Item Format

```markdown
- [ ] **P1** Title `added:YYYY-MM-DD` `prompt:category/slug.md`
  One-line context describing what this todo is about.
```

| Field | Required | Notes |
|-------|----------|-------|
| Checkbox | Yes | `- [ ]` open, `- [x]` done |
| Priority | Yes | `**P1**`, `**P2**`, or `**P3**` |
| Title | Yes | Short imperative description |
| `added:` | Yes | ISO date when item was created |
| `prompt:` | No | Path relative to `todos/` directory; absent for inline/trivial tasks |
| `completed:` | On done items | ISO date when item was completed |
| Context line | Yes | One line indented below the item |

## Rules

### Summary Blockquote

The blockquote under the H1 heading is updated on every write operation:
- **Items:** count of open items, count of done items from last 7 days
- **Last updated:** ISO-8601 timestamp of this write
- **Overflow:** `true` when >50 open items or >200 total lines

### Overflow Handling

When overflow is `true`, split `## Later` and `## Done` sections into a separate `roadmap.md` file in the same directory. The `_INDEX` retains only `## Now` and `## Soon`, plus a pointer:

```markdown
## Later & Done

See [roadmap.md](roadmap.md) for backlog and completed items.
```

### Category Directory Convention

- Categories are flat subdirectories of `todos/` (e.g., `todos/infra/`, `todos/legal/`).
- When a category has only one prompt, the file sits flat: `todos/slug.md`.
- When a second prompt joins the same category, move the first flat file into the category folder: `todos/category/first-slug.md`, `todos/category/second-slug.md`.
- Discover categories by listing the `todos/` directory -- do not maintain a separate registry.

### Deduplication

Never create a duplicate entry. If a todo already exists, update its priority, urgency group, or context line rather than adding a new item.

### Completion

Move completed items to `## Done (last 7 days)` with `[x]` and a `completed:` date. Items older than 7 days are pruned on the next write.

## Complete Example

```markdown
# Todos — atticus-finch

> **Items:** 4 open, 1 done (last 7 days)
> **Last updated:** 2026-05-12T14:30:00Z
> **Overflow:** false

## Now

### Legal

- [ ] **P1** Draft formal accommodation request `added:2026-05-10` `prompt:legal/formal-accommodation-request.md`
  Blocked on acceptance email landing; fires as state-transition prompt.

### Comms

- [ ] **P1** Reply to Stina re meeting debrief `added:2026-05-11` `prompt:comms/stina-reply-2026-05-11.md`
  Date-sensitive, must ship today.

## Soon

### Evidence

- [ ] **P2** Compile timeline gaps for Q1 `added:2026-05-08` `prompt:evidence/q1-timeline-gaps.md`
  Three witness statements still outstanding.

## Later

- [ ] **P3** Update Peter Toth on current status `added:2026-05-05` `prompt:update-peter-toth.md`
  Low-urgency ally update, no deadline.

## Done (last 7 days)

- [x] **Prepare union brief** `completed:2026-05-09` `prompt:legal/union-brief.md`
```
