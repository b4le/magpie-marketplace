# Handoff Template

Use this template when a session budget check recommends a split. Write the completed file to `~/.claude/handoffs/{project-slug}-{YYYY-MM-DD}.md`. Goal: make the next session zero-ramp — no re-reading, no re-deciding.

## Main Template

```markdown
# Handoff: {project} — Session {N} of {total}

**Date:** {YYYY-MM-DD}
**Project:** {project name}
**Branch / context:** {git branch or working context}

---

## What this session completed

- [x] {Task description} → `{output/file/path}`
- [x] {Task description} → `{output/file/path}`

## What the next session must do

{Paste the session-budget split table for the next session here.}

| # | Task | Complexity | Points | Cumulative |
|---|------|------------|--------|------------|
| 1 | {task} | {simple/medium/complex} | {1/2/3} | {running total} |

## State to carry forward

**Decisions made:**
- {Decision and rationale — be specific}

**Files in partial state:**
- `{path}` — {what's done, what remains}

**Open questions:**
- {Question that the next session must resolve before proceeding}

## Prerequisites for next session

- [ ] {Specific check or action before starting}
- [ ] {e.g., "branch X merged", "env var Y set", "file Z reviewed"}

## Do not re-do

- {Thing the next agent should skip — it's done}
- {e.g., "do not re-scaffold the plugin — skeleton already in place"}
```

---

## Multi-Agent Variant

Use this variant when the split also divides work across agents (not just time).

```markdown
# Handoff: {project} — Session {N} of {total} (Multi-Agent)

**Date:** {YYYY-MM-DD}
**Project:** {project name}
**Branch / context:** {git branch or working context}

---

## Agent Assignments

| Agent | Domain | Owned Files | Points |
|-------|--------|-------------|--------|
| {agent-name} | {domain} | `{file1}`, `{file2}` | {N} |
| {agent-name} | {domain} | `{file1}` | {N} |

## Per-Agent Pipeline

### {agent-name}

1. {Step description}
2. {Step description}
3. {Step description}

**Done criteria:** {How to verify this agent's work is complete}

### {agent-name}

1. {Step description}

**Done criteria:** {How to verify this agent's work is complete}

---

**MCP delegation:** Before spawning work agents, delegate MCP fetching to foreground
sub-agents using the dual return pattern. Sub-agents write full results to
`local-state/prefetch/{session}/` and return summary + file path. Pass file paths to
downstream agents — the orchestrator must never call MCP tools directly.

**Separate worktrees:** If agents use separate worktrees, write one handoff file per
agent: `{project-slug}-{YYYY-MM-DD}-agent-{name}.md`.

**Full orchestration model:** `~/.claude/references/fan-out-pattern.md`

---

## What this session completed

- [x] {Task} → `{output/file/path}`

## State to carry forward

**Decisions made:**
- {Decision and rationale}

**Open questions:**
- {Question for the next session}

## Do not re-do

- {Completed work to skip}
```

---

## Naming Convention

```
~/.claude/handoffs/{project-slug}-{YYYY-MM-DD}.md
~/.claude/handoffs/{project-slug}-{YYYY-MM-DD}-{N}.md   # multiple splits same day
```

---

## Pre-Close Checklist

- [ ] All completed tasks listed with output paths
- [ ] Next session's budget table filled in
- [ ] State to carry forward is specific (not "see context")
- [ ] Prerequisites are actionable yes/no checks
- [ ] File written to `~/.claude/handoffs/`
