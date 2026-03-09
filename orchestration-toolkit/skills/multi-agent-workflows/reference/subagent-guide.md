# Sub-Agent Guide: Working Within Orchestrated Workflows

## Table of Contents

1. [Overview](#overview)
2. [Understanding Your Role](#understanding-your-role)
3. [Reading Context](#reading-context)
4. [Working Within Boundaries](#working-within-boundaries)
5. [Writing Outputs](#writing-outputs)
6. [Updating Status](#updating-status)
7. [Asking Questions](#asking-questions)
8. [Signaling Completion](#signaling-completion)
9. [Multi-File Outputs](#multi-file-outputs)
10. [Best Practices](#best-practices)
11. [Common Patterns](#common-patterns)
12. [Troubleshooting](#troubleshooting)

---

## Overview

As a sub-agent, you execute specific tasks within a larger orchestrated workflow. Your work is scoped, bounded, and coordinated through file-based communication. This guide helps you work effectively within the orchestration framework.

**Key Principles**:
- **Read context** from files provided by orchestrator
- **Stay within boundaries** (work only in assigned output location)
- **Update status** so orchestrator knows your progress
- **Write structured outputs** that next phase can consume
- **Signal clearly** when done, blocked, or needing input

**Your Goal**: Complete your assigned task efficiently while maintaining clear communication with the orchestrator through files and status updates.

---

## Understanding Your Role

### What You Receive

When launched, your prompt will include a JSON structure (either inline or referenced):

```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": ["active/planning/agent-001-requirements.md"],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"],
    "research": ["archive/research-20251124T1545/findings.md"]
  },
  "questions_answered": {
    "oauth_provider": "Google OAuth 2.0",
    "database": "PostgreSQL"
  },
  "continuation_prompt": "Design the authentication flow based on requirements...",
  "output_location": ".development/workflows/feature-auth-20251124/active/design/",
  "token_budget": 25000
}
```

**Fields Explained**:
- **workflow_id**: Unique ID for this workflow (helps you find files)
- **context_files**: Files you should read for context (organized by phase)
- **questions_answered**: Decisions made by orchestrator (questions previously asked)
- **continuation_prompt**: Your specific task assignment
- **output_location**: Where you write your outputs
- **token_budget**: Approximate token limit for your work

### What You Return

When finished, include JSON in your final message:

```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-abc123-auth-flow.md",
    "active/design/agent-abc123-diagrams/READ-FIRST.md"
  ],
  "questions": [],
  "summary": "Designed complete authentication flow with OAuth 2.0 integration. Includes sequence diagrams and error handling patterns.",
  "tokens_used": 18750,
  "next_phase_context": "Implementation should reference auth-flow.md for sequence, diagrams/ for visual guides.",
  "protocol_version": "1.1.0",
  "agent_id": "agent-abc123",
  "confidence": "high",
  "handoff": {
    "key_files": ["active/design/agent-abc123-auth-flow.md"],
    "decisions": ["Used OAuth 2.0 with PKCE", "JWT for session tokens"],
    "blockers": [],
    "next_focus": "Implement token refresh logic first"
  }
}
```

**Required Fields**:
- **status**: "finished" | "needs-input" | "failed"
- **output_paths**: All files you created (list paths relative to workflow root)
- **questions**: Array of questions if status is "needs-input" (empty if finished)
- **summary**: Brief 2-3 sentence summary of what you accomplished
- **tokens_used**: Approximate tokens you consumed
- **next_phase_context**: What should next phase/agent know about your outputs

**Optional Fields (v1.1.0)**:
- **protocol_version**: Set to "1.1.0" if using new fields (default: "1.0.0")
- **agent_id**: Your unique identifier for traceability
- **confidence**: Your confidence level in output quality (see table below)
- **handoff**: Structured context for successor (alternative to prose)

### Confidence Levels

Use the `confidence` field to signal output quality to orchestrators:

| Level | When to Use | Example Scenarios |
|-------|-------------|-------------------|
| `high` | Requirements clear, outputs validated, no assumptions | "Clear spec, tested implementation, verified against requirements" |
| `medium` | Standard completion, minor uncertainties | "Completed task, some edge cases may need review" (default if omitted) |
| `low` | Made assumptions, partial completion, recommend review | "Ambiguous requirements, made best-guess decisions, suggest validation"

---

## Reading Context

### Step 1: Locate Workflow Directory

```bash
WORKFLOW_ID="[from your prompt]"  # e.g., feature-auth-20251124
WORKFLOW_DIR=".development/workflows/${WORKFLOW_ID}"
```

### Step 2: Read Phase Instructions

**Always start by reading the phase README.md**:

```bash
PHASE="[from output_location]"  # e.g., design
cat ${WORKFLOW_DIR}/active/${PHASE}/README.md
```

**This tells you**:
- Phase objectives
- Expected outputs
- File format guidelines
- Boundaries and constraints
- Success criteria

### Step 3: Load Context Files

Read files in order of importance:

**Priority 1: Current Phase Context**
```javascript
// Read other agents' outputs in this phase
const context_files = parseJSON(prompt).context_files;

if (context_files.current_phase) {
  for (const file of context_files.current_phase) {
    const content = await readFile(`${WORKFLOW_DIR}/${file}`);
    // Extract key insights, don't load everything into context
  }
}
```

**Priority 2: Previous Phase Summaries**
```javascript
// Read ONLY summaries from archived phases, not raw outputs
if (context_files.planning) {
  const planningSummary = await readFile(`${WORKFLOW_DIR}/${context_files.planning[0]}`);
  // Read "Key Decisions" and "Handoff to Next Phase" sections
}

if (context_files.research) {
  const researchSummary = await readFile(`${WORKFLOW_DIR}/${context_files.research[0]}`);
  // Focus on "Consolidated Findings" section
}
```

**Priority 3: Shared Context** (if referenced)
```javascript
// Read shared decisions/glossary if needed
const decisions = await readFile(`${WORKFLOW_DIR}/shared/decisions.md`);
const glossary = await readFile(`${WORKFLOW_DIR}/shared/glossary.md`);
```

### Step 4: Parse Questions Answered

```javascript
const questions_answered = parseJSON(prompt).questions_answered;

// Apply these decisions to your work
// Example:
if (questions_answered.oauth_provider === "Google OAuth 2.0") {
  // Use Google OAuth in your design
}
```

### Context Reading Best Practices

**DO**:
- ✅ Read phase README.md first
- ✅ Read summaries, not full raw outputs
- ✅ Extract only relevant information (key decisions, findings)
- ✅ Focus on "Handoff" sections of phase summaries
- ✅ Validate context files exist before reading

**DON'T**:
- ❌ Load all context files into memory at once
- ❌ Read archived raw agent outputs (use phase-summary.md)
- ❌ Assume context structure (validate paths exist)
- ❌ Skip phase README.md (it has critical instructions)

---

## Working Within Boundaries

### What You CAN Do

**Reading**:
- ✅ Read files from `context_files` (provided by orchestrator)
- ✅ Read phase README.md for instructions
- ✅ Read shared/ folder files (decisions.md, glossary.md)
- ✅ Read project documentation (README.md, CLAUDE.md)
- ✅ Read codebase files (for analysis tasks)

**Writing**:
- ✅ Create files in `output_location` only
- ✅ Update STATUS.yaml in your phase
- ✅ Create signal files (NEEDS-INPUT.md, BLOCKED.md) if needed

**Tools**:
- ✅ Use Read, Write, Edit, Grep, Glob, Bash as needed
- ✅ Use Task tool if you need to spawn sub-tasks (rare)

### What You CANNOT Do

**Reading**:
- ❌ Access files outside workflow directory (unless for codebase analysis)
- ❌ Read other workflows' directories

**Writing**:
- ❌ Write to archived phases (they're historical)
- ❌ Write to other phases' active/ folders
- ❌ Modify workflow-state.yaml (orchestrator manages this)
- ❌ Modify other agents' output files

**Actions**:
- ❌ Launch other sub-agents directly (request via questions if needed)
- ❌ Transition phases (orchestrator controls this)
- ❌ Archive phases (cleanup agents handle this)

### Boundary Validation

Before writing files, validate you're in the right place:

```bash
# Your output_location from prompt
OUTPUT_LOC=".development/workflows/feature-auth-20251124/active/design/"

# Verify it exists
if [ ! -d "$OUTPUT_LOC" ]; then
  echo "ERROR: Output location doesn't exist: $OUTPUT_LOC"
  # Signal error to orchestrator
fi

# Verify it's in active/ (not archive/)
if [[ "$OUTPUT_LOC" == *"/archive/"* ]]; then
  echo "ERROR: Cannot write to archive: $OUTPUT_LOC"
  # Signal error
fi
```

---

## Writing Outputs

### Single-File Output

**Naming Convention**:
```
agent-{your-id}-{topic}.md
```

**Example**:
```bash
OUTPUT_FILE="${OUTPUT_LOC}/agent-abc123-auth-flow.md"
```

**File Structure** (use template):
```bash
cp templates/agent-output.md \
   ${OUTPUT_FILE}

# Then customize with your content
```

**Required Elements**:
```yaml
---
phase: design
author_agent: agent-abc123
created_at: 2025-11-24T15:30:00Z
topic: auth-flow
status: completed
tokens_used: 12500
context_sources:
  - archive/planning-20251124T1430/phase-summary.md
  - active/design/agent-001-requirements.md
---

# Authentication Flow Design

## Summary
[2-3 sentence summary]

## [Main content sections]
...
```

### Choosing Your Agent ID

Use a memorable, unique ID:

**From your invocation**:
- If you're an Explore agent: `agent-explore-abc123` (abc123 from your session ID)
- If you're a Plan agent: `agent-plan-xyz789`
- If you're general-purpose: `agent-{topic}-{short-hash}`

**Keep it short**: `agent-abc123` is better than `agent-explore-feature-auth-planning-abc123def456`

### Topic Selection

Choose a clear, specific topic that won't collide with other agents:

**Good Topics**:
- ✅ `auth-flow` (specific)
- ✅ `database-schema` (specific)
- ✅ `api-design` (specific)
- ✅ `security-review` (specific)

**Bad Topics**:
- ❌ `analysis` (too generic, may collide)
- ❌ `design` (too generic)
- ❌ `output` (meaningless)
- ❌ `requirements` (may collide if multiple agents analyze requirements)

**If in doubt**: Add more specificity
- `auth-flow` → `oauth-flow` (if multiple auth methods)
- `api-design` → `rest-api-design` (if multiple API types)

---

## Updating Status

### When to Update STATUS.yaml

**Required Updates**:
1. **When you start work** - Add yourself to active_agents
2. **When you complete** - Move yourself to completed_agents
3. **When you need input** - Add to questions_pending, set status: needs-input
4. **When you fail** - Move to failed_agents with error message

### Adding Yourself (On Start)

```yaml
# In .development/workflows/{workflow-id}/active/{phase}/STATUS.yaml

active_agents:
  - id: agent-abc123
    topic: auth-flow
    status: in-progress
    started_at: 2025-11-24T15:30:00Z
    updated_at: 2025-11-24T15:30:00Z
    output_location: active/design/agent-abc123-auth-flow.md
    estimated_completion: null
```

**Use Edit tool**:
```javascript
// Read current STATUS.yaml
const status = readFile('STATUS.yaml');

// Add yourself to active_agents array
// Use Edit tool to insert

Edit({
  file_path: `${WORKFLOW_DIR}/active/${PHASE}/STATUS.yaml`,
  old_string: "active_agents: []",
  new_string: `active_agents:
  - id: agent-abc123
    topic: auth-flow
    status: in-progress
    started_at: 2025-11-24T15:30:00Z
    updated_at: 2025-11-24T15:30:00Z`
});
```

### Marking Complete

```yaml
# Move from active_agents to completed_agents

active_agents: []  # Remove yourself

completed_agents:
  - id: agent-abc123
    topic: auth-flow
    status: completed
    started_at: 2025-11-24T15:30:00Z
    completed_at: 2025-11-24T16:45:00Z
    tokens_used: 12500
    output_paths:
      - active/design/agent-abc123-auth-flow.md

# Update metrics
metrics:
  agents_completed: 1  # Increment
  total_tokens_used: 12500  # Add your tokens
  progress_percent: 33  # If 3 agents expected, 1/3 = 33%
```

### Signaling Needs-Input

If you need orchestrator decision:

```yaml
# Set phase status
status: needs-input

# Add yourself to active_agents with needs-input status
active_agents:
  - id: agent-abc123
    topic: auth-flow
    status: needs-input  # Changed from in-progress
    updated_at: 2025-11-24T16:00:00Z

# Add your question
questions_pending:
  - question: "Should MFA be required or optional?"
    asked_by: agent-abc123
    asked_at: 2025-11-24T16:00:00Z
    priority: high
    blocking: true
    context: "Security analysis suggests MFA critical, but UX team worried about friction"
    options:
      - Required for all users
      - Optional (user choice)
      - Required for admins only
    recommendation: Required for admins only
```

**Also create signal file**:
```bash
echo "# Input Required

Agent-abc123 is blocked pending orchestrator decision.

**Question**: Should MFA be required or optional?

See STATUS.yaml for details." > ${WORKFLOW_DIR}/active/${PHASE}/NEEDS-INPUT.md
```

### Signaling Failure

If you encounter unrecoverable error:

```yaml
active_agents: []  # Remove from active

failed_agents:
  - id: agent-abc123
    topic: auth-flow
    status: failed
    started_at: 2025-11-24T15:30:00Z
    failed_at: 2025-11-24T16:15:00Z
    error: "Cannot access required OAuth documentation at docs.google.com/oauth"
    recovery_action: "Provide OAuth documentation or mock OAuth endpoints for design"
```

---

## Asking Questions

### When to Ask Questions

**Ask when**:
- ✅ Decision requires user/business input (not technical)
- ✅ Multiple valid approaches exist with different tradeoffs
- ✅ Constraint conflicts (can't satisfy all requirements)
- ✅ Blocked by missing information

**Don't ask when**:
- ❌ You can make reasonable technical decision yourself
- ❌ Answer is in provided context (search first)
- ❌ Standard best practice exists (use it)
- ❌ Question is too vague ("what should I do?")

### Question Format

**In return JSON**:
```json
{
  "status": "needs-input",
  "questions": [
    {
      "question": "Should MFA be required or optional for end users?",
      "context": "Security analysis shows MFA reduces account takeover by 99%, but UX team reports 30% drop in signups when required. Current requirements don't specify.",
      "options": [
        "Required for all users",
        "Optional (user chooses)",
        "Required for admins, optional for regular users"
      ],
      "recommendation": "Required for admins, optional for regular users",
      "rationale": "Balances security (protects high-value accounts) with UX (doesn't block regular user signups)",
      "blocking": true,
      "priority": "high"
    }
  ],
  "output_paths": ["active/design/agent-abc123-auth-flow-partial.md"],
  "summary": "Completed 80% of auth flow design. Blocked on MFA requirement decision.",
  "tokens_used": 10000
}
```

**And in STATUS.yaml**:
```yaml
questions_pending:
  - question: "Should MFA be required or optional for end users?"
    asked_by: agent-abc123
    asked_at: 2025-11-24T16:00:00Z
    priority: high
    blocking: true
    context: "Security vs UX tradeoff. Current requirements ambiguous."
    options:
      - Required for all users
      - Optional (user chooses)
      - Required for admins, optional for regular users
    recommendation: Required for admins, optional for regular users
```

### Question Best Practices

**DO**:
- ✅ Provide specific, actionable options
- ✅ Include your recommendation with rationale
- ✅ Explain context (why you're asking)
- ✅ Indicate if blocking (can you continue without answer?)
- ✅ Set appropriate priority (high if blocking, medium otherwise)

**DON'T**:
- ❌ Ask open-ended questions ("what should I do?")
- ❌ Ask without providing options
- ❌ Ask without recommendation
- ❌ Forget to explain why you're asking
- ❌ Mark everything as high priority

---

## Signaling Completion

### Return JSON Structure

**Finished Successfully**:
```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-abc123-auth-flow.md"
  ],
  "questions": [],
  "summary": "Designed complete OAuth 2.0 authentication flow with MFA support. Includes sequence diagrams, error handling, and session management patterns. Ready for implementation.",
  "tokens_used": 12500,
  "next_phase_context": "Implementation should reference auth-flow.md sections 3-5 for sequence flows. Section 6 covers error codes to implement. MFA is optional per user preference (decision Q1 resolved)."
}
```

**Needs Input** (question asked):
```json
{
  "status": "needs-input",
  "output_paths": [
    "active/design/agent-abc123-auth-flow-partial.md"
  ],
  "questions": [
    {
      "question": "Should session timeout be 15 min or 60 min?",
      "options": ["15 minutes", "60 minutes", "Configurable"],
      "recommendation": "Configurable",
      "blocking": false
    }
  ],
  "summary": "Completed auth flow design except session timeout. Non-blocking question - can proceed with placeholder if needed.",
  "tokens_used": 10000,
  "next_phase_context": "Partially complete, resume after question answered."
}
```

**Failed**:
```json
{
  "status": "failed",
  "output_paths": [],
  "questions": [],
  "summary": "Failed to complete auth flow design due to missing OAuth 2.0 documentation access. Error: 403 Forbidden on docs.google.com/oauth.",
  "tokens_used": 3500,
  "next_phase_context": "Cannot proceed. Need OAuth documentation or alternative source."
}
```

### Summary Guidelines

**Good Summaries** (2-3 sentences):
- ✅ "Designed OAuth 2.0 auth flow with MFA. Includes 5 sequence diagrams and error handling. Ready for implementation."
- ✅ "Analyzed database schema needs. Identified 8 tables with 3NF normalization. Created schema.json and migration scripts."
- ✅ "Reviewed security patterns for session management. Recommended Redis for session store. Documented 4 attack vectors and mitigations."

**Bad Summaries**:
- ❌ "Completed the task." (too vague)
- ❌ "Spent 12000 tokens analyzing authentication and looked at OAuth and also MFA and sessions and cookies..." (too detailed, rambling)
- ❌ "See output file." (not a summary)

### Next Phase Context

Tell next phase what they need to know:

**Good Context**:
- ✅ "Implementation should use schema.json for table creation. migrations.sql has DDL. Refer to rationale.md section 2 for normalization decisions."
- ✅ "Testing should validate auth flow from section 3. Error codes in section 6 must all be tested. MFA is optional (per Q1 decision)."

**Bad Context**:
- ❌ "Read my output." (not helpful)
- ❌ "Everything is documented." (where?)
- ❌ "" (empty - always provide context)

---

## Multi-File Outputs

### When to Use Multiple Files

Use multi-file output (folder) when:
- ✅ Output includes both structured data (JSON/YAML) and documentation (Markdown)
- ✅ Output is large (>3000 tokens) and can be logically separated
- ✅ Output serves multiple audiences (e.g., schema for tools, rationale for humans)
- ✅ Output includes generated code + explanation

**Don't use when**:
- ❌ Everything fits comfortably in one markdown file
- ❌ Files would be very small (<500 tokens each)
- ❌ No logical separation (arbitrary splits)

### Creating Multi-File Output

**Step 1: Create Folder**
```bash
FOLDER="${OUTPUT_LOC}/agent-abc123-database-schema"
mkdir -p ${FOLDER}
```

**Step 2: Create Files**
```bash
# Create each output file
cat > ${FOLDER}/schema.json << 'EOF'
{
  "tables": [
    {
      "name": "users",
      "columns": [...]
    }
  ]
}
EOF

cat > ${FOLDER}/migrations.sql << 'EOF'
-- Create users table
CREATE TABLE users (...);
EOF

cat > ${FOLDER}/rationale.md << 'EOF'
# Database Schema Rationale
...
EOF
```

**Step 3: Create READ-FIRST.md**
```bash
cp templates/read-first.md \
   ${FOLDER}/READ-FIRST.md

# Customize with your content
```

**Update READ-FIRST.md**:
```yaml
---
phase: design
author_agent: agent-abc123
created_at: 2025-11-24T16:30:00Z
topic: database-schema
folder_purpose: Separate machine-readable schema (JSON) from human documentation
total_files: 3
total_tokens: 4500
---

# READ FIRST: Database Schema Design

## Folder Overview

Contains database schema for authentication system.

## Files in This Folder

### 1. schema.json
**Purpose**: Machine-readable table definitions
**Format**: JSON
**When to Use**: Direct consumption by migration tools or ORM
**Read This If**: Implementing database creation

### 2. migrations.sql
**Purpose**: SQL DDL statements for table creation
**Format**: SQL
**When to Use**: Manual database setup
**Read This If**: Running migrations manually

### 3. rationale.md
**Purpose**: Explains design decisions and normalization
**Format**: Markdown
**When to Use**: Understanding why schema is structured this way
**Read This If**: Reviewing design or making changes

## Reading Order

**For Orchestrators**: Read this file only (2 min)
**For Implementation**: schema.json → migrations.sql (10 min)
**For Review**: rationale.md → schema.json (15 min)
```

### Return JSON for Multi-File

```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-abc123-database-schema/READ-FIRST.md",
    "active/design/agent-abc123-database-schema/schema.json",
    "active/design/agent-abc123-database-schema/migrations.sql",
    "active/design/agent-abc123-database-schema/rationale.md"
  ],
  "summary": "Designed database schema with 8 tables, normalized to 3NF. Includes JSON schema, SQL migrations, and design rationale.",
  "tokens_used": 15000,
  "next_phase_context": "Implementation should use schema.json for ORM configuration or migrations.sql for manual setup. See READ-FIRST.md for navigation."
}
```

**Key**: Always list READ-FIRST.md first in output_paths

---

## Best Practices

### Context Efficiency

**DO**:
- ✅ Read summaries before full outputs
- ✅ Extract only relevant information
- ✅ Focus on decisions and key findings
- ✅ Skip irrelevant sections

**DON'T**:
- ❌ Load all context into memory at once
- ❌ Read entire files if you only need summary
- ❌ Process data you don't need

### Output Quality

**DO**:
- ✅ Front-load critical information (summary, decisions)
- ✅ Use structured formats (tables, lists, headers)
- ✅ Include file paths with line numbers for code refs
- ✅ Provide clear next steps

**DON'T**:
- ❌ Write walls of text
- ❌ Bury key decisions in appendices
- ❌ Use vague references ("the code", "that file")
- ❌ Forget to summarize

### Communication

**DO**:
- ✅ Update STATUS.yaml promptly
- ✅ Signal completion clearly
- ✅ Ask specific questions
- ✅ Provide recommendations with questions

**DON'T**:
- ❌ Go silent (update status regularly)
- ❌ Ask vague questions
- ❌ Forget to return JSON at completion
- ❌ Mark yourself complete in STATUS.yaml but not return completion JSON

### Token Management

**DO**:
- ✅ Track your token usage
- ✅ Warn if approaching budget (>80%)
- ✅ Be concise but complete
- ✅ Use references instead of copying large blocks

**DON'T**:
- ❌ Ignore token budget
- ❌ Create unnecessarily verbose outputs
- ❌ Copy/paste entire code files into outputs
- ❌ Forget to report tokens_used in return JSON

---

## Common Patterns

### Pattern: Analysis Task

**Typical Flow**:
1. Read requirements from context_files
2. Read codebase files (via Grep, Glob, Read)
3. Analyze and identify patterns
4. Document findings in structured format
5. Make recommendations
6. Return completion JSON

**Output Structure**:
```markdown
## Summary
[Key findings in 3 bullets]

## Analysis
[Detailed findings with evidence]

## Recommendations
[Actionable recommendations]

## Next Steps
[What should happen based on this analysis]
```

### Pattern: Design Task

**Typical Flow**:
1. Read requirements and constraints
2. Read previous design decisions (from shared/decisions.md)
3. Design solution
4. Document design with diagrams/schemas
5. Explain rationale
6. Return completion JSON

**Output Structure**:
```markdown
## Summary
[What was designed]

## Design
[The actual design with diagrams/schemas]

## Rationale
[Why this design, alternatives considered]

## Implementation Guide
[How to implement this design]
```

### Pattern: Implementation Task

**Typical Flow**:
1. Read design documents
2. Read existing code patterns
3. Implement changes
4. Document what was changed and why
5. Note any deviations from design
6. Return completion JSON

**Output Structure**:
```markdown
## Summary
[What was implemented]

## Changes Made
[Files modified with descriptions]

## Deviations from Design
[Any changes to original design and why]

## Testing Notes
[How to test/verify changes]
```

### Pattern: Blocked Task

**Typical Flow**:
1. Start work
2. Encounter blocker (missing info, ambiguous requirement)
3. Document progress so far
4. Formulate question with options and recommendation
5. Update STATUS.yaml with needs-input
6. Create NEEDS-INPUT.md signal file
7. Return needs-input JSON

**Output Structure**:
```markdown
## Summary
[What was completed, what's blocked]

## Progress
[What you accomplished]

## Blocker
[What's blocking you]

## Question
[Specific question with options and recommendation]
```

---

## Troubleshooting

### "Cannot find context files"

**Cause**: Paths in context_files don't exist
**Fix**:
```bash
# Validate paths exist
for file in ${context_files[@]}; do
  if [ ! -f "${WORKFLOW_DIR}/${file}" ]; then
    echo "ERROR: Context file missing: ${file}"
    # Ask orchestrator for correct paths
  fi
done
```

### "Output location doesn't exist"

**Cause**: Phase folder not created or wrong path
**Fix**:
```bash
# Create if missing
mkdir -p ${OUTPUT_LOC}

# Verify it's correct phase
# If wrong, ask orchestrator for correct location
```

### "STATUS.yaml format invalid"

**Cause**: YAML syntax error in your edit
**Fix**:
```bash
# Validate YAML before writing
# Use Edit tool carefully to preserve structure
# Test with: cat STATUS.yaml | python -c "import yaml; yaml.safe_load(open('STATUS.yaml'))"
```

### "Filename collision with another agent"

**Cause**: Another agent used same topic name
**Fix**:
```bash
# Use more specific topic
# Instead of: agent-abc123-design.md
# Use: agent-abc123-api-design.md
```

### "Running out of tokens"

**Cause**: Task more complex than budgeted
**Fix**:
- Focus on essentials only
- Break into sub-tasks (ask orchestrator to split work)
- Use references instead of copying large blocks
- Update STATUS.yaml with warning, report in return JSON

### "Can't update STATUS.yaml (conflicts)"

**Cause**: Another agent modified STATUS.yaml simultaneously
**Fix**:
```bash
# Read latest version
# Re-apply your changes carefully
# Use Edit tool with specific old_string (include context to avoid conflicts)
```

---

## Checklist for Completion

Before returning completion JSON, verify:

**Context**:
- [ ] Read all files in context_files
- [ ] Read phase README.md
- [ ] Applied questions_answered to your work

**Output**:
- [ ] Created output file(s) in correct location
- [ ] Used proper naming (agent-{id}-{topic})
- [ ] Included YAML frontmatter in markdown files
- [ ] If multi-file: created READ-FIRST.md

**Status**:
- [ ] Updated STATUS.yaml with completion
- [ ] Moved yourself from active_agents to completed_agents
- [ ] Updated metrics (tokens_used, progress_percent)
- [ ] Removed signal files if you created any

**Communication**:
- [ ] Return JSON includes all required fields
- [ ] Summary is 2-3 sentences, clear and specific
- [ ] next_phase_context explains what to do with your outputs
- [ ] tokens_used is accurate (approximate OK)
- [ ] output_paths lists all files you created

**Quality**:
- [ ] Output is complete (addresses full scope)
- [ ] Output is concise (no unnecessary verbosity)
- [ ] Output is structured (headers, lists, tables)
- [ ] Output includes references (file paths with line numbers)

---

**Sub-Agent Guide Version**: 1.1.0
**Last Updated**: 2025-02-24
**Protocol Version**: 1.1.0

**Next**: See `orchestrator-guide.md` for orchestrator perspective, or `examples/` for complete workflow examples.
