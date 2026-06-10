---
name: session-budget
description: >-
  This skill should be used when the user is planning a session or wants to check scope.
  Trigger phrases: "plan this session", "scope check", "session budget",
  "is this too much", "is this too much for one session", "how much can I fit",
  "split this work", "estimate complexity", "too many tasks",
  "what should I tackle first", "can we do all of this today",
  "can we do all of this this session", "prioritise these tasks",
  "how many sessions will this take", "is this too much for one agent",
  "how should I split agents", "how should I split this across agents".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
version: 1.2.0
last_updated: 2026-03-09
---

# Session Budget Estimator

Score proposed tasks by complexity, check against the per-agent budget cap, and recommend session splits when needed.

## Step 1: Score Each Task

**Decompose compound tasks first.** If a task description contains any of the following, split it into separate tasks before scoring:
- The word AND, also, plus, or as well as joining distinct actions
- A comma-separated list of actions ("build X, update Y, write tests")
- Multiple verbs pointing at different targets ("refactor the module and add documentation")

Each resulting sub-task is scored independently. Do not score the compound form.

Classify every task by complexity:

| Complexity | Points | Characteristics | Examples |
|-----------|--------|-----------------|----------|
| Simple | 1 | Single file, clear change, no unknowns | Fix typo, add config value, prune files, write one reference doc |
| Medium | 2 | 2-5 files, some design decisions, known patterns | Build a skill, add a hook, refactor a module |
| Complex | 3 | 6+ files or unknowns, research needed, architectural decisions | New multi-file feature, cross-cutting refactor, pattern with template + skill + CLAUDE.md updates |

For worked examples of scored session plans, see `references/scoring-examples.md`.

## Step 2: Check Budget

**Budget: 7 points is the target; 8 is the ceiling.**

Leave one point of headroom for tasks that turn out more complex than scored. Exceeding 8 reliably degrades quality on later tasks (lost-in-the-middle effect).

**Exception — research-only sessions** (reading docs, scanning code, running evals, no implementation): the ceiling may be raised to 12 points, since research tasks generate far less context pressure than implementation.

Present the budget as a table:

```
| # | Task | Complexity | Points | Cumulative |
|---|------|-----------|--------|------------|
| 1 | {task} | {simple/medium/complex} | {1/2/3} | {running total} |
| 2 | {task} | ... | ... | ... |
```

### If cumulative ≤ 8: Proceed

Front-load the hardest tasks (positions 1-2). Tasks in positions 3-5 get degraded attention due to lost-in-the-middle effect.

### If cumulative > 8: Split

1. Group tasks into sessions of ≤8 points each
2. Put tightly related tasks in the same session
3. End each session with a handoff: scope + state to `~/.claude/handoffs/`. See `references/handoff-template.md` for the exact format.
4. Present the split to the user for approval

## Step 3: Check for Stale Tasks

For each unchecked task in the proposed list, use Glob and Read to scan `~/.claude/handoffs/` for its title or a close paraphrase appearing in a "What the next session must do" or "What's not done" section of two or more handoff files.

A task stranded across multiple handoffs while still `- [ ]` in `~/.claude/todos.md` is a stale task — it has been deferred at least twice without completion.

**If found:** Flag as stale. Recommend one of:
- Decompose into sub-tasks of ≤2 points each, naming the specific blocker per sub-task
- Explicitly park it: move to the `## Later` section of todos.md with a note on what must change before it becomes actionable
- Re-evaluate whether the original scope has grown — if yes, re-score before proceeding

## Step 4: Agent Specialisation Check

For multi-agent sessions, apply this budget per agent — not across the whole session. Each agent should own one coherent domain. If a proposed agent would span unrelated areas (e.g. "write the migration AND update the frontend AND run the tests"), split it into separate agents, each with its own budget.

## Output Format

After analysis, present:

```
**Session Budget: {total} / 8 points** (target: 7) {[OK] within budget | [OVER BUDGET]}

| # | Task | Complexity | Points | Cumulative |
|---|------|-----------|--------|------------|

{Recommendations if any: reorder, split, decompose stale tasks}
```

## Step 5: Write Budget State

After presenting the budget table, write the session's budget state to `/tmp/claude-session-budget/` so enforcement hooks can track progress.

**Directory:** `/tmp/claude-session-budget/{session-id}/budget.json`

Use `$CLAUDE_SESSION_ID` if available in the environment; otherwise generate a slug from the current date + first task name (e.g., `2026-03-09-auth-module`).

**Schema:**

```json
{
  "session_id": "string",
  "created_at": "ISO 8601",
  "budget_ceiling": 8,
  "budget_target": 7,
  "mode": "implementation|research",
  "tasks": [
    {
      "id": 1,
      "name": "string",
      "points": 1,
      "status": "planned|in_progress|completed",
      "started_at": "ISO 8601 | null",
      "completed_at": "ISO 8601 | null"
    }
  ],
  "points_completed": 0,
  "points_in_progress": 0,
  "points_planned": 0,
  "points_total": 0
}
```

**Rules:**
- Create the directory if it doesn't exist: `mkdir -p /tmp/claude-session-budget/{session-id}/`
- Set `mode` to `"research"` if all tasks are read-only (no Write/Edit tools needed); otherwise `"implementation"`
- The first task in the budget table starts as `"in_progress"`; all others as `"planned"`
- `points_total` = sum of all task points
- `points_planned` = sum of `"planned"` task points
- `points_in_progress` = sum of `"in_progress"` task points
- `points_completed` = 0 (initial state)
- Use the Write tool to create the file
- If the file already exists (re-run of budget check), overwrite it with updated state
