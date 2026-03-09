# Orchestrator Guide: Managing Multi-Agent Workflows

## Table of Contents

1. [Overview](#overview)
2. [Initialization](#initialization)
3. [Launching Sub-Agents](#launching-sub-agents)
4. [Monitoring Progress](#monitoring-progress)
5. [Handling Input Requests](#handling-input-requests)
6. [Phase Transitions](#phase-transitions)
7. [Archival Process](#archival-process)
8. [Workflow Resumption](#workflow-resumption)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Overview

As an orchestrator, you coordinate multiple sub-agents across workflow phases while maintaining minimal context in your main thread. This guide provides step-by-step workflows for all orchestration tasks.

**Key Responsibilities**:
- Initialize workflow structure
- Launch sub-agents with appropriate context
- Monitor phase progress via STATUS.yaml
- Provide input when sub-agents are blocked
- Trigger phase transitions and archival
- Maintain workflow-state.yaml

**Context Budget**: Aim to keep your main thread under 10K tokens by:
- Reading only phase summaries, not raw agent outputs
- Using sub-agents for research and analysis
- Archiving completed phases promptly

---

## Initialization

### Step 1: Create Workflow ID

Choose a unique, descriptive workflow ID:

```bash
# Format: {feature/task}-{date} or {feature/task}-{branch}
WORKFLOW_ID="feature-auth-20251124"
# or
WORKFLOW_ID="refactor-api-v2"
# or
WORKFLOW_ID="migrate-postgres"
```

**Best Practices**:
- ✅ Include feature/task name for clarity
- ✅ Include date or version for uniqueness
- ✅ Use lowercase with hyphens (kebab-case)
- ❌ Avoid generic names like "workflow1"

### Step 2: Create Directory Structure

```bash
# Create base structure
mkdir -p .development/workflows/${WORKFLOW_ID}/{active,archive,shared}

# Create phase folders (use subset as needed)
mkdir -p .development/workflows/${WORKFLOW_ID}/active/{planning,research,design,execution,review}
```

**Minimal Setup** (if you don't need all phases):
```bash
# Example: Only planning and execution
mkdir -p .development/workflows/${WORKFLOW_ID}/active/{planning,execution}
```

### Step 3: Initialize State File

```bash
# Copy template
cp templates/workflow-state.yaml \
   .development/workflows/${WORKFLOW_ID}/workflow-state.yaml

# Update with your workflow details
```

**Edit workflow-state.yaml**:
```yaml
workflow_id: feature-auth-20251124
workflow_name: Implement Authentication System
created_at: 2025-11-24T10:00:00Z
updated_at: 2025-11-24T10:00:00Z
status: planning

current_phase:
  name: planning
  started_at: 2025-11-24T10:00:00Z
  estimated_completion: null
  progress_percent: 0

# Keep default values for other fields
```

### Step 4: Create Phase README Files

For each phase you're using:

```bash
# Copy template for each phase
cp templates/phase-readme.md \
   .development/workflows/${WORKFLOW_ID}/active/planning/README.md

# Repeat for other phases
```

**Customize each phase README.md**:
```yaml
---
phase: planning  # Update this
purpose: Establish requirements and architectural foundations  # Update this
created_at: 2025-11-24T10:00:00Z
inputs_from_phases: []  # Empty for planning, list prior phases for others
expected_outputs: [requirements.md, architecture-decisions.md]  # Customize
token_budget: 50000
sub_agents_expected: 2-3  # Your estimate
---

# Planning Phase

## Objective

[Customize with specific objectives for YOUR workflow]
```

### Step 5: Create Phase STATUS Files

```bash
# Copy template for each phase
cp templates/status.yaml \
   .development/workflows/${WORKFLOW_ID}/active/planning/STATUS.yaml
```

**Update STATUS.yaml**:
```yaml
phase: planning  # Update this
status: pending  # Start as pending
last_updated: 2025-11-24T10:00:00Z
started_at: null
completed_at: null
# Keep defaults for other fields
```

### Step 6: Create Shared Context (Optional)

```bash
# Create initial context files if helpful
touch .development/workflows/${WORKFLOW_ID}/shared/decisions.md
touch .development/workflows/${WORKFLOW_ID}/shared/glossary.md
```

**decisions.md template**:
```markdown
# Architectural Decisions

## [Date] - [Phase]

### Decision: [Title]
- **What**: [What was decided]
- **Why**: [Rationale]
- **Alternatives**: [What was considered and rejected]
- **Impact**: [How this affects the project]
```

---

## Launching Sub-Agents

### Basic Launch Pattern

```javascript
Task({
  subagent_type: "Plan",  // or "Explore", "general-purpose"
  description: "Brief description for task list",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `
You are working within orchestrated workflow: ${WORKFLOW_ID}

**Context from Previous Work**:
${context_summary}

**Your Task**:
${specific_task_description}

**Output Requirements**:
- Location: .development/workflows/${WORKFLOW_ID}/active/${PHASE}/
- Filename: agent-{your-id}-${TOPIC}.md
- Format: Follow template at templates/agent-output.md
- Update: STATUS.yaml when complete

**Phase Instructions**:
Read: .development/workflows/${WORKFLOW_ID}/active/${PHASE}/README.md

**Communication Protocol**:
When finished, return JSON:
{
  "status": "finished | needs-input | failed",
  "output_paths": ["active/${PHASE}/agent-{id}-${TOPIC}.md"],
  "questions": [],
  "summary": "Brief summary (2-3 sentences)",
  "tokens_used": [estimate],
  "next_phase_context": "What next phase should know"
}
  `
})
```

### Providing Context to Sub-Agents

**For First Agent in Workflow**:
```javascript
const context_summary = `
No previous agent outputs (you're first!).

Project background:
- [Brief description of project]
- [Key constraints or requirements]

Reference project documentation:
- README.md or CLAUDE.md for project context
- [Any other relevant docs]
`;
```

**For Subsequent Agents (Same Phase)**:
```javascript
// Read previous agent output summaries
const agent001Summary = await readFile(
  `.development/workflows/${WORKFLOW_ID}/active/planning/agent-001-requirements.md`
);

const context_summary = `
Previous agents in this phase:

**Agent-001 (Requirements)**:
${extractSummarySection(agent001Summary)}

Key findings:
- [Extract 3-5 key points]

Your work should build on these findings.
`;
```

**For Agents in Later Phases**:
```javascript
// Read ONLY phase summaries from archive, not raw outputs
const planningSummary = await readFile(
  `.development/workflows/${WORKFLOW_ID}/archive/planning-20251124T1430/phase-summary.md`
);

const researchSummary = await readFile(
  `.development/workflows/${WORKFLOW_ID}/archive/research-20251124T1545/phase-summary.md`
);

const context_summary = `
Context from completed phases:

**Planning Phase** (archived):
${extractKeyDecisions(planningSummary)}

**Research Phase** (archived):
${extractKeyFindings(researchSummary)}

Critical files to reference:
- archive/planning-20251124T1430/phase-summary.md
- archive/research-20251124T1545/phase-summary.md

Your task builds on these foundations.
`;
```

### Parallel Agent Launch

When launching multiple agents simultaneously:

```javascript
// Launch all agents in parallel (single message, multiple Task calls)
Task({
  subagent_type: "Plan",
  description: "Research authentication patterns",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `[Agent 1 prompt with topic: auth-patterns]`
});

Task({
  subagent_type: "Plan",
  description: "Research security best practices",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `[Agent 2 prompt with topic: security-practices]`
});

Task({
  subagent_type: "Plan",
  description: "Research session management",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `[Agent 3 prompt with topic: session-management]`
});

// All three agents run simultaneously
// Each writes to: agent-{id}-{unique-topic}.md
```

**Coordination**:
- Ensure each agent has unique topic (prevents filename conflicts)
- Give each agent independent scope (no dependencies between them)
- Update STATUS.yaml after all agents launch (add to active_agents)

---

## Monitoring Progress

### Check Phase Status

```bash
# Quick status check
cat .development/workflows/${WORKFLOW_ID}/active/${PHASE}/STATUS.yaml
```

**Look for**:
```yaml
status: in-progress | needs-input | completed | failed
active_agents:
  - id: agent-abc123
    status: in-progress  # Still working
  - id: agent-def456
    status: completed    # Done
questions_pending: []    # Any questions?
blockers: []             # Any blockers?
```

### Check for Signal Files

```bash
# Check if input needed
ls .development/workflows/${WORKFLOW_ID}/active/${PHASE}/NEEDS-INPUT.md 2>/dev/null

# Check if blocked
ls .development/workflows/${WORKFLOW_ID}/active/${PHASE}/BLOCKED.md 2>/dev/null

# Check if completed
ls .development/workflows/${WORKFLOW_ID}/active/${PHASE}/COMPLETED.md 2>/dev/null
```

**Signal file exists = action required**

### Monitor Workflow State

```bash
# Check overall workflow status
cat .development/workflows/${WORKFLOW_ID}/workflow-state.yaml
```

**Key metrics**:
```yaml
current_phase:
  name: research
  progress_percent: 60  # 60% complete

metrics:
  total_agents_launched: 5
  total_tokens_used: 87500

questions_pending: 1  # Need to answer
```

### Update Workflow State After Agent Completes

When agent returns completion JSON:

```yaml
# Add to completed_agents
completed_agents:
  - id: agent-abc123
    phase: planning
    topic: requirements
    started_at: 2025-11-24T10:15:00Z
    completed_at: 2025-11-24T10:45:00Z
    tokens_used: 12500
    output_paths:
      - active/planning/agent-abc123-requirements.md

# Update metrics
metrics:
  total_agents_launched: 3
  total_tokens_used: 37500  # Cumulative

# Update phase status
phases:
  planning:
    status: in-progress
    agents_used: [agent-abc123, agent-def456]
    tokens_used: 25000
```

---

## Handling Input Requests

### When Agent Signals needs-input

**Detection**:
```yaml
# In STATUS.yaml
status: needs-input
questions_pending:
  - question: "Should we use REST or GraphQL?"
    asked_by: agent-def456
    priority: high
    blocking: true
```

**Or signal file exists**:
```bash
ls .development/workflows/${WORKFLOW_ID}/active/planning/NEEDS-INPUT.md
# File exists = input needed
```

### Step 1: Read Questions

```bash
# Read STATUS.yaml for questions
cat .development/workflows/${WORKFLOW_ID}/active/planning/STATUS.yaml | grep -A 10 "questions_pending"
```

**Parse question details**:
```yaml
questions_pending:
  - question: "Should we use REST or GraphQL?"
    asked_by: agent-def456
    asked_at: 2025-11-24T11:00:00Z
    priority: high
    blocking: true
    context: "Both viable, REST simpler, GraphQL more flexible"
    options: [REST, GraphQL, Both]
    recommendation: REST
```

### Step 2: Decide Answer

**Option A: You can decide** (based on your knowledge):
```javascript
const answer = "REST";
const rationale = "Team has more REST experience, simpler for this use case";
```

**Option B: Ask user** (if you need input):
```javascript
AskUserQuestion({
  questions: [{
    question: "Should we use REST or GraphQL for the API?",
    header: "API Style",
    multiSelect: false,
    options: [
      {
        label: "REST",
        description: "Simpler, team has experience, adequate for use case"
      },
      {
        label: "GraphQL",
        description: "More flexible, better for complex queries, steeper learning curve"
      }
    ]
  }]
});

// User answers, store result
const answer = userAnswer; // From AskUserQuestion result
const rationale = "User preference based on team capabilities";
```

### Step 3: Update STATUS.yaml

```yaml
# Move from questions_pending to questions_resolved
questions_pending: []  # Clear

questions_resolved:
  - question: "Should we use REST or GraphQL?"
    answer: "REST"
    rationale: "Team has more REST experience, simpler for this use case"
    answered_by: orchestrator
    answered_at: 2025-11-24T11:15:00Z
    asked_by: agent-def456

# Update status
status: in-progress  # Resume from needs-input
```

### Step 4: Continue Agent with Answer

```javascript
// Launch continuation agent (or resume blocked agent)
Task({
  subagent_type: "Plan",
  description: "Continue with API design (REST)",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `
Continue your API design work.

**Question Answered**:
Q: "Should we use REST or GraphQL?"
A: "REST"
Rationale: ${rationale}

**Your Task**:
Proceed with REST API design based on this decision.

[Include same context and protocol as original agent launch]
  `
});
```

### Step 5: Remove Signal File

```bash
# Remove NEEDS-INPUT.md once resolved
rm .development/workflows/${WORKFLOW_ID}/active/planning/NEEDS-INPUT.md
```

---

## Phase Transitions

### When to Transition

**Criteria**:
- ✅ All agents in phase completed
- ✅ No questions pending
- ✅ No blockers
- ✅ Outputs validated (you've reviewed them)
- ✅ Success criteria met (from phase README.md)

**Check STATUS.yaml**:
```yaml
status: completed
active_agents: []
completed_agents: [agent-001, agent-002, agent-003]
questions_pending: []
blockers: []
completion_criteria:
  all_agents_finished: true
  no_questions_pending: true
  no_critical_blockers: true
  outputs_validated: true  # You set this after review
  within_token_budget: true
```

### Step 1: Validate Outputs

Review agent outputs for quality:

```bash
# Read agent output summaries
cat .development/workflows/${WORKFLOW_ID}/active/planning/agent-001-requirements.md | head -50

# Check if objectives met (from phase README.md)
cat .development/workflows/${WORKFLOW_ID}/active/planning/README.md
```

**Validation Checklist**:
- [ ] All expected outputs created?
- [ ] Outputs complete and high quality?
- [ ] Decisions clearly documented?
- [ ] Next phase has clear context?
- [ ] No critical gaps or errors?

### Step 2: Update STATUS.yaml

```yaml
status: completed
completed_at: 2025-11-24T14:30:00Z
completion_criteria:
  outputs_validated: true  # You just validated
```

### Step 3: Create Signal File

```bash
# Create COMPLETED.md
echo "# Phase Complete

All agents finished successfully.

**Agents Completed**: 3
**Total Tokens**: 42000

Ready for archival." > .development/workflows/${WORKFLOW_ID}/active/planning/COMPLETED.md
```

---

## Archival Process

### Launch Cleanup Agent

```javascript
Task({
  subagent_type: "general-purpose",
  description: "Archive planning phase",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `
Archive the planning phase for workflow: ${WORKFLOW_ID}

**Your Task**:
1. Create timestamp: $(date +"%Y%m%dT%H%M")
2. Create archive folder: .development/workflows/${WORKFLOW_ID}/archive/planning-{timestamp}/
3. Move all files from active/planning/ to archive/planning-{timestamp}/
4. Create phase-summary.md synthesizing all agent outputs
5. Update workflow-state.yaml with archival timestamp

**Phase Summary Requirements**:
- Read all agent outputs in active/planning/
- Read STATUS.yaml for metrics
- Use template: templates/phase-summary.md
- Synthesize findings (don't copy/paste entire outputs)
- Focus on what NEXT PHASE needs to know
- Keep under 3000 tokens

**Workflow State Updates**:
In workflow-state.yaml:
- Set phases.planning.status = "completed"
- Set phases.planning.archived_at = {timestamp}
- Update metrics.total_phases_completed += 1

Return JSON with archival confirmation.
  `
});
```

### Post-Archival Updates

After cleanup agent completes:

**Update workflow-state.yaml**:
```yaml
current_phase:
  name: research  # Next phase
  started_at: 2025-11-24T14:45:00Z
  progress_percent: 0

phases:
  planning:
    status: completed
    completed_at: 2025-11-24T14:30:00Z
    archived_at: 2025-11-24T14:35:00Z
    agents_used: [agent-001, agent-002, agent-003]
    tokens_used: 42000

  research:
    status: in-progress
    started_at: 2025-11-24T14:45:00Z
```

**Update shared/decisions.md** (if applicable):
```markdown
## Planning Phase Decisions (2025-11-24)

1. **Use REST API**
   - Rationale: Team experience, adequate for use case
   - Source: archive/planning-20251124T1430/phase-summary.md

2. **PostgreSQL Database**
   - Rationale: Relational model, ACID guarantees
   - Source: archive/planning-20251124T1430/agent-002-architecture.md
```

### Verify Archival

```bash
# Check archive created
ls .development/workflows/${WORKFLOW_ID}/archive/

# Verify phase-summary.md exists
cat .development/workflows/${WORKFLOW_ID}/archive/planning-20251124T1430/phase-summary.md | head -30

# Verify active/planning/ is now empty or removed
ls .development/workflows/${WORKFLOW_ID}/active/planning/
```

---

## Workflow Resumption

### After Interruption

If workflow was interrupted (system restart, error, etc.):

**Step 1: Read Workflow State**
```bash
cat .development/workflows/${WORKFLOW_ID}/workflow-state.yaml
```

**Determine current state**:
```yaml
current_phase:
  name: research
  started_at: 2025-11-24T14:45:00Z
  progress_percent: 30

active_agents:
  - id: agent-ghi789
    phase: research
    status: in-progress  # Was working when interrupted
```

**Step 2: Check Agent Status**

```bash
# Did agent complete before interruption?
cat .development/workflows/${WORKFLOW_ID}/active/research/STATUS.yaml
```

**If agent completed**:
```yaml
completed_agents:
  - id: agent-ghi789
    status: completed
    # Agent finished, update workflow-state.yaml
```

**If agent didn't complete**:
```yaml
active_agents:
  - id: agent-ghi789
    status: in-progress
    # No output file exists - agent didn't finish
```

**Step 3: Resume or Restart**

**If agent completed while you were gone**:
```javascript
// Just update workflow-state.yaml, continue with next agent
```

**If agent didn't complete**:
```javascript
// Relaunch agent with same prompt
Task({
  subagent_type: "Plan",
  description: "Research API patterns (retry)",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `[Same prompt as before]`
});
```

---

## Best Practices

### Context Management

**DO**:
- ✅ Read only phase-summary.md from archives, not raw agent outputs
- ✅ Pass only essential context to sub-agents (summaries, not full outputs)
- ✅ Archive phases promptly after completion
- ✅ Keep your main thread under 10K tokens

**DON'T**:
- ❌ Load all agent outputs into your context
- ❌ Pass massive context blobs to sub-agents
- ❌ Read archived raw files (use summaries)
- ❌ Let completed phases linger in active/

### Agent Coordination

**DO**:
- ✅ Give each agent clear, specific scope
- ✅ Use unique topics to prevent filename conflicts
- ✅ Update STATUS.yaml after every agent launch/completion
- ✅ Monitor token budgets (warn if >80% used)

**DON'T**:
- ❌ Launch agents with overlapping scopes
- ❌ Use generic topics (causes filename collisions)
- ❌ Forget to update workflow-state.yaml
- ❌ Ignore token budget overruns

### Question Handling

**DO**:
- ✅ Answer promptly (blocked agents waste time)
- ✅ Use AskUserQuestion for user decisions
- ✅ Document rationale for all decisions
- ✅ Update shared/decisions.md with key decisions

**DON'T**:
- ❌ Delay answering questions
- ❌ Guess at user preferences
- ❌ Fail to document why you decided something
- ❌ Let decisions be buried in agent outputs

### Workflow Hygiene

**DO**:
- ✅ Use descriptive workflow IDs
- ✅ Keep workflow-state.yaml updated
- ✅ Archive completed phases
- ✅ Document key decisions in shared/

**DON'T**:
- ❌ Use generic IDs (workflow1, test, etc.)
- ❌ Let workflow-state.yaml get stale
- ❌ Accumulate completed phases in active/
- ❌ Lose track of decisions made

---

## Troubleshooting

### "MCP tools not available in sub-agent"

**Cause**: Agent was launched with `run_in_background: true` (default or inferred)
**Impact**: Sub-agents cannot access MCP tools (Groove, Jira, Google Drive, etc.)
**Fix**:
```javascript
// Always set run_in_background: false for MCP access
Task({
  subagent_type: "general-purpose",
  description: "Task requiring MCP",
  run_in_background: false,  // CRITICAL: Required for MCP tool access
  prompt: `...`
});
```

**Background**: Background agents in Claude Code cannot access MCP tools. This is a platform limitation. All Task examples in this guide include `run_in_background: false` to ensure MCP access.

### "Agent outputs missing after launch"

**Cause**: Agent failed silently or hasn't finished yet
**Fix**:
```bash
# Check if agent is still running (may take time)
# Check for error messages in agent output
# If no output after reasonable time, agent failed - relaunch
```

### "STATUS.yaml shows needs-input but no questions"

**Cause**: Agent updated status but forgot to add questions
**Fix**:
```bash
# Read agent output directly for context
cat .development/workflows/${WORKFLOW_ID}/active/${PHASE}/agent-${ID}-${TOPIC}.md

# Look for questions in agent output
# Manually add to STATUS.yaml:
questions_pending:
  - question: "[extracted from agent output]"
    asked_by: agent-${ID}
```

### "Filename collision in parallel agents"

**Cause**: Two agents used same topic name
**Fix**:
```bash
# Rename one agent's output:
mv agent-abc-auth.md agent-abc-auth-patterns.md

# Update STATUS.yaml with corrected path
# For future: give agents unique topics
```

### "Token budget exceeded significantly"

**Cause**: Agents used more tokens than budgeted
**Fix**:
```yaml
# In STATUS.yaml, add note:
notes:
  - "Token budget exceeded by 40% due to complex requirements analysis"
  - "Future phases: increase budget or narrow scope"

# Adjust future phase budgets accordingly
```

### "Can't find archived phase"

**Cause**: Archival didn't complete or wrong timestamp
**Fix**:
```bash
# List archive folder
ls .development/workflows/${WORKFLOW_ID}/archive/

# Find phase with timestamp
# Update context_files paths in agent prompts with correct timestamp
```

### "Workflow state out of sync with reality"

**Cause**: Forgot to update workflow-state.yaml after changes
**Fix**:
```bash
# Manually audit:
# 1. Check what's actually in active/ and archive/
# 2. Update workflow-state.yaml to match reality
# 3. Document discrepancy in notes

# Prevention: update workflow-state.yaml immediately after every change
```

---

## Workflow State Management Checklist

Use this checklist to ensure workflow-state.yaml stays current:

**After agent launches**:
- [ ] Add to active_agents with id, phase, topic, started_at
- [ ] Increment metrics.agents_launched

**After agent completes**:
- [ ] Move from active_agents to completed_agents
- [ ] Add tokens_used and output_paths
- [ ] Update metrics.total_tokens_used
- [ ] Update phases.{phase}.tokens_used

**After question asked**:
- [ ] Add to questions_pending
- [ ] Update current_phase.progress_percent if blocked

**After question answered**:
- [ ] Move from questions_pending to questions_resolved
- [ ] Add answer, rationale, answered_by

**After phase completes**:
- [ ] Update phases.{phase}.status = "completed"
- [ ] Set phases.{phase}.completed_at
- [ ] Update current_phase to next phase
- [ ] Increment metrics.total_phases_completed

**After phase archived**:
- [ ] Set phases.{phase}.archived_at
- [ ] Verify archive folder exists

---

**Orchestrator Guide Version**: 1.0.0
**Last Updated**: 2025-11-24

**Next**: See `subagent-guide.md` for sub-agent perspective, or `examples/` for complete workflow examples.
