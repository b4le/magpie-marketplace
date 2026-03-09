# Workflow Phases Reference

Phases organize work into logical stages. Use suggested patterns or define custom phases.

## Phase Patterns

### Engineering Workflow

Best for: Building features, implementing systems, code projects.

```
planning → execution → review
```

| Phase | Purpose | Agents | Outputs |
|-------|---------|--------|---------|
| planning | Requirements, design | Researcher, Architect | requirements.md, architecture.md |
| execution | Build the thing | Engineers (parallel) | Implementation files |
| review | Validate, test | Reviewer | review-findings.md |

### Research Workflow

Best for: Investigation, analysis, recommendations.

```
research → analysis → synthesis → recommendations
```

| Phase | Purpose | Agents | Outputs |
|-------|---------|--------|---------|
| research | Gather information | Researchers (parallel) | topic-findings.md |
| analysis | Process findings | Analyst | analysis.md |
| synthesis | Combine insights | Writer | synthesis.md |
| recommendations | Actionable output | PM | recommendations.md |

### Discovery Workflow

Best for: Exploring unknowns, understanding systems.

```
explore → document → validate
```

| Phase | Purpose | Agents | Outputs |
|-------|---------|--------|---------|
| explore | Investigate broadly | Researchers | exploration-notes.md |
| document | Capture findings | Writer | documentation.md |
| validate | Verify accuracy | Reviewer | validation-report.md |

### Custom Workflow

Define phases that match your project:

```
User: "Phases: discovery, prototyping, polish, launch"

discovery → prototyping → polish → launch
```

## Phase Transitions

### Automatic Transitions

Phases progress automatically when:
1. All agents in current phase complete
2. Phase STATUS.yaml shows `status: completed`
3. No blockers remain

### Manual Transitions

User can trigger transitions:
- "Move to execution phase"
- "Skip review, we're done"
- "Go back to planning"

### Handoff Protocol

When transitioning phases:

1. **Current phase summary**
   - Agent outputs synthesized
   - Key decisions documented in `shared/decisions.md`
   - Blockers resolved or escalated

2. **Next phase setup**
   - New STATUS.yaml created
   - Agents spawned for next phase
   - Context passed via `shared/context.md`

3. **Update workflow-state.yaml**
   - `current_phase` updated
   - Previous phase marked completed

## Phase Dependencies

Create dependent phases using task blocking:

```python
# Phase 2 waits for Phase 1
TaskCreate(
    subject="Execute implementation",
    description="Build feature per architecture",
    addBlockedBy=["planning-task-id"]
)
```

## Phase Outputs

### Required Outputs

Each phase should produce:
- Summary file in `outputs/`
- Updated STATUS.yaml
- Updated decisions if any made

### Output Naming

```
outputs/{agent}-{topic}.md

Examples:
- researcher-1-auth-patterns.md
- architect-system-design.md
- engineer-api-implementation.md
```

## Parallel vs Sequential Phases

### Parallel Within Phase

Multiple agents can work simultaneously:

```
planning/
├── researcher-1 → requirements
├── researcher-2 → existing-patterns
└── architect → preliminary-design (blocked by researchers)
```

### Sequential Between Phases

Phases generally run sequentially:

```
planning (complete) → execution (in_progress) → review (pending)
```

### Hybrid Approach

Some phases can overlap:

```
Late planning + early execution
  └─ Architect refining design
  └─ Engineer starting foundation work
```

## Phase Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started |
| `in_progress` | Agents actively working |
| `blocked` | Waiting on external input |
| `completed` | All work done |

## Examples

### Simple Engineering Project

```yaml
phases:
  - name: planning
    status: completed
    agents: [researcher, architect]
  - name: execution
    status: in_progress
    agents: [engineer-1, engineer-2]
  - name: review
    status: pending
    agents: []
```

### Research with Custom Phases

```yaml
phases:
  - name: literature-review
    status: completed
    agents: [researcher-1, researcher-2]
  - name: gap-analysis
    status: in_progress
    agents: [analyst]
  - name: proposal
    status: pending
    agents: []
```
