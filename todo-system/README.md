# Todo System

**Version:** 1.0.0

Portable todo management with paired session-launch prompts, category folders, modular gates, and auto-capture at session end.

## Components

### Skills

| Skill | Description |
|-------|-------------|
| `todo-manage` | Add, update, complete, and capture todo items. Creates `_INDEX` manifests and paired session-launch prompts for non-trivial work. |
| `todo-review` | Read-only review of `_INDEX` files. Shows prioritized status, roadmap views, and overflow management recommendations. |

### Agents

| Agent | Description |
|-------|-------------|
| `prompt-writer` | Creates 7-section session-launch prompts for todo items. Dispatched by `todo-manage` when a non-trivial todo needs a paired prompt. |

### Commands

| Command | Description |
|---------|-------------|
| `/todo add <title>` | Add a new todo item |
| `/todo review` | Show todo status overview |
| `/todo roadmap` | Show full roadmap with stats |

### Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| Stop | Session end | Scans the session for uncaptured deferred work and blocks exit if any are found. |

## How `/todo` Works

The `/todo` command routes to two skills based on the sub-command:

- **`/todo add <title>`** — invokes `todo-manage` to create a structured entry in the `_INDEX` manifest. For non-trivial items, `todo-manage` dispatches the `prompt-writer` agent to generate a paired session-launch prompt.
- **`/todo review`** — invokes `todo-review` to display a prioritized status overview across both project and global scopes.
- **`/todo roadmap`** — invokes `todo-review` with roadmap mode, showing the full backlog including overflow archives with stats.

## How the Stop Hook Works

At session end, the Stop hook runs a deferred-work detector that reviews the assistant's last message and recent conversation context. It looks for uncaptured signals: explicit TODOs or FIXMEs, phrases like "next session" or "park this", and sessions ending in a known-broken or partial state. If any concrete, actionable uncaptured items are found, the hook blocks the session from closing and prompts you to capture them with `todo-manage`. False positives are avoided — vague suggestions and already-captured items do not trigger it.

## Gate System

Session-launch prompts support four modular gates that control how a future session picks up the work:

- **Worktree gate** — whether to open a git worktree before starting
- **Specialist-routing gate** — whether to dispatch a domain-specific agent
- **Parallelization gate** — whether sub-tasks can run concurrently
- **Review gate** — whether a review step is required before finishing

Gates are configured per-prompt and injected as preflight steps when a fresh session executes the prompt. See `skills/todo-manage/references/gate-configuration.md` for values and precedence.

## Todo Structure

Todos live in `_INDEX` manifests organized into three urgency tiers:

- **Now** — P1, blocking or must-do-today
- **Soon** — P2, this week
- **Later** — P3, backlog

Scope is either project-level (`<project>/.claude/prompts/todos/`) or global (`~/.claude/prompts/todos/`). When an `_INDEX` grows too large, items overflow to a `roadmap.md` archive.

## Installation

Available via the magpie-marketplace. Enable with `todo-system@magpie-marketplace` in settings.

## License

MIT
