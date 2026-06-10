---
phase: REPLACE_WITH_PHASE_NAME  # planning | research | design | execution | review
purpose: REPLACE_WITH_PURPOSE    # Brief description of phase objective
created_at: REPLACE_WITH_TIMESTAMP
inputs_from_phases: []           # List phases this phase depends on, e.g., [planning, research]
expected_outputs: []             # List expected output types, e.g., [requirements.md, architecture-decisions.md]
token_budget: 50000             # Recommended token budget for entire phase
sub_agents_expected: 2-4         # Estimated number of agents needed
---

# [Phase Name] Phase

## Objective

[1-2 sentences describing what this phase aims to accomplish]

Example: "Establish clear requirements and architectural foundations before implementation. Analyze user needs, technical constraints, and define success criteria."

---

## Prerequisites

### Context Required

Before working in this phase, read:

- **From Previous Phases**:
  - `archive/[previous-phase]-[timestamp]/phase-summary.md` - Summary of [previous phase]
  - `shared/decisions.md` - Key architectural decisions
  - `shared/glossary.md` - Domain terminology

- **Project Context**:
  - Project README or CLAUDE.md for project background
  - Relevant codebase documentation

### Tools and Access

- [ ] Read access to codebase
- [ ] Write access to `.development/workflows/{workflow-id}/active/[this-phase]/`
- [ ] Tool permissions: Read, Write, Edit, Grep, Glob
- [ ] (Optional) External tools: [List any MCP servers, databases, etc.]

---

## Instructions for Sub-Agents

### What You Should Do

1. **Read Context**: Load all files from `context_files` parameter in your invocation
2. **Understand Scope**: Review this README.md and phase objectives
3. **Execute Task**: Perform your assigned work (specified in continuation_prompt)
4. **Write Outputs**: Create files in `output_location` following naming conventions
5. **Update Status**: Modify `STATUS.yaml` to reflect your current state
6. **Signal Completion**: Return JSON with status, output_paths, questions, and summary

### Output Naming Conventions

**Single-file output:**
```
.development/workflows/{workflow-id}/active/[this-phase]/agent-{id}-{topic}.md
```

Example: `agent-001-requirements.md`

**Multi-file output:**
```
.development/workflows/{workflow-id}/active/[this-phase]/agent-{id}-{topic}/
├── READ-FIRST.md      # Explains folder contents
├── [output-file-1]
└── [output-file-2]
```

Example:
```
agent-005-data-model/
├── READ-FIRST.md
├── schema.json
└── migrations.md
```

### File Format Guidelines

- **Markdown** (.md): Primary format for documentation, analysis, summaries
- **YAML** (.yaml): Metadata, configurations, structured decisions
- **JSON** (.json): Schemas, API specifications, structured data

All markdown files should include YAML frontmatter:

```yaml
---
phase: [this-phase]
author_agent: agent-{id}
created_at: YYYY-MM-DDTHH:MM:SSZ
topic: [brief-topic-description]
status: completed | in-progress
---

# Content starts here...
```

---

## Expected Outputs

This phase should produce:

1. **[Output Type 1]**: [Description]
   - Format: [markdown | JSON | YAML]
   - Example: `agent-001-requirements.md` containing user requirements analysis

2. **[Output Type 2]**: [Description]
   - Format: [markdown | JSON | YAML]
   - Example: `agent-002-architecture/READ-FIRST.md` explaining architectural decisions

3. **[Output Type 3]**: [Description]
   - Format: [markdown | JSON | YAML]
   - Example: `agent-003-constraints.yaml` listing technical constraints

### Quality Criteria

Outputs should be:
- ✅ **Complete**: Address all aspects of the assigned task
- ✅ **Concise**: Focus on essential information, avoid verbosity
- ✅ **Structured**: Use headers, lists, tables for scanability
- ✅ **Referenced**: Include file paths and line numbers for code references
- ✅ **Token-Efficient**: Aim for 1000-3000 tokens per output file

---

## Boundaries and Constraints

### What You CAN Do

- ✅ Read files from previous phases (via context_files)
- ✅ Write outputs to `active/[this-phase]/`
- ✅ Update `STATUS.yaml` in this phase
- ✅ Create NEEDS-INPUT.md if you need orchestrator input
- ✅ Reference files in `shared/` folder
- ✅ Ask questions via return JSON

### What You CANNOT Do

- ❌ Modify files in archived phases (they're historical)
- ❌ Write to other phases' folders
- ❌ Change `workflow-state.yaml` (orchestrator manages this)
- ❌ Launch other sub-agents directly (request via return JSON questions)
- ❌ Skip updating STATUS.yaml (orchestrator relies on it)

---

## STATUS.yaml Updates

Update `STATUS.yaml` when:
1. You start work (`status: in-progress`)
2. You complete work (`status: completed`)
3. You need input (`status: needs-input`)
4. You encounter errors (`status: failed`)

**Format:**

```yaml
active_agents:
  - id: agent-{your-id}
    topic: {your-topic}
    status: in-progress | completed | needs-input | failed
    started_at: YYYY-MM-DDTHH:MM:SSZ
    updated_at: YYYY-MM-DDTHH:MM:SSZ
```

---

## Signaling Completion

When finished, return this JSON structure in your final message:

```json
{
  "status": "finished",
  "output_paths": [
    "active/[this-phase]/agent-{id}-{topic}.md",
    "active/[this-phase]/agent-{id}-{topic}/READ-FIRST.md"
  ],
  "questions": [],
  "summary": "Brief summary of what was accomplished (2-3 sentences)",
  "tokens_used": 18750,
  "next_phase_context": "What the next phase should know about your outputs"
}
```

**Status Values:**
- `"finished"` - Work complete, no blockers
- `"needs-input"` - Require orchestrator/user decision (populate `questions` array)
- `"failed"` - Encountered unresolvable error

**Questions Format** (if status is "needs-input"):

```json
{
  "status": "needs-input",
  "questions": [
    {
      "question": "Should we use REST or GraphQL for the API?",
      "context": "Both are viable, but REST is simpler while GraphQL offers flexibility",
      "options": ["REST", "GraphQL", "Both"],
      "recommendation": "REST",
      "blocking": true
    }
  ],
  ...
}
```

---

## Common Patterns for This Phase

### [Pattern 1 Name]

**When to use**: [Description of scenario]

**Example**:
```
[Show example output or code snippet]
```

**Rationale**: [Why this pattern works for this phase]

### [Pattern 2 Name]

**When to use**: [Description of scenario]

**Example**:
```
[Show example output or code snippet]
```

**Rationale**: [Why this pattern works for this phase]

---

## Success Criteria

This phase is considered successful when:

- [ ] All expected outputs created with proper naming
- [ ] STATUS.yaml shows all agents `status: completed`
- [ ] No questions pending (or all questions have answers)
- [ ] Token budget not exceeded significantly (<20% over is acceptable)
- [ ] Outputs meet quality criteria (complete, concise, structured)
- [ ] Next phase has clear context (next_phase_context provided)

---

## Phase Transition

Once all agents in this phase complete:

1. **Orchestrator reviews** all outputs
2. **Orchestrator validates** success criteria met
3. **Orchestrator launches cleanup agent** to archive this phase
4. **Cleanup agent creates** `phase-summary.md` synthesizing all outputs
5. **Orchestrator moves** to next phase (updates workflow-state.yaml)

---

## Troubleshooting

**Issue**: "Cannot find context files"
- **Fix**: Check that previous phases are archived and paths in context_files are correct

**Issue**: "Output path invalid"
- **Fix**: Ensure output_location matches `.development/workflows/{workflow-id}/active/[this-phase]/`

**Issue**: "STATUS.yaml not updating"
- **Fix**: Use Write or Edit tool to modify STATUS.yaml, don't just return it in your message

**Issue**: "Running out of tokens"
- **Fix**: Focus on essential information only. Consider breaking work into smaller sub-tasks.

---

## Template Notes

**For Orchestrators**: Customize this template for each phase with specific:
- Objectives relevant to the phase
- Expected outputs tailored to the work
- Success criteria specific to phase goals
- Common patterns observed in similar phases

**For Sub-Agents**: Treat this README.md as your "mission brief" - read it carefully before starting work.

---

**Phase README Version**: 1.0.0
**Last Updated**: REPLACE_WITH_TIMESTAMP
