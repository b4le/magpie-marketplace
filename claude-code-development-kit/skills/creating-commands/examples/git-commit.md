# Example: Git Commit Command

**File**: `.claude/commands/git/commit-all.md`

```markdown
---
description: Review and commit all changes
argument-hint: [commit-message-summary]
---

Review all changed files:

!git status
!git diff

If the changes are appropriate:
1. Stage all changes
2. Create a commit with message: "$1"
3. Follow commit message conventions from @CLAUDE.md

Include the standard co-author footer.
```

**Usage**: `/git:commit-all "Add user authentication"`
