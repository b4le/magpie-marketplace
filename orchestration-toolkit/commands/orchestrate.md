---
name: orchestrate
description: Initialize orchestrated multi-agent workflow with phase structure
argument-hint: "[workflow-id] [phases...]"
version: 2.0.0
---

Initialize orchestrated workflow with smart defaults.

## Arguments

- **$1** (optional): Workflow ID. If omitted, auto-generates from context.
- **$ARGUMENTS** (optional): Custom phases. If omitted, uses smart defaults.

## Flags

- `--think`: Use non-engineering workflow (research → analysis → synthesis → recommendations)
- `--flat`: Single-agent execution (no sub-agent spawning). Agent executes all phases sequentially.

## Quick Start

```
/orchestrate                           # Auto-everything
/orchestrate my-feature                # Custom ID, default phases
/orchestrate my-feature plan execute   # Custom ID and phases
/orchestrate --think strategy-review   # Non-engineering workflow
/orchestrate --flat my-task            # Single-agent, no sub-agents
/orchestrate --think --flat analysis   # Non-engineering + flat execution
```

---

## Instructions

### Step 1: Parse Arguments

**Detect flags:**
- If `--think` is present: Set `WORKFLOW_TYPE=thinking`, remove from arguments
- Otherwise: Set `WORKFLOW_TYPE=engineering`
- If `--flat` is present: Set `EXECUTION_MODE=flat`, remove from arguments
- Otherwise: Set `EXECUTION_MODE=delegated`

**Determine workflow-id:**
- If `$1` provided and not a flag: Use as workflow-id
- If omitted: Generate from current date: `workflow-{YYYYMMDD}-{HHMMSS}`

**Determine phases:**
- If additional arguments after workflow-id: Use those as phases
- If `--think` flag: Use `research analysis synthesis recommendations`
- Otherwise: Use default `planning execution review`

### Step 2: Validate

**Check workflow doesn't exist:**
```bash
ls .development/workflows/$WORKFLOW_ID/ 2>/dev/null && echo "ERROR: Workflow exists" && exit 1
```

**Validate workflow-id format:**
- No spaces, no special chars except `-` and `_`
- If invalid, suggest: `{feature-name}-{YYYYMMDD}`

### Step 3: Create Structure

```bash
# Create directories
mkdir -p .development/workflows/$WORKFLOW_ID/{active,archive,shared}

# Create phase directories
for phase in $PHASES; do
  mkdir -p .development/workflows/$WORKFLOW_ID/active/$phase
done
```

### Step 4: Create Minimal State File

**Create `workflow-state.yaml`:**

```yaml
workflow_id: $WORKFLOW_ID
type: $WORKFLOW_TYPE
execution_mode: $EXECUTION_MODE  # 'flat' or 'delegated'
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
status: in-progress

current_phase: $FIRST_PHASE
phases:
$PHASE_ENTRIES

agents: []
decisions: []
```

Where `$PHASE_ENTRIES` is generated as:
```yaml
  - name: $PHASE_NAME
    status: pending  # First phase = "in-progress"
```

### Step 5: Create Phase Files (Minimal)

For each phase, create a simple `README.md`:

```markdown
# $PHASE_NAME Phase

## Context
Part of workflow: $WORKFLOW_ID

## Goal
[To be defined by first agent in this phase]

## Outputs
Save outputs to this directory.

## Status
Update ../workflow-state.yaml when complete.
```

### Step 6: Create Shared Files

**`shared/decisions.md`:**
```markdown
# Decisions

| Date | Decision | Rationale | Phase |
|------|----------|-----------|-------|
```

### Step 7: Output (Concise)

**For delegated mode (default):**
```
Workflow initialized: $WORKFLOW_ID

Phases: $PHASE_LIST
Current: $FIRST_PHASE (in-progress)
Mode: delegated (sub-agents)

Location: .development/workflows/$WORKFLOW_ID/

Ready to start. Launch your first agent for the $FIRST_PHASE phase.
```

**For flat mode (--flat flag):**
```
Workflow initialized: $WORKFLOW_ID

Phases: $PHASE_LIST
Current: $FIRST_PHASE (in-progress)
Mode: flat (single-agent, no spawning)

Location: .development/workflows/$WORKFLOW_ID/

FLAT EXECUTION: Execute all phases directly without using the Task tool.
Use TodoWrite to track progress. Save outputs to phase directories.
See: skills/multi-agent-workflows/reference/patterns/flat-execution.md
```

**That's it.** No lengthy "Next Steps". The user is ready to proceed.

---

## Error Handling

| Error | Message |
|-------|---------|
| Workflow exists | `Workflow '$ID' exists. Use different ID or resume existing.` |
| Invalid ID | `Invalid ID. Use format: feature-name-YYYYMMDD` |

---

## Examples

### Engineering Workflow
```
/orchestrate auth-feature
→ Phases: planning, execution, review
→ Location: .development/workflows/auth-feature/
```

### Strategic Thinking Workflow
```
/orchestrate --think q4-strategy
→ Phases: research, analysis, synthesis, recommendations
→ Location: .development/workflows/q4-strategy/
```

### Custom Phases
```
/orchestrate migration audit plan migrate validate
→ Phases: audit, plan, migrate, validate
→ Location: .development/workflows/migration/
```

---

## Related Skills

- **multi-agent-workflows**: Full framework for 5+ agents, multi-phase projects
- **iterative-agent-refinement**: Pause/resume pattern for approval gates

See `skills/multi-agent-workflows/reference/decision-tree.md` for when to use each.
