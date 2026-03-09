# Advanced Features

## Combining Multiple Commands

Create a command that invokes other commands:

```markdown
---
description: Full CI/CD workflow
---

Run complete CI/CD workflow:

1. Run tests: /test:all
2. Run linter: /lint:fix
3. Build: /build:production
4. Deploy: /deploy:staging
```

## Dynamic Command Generation

Generate commands based on project structure:

```markdown
---
description: Generate commands for all microservices
---

!ls services/

For each service found, create deployment and testing commands.
```

## Context-Aware Commands

Commands that behave differently based on context:

```markdown
---
description: Smart commit
---

Analyze changes:

!git status
!git diff

Determine commit type:
- If only tests changed: "test: ..."
- If only docs changed: "docs: ..."
- If code changed: "feat: ..." or "fix: ..."

Generate appropriate conventional commit message.
```

## Tool Restrictions for Safety

Limit tools to prevent unintended actions:

```yaml
---
name: analyze-only
description: Read-only analysis
allowed-tools:
  - Read
  - Grep
  - Glob
---
```

This prevents writes, edits, or bash commands.

## Model Selection for Performance

Use lighter models for simple tasks:

```yaml
---
name: format-code
description: Simple code formatting
model: haiku
---
```

Use opus for complex analysis:

```yaml
---
name: architecture-review
description: Deep architectural analysis
model: opus
---
```

## Template-Only Commands

Disable model invocation for pure templates:

```yaml
---
name: issue-template
description: GitHub issue template
disable-model-invocation: true
---

## Bug Report

**Description**: $1

**Steps to Reproduce**:
1. $2

**Expected**: $3
**Actual**: $4
```
