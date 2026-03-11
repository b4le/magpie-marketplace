# Plan Schema

JSON schema contract for the decompose skill's machine-readable output. Downstream execution tools (fan-out, team-spawn, orchestrate) consume this format.

## Output Location

Plans are written to `~/.claude/decompose/plans/{plan-id}/`. Each plan gets its own directory with two files:
- `plan.md` — human-readable markdown
- `plan.json` — machine-readable JSON (this schema)

The `plan-id` is `decompose-{YYYYMMDD}-{HHMMSS}`. If a collision occurs (two decompose runs in the same second), append a 4-character random suffix: `decompose-{YYYYMMDD}-{HHMMSS}-{xxxx}`.

## Top-Level Schema

```json
{
  "schema_version": "1.0",
  "plan_id": "decompose-20260308-143022",
  "created_at": "2026-03-08T14:30:22Z",
  "goal": "Free-text description of the original goal",
  "requirements": ["Extracted requirement 1", "Extracted requirement 2"],
  "source": {
    "type": "inline | file | handoff",
    "path": "optional — file path or handoff path if applicable"
  },
  "project_root": "/absolute/path/to/repo",
  "plan_path": "/absolute/path/to/plan.json",
  "registry_snapshot": {
    "generated_at": "2026-03-08T14:30:10Z",
    "total_capabilities": 42,
    "enabled_capabilities": 38
  },
  "file_manifest": [
    {
      "path": "src/auth/login.ts",
      "action": "create | modify | delete",
      "domain": "typescript",
      "description": "What changes are needed and why",
      "depends_on": ["src/auth/types.ts"],
      "complexity": "low | medium | high",
      "estimated_minutes": 15
    }
  ],
  "work_items": [
    {
      "id": "WI-1",
      "title": "Short descriptive title",
      "scope": "One-sentence scope statement",
      "files": ["src/auth/login.ts", "src/auth/login.test.ts"],
      "agent_config": {
        "subagent_type": "typescript-pro",
        "skills": ["javascript-typescript:javascript-testing-patterns"],
        "model": "sonnet",
        "mode": "acceptEdits",
        "max_turns": 30,
        "missing_specialist": false,
        "isolation": "worktree | none"
      },
      "pipeline": ["Read context files", "Implement changes", "Run tests", "Verify"],
      "inputs": {
        "context_files": ["src/auth/types.ts"],
        "prefetch_paths": []
      },
      "interface_contracts": {
        "exports": ["LoginHandler type from src/auth/login.ts"],
        "imports": ["AuthConfig from src/auth/types.ts (WI-2)"]
      },
      "done_criteria": ["File exists", "Tests pass", "Types compile"],
      "depends_on": ["WI-2"],
      "blocks": ["WI-3"],  // computed inverse of depends_on — for readability only
      "estimated_minutes": 20
    }
  ],
  "execution_phases": [
    {
      "phase": 1,
      "work_items": ["WI-2", "WI-4"],
      "parallel": true,
      "description": "Foundation types and config"
    },
    {
      "phase": 2,
      "work_items": ["WI-1", "WI-3"],
      "parallel": true,
      "description": "Core implementation"
    }
  ],
  "validation": [
    {
      "work_item_id": "WI-1",
      "reviewer_config": {
        "subagent_type": "Explore",
        "skills": ["comprehensive-review"],
        "model": "opus"
      },
      "mode": "after_complete | batch",
      "checks": ["Types compile", "Test coverage adequate", "No security issues"]
    }
  ],
  "summary": {
    "total_work_items": 4,
    "total_files": 8,
    "total_execution_phases": 2,
    "estimated_total_minutes": 65,
    "agent_types_used": ["typescript-pro", "test-runner", "Explore"],
    "missing_specialists": 0
  },
  "execution_status": {
    "started_at": "ISO8601 | null",
    "completed_at": "ISO8601 | null",
    "mode": "fan-out | sequential | team | null",
    "current_phase": "number | null",
    "work_item_status": {
      "WI-1": {
        "status": "pending | in_progress | completed | failed | skipped",
        "agent_name": "string | null",
        "started_at": "ISO8601 | null",
        "completed_at": "ISO8601 | null",
        "error": "string | null",
        "skipped_reason": "string | null",
        "attempt_count": 0
      }
    }
  }
}
```

## Field Constraints

| Field | Required | Notes |
|---|---|---|
| `schema_version` | yes | Always `"1.0"` for this version |
| `plan_id` | yes | Unique, timestamp-based |
| `work_items[].id` | yes | Format: `WI-{N}`, sequential |
| `work_items[].files` | yes | Must be non-empty, no overlaps across items |
| `work_items[].agent_config.subagent_type` | yes | Must match a known agent type |
| `work_items[].depends_on` | no | References other WI ids; creates DAG |
| `work_items[].blocks` | no | Computed inverse of `depends_on`. Present for readability; orchestration derives task dependencies from `depends_on` only |
| `execution_phases` | yes | Topological sort of work_items by dependencies |
| `validation` | yes | One entry per implementation work item |
| `project_root` | no | Absolute POSIX-normalized path (no trailing slash, symlinks resolved via `realpath`) |
| `plan_path` | no | Set once at plan creation; read-only metadata |
| `execution_status` | no | Written by orchestrator only, not decompose. Absence = "not yet started" |
| `execution_status.current_phase` | no | Must equal an `execution_phases[].phase` value — not an array index. `null` when execution has not started |
| `execution_status.mode` | no | Write-once on first non-null set. Set by orchestrator; not written by decompose |
| `agent_config.isolation` | no | `"worktree"` or `"none"`. Unknown values treated as `"none"` with a warning |

## Dispatch-Time Agent Parameters

The following Agent tool parameters are derived at dispatch time and are **not stored in the plan**. The `agent_config` block only captures what the decompose skill can determine statically.

| Parameter | Derived from |
|---|---|
| `name` | Work item id / title |
| `description` | Work item title / scope |
| `prompt` | Assembled from `work-item-template.md` at dispatch |
| `run_in_background` | `true` in fan-out mode; omitted in sequential mode |

## Invariants

Downstream tools may assume these hold:

1. **Single-owner files:** Every path in `file_manifest` appears in exactly one `work_items[].files`
2. **DAG ordering:** `execution_phases` respect all `depends_on` relationships
3. **Complete coverage:** Every `file_manifest` entry maps to a work item
4. **Valid agents:** Every `agent_config.subagent_type` is either a built-in type, a registered agent, or a plugin-provided agent
5. **Validation coverage:** Every work item with `action: "create"` or `action: "modify"` files has a validation entry
6. **Size bounds:** Every work item has 1-8 files and ≤35 min estimated duration
7. **Phase ordering:** `execution_phases` array is a valid topological sort with no circular dependencies
8. **Context-file ownership ordering:** If work_item A lists file F in `inputs.context_files`, and work_item B owns file F (has it in `work_items[].files` with `action: create` or `action: modify`), then A.depends_on must include B, or they must be in different execution phases with B's phase earlier
9. **Work item status referential integrity:** Every key in `execution_status.work_item_status` must correspond to a valid `work_items[].id`. Orchestrator validates at load time
10. **Minimum plan size:** A valid plan must contain at least one work item. Orchestrator rejects empty plans at load time

## Defaults Table

| Field | Default when absent | Rationale |
|---|---|---|
| `project_root` | `null` | No safe inference — consumer must handle null |
| `plan_path` | `null` | Derive from directory convention if needed |
| `execution_status` | `null` | Absence = "not yet started" |
| `execution_status.started_at` | `null` | — |
| `execution_status.completed_at` | `null` | — |
| `execution_status.mode` | `null` | — |
| `execution_status.current_phase` | `null` | Not `0` or `1` — null is unambiguous |
| `execution_status.work_item_status` | `{}` | Empty object — consumers iterate without null-guard |
| `work_item_status[id].status` | `"pending"` | Safe assumption for any WI absent from map |
| `work_item_status[id].agent_name` | `null` | — |
| `work_item_status[id].started_at` | `null` | Written at dispatch time |
| `work_item_status[id].completed_at` | `null` | Written at completion time |
| `work_item_status[id].error` | `null` | — |
| `work_item_status[id].skipped_reason` | `null` | — |
| `work_item_status[id].attempt_count` | `0` | — |
| `work_items[].depends_on` | `[]` | Empty array — no dependencies |
| `source.path` | `null` | Optional — present when source is a file |
| `agent_config.isolation` | `"none"` | Opt-in semantics — existing plans unaffected |

## Schema Evolution Policy

- **Additive-only** (new optional fields with documented defaults): no version bump. Consumers tolerate missing fields.
- **Breaking changes** require bumping `schema_version` to `"2.0"`. Breaking means: field removal, field type change, enum value removal, or semantic redefinition of existing fields.
- Orchestrator validates `schema_version` at load time. Unknown version → hard stop.
- New enum values (e.g., a future `isolation: "container"`) are additive and non-breaking per this policy.
