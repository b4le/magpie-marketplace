---
name: multi-agent-workflows
description: >
  DEPRECATED (v2.0) — Framework for managing complex multi-agent workflows with persistent context storage.
  This skill uses the .development/workflows/{workflow-id}/ folder structure and workflow-state.yaml state model,
  which are replaced by the composable pipeline in v3.0. For new work, use /orchestrate (which runs decompose
  and dispatches agents automatically). This skill is retained for reference only.
version: 2.0.0
created: 2025-11-20
last_updated: 2026-03-09
deprecated: true
deprecated_in: "3.0.0"
replacement: "Use /orchestrate (composable pipeline) + decompose skill instead"
tags:
  - orchestration
  - multi-agent
  - workflows
  - context-persistence
---

> **DEPRECATED:** This skill describes the v2.0 `.development/workflows/` pattern, which was replaced in v3.0 by the composable pipeline (`/orchestrate` + `decompose`). For new work, run `/orchestrate` — it handles decomposition, agent assignment, and dispatch automatically. Plans are stored at `~/.claude/decompose/plans/`. This file is retained as a reference for workflows that were started under v2.0.

## Choosing the Right Pattern

**Not sure if this is the right skill?** Start with `skills/orchestration-guide/SKILL.md` for the central decision framework.

**The key question:** Do agents need to discuss with each other, or just report back to you?
- **Report back** → This skill (multi-agent-workflows) or parallel Task calls
- **Discuss** → Agent Teams (TeamCreate)

## When to Use This Skill

### Use This Skill When:
- ✅ Task requires **distinct phases with context persistence across agents**
- ✅ Multi-phase workflow with distinct phases
- ✅ Context must **persist across multiple agents** (agent B needs agent A's outputs)
- ✅ Long-running work (hours or days, not minutes)
- ✅ Multiple orchestrators may run concurrently
- ✅ Orchestrator synthesizes between phases (agents don't need to discuss)

**Engineering examples:**
- Complex refactoring, feature implementation, system migration
- Multi-phase development: planning → design → execution → review

**Non-engineering examples:**
- Document analysis: collection → extraction → synthesis → recommendations
- Strategic planning: research → analysis → synthesis → recommendations
- Content creation: ideation → drafting → editing → publishing

### Do NOT Use This Skill When:
- ❌ Simple tasks without phase boundaries (use direct Task tool orchestration instead)
- ❌ Single-file edits or quick fixes
- ❌ Tasks completable in under 30 minutes
- ❌ No need for persistent context between agents
- ❌ Agents need to debate/challenge each other → Use Agent Teams instead

## Related Skills

**For decision guidance:** See `skills/orchestration-guide/SKILL.md` (central entry point)

**When to use iterative-agent-refinement instead**:
- Task doesn't need phase boundaries or context persistence
- Need pause/resume for user input mid-execution
- Iterative refinement with approval gates
- Single-agent tasks requiring checkpoints

**When to use Agent Teams instead**:
- Agents need to discuss, debate, or challenge each other
- Multiple perspectives that should interact
- Collaborative work requiring peer-to-peer communication

See `skills/iterative-agent-refinement/SKILL.md` for the pause/resume pattern.

## Critical: MCP Tool Access

**Sub-agents require `run_in_background: false` to access MCP tools.**

Background agents in Claude Code cannot access MCP tools (Groove, Jira, Google Drive, etc.). Always set `run_in_background: false` when launching Task agents that need MCP access:

```javascript
Task({
  subagent_type: "general-purpose",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `...`
});
```

All examples in this skill include this parameter.

## Quick Start: For Orchestrators

> **Note:** This section documents the v2.0 `.development/workflows/` pattern. In v3.0, `/orchestrate` initializes and manages the entire pipeline — there is no manual directory setup. Jump to `/orchestrate` unless you are resuming an existing v2.0 workflow.

### Step 1: Initialize Workflow (v2.0 pattern — deprecated)

```bash
# Create workflow structure
mkdir -p .development/workflows/{workflow-id}/{active,archive,shared}

# Create initial state file from template
# See: templates/workflow-state.yaml

# Create phase folders (use subset as needed)
mkdir -p .development/workflows/{workflow-id}/active/{planning,research,design,execution,review}

# Populate each phase with README.md from template
# See: templates/phase-readme.md
```

**Note**: Workflow ID should be unique per concurrent workflow (e.g., `feature-auth-20251124`, `refactor-api-v2`, etc.)

### Step 2: Launch Sub-Agents

```javascript
// Example: Launch planning agent
Task({
  subagent_type: "Plan",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `
    You are working within an orchestrated workflow: feature-auth-20251124

    Context from previous agents:
    ${JSON.stringify(context_files)}

    Questions answered:
    ${JSON.stringify(questions_answered)}

    Your task: ${continuation_prompt}

    Output location: .development/workflows/feature-auth-20251124/active/planning/

    Instructions:
    1. Read context files listed above
    2. Create output file: agent-{your-id}-{topic}.md
    3. Update STATUS.yaml when complete or blocked
    4. Return JSON: {status, output_paths, questions, summary}

    For detailed guidance, read:
    .development/workflows/feature-auth-20251124/active/planning/README.md
  `
})
```

### Step 3: Monitor Status

```bash
# Check phase status
cat .development/workflows/{workflow-id}/active/{phase}/STATUS.yaml

# Look for signal files
ls .development/workflows/{workflow-id}/active/{phase}/NEEDS-INPUT.md  # Exists if input needed
ls .development/workflows/{workflow-id}/active/{phase}/BLOCKED.md      # Exists if blocked
```

**When `status: needs-input`**:
1. Read `STATUS.yaml` for questions
2. Decide answers (or ask user via AskUserQuestion tool)
3. Pass answers to next sub-agent in `questions_answered` field

### Step 4: Archive Completed Phases

```bash
# When all agents in phase complete, launch cleanup agent:
Task({
  subagent_type: "general-purpose",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `
    Archive the planning phase for workflow: feature-auth-20251124

    1. Move .development/workflows/feature-auth-20251124/active/planning/
       to .development/workflows/feature-auth-20251124/archive/planning-{timestamp}/
    2. Create phase-summary.md synthesizing all agent outputs
    3. Update workflow-state.yaml with archival timestamp

    Use template: templates/phase-summary.md
  `
})
```

**For comprehensive orchestrator workflow, see:** `@reference/orchestrator-guide.md`


## File Conventions

@reference/file-conventions.md


## Templates

> **Deprecated templates** for the v2.0 `.development/workflows/` pattern. For v3.0 workflows, `/orchestrate` manages state in `~/.claude/decompose/plans/` — these templates are not used.

All templates available in `templates/` directory:

| Template | Purpose | Use When |
|----------|---------|----------|
| `workflow-state.yaml` | Persistent workflow state tracking (v2.0) | Resuming an existing v2.0 workflow |
| `phase-readme.md` | Phase "pseudo-skill" instructions | Resuming an existing v2.0 workflow |
| `agent-output.md` | Standard single-file agent output | Sub-agent creates output |
| `status.yaml` | Phase status tracking | Resuming an existing v2.0 workflow |
| `phase-summary.md` | Archival summary format | Archiving completed phase |
| `read-first.md` | Multi-file output index | Sub-agent creates folder with multiple files |

**Access templates (for existing v2.0 workflows only):**
```bash
# Copy template for use
cp templates/workflow-state.yaml \
   .development/workflows/{workflow-id}/workflow-state.yaml

# Read template for reference
cat templates/phase-readme.md
```


## Best Practices

@reference/best-practices.md


## Anti-Patterns

@reference/anti-patterns.md


## Examples

| Example | Use Case | Location |
|---------|----------|----------|
| Simple Workflow | Basic 3-phase engineering task | `@examples/simple-workflow/` |
| Multi-Phase Workflow | Complex engineering with 5+ phases | `@examples/multi-phase-workflow/` |
| Document Analysis | Non-engineering: analyzing documents | `@examples/document-analysis/` |
| Strategic Planning | Non-engineering: strategy development | `@examples/strategic-planning/` |
| Parallel Agents | Running multiple agents concurrently | `@examples/parallel-agents/` |
| Workflow Interruption | Handling interruptions and resumption | `@examples/workflow-interruption/` |

## Quick Reference

> **v3.0 replacement:** Use `/orchestrate` directly with a goal, spec file, or handoff — it runs decompose and dispatches agents automatically. The commands below are v2.0 patterns.

**v2.0 workflow initialization (deprecated — use `/orchestrate <goal>` instead):**
```
/orchestrate my-feature                    # Engineering (planning, execution, review)
/orchestrate --brainstorm my-strategy      # Non-engineering with brainstorm step
/orchestrate my-task phase1 phase2 phase3  # Custom phases
```

**Communication Protocol:** v1.1.0 (see `@reference/communication-protocol.md`)
- New optional fields: `protocol_version`, `agent_id`, `confidence`, `handoff`
- v1.0.0 outputs remain fully compatible

**Decision tree:** See `@reference/decision-tree.md` for when to use this skill vs. alternatives.
