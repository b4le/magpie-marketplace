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
# Todos — api-v3-migration

> **Items:** 4 open, 1 done (last 7 days)
> **Last updated:** 2026-05-12T14:30:00Z
> **Overflow:** false

## Now

### Endpoints

- [ ] **P1** Update REST endpoints to v3 schema `added:2026-05-10` `prompt:endpoints/v3-schema-update.md`
  Blocked on OpenAPI spec review; fires as state-transition prompt.

### Comms

- [ ] **P1** Notify platform team of deprecation timeline `added:2026-05-11` `prompt:comms/platform-deprecation-notice-2026-05-11.md`
  Date-sensitive, must ship today.

## Soon

### Docs

- [ ] **P2** Write migration guide for API consumers `added:2026-05-08` `prompt:docs/consumer-migration-guide.md`
  Three partner teams still need example payloads.

## Later

- [ ] **P3** Fix flaky integration tests in CI `added:2026-05-05` `prompt:fix-flaky-integration-tests.md`
  Intermittent timeout in the v2 compatibility suite, no deadline.

## Done (last 7 days)

- [x] **P2** Add v3 request validation middleware `added:2026-05-01` `completed:2026-05-09` `prompt:endpoints/v3-validation-middleware.md`
```
