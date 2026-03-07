---
generated: 2026-02-26
project: .claude
pattern_types: [subagent, agent-team, task-list, workflow-state]
source_count: 66
---

# Orchestration Patterns

Extracted patterns for agent orchestration in Claude Code, covering sub-agents, agent teams, and multi-step coordination workflows.

## Quick Reference

| Pattern | When to Use | Cost | Files |
|---------|------------|------|-------|
| **Direct Execution** | 1-2 steps | Lowest | N/A |
| **Subagents (Star)** | 3+ independent tasks | Medium | [subagent-prompts.md](./subagent-prompts.md) |
| **Agent Teams (Mesh)** | Agents need discussion | High | [team-prompts.md](./team-prompts.md) |
| **Task List** | Complex dependencies | Low overhead | [patterns.md](./patterns.md) |

## Decision Tree

```yaml
START: Task received
│
├─ Q1: Need delegation at all?
│   ├─ NO → Direct execution (Bash, Read, Edit)
│   └─ YES → Q2
│
├─ Q2: One task or multiple?
│   ├─ ONE → Single sub-agent
│   ├─ MULTIPLE INDEPENDENT → Parallel Task calls
│   └─ MULTIPLE NEEDING COORDINATION → Q3
│
└─ Q3: Do agents need to DISCUSS with each other?
    ├─ YES (debate, challenge) → Agent Teams
    └─ NO (you bridge results) → Parallel Task calls
```

## Core Patterns Discovered

### 1. Star Topology (Subagents)
Multiple independent subagents working in parallel on specialized tasks.
- Foreground execution with sequential dispatch
- Used for: reviews, audits, content creation, research
- Example: 3-8 subagents reviewing different aspects

### 2. Mesh Topology (Agent Teams)
Full Claude instances messaging each other.
- TeamCreate establishes shared context
- SendMessage (broadcast) for team-wide announcements
- SendMessage (targeted) for individual tasks
- Used for: user testing, complex coordination, debate

### 3. Sequential Role-Based
Analyst → Creator → Reviewer → Editor pattern.
- Each role depends on output of previous role
- Specialized prompts establish role identity
- Wait-state communication between subagents

### 4. Task List Coordination
Fine-grained decomposition with TaskCreate/TaskUpdate.
- Tasks persist across agent lifespans
- Enables progress tracking and dependency management
- Primary coordination mechanism for complex workflows

### 5. Phase-Based Workflows
Multi-phase with persistent state files.
- STATUS.yaml tracks completion
- Filename suffixes signal progress (`-INCOMPLETE`, `-TODO`)
- Designed for crash resilience

## Files in This Directory

| File | Description |
|------|-------------|
| [README.md](./README.md) | This index |
| [subagent-prompts.md](./subagent-prompts.md) | Verbatim prompts for subagent invocations |
| [team-prompts.md](./team-prompts.md) | Prompts and configs for agent teams |
| [patterns.md](./patterns.md) | Decision framework and topology diagrams |

## Key Insights

1. **Prompt Engineering as First-Class Pattern** - Detailed role-based prompts establish identity, constraints, and success criteria
2. **100K Token Threshold** - Shut down agents approaching context limit, spawn fresh ones
3. **No Sleep Commands** - Use `run_in_background: false` to block until completion
4. **Parallel Launches** - Multiple Task calls in single message = simultaneous execution
5. **Delegate Mode** - Team lead stays coordination-only (Shift+Tab in terminal)

## Source Projects

- `agent-orchestration-analysis` (66 sessions, primary source)
- `TeamExperimentation` (legal system design)
- `google-workspace-mcp-spotify` (10+ parallel subagents)
- 13 active teams in `~/.claude/teams/`
- 45+ plan documents in `~/.claude/plans/`
