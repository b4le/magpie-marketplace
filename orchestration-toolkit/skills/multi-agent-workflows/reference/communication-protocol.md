# Communication Protocol Reference

## Table of Contents

1. [Overview](#overview)
2. [Protocol Architecture](#protocol-architecture)
3. [Input Protocol Schema](#input-protocol-schema)
4. [Output Protocol Schema](#output-protocol-schema)
5. [Validation Rules](#validation-rules)
6. [Complete Examples](#complete-examples)
7. [Error Handling](#error-handling)
8. [Best Practices](#best-practices)

---

## Overview

The multi-agent-workflows framework uses a **JSON-based communication protocol** for passing context from orchestrators to sub-agents (input protocol) and receiving results back (output protocol). This enables:

- **Structured communication**: Clear contracts between orchestrator and sub-agents
- **Context isolation**: Sub-agents receive only necessary context
- **Status signaling**: Explicit completion, blocking, or failure states
- **Resumability**: Workflow can resume from interruptions using protocol data

**Communication Flow**:
```
Orchestrator → [Input Protocol] → Sub-Agent → [Output Protocol] → Orchestrator
```

---

## Protocol Architecture

### Design Principles

1. **Explicit over Implicit**: All context and expectations explicitly stated
2. **Minimal Payload**: Only necessary context transferred
3. **Validation-Friendly**: Schema enables validation before processing
4. **Self-Documenting**: Field names and structure are self-explanatory

### Message Types

| Direction | Protocol | Purpose | When Used |
|-----------|----------|---------|-----------|
| **Orchestrator → Agent** | Input Protocol | Launch sub-agent with context | Every sub-agent invocation |
| **Agent → Orchestrator** | Output Protocol | Return results and status | Sub-agent completion or blocking |

---

## Input Protocol Schema

### JSON Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Orchestrator to Sub-Agent Input Protocol",
  "type": "object",
  "required": ["workflow_id", "context_files", "continuation_prompt", "output_location"],
  "properties": {
    "workflow_id": {
      "type": "string",
      "description": "Unique identifier for this workflow",
      "pattern": "^[a-z0-9-]+$",
      "minLength": 5,
      "maxLength": 64,
      "examples": ["feature-auth-20251124", "refactor-api-v2", "migrate-postgres"]
    },
    "context_files": {
      "type": "object",
      "description": "Files organized by phase for sub-agent to read",
      "properties": {
        "current_phase": {
          "type": "array",
          "description": "Files from current phase (other agents' outputs)",
          "items": {"type": "string"},
          "examples": [["active/planning/agent-001-requirements.md"]]
        }
      },
      "patternProperties": {
        "^(planning|research|design|execution|review)$": {
          "type": "array",
          "description": "Phase summary files from archived phases",
          "items": {"type": "string"},
          "examples": [["archive/planning-20251124T1430/phase-summary.md"]]
        }
      },
      "additionalProperties": false
    },
    "questions_answered": {
      "type": "object",
      "description": "Decisions made by orchestrator (answers to previous questions)",
      "additionalProperties": {"type": "string"},
      "examples": [{"oauth_provider": "Google OAuth 2.0", "database": "PostgreSQL"}]
    },
    "continuation_prompt": {
      "type": "string",
      "description": "Specific task assignment for this sub-agent",
      "minLength": 10,
      "examples": ["Design the database schema based on requirements and research findings"]
    },
    "output_location": {
      "type": "string",
      "description": "Directory where sub-agent writes outputs (must be in active/)",
      "pattern": "^\\.development/workflows/[^/]+/active/[^/]+/$",
      "examples": [".development/workflows/feature-auth-20251124/active/design/"]
    },
    "token_budget": {
      "type": "integer",
      "description": "Approximate token limit for sub-agent work (optional)",
      "minimum": 1000,
      "maximum": 100000,
      "default": 25000,
      "examples": [25000]
    }
  }
}
```

### Field Descriptions

#### `workflow_id` (required)

**Type**: `string`
**Format**: Kebab-case, alphanumeric with hyphens
**Purpose**: Uniquely identifies this workflow to prevent cross-workflow contamination

**Examples**:
- ✅ `"feature-auth-20251124"` - Feature name + date
- ✅ `"refactor-api-v2"` - Task + version
- ✅ `"migrate-postgres"` - Descriptive task name
- ❌ `"workflow1"` - Too generic
- ❌ `"Feature_Auth"` - Wrong case/format

**Usage**:
```json
{
  "workflow_id": "feature-auth-20251124"
}
```

---

#### `context_files` (required)

**Type**: `object`
**Purpose**: Organizes files by phase for sub-agent to read

**Structure**:
```json
{
  "current_phase": ["path/to/current/file.md"],
  "planning": ["archive/planning-timestamp/phase-summary.md"],
  "research": ["archive/research-timestamp/phase-summary.md"],
  "design": ["archive/design-timestamp/phase-summary.md"]
}
```

**Rules**:
- `current_phase`: Files from active phase (other agents' outputs in same phase)
- Phase keys (`planning`, `research`, etc.): Files from **archived** phases (ONLY phase-summary.md)
- All paths relative to workflow root (`.development/workflows/{workflow_id}/`)
- Arrays can be empty if no context from that phase

**Examples**:

First agent (no previous context):
```json
{
  "context_files": {
    "current_phase": []
  }
}
```

Agent with previous outputs in same phase:
```json
{
  "context_files": {
    "current_phase": [
      "active/design/agent-001-requirements.md",
      "active/design/agent-002-constraints.md"
    ]
  }
}
```

Agent in later phase with archived context:
```json
{
  "context_files": {
    "current_phase": [],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"],
    "research": ["archive/research-20251124T1545/phase-summary.md"]
  }
}
```

---

#### `questions_answered` (optional)

**Type**: `object` (key-value pairs)
**Purpose**: Provides decisions made by orchestrator in response to previous agent questions

**Structure**:
```json
{
  "question_identifier": "answer_value"
}
```

**Rules**:
- Keys are question identifiers (short, descriptive)
- Values are the orchestrator's decision/answer
- Empty object `{}` if no questions answered
- Can be omitted entirely if no questions

**Examples**:

No questions answered:
```json
{
  "questions_answered": {}
}
```

Single decision:
```json
{
  "questions_answered": {
    "oauth_provider": "Google OAuth 2.0"
  }
}
```

Multiple decisions:
```json
{
  "questions_answered": {
    "oauth_provider": "Google OAuth 2.0",
    "database": "PostgreSQL",
    "mfa_required": "Optional for users, required for admins",
    "session_timeout": "60 minutes"
  }
}
```

---

#### `continuation_prompt` (required)

**Type**: `string`
**Purpose**: Clear, specific task assignment for sub-agent

**Format**: Natural language description of task

**Good Examples**:
- ✅ `"Design the authentication flow using OAuth 2.0. Include sequence diagrams and error handling."`
- ✅ `"Analyze the existing codebase for authentication patterns. Document findings and recommend improvements."`
- ✅ `"Implement the database schema from design phase. Create migration scripts and seed data."`

**Bad Examples**:
- ❌ `"Do the design"` - Too vague
- ❌ `"Continue"` - No context
- ❌ `"Design authentication flow using OAuth 2.0 with Google as provider, supporting MFA optionally for regular users but required for admins, with 60-minute session timeout..."` - Too prescriptive (put details in questions_answered)

---

#### `output_location` (required)

**Type**: `string`
**Format**: Absolute path ending with `/`
**Purpose**: Directory where sub-agent writes all outputs

**Pattern**: `.development/workflows/{workflow_id}/active/{phase}/`

**Rules**:
- Must be within `active/` (not `archive/`)
- Must end with trailing slash
- Sub-agent writes files here: `{output_location}/agent-{id}-{topic}.md`

**Examples**:
```json
{
  "output_location": ".development/workflows/feature-auth-20251124/active/planning/"
}
```

```json
{
  "output_location": ".development/workflows/refactor-api-v2/active/execution/"
}
```

---

#### `token_budget` (optional)

**Type**: `integer`
**Default**: 25000
**Purpose**: Approximate token limit for sub-agent's work

**Usage**:
- Helps sub-agent pace work
- Sub-agent should warn if approaching 80% of budget
- Sub-agent reports actual usage in output protocol

**Examples**:
```json
{
  "token_budget": 15000  // Lighter task
}
```

```json
{
  "token_budget": 50000  // Complex analysis
}
```

---

## Output Protocol Schema

### JSON Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Sub-Agent to Orchestrator Output Protocol",
  "type": "object",
  "required": ["status", "output_paths", "summary", "tokens_used", "next_phase_context"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["finished", "needs-input", "failed"],
      "description": "Completion status of sub-agent work"
    },
    "output_paths": {
      "type": "array",
      "description": "Paths to all files created (relative to workflow root)",
      "items": {"type": "string"},
      "minItems": 0,
      "examples": [
        ["active/design/agent-abc123-auth-flow.md"],
        ["active/design/agent-def456-schema/READ-FIRST.md", "active/design/agent-def456-schema/schema.json"]
      ]
    },
    "questions": {
      "type": "array",
      "description": "Questions requiring orchestrator input (required if status=needs-input)",
      "items": {
        "type": "object",
        "required": ["question", "options", "recommendation", "blocking"],
        "properties": {
          "question": {
            "type": "string",
            "description": "Clear, specific question",
            "examples": ["Should MFA be required or optional for end users?"]
          },
          "context": {
            "type": "string",
            "description": "Why asking, what's been considered"
          },
          "options": {
            "type": "array",
            "description": "2-4 possible answers",
            "items": {"type": "string"},
            "minItems": 2,
            "maxItems": 4
          },
          "recommendation": {
            "type": "string",
            "description": "Agent's recommended answer with rationale"
          },
          "blocking": {
            "type": "boolean",
            "description": "Can agent continue without answer?"
          },
          "priority": {
            "type": "string",
            "enum": ["high", "medium", "low"],
            "default": "medium"
          }
        }
      }
    },
    "summary": {
      "type": "string",
      "description": "2-3 sentence summary of what was accomplished",
      "minLength": 20,
      "maxLength": 500
    },
    "tokens_used": {
      "type": "integer",
      "description": "Approximate tokens consumed by this sub-agent",
      "minimum": 0
    },
    "next_phase_context": {
      "type": "string",
      "description": "What next phase/agent should know about these outputs",
      "minLength": 10
    },
    "protocol_version": {
      "type": "string",
      "description": "Protocol version used by this agent (optional, default: 1.0.0)",
      "default": "1.0.0",
      "examples": ["1.0.0", "1.1.0"]
    },
    "agent_id": {
      "type": "string",
      "description": "Unique identifier for this agent instance (optional, can be extracted from output_paths)",
      "pattern": "^agent-[a-z0-9-]+$",
      "examples": ["agent-abc123", "agent-plan-xyz789"]
    },
    "confidence": {
      "type": "string",
      "enum": ["high", "medium", "low"],
      "description": "Agent's confidence in the quality/completeness of outputs (optional, default: medium)",
      "default": "medium"
    },
    "handoff": {
      "type": "object",
      "description": "Structured handoff context for next phase (optional, alternative to next_phase_context)",
      "properties": {
        "key_files": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Most important files for successor to read"
        },
        "decisions": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Key decisions made during this work"
        },
        "blockers": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Any blockers or concerns for successor"
        },
        "next_focus": {
          "type": "string",
          "description": "What successor should prioritize"
        }
      }
    }
  }
}
```

### Field Descriptions

#### `status` (required)

**Type**: `enum` - One of: `"finished"`, `"needs-input"`, `"failed"`

**Values**:

| Status | Meaning | When to Use | Required Fields |
|--------|---------|-------------|-----------------|
| `finished` | Work completed successfully | Task done, no blockers | `output_paths`, `summary`, `tokens_used`, `next_phase_context` |
| `needs-input` | Blocked waiting for decision | Can't proceed without answer | `output_paths`, `questions`, `summary`, `tokens_used` |
| `failed` | Unrecoverable error occurred | Cannot complete task | `summary` (error details), `tokens_used` |

**Examples**:
```json
{"status": "finished"}
{"status": "needs-input"}
{"status": "failed"}
```

---

#### `output_paths` (required)

**Type**: `array` of `string`
**Purpose**: Lists all files created by sub-agent

**Format**: Paths relative to workflow root

**Rules**:
- Empty array `[]` if status is `failed` and no outputs created
- For multi-file outputs, list READ-FIRST.md **first**
- Paths must be within `output_location` from input protocol

**Examples**:

Single file:
```json
{
  "output_paths": ["active/planning/agent-abc123-requirements.md"]
}
```

Multiple files (folder):
```json
{
  "output_paths": [
    "active/design/agent-def456-schema/READ-FIRST.md",
    "active/design/agent-def456-schema/schema.json",
    "active/design/agent-def456-schema/migrations.sql",
    "active/design/agent-def456-schema/rationale.md"
  ]
}
```

No outputs (failed):
```json
{
  "output_paths": []
}
```

---

#### `questions` (required if status=needs-input)

**Type**: `array` of `question` objects
**Purpose**: Questions requiring orchestrator/user input

**Question Object Schema**:
```json
{
  "question": "string (required)",
  "context": "string (optional)",
  "options": ["string", "string", ...],
  "recommendation": "string (required)",
  "blocking": boolean (required),
  "priority": "high | medium | low (optional)"
}
```

**Rules**:
- Must be empty array `[]` if status is `finished`
- Must have 1+ questions if status is `needs-input`
- Each question must have 2-4 options
- Must include recommendation (can't just ask open-ended)

**Examples**:

Single question:
```json
{
  "questions": [
    {
      "question": "Should MFA be required or optional for end users?",
      "context": "Security analysis shows 99% reduction in account takeover with MFA, but UX reports 30% drop in signups when required.",
      "options": [
        "Required for all users",
        "Optional (user chooses)",
        "Required for admins, optional for regular users"
      ],
      "recommendation": "Required for admins, optional for regular users",
      "blocking": true,
      "priority": "high"
    }
  ]
}
```

Multiple questions:
```json
{
  "questions": [
    {
      "question": "Should we use REST or GraphQL for the API?",
      "context": "Both viable. REST simpler, GraphQL more flexible.",
      "options": ["REST", "GraphQL", "Both (hybrid)"],
      "recommendation": "REST",
      "blocking": true,
      "priority": "high"
    },
    {
      "question": "What should session timeout be?",
      "context": "Security vs UX tradeoff. Shorter = more secure, longer = better UX.",
      "options": ["15 minutes", "60 minutes", "Configurable by user"],
      "recommendation": "Configurable by user",
      "blocking": false,
      "priority": "medium"
    }
  ]
}
```

No questions (finished):
```json
{
  "questions": []
}
```

> **CRITICAL: The `needs-input` / `questions` Invariant**
>
> `status: "needs-input"` REQUIRES `questions` array with 1+ items.
>
> Returning `needs-input` with empty questions causes **workflow deadlock**:
> - Orchestrator sees "needs-input" status
> - Orchestrator looks for questions to answer
> - Questions array is empty
> - Orchestrator cannot proceed
> - Workflow stalls indefinitely
>
> **ALWAYS**: If `status: "needs-input"`, include at least one question.
> **ALWAYS**: If no questions, use `status: "finished"` instead.

---

#### `summary` (required)

**Type**: `string`
**Length**: 20-500 characters (2-3 sentences)
**Purpose**: Brief, scannable summary of what was accomplished

**Good Examples**:
- ✅ `"Designed OAuth 2.0 authentication flow with MFA support. Includes 5 sequence diagrams covering login, logout, token refresh, MFA enrollment, and error handling. Ready for implementation phase."`
- ✅ `"Analyzed existing codebase authentication patterns across 12 files. Identified 3 security vulnerabilities and 5 improvement opportunities. Recommended migration to OAuth 2.0."`
- ✅ `"Completed 80% of database schema design. Blocked on decision about user table partitioning strategy. Can proceed with other tables while waiting."`

**Bad Examples**:
- ❌ `"Done."` - Too vague
- ❌ `"Completed the task successfully."` - Not informative
- ❌ `"I spent time analyzing the authentication system and looked at OAuth and then considered JWT and also examined session management and reviewed cookies and..."` - Too detailed/rambling

---

#### `tokens_used` (required)

**Type**: `integer`
**Purpose**: Approximate tokens consumed by sub-agent

**Usage**:
- Helps orchestrator track token budget
- Informs future task allocation
- Approximate is fine (don't need exact count)

**Examples**:
```json
{"tokens_used": 12500}
{"tokens_used": 3500}
{"tokens_used": 45000}
```

---

#### `next_phase_context` (required)

**Type**: `string`
**Purpose**: Tells next phase/agent what they need to know

**Format**: 1-3 sentences explaining how to use outputs

**Good Examples**:
- ✅ `"Implementation should use schema.json for table creation and migrations.sql for DDL. Refer to rationale.md section 2 for normalization decisions if questions arise."`
- ✅ `"Testing phase should validate auth flow from section 3 of auth-flow.md. Error codes listed in section 6 must all be covered. MFA is optional per user preference (decision Q1)."`
- ✅ `"Review phase should check security requirements against findings.md sections 4-6. High-priority vulnerabilities are listed in findings.md section 2."`

**Bad Examples**:
- ❌ `"Read my output."` - Not helpful
- ❌ `"Everything is in the files."` - Where?
- ❌ `""` - Empty (never leave empty)

---

#### `protocol_version` (optional, v1.1.0+)

**Type**: `string`
**Default**: `"1.0.0"`
**Purpose**: Indicates which protocol version the agent is using

**Usage**:
- Enables orchestrators to handle different protocol versions
- Supports gradual migration to newer protocol features
- Omit to default to v1.0.0 behavior

**Examples**:
```json
{"protocol_version": "1.0.0"}
{"protocol_version": "1.1.0"}
```

---

#### `agent_id` (optional, v1.1.0+)

**Type**: `string`
**Format**: `agent-{identifier}` (kebab-case)
**Purpose**: Unique identifier for traceability and debugging

**Usage**:
- Helps orchestrators track which agent produced which outputs
- Useful for debugging and logging
- Can be extracted from output_paths if not provided

**Examples**:
```json
{"agent_id": "agent-abc123"}
{"agent_id": "agent-plan-xyz789"}
{"agent_id": "agent-explore-auth-flow"}
```

---

#### `confidence` (optional, v1.1.0+)

**Type**: `enum` - One of: `"high"`, `"medium"`, `"low"`
**Default**: `"medium"`
**Purpose**: Agent's self-assessed confidence in output quality/completeness

**Confidence Levels**:

| Level | When to Use | Orchestrator Action |
|-------|-------------|---------------------|
| `high` | Task fully understood, outputs complete and verified | Proceed with normal workflow |
| `medium` | Task completed but some uncertainty remains | Review outputs before proceeding |
| `low` | Significant gaps, assumptions made, or partial completion | Consider requesting review or re-work |

**Examples**:
```json
{"confidence": "high"}    // Clear requirements, validated outputs
{"confidence": "medium"}  // Standard completion, default if omitted
{"confidence": "low"}     // Made assumptions, recommend review
```

---

#### `handoff` (optional, v1.1.0+)

**Type**: `object`
**Purpose**: Structured alternative to `next_phase_context` for precise handoff

**Structure**:
```json
{
  "handoff": {
    "key_files": ["path/to/important.md", "path/to/schema.json"],
    "decisions": ["Chose OAuth 2.0 over SAML", "Using PostgreSQL for sessions"],
    "blockers": [],
    "next_focus": "Implement token refresh logic first"
  }
}
```

**Fields**:
- **key_files**: Most important files for successor (read order matters)
- **decisions**: Key decisions made during this work
- **blockers**: Any concerns or blockers for successor
- **next_focus**: What successor should prioritize

**Usage**:
- Use `handoff` for structured, machine-parseable context
- Falls back to `next_phase_context` for prose description
- Can include both for comprehensive handoff

**Example**:
```json
{
  "next_phase_context": "Implementation should use schema.json for table creation.",
  "handoff": {
    "key_files": ["active/design/agent-abc123-schema/schema.json"],
    "decisions": ["Normalized to 3NF", "Added audit columns"],
    "blockers": [],
    "next_focus": "Create migration scripts from schema.json"
  }
}
```

---

## Validation Rules

### Input Protocol Validation

**Pre-Launch Checklist** (Orchestrator):

```yaml
workflow_id:
  - ✓ Is kebab-case (lowercase, hyphens only)
  - ✓ Is unique (no other active workflow with same ID)
  - ✓ Is descriptive (not "workflow1" or "test")
  - ✓ Length 5-64 characters

context_files:
  - ✓ All paths are relative to workflow root
  - ✓ All files exist (check with ls or stat)
  - ✓ Phase keys match standard phases (planning, research, design, execution, review)
  - ✓ Archived phases reference phase-summary.md ONLY (not raw agent outputs)
  - ✓ current_phase files are in active/ directory

questions_answered:
  - ✓ All keys are meaningful identifiers
  - ✓ All values are clear, specific answers
  - ✓ No placeholder values ("TBD", "???")

continuation_prompt:
  - ✓ Is specific and actionable
  - ✓ Describes what to do, not just "continue"
  - ✓ Is concise (1-3 sentences)

output_location:
  - ✓ Path exists (create if needed)
  - ✓ Is in active/ directory (not archive/)
  - ✓ Ends with trailing slash
  - ✓ Matches pattern: .development/workflows/{workflow_id}/active/{phase}/

token_budget:
  - ✓ Is reasonable for task (1000-100000)
  - ✓ Is specified if task is complex
```

**Validation Errors**:

| Error | Cause | Fix |
|-------|-------|-----|
| "workflow_id invalid format" | Not kebab-case | Use lowercase with hyphens only |
| "context_file not found: X" | File path doesn't exist | Check path, ensure file created |
| "output_location not in active/" | Path points to archive | Change to active/{phase}/ |
| "continuation_prompt too vague" | No clear task | Specify exactly what agent should do |

---

### Output Protocol Validation

**Pre-Return Checklist** (Sub-Agent):

```yaml
status:
  - ✓ Is one of: finished, needs-input, failed
  - ✓ Matches actual outcome (don't say finished if blocked)

output_paths:
  - ✓ All paths exist (created files successfully)
  - ✓ All paths are relative to workflow root
  - ✓ All paths are within output_location from input
  - ✓ For multi-file: READ-FIRST.md is listed first
  - ✓ Empty array [] if status is failed with no outputs

questions (if status=needs-input):
  - ✓ At least 1 question present
  - ✓ Each question has 2-4 options
  - ✓ Each question has recommendation
  - ✓ Each question has blocking flag set
  - ✓ Context explains why asking

questions (if status=finished):
  - ✓ Empty array []

summary:
  - ✓ Length 20-500 characters
  - ✓ Is 2-3 sentences
  - ✓ Describes what was accomplished
  - ✓ Is specific (not "completed task")

tokens_used:
  - ✓ Is positive integer
  - ✓ Is reasonable approximation
  - ✓ Reflects actual work done

next_phase_context:
  - ✓ Explains how to use outputs
  - ✓ References specific files/sections
  - ✓ Is actionable
  - ✓ Is not empty
```

**Validation Errors**:

| Error | Cause | Fix |
|-------|-------|-----|
| "status=finished but questions not empty" | Inconsistent state | Remove questions or change status |
| "status=needs-input but questions empty" | Missing questions | Add questions or change status |
| "output_paths file not found: X" | File not actually created | Create file or remove from paths |
| "summary too short" | Not enough detail | Expand to 2-3 sentences |
| "next_phase_context empty" | Forgot to fill | Explain how to use outputs |

---

## Complete Examples

### Example 1: Simple Task - Requirements Analysis

**Input Protocol**:
```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": []
  },
  "questions_answered": {},
  "continuation_prompt": "Analyze requirements for authentication system. Review project documentation and user stories to extract security, UX, and technical requirements.",
  "output_location": ".development/workflows/feature-auth-20251124/active/planning/",
  "token_budget": 20000
}
```

**Output Protocol** (Success):
```json
{
  "status": "finished",
  "output_paths": [
    "active/planning/agent-abc123-requirements.md"
  ],
  "questions": [],
  "summary": "Analyzed authentication requirements from 3 user stories and 2 design docs. Identified 12 functional requirements and 8 non-functional constraints. Recommend OAuth 2.0 + JWT approach for implementation.",
  "tokens_used": 15000,
  "next_phase_context": "Research phase should investigate OAuth 2.0 providers and JWT libraries. Requirements are categorized by priority in requirements.md section 3."
}
```

---

### Example 2: Multi-File Output - Database Schema

**Input Protocol**:
```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": [],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"],
    "research": ["archive/research-20251124T1545/phase-summary.md"]
  },
  "questions_answered": {
    "database": "PostgreSQL",
    "oauth_provider": "Google OAuth 2.0"
  },
  "continuation_prompt": "Design database schema for authentication system. Create structured schema file and migration scripts based on requirements and research findings.",
  "output_location": ".development/workflows/feature-auth-20251124/active/design/",
  "token_budget": 30000
}
```

**Output Protocol** (Success, v1.1.0):
```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-def456-schema/READ-FIRST.md",
    "active/design/agent-def456-schema/schema.json",
    "active/design/agent-def456-schema/migrations.sql",
    "active/design/agent-def456-schema/rationale.md"
  ],
  "questions": [],
  "summary": "Designed database schema with 8 tables normalized to 3NF for authentication system. Includes JSON schema for programmatic use, SQL migrations for setup, and design rationale document.",
  "tokens_used": 22000,
  "next_phase_context": "Implementation should use schema.json for ORM configuration or migrations.sql for manual database setup. See READ-FIRST.md for file navigation and rationale.md for design decisions.",
  "protocol_version": "1.1.0",
  "agent_id": "agent-def456",
  "confidence": "high",
  "handoff": {
    "key_files": [
      "active/design/agent-def456-schema/schema.json",
      "active/design/agent-def456-schema/migrations.sql"
    ],
    "decisions": [
      "Normalized to 3NF for data integrity",
      "Added audit columns (created_at, updated_at) to all tables",
      "Used UUID for primary keys for distributed compatibility"
    ],
    "blockers": [],
    "next_focus": "Run migrations.sql first, then configure ORM with schema.json"
  }
}
```

> **Note**: The new v1.1.0 fields (`protocol_version`, `agent_id`, `confidence`, `handoff`) are **optional**. Agents using v1.0.0 protocol (without these fields) remain fully compatible.

---

### Example 3: Needs Input - Blocked on Decision

**Input Protocol**:
```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": [
      "active/design/agent-abc123-auth-flow.md"
    ],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"]
  },
  "questions_answered": {
    "oauth_provider": "Google OAuth 2.0"
  },
  "continuation_prompt": "Design session management strategy including timeout policies and token refresh mechanisms.",
  "output_location": ".development/workflows/feature-auth-20251124/active/design/",
  "token_budget": 25000
}
```

**Output Protocol** (Needs Input):
```json
{
  "status": "needs-input",
  "output_paths": [
    "active/design/agent-ghi789-session-mgmt-partial.md"
  ],
  "questions": [
    {
      "question": "What should the session timeout policy be?",
      "context": "Security best practices recommend 15-30 min for sensitive apps, but UX research shows 30%+ drop in engagement with timeouts under 60 min. Current requirements don't specify.",
      "options": [
        "15 minutes (high security)",
        "60 minutes (balanced)",
        "4 hours (convenience focused)",
        "Configurable by user"
      ],
      "recommendation": "60 minutes (balanced)",
      "blocking": true,
      "priority": "high"
    },
    {
      "question": "Should we support 'Remember Me' functionality?",
      "context": "Enables longer session persistence but reduces security. Common in consumer apps, less common in enterprise.",
      "options": [
        "Yes, with 30-day extended session",
        "Yes, with 7-day extended session",
        "No, always require re-authentication"
      ],
      "recommendation": "Yes, with 7-day extended session",
      "blocking": false,
      "priority": "medium"
    }
  ],
  "summary": "Completed 70% of session management design. Blocked on timeout policy decision which impacts token refresh strategy and user experience. Non-blocking question about Remember Me functionality also pending.",
  "tokens_used": 18000,
  "next_phase_context": "Partially complete. Resume after questions answered. Existing session-mgmt-partial.md covers token structure and refresh flow (sections 1-3)."
}
```

---

### Example 4: Failure - Unrecoverable Error

**Input Protocol**:
```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": [],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"]
  },
  "questions_answered": {},
  "continuation_prompt": "Research OAuth 2.0 implementation patterns and security best practices. Review official documentation and recent security advisories.",
  "output_location": ".development/workflows/feature-auth-20251124/active/research/",
  "token_budget": 20000
}
```

**Output Protocol** (Failed):
```json
{
  "status": "failed",
  "output_paths": [],
  "questions": [],
  "summary": "Failed to complete OAuth 2.0 research. Unable to access required documentation at https://developers.google.com/identity/protocols/oauth2 (403 Forbidden). Cannot proceed without official OAuth 2.0 specs and security guidelines.",
  "tokens_used": 3500,
  "next_phase_context": "Cannot proceed. Need alternative OAuth 2.0 documentation source or network access to Google's developer documentation."
}
```

---

### Example 5: Continuation with Previous Agent Context

**Input Protocol**:
```json
{
  "workflow_id": "feature-auth-20251124",
  "context_files": {
    "current_phase": [
      "active/design/agent-abc123-auth-flow.md",
      "active/design/agent-def456-schema/READ-FIRST.md"
    ],
    "planning": ["archive/planning-20251124T1430/phase-summary.md"],
    "research": ["archive/research-20251124T1545/phase-summary.md"]
  },
  "questions_answered": {
    "oauth_provider": "Google OAuth 2.0",
    "database": "PostgreSQL",
    "session_timeout": "60 minutes",
    "remember_me": "Yes, 7-day extended session"
  },
  "continuation_prompt": "Design the complete session management implementation including timeout handling, token refresh, and Remember Me functionality. Integrate with auth flow and database schema from previous agents.",
  "output_location": ".development/workflows/feature-auth-20251124/active/design/",
  "token_budget": 30000
}
```

**Output Protocol** (Success):
```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-jkl012-session-complete.md"
  ],
  "questions": [],
  "summary": "Completed session management design with 60-min timeout and 7-day Remember Me. Integrates with OAuth flow from agent-abc123 and database schema from agent-def456. Includes token refresh logic, expiration handling, and security considerations.",
  "tokens_used": 25000,
  "next_phase_context": "Implementation should reference session-complete.md sections 2-4 for token refresh logic. Uses 'sessions' table from agent-def456 schema. Integrates with auth-flow.md token issuance in section 3."
}
```

---

## Error Handling

### Input Protocol Errors

**Error**: Invalid workflow_id format
```json
{
  "error": "workflow_id must be kebab-case (lowercase, hyphens only)",
  "received": "Feature_Auth",
  "expected_pattern": "^[a-z0-9-]+$"
}
```

**Error**: Context file not found
```json
{
  "error": "context_file does not exist",
  "file": "archive/planning-20251124T1430/phase-summary.md",
  "workflow_id": "feature-auth-20251124",
  "suggestion": "Check that planning phase was archived with correct timestamp"
}
```

**Error**: Output location invalid
```json
{
  "error": "output_location must be in active/ directory",
  "received": ".development/workflows/feature-auth-20251124/archive/planning/",
  "expected_pattern": ".development/workflows/{workflow_id}/active/{phase}/"
}
```

---

### Output Protocol Errors

**Error**: Status/questions mismatch
```json
{
  "error": "status is 'finished' but questions array is not empty",
  "status": "finished",
  "questions_count": 2,
  "fix": "Either remove questions or change status to 'needs-input'"
}
```

**Error**: Output file not found
```json
{
  "error": "output_path file does not exist",
  "path": "active/design/agent-abc123-auth-flow.md",
  "suggestion": "Ensure file was created before returning completion JSON"
}
```

**Error**: Question missing required fields
```json
{
  "error": "question missing required field",
  "question_index": 0,
  "missing_field": "recommendation",
  "fix": "Add recommendation field to all questions"
}
```

---

## Best Practices

### For Orchestrators

**DO**:
- ✅ Validate input protocol before launching sub-agent (check file paths exist)
- ✅ Keep context_files minimal (only essential context)
- ✅ Use phase summaries, not raw agent outputs, for archived phases
- ✅ Provide clear, specific continuation_prompt
- ✅ Set reasonable token_budget for task complexity
- ✅ Pass all previous decisions in questions_answered

**DON'T**:
- ❌ Pass massive context blobs (list 20+ files in context_files)
- ❌ Use vague continuation_prompt ("do the design")
- ❌ Forget to create output_location directory
- ❌ Reuse workflow_id for different workflows
- ❌ Pass raw agent outputs for archived phases (use summaries)

#### Defensive Parsing

Sub-agents may return malformed JSON due to token limits, interruptions, or formatting errors. Orchestrators must handle these gracefully to prevent workflow failures.

**Why Defensive Parsing Matters**:
- Sub-agents operate in isolated contexts and may truncate output
- Network interruptions can corrupt response data
- Token budget exhaustion may cut off JSON mid-structure
- LLM responses occasionally include markdown fences or prose around JSON

**Parsing Strategy**:

```
1. Attempt strict JSON parse
2. If fails, try extraction strategies:
   a. Strip markdown code fences (```json ... ```)
   b. Find JSON object boundaries ({ ... })
   c. Attempt partial field extraction
3. If extraction fails, use fallback response
```

**Extraction Pseudocode**:
```python
def defensive_parse(response: str) -> dict:
    # Strategy 1: Direct parse
    try:
        return json.loads(response)
    except JSONDecodeError:
        pass

    # Strategy 2: Strip markdown fences
    stripped = re.sub(r'^```json?\n?|\n?```$', '', response.strip())
    try:
        return json.loads(stripped)
    except JSONDecodeError:
        pass

    # Strategy 3: Extract JSON object
    match = re.search(r'\{[\s\S]*\}', response)
    if match:
        try:
            return json.loads(match.group())
        except JSONDecodeError:
            pass

    # Strategy 4: Partial field extraction
    return extract_partial_fields(response)

def extract_partial_fields(response: str) -> dict:
    """Extract whatever fields we can find"""
    result = {"_parsing_failed": True}

    # Extract status if present
    status_match = re.search(r'"status"\s*:\s*"(finished|needs-input|failed)"', response)
    if status_match:
        result["status"] = status_match.group(1)

    # Extract summary if present
    summary_match = re.search(r'"summary"\s*:\s*"([^"]+)"', response)
    if summary_match:
        result["summary"] = summary_match.group(1)

    # Extract output_paths array
    paths_match = re.search(r'"output_paths"\s*:\s*\[(.*?)\]', response, re.DOTALL)
    if paths_match:
        paths = re.findall(r'"([^"]+)"', paths_match.group(1))
        result["output_paths"] = paths

    return result
```

**Fallback Response**:
When parsing completely fails, construct a minimal valid response:

```json
{
  "status": "failed",
  "output_paths": [],
  "questions": [],
  "summary": "Agent response could not be parsed. Raw response logged for debugging.",
  "tokens_used": 0,
  "next_phase_context": "Previous agent response was malformed. Review logs and retry.",
  "_raw_response": "<truncated first 500 chars of response>",
  "_parsing_error": "<error message>"
}
```

**Recovery Strategies**:

| Scenario | Recovery Action |
|----------|-----------------|
| Partial JSON with status | Honor extracted status, fill missing fields with defaults |
| Output paths extractable | Check if files exist on disk to validate work completed |
| Complete parse failure | Log raw response, retry agent with smaller task scope |
| Repeated failures | Escalate to user with diagnostic information |

**Integration with `needs-input` Invariant**:

> **WARNING**: Recall the critical invariant from the Output Protocol section: `status: "needs-input"` REQUIRES a non-empty `questions` array. When defensively parsing, if you extract `status: "needs-input"` but cannot extract valid questions, treat this as a **parse failure** and use the fallback response. Never allow the workflow to proceed with `needs-input` and empty questions, as this causes workflow deadlock.

**Logging Best Practice**:
Always log parsing failures with context for debugging:
```
[WARN] Agent response parse failed
  workflow_id: feature-auth-20251124
  agent_task: design-session-management
  error: Expecting ',' delimiter at line 42
  raw_length: 15234
  extracted_fields: ["status", "summary"]
```

### For Sub-Agents

**DO**:
- ✅ Validate all context_files exist before reading
- ✅ Apply all questions_answered to your work
- ✅ Stay within token_budget (warn at 80%)
- ✅ Write outputs only to output_location
- ✅ Update STATUS.yaml when complete
- ✅ Return complete, valid output protocol JSON

**DON'T**:
- ❌ Assume context_files exist (validate first)
- ❌ Ignore questions_answered (apply decisions)
- ❌ Exceed token_budget without warning
- ❌ Write outputs to wrong location
- ❌ Return completion without valid JSON
- ❌ Leave summary empty or vague

### Protocol Evolution

**Version Compatibility**:
- Protocol is versioned separately from skill
- Current version: 1.1.0
- Breaking changes increment major version
- Agents should validate protocol version if multiple versions exist
- v1.0.0 outputs remain fully compatible (new fields are optional)

**Version History**:

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-24 | Initial protocol release |
| 1.1.0 | 2025-02-24 | Added optional fields: `protocol_version`, `agent_id`, `confidence`, `handoff`. Added critical warning about `needs-input`/`questions` invariant. |

**Future Considerations**:
- May add status values (e.g., "paused", "cancelled")
- Protocol schema may become strict (validated by tools)
- `handoff` may become preferred over `next_phase_context` in v2.0.0

---

**Communication Protocol Version**: 1.1.0
**Last Updated**: 2025-02-24
**Skill Version**: 2.0.0

**Related Documentation**:
- `orchestrator-guide.md` - How to construct and send input protocol
- `subagent-guide.md` - How to parse and respond with output protocol
- `SKILL.md` - Overview of orchestration framework
