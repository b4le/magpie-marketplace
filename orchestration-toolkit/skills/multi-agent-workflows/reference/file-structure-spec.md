# File Structure Specification

Complete reference for `.development/` folder organization in orchestrated workflows.

## Complete Structure

```
.development/
└── workflows/
    └── {workflow-id}/                      # e.g., feature-auth-20251124
        ├── workflow-state.yaml              # Persistent workflow state
        ├── active/                          # Current work phases
        │   ├── planning/
        │   │   ├── README.md               # Phase pseudo-skill
        │   │   ├── STATUS.yaml             # Phase status tracking
        │   │   ├── agent-001-requirements.md
        │   │   ├── agent-002-architecture/
        │   │   │   ├── READ-FIRST.md
        │   │   │   ├── decisions.yaml
        │   │   │   └── diagrams.md
        │   │   ├── NEEDS-INPUT.md          # Signal: input required
        │   │   ├── BLOCKED.md              # Signal: blocked
        │   │   └── COMPLETED.md            # Signal: phase complete
        │   ├── research/
        │   ├── design/
        │   ├── execution/
        │   └── review/
        ├── archive/                         # Completed phases
        │   ├── planning-20251124T1430/
        │   │   ├── phase-summary.md        # CRITICAL: Read this, not raw files
        │   │   ├── agent-001-requirements.md
        │   │   └── agent-002-architecture/
        │   │       └── ...
        │   └── research-20251124T1545/
        │       └── phase-summary.md
        └── shared/                          # Cross-phase reference
            ├── decisions.md                 # Architecture Decision Records
            ├── glossary.md                  # Domain terminology
            └── common-patterns.md           # Reusable patterns
```

## File Purposes

### Root Level

**workflow-state.yaml**
- **Purpose**: Persistent state tracking for entire workflow
- **Updated By**: Orchestrator and cleanup agents
- **Read By**: Orchestrators (for resumption), sub-agents (rarely)
- **Update Frequency**: Every phase transition, agent launch/completion
- **Critical Fields**: current_phase, active_agents, phases status

### Active Phase Folders

**README.md**
- **Purpose**: Phase "pseudo-skill" - instructions for sub-agents
- **Template**: `templates/phase-readme.md`
- **Updated By**: Orchestrator (once at phase start)
- **Read By**: All sub-agents in this phase (required reading)
- **Content**: Objectives, expected outputs, boundaries, success criteria

**STATUS.yaml**
- **Purpose**: Real-time phase status and agent coordination
- **Template**: `templates/status.yaml`
- **Updated By**: Sub-agents (add/update themselves), orchestrator (validation)
- **Read By**: Orchestrator (monitoring), sub-agents (checking other agents' progress)
- **Update Frequency**: On agent start, progress, completion, questions

**agent-{id}-{topic}.md**
- **Purpose**: Single-file agent output
- **Template**: `templates/agent-output.md`
- **Naming**: agent-{short-id}-{descriptive-topic}.md
- **Created By**: Sub-agent
- **Read By**: Orchestrator (summary), subsequent sub-agents (details), cleanup agent (for summary)

**agent-{id}-{topic}/**
- **Purpose**: Multi-file agent output folder
- **Created By**: Sub-agent (when output requires multiple files)
- **Must Contain**: READ-FIRST.md (template: `templates/read-first.md`)
- **Read By**: READ-FIRST.md by orchestrator, individual files by implementation agents

**Signal Files** (presence = signal)

- **NEEDS-INPUT.md**: Created when `STATUS.yaml` has `questions_pending`
- **BLOCKED.md**: Created when `STATUS.yaml` has high-severity blockers
- **COMPLETED.md**: Created when phase status is `completed`
- **Purpose**: Quick visual indication of phase state (file existence = condition true)

### Archive Folders

**{phase}-{timestamp}/**
- **Naming**: `planning-20251124T1430` (phase name + ISO timestamp)
- **Created By**: Cleanup agent during archival
- **Contains**: All files from `active/{phase}/` + generated phase-summary.md

**phase-summary.md**
- **Purpose**: Synthesized summary of entire phase
- **Template**: `templates/phase-summary.md`
- **Created By**: Cleanup agent
- **Read By**: Future phases (primary context source), orchestrator (validation)
- **Critical**: This is what future agents should read, NOT raw archived files
- **Content**: Key findings, decisions, handoff context, metrics

### Shared Folder

**decisions.md**
- **Purpose**: Architecture Decision Records (lightweight ADR format)
- **Format**: Chronological list of decisions with rationale
- **Updated By**: Orchestrator (after each phase archival)
- **Read By**: All sub-agents needing architectural context
- **Example**:
```markdown
## 2025-11-24 - Planning Phase

### Use REST API
- **What**: REST over GraphQL
- **Why**: Team experience, adequate for use case
- **Impact**: Simpler implementation, less flexibility for complex queries
```

**glossary.md**
- **Purpose**: Domain-specific terminology definitions
- **Updated By**: Agents discovering/refining terms, orchestrator consolidating
- **Read By**: Agents unfamiliar with domain
- **Example**:
```markdown
- **MFA**: Multi-Factor Authentication - second factor (e.g., SMS code) beyond password
- **OAuth 2.0**: Authorization framework for delegated access
```

**common-patterns.md** (optional)
- **Purpose**: Reusable code/design patterns discovered during workflow
- **Updated By**: Implementation agents
- **Read By**: Subsequent implementation agents for consistency

## Naming Conventions

### Workflow IDs

**Format**: `{feature|refactor|migrate}-{name}-{date|version}`

**Examples**:
- `feature-auth-20251124`
- `refactor-api-v2`
- `migrate-postgres-20251125`

**Rules**:
- Lowercase with hyphens (kebab-case)
- Descriptive (not "workflow1")
- Unique per concurrent workflow

### Agent Output Files

**Single-File Format**: `agent-{id}-{topic}.md`

**Components**:
- **agent**: Literal prefix
- **{id}**: Short unique ID (e.g., abc123, explore-001, plan-xyz)
- **{topic}**: Descriptive, specific, lowercase with hyphens

**Examples**:
- `agent-abc123-requirements.md`
- `agent-def456-oauth-flow.md`
- `agent-explore-001-security-patterns.md`

**Multi-File Format**: `agent-{id}-{topic}/`

**Must contain**: `READ-FIRST.md`

**Examples**:
- `agent-ghi789-database-schema/`
  - `READ-FIRST.md`
  - `schema.json`
  - `migrations.sql`

### Archive Folders

**Format**: `{phase}-{timestamp}/`

**Components**:
- **{phase}**: Phase name (planning, research, design, execution, review)
- **{timestamp}**: ISO 8601 compact format (YYYYMMDDTHHMM)

**Examples**:
- `planning-20251124T1430/`
- `research-20251124T1545/`
- `design-20251125T0900/`

## File Format Guidelines

### Markdown Files

**All markdown files MUST include YAML frontmatter**:

```yaml
---
phase: planning
author_agent: agent-abc123
created_at: 2025-11-24T14:30:00Z
topic: requirements-analysis
status: completed
---

# Content starts here
```

**Structure**:
1. Frontmatter (YAML)
2. Title (# H1)
3. Summary section (2-3 sentences)
4. Main content sections (## H2)
5. References/metadata at end

### YAML Files

**Used for**: Status tracking, state management, structured decisions

**Validation**: Must be valid YAML (no syntax errors)

**Indentation**: 2 spaces (no tabs)

**Example** (STATUS.yaml):
```yaml
phase: planning
status: in-progress
last_updated: 2025-11-24T15:00:00Z
active_agents:
  - id: agent-001
    topic: requirements
    status: in-progress
```

### JSON Files

**Used for**: Schemas, API specs, structured data for tools

**Validation**: Must be valid JSON

**Formatting**: Pretty-printed (2-space indent) for readability

**Example** (schema.json):
```json
{
  "tables": [
    {
      "name": "users",
      "columns": [
        {"name": "id", "type": "integer", "primary_key": true}
      ]
    }
  ]
}
```

## Access Patterns

### Orchestrator Reading

**For monitoring current phase**:
```
Read: active/{current-phase}/STATUS.yaml
Check: active/{current-phase}/NEEDS-INPUT.md (existence)
Check: active/{current-phase}/BLOCKED.md (existence)
```

**For launching next agent**:
```
Read: active/{current-phase}/STATUS.yaml (for context)
Read: archive/{previous-phase}-{timestamp}/phase-summary.md (NOT raw files)
Read: shared/decisions.md (for constraints)
```

**For phase transition**:
```
Read: active/{phase}/STATUS.yaml (verify completion criteria)
Read: active/{phase}/agent-*/  (validate outputs)
Trigger: cleanup agent to archive
```

### Sub-Agent Reading

**On initialization**:
```
Read: active/{phase}/README.md (phase instructions)
Read: context_files from prompt (provided by orchestrator)
Read: shared/decisions.md (if architectural constraints needed)
```

**During work**:
```
Read: active/{phase}/agent-{other-id}-*.md (other agents' outputs in same phase)
Read: codebase files (via Grep, Glob, Read)
```

### Sub-Agent Writing

**Output creation**:
```
Write: active/{phase}/agent-{my-id}-{topic}.md
  OR
Create: active/{phase}/agent-{my-id}-{topic}/
Write: active/{phase}/agent-{my-id}-{topic}/READ-FIRST.md
Write: active/{phase}/agent-{my-id}-{topic}/{additional-files}
```

**Status updates**:
```
Edit: active/{phase}/STATUS.yaml (add/update yourself)
```

**Signals**:
```
Write: active/{phase}/NEEDS-INPUT.md (if needs-input status)
```

## Storage Optimization

### Token Efficiency

**Phase summaries** (archive/{phase}-{timestamp}/phase-summary.md):
- Target: 2000-3000 tokens
- Maximum: 5000 tokens
- Focus: Decisions, key findings, handoff context

**Agent outputs**:
- Target: 1000-3000 tokens per file
- Maximum: 5000 tokens (consider splitting if larger)
- Use multi-file output for >3000 tokens

### Archive Management

**Retention policy** (recommended):
- Keep all phase-summary.md indefinitely (small footprint)
- Keep raw agent files for 30 days
- After 30 days: optionally compress or remove raw files (keep summaries)

**Cleanup script** (example):
```bash
# Find archives older than 30 days
find .development/workflows/*/archive/*-* -type d -mtime +30 | while read archive; do
  # Keep phase-summary.md, remove other files
  find "$archive" -type f ! -name "phase-summary.md" -delete
done
```

## Validation Checklist

### Workflow Initialization

- [ ] workflow-state.yaml created and populated
- [ ] Phase folders created (at least starting phase)
- [ ] Phase README.md created for each phase
- [ ] Phase STATUS.yaml created for each phase
- [ ] Unique workflow-id chosen

### Agent Launch

- [ ] context_files paths exist and are readable
- [ ] output_location exists
- [ ] Agent has unique topic (no collision risk)

### Agent Completion

- [ ] Output file(s) created in correct location
- [ ] STATUS.yaml updated (moved to completed_agents)
- [ ] Return JSON includes all required fields

### Phase Archival

- [ ] All agents completed
- [ ] No questions pending
- [ ] Archive folder created with timestamp
- [ ] phase-summary.md generated
- [ ] workflow-state.yaml updated with archived_at
- [ ] active/{phase}/ moved to archive/

---

**Version**: 1.0.0
**Last Updated**: 2025-11-24
