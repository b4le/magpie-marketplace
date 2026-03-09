---
name: expert-review
description: Spawn expert sub-agents to review your work
argument-hint: "[expertise-areas] [--report-only]"
---

# /expert-review

Invoke the expert-review skill to spawn specialized agents for code review.

## Usage

```
/expert-review                      # Auto-detect experts from recent changes
/expert-review security             # Security-focused review
/expert-review security backend     # Multiple expertise areas
/expert-review --report-only        # No changes, recommendations only
```

## What Happens

1. **Discovery**: Scans installed plugins for matching agents
2. **Spawn**: Launches experts in parallel (worktrees for modifiers)
3. **Review**: Each expert analyzes and optionally fixes issues
4. **Consolidate**: Merge coordinator combines results
5. **Return**: Structured summary for orchestrator

## Examples

**After completing a batch of tasks:**
```
/expert-review
```

**Before merging security-sensitive code:**
```
/expert-review security --report-only
```

**Full-stack review:**
```
/expert-review backend frontend database
```
