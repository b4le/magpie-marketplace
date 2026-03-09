# Agent-Specific Patterns

Best practices for working with Claude Code's specialized agents and tools.

## Using the Explore Agent (via Agent/Task tool)

**Pattern**:
```
Use the Explore agent with medium thoroughness to:

Understand how API error handling works across the codebase.

Specifically find:
- Where errors are caught
- How they're logged
- How they're reported to users
- Any retry logic
- Error boundary implementations
```

## Using the Plan Agent (via Agent/Task tool)

**Pattern**:
```
Use the Plan agent to break down this task:

Implement a real-time notification system.

Requirements:
- WebSocket connection
- Toast notifications
- Notification history
- Mark as read functionality
- Desktop notifications

Create a detailed implementation plan before we start coding.
```

## Using Task Management Tools Effectively

**Pattern**:
```
This is a complex feature with multiple steps. Use TaskCreate/TaskUpdate to track:

1. Database schema updates
2. API endpoint creation
3. Frontend component development
4. Integration testing
5. Documentation updates

Mark each todo as in_progress when you start, and completed when done.
```
