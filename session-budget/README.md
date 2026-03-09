# Session Budget

A scope estimator for Claude Code sessions. Scores tasks by complexity, enforces a per-agent budget cap, and recommends splitting work across sessions when you're overloaded.

## Features

- **Complexity scoring** — Classifies tasks as simple (1pt), medium (2pt), or complex (3pt) with a compound task decomposition rule
- **Budget enforcement** — Target of 7 points per agent per session, hard ceiling of 8. Research-only sessions may go up to 12
- **Session splitting** — Recommends how to split overloaded sessions with a structured handoff template
- **Stale task detection** — Scans handoff files to flag tasks that have been deferred across multiple sessions without completion
- **Agent specialisation** — Verifies each agent owns one coherent domain, with budget applied per-agent
- **Budget state tracking** — Writes session budget state to `/tmp/claude-session-budget/` so hooks can monitor progress mid-session
- **Budget threshold warnings** — Automatic warnings at 5/7/8 consumed points via UserPromptSubmit hook
- **Manual task ticking** — `/budget-tick` skill to mark tasks complete and advance to the next one

## Usage

Trigger naturally in conversation:

- "Plan this session" / "scope check" / "session budget"
- "Is this too much for one session?"
- "How should I split this work?"
- "Estimate complexity for these tasks"
- "Too many tasks" / "what should I tackle first?"
- "How many sessions will this take?"
- "Is this too much for one agent?" / "how should I split agents?"

## Hooks

The plugin includes hooks that fire automatically:

### SessionStart
- Reminds Claude that the session-budget skill is available
- Skips `"compact"` source to avoid nagging
- 6-hour cache prevents repeated reminders on rapid restarts

### UserPromptSubmit (planning detector)
- Prompt hook that detects planning language in user messages
- Triggers a systemMessage when scoping/planning intent is detected

### UserPromptSubmit (budget tracker)
- Command hook that reads budget state from `/tmp/claude-session-budget/`
- Emits threshold warnings:
  - **≥5 points:** Informational — remaining budget and planned tasks
  - **≥7 points:** Warning — only simple tasks recommended
  - **≥8 points:** Critical — recommend handoff and session end
- Exits silently when no budget file exists

## Installation

```bash
claude mcp add-plugin session-budget --from magpie-marketplace
```

Or add the plugin directory to your Claude Code configuration.

## Budget State

When `/session-budget` runs, it writes a state file to `/tmp/claude-session-budget/{session-id}/budget.json`:

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

Use `/budget-tick` to advance tasks through the pipeline (planned → in_progress → completed).

## Budget Tick

Mark tasks complete and advance to the next one. Trigger with:

- "task done" / "next task" / "budget tick"
- "mark complete" / "finished task" / "that's done"

The skill reads the budget state, marks the current `in_progress` task as `completed`, advances the next `planned` task to `in_progress`, and reports the updated budget.

## How It Works

1. **Decompose** compound tasks (AND/also/plus) into separate scoreable items
2. **Score** each task by complexity (1-3 points)
3. **Check** cumulative total against the budget (target 7, ceiling 8)
4. **Flag** stale tasks found stranded across multiple handoff files
5. **Verify** agent specialisation if multi-agent work is planned
6. **Recommend** session splits with structured handoff notes when over budget
7. **Track** budget state to /tmp/ for mid-session enforcement hooks

## Reference Files

The skill includes reference documents and hooks for detailed guidance:

- **`references/scoring-examples.md`** — Five worked examples: simple session, at-cap, over-budget split, stale task, and research-only
- **`references/handoff-template.md`** — Structured template for writing handoff files when splitting sessions, with a multi-agent variant
- **`hooks/`** — SessionStart and UserPromptSubmit hooks for automatic triggering and budget tracking
