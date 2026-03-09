# Skill Issues

Troubleshooting skill invocation, YAML errors, and tool restrictions.

## Skill Not Being Invoked

**Problem**: Skill exists but Claude doesn't use it

**Solutions**:

1. Check description is specific:
```yaml
# Bad
description: Helps with React

# Good
description: Generate React components following project patterns with TypeScript, tests, and Storybook stories. Use when user requests creating a new React component.
```

2. Verify YAML syntax:
```bash
# Check for syntax errors
cat skills/my-skill/SKILL.md
```

3. Confirm location:
```bash
ls ~/.claude/skills/
ls .claude/skills/
```

4. Check file permissions:
```bash
chmod 644 skills/my-skill/SKILL.md
```

5. Restart Claude Code

## YAML Parsing Errors

**Problem**: SKILL.md fails to parse

**Common issues**:
```yaml
# Missing closing quotes
name: my-skill
description: "This is broken

# Incorrect indentation
name:my-skill
description:  test

# Special characters not escaped
description: This has: colons
```

**Solution**: Use YAML linter:
```bash
yamllint skills/my-skill/SKILL.md
```

## Skill Tool Restrictions Not Working

**Problem**: Skill using disallowed tools

**Verify syntax**:
```yaml
---
name: my-skill
description: Test
allowed-tools:
  - Read
  - Grep
---
```

Not:
```yaml
allowed-tools: Read, Grep  # Wrong format
```
