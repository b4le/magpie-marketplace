---
name: orchestrate
description: Composable pipeline — detect input, optionally brainstorm, decompose into a plan, select dispatch mode, and execute
argument-hint: "[goal | file path] [--brainstorm] [--think] [--store] [--dry-run] [--flat]"
version: 3.0.0
---

## Quick Start

```
/orchestrate "Add user authentication with OAuth2"        # Goal text → decompose → execute
/orchestrate ~/specs/auth-design.md                       # Spec file → decompose → execute
/orchestrate ~/.claude/decompose/plans/decompose-20260309/plan.json  # Existing plan → execute
/orchestrate --brainstorm "improve API performance"        # Brainstorm → decompose → execute
/orchestrate --dry-run "refactor payment module"           # Decompose + plan, skip execution
/orchestrate --store ~/specs/migration.md                  # Decompose + save plan for later
/orchestrate --flat "fix login bug"                        # Sequential mode, no parallelism
/orchestrate                                               # Interactive prompt
```

---

## Instructions

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

Per-item status shapes (`work_item_status[id]` at dispatch and completion, including `attempt_count`) are defined in `{plugin}/references/dispatch-execution.md` § Status Update Protocol.

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
- Map plan JSON `agent_config` fields to Agent tool parameters per `{plugin}/references/agent-config-examples.md`.
- Use `isolation: "worktree"` when the plan specifies it or when agents in the same phase modify files in overlapping directory trees.
- After all agents in a phase return, apply Step 7 before starting next phase.

**Team:**
- Use `/team-spawn` with the plan as input.
- Work items become TaskCreate entries with dependency ordering.
- Reference `{plugin}/references/dispatch-execution.md` for team coordination protocol.

### Step 7: Per-Phase Error Handling

Applied at each phase boundary after all agents in the phase complete.

**7a. Collect results.** For each work item: success/failure, error message, output artifacts.

**7b. Tier 1 verification (hard gate on missing artifacts).**
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

---

## Flag Summary

| Flag | Effect | Stops At |
|------|--------|----------|
| `--brainstorm` | Invoke brainstorm before decompose | — |
| `--store` | Save plan without executing | Step 5e |
| `--dry-run` | Detect + decompose + select mode, skip execution | Step 5d |
| `--flat` | Force sequential mode | — |
| `--think` | Legacy alias for `--brainstorm` | — |

## Error Table

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

## Related

- `/decompose` — 7-phase plan generation (invoked automatically in Step 4)
- `/brainstorm` — Divergent exploration (invoked with `--brainstorm` flag)
- `/team-spawn` — Team coordination (used in Team dispatch mode)
- `references/fan-out-pattern.md` — Parallel execution pattern
- `references/dispatch-execution.md` — Execution mode details
- `references/verification-pattern.md` — Two-tier verification
- `references/mcp-prefetch-pattern.md` — Pre-fetch external data
