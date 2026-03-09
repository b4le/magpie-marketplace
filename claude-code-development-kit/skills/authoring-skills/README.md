# Authoring Skills - Claude Code Skill

Complete guide to creating effective, discoverable, and reusable Claude Code skills.

## Overview

This skill provides comprehensive guidance for developing Claude Code skills with YAML frontmatter, progressive disclosure architecture, and industry best practices.

## Structure

```
authoring-skills/
├── SKILL.md                    # Main skill file (< 500 lines)
├── README.md                   # This file
├── templates/                  # Skill templates
│   ├── minimal-skill-template.md
│   ├── comprehensive-skill-template.md
│   ├── code-generation-skill-template.md
│   └── analysis-skill-template.md
├── examples/                   # Complete skill examples
│   ├── react-component-skill.md
│   ├── api-documentation-skill.md
│   └── migration-skill.md
└── reference/                  # Detailed reference material
    ├── description-guidelines.md
    ├── testing-guide.md
    └── yaml-best-practices.md
```

## Quick Start

### Creating Your First Skill

1. **Choose a template** from `templates/`:
   - `minimal-skill-template.md` - Simple, focused skills
   - `comprehensive-skill-template.md` - Complex skills with supporting files

2. **Follow the structure**:
   ```yaml
   ---
   name: skill-name          # Gerund form, lowercase with hyphens
   description: Clear description with trigger phrases (200-400 chars)
   ---

   # Skill content (under 500 lines)
   ```

3. **Test locally**:
   ```bash
   mkdir -p .claude/skills/my-skill
   # Create SKILL.md
   # Test invocation
   ```

4. **Iterate and refine** based on usage

### Key Requirements

- **Name**: Gerund form (e.g., `generating-components`, not `component-generator`)
- **Description**: 200-400 characters with trigger phrases
- **Line Limit**: SKILL.md under 500 lines
- **Progressive Disclosure**: Use `@path` imports for detailed content

## Usage

### Invoke the Skill

The skill is automatically invoked when you:
- Ask about creating skills
- Request help with SKILL.md files
- Need guidance on skill development
- Want to learn skill authoring best practices

### Manual Invocation

```
Use the authoring-skills skill to help me create a new skill for [purpose]
```

## Supporting Material

### Reference Documentation

- **description-guidelines.md** - Writing effective skill descriptions
  - Character limits and format requirements
  - Trigger phrase patterns
  - Common mistakes and fixes
  - Testing strategies

- **testing-guide.md** - Comprehensive skill testing
  - Testing phases (local, validation, invocation)
  - Cross-model testing
  - Output validation
  - Common issues and solutions

- **yaml-best-practices.md** - YAML frontmatter patterns
  - Required and optional fields
  - Syntax rules and validation
  - Tool restrictions
  - Examples by skill type

### Templates

- **minimal-skill-template.md** - For simple, focused skills
  - 100-300 line target
  - Single purpose
  - Inline examples
  - Quick reference format

- **comprehensive-skill-template.md** - For complex skills
  - 200-400 line SKILL.md
  - Supporting file structure
  - Multiple workflows
  - Progressive disclosure

### Examples

- **react-component-skill.md** - Code generation example
  - Complete React component generation skill
  - TypeScript and accessibility focus
  - Testing and styling templates
  - Validation checklist

- **api-documentation-skill.md** - Documentation example
  - OpenAPI 3.0 documentation generation
  - Read-only tool restrictions
  - Schema and endpoint templates
  - Complete examples

## Best Practices

1. **One Skill, One Purpose** - Keep skills focused
2. **Clear Descriptions** - Use trigger phrases for discoverability
3. **Step-by-Step** - Provide actionable instructions
4. **Include Examples** - Show real-world usage
5. **Use Supporting Files** - Keep SKILL.md under 500 lines
6. **Test Locally First** - Validate before sharing
7. **Document Dependencies** - Note requirements
8. **Version History** - Track changes
9. **Team Alignment** - Share via git
10. **Iterate** - Refine based on usage

## Skill Locations

- **Personal**: `~/.claude/skills/` - Available across all projects
- **Project**: `.claude/skills/` - Shared with team via git
- **Plugin**: Bundled with installed plugins

## Common Patterns

### Code Generation
```yaml
name: generating-{output}
description: Creates {what} with {features}. Use when creating {triggers}.
allowed-tools: [Read, Write, Edit, Grep, Glob]
```

### Analysis
```yaml
name: analyzing-{aspect}
description: Analyzes {what} for {issues}. Use when {context}.
allowed-tools: [Read, Grep, Glob]
```

### Documentation
```yaml
name: documenting-{subject}
description: Generates {doc-type} following {standards}. Use when documenting {what}.
allowed-tools: [Read, Grep, Glob]
```

### Refactoring
```yaml
name: migrating-{from}-to-{to}
description: Migrates {what} with {approach}. Use when converting {triggers}.
allowed-tools: [Read, Write, Edit, Grep, Glob]
```

## Validation Checklist

Before sharing a skill:

- [ ] YAML frontmatter is valid
- [ ] Name uses gerund form, lowercase with hyphens
- [ ] Description is 200-400 characters with triggers
- [ ] SKILL.md is under 500 lines
- [ ] Instructions are step-by-step
- [ ] Examples are included
- [ ] Tool restrictions are appropriate
- [ ] @path imports are correct
- [ ] Skill invokes correctly for trigger phrases
- [ ] Output is accurate and consistent

## Resources

- Main Skills Documentation: https://code.claude.com/docs/en/skills
- YAML Syntax: https://yaml.org/spec/1.2/spec.html
- Example Skills: Check community plugins

## Version History

### v1.0.0 (2025-11-17)
- Initial creation from skills-authoring-guide.md
- Implemented progressive disclosure architecture
- Created comprehensive supporting file structure
- Added templates, examples, and reference documentation

## Contributing

To improve this skill:

1. Add new templates for common skill patterns
2. Include additional examples (testing, migration, etc.)
3. Expand reference documentation
4. Share feedback on what works and what doesn't

## License

This skill is part of the Claude Code best practices reference library.
