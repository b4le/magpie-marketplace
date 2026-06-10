# Strategic Planning Workflow Example

This example demonstrates using multi-agent workflows for **strategic thinking tasks** like quarterly planning, roadmap development, and decision frameworks.

## Use Case

Developing a strategic plan (e.g., product roadmap, organizational strategy, initiative prioritization) through structured research and analysis.

## Workflow Structure

```
/orchestrate --think q1-roadmap

Phases: research → analysis → synthesis → recommendations
```

## Phase Breakdown

### Phase 1: Research

**Goal:** Gather context, data, and stakeholder input

**Agent prompt example:**
```
You are working in workflow: q1-roadmap
Phase: research

Task:
1. Read current strategy documents in /strategy/
2. Analyze market context and competitor landscape
3. Review stakeholder feedback and user research
4. Identify constraints (budget, timeline, resources)
5. Output: research/context-summary.md

Save output to: .development/workflows/q1-roadmap/active/research/
```

**Expected outputs:**
- `context-summary.md` - Current state overview
- `constraints.md` - Known constraints and requirements
- `stakeholder-input.md` - Key stakeholder perspectives

### Phase 2: Analysis

**Goal:** Evaluate options, identify trade-offs

**Agent prompt example:**
```
You are working in workflow: q1-roadmap
Phase: analysis

Context: Read all files in research/

Task:
1. Identify strategic options (3-5 paths forward)
2. Evaluate each option against criteria:
   - Impact potential
   - Resource requirements
   - Risk level
   - Strategic alignment
3. Create comparison matrix
4. Output: analysis/options-matrix.md

Save output to: .development/workflows/q1-roadmap/active/analysis/
```

**Expected outputs:**
- `options-matrix.md` - Comparison of strategic options
- `risk-assessment.md` - Risk analysis per option
- `resource-estimates.md` - Resource requirements

### Phase 3: Synthesis

**Goal:** Develop coherent strategy from analysis

**Agent prompt example:**
```
You are working in workflow: q1-roadmap
Phase: synthesis

Context:
- Read research/context-summary.md
- Read analysis/options-matrix.md

Task:
1. Synthesize research and analysis into recommended approach
2. Develop narrative for strategy
3. Identify key initiatives and sequencing
4. Create draft roadmap
5. Output: synthesis/draft-roadmap.md

Save output to: .development/workflows/q1-roadmap/active/synthesis/
```

**Expected outputs:**
- `draft-roadmap.md` - Draft strategic roadmap
- `initiative-priorities.md` - Prioritized initiatives
- `narrative.md` - Strategy narrative/story

### Phase 4: Recommendations

**Goal:** Finalize deliverables and action plan

**Agent prompt example:**
```
You are working in workflow: q1-roadmap
Phase: recommendations

Context: Read synthesis/draft-roadmap.md

Task:
1. Finalize strategic recommendations
2. Create actionable plan with milestones
3. Define success metrics and KPIs
4. Identify dependencies and risks
5. Output: recommendations/strategic-plan.md

Save output to: .development/workflows/q1-roadmap/active/recommendations/
```

**Expected outputs:**
- `strategic-plan.md` - Final strategic plan
- `milestones.md` - Key milestones and timeline
- `metrics.md` - Success criteria and KPIs
- `risks-mitigations.md` - Risk management plan

## Workflow State Example

```yaml
workflow_id: q1-roadmap
type: thinking
created: 2025-12-06T10:00:00Z
status: in-progress

current_phase: synthesis
phases:
  - name: research
    status: completed
  - name: analysis
    status: completed
  - name: synthesis
    status: in-progress
  - name: recommendations
    status: pending

agents:
  - id: research-agent-001
    phase: research
    status: completed
    output: research/context-summary.md
  - id: analysis-agent-001
    phase: analysis
    status: completed
    output: analysis/options-matrix.md

decisions:
  - date: 2025-12-06
    decision: Focus on customer growth over operational efficiency
    rationale: Market opportunity window closing
    phase: analysis
  - date: 2025-12-06
    decision: 3 major initiatives max for Q1
    rationale: Resource constraints
    phase: synthesis
```

## Using Approval Gates

Strategic planning often benefits from stakeholder review. Use `iterative-agent-refinement` pattern:

```
Phase: synthesis
1. Agent creates draft roadmap
2. PAUSE - "Does this draft align with leadership direction?"
3. User reviews, provides feedback
4. RESUME - Agent incorporates feedback
5. Continue to recommendations
```

## Custom Phase Variations

### Initiative Prioritization
```
/orchestrate --think initiative-review research scoring ranking recommendations
```

### Decision Framework
```
/orchestrate --think decision-framework context options evaluation decision
```

### Quarterly Business Review
```
/orchestrate --think qbr-q4 retrospective metrics goals planning
```

## Tips for Strategic Workflows

1. **Use AskUserQuestion liberally** - Strategic decisions need human judgment
2. **Save decisions to shared/decisions.md** - Track rationale for future reference
3. **Break into smaller workflows** - One workflow per strategic question
4. **Archive completed workflows** - Maintain decision history
5. **Compose with iterative-agent-refinement** - Approval gates are valuable for strategy
