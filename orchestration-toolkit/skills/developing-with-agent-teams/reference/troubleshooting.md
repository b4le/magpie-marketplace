# Troubleshooting Reference

Common issues and solutions when working with agent teams.

## Teams Not Working

**Symptom:** TeamCreate fails, or team features not available.

**Solution:** Enable the experimental flag:

```json
// settings.json or .claude/settings.local.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Restart Claude Code after adding.

## MCP Tools Failing in Agents

**Symptom:** Spawned agents cannot access MCP tools (Groove, Aika, code-search, etc.).

**Causes and solutions:**

1. **Background agent:** Background agents cannot access MCP tools. Use `run_in_background=False`.
2. **Orchestrator calling MCP directly:** The orchestrator must never call MCP tools directly — delegate to foreground sub-agents using the dual return pattern (write raw results to `local-state/prefetch/{session}/`, return summary + path).

```python
# Wrong — orchestrator fetches directly or agent runs in background
Task(description="Research using Aika...")

# Correct — foreground sub-agent with dual return
Task(
    description="Fetch Aika results, write to local-state/prefetch/{session}/, return summary + path",
    run_in_background=False
)
```

See `references/mcp-prefetch-pattern.md` for the full protocol.

## Agent Context Lost

**Symptom:** Agent doesn't remember previous context or decisions.

**Solutions:**

1. **Use shared context file:**
   Write key context to `.development/{project}/shared/context.md`
   Include in agent prompts: "Read shared/context.md first"

2. **Use phase summaries:**
   Previous phase outputs should be summarized, not raw-dumped
   Point agents to synthesis files, not all raw outputs

3. **Include explicit instructions:**
   Tell agents what files to read at start of prompt

## Stuck Tasks

**Symptom:** Tasks remain `pending` when they should be `in_progress`.

**Solutions:**

1. **Check dependencies:**
   ```python
   TaskGet(taskId="stuck-task-id")
   # Look at blockedBy list
   ```

2. **Resolve blockers:**
   - Complete blocking tasks
   - Or remove dependency if no longer needed

3. **Manual update:**
   ```python
   TaskUpdate(taskId="stuck-task-id", status="in_progress")
   ```

## Agents Not Responding

**Symptom:** Agent spawned but no output appears.

**Solutions:**

1. **Check task status:**
   ```python
   TaskList()
   ```

2. **Agent may be working:**
   Long tasks take time—check if agent is still processing

3. **Spawn new agent:**
   If agent truly stuck, spawn replacement with same task

## Workflow State Out of Sync

**Symptom:** `workflow-state.yaml` doesn't match actual progress.

**Solution:** Manually update the file:

```yaml
# .development/{project}/workflow-state.yaml
status: in_progress
current_phase: execution
phases:
  - name: planning
    status: completed
  - name: execution
    status: in_progress
```

## SendMessage Not Delivered

**Symptom:** Messages sent but recipient doesn't see them.

**Solutions:**

1. **Check recipient name:**
   Use exact agent name, not UUID

2. **Verify agent is running:**
   Shutdown agents can't receive messages

3. **Check message type:**
   `type: "message"` for direct, `type: "broadcast"` for all

## Team Cleanup Failed

**Symptom:** TeamDelete fails or team persists.

**Solutions:**

1. **Shutdown agents first:**
   ```python
   SendMessage(type="shutdown_request", recipient="agent-1", ...)
   # Wait for confirmation
   TeamDelete(teamName="project-team")
   ```

2. **Force delete:**
   If agents won't shutdown, TeamDelete should still work

3. **Manual cleanup:**
   Team state is in `.development/`—can be deleted manually

## Phase Transition Issues

**Symptom:** Workflow stuck between phases.

**Solutions:**

1. **Check all tasks complete:**
   ```python
   TaskList()
   # All tasks in current phase should be completed
   ```

2. **Manual transition:**
   Update `workflow-state.yaml`:
   ```yaml
   current_phase: execution  # Move to next phase
   ```

3. **Create next phase structure:**
   ```
   mkdir -p .development/{project}/phases/execution/outputs
   ```

## Performance Issues

**Symptom:** Workflow is slow or consuming too much context.

**Solutions:**

1. **Reduce parallelism:**
   Spawn fewer concurrent agents

2. **Use summaries:**
   Don't pass raw outputs between phases—summarize

3. **Limit scope:**
   Break large projects into smaller workflows

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "Team not found" | TeamCreate not called | Call TeamCreate first |
| "Agent not found" | Wrong recipient name | Use correct agent name |
| "Task blocked" | Dependencies not met | Complete blocking tasks |
| "MCP unavailable" | Background agent or orchestrator calling directly | Use foreground sub-agent with dual return |
| "Permission denied" | Sandbox restrictions | Check file paths |
