---
name: orchestration-guide
description: >
  Central decision guide for choosing between agent orchestration patterns.
  Use when deciding how to delegate work: direct execution, single sub-agent,
  parallel sub-agents, phased workflows, or collaborative agent teams.
  Answers the key question: "Do agents need to discuss with each other?"
version: 1.0.0
created: 2026-02-17
last_updated: 2026-02-17
tags:
  - orchestration
  - decision-guide
  - agent-teams
  - sub-agents
  - workflows
---

# Orchestration Guide

**Purpose:** Help users and Claude choose the right agent configuration for any task.

## The Key Question

When multi-agent work is detected, ask yourself:

> **"Do the agents need to discuss with each other, or just report back to you?"**

- **Report back** → Subagents (Task tool)
- **Discuss** → Agent Teams

This single distinction captures the fundamental difference between orchestration patterns.

---

## Quick Decision Flow

```
START: Task received
│
├─→ Q1: Do you need delegation at all?
│   │
│   ├─→ NO → Direct execution
│   │        Use: Read, Edit, Write, Bash, Glob, Grep
│   │
│   └─→ YES ↓
│
├─→ Q2: Is it one focused task or multiple?
│   │
│   ├─→ ONE TASK → Single sub-agent
│   │              Task(subagent_type=..., prompt="...")
│   │
│   ├─→ MULTIPLE INDEPENDENT → Multiple Task calls in one message
│   │                          Parallel execution, you synthesize results
│   │
│   └─→ MULTIPLE NEEDING COORDINATION → ↓
│
├─→ Q3: Do agents need to DISCUSS with each other?
│   │
│   ├─→ YES (debate, challenge, share findings) → Agent Teams
│   │        Teammates message each other directly
│   │        Use: TeamCreate or natural language "create an agent team"
│   │
│   └─→ NO (sequential phases, you bridge results) → ↓
│
├─→ Q4: Complex multi-phase project with persistent context?
│   │
│   ├─→ YES → /orchestrate (multi-agent-workflows)
│   │          .development/ folder structure
│   │          Phase-based coordination
│   │
│   └─→ NO → Parallel Task calls
│            Direct orchestration without file structure
│
└─→ Q5: Need approval gates mid-execution?
    │
    ├─→ YES → Add iterative-agent-refinement pattern
    │          Pause/resume with user input
    │
    └─→ NO → Proceed without pause/resume
```

---

## Configuration Modes

| Mode | Setup | When to Use |
|------|-------|-------------|
| **Direct Execution** | Don't use Task tool | 1-2 steps, single file, needle queries |
| **Single Sub-Agent** | `Task(subagent_type, prompt)` | Focused research, isolated investigation |
| **Parallel Sub-Agents** | Multiple Task calls in same message | Independent tasks, you synthesize results |
| **Phased Workflow** | `/orchestrate project-name` | 5+ steps, distinct phases, context persistence |
| **Approval Gates** | `Task(resume=agentId, prompt)` | Mid-execution user input, iterative refinement |
| **Agent Teams** | `TeamCreate` or natural language | Collaborative work requiring debate/discussion |

---

## Subagents vs Agent Teams

**These are NOT competing features** - they serve different purposes:

| Aspect | Subagents (Task tool) | Agent Teams |
|--------|----------------------|-------------|
| **Context** | Own context; results return to caller | Own context; fully independent sessions |
| **Communication** | Report results back to main agent only | Teammates message each other directly |
| **Coordination** | Main agent manages all work | Shared task list with self-coordination |
| **Best for** | Focused tasks where only the result matters | Complex work requiring discussion and collaboration |
| **Token cost** | Lower (results summarized back) | Higher (each teammate is separate instance) |

### When to Use Agent Teams

- Competing hypotheses where teammates debate theories
- Multiple reviewers applying different lenses to same work
- Cross-layer coordination (frontend/backend/tests each owned by different teammate)
- Work where agents need to share findings, challenge each other, coordinate independently

### When to Use Subagents

- Research/analysis where you synthesize results
- Parallel independent tasks
- Focused work where only the final output matters
- Tasks where you (the orchestrator) make all decisions

---

## Multi-Agent-Workflows vs Agent Teams

| Multi-Agent-Workflows | Agent Teams |
|-----------------------|-------------|
| Phase-based orchestration | Collaboration-based coordination |
| File-based context passing (.development/) | Direct inter-agent messaging |
| Sequential phases (planning → execution → review) | Parallel exploration with debate |
| Orchestrator synthesizes at phase boundaries | Teammates challenge each other in real-time |

**Use multi-agent-workflows when:**
- You have distinct phases
- The orchestrator synthesizes between them
- Context must persist across agents via files

**Use Agent Teams when:**
- Teammates need to discuss, debate, and coordinate with each other directly
- Multiple perspectives need to interact, not just be collected

---

## Intent-Based Selection Guide

| User Intent | Configuration | Setup |
|-------------|---------------|-------|
| "I'll do this myself" | Direct | No Task tool |
| "Get me an answer/analysis" | Single Sub-Agent | `Task(subagent_type=Explore)` |
| "Do this task for me" | Single Sub-Agent | `Task(subagent_type=general-purpose)` |
| "Research these 3 things in parallel" | Parallel Sub-Agents | 3 Task calls in one message |
| "Let me review before you continue" | Approval Gate | iterative-agent-refinement pattern |
| "Big project with distinct phases" | Phased Workflow | `/orchestrate project-name` |
| "I need agents to discuss/debate/challenge each other" | Agent Teams | Natural language request |
| "Multiple perspectives on same problem" | Agent Teams | Natural language request |

---

## Proactive Guidance Pattern

When detecting multi-agent work, Claude should offer choices:

```
User: "I need help reviewing this PR from multiple angles"

Claude: "I can approach this a few ways:

- **Me doing it**: I review for security, then performance, then tests (sequential)
- **Parallel sub-agents**: 3 agents each review one aspect, I synthesize findings
- **Agent Team**: 3 teammates review in parallel AND debate their findings with each other

For code review with competing perspectives, an Agent Team works well - the teammates
can challenge each other's findings. Want me to set that up?"
```

---

## Use Case Examples

| Use Case | Pattern | Why |
|----------|---------|-----|
| Review PR from multiple angles | Agent Team | Teammates debate findings |
| Debug with competing hypotheses | Agent Team | Teammates try to disprove each other |
| Build feature with distinct phases | Multi-agent-workflows | Sequential phases, orchestrator bridges |
| Research 3 topics in parallel | Parallel Task calls | Independent work, no discussion needed |
| Design requiring user feedback | Iterative refinement | Pause/resume with approval gates |
| Codebase exploration | Single Explore agent | Focused research, results return to you |
| Complex refactoring | Multi-agent-workflows | Planning → execution → review phases |

---

## Critical Configuration Notes

### MCP Tool Access

**The orchestrator must never call MCP tools directly.** Delegate all MCP fetching to foreground sub-agents using the dual return pattern:

1. Spawn a foreground sub-agent (`run_in_background: false`) to execute MCP queries
2. Sub-agent writes full results to `local-state/prefetch/{session}/` and returns a concise summary + file path
3. Pass file paths (not raw data) to downstream agents

Background agents cannot access MCP tools at all (GitHub #13254, #19964).

See `references/mcp-prefetch-pattern.md` for the full protocol and decision tree.

### team_name Parameter

The `team_name` parameter on Task tool associates sub-agents with a team's task list. Use when:
- Spawning teammates in an existing team
- Sub-agents need access to team's shared task list

Do NOT use for general sub-agent work outside teams.

---

## Quick Start Commands

```bash
# Single focused research
"Research how authentication works in this codebase"
→ Claude uses Task(subagent_type=Explore)

# Parallel independent work
"Research security, performance, and testing best practices"
→ Claude uses 3 parallel Task calls

# Phased project
"/orchestrate my-feature"
→ Creates .development/ structure, multi-agent-workflows

# Non-engineering workflow
"/orchestrate --think my-strategy"
→ Research → analysis → synthesis → recommendations

# Collaborative team
"Create an agent team to review this PR with different perspectives"
→ Claude uses TeamCreate, spawns teammates
```

---

## Related Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `multi-agent-workflows` | Full framework for 5+ agents | Large-scale, multi-phase projects |
| `iterative-agent-refinement` | Pause/resume pattern | Approval gates, user input mid-execution |
| `best-practices-reference` | Tool selection guide | Choosing between Read/Edit/Glob/Grep/Bash |

**Decision tree for details:** See `skills/multi-agent-workflows/reference/decision-tree.md`

---

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Correct Approach |
|--------------|--------------|------------------|
| Using Teams for independent parallel work | Overhead exceeds benefit | Parallel Task calls |
| Using subagents when agents need to debate | Missing collaboration value | Agent Teams |
| Using multi-agent-workflows for 2-step task | Too much structure | Direct execution |
| Orchestrator calling MCP directly | Context bloat (~25KB per call) | Delegate to foreground sub-agent with dual return |
| Using run_in_background for MCP work | Background agents can't access MCP | Use run_in_background: false for MCP agents |
| Arbitrary "5+ agents" threshold | Doesn't reflect intent | Ask "do agents need to discuss?" |

---

## Summary

The right orchestration pattern depends on **how agents need to work together**, not arbitrary thresholds:

1. **No delegation needed** → Direct execution
2. **Agents work independently, you synthesize** → Subagents (Task tool)
3. **Agents need to discuss with each other** → Agent Teams
4. **Complex phases with persistent context** → Multi-agent-workflows
5. **User input needed mid-execution** → Add iterative-agent-refinement

**The key differentiating question:**

> "Do the agents need to discuss with each other, or just report back to you?"
