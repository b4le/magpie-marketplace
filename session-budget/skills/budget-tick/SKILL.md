---
name: budget-tick
description: >-
  Use when the user marks a task as complete or wants to advance to the next task.
  Trigger phrases: "task done", "next task", "budget tick", "mark complete",
  "finished task", "done with this task", "task complete", "move to next",
  "check off task", "that's done".
allowed-tools:
  - Read
  - Write
  - Glob
version: 1.0.0
last_updated: 2026-03-09
---

# Budget Tick — Mark Task Complete

Update the session budget state when a task is completed.

## Step 1: Find Budget State

Look for the most recent budget state file:

```bash
/tmp/claude-session-budget/*/budget.json
```

Use Glob to find matching files. If no file exists, inform the user:
> "No active session budget found. Use `/session-budget` to create one first."

## Step 2: Read Current State

Use Read to load the budget.json file. Parse the tasks array and find:
- The task currently marked as `"in_progress"` — this is the one being completed
- The next task marked as `"planned"` — this will become `"in_progress"`

If no `"in_progress"` task exists, ask the user which task to mark complete.

## Step 3: Update State

1. Mark the `"in_progress"` task as `"completed"`:
   - Set `status` to `"completed"`
   - Set `completed_at` to the current ISO 8601 timestamp

2. Advance the next `"planned"` task to `"in_progress"`:
   - Set `status` to `"in_progress"`
   - Set `started_at` to the current ISO 8601 timestamp

3. Recalculate point tallies:
   - `points_completed` = sum of points for all `"completed"` tasks
   - `points_in_progress` = sum of points for all `"in_progress"` tasks
   - `points_planned` = sum of points for all `"planned"` tasks

4. Use Write to save the updated budget.json back to the same path.

## Step 4: Report

Present a brief status update:

```
Task completed: {task_name} ({points}pt)
Now working on: {next_task_name} ({next_points}pt)

Budget: {points_completed}/{points_total} points completed
Remaining: {points_planned + points_in_progress} points ({count} tasks)
```

If no more planned tasks remain:
```
Task completed: {task_name} ({points}pt)
All tasks complete! Budget: {points_total}/{points_total} points used.
Consider writing a handoff with /handoff if ending the session.
```

If the completed points reach a threshold (>=7), add a warning:
```
Warning: {points_completed}/{budget_ceiling} points consumed. Consider wrapping up.
```
