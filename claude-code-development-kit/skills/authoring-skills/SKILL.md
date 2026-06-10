---
name: authoring-skills
description: Guide for creating Claude Code skills with YAML frontmatter, progressive disclosure, and best practices. Use when creating new skills, writing SKILL.md files, designing skill workflows, or learning skill development patterns.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
version: 1.3.0
created: 2025-11-20
last_updated: 2026-03-09
tags:
  - skills
  - authoring
  - development
---

# Authoring Skills

## When to Use This Skill

Use this skill when:
- Creating new skills or writing SKILL.md files
- Designing skill workflows or learning skill development patterns
- Understanding YAML frontmatter and skill structure
- Need templates and examples for skill authoring

### Do NOT Use This Skill When:
- ❌ Creating slash commands → Use `creating-commands` instead
- ❌ Creating plugins → Use `creating-plugins` instead
- ❌ Need prompt engineering guidance → Use `authoring-agent-prompts` instead
- ❌ Just using existing skills → Use `using-commands` or direct skill invocation

## Skill Patterns

See @templates/ for complete examples of:
- **Code Generation**: `code-generation-skill-template.md` - Templates, steps, validation
- **Analysis**: `analysis-skill-template.md` - Read-only tools, checklists
- **Documentation**: Structured around standards and templates
- **Refactoring**: Migration steps and patterns

Quick pattern reference:

```yaml
# Code Generation
name: generating-{output}
allowed-tools: [Read, Write, Edit, Grep, Glob]
```
```yaml
# Analysis
name: analyzing-{aspect}
allowed-tools: [Read, Grep, Glob]
```
```yaml
# Documentation
name: documenting-{subject}
allowed-tools: [Read, Grep, Glob]
```
```yaml
# Refactoring
name: migrating-{from}-to-{to}
allowed-tools: [Read, Write, Edit, Grep, Glob]
```

## Best Practices

### 1. One Skill, One Purpose
Keep skills focused on a single capability. Don't create "do-everything" skills.

### 2. Clear Descriptions
Help Claude discover when to use your skill with specific trigger words and contexts.

### 3. Step-by-Step Instructions
Provide clear, actionable instructions that Claude can follow systematically.

### 4. Include Examples
Concrete examples help Claude understand expected output and patterns.

### 5. Use Supporting Files
Keep SKILL.md under 500 lines by extracting detailed content to supporting files.

### 6. Test Locally First
Create skills in `.claude/skills/` within a project before moving to `~/.claude/skills/` or sharing.

### 7. Document Dependencies
Note any required tools, setup, or project structure.

### 8. Version History
Track changes and document versions in your SKILL.md.

### 9. Team Alignment
Share skills that benefit the whole team via version control.

### 10. Iterate Based on Usage
Refine descriptions and instructions based on how Claude actually uses the skill.

## Sharing Skills

- **Via Git**: Commit `.claude/skills/` - team members get skills on clone/pull
- **Via Plugin**: Bundle in `.claude-plugin/` structure
- **As Archive**: Zip skill directory for manual distribution

See project documentation for plugin creation details.

## Troubleshooting

Common issues:
- **Not Invoked**: Check description specificity, YAML syntax, file location
- **YAML Errors**: Validate with `yamllint SKILL.md`
- **Tool Restrictions**: Use array format (`- Read`), not comma-separated

See @reference/testing-guide.md for comprehensive troubleshooting.

## Advanced Topics

- **Skill Composition**: Reference other skills for complex workflows
- **Context-Aware**: Use project memory (CLAUDE.md) for project-specific patterns
- **Dynamic Context Injection**: Use `!command` lines to embed live shell output (git log, env state) into skill context at load time — contrast with `@path` imports which are resolved statically at parse time
- **Runtime Path Variables**: Two variables are available in SKILL.md body content (not frontmatter):
  - `${CLAUDE_SKILL_DIR}` — resolves to the absolute path of the directory containing the current SKILL.md. Use this to reference sibling files portably: `@${CLAUDE_SKILL_DIR}/references/coding-standards.md`. Differs from `${CLAUDE_PLUGIN_ROOT}`, which points to the plugin root; skill directories may be nested deeper inside the plugin.
  - `${CLAUDE_PLUGIN_ROOT}` — resolves to the root directory of the plugin that owns the skill.
- **Description Calibration**: Tune description specificity so Claude activates the skill at the right rate — too generic causes over-selection (~90% activation), too specific causes under-selection (~20% activation), well-targeted lands around ~50%

See @reference/yaml-best-practices.md for dynamic context injection details and security guidance.
See @reference/description-guidelines.md for activation optimization patterns.

## Supporting Documentation

### Detailed References
@reference/description-guidelines.md - Writing effective skill descriptions
@reference/testing-guide.md - Comprehensive testing strategies
@reference/yaml-best-practices.md - YAML frontmatter patterns

### Templates
@templates/minimal-skill-template.md - Bare minimum skill structure
@templates/comprehensive-skill-template.md - Full-featured skill template
@templates/code-generation-skill-template.md - Template for code generation skills
@templates/analysis-skill-template.md - Template for analysis skills

### Examples
@examples/react-component-skill.md - Complete React component generation skill
@examples/api-documentation-skill.md - API documentation skill example

## Resources

- Main Skills Documentation: https://code.claude.com/docs/en/skills
- YAML Syntax: https://yaml.org/spec/1.2/spec.html
- Example Skills: Check community plugins for examples

## Version History

### v1.3.0 (2026-03-09)
- Documented `${CLAUDE_SKILL_DIR}` runtime variable (added in devkit v2.1.69) and contrasted it with `${CLAUDE_PLUGIN_ROOT}`

### v1.2.0 (2026-03-01)
- Updated reference to yaml-best-practices.md to reflect corrected frontmatter documentation (name is optional, no gerund requirement, added disable-model-invocation and user-invocable fields)

### v1.1.0 (2026-02-28)
- Added dynamic context injection (`!command`) to Advanced Topics
- Added description calibration and activation rate guidance to Advanced Topics

### v1.0.0 (2025-11-17)
- Initial conversion from skills-authoring-guide.md
- Implemented progressive disclosure architecture
- Created supporting file structure
- Added comprehensive templates and examples
