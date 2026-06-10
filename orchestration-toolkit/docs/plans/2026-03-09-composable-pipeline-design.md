# Composable Pipeline Design: brainstorm → decompose → execute

**Created:** 2026-03-09
**Status:** All steps (0-5) complete — pipeline fully implemented
**Scope:** Wire brainstorm, decompose, and execution dispatch into a single composable pipeline via an upgraded `/orchestrate` command

> **Plugin root:** `~/Personal/personal-marketplaces/magpie-marketplace/orchestration-toolkit/`
> Paths prefixed with `{plugin}/` refer to this directory. Files are symlinked into `~/.claude/` for runtime access.

---

## 1. Overview

This design upgrades `/orchestrate` from a workflow initializer (creating YAML state files and `.development/workflows/` directories) into a **thin router** that detects input type, optionally invokes brainstorm, chains to `/decompose` to produce a structured plan, selects a dispatch mode, and executes. The plan JSON file is the contract between stages — each skill reads and writes independently, and the orchestrator validates but does not transform.

The goal is a single entry point (`/orchestrate`) that handles the full lifecycle from fuzzy goal to parallel execution, replacing the current fragmented workflow of manually invoking brainstorm → decompose → fan-out/team-spawn as separate steps.

All design decisions are locked after four independent reviews (architect, setup audit, prompt engineer, AI data engineer).

---

## 2. Architecture

### Flow

```
/orchestrate $INPUT → parse flags → detect input type → route:

  No argument        → interactive prompt → re-enter detection
  --brainstorm       → brainstorm skill → /decompose → dispatch
  Goal text          → /decompose → dispatch
  Spec/design file   → /decompose → dispatch
  Plan JSON file     → skip to dispatch
  Handoff file       → extract scope → /decompose → dispatch
```

Dispatch modes (detected from plan shape):
```
  1 work item / all phases have 1 item  → Sequential
  Any phase has 2-5 parallel items      → Fan-out (default)
  Any phase has >5 parallel items       → Team
  --store flag                          → Store (save, don't execute)
```

### What Changes

| Component | Change |
|---|---|
| `/orchestrate` | Full rewrite — thin router with input detection, decompose invocation, dispatch mode selection, execution |
| `/decompose` | Output path → `~/.claude/decompose/plans/{plan-id}/`, Phase 2 registry optimization, Phase 3b concrete examples |
| `/handoff` | Add optional `## Plan Reference` section |
| `/resume` | Detect plan reference, surface as context |
| `/delegate` | Update routing table to reference `/orchestrate` for pipeline work |
| `plan-schema.md` | Add `execution_status`, `isolation`, `project_root`, `plan_path` fields |
| `.development/workflows/` | Deprecated and removed (migration script provided) |

### What Stays the Same

- `/decompose` 7-phase workflow — unchanged except output path and targeted optimizations
- Plan JSON schema v1.0 — additive changes only, no version bump
- Fan-out pattern — referenced, not inlined
- Verification pattern — two-tier checks at phase boundaries
- MCP pre-fetch pattern — applied in Phase 0 of fan-out execution
- Agent config → tool call mapping — unchanged

### Component Boundaries

```
┌─────────────────────────────────────────────────────────┐
│ /orchestrate (thin router)                              │
│                                                         │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌───────┐  │
│  │ Input    │→ │ Brainstorm│→ │/decompose│→ │Dispatch│  │
│  │ Detection│  │ (opt-in)  │  │ (7-phase)│  │ Engine │  │
│  └──────────┘  └───────────┘  └──────────┘  └───────┘  │
│       ↓                            ↓            ↓       │
│  file/text                    plan.json    agents/teams  │
└─────────────────────────────────────────────────────────┘
                                     ↓
                    ~/.claude/decompose/plans/{id}/
                    ├── plan.json   (machine-readable)
                    └── plan.md     (human-readable)
```

The orchestrator validates at boundaries but does not transform data between stages. Each stage reads its input and writes its output independently.

---

## 3. Decisions

All decisions are locked. Do not re-debate.

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Glue between steps | Hybrid: plan JSON file contract + thin orchestrator | Consensus across major frameworks (Anthropic, Google ADK, CrewAI, LangGraph). Each skill reads/writes independently. Orchestrator validates but doesn't transform. |
| 2 | Dispatch mode selection | Detect capabilities + recommend at runtime | Plan stays mode-agnostic. Orchestrate checks what's available and presents viable options. |
| 3 | Agent assignment UX | Summary table + single confirm/override | Low friction. One interaction point. Easy to scan and tweak. |
| 4 | Cross-session state | Plans are passive artifacts. Handoff loosely references them. New sessions discuss context first. | User explicitly said: don't push plans on new sessions. Discussion comes before execution. |
| 5 | Skill shape | Merge into upgraded `/orchestrate`. No new skill. | Setup audit found `/orchestrate` already exists with overlapping scope. Rewriting avoids reinvention. |
| 6 | Brainstorm flexibility | Bring-your-own. Brainstorm is opt-in (`--brainstorm`), not mandatory. | Orchestrate doesn't mandate any brainstorm tool. If input is a raw goal, default to decompose-directly. |
| 7 | Plan namespace | `~/.claude/decompose/plans/{plan-id}/` | Own top-level dir under decompose. Room for future decompose artifacts. Each plan gets a folder (plan.json + plan.md). |
| 8 | Orchestrate doesn't own execution state | Fan-out / team-spawn track their own execution. Orchestrate writes `execution_status` to plan.json as an observer. | Keeps orchestrate thin. Execution layer reports back, orchestrate records in plan. |

---

## 4. Orchestrate Command Spec

The `/orchestrate` command is a thin router. It detects input type, optionally invokes brainstorm, chains to `/decompose` to produce a plan, selects a dispatch mode, and executes. It does not transform input or own execution state.

### Step 1: Parse Flags

Strip recognized flags from `$ARGUMENTS` before input detection. Flags can appear anywhere in the argument string.

1. If `--brainstorm` is present: set `BRAINSTORM=true`, remove from arguments.
2. If `--think` is present: treat as legacy alias for `--brainstorm`. Set `BRAINSTORM=true`, remove.
3. If `--store` is present: set `STORE_ONLY=true`, remove.
4. If `--dry-run` is present: set `DRY_RUN=true`, remove.
5. If `--flat` is present: set `FORCE_MODE=sequential`, remove.
6. After stripping, the remaining string is `$INPUT`.

### Step 2: Detect Input Type

Apply the following checks in order. **First match wins. No fallthrough.**

**2a. No argument.**
If `$INPUT` is empty and `BRAINSTORM` is false:
- Prompt the user: "What would you like to build or work on?"
- Wait for response. The response becomes `$INPUT`.
- Re-enter Step 2 with the new `$INPUT`.

**2b. Brainstorm with no seed text.**
If `$INPUT` is empty and `BRAINSTORM` is true:
- Set `INPUT_TYPE=brainstorm_empty`.
- Proceed to Step 3.

**2c. Argument looks like a file path.**
Test: `$INPUT` contains a `/` character OR matches `*.*` (dot preceded by non-whitespace). If true:

- **2c-i. File does not exist.** Run `test -f "$INPUT"`. If false → treat as goal text. Set `INPUT_TYPE=goal`.
- **2c-ii. File exists — plan JSON.** Read first 5 lines. If any line contains `"schema_version"` OR `head -c 4096 | jq '.work_items' 2>/dev/null` succeeds → set `INPUT_TYPE=plan`, `PLAN_PATH=$INPUT`. **Skip to Step 5.**
- **2c-iii. File exists — handoff.** First line is exactly `# Session Handoff` → set `INPUT_TYPE=handoff`. Extract scope from `## What's not done` + constraints from `## Key decisions made`.
- **2c-iv. File exists — spec/design doc.** Anything else → set `INPUT_TYPE=spec`, `SPEC_PATH=$INPUT`.

**2d. Any other text.**
If none matched → set `INPUT_TYPE=goal`, `GOAL_TEXT=$INPUT`.

### Step 3: Brainstorm (When Opted In)

Skip unless `BRAINSTORM=true`.

1. If `INPUT_TYPE=brainstorm_empty`: invoke brainstorm with no seed. Explore scope, constraints, edge cases.
2. Otherwise: invoke brainstorm with detected input as seed context.
3. Capture output as `$BRAINSTORM_OUTPUT` — a refined goal statement + optional constraint list.
4. Set `DECOMPOSE_INPUT=$BRAINSTORM_OUTPUT`.

If `BRAINSTORM=false`: set `DECOMPOSE_INPUT` to raw input (`$GOAL_TEXT`, spec file content, or extracted handoff scope).

### Step 4: Decompose

Skip if `INPUT_TYPE=plan` (plan JSON already exists).

1. Invoke `/decompose` with `$DECOMPOSE_INPUT` as the goal.
   - If `INPUT_TYPE=spec`: pass the spec file path for decompose to read.
   - If `INPUT_TYPE=handoff`: pass both extracted scope and full handoff path for context.
2. Decompose produces plan at `~/.claude/decompose/plans/{plan-id}/plan.json`.
3. **Tier 1 verification:** Confirm `plan.json` exists, valid JSON, `work_items` array has ≥1 item. Hard stop on failure.
4. **Tier 2 verification:** Review that work item scopes collectively cover the stated goal. Flag gaps but don't block.
5. Set `PLAN_PATH` to the generated plan file.

### Step 5: Select Dispatch Mode

Read the plan at `$PLAN_PATH`. Extract work items and execution phases.

**5a. Compute mode recommendation.** First match wins:

| Condition | Mode |
|-----------|------|
| `FORCE_MODE` is set (from `--flat`) | Use `FORCE_MODE` |
| `STORE_ONLY=true` | **Store** |
| Total work items = 1 | **Sequential** |
| All phases contain exactly 1 work item | **Sequential** |
| Any phase contains 2-5 parallel items | **Fan-out** |
| Any phase contains >5 parallel items | **Team** |

If multiple phases qualify for different modes, select the highest: Sequential < Fan-out < Team.

**5b. Pre-dispatch validation.** Before presenting the summary:
- Verify no two work items in the same phase own overlapping files.
- Verify all `work_item_status` keys (if present) reference valid work item IDs.
- If `project_root` is set, verify all file paths resolve within it.

**5c. Build summary table.**

```
Plan: {plan_id}
Goal: {goal, first 100 chars}
Mode: {selected mode}

| WI   | Title              | Agent           | Model  | Phase | Est.  |
|------|--------------------|-----------------|--------|-------|-------|
| WI-1 | Auth middleware     | typescript-pro  | sonnet | 1     | 15m   |
| WI-2 | Database migration  | implementation  | sonnet | 1     | 20m   |
| WI-3 | Integration tests   | test-runner     | haiku  | 2     | 10m   |

Proceed with {mode}? (override any row, switch modes, or edit plan at {path})
```

For plans with >15 work items, group by phase rather than listing flat.

**5d. Handle `--dry-run`.** Display summary and stop. "Dry run complete. Plan saved at {PLAN_PATH}."

**5e. Handle `--store`.** Display summary and stop. "Plan stored at {PLAN_PATH}. Run `/orchestrate {PLAN_PATH}` to execute later."

**5f. Wait for user confirmation.** User may:
- **Confirm** → proceed to Step 6
- **Override a row** → update agent/model/scope in plan.json, re-display
- **Switch modes** → set `FORCE_MODE`, re-display
- **Edit plan** → user edits file directly, re-run from Step 5

### Step 6: Execute by Mode

Initialize `execution_status` in plan.json before dispatching:
```json
{
  "execution_status": {
    "started_at": "{ISO 8601}",
    "mode": "{selected mode}",
    "current_phase": 1,
    "work_item_status": {}
  }
}
```

Use atomic writes (write to `.tmp`, rename) when updating plan.json during execution.

Execution logic is **not inlined**. Each mode references its pattern document:

**Sequential:**
- Execute work items in phase order, one at a time.
- Each agent receives the work item prompt (populated from plan JSON via the template in `references/work-item-template.md`).
- Wait for completion before starting the next.
- Apply phase boundary verification (Step 7) between phases.

**Fan-out:**
- Follow `{plugin}/references/fan-out-pattern.md`.
- Phase 0: if any work item needs external data, apply `{plugin}/references/mcp-prefetch-pattern.md`.
- Spawn one agent per work item within a phase. Cap at 5 concurrent.
- Map plan JSON `agent_config` fields to Agent tool parameters per `references/agent-config-examples.md`.
- Use `isolation: "worktree"` when the plan specifies it or when agents in the same phase modify files in overlapping directory trees.
- After all agents in a phase return, apply Step 7 before starting next phase.

**Team:**
- Use `/team-spawn` with the plan as input.
- Work items become TaskCreate entries with dependency ordering.
- Reference `{plugin}/references/dispatch-execution.md` for team coordination protocol.

### Step 7: Per-Phase Error Handling

Applied at each phase boundary after all agents in the phase complete.

**7a. Collect results.** For each work item: success/failure, error message, output artifacts.

**7b. Tier 1 verification (hard stop on missing artifacts).**
- Check that expected output files exist and are non-empty.
- Run validator scripts if specified in `done_criteria`.
- Failed checks → mark work item as `failed`.

**7c. Tier 2 verification (soft gate, one retry).**
- Review output against the work item's stated scope.
- If quality insufficient → one self-correction attempt. Failed second attempt → mark as `failed`.

**7d. Handle failures.** If any work items failed:
- Log: `WI-{id} failed: {error}`
- **Never auto-retry.** Present to user:
  ```
  WI-3 failed: {error}. Retry, skip, or stop?
  ```
- **Retry:** Re-dispatch failed item only, re-run Step 7 for it.
- **Skip:** Mark as `skipped` in plan.json. Downstream dependents are flagged as blocked.
- **Stop:** Halt execution. Write current state to plan.json.

**7e. Proceed.** If all passed (or user chose skip), advance to next phase.

### Step 8: Post-Execution Status Update

After all phases complete or execution is halted:

1. Update plan.json:
   - `execution_status.completed_at`: ISO 8601 timestamp
   - Per work item: `status` → `completed`, `failed`, or `skipped`
2. If all completed: `"All {N} work items completed successfully."`
3. If partial/stopped: summary of what completed + what didn't + plan path for resumption.
4. Plans persist at their path — never auto-deleted or archived.

### Flag Summary

| Flag | Effect | Stops At |
|------|--------|----------|
| `--brainstorm` | Invoke brainstorm before decompose | — |
| `--store` | Save plan without executing | Step 5e |
| `--dry-run` | Detect + decompose + select mode, skip execution | Step 5d |
| `--flat` | Force sequential mode | — |
| `--think` | Legacy alias for `--brainstorm` | — |

### Error Table

| Error | When | Response |
|-------|------|----------|
| `/decompose` fails | Step 4, Tier 1 | Hard stop. Report error. User retries or provides plan file directly. |
| Plan has no `work_items` | Step 5 | Hard stop. `"Plan at {path} has no work_items. Fix or re-run /decompose."` |
| Plan has 0 valid work items | Step 5b | Hard stop. Surface to user before dispatch. |
| Agent spawn fails | Step 6 | Mark work item as failed. Present at phase boundary (Step 7d). |
| All agents in phase fail | Step 7d | Present failures. Recommend `stop` to investigate. |
| Plan file not writable | Step 8 | Warn but don't fail. Output status to terminal. |
| Schema version mismatch | Step 5 (plan load) | Hard stop if `schema_version` > supported. Warn if unknown optional fields present. |

---

## 5. Schema Changes

### New Fields (all optional, additive — no version bump)

Added to the plan JSON schema at `references/plan-schema.md`:

#### Top-level fields

```json
{
  "project_root": "/absolute/path/to/repo",
  "plan_path": "/absolute/path/to/plan.json"
}
```

- `project_root`: Absolute POSIX-normalized path (no trailing slash, symlinks resolved at write time via `realpath`). Enables cross-session path resolution. Orchestrator includes in every agent's prompt as a constraint when set.
- `plan_path`: Set once at plan creation. Read-only metadata — do not mutate. Moving plans is unsupported.

#### execution_status (top-level)

```json
{
  "execution_status": {
    "started_at": "ISO8601 | null",
    "completed_at": "ISO8601 | null",
    "mode": "fan-out | sequential | team | null",
    "current_phase": 1,
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

Written by the orchestrator only (not decompose). In team mode, agents report via TaskList and orchestrator consolidates. `mode` is write-once on first non-null set.

`current_phase` must equal an `execution_phases[].phase` value, not an array index.

#### isolation in agent_config

```json
{
  "agent_config": {
    "isolation": "worktree | none"
  }
}
```

Set in Phase 5 of decompose when same-directory overlap exists between parallel work items. Consumers must treat unknown values as `"none"` with a warning.

### Defaults Table

| Field | Default when absent | Rationale |
|---|---|---|
| `project_root` | `null` | No safe inference — consumer must handle null |
| `plan_path` | `null` | Same — derive from directory convention if needed |
| `execution_status` | `null` | Absence = "not yet started" |
| `execution_status.started_at` | `null` | — |
| `execution_status.completed_at` | `null` | — |
| `execution_status.mode` | `null` | — |
| `execution_status.current_phase` | `null` | Not `0` or `1` — null is unambiguous |
| `execution_status.work_item_status` | `{}` | Empty object — consumers iterate without null-guard |
| `work_item_status[id].status` | `"pending"` | Safe assumption for any WI absent from map |
| `work_item_status[id].agent_name` | `null` | — |
| `work_item_status[id].error` | `null` | — |
| `work_item_status[id].skipped_reason` | `null` | — |
| `work_item_status[id].attempt_count` | `0` | — |
| `agent_config.isolation` | `"none"` | Opt-in semantics — existing plans unaffected |

### New Invariants

Added to the existing invariants in `plan-schema.md` (Invariants 1-7 cover: single-owner files, DAG ordering, complete coverage, valid agents, validation coverage, size bounds, agent validity):

**Invariant 8 — Context-file ownership ordering:**
If work_item A lists file F in `inputs.context_files`, and work_item B owns file F (has it in `work_items[].files` with `action: create` or `action: modify`), then A.depends_on must include B, or they must be in different execution phases with B's phase earlier.

**Invariant 9 — Work item status referential integrity:**
Every key in `execution_status.work_item_status` must correspond to a valid `work_items[].id`. Orchestrator validates at load time.

**Invariant 10 — Minimum plan size:**
A valid plan must contain at least one work item. Orchestrator rejects empty plans at load time.

### Schema Evolution Policy

- **Additive-only** (new optional fields with documented defaults): no version bump. Consumers tolerate missing fields.
- **Breaking changes** require bumping `schema_version` to `"2.0"`. Breaking means: field removal, field type change, enum value removal, or semantic redefinition of existing fields.
- Orchestrator validates `schema_version` at load time. Unknown version → hard stop.
- New enum values (e.g., a future `isolation: "container"`) are additive and non-breaking per this policy.

---

## 6. Decompose Changes

Three targeted changes to the existing `/decompose` skill. The 7-phase workflow is unchanged.

### 6a. Output Path Migration

**Current:** `{project}/.claude/plans/` or `~/.claude/plans/`
**New:** `~/.claude/decompose/plans/{plan-id}/`

Each plan gets its own directory:
```
~/.claude/decompose/plans/decompose-20260309-143022/
├── plan.json
└── plan.md
```

The `plan-id` format remains `decompose-{YYYYMMDD}-{HHMMSS}`. If a collision occurs (two decompose runs in the same second), append a 4-character random suffix.

### 6b. Phase 2 Optimization: Registry Access

**Problem:** Phase 2 reads the full `capabilities.json` (264KB, ~33K tokens) — consuming ~16% of context window.

**Fix:** Replace the full file read with targeted Grep-based search:
1. After running `build-capability-registry.sh --quiet`, do NOT read the full file.
2. Instead, Grep the registry for specific domain tags relevant to the goal's identified domains.
3. Example: for a TypeScript + SQL goal, search for `"typescript"`, `"sql"`, `"database"` domain tags.
4. Only read matching entries, not the entire registry.

This reduces registry context from ~33K tokens to ~2-5K tokens depending on domain count.

### 6c. Phase 3b: Concrete Agent Tool Call Example

**Problem:** Phase 3b currently uses pseudocode (`For each domain cluster:`) that LLMs struggle to follow reliably.

**Fix:** Replace the pseudocode with a concrete Agent tool call example:

```
For each domain identified in Step 3a, spawn a specialist sub-agent:

Agent tool call:
  name: "explore-{domain}"
  subagent_type: {best Explore-capable specialist from registry}
  model: "haiku"
  description: "Explore {domain} files for {goal}"
  prompt: |
    You are exploring the {domain} portion of this codebase for:
    Goal: {goal}
    Requirements: {relevant requirements}

    Your task:
    1. Read the files in {relevant directories}
    2. For each file that needs changes, produce a manifest entry:
       - path, action (create|modify|delete), description, depends_on[], complexity
    3. Flag realistic gotchas and hidden dependencies

    Return a JSON array of manifest entries.

Collect all specialist outputs. Merge into a single file manifest.
Resolve cross-domain dependencies (e.g., frontend → backend API types).
```

The `when to use specialists vs. self` threshold (≤2 domains or ≤5 files → skip sub-agents) remains unchanged.

---

## 7. Peripheral Changes

### 7a. Handoff: Plan Reference Section

Add an optional `## Plan Reference` section to the handoff template, placed after `## Key decisions made`:

```markdown
## Plan Reference
- **Plan ID:** {plan-id}
- **Path:** {absolute path to plan.json}
- **Status:** {execution_status summary — e.g., "3/5 items completed, WI-4 failed"}
- **Timestamp:** {plan's execution_status.started_at or created_at}
```

Written only when the session used a decompose plan. Omitted otherwise (no empty section).

### 7b. Resume: Plan Detection

When `/resume` reads a handoff file:
1. Check for `## Plan Reference` section.
2. If present, extract the plan path.
3. Verify the plan file still exists at that path.
4. If it exists, compare the plan's current `execution_status` against the handoff timestamp. Surface a delta:
   ```
   Plan reference: decompose-20260309-143022
   Status at handoff: 3/5 completed
   Current status: 4/5 completed (1 item progressed since handoff)
   ```
5. Include in the resume summary under a `### Plan Context` heading.
6. Do NOT auto-execute. The plan is informational — the user decides whether to continue.

### 7c. Delegate: Routing Update

Update `/delegate`'s routing guidance to reference `/orchestrate` for multi-step pipeline work:

- When the task requires decomposition + parallel execution → recommend `/orchestrate`
- When the task is a single delegation to one agent → `/delegate` handles directly
- When the task matches a team preset → `/delegate` can suggest `/team-spawn` OR `/orchestrate`

This is a documentation change to `/delegate`'s routing table, not a behavioral change.

---

## 8. Review Findings

Consolidated findings from four independent reviews (architect, setup audit, prompt engineer, AI data engineer) plus validation-stage findings from the architect and schema review agents.

### Critical (addressed in this design)

The original four reviews identified 4 critical findings. Three additional findings were elevated to critical during architecture and schema validation (C5-C7).

| # | Finding | Resolution | Section |
|---|---------|------------|---------|
| 1 | `execution_status` field needed for resumability | Added to schema with per-item status, timestamps, errors, attempt_count | §5 |
| 2 | Input detection must be deterministic | First-match-wins algorithm with `test -f`, `head`, `jq` checks | §4 Step 2 |
| 3 | capabilities.json eats 33K tokens in Phase 2 | Changed to Grep-based domain search | §6b |
| 4 | Dispatch step needs concrete prompt, not reference doc | Full step-numbered spec in §4, execution patterns in reference files | §4 |
| 5 | Schema validation ownership undefined | Orchestrator validates schema_version at plan load time, before dispatch | §4 Step 5 |
| 6 | File write conflicts in fan-out unhandled | Pre-dispatch validation checks overlapping files in same phase | §4 Step 5b |
| 7 | Fan-out/Team boundary ambiguity (per-phase vs total count) | Phases execute sequentially; per-phase count determines mode | §4 Step 5a |

### High Priority (addressed in this design)

| # | Finding | Resolution | Section |
|---|---------|------------|---------|
| 8 | No `isolation` field for worktree decisions | Added to `agent_config` | §5 |
| 9 | Handoff doesn't reference plans | Added `## Plan Reference` section | §7a |
| 10 | No `project_root` for cross-session paths | Added to schema, normalized via `realpath` | §5 |
| 11 | Error/failure handling unspecified | Per-phase protocol: log, continue, present, user decides | §4 Step 7 |
| 12 | Phase 3b pseudocode unreliable for LLMs | Concrete Agent tool call example | §6c |
| 13 | `execution_status` write conflicts in team mode | Only orchestrator writes plan.json; agents report via TaskList | §5 |
| 14 | `plan_path` self-referential risk | Set once at creation, read-only, atomic writes for updates | §5 |
| 15 | Brainstorm output has no defined contract | Brainstorm produces refined goal + constraints; passed as text to decompose | §4 Step 3 |
| 16 | `work_item_status` keys need referential validation | Added as Invariant 9 | §5 |
| 17 | Empty plan (0 work items) unhandled | Added as Invariant 10 + post-decompose gate | §5, §4 Step 4 |
| 18 | `current_phase` off-by-one risk | Must equal `execution_phases[].phase` value, not array index | §5 |

### Medium Priority (addressed or scoped)

| # | Finding | Resolution |
|---|---------|------------|
| 19 | Orchestrate could become God object (6 responsibilities) | Input detection stays inline (small). Dispatch execution extracted to `references/dispatch-execution.md`. |
| 20 | Schema evolution needs precise "breaking" definition | Defined: removal, type change, enum removal, semantic redefinition |
| 21 | `done_criteria` lack verification commands | Deferred — current prose criteria work for LLM agents. Optional `command`/`type` fields added in future. |
| 22 | `summary` block becomes stale during execution | Documented as plan-time metadata only, not live counts |
| 23 | >15 work items unwieldy in summary table | Group by phase for large plans |
| 24 | Decompose output path change needs migration | Migration script in Step 5 of implementation plan |
| 25 | `.development/workflows/` deprecation needs grep before removal | Search step added to cleanup implementation |
| 26 | No `skipped_reason` field | Added to schema |
| 27 | Phases execute sequentially — made explicit | Stated in §4 Step 6: phases run in dependency order, one at a time |
| 28 | `project_root` needs normalization rule | Absolute POSIX path, no trailing slash, symlinks resolved |

### Low Priority (documented, deferred)

See §10 (Open Items).

---

## 9. Implementation Plan

Five steps, ordered by dependency. Each step is independently testable.

### Step 0: Schema Fixes

**Effort:** Small (1 session)
**Status: Complete**
**Files:** `{plugin}/skills/decompose/references/plan-schema.md`

- Add `execution_status`, `isolation`, `project_root`, `plan_path` fields with defaults table
- Add Invariants 8, 9, 10 (context-file ordering, referential integrity, minimum size)
- Add `skipped_reason` and `attempt_count` to work item status
- Document schema evolution policy with precise "breaking" definition
- Document `current_phase` must reference `execution_phases[].phase` value

### Step 1: Decompose Path Migration + Optimizations

**Effort:** Medium (1-2 sessions)
**Status: Complete**
**Files:** `{plugin}/skills/decompose/SKILL.md`, `{plugin}/skills/decompose/references/plan-schema.md`

- Change output path to `~/.claude/decompose/plans/{plan-id}/`
- Add collision handling (random 4-char suffix)
- Phase 2: Replace full registry read with Grep-based domain search
- Phase 3b: Replace pseudocode with concrete Agent tool call example
- Verify: decompose a sample goal, confirm new path + smaller registry footprint

### Step 2: Rewrite Orchestrate

**Effort:** Large (2-3 sessions)
**Status: Complete**
**Files:** `{plugin}/commands/orchestrate.md`, `{plugin}/references/dispatch-execution.md` (new)

- Replace entire orchestrate command with the spec from §4
- Input detection: first-match-wins with deterministic checks
- Brainstorm opt-in via `--brainstorm`
- Extract dispatch execution patterns to `{plugin}/references/dispatch-execution.md`
- Add `--dry-run` and `--store` flags
- Map legacy flags: `--flat` → sequential, `--think` → `--brainstorm`
- Verify: test each input type (goal, spec, plan JSON, handoff, no arg)

### Step 3: Dispatch Modes

**Effort:** Medium (1-2 sessions per mode)
**Files:** `{plugin}/commands/orchestrate.md`, `{plugin}/references/dispatch-execution.md`

Implement in order:
1. **Fan-out** — highest value, parallel phases. References `{plugin}/references/fan-out-pattern.md`.
2. **Sequential** — simplest, always available. Single-agent phase-by-phase.
3. **Team** — TaskCreate-based coordination. References `/team-spawn`.
4. **Store** — save plan without executing.

Each mode includes per-phase error handling (Step 7 of spec) and post-execution status update (Step 8).

### Step 4: Peripheral Updates

**Effort:** Small (1 session)
**Status: In progress**
**Files:** `~/.claude/skills/handoff/SKILL.md`, `~/.claude/skills/resume/SKILL.md`, routing docs

- Handoff: add `## Plan Reference` section
- Resume: detect plan reference, surface delta
- Delegate: update routing table
- Verify: create a handoff with plan reference, resume it, confirm delta display

### Step 5: Cleanup

**Effort:** Small (1 session)

- Migration script: move existing plans from `~/.claude/plans/` → `~/.claude/decompose/plans/`
- Grep for `.development/workflows/` references before removal
- Remove `.development/workflows/` directory structure
- Remove orchestrate's YAML state model (`workflow-state.yaml`)
- Update any cross-references in CLAUDE.md or memory files

---

## 10. Open Items

Documented for future consideration. Not in scope for this implementation.

| # | Item | Notes |
|---|------|-------|
| 1 | `interface_contracts` are free-text | Works for LLMs, not machine-verifiable. Could structure as `{ symbol, type, file, from_work_item }` later. |
| 2 | Post-execution git diff | Catches unauthorized file changes. Good defense-in-depth for non-worktree execution. |
| 3 | Prerequisites field | Per-work-item commands/env vars needed. Lower priority. |
| 4 | Plan archival | Move completed plans to `archive/` subdirectory. |
| 5 | `--dry-run` integration testing | Flag is implemented in Step 2. Full end-to-end testing across all dispatch modes deferred to Step 3. |
| 6 | `context_file_hashes` | SHA256 for drift detection. Defense-in-depth. |
| 7 | `validation_status` tracking | No status tracking for review/validation pass/fail in `execution_status`. Add when validation becomes more automated. |
| 8 | `worktree_path` in work item status | For resume to attach to existing worktrees. Add when worktree isolation is battle-tested. |
| 9 | `error_history` array | Full history of attempts/errors per work item. Add when retry logic matures. |
| 10 | `--unattended` flag | For CI-like contexts where retry prompts aren't viable. Failures log and halt. |
| 11 | `execution_summary` block | Live counts (completed/failed/skipped/pending) under `execution_status`. Currently derivable from `work_item_status`. |
