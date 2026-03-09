# Dispatch Execution Patterns

Three modes for executing a decomposed plan: sequential (one at a time), fan-out (parallel, ≤5), and team (parallel, >5). Mode selection is deterministic from the plan structure.

## Model

The orchestrator selects exactly one mode per execution run. Mode drives agent spawning, status tracking, and error handling. All modes share the same phase boundary verification protocol and status update schema.

**Mode selection:**

| Condition | Mode |
|-----------|------|
| `--flat` flag set, OR total work items = 1, OR all phases have exactly 1 item | sequential |
| Any phase has 2–5 parallel work items | fan-out |
| Any phase has >5 parallel work items | team |

**Anti-patterns to avoid:**
- Mixing modes within a run — pick once, apply consistently.
- Advancing phases before verification completes — always apply phase boundary checks before dispatching the next phase.
- Auto-retrying on failure — present to the user; do not silently retry.

---

## Sequential Mode

Execute work items one at a time, phase by phase.

### When to Use

- `--flat` flag is set
- Total work items = 1
- All execution phases contain exactly 1 work item

### When NOT to Use

- Multiple independent work items exist in any phase — use fan-out instead
- Work can proceed in parallel without conflict

### Protocol

```
1. Iterate through execution phases in order (phase 1, 2, 3...).

2. Within each phase, execute work items one at a time:
   a. Apply status update: set WI-{id} status → "in_progress"
   b. Spawn a single agent using the Agent tool
   c. Agent receives:
      - Work item scope and done criteria
      - Owned files list
      - Pipeline steps (ordered)
      - project_root context
   d. Map agent_config fields from plan JSON:
      - agent_config.subagent_type → Agent tool subagent_type
      - agent_config.model         → Agent tool model
      - agent_config.isolation     → Agent tool isolation
   e. Wait for agent to return
   f. Apply status update: set WI-{id} status → "completed" or "failed"

3. After all items in a phase complete:
   - Apply phase boundary verification (Tier 1 + Tier 2 per verification-pattern.md)
   - Update execution_status.current_phase in plan.json (atomic write)
   - On verification failure → present to user: retry / skip / stop

4. Advance to next phase.
```

### Guidance for Orchestrators

- There is no parallelism in this mode — do not spawn multiple agents simultaneously.
- Phase boundary verification still applies even with one agent per phase.
- Use this mode when work items have implicit dependencies not captured in the plan, or when the user wants predictable, reviewable execution.

---

## Fan-Out Mode

Spawn agents in parallel within each phase. Cap at 5 concurrent agents.

### When to Use

- Any execution phase contains 2–5 parallel work items
- Default mode when parallelism is detected in the plan

### When NOT to Use

- Any phase exceeds 5 parallel work items — use team mode
- Work items share files and can't be given exclusive ownership
- Phase 0 pre-fetch would block indefinitely (degenerate external dependency)

### Protocol

```
### Phase 0: Pre-Fetch (conditional)
Before Phase 1, check whether any work item needs external data
(MCP queries, shared file reads). If yes:
- Apply mcp-prefetch-pattern.md
- Write results to /tmp/prefetch/{session}/
- Pass file paths to agents, not raw data

### Per Execution Phase:
a. Identify all work items in the phase.

b. Pre-dispatch validation:
   - Verify no two items own overlapping files.
   - If overlap found → merge items or reassign before dispatching.

c. Spawn agents in parallel (single message, multiple Agent tool calls):
   - Cap: 5 concurrent agents maximum
   - Each agent receives:
     - Work item scope and done criteria
     - Owned files list (exclusive to this agent)
     - Pipeline steps (ordered)
     - Input paths (including pre-fetched data from Phase 0)
   - Map agent_config fields from plan JSON:
     - agent_config.subagent_type → Agent tool subagent_type
     - agent_config.model         → Agent tool model
     - agent_config.isolation     → Agent tool isolation
       Use "worktree" when plan specifies it OR when agents in the same
       phase modify files in overlapping directory trees.

d. Wait for all agents in the phase to return.

e. Apply phase boundary verification (per verification-pattern.md).

f. Update plan.json with per-item status (atomic write).

g. If any items failed → present to user (retry / skip / stop).
   Retry re-dispatches only the failed items.

h. Advance to next phase.
```

References: `fan-out-pattern.md` for the general pattern, `mcp-prefetch-pattern.md` for Phase 0.

### Guidance for Orchestrators

- File ownership is a hard constraint. If two items claim the same file, resolve before dispatch — not during.
- Worktrees add overhead. Only use `isolation: "worktree"` when directory trees actually overlap.
- Retry is scoped to failed items only. Completed items in the same phase are not re-run.
- If a phase has exactly 1 item after filtering skipped items, dispatch it sequentially — no need to fan-out.

---

## Team Mode

Delegate work to a spawned team via `/team-spawn` when any phase exceeds 5 parallel work items.

### When to Use

- Any execution phase contains >5 parallel work items

### When NOT to Use

- All phases have ≤5 items — use fan-out
- Work items have tight sequential dependencies — team coordination overhead outweighs gains

### Protocol

```
1. Use /team-spawn to create the team (specify preset from plan if provided).

2. Convert each work item into a TaskCreate entry:
   - subject:     work item title
   - description: work item scope + owned files + pipeline steps + done criteria
   - addBlockedBy: list of task IDs derived from depends_on relationships in the plan

3. Team lead assigns tasks to teammates based on agent_config routing.

4. Teammates execute work items and mark tasks completed via TaskUpdate.

5. Orchestrator monitors via TaskList.
   - Does NOT write execution state directly during team execution.
   - Consolidates from task statuses into plan.json after each phase completes.

6. Phase boundary verification:
   - Wait for all tasks in a phase to reach completed / failed / skipped.
   - Then apply Tier 1 + Tier 2 checks (per verification-pattern.md).
   - Failures: team lead presents to orchestrator → orchestrator presents to user
     (retry / skip / stop).

7. Advance to next phase.
```

### Key Difference from Fan-Out

In fan-out mode, agents return results directly to the orchestrator. In team mode, agents coordinate via TaskList — the orchestrator is an observer that consolidates status into plan.json after phases complete.

### Guidance for Orchestrators

- Do not bypass `/team-spawn` — never call `TeamCreate`, `TeamDelete`, or `SendMessage` directly for team initiation.
- `addBlockedBy` must reflect inter-item dependencies accurately. Team lead cannot infer them from descriptions alone.
- The orchestrator owns plan.json. Teammates own their work items. These responsibilities do not overlap.

---

## Status Update Protocol

Shared across all modes. All writes to plan.json use atomic write (write to `.tmp`, then rename).

**On execution start:**
```json
{
  "execution_status": {
    "started_at": "{ISO 8601}",
    "mode": "{sequential|fan-out|team}",
    "current_phase": 1,
    "work_item_status": {}
  }
}
```

**Per work item — on dispatch:**
```json
{
  "WI-{id}": {
    "status": "in_progress",
    "agent_name": "{agent name or task owner}",
    "started_at": "{ISO 8601}",
    "attempt_count": 1
  }
}
```

**Per work item — on completion (merge into existing entry):**
```json
{
  "WI-{id}": {
    "status": "completed|failed|skipped",
    "completed_at": "{ISO 8601}",
    "error": "{error message if failed, null otherwise}",
    "skipped_reason": "{reason if skipped, null otherwise}",
    "attempt_count": "{N, carried from dispatch, incremented on retry}"
  }
}
```

**On execution complete:**
```json
{
  "execution_status": {
    "completed_at": "{ISO 8601}"
  }
}
```

---

## Error Handling at Phase Boundaries

Applied after all work items in a phase complete, before advancing. Shared across all modes.

1. **Collect results.** Record success / failure / error per work item.
2. **Tier 1 (hard gate).** Expected output files exist and are non-empty. Validator scripts pass if specified in `done_criteria`. Failure = stop, report what's missing.
3. **Tier 2 (soft gate).** Output quality reviewed against stated scope. One self-correction retry allowed. See `verification-pattern.md`.
4. **On failure.** Never auto-retry. Present to user:

   ```
   WI-{id} failed: {error}. Retry, skip, or stop?
   ```

   | User choice | Action |
   |-------------|--------|
   | Retry | Re-dispatch failed item only. Re-verify after completion. |
   | Skip | Mark item as `skipped`. Flag downstream dependents as blocked. |
   | Stop | Halt execution. Write current state to plan.json. |

5. **On success.** Advance to next phase.
