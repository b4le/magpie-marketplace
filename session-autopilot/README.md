# Session Autopilot

Automatic session continuity for Claude Code. Writes a handoff when you exit, saves a checkpoint before compaction, and resumes from where you left off when you start a new session — without any manual steps.

## Features

- **Auto-resume** — On session start, finds the best available handoff for the current branch and injects it as context automatically
- **Auto-handoff** — On session end, writes a git-state snapshot capturing branch, HEAD, status, diff stats, and recent commits
- **Checkpoint** — Before context compaction, writes a lightweight recovery file so state survives even if the session dies mid-work
- **Collision detection** — When multiple handoffs exist within 1 hour, defers to `/pickup` for manual selection rather than guessing
- **Handoff pruning** — Handoffs older than 7 days are removed automatically on resume
- **Manual `/handoff`** — Writes a rich handoff with goal, decisions, files touched, blockers, and next steps; auto-handoff skips if this ran in the last 60 seconds
- **Manual `/pickup`** — Finds the best handoff, detects git drift since it was written, handles collision selection, and offers to load referenced files

## Usage

The three hooks fire automatically — no user action required. The two skills are available on demand:

- `/handoff` / "wrap up" / "save my progress" / "I'm done for today" / "end session"
- `/pickup` / "pick up where I left off" / "resume" / "where did I leave off" / "what was I working on"

## Installation

```bash
claude mcp add-plugin session-autopilot --from magpie-marketplace
```

Or add the plugin directory to your Claude Code configuration.

## How It Works

### Hooks (automatic)

1. **SessionStart → auto-resume:** Looks up handoffs in priority order — branch handoff, checkpoint, git inference. Injects the best match via `additionalContext`. Skips if the source is not a fresh startup or clear. Defers to `/pickup` on collision.
2. **SessionEnd → auto-handoff:** Writes a skeleton handoff to `.claude/handoffs/{branch}_{timestamp}.md`. Skips if a manual `/handoff` was written in the last 60 seconds.
3. **PreCompact → checkpoint:** Writes `.claude/handoffs/.checkpoint_{branch}.md`. Primary crash-recovery path — fires before compaction so context is preserved even if the session does not reach a clean exit.

### Skills (manual)

1. **/handoff:** Reviews the conversation, runs `git status` and `git diff --stat`, and writes a structured document covering goal, progress, decisions, remaining work, blockers, and continuation steps. Also copies to `latest.md` for quick access.
2. **/pickup:** Finds the best handoff for the current branch, displays it with drift analysis (new commits, modified files), and offers to load referenced files into context. Handles collision selection with a numbered list.

### Lookup priority (both auto-resume and `/pickup`)

1. Most recent `{branch}_*.md` in `.claude/handoffs/`
2. `.checkpoint_{branch}.md` in `.claude/handoffs/`
3. Git-state inference from branch, recent commits, and modified files

## Reference Files

- **`skills/handoff/SKILL.md`** — Full handoff template and instructions
- **`skills/pickup/SKILL.md`** — Pickup steps, drift detection, and collision-selection logic
- **`scripts/lib/common.sh`** — Shared utilities used by all three hooks (JSON helpers, git helpers, atomic write)
