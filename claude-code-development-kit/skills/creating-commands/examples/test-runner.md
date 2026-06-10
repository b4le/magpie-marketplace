# Example: Test Runner

**File**: `.claude/commands/test.md`

```markdown
---
description: Run tests and analyze failures
argument-hint: [test-pattern]
---

Run tests matching: $1

!npm test -- $1

If tests fail:
1. Analyze the failure messages
2. Identify the root cause
3. Suggest fixes
4. Implement the fixes if requested
```

**Usage**: `/test UserProfile`
