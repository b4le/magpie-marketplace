# Directory Structure: Password Reset Example

This document shows the complete file structure of the password reset workflow example.

```
simple-workflow/
├── README.md                                    # Example overview and navigation guide
├── DIRECTORY-STRUCTURE.md                       # This file - visual directory map
│
└── .development/
    └── workflows/
        └── password-reset-example/
            │
            ├── workflow-state.yaml              # Initial workflow state (START HERE)
            ├── workflow-state-FINAL.yaml        # Final workflow state (END HERE)
            │
            ├── active/                          # Active phase work (before archival)
            │   │
            │   ├── planning/
            │   │   ├── README.md                # Planning phase instructions for agents
            │   │   ├── STATUS.yaml              # Planning phase status (shows before/after states)
            │   │   └── agent-001-requirements.md  # Agent-001 output: requirements analysis
            │   │
            │   └── implementation/
            │       ├── README.md                # Implementation phase instructions
            │       └── agent-002-password-reset.md  # Agent-002 output: implementation details
            │
            ├── archive/                         # Completed phases (after archival)
            │   │
            │   ├── planning-20251124T1500/
            │   │   └── phase-summary.md         # Planning phase synthesis
            │   │
            │   └── implementation-20251124T1630/
            │       └── phase-summary.md         # Implementation phase synthesis
            │
            └── shared/                          # Cross-phase artifacts (none in this example)
```

---

## File Reading Order

### Option 1: Quick Overview (5 minutes)
1. `README.md` - Example overview
2. `workflow-state.yaml` - Initial state
3. `workflow-state-FINAL.yaml` - Final state
4. `archive/planning-20251124T1500/phase-summary.md` - Planning summary
5. `archive/implementation-20251124T1630/phase-summary.md` - Implementation summary

### Option 2: Complete Walkthrough (20 minutes)
1. `README.md` - Example overview
2. `workflow-state.yaml` - Initial state
3. `active/planning/README.md` - Planning phase setup
4. `active/planning/STATUS.yaml` - Status tracking (initial state)
5. `active/planning/agent-001-requirements.md` - Agent output
6. `active/planning/STATUS.yaml` - Status tracking (after agent-001 - see commented section)
7. `archive/planning-20251124T1500/phase-summary.md` - Planning synthesis
8. `active/implementation/README.md` - Implementation phase setup
9. `active/implementation/agent-002-password-reset.md` - Agent output
10. `archive/implementation-20251124T1630/phase-summary.md` - Implementation synthesis
11. `workflow-state-FINAL.yaml` - Final state

### Option 3: Focus on State Management (10 minutes)
1. `workflow-state.yaml` - Initial state
2. `active/planning/STATUS.yaml` - Phase-level status
3. `workflow-state.yaml` (see comments) - State after planning
4. `workflow-state-FINAL.yaml` - Final state
5. Compare initial → intermediate → final to understand state progression

---

## Key File Sizes (Token Estimates)

| File | Purpose | Approx. Tokens |
|------|---------|----------------|
| `README.md` | Example overview | 800 |
| `workflow-state.yaml` | Initial state + snapshots | 600 |
| `workflow-state-FINAL.yaml` | Final state | 700 |
| `active/planning/README.md` | Phase instructions | 500 |
| `active/planning/STATUS.yaml` | Status tracking | 400 |
| `active/planning/agent-001-requirements.md` | Requirements analysis | 2,800 |
| `archive/planning-20251124T1500/phase-summary.md` | Planning synthesis | 2,200 |
| `active/implementation/README.md` | Phase instructions | 400 |
| `active/implementation/agent-002-password-reset.md` | Implementation details | 3,200 |
| `archive/implementation-20251124T1630/phase-summary.md` | Implementation synthesis | 2,000 |

**Total**: ~13,600 tokens (reading entire example)

---

## State Progression Visualization

```
┌─────────────────────────────────────────────────────────────┐
│ INITIAL STATE (workflow-state.yaml)                         │
│ • status: planning                                           │
│ • agents: 0 launched                                         │
│ • tokens: 0 used                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ PLANNING PHASE (active/planning/)                           │
│ • Agent-001 launches → agent-001-requirements.md created     │
│ • STATUS.yaml updated: agents_completed: 1                   │
│ • Question asked & resolved (token expiry)                   │
│ • Duration: 30 minutes, Tokens: 12,500                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ PLANNING ARCHIVED (archive/planning-20251124T1500/)         │
│ • phase-summary.md synthesizes agent-001 output              │
│ • workflow-state.yaml updated: planning → completed          │
│ • Active planning/ folder contents moved to archive          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ IMPLEMENTATION PHASE (active/implementation/)               │
│ • Agent-002 launches → agent-002-password-reset.md created   │
│ • Implements: DB migration, APIs, tests                      │
│ • Duration: 90 minutes, Tokens: 14,300                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ IMPLEMENTATION ARCHIVED (archive/implementation-.../)       │
│ • phase-summary.md synthesizes agent-002 output              │
│ • workflow-state.yaml updated: implementation → completed    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ FINAL STATE (workflow-state-FINAL.yaml)                     │
│ • status: completed                                          │
│ • agents: 2 completed                                        │
│ • tokens: 26,800 used (24.4% of budget)                      │
│ • duration: 135 minutes                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## What to Learn from Each File

### Workflow State Files
- `workflow-state.yaml` - How to initialize a workflow, track active phases
- `workflow-state-FINAL.yaml` - How completed workflows look, metrics calculation

### Phase READMEs
- `active/planning/README.md` - How to set phase objectives and agent instructions
- `active/implementation/README.md` - How to reference previous phases

### Status Files
- `active/planning/STATUS.yaml` - Phase-level status tracking, agent progress

### Agent Outputs
- `agent-001-requirements.md` - Planning agent output format (requirements, decisions, questions)
- `agent-002-password-reset.md` - Implementation agent output format (files created/modified, testing)

### Phase Summaries
- `archive/planning-20251124T1500/phase-summary.md` - How to synthesize planning work
- `archive/implementation-20251124T1630/phase-summary.md` - How to document implementation

---

## Example Patterns Demonstrated

1. **Two-Phase Workflow**: Planning → Implementation (common pattern)
2. **Single Agent Per Phase**: Simple workflows may only need one agent per phase
3. **Question/Answer Flow**: Agent asks question, orchestrator answers (see planning phase)
4. **State Snapshots**: Showing state at different points (initial, after planning, final)
5. **Phase Archival**: How active/ content moves to archive/ with synthesis
6. **Handoff Context**: How planning outputs inform implementation work
7. **Token Efficiency**: Completing workflow in 24% of budget
8. **Decision Logging**: Tracking architectural decisions across phases

---

**Last Updated**: 2025-11-24
