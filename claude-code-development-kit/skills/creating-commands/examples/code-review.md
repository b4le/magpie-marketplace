# Example: Code Review Command

**File**: `.claude/commands/code-review.md`

```markdown
---
description: Perform comprehensive code review
argument-hint: [file-or-directory]
---

Perform a comprehensive code review of $1.

Review checklist:
- [ ] Code follows project style guide (see @.claude/CLAUDE.md)
- [ ] No security vulnerabilities (XSS, SQL injection, etc.)
- [ ] Proper error handling
- [ ] Tests included and passing
- [ ] Documentation updated
- [ ] Performance considerations addressed
- [ ] Accessibility requirements met

Provide specific feedback with file paths and line numbers.
```

**Usage**: `/code-review src/components/UserProfile.tsx`
