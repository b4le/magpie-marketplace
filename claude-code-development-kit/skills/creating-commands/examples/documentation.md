# Example: Documentation Generator

**File**: `.claude/commands/docs/generate.md`

```markdown
---
description: Generate documentation for code
argument-hint: [file-path]
---

Generate comprehensive documentation for: $1

Include:
- Purpose and overview
- Function/class descriptions
- Parameter documentation
- Return value descriptions
- Usage examples
- Edge cases and limitations

Follow the documentation style in @docs/documentation-guide.md.
```

**Usage**: `/docs:generate src/utils/validation.ts`
