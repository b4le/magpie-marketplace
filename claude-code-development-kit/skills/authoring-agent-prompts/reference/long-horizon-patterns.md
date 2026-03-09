# Long-Horizon Reasoning Patterns

Best practices for structuring multi-step tasks that require state tracking across multiple interactions.

**When to use these patterns:**
- Tasks with 3+ distinct steps
- Features requiring multiple files/components
- Complex refactoring across codebase
- Multi-phase implementations

## Use Structured Tracking

**Pattern:**
```
Implement user authentication with the following steps. Track progress in a JSON file:

{
  "steps": [
    {"id": 1, "task": "Set up auth context", "status": "pending"},
    {"id": 2, "task": "Create login form", "status": "pending"},
    {"id": 3, "task": "Implement JWT handling", "status": "pending"},
    {"id": 4, "task": "Add protected routes", "status": "pending"},
    {"id": 5, "task": "Write tests", "status": "pending"}
  ]
}

Update the JSON after completing each step.
```

**Why it works:** Structured tracking helps Claude maintain context across multiple steps.

**Alternative:** Use `TaskCreate`/`TaskUpdate` for built-in progress tracking without manual JSON files.

**Related:** See @../reference/agent-workflows.md for Tasks usage patterns.

## Break Down Complex Tasks

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `Build a complete user authentication system` |
| **Good** ✅ | `Build a user authentication system in phases:`<br><br>`Phase 1: Basic Auth`<br>`- Create login/logout endpoints`<br>`- Implement JWT token generation`<br>`- Add auth middleware`<br><br>`Phase 2: Security`<br>`- Add password hashing`<br>`- Implement CSRF protection`<br>`- Add rate limiting`<br><br>`Phase 3: Testing`<br>`- Unit tests for auth functions`<br>`- Integration tests for endpoints`<br>`- E2E tests for user flows`<br><br>`Complete each phase before moving to the next.` |

**Why it works:** Breaking tasks into phases prevents scope creep and allows for verification at each stage.

**Tip:** Use numbered phases or explicit milestones to create natural stopping points for review.

## Incremental Work

Request incremental progress rather than all-at-once:

**Pattern:**
```
Let's refactor the API layer incrementally:

1. First, analyze the current structure and identify issues
2. Create a plan for the new structure
3. Refactor one endpoint as a proof of concept
4. Review the approach
5. Apply pattern to remaining endpoints

Stop after each step for review.
```

**Why it works:** Incremental work allows for course correction before investing too much effort.

**Best Practice:** Always include explicit "stop" points to prevent Claude from completing all steps without verification.

**Related:** See @../templates/refactoring.md for structured refactoring templates.
