# Archival Process Reference Guide

## Overview

### What is Archival?

Archival is the process of moving a completed phase from `active/` to `archive/` with a timestamped snapshot, generating a synthesized phase summary, and updating workflow state to reflect completion.

**Why Archival is Important**:
- **Context Efficiency**: Future agents read concise summaries (2000-3000 tokens) instead of raw outputs (20K+ tokens)
- **Historical Record**: Preserves complete work with timestamp for auditing and rollback
- **Clean Workspace**: Keeps `active/` folder focused on current work only
- **State Tracking**: Marks clear progression through workflow phases

### When to Trigger Archival

Archival should occur when ALL of these criteria are met:

- ✅ **All agents in phase completed** - No agents with status `in-progress` or `failed`
- ✅ **No questions pending** - All `questions_pending` resolved
- ✅ **No active blockers** - No `BLOCKED.md` files exist
- ✅ **Outputs validated** - Orchestrator has reviewed agent outputs for quality
- ✅ **Success criteria met** - Phase objectives (from README.md) achieved

**Check before archival**:
```bash
# Verify phase completion
cat .development/workflows/{workflow-id}/active/{phase}/STATUS.yaml

# Should show:
# status: completed
# active_agents: []
# questions_pending: []
# blockers: []
```

### Who Performs Archival?

**Cleanup Agent** (sub-agent):
- Launched by orchestrator when phase complete
- Responsible for moving files, generating summary, updating state
- Uses `subagent_type: "general-purpose"`

**Orchestrator** (you):
- Validates phase completion before archival
- Launches cleanup agent with detailed instructions
- Updates workflow-state.yaml after archival
- Transitions to next phase

---

## Prerequisites

### Completion Criteria Checklist

Before archival, verify:

**Phase Status**:
- [ ] `STATUS.yaml` shows `status: completed`
- [ ] `completed_at` timestamp is set
- [ ] All agents transitioned from `active_agents` to `completed_agents`
- [ ] No `NEEDS-INPUT.md` or `BLOCKED.md` signal files exist

**Agent Outputs**:
- [ ] All expected outputs created (check against phase README.md)
- [ ] Output files follow naming conventions (`agent-{id}-{topic}.md`)
- [ ] Multi-file outputs have `READ-FIRST.md` index files
- [ ] No placeholder content (all work actually complete)

**Questions and Decisions**:
- [ ] `questions_pending: []` (empty)
- [ ] All questions moved to `questions_resolved`
- [ ] Key decisions documented (ready for shared/decisions.md)

**Token Budget**:
- [ ] `token_budget_used` within acceptable range (<150% of budget)
- [ ] If over budget, reason documented in `notes`

### Validation Steps Before Archival

**Step 1: Read Phase STATUS.yaml**
```bash
cat .development/workflows/{workflow-id}/active/{phase}/STATUS.yaml
```

Verify all completion criteria in YAML.

**Step 2: Review Agent Outputs**
```bash
# List all outputs
ls .development/workflows/{workflow-id}/active/{phase}/

# Quick review of each agent output (summary sections)
cat .development/workflows/{workflow-id}/active/{phase}/agent-001-*.md | head -50
```

**Step 3: Check Phase Objectives**
```bash
# Read phase README.md to confirm objectives met
cat .development/workflows/{workflow-id}/active/{phase}/README.md
```

Compare expected outputs with actual outputs created.

**Step 4: Verify No Signal Files**
```bash
# Should return nothing (no files found)
ls .development/workflows/{workflow-id}/active/{phase}/NEEDS-INPUT.md 2>/dev/null
ls .development/workflows/{workflow-id}/active/{phase}/BLOCKED.md 2>/dev/null
```

### What to Check in STATUS.yaml

**Required fields for archival readiness**:
```yaml
phase: planning
status: completed  # Must be "completed"
completed_at: 2025-11-24T14:30:00Z  # Must be set

active_agents: []  # Must be empty
completed_agents:  # All agents should be here
  - id: agent-001
    status: completed
  - id: agent-002
    status: completed

questions_pending: []  # Must be empty
questions_resolved:    # Moved from pending
  - question: "..."
    answer: "..."

blockers: []  # Must be empty

completion_criteria:
  all_agents_finished: true
  no_questions_pending: true
  no_critical_blockers: true
  outputs_validated: true  # Orchestrator sets this
  within_token_budget: true
```

---

## Step-by-Step Process

### Step 1: Create Timestamp

```bash
# Generate ISO 8601 timestamp
TIMESTAMP=$(date -u +"%Y%m%dT%H%M")
# Example: 20251124T1430

# Or if cleanup agent uses date command:
# TIMESTAMP="20251124T1430"
```

**Timestamp Format**: `YYYYMMDDTHHmm` (UTC)
- Example: `20251124T1430` = November 24, 2025 at 14:30 UTC

### Step 2: Create Archive Folder Structure

```bash
# Create archive directory with timestamp
mkdir -p .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/

# Example:
# .development/workflows/feature-auth-20251124/archive/planning-20251124T1430/
```

### Step 3: Move Files from active/ to archive/

```bash
# Move all files from active phase to archive
mv .development/workflows/{workflow-id}/active/{phase}/* \
   .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/

# Or if preserving active/ directory structure:
cp -r .development/workflows/{workflow-id}/active/{phase}/* \
      .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/
rm -rf .development/workflows/{workflow-id}/active/{phase}/*
```

**What gets moved**:
- All `agent-*.md` files
- All `agent-*/` folders (multi-file outputs)
- `STATUS.yaml`
- `README.md` (phase instructions)
- Any signal files (COMPLETED.md, etc.)

**What does NOT get moved**:
- Nothing (entire phase folder contents archived)

### Step 4: Generate phase-summary.md

**Location**: `.development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/phase-summary.md`

**Process**:
1. Read all agent outputs from archive folder
2. Read STATUS.yaml for metrics
3. Use template: `templates/phase-summary.md`
4. Synthesize findings (see "Phase Summary Generation" section below)
5. Write summary to archive folder

**Template location**:
```bash
templates/phase-summary.md
```

### Step 5: Update workflow-state.yaml

**Location**: `.development/workflows/{workflow-id}/workflow-state.yaml`

**Updates to make**:
```yaml
# Update current phase to next phase
current_phase:
  name: research  # Next phase
  started_at: 2025-11-24T14:45:00Z
  progress_percent: 0

# Mark archived phase as completed
phases:
  planning:
    status: completed
    completed_at: 2025-11-24T14:30:00Z
    archived_at: 2025-11-24T14:35:00Z  # Archival timestamp
    agents_used: [agent-001, agent-002, agent-003]
    tokens_used: 42000

# Update metrics
metrics:
  total_phases_completed: 1  # Increment
  total_tokens_used: 42000   # Cumulative

# Clear active agents (should already be empty)
active_agents: []
```

### Step 6: Update shared/decisions.md (if applicable)

If key decisions were made during this phase, add to shared log:

**Location**: `.development/workflows/{workflow-id}/shared/decisions.md`

**Format**:
```markdown
## Planning Phase Decisions (2025-11-24)

### Decision 1: Use REST API
- **What**: Use REST instead of GraphQL for API design
- **Why**: Team has more experience, adequate for use case
- **Source**: archive/planning-20251124T1430/phase-summary.md

### Decision 2: PostgreSQL Database
- **What**: Use PostgreSQL for data persistence
- **Why**: Relational model fits requirements, ACID guarantees
- **Source**: archive/planning-20251124T1430/agent-002-architecture.md
```

### Step 7: Verify Archival Success

**Checklist**:
```bash
# 1. Verify archive folder exists
ls .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/

# 2. Verify phase-summary.md created
cat .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/phase-summary.md | head -30

# 3. Verify all agent outputs moved
ls .development/workflows/{workflow-id}/archive/{phase}-${TIMESTAMP}/agent-*

# 4. Verify active/{phase}/ is empty or removed
ls .development/workflows/{workflow-id}/active/{phase}/ 2>/dev/null
# Should show nothing or "No such file or directory"

# 5. Verify workflow-state.yaml updated
cat .development/workflows/{workflow-id}/workflow-state.yaml | grep -A 10 "phases:"
```

---

## Phase Summary Generation

### What to Include in phase-summary.md

**Mandatory Sections**:
1. **Overview** - Brief summary of phase (2-3 sentences)
2. **Objectives Achieved** - Checklist of phase objectives
3. **Key Outputs** - Per-agent summary with findings
4. **Consolidated Findings** - Synthesis across all agents
5. **Decisions Made** - Key decisions with rationale
6. **Questions Resolved** - Q&A log
7. **Handoff to Next Phase** - Critical context for next phase

**Optional Sections** (if applicable):
- Risks and Issues Identified
- Metrics (token usage, duration, agent counts)
- Lessons Learned
- Timeline visualization

### How to Synthesize Multiple Agent Outputs

**Bad Synthesis** (avoid):
```markdown
### Agent-001 Output

[Copy/paste entire agent-001-requirements.md file - 5000 tokens]

### Agent-002 Output

[Copy/paste entire agent-002-architecture.md file - 8000 tokens]
```

**Good Synthesis**:
```markdown
### Agent-001: Requirements Gathering

**Output**: `agent-001-requirements.md`
**Tokens**: 5000
**Summary**: Analyzed 8 user personas and extracted 23 functional requirements for authentication system.

**Key Findings**:
1. Users need SSO support (80% of enterprise customers require this)
2. 2FA is critical for compliance (GDPR, SOC2)
3. Session management complexity drives need for JWT approach

**Decisions Made**:
- Use OAuth 2.0 + JWT (best fit for requirements)
- Support Google, Microsoft, GitHub providers (covers 95% of use cases)
```

**Synthesis Strategy**:
- **Extract key findings** (3-5 bullets per agent)
- **Summarize decisions** with rationale
- **Highlight connections** between agent outputs
- **Focus on actionable insights** for next phase

### Token Efficiency Guidelines

**Target**: 2000-3000 tokens for phase-summary.md

**Efficiency Techniques**:

1. **Use bullet points over paragraphs** (more information density)
2. **Reference files instead of quoting** (link, don't copy)
3. **Synthesize findings** across agents (don't repeat)
4. **Focus on "what" and "why"**, not "how" (details in raw files)

**Token Budget by Section**:
```
Overview:                  200 tokens
Objectives Achieved:       300 tokens
Key Outputs (3 agents):    900 tokens (300 each)
Consolidated Findings:     600 tokens
Decisions Made:            400 tokens
Questions Resolved:        200 tokens
Handoff to Next Phase:     400 tokens
---
Total:                     3000 tokens
```

### Focus on Handoff Context for Next Phase

**Most Important Section**: "Handoff to Next Phase"

**What to include**:
```markdown
## Handoff to Next Phase

### Context for Research Phase

**What's Ready**:
- Authentication requirements validated with 8 user personas
- OAuth 2.0 + JWT approach approved
- Database schema requirements outlined

**What's Needed**:
- Research OAuth 2.0 implementation patterns in Node.js
- Investigate JWT best practices and security concerns
- Explore session management strategies

**Critical Files to Reference**:
- `archive/planning-20251124T1430/agent-001-requirements.md` - Full requirements list
- `archive/planning-20251124T1430/agent-002-architecture.md` - High-level architecture
- `shared/decisions.md` - OAuth provider choices

**Recommended Focus**:
1. Security patterns for JWT implementation (HIGH PRIORITY)
2. OAuth 2.0 provider integration complexity
3. Session management and token refresh strategies
```

**Why this matters**:
- Next phase agents read THIS section first
- Sets clear priorities and context
- Prevents re-research of decided topics
- Points to specific files if deep dive needed

---

## Cleanup Agent Prompt Template

Use this template when launching the cleanup agent:

```javascript
Task({
  subagent_type: "general-purpose",
  description: "Archive {phase} phase for {workflow-id}",
  prompt: `
You are the cleanup agent for workflow: {workflow-id}

**Your Task**: Archive the completed {phase} phase

**Step-by-Step Instructions**:

1. **Create Timestamp**
   - Generate: $(date -u +"%Y%m%dT%H%M")
   - Store in variable: TIMESTAMP

2. **Create Archive Folder**
   - Path: .development/workflows/{workflow-id}/archive/{phase}-$TIMESTAMP/
   - Use: mkdir -p [path]

3. **Move All Files**
   - From: .development/workflows/{workflow-id}/active/{phase}/*
   - To: .development/workflows/{workflow-id}/archive/{phase}-$TIMESTAMP/
   - Use: mv command (move everything in phase folder)

4. **Generate Phase Summary**
   - Read template: templates/phase-summary.md
   - Read all agent outputs from archive/{phase}-$TIMESTAMP/
   - Read STATUS.yaml for metrics
   - Synthesize findings (follow template structure)
   - Focus on handoff context for next phase
   - Keep under 3000 tokens
   - Write to: archive/{phase}-$TIMESTAMP/phase-summary.md

5. **Update workflow-state.yaml**
   - Path: .development/workflows/{workflow-id}/workflow-state.yaml
   - Updates:
     * phases.{phase}.status = "completed"
     * phases.{phase}.archived_at = $TIMESTAMP
     * metrics.total_phases_completed += 1
     * (Do NOT change current_phase - orchestrator will do this)

6. **Extract Key Decisions**
   - Identify 2-5 major decisions from this phase
   - Format for shared/decisions.md (but DON'T update file yet)
   - Include in your return JSON

**Phase Summary Requirements**:
- Use template structure exactly
- Synthesize all agent outputs (don't copy/paste)
- Include per-agent summaries with key findings
- Focus "Handoff to Next Phase" on what {next-phase} needs to know
- Keep total summary under 3000 tokens
- Be specific with file references (use full paths)

**Return JSON Format**:
{
  "status": "finished",
  "timestamp": "$TIMESTAMP",
  "archive_path": "archive/{phase}-$TIMESTAMP/",
  "summary_path": "archive/{phase}-$TIMESTAMP/phase-summary.md",
  "summary_tokens": [estimated count],
  "decisions_for_shared_log": [
    {
      "title": "Decision title",
      "what": "What was decided",
      "why": "Rationale"
    }
  ],
  "files_archived": [count],
  "verification": {
    "archive_created": true,
    "summary_created": true,
    "workflow_state_updated": true,
    "active_phase_empty": true
  }
}

**Critical Rules**:
- Synthesize, don't copy/paste entire outputs
- Focus on insights, not raw data
- Phase summary is for NEXT PHASE, not historical record
- Raw files are preserved for deep dives if needed
  `
});
```

### What the Agent Should Do Step-by-Step

**Execution Order**:
1. Generate timestamp
2. Create archive folder
3. Move files from active/ to archive/
4. Read all agent outputs (from archive location)
5. Read STATUS.yaml for metrics
6. Read phase README.md for objectives
7. Read template: templates/phase-summary.md
8. Generate phase summary following template
9. Write phase-summary.md to archive folder
10. Update workflow-state.yaml
11. Return completion JSON with verification

**Agent Responsibilities**:
- ✅ Moving files
- ✅ Generating phase summary
- ✅ Updating workflow-state.yaml (partial)
- ✅ Extracting key decisions
- ✅ Verifying archival success

**NOT Agent's Responsibility** (orchestrator does):
- ❌ Updating current_phase in workflow-state.yaml
- ❌ Updating shared/decisions.md
- ❌ Transitioning to next phase
- ❌ Launching next phase agents

### How to Return Completion Status

**JSON Return Format**:
```json
{
  "status": "finished",
  "timestamp": "20251124T1430",
  "archive_path": "archive/planning-20251124T1430/",
  "summary_path": "archive/planning-20251124T1430/phase-summary.md",
  "summary_tokens": 2847,
  "decisions_for_shared_log": [
    {
      "title": "Use REST API",
      "what": "Use REST instead of GraphQL for API design",
      "why": "Team has more experience, adequate for use case"
    },
    {
      "title": "PostgreSQL Database",
      "what": "Use PostgreSQL for data persistence",
      "why": "Relational model fits requirements, ACID guarantees"
    }
  ],
  "files_archived": 8,
  "verification": {
    "archive_created": true,
    "summary_created": true,
    "workflow_state_updated": true,
    "active_phase_empty": true
  }
}
```

**Status values**:
- `"finished"` - Archival completed successfully
- `"failed"` - Archival encountered errors (include error details)
- `"partial"` - Some steps completed, others failed (explain which)

---

## Post-Archival Tasks

### Updating workflow-state.yaml

After cleanup agent completes, orchestrator makes final updates:

```yaml
# Transition to next phase
current_phase:
  name: research  # Next phase
  started_at: 2025-11-24T14:45:00Z  # Now
  estimated_completion: null
  progress_percent: 0

# Archived phase already updated by cleanup agent
phases:
  planning:
    status: completed
    completed_at: 2025-11-24T14:30:00Z
    archived_at: 2025-11-24T14:35:00Z  # From cleanup agent
    agents_used: [agent-001, agent-002, agent-003]
    tokens_used: 42000

  research:
    status: in-progress  # NEW
    started_at: 2025-11-24T14:45:00Z

# Update overall status
status: research  # Current workflow status
```

### Transitioning to Next Phase

**Step 1: Verify Archival**
```bash
cat .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/phase-summary.md | head -50
```

**Step 2: Update shared/decisions.md**
```markdown
## Planning Phase Decisions (2025-11-24)

[Use decisions_for_shared_log from cleanup agent JSON]

1. **Use REST API**
   - Decided: Use REST instead of GraphQL
   - Rationale: Team experience, adequate for use case
   - Source: archive/planning-20251124T1430/phase-summary.md
```

**Step 3: Prepare Next Phase Context**
```javascript
// Extract handoff context from phase-summary.md
const planningSummary = await readFile(
  `.development/workflows/{workflow-id}/archive/planning-20251124T1430/phase-summary.md`
);

const handoffContext = extractSection(planningSummary, "Handoff to Next Phase");

// Use this when launching first agent in next phase
```

**Step 4: Update workflow-state.yaml**
```bash
# Set current phase to next phase
# Mark next phase as in-progress
# See full YAML structure above
```

**Step 5: Initialize Next Phase**
```bash
# Next phase README.md should already exist
# Update STATUS.yaml to in-progress
cat > .development/workflows/{workflow-id}/active/research/STATUS.yaml <<EOF
phase: research
status: in-progress
started_at: 2025-11-24T14:45:00Z
active_agents: []
completed_agents: []
# ...
EOF
```

**Step 6: Launch First Agent in Next Phase**
```javascript
Task({
  subagent_type: "Plan",
  description: "Research OAuth 2.0 patterns",
  prompt: `
Context from completed planning phase:
${handoffContext}

Read full planning summary:
.development/workflows/{workflow-id}/archive/planning-20251124T1430/phase-summary.md

Your task: Research OAuth 2.0 implementation patterns in Node.js
[...]
  `
});
```

### Verifying Archive Integrity

**Verification Checklist**:
```bash
# 1. Archive folder exists
ls .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/

# 2. Phase summary exists and is complete
cat .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/phase-summary.md
# Check: Has all required sections
# Check: Token count reasonable (2000-3000)
# Check: "Handoff to Next Phase" section present

# 3. All agent outputs preserved
ls .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/agent-*
# Should see all expected agent files

# 4. STATUS.yaml preserved
cat .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/STATUS.yaml
# Should show completed status

# 5. Active phase empty
ls .development/workflows/{workflow-id}/active/{phase}/ 2>/dev/null
# Should return nothing or error

# 6. workflow-state.yaml updated
cat .development/workflows/{workflow-id}/workflow-state.yaml | grep -A 5 "phases:"
# Should show archived phase with completed status and archived_at timestamp
```

---

## Troubleshooting

### Common Archival Errors

#### Error: "Archive folder already exists"

**Symptom**:
```
mkdir: .development/workflows/{workflow-id}/archive/planning-20251124T1430: File exists
```

**Cause**: Previous archival attempt with same timestamp (or retry within same minute)

**Fix**:
```bash
# Option 1: Use new timestamp (wait 1 minute or add seconds)
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")  # Add seconds

# Option 2: Remove incomplete archive (if previous attempt failed)
rm -rf .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/
# Then retry
```

#### Error: "No agent outputs found to archive"

**Symptom**: active/{phase}/ folder is empty

**Cause**: Agents didn't complete or outputs in wrong location

**Fix**:
```bash
# Find where agent outputs actually are
find .development/workflows/{workflow-id}/ -name "agent-*.md"

# If in wrong phase folder, move them
# If agents didn't complete, don't archive yet
```

#### Error: "phase-summary.md generation failed"

**Symptom**: Summary file empty or missing sections

**Cause**: Cleanup agent ran out of tokens or template not followed

**Fix**:
```bash
# Relaunch cleanup agent with higher token budget
# Emphasize template adherence in prompt
# Or manually create summary using template
```

#### Error: "workflow-state.yaml corrupted after update"

**Symptom**: YAML parse errors when reading state file

**Cause**: Invalid YAML syntax in update

**Fix**:
```bash
# Validate YAML syntax
cat .development/workflows/{workflow-id}/workflow-state.yaml | python -m yaml

# If corrupted, restore from backup or manually fix
# Always validate YAML after edits
```

### Recovery Procedures

#### Partial Archival (some files moved, process interrupted)

**Situation**: Archival started but didn't complete

**Recovery**:
```bash
# 1. Assess what was moved
ls .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/
ls .development/workflows/{workflow-id}/active/{phase}/

# 2. Complete the move
mv .development/workflows/{workflow-id}/active/{phase}/* \
   .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/

# 3. Verify phase-summary.md exists, create if missing
# 4. Verify workflow-state.yaml updated, update if not
# 5. Run full verification checklist
```

#### Archive Created but State Not Updated

**Situation**: Files moved but workflow-state.yaml not updated

**Recovery**:
```bash
# 1. Verify archive is complete
ls .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/

# 2. Get timestamp from folder name
TIMESTAMP="20251124T1430"  # Extract from folder

# 3. Manually update workflow-state.yaml
# Add archived_at timestamp to phase
# Mark phase as completed

# 4. Continue with post-archival tasks
```

#### Summary Generated but Low Quality

**Situation**: phase-summary.md exists but doesn't follow guidelines

**Recovery**:
```bash
# 1. Read current summary
cat .development/workflows/{workflow-id}/archive/{phase}-{timestamp}/phase-summary.md

# 2. Relaunch cleanup agent with stricter instructions
# Emphasize synthesis over copy/paste
# Highlight "Handoff to Next Phase" importance

# 3. Overwrite phase-summary.md with better version

# 4. Verify token count and content quality
```

### Partial Archival (if some agents incomplete)

**Situation**: Most agents completed, one still in-progress

**Decision Matrix**:

| Scenario | Action |
|----------|--------|
| **1 of 5 agents incomplete, not critical** | Archive other 4, leave incomplete agent in active/, note in STATUS.yaml |
| **Critical agent incomplete** | Wait for completion before archival |
| **Agent failed permanently** | Archive completed agents, document failure in phase-summary.md |

**Partial Archival Process**:
```bash
# 1. Create archive folder
mkdir -p .development/workflows/{workflow-id}/archive/{phase}-partial-{timestamp}/

# 2. Move ONLY completed agent outputs
mv .development/workflows/{workflow-id}/active/{phase}/agent-001-*.md \
   .development/workflows/{workflow-id}/archive/{phase}-partial-{timestamp}/

# 3. Create phase-summary.md noting partial status
# Include section: "Incomplete Work"
# - agent-003: Still in progress, investigating [topic]

# 4. Update STATUS.yaml in active/{phase}/
# Note partial archival and what remains

# 5. Don't update phases.{phase}.status to "completed"
# Use "partially-archived" status instead
```

**When to use partial archival**:
- ❌ Generally avoid (prefer complete archival)
- ✅ Only if waiting for incomplete agent blocks entire workflow
- ✅ Document clearly what's missing and why
- ✅ Plan to complete and re-archive later

---

## Best Practices

**DO**:
- ✅ Verify completion criteria before launching cleanup agent
- ✅ Use cleanup agent for archival (don't do manually)
- ✅ Keep phase summaries under 3000 tokens
- ✅ Focus summaries on handoff context for next phase
- ✅ Verify archival success before transitioning phases
- ✅ Update shared/decisions.md with key decisions
- ✅ Use unique timestamps (minute-level precision)

**DON'T**:
- ❌ Archive incomplete phases (validate first)
- ❌ Copy/paste entire agent outputs into summary
- ❌ Skip phase-summary.md generation
- ❌ Forget to update workflow-state.yaml
- ❌ Archive without verifying file integrity
- ❌ Use same timestamp for multiple archives
- ❌ Archive manually (use cleanup agent for consistency)

---

**Archival Process Guide Version**: 1.0.0
**Last Updated**: 2025-11-24
**Part of**: multi-agent-workflows skill
