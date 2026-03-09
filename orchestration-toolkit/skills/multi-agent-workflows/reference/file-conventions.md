# File Conventions

## Naming Patterns

| File Type | Pattern | Example |
|-----------|---------|---------|
| **Workflow directory** | `.development/workflows/{workflow-id}/` | `feature-auth-20251124/` |
| **Agent output (single)** | `agent-{id}-{topic}.md` | `agent-001-requirements.md` |
| **Agent output (multi)** | `agent-{id}-{topic}/READ-FIRST.md` | `agent-005-data-model/READ-FIRST.md` |
| **Archive folder** | `archive/{phase}-{timestamp}/` | `planning-20251124T1430/` |
| **Phase summary** | `archive/{phase}-{timestamp}/phase-summary.md` | `planning-20251124T1430/phase-summary.md` |

## File Formats

- **Markdown** (.md): Primary format for all narrative content, summaries, documentation
- **YAML** (.yaml): Metadata, status, state tracking (with frontmatter in markdown files)
- **JSON** (.json): Structured data (schemas, API specs, task breakdowns)

## Frontmatter Pattern

All markdown files should include YAML frontmatter:

```yaml
---
phase: planning
author_agent: agent-001
created: 2025-11-24T14:00:00Z
status: completed
purpose: Requirements gathering for authentication feature
---

# Content starts here...
```
