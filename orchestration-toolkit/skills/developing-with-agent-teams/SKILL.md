---
name: developing-with-agent-teams
description: >
  Spawn and coordinate agent teams for complex projects.
  Use when building features requiring 3+ agents, running parallel research,
  or orchestrating multi-phase work. Supports engineering, research, and
  creative workflows with flexible team composition.
version: 1.0.0
created: 2026-02-12
last_updated: 2026-02-17
---

# Developing with Agent Teams

Orchestrate agent teams for complex, multi-phase work. Describe what you want to build—Claude handles team composition, task assignment, and coordination.

## Prerequisites

Enable agent teams in your settings:

```json
// In settings.json or .claude/settings.local.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Restart Claude Code after enabling.

## When to Use This Skill

**Use when:**
- Building features requiring 3+ coordinated agents
- Running parallel research across multiple domains
- Orchestrating multi-phase work (research → design → implementation)
- Need visibility into agent progress via file system
- Working on projects that benefit from role specialization

**Do NOT use when:**
- Task requires 1-2 agents (use Task tool directly)
- Simple, sequential work without parallelism
- Quick exploration or single-file changes
- No need for persistent state tracking

## Quick Start

**Invoke:** `/orchestration-toolkit:developing-with-agent-teams`

1. **Describe your project**

   Tell Claude what you want to build. Be specific about outcomes.

   > "Build a feature that lets users export their data as PDF"

   > "Research authentication patterns and recommend an approach"

2. **Claude spawns a team**

   Based on complexity, Claude creates:
   - `.development/{project}/` folder structure
   - Team with appropriate roles
   - Tasks with dependencies

3. **Monitor and guide**

   Check progress in `.development/{project}/README.md`.
   Agents ping you for clarification via SendMessage.
   Review outputs in `phases/{phase}/outputs/`.

For explicit phase/role configuration, see @reference/workflow-phases.md

## Workflow Folder Structure

When a team spawns, this structure is created:

```
.development/
└── {project-name}/
    ├── README.md              # Project overview, current status
    ├── workflow-state.yaml    # Global state tracking
    ├── phases/
    │   └── {phase-name}/
    │       ├── STATUS.yaml    # Phase status
    │       └── outputs/       # Agent deliverables
    │           └── {agent}-{topic}.md
    └── shared/
        ├── decisions.md       # Key decisions (rationale, tradeoffs, outcomes)
        └── context.md         # Shared context (domain knowledge, constraints)
```

**Where to look:**
- `README.md` — Quick status check
- `workflow-state.yaml` — Current phase, team info
- `phases/{phase}/STATUS.yaml` — Phase progress, blockers
- `phases/{phase}/outputs/` — Agent deliverables

## Team Composition

Let Claude reason about team composition, or specify explicitly.

### Common Roles

| Role | Agent Type | Typical Work |
|------|------------|--------------|
| Researcher | Explore | Investigation, documentation |
| Architect | Plan | System design, decisions |
| Engineer | general-purpose | Implementation |
| Reviewer | general-purpose | Validation, testing |

### Specifying Roles

**Implicit** (Claude decides):
> "Build a CLI tool that fetches weather data"

**Explicit** (you specify):
> "Build a CLI tool with: 1 researcher, 1 architect, 2 engineers"

For role prompt templates, see @reference/team-roles.md

## Workflow Phases

### Engineering Projects

| Phase | Purpose | Typical Agents |
|-------|---------|----------------|
| planning | Requirements, architecture | Researcher, Architect |
| execution | Implementation | Engineers (parallel) |
| review | Validation, cleanup | Reviewer |

### Research Projects

| Phase | Purpose | Typical Agents |
|-------|---------|----------------|
| research | Gather information | Researchers (parallel) |
| analysis | Process findings | Analyst |
| synthesis | Combine insights | Writer |
| recommendations | Actionable output | PM |

### Custom Phases

Specify your own:
> "Phases: discovery, prototyping, polish, launch"

For phase configuration details, see @reference/workflow-phases.md

## Communication Patterns

### Task Dependencies

```python
# Create dependent tasks
TaskCreate(subject="Design API", ...)
TaskCreate(subject="Implement API", addBlockedBy=["task-1"], ...)
```

### Agent Coordination

```python
# Direct message
SendMessage(type="message", recipient="engineer-1",
            content="Auth module ready for integration",
            summary="Auth module ready")

# Team-wide (use sparingly)
SendMessage(type="broadcast",
            content="Switching to review phase",
            summary="Phase transition")
```

### Graceful Shutdown

```python
# Request shutdown when complete
SendMessage(type="shutdown_request", recipient="researcher",
            content="Research complete, shutting down")
```

**Critical:** All Task calls spawning agents must include:
```python
Task(..., run_in_background=False)  # Required for MCP access
```

For full communication patterns, see @reference/communication-patterns.md

## Templates

| Template | Purpose | When to Use |
|----------|---------|-------------|
| `workflow-state.yaml` | Track overall project state | Copy to `.development/{project}/` |
| `phase-status.yaml` | Track phase progress | Copy to `phases/{phase}/STATUS.yaml` |

See @templates/

## Troubleshooting

@reference/troubleshooting.md

## Quick Reference

### Key Tools

| Tool | Purpose |
|------|---------|
| `TeamCreate` | Create named team |
| `TeamDelete` | Clean up when complete |
| `TaskCreate` | Create tasks with dependencies |
| `TaskUpdate` | Update status, mark complete |
| `TaskList` | View all tasks |
| `Task` | Spawn agents (subagent_type: Explore/Plan) |
| `SendMessage` | Coordinate between agents |

### Required Parameters

```python
# Agent spawning (MUST include)
Task(..., run_in_background=False)

# Task dependencies
TaskCreate(..., addBlockedBy=["task-id"])

# Shutdown
SendMessage(type="shutdown_request", recipient="agent-name", ...)
```

### Environment Variable

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```
