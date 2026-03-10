# Communication Patterns Reference

How agents communicate with each other and the user.

## Message Types

### Direct Message

Send to a specific teammate:

```python
SendMessage(
    type="message",
    recipient="engineer-1",
    content="Auth module is ready for integration. See outputs/auth-module.md",
    summary="Auth module ready"
)
```

**Use for:**
- Handoffs between agents
- Asking questions to specific teammates
- Status updates to team lead
- Sharing relevant outputs

### Broadcast

Send to all teammates (use sparingly):

```python
SendMessage(
    type="broadcast",
    content="Switching to review phase. All execution work should be complete.",
    summary="Phase transition to review"
)
```

**Use for:**
- Phase transitions
- Critical blockers affecting everyone
- Major announcements

**Warning:** Broadcasts are expensive—each message is delivered to every teammate. Default to direct messages.

### Shutdown Request

Request an agent to gracefully terminate:

```python
SendMessage(
    type="shutdown_request",
    recipient="researcher",
    content="Research complete, thank you for your work"
)
```

**Use for:**
- Cleaning up after phase completion
- Dismissing agents no longer needed
- Final workflow cleanup

### Shutdown Response

Respond to shutdown request:

```python
SendMessage(
    type="shutdown_response",
    request_id="abc-123",  # From the request
    approve=True
)
```

Or reject:

```python
SendMessage(
    type="shutdown_response",
    request_id="abc-123",
    approve=False,
    content="Still finishing analysis, need 5 more minutes"
)
```

## Task Dependencies

### Creating Dependent Tasks

```python
# Task 1: No dependencies
TaskCreate(
    subject="Design API schema",
    description="Create OpenAPI spec for export endpoints",
    activeForm="Designing API schema"
)
# Returns task_id: "task-1"

# Task 2: Depends on Task 1
TaskCreate(
    subject="Implement API endpoints",
    description="Build endpoints per API schema",
    activeForm="Implementing API endpoints",
    addBlockedBy=["task-1"]
)
```

### Checking Dependencies

Before starting work:

```python
TaskGet(taskId="task-2")
# Check blockedBy is empty before proceeding
```

### Marking Complete

```python
TaskUpdate(
    taskId="task-1",
    status="completed"
)
# This unblocks task-2
```

## Agent Spawning

### Critical: MCP Tool Access

**The orchestrator must never call MCP tools directly.** Delegate all MCP fetching to foreground sub-agents using the dual return pattern: sub-agent writes full results to `local-state/prefetch/{session}/`, returns summary + file path. Pass file paths to downstream agents, not raw data.

All agents that need MCP access **must** use `run_in_background=False` — background agents cannot access MCP tools.

See `references/mcp-prefetch-pattern.md` for the full protocol.

### Spawning by Agent Type

**Explore agent** (for investigation):
```python
Task(
    description="Research authentication patterns in codebase",
    subagent_type="Explore",
    run_in_background=False
)
```

**Plan agent** (for design):
```python
Task(
    description="Design architecture for export feature",
    subagent_type="Plan",
    run_in_background=False
)
```

**General-purpose agent** (for implementation):
```python
Task(
    description="Implement PDF generation service",
    run_in_background=False
)
```

## Coordination Patterns

### Sequential Handoff

```
Agent A completes → Messages Agent B → Agent B starts
```

```python
# Agent A, when done:
SendMessage(
    type="message",
    recipient="engineer-1",
    content="Research complete. Key findings in outputs/research.md. Ready for implementation.",
    summary="Research handoff"
)
```

### Parallel Coordination

```
Agents A, B, C work in parallel → All complete → Coordinator synthesizes
```

```python
# Team lead monitors:
TaskList()
# When all tasks completed, synthesize outputs
```

### Blocking Communication

```
Agent A needs input from Agent B mid-task
```

```python
# Agent A:
SendMessage(
    type="message",
    recipient="architect",
    content="Need clarification: should we use REST or GraphQL for export API?",
    summary="API design question"
)

# Agent A waits or continues with assumption
# Architect responds when available
```

## Team Lead Patterns

### Status Checks

```python
# See all tasks
TaskList()

# Check specific agent
TaskGet(taskId="agent-task-id")
```

### Progress Updates

The team lead should periodically update:
- `workflow-state.yaml` — overall status
- `phases/{phase}/STATUS.yaml` — phase progress
- `README.md` — user-visible summary

### Escalation

When agent is blocked:

```python
# Agent reports to team lead:
SendMessage(
    type="message",
    recipient="team-lead",
    content="Blocked: need database credentials to proceed. Cannot access production data.",
    summary="Blocked on credentials"
)
```

## When to Update State Files

Keep state files current to maintain visibility:

| File | When to Update | Who Updates |
|------|----------------|-------------|
| `workflow-state.yaml` | Phase transitions, status changes | Team Lead |
| `README.md` | After each phase completes, blockers resolved | Team Lead |
| `phases/{phase}/STATUS.yaml` | Task completion, blockers, agent changes | Team Lead or assigned agent |

### Update Triggers

**workflow-state.yaml:**
- Project starts → set `status: in_progress`, `current_phase`
- Phase completes → update phase status, advance `current_phase`
- Blocker encountered → set `status: blocked`, add to `notes`
- Project completes → set `status: completed`

**README.md:**
- After spawning team → document team composition
- Phase completion → summarize outputs and decisions
- Major decisions → document rationale
- Project completion → final summary for reference

**STATUS.yaml (per phase):**
- Agent assigned → add to agents list
- Task complete → update task status
- Blocker → document in blockers section
- Phase complete → set `status: completed`

## Cleanup Protocol

When workflow completes:

1. **Shutdown all agents**
   ```python
   SendMessage(type="shutdown_request", recipient="agent-1", ...)
   SendMessage(type="shutdown_request", recipient="agent-2", ...)
   ```

2. **Delete team**
   ```python
   TeamDelete(teamName="project-team")
   ```

3. **Update final status**
   - `workflow-state.yaml`: status = completed
   - `README.md`: final summary

4. **Archive if desired**
   - Move `.development/{project}/` to archive location
   - Or leave in place for reference
