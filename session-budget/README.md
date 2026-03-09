# Session Budget

A scope estimator for Claude Code sessions. Scores tasks by complexity, enforces a per-agent budget cap, and recommends splitting work across sessions when you're overloaded.

## Features

- **Complexity scoring** — Classifies tasks as simple (1pt), medium (2pt), or complex (3pt) with a compound task decomposition rule
- **Budget enforcement** — Target of 7 points per agent per session, hard ceiling of 8. Research-only sessions may go up to 12
- **Session splitting** — Recommends how to split overloaded sessions with a structured handoff template
- **Stale task detection** — Scans handoff files to flag tasks that have been deferred across multiple sessions without completion
- **Agent specialisation** — Verifies each agent owns one coherent domain, with budget applied per-agent

## Usage

Trigger naturally in conversation:

- "Plan this session" / "scope check" / "session budget"
- "Is this too much for one session?"
- "How should I split this work?"
- "Estimate complexity for these tasks"
- "Too many tasks" / "what should I tackle first?"
- "How many sessions will this take?"
- "Is this too much for one agent?" / "how should I split agents?"

## Installation

```bash
claude mcp add-plugin session-budget --from magpie-marketplace
```

Or add the plugin directory to your Claude Code configuration.

## How It Works

1. **Decompose** compound tasks (AND/also/plus) into separate scoreable items
2. **Score** each task by complexity (1-3 points)
3. **Check** cumulative total against the budget (target 7, ceiling 8)
4. **Flag** stale tasks found stranded across multiple handoff files
5. **Verify** agent specialisation if multi-agent work is planned
6. **Recommend** session splits with structured handoff notes when over budget

## Reference Files

The skill includes two reference documents for detailed guidance:

- **`references/scoring-examples.md`** — Five worked examples: simple session, at-cap, over-budget split, stale task, and research-only
- **`references/handoff-template.md`** — Structured template for writing handoff files when splitting sessions, with a multi-agent variant
