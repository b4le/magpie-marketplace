---
phase: REPLACE_WITH_PHASE_NAME          # planning | research | design | execution | review
workflow_id: REPLACE_WITH_WORKFLOW_ID   # e.g., feature-auth-20251124
archived_at: REPLACE_WITH_TIMESTAMP     # YYYY-MM-DDTHH:MM:SSZ
started_at: REPLACE_WITH_TIMESTAMP      # When phase started
completed_at: REPLACE_WITH_TIMESTAMP    # When phase completed
duration_minutes: 0                     # Calculate from started_at to completed_at
agents_involved: []                     # List of agent IDs, e.g., [agent-001, agent-002]
total_tokens_used: 0                    # Sum of all agent token usage
token_budget: 50000                     # Original budget allocation
budget_status: under | over | at        # under: <100%, at: 100-120%, over: >120%
---

# [Phase Name] Phase Summary

## Overview

**Duration**: [X hours/minutes]
**Agents**: [Count] agents completed work
**Tokens Used**: [total_tokens_used] / [token_budget] ([percent]%)
**Status**: ✅ Completed successfully

[2-3 sentence summary of what was accomplished in this phase]

Example: "Planning phase established clear requirements for authentication system through analysis of 8 user personas. Architectural decisions made for OAuth 2.0 + JWT approach. Task breakdown created with 15 discrete implementation steps across 4 development phases."

---

## Objectives Achieved

[List the phase objectives from the phase README.md and mark which were achieved]

- ✅ Objective 1: [Description]
- ✅ Objective 2: [Description]
- ✅ Objective 3: [Description]
- ⚠️ Objective 4: [Partially achieved - explain why]
- ❌ Objective 5: [Not achieved - explain why and next steps]

---

## Key Outputs

### Agent-001: [Topic]

**Output**: `agent-001-[topic].md`
**Tokens**: [token count]
**Summary**: [1-2 sentence summary of this agent's output]

**Key Findings**:
1. [Finding 1]
2. [Finding 2]
3. [Finding 3]

**Decisions Made**:
- Decision 1: [What and why]
- Decision 2: [What and why]

### Agent-002: [Topic]

**Output**: `agent-002-[topic]/READ-FIRST.md` (multi-file output)
**Tokens**: [token count]
**Summary**: [1-2 sentence summary]

**Key Findings**:
1. [Finding 1]
2. [Finding 2]

**Decisions Made**:
- Decision 1: [What and why]

### Agent-003: [Topic]

[Follow same structure for each agent]

---

## Consolidated Findings

[Synthesize findings from all agents into cohesive insights. This is the most important section for future phases.]

### Finding Category 1

[Group related findings from multiple agents]

**From Agent-001**: [Insight]
**From Agent-002**: [Insight]
**Synthesis**: [Combined conclusion]

### Finding Category 2

[Follow same structure]

---

## Decisions Made

[List all key decisions made during this phase. These should also be added to shared/decisions.md]

### Decision 1: [Decision Title]

**Decision**: [What was decided]
**Rationale**: [Why this was chosen]
**Alternatives Considered**:
- Alternative A: [Why rejected]
- Alternative B: [Why rejected]

**Impact on Next Phases**:
- [How this affects future work]

**Decided By**: [Agent ID or orchestrator]
**Decided At**: [Timestamp]

### Decision 2: [Decision Title]

[Follow same structure]

---

## Questions Resolved

[List questions that were asked and answered during this phase]

### Q1: [Question]

**Asked By**: agent-[id]
**Answer**: [Decision/answer provided]
**Rationale**: [Why this answer]
**Answered By**: orchestrator | user

### Q2: [Question]

[Follow same structure]

---

## Risks and Issues Identified

### High Priority

1. **Risk**: [Description]
   - **Likelihood**: High | Medium | Low
   - **Impact**: High | Medium | Low
   - **Mitigation**: [Recommended approach]
   - **Owner for Next Phase**: [Who should address this]

### Medium Priority

1. **Risk**: [Description]
   [Follow same structure]

### Resolved Issues

1. **Issue**: [What went wrong]
   - **Resolution**: [How it was fixed]
   - **Prevention**: [How to avoid in future]

---

## Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Agents Launched** | [count] | [expected] | ✅ Met |
| **Agents Completed** | [count] | [expected] | ✅ Met |
| **Agents Failed** | [count] | 0 | ✅ None |
| **Total Tokens** | [tokens_used] | [budget] | ✅ Under budget |
| **Duration** | [minutes] | [estimated] | ⚠️ Over estimate |
| **Questions Asked** | [count] | - | - |
| **Decisions Made** | [count] | - | - |

**Budget Analysis**:
- Actual: [total_tokens_used] tokens
- Budget: [token_budget] tokens
- Variance: [+/- percent]%
- Reason for variance: [If over/under by >20%, explain why]

---

## Handoff to Next Phase

### Context for [Next Phase Name]

[What the next phase should know. This is critical for smooth handoff.]

**What's Ready**:
- [Item 1 that's ready for next phase]
- [Item 2 that's ready for next phase]

**What's Needed**:
- [Action item for next phase]
- [Action item for next phase]

**Critical Files to Reference**:
- `archive/[this-phase]-[timestamp]/agent-001-[topic].md` - [Why this is important]
- `archive/[this-phase]-[timestamp]/agent-002-[topic]/schema.json` - [Why this is important]
- `shared/decisions.md` - [Updated with decision 1, 2, 3]

**Recommended Focus**:
1. [Priority 1 for next phase]
2. [Priority 2 for next phase]
3. [Priority 3 for next phase]

---

## Raw Outputs Reference

[Link to all agent outputs for future reference if needed]

All agent outputs preserved in:
```
archive/[this-phase]-[timestamp]/
├── agent-001-[topic].md
├── agent-002-[topic]/
│   ├── READ-FIRST.md
│   ├── [file1]
│   └── [file2]
└── agent-003-[topic].md
```

**Note**: Future phases should read THIS SUMMARY, not the raw outputs, for efficiency. Raw outputs available if deep dive needed.

---

## Lessons Learned

[Observations for improving future phases or workflows]

### What Went Well

1. [Success 1]
   - **Why**: [Reason]
   - **Repeat**: [How to replicate in future phases]

2. [Success 2]
   [Follow same structure]

### What Could Improve

1. [Challenge 1]
   - **Impact**: [How this affected the phase]
   - **Recommendation**: [How to avoid next time]

2. [Challenge 2]
   [Follow same structure]

### Process Improvements

- [Improvement 1]: [How this would help]
- [Improvement 2]: [How this would help]

---

## Timeline

[Visual representation of phase progression]

```
Phase: [This Phase]
Duration: [started_at] → [completed_at] ([duration] minutes)

Milestones:
├─ [started_at]         : Phase started
├─ [agent-1-complete]   : Agent-001 completed [topic]
├─ [question-asked]     : Question about [topic] raised
├─ [question-answered]  : Question answered, work resumed
├─ [agent-2-complete]   : Agent-002 completed [topic]
├─ [agent-3-complete]   : Agent-003 completed [topic]
└─ [completed_at]       : Phase completed

Next Phase: [Next Phase Name]
Estimated Start: [If known]
```

---

## Appendix

### Decision Log Updates

These decisions should be added to `shared/decisions.md`:

```markdown
## [This Phase] Phase Decisions ([Date])

1. **Decision 1**: [Title]
   - Decided: [What]
   - Rationale: [Why]

2. **Decision 2**: [Title]
   - Decided: [What]
   - Rationale: [Why]
```

### Glossary Updates

These terms should be added to `shared/glossary.md` (if applicable):

- **Term 1**: [Definition discovered/refined in this phase]
- **Term 2**: [Definition discovered/refined in this phase]

### Architecture Decision Records

If ADRs are used in this project, create:

```
docs/adr/
├── 0001-decision-from-this-phase.md
└── 0002-another-decision.md
```

---

## Summary Statistics

**Phase**: [This Phase]
**Workflow**: [workflow_id]
**Status**: ✅ Archived
**Archived**: [archived_at]

**Agents**: [count] total ([completed] completed, [failed] failed)
**Tokens**: [total_tokens_used] used / [token_budget] budgeted ([percent]%)
**Duration**: [duration_minutes] minutes

**Key Outputs**: [count] files created
**Decisions**: [count] decisions made
**Questions**: [count] questions resolved

---

## Template Notes

**For Cleanup Agents**: When creating this summary:
1. Read all agent outputs in `active/[this-phase]/`
2. Read `STATUS.yaml` for metrics
3. Synthesize findings (don't just copy/paste entire outputs)
4. Focus on what NEXT PHASE needs to know
5. Keep summary under 3000 tokens if possible

**For Future Agents**: When reading this summary:
1. Start with "Overview" and "Handoff to Next Phase" sections
2. Review "Consolidated Findings" for key insights
3. Check "Decisions Made" for constraints
4. Reference raw outputs only if you need specific details

---

**Phase Summary Version**: 1.0.0
**Created By**: [Cleanup agent ID]
**Last Updated**: [archived_at]
