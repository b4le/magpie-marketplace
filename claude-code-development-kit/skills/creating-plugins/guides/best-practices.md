# Plugin Best Practices

This guide covers best practices for creating high-quality, maintainable Claude Code plugins.

## Table of Contents

- [Documentation](#documentation)
- [Namespacing](#namespacing)
- [Testing](#testing)
- [Validation](#validation)
- [Dependencies](#dependencies)
- [Examples](#examples)
- [Versioning](#versioning)
- [Licensing](#licensing)

## Documentation

Comprehensive documentation is essential for plugin adoption and usability.

### README.md Structure

Every plugin should include a comprehensive README.md:

```markdown
# My Plugin

Brief description of what the plugin does and why it's useful.

## Features

- Feature 1: Description
- Feature 2: Description
- Feature 3: Description

## Installation

\`\`\`bash
/plugin marketplace add github https://github.com/user/my-plugin
/plugin install my-plugin@github
\`\`\`

## Usage

### Commands

- `/my-plugin:command1` - Description of what this command does
  - Arguments: `[arg1] [arg2]`
  - Example: `/my-plugin:command1 value1 value2`

- `/my-plugin:command2` - Description of what this command does
  - Arguments: `[arg1]`
  - Example: `/my-plugin:command2 value1`

### Skills

- `skill-name` - When this skill is invoked and what it does

## Configuration

### Environment Variables

If your plugin requires configuration:

\`\`\`bash
export API_ENDPOINT="https://api.example.com"
export API_TOKEN="your-token-here"
\`\`\`

### Required Setup

1. Step 1
2. Step 2
3. Step 3

## Examples

### Example 1: Basic Usage

\`\`\`bash
/my-plugin:command1 example
\`\`\`

Expected output: ...

### Example 2: Advanced Usage

\`\`\`bash
/my-plugin:command2 complex-example
\`\`\`

Expected output: ...

## Troubleshooting

### Issue 1

**Problem**: Description of problem

**Solution**: How to fix it

### Issue 2

**Problem**: Description of problem

**Solution**: How to fix it

## Contributing

Instructions for contributing to the plugin.

## License

MIT

## Support

- Issues: https://github.com/user/my-plugin/issues
- Discussions: https://github.com/user/my-plugin/discussions
- Email: support@example.com
\`\`\`

### Command Documentation

Each command should have clear frontmatter:

```markdown
---
description: Clear, concise description of command purpose
argument-hint: [descriptive-arg-name]
---

Detailed instructions for Claude.

**Usage Example**:
/my-plugin:command-name argument-value

**Expected Behavior**:
What this command will do...

**Notes**:
- Important note 1
- Important note 2
```

### Skill Documentation

Skills should have comprehensive SKILL.md files:

```yaml
---
name: skill-name
description: Clear description of when to use. Use when [specific scenario].
---

# Skill Name

## Overview

What this skill does and when it should be used.

## When to Use

Specific scenarios:
- Scenario 1
- Scenario 2
- Scenario 3

## Workflow

### Step 1: [Step Name]

Detailed instructions...

### Step 2: [Step Name]

Detailed instructions...

## Examples

### Example 1

Input: ...
Output: ...

### Example 2

Input: ...
Output: ...

## Quality Checks

- [ ] Check 1
- [ ] Check 2
- [ ] Check 3
```

### MCP Server Documentation

Document each MCP server in README:

```markdown
## MCP Servers

### company-api

Provides access to company internal API.

**Configuration**:
\`\`\`bash
export COMPANY_API_TOKEN="your-token"
\`\`\`

**Available Tools**:
- `fetch_user` - Get user information
- `create_ticket` - Create support ticket

### local-db

PostgreSQL database access.

**Configuration**:
\`\`\`bash
export DATABASE_URL="postgresql://localhost/mydb"
\`\`\`

**Available Tools**:
- `query` - Execute SQL query
- `schema` - Get table schema
```

## Namespacing

Proper namespacing prevents conflicts with other plugins.

### Command Namespacing

#### Option 1: Subdirectories

Organize related commands in subdirectories:

```
commands/
├── api/
│   ├── create.md
│   ├── test.md
│   └── deploy.md
└── db/
    ├── migrate.md
    └── seed.md
```

Usage:
- `/my-plugin:api:create`
- `/my-plugin:api:test`
- `/my-plugin:db:migrate`

#### Option 2: Prefix Naming

Name commands with category prefix:

```
commands/
├── api-create.md
├── api-test.md
├── db-migrate.md
└── db-seed.md
```

Usage:
- `/my-plugin:api-create`
- `/my-plugin:api-test`
- `/my-plugin:db-migrate`

### Skill Namespacing

Use descriptive, specific skill names:

**Good**:
- `react-component-generator`
- `api-endpoint-creator`
- `database-migration-helper`

**Avoid**:
- `generator` (too generic)
- `helper` (too vague)
- `tool` (not descriptive)

### Plugin Naming

Choose unique, descriptive plugin names:

**Good**:
- `react-toolkit`
- `api-development-suite`
- `testing-framework`

**Avoid**:
- `utils` (too generic)
- `helpers` (too vague)
- `tools` (not specific)

## Testing

Thoroughly test your plugin before publishing.

### Testing Checklist

#### Command Testing

- [ ] Each command executes successfully
- [ ] Arguments parse correctly
- [ ] Error handling works
- [ ] Output is as expected
- [ ] Edge cases handled
- [ ] Help text is clear

#### Skill Testing

- [ ] Skill is discoverable
- [ ] Description matches behavior
- [ ] Skill invokes at right times
- [ ] Workflow completes successfully
- [ ] Templates are valid
- [ ] Quality checks pass

#### Hook Testing

- [ ] Hooks execute at correct lifecycle events
- [ ] Exit codes are correct
- [ ] Error messages are clear
- [ ] Performance is acceptable
- [ ] No unintended side effects
- [ ] Permissions are correct

#### MCP Server Testing

- [ ] Servers connect successfully
- [ ] Authentication works
- [ ] Tools are available
- [ ] Responses are correct
- [ ] Error handling works
- [ ] Timeouts handled gracefully

### Test in Fresh Environment

Before publishing, test in a clean environment:

```bash
# Create test directory
mkdir ~/plugin-test
cd ~/plugin-test

# Install plugin
/plugin marketplace add test /path/to/plugin
/plugin install my-plugin@test

# Test all features
/my-plugin:command1
# ... test each command

# Verify skills load
# Test hooks trigger
# Check MCP servers connect
```

### Test with Different Claude Code Versions

If possible, test with:
- Current latest version
- Beta versions (if available)

## Validation

Use validation tools before publishing.

### Plugin Validation Command

Validate plugin structure:

```bash
claude plugin validate /path/to/plugin
```

### Common Validation Errors

#### Missing Required Fields

```bash
❌ Error: plugin.json missing required field "version"
```

**Fix**: Add version to plugin.json:
```json
{
  "name": "my-plugin",
  "version": "1.0.0"
}
```

#### Invalid YAML Frontmatter

```bash
❌ Error: skills/my-skill/SKILL.md has invalid YAML frontmatter
```

**Fix**: Ensure YAML syntax is correct:
```yaml
---
name: skill-name
description: Valid description
---
```

#### Hook Script Not Found

```bash
❌ Error: Hook script not found: scripts/missing.sh
```

**Fix**: Ensure hook file exists and path is correct in hooks.json.

#### Invalid Hook Configuration

```bash
❌ Error: hooks/hooks.json invalid: "hooks" array is required
```

**Fix**: Use the correct hook structure with event arrays and handler objects:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/script.sh"
          }
        ]
      }
    ]
  }
}
```

### Manual Validation Checklist

Before publishing:

- [ ] plugin.json is valid JSON
- [ ] All required fields present
- [ ] Version follows semver
- [ ] Command files have valid frontmatter
- [ ] Skill files have valid YAML
- [ ] Hook scripts are executable
- [ ] MCP servers.json is valid
- [ ] README.md exists and is complete
- [ ] LICENSE file exists
- [ ] CHANGELOG.md is up to date
- [ ] No sensitive data in files
- [ ] File permissions are correct

## Dependencies

Manage plugin dependencies carefully.

### Minimal Dependencies

Only depend on plugins truly needed:

**Good**:
```json
{
  "dependencies": {
    "core-utilities": "^1.0.0"
  }
}
```

**Avoid**:
```json
{
  "dependencies": {
    "plugin-a": "^1.0.0",
    "plugin-b": "^1.0.0",
    "plugin-c": "^1.0.0",
    "plugin-d": "^1.0.0",
    "plugin-e": "^1.0.0"
  }
}
```

### Document Dependencies

Explain why dependencies are needed in README:

```markdown
## Dependencies

This plugin depends on:

- `core-utilities` (^1.0.0) - Provides shared helper functions
- `api-base` (^2.0.0) - Base API integration layer
```

### Version Constraints

Use appropriate version constraints:

```json
{
  "dependencies": {
    "stable-plugin": "^1.0.0",      // Compatible with 1.x
    "newer-plugin": ">=2.0.0",       // At least 2.0.0
    "exact-plugin": "1.5.2"          // Exact version (avoid unless necessary)
  }
}
```

## Examples

Provide clear examples in documentation and code.

### Command Examples

In command files:

```markdown
---
description: Create React component
argument-hint: [component-name]
---

Create a React component named $1.

**Example**:
\`\`\`
/my-plugin:create-component Button
\`\`\`

This will create:
- src/components/Button/Button.tsx
- src/components/Button/Button.module.css
- src/components/Button/Button.test.tsx
- src/components/Button/Button.stories.tsx
```

### Skill Examples

In SKILL.md:

```yaml
---
name: component-generator
description: Generate React components. Use when creating new UI components.
---

# Component Generator

## Examples

### Example 1: Simple Component

**Input**:
- Component name: Button
- Props: text, onClick
- Style: CSS modules

**Output**:
- Button.tsx with typed props
- Button.module.css with base styles
- Button.test.tsx with basic tests
- Button.stories.tsx with variants

### Example 2: Complex Component

**Input**:
- Component name: DataTable
- Props: data, columns, onSort, onFilter
- Style: styled-components

**Output**:
- DataTable.tsx with sorting/filtering
- DataTable.styles.ts with styled components
- DataTable.test.tsx with comprehensive tests
- DataTable.stories.tsx with interactive examples
```

### README Examples

Include real-world examples:

```markdown
## Examples

### Example 1: Generate Component

\`\`\`bash
/react-toolkit:component Button
\`\`\`

Creates a Button component with:
- TypeScript interface
- CSS modules
- Unit tests
- Storybook story

### Example 2: Generate Page

\`\`\`bash
/react-toolkit:page Dashboard
\`\`\`

Creates a Dashboard page with:
- Page component
- Layout integration
- Route configuration
- Tests
```

## Versioning

Follow semantic versioning strictly.

### Version Guidelines

**Major version (x.0.0)** - Breaking changes:
- Remove commands
- Change command arguments
- Remove skills
- Change skill behavior significantly
- Remove hooks
- Change MCP server configuration

**Minor version (1.x.0)** - New features:
- Add commands
- Add skills
- Add hooks (non-breaking)
- Enhance existing features
- Add MCP servers

**Patch version (1.0.x)** - Bug fixes:
- Fix command bugs
- Fix skill issues
- Update documentation
- Fix hook bugs
- Fix MCP server issues

### Version Communication

Document breaking changes clearly:

```markdown
# CHANGELOG.md

## [2.0.0] - 2025-01-20

### BREAKING CHANGES

- Removed `/my-plugin:old-command` - use `/my-plugin:new-command` instead
- Changed `generate-component` skill to require TypeScript (previously optional)
- Renamed hook from `pre-edit` to `before-edit`

### Migration Guide

**Old**:
\`\`\`
/my-plugin:old-command arg
\`\`\`

**New**:
\`\`\`
/my-plugin:new-command arg --new-flag
\`\`\`
```

## Licensing

Choose and document your license clearly.

### License File

Include LICENSE file in plugin root:

```
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

### Common Licenses

- **MIT**: Permissive, allows commercial use
- **Apache-2.0**: Permissive with patent grant
- **GPL-3.0**: Copyleft, requires derivative works to be open source
- **BSD-3-Clause**: Permissive with attribution

### License in plugin.json

Specify license in metadata:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "license": "MIT"
}
```

### License in README

Include license section:

```markdown
## License

This plugin is licensed under the MIT License. See [LICENSE](LICENSE) file for details.
```

## Summary

Key best practices:

1. **Documentation**: Comprehensive README, clear command descriptions, detailed skill instructions
2. **Namespacing**: Organized commands, specific skill names, unique plugin names
3. **Testing**: Test all components, test in fresh environment, test edge cases
4. **Validation**: Use validation tools, fix errors before publishing, manual checklist
5. **Dependencies**: Minimal dependencies, document why needed, appropriate version constraints
6. **Examples**: Real-world examples, clear inputs/outputs, multiple scenarios
7. **Versioning**: Follow semver, document breaking changes, migration guides
8. **Licensing**: Clear license, LICENSE file, documented in metadata

Following these practices ensures your plugin is:
- Easy to discover and install
- Clear to use
- Reliable and well-tested
- Compatible with other plugins
- Maintainable over time

## Next Steps

- Learn about [Adding Components](adding-components.md)
- Review [Publishing](publishing.md) guide
- Explore [Advanced Topics](advanced.md)
- Set up [Team Marketplace](marketplace-setup.md)
