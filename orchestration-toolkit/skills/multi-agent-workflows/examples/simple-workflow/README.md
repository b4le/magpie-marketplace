# Simple Two-Phase Workflow Example: Password Reset Feature

## Overview

This is a complete, realistic example demonstrating the multi-agent-workflows framework for a simple feature implementation workflow. The scenario simulates implementing a password reset feature through two phases: **planning** and **implementation**.

**Scenario**: "Implement password reset feature for user authentication system"

**Total Duration**: ~2 hours 15 minutes
**Agents Used**: 2 agents (1 planning, 1 implementation)
**Tokens Used**: 26,800 / 110,000 budgeted

---

## Workflow Phases

### Phase 1: Planning
- **Agent**: agent-001-requirements
- **Duration**: 45 minutes
- **Tokens**: 12,500
- **Outputs**: Requirements analysis, user stories, technical specifications, security considerations

### Phase 2: Implementation
- **Agent**: agent-002-password-reset
- **Duration**: 90 minutes
- **Tokens**: 14,300
- **Outputs**: Implementation details, code changes, testing notes

---

## Learning Objectives

After reviewing this example, you will understand:

1. **State Progression**: How `workflow-state.yaml` evolves from start to completion
2. **Phase Structure**: How planning outputs inform implementation work
3. **Agent Outputs**: Realistic format and content of agent deliverables
4. **Archival Process**: How completed phases are archived with summaries
5. **Handoff Patterns**: How information flows from planning to implementation

---

## How to Navigate This Example

### Start Here: Initial State
Begin by reviewing the workflow at its starting point:
```
.development/workflows/password-reset-example/workflow-state.yaml (initial)
```

### Follow the Planning Phase
1. Read `.development/workflows/password-reset-example/active/planning/README.md`
2. Review `.development/workflows/password-reset-example/active/planning/STATUS.yaml` (initial - empty)
3. Study `.development/workflows/password-reset-example/active/planning/agent-001-requirements.md` (agent output)
4. Check `.development/workflows/password-reset-example/active/planning/STATUS.yaml` (updated - after agent-001)

### See Planning Archived
1. Read `.development/workflows/password-reset-example/archive/planning-20251124T1500/phase-summary.md`
2. Review `.development/workflows/password-reset-example/workflow-state.yaml` (after planning archived)

### Follow the Implementation Phase
1. Read `.development/workflows/password-reset-example/active/implementation/README.md`
2. Study `.development/workflows/password-reset-example/active/implementation/agent-002-password-reset.md` (agent output)

### See Final State
1. Review `.development/workflows/password-reset-example/archive/implementation-20251124T1630/phase-summary.md`
2. Check `.development/workflows/password-reset-example/workflow-state.yaml` (final - workflow complete)

---

## Key Files

| File | Purpose | State Shown |
|------|---------|-------------|
| `workflow-state.yaml` | Main workflow state tracking | Multiple snapshots at different stages |
| `active/planning/README.md` | Planning phase instructions for agents | Customized for password reset |
| `active/planning/STATUS.yaml` | Planning phase status tracking | Before and after agent-001 |
| `active/planning/agent-001-requirements.md` | Requirements analysis output | Completed agent deliverable |
| `archive/planning-20251124T1500/phase-summary.md` | Planning phase synthesis | Created during archival |
| `active/implementation/README.md` | Implementation phase instructions | Customized for password reset |
| `active/implementation/agent-002-password-reset.md` | Implementation output | Completed agent deliverable |
| `archive/implementation-20251124T1630/phase-summary.md` | Implementation synthesis | Created during archival |

---

## What Makes This Example Realistic

- **Authentic Content**: Real requirements, user stories, security considerations (not Lorem ipsum)
- **Token Estimates**: Realistic token usage based on actual agent work
- **Time Progression**: Timestamps show realistic duration for each phase
- **Decision Points**: Shows how architectural decisions are made and documented
- **Handoff Clarity**: Demonstrates how planning outputs inform implementation
- **Practical Scope**: Password reset is complex enough to show patterns but simple enough to follow

---

## Using This Example

### For Learning
- Follow the navigation guide above to understand workflow progression
- Compare different states of `workflow-state.yaml` to see how state evolves
- Study agent outputs to understand expected quality and format

### For Templates
- Copy the structure to `.development/workflows/{your-workflow-id}/`
- Customize phase READMEs for your specific objectives
- Use agent outputs as formatting examples

### For Testing
- Use this as a reference implementation to validate your own workflows
- Check that your workflow structure matches this example
- Verify your agent outputs follow similar patterns

---

## Example Statistics

| Metric | Value |
|--------|-------|
| **Total Duration** | 135 minutes (2h 15m) |
| **Phases** | 2 (planning, implementation) |
| **Agents** | 2 total |
| **Total Tokens** | 26,800 |
| **Token Budget** | 110,000 |
| **Budget Utilization** | 24.4% |
| **Decisions Made** | 3 key decisions |
| **Questions Resolved** | 1 (token expiry duration) |
| **Files Modified** | 4 files in implementation |

---

## Related Documentation

- **Framework Overview**: `../../reference/file-structure-spec.md`
- **Orchestrator Guide**: `../../reference/orchestrator-guide.md`
- **Sub-agent Guide**: `../../reference/subagent-guide.md`
- **Archival Process**: `../../reference/archival-process.md`

---

**Example Version**: 1.0.0
**Created**: 2025-11-24
**Last Updated**: 2025-11-24
