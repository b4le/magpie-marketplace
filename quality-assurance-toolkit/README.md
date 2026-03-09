# Quality Assurance Toolkit

**Version:** 2.0.0

Validation and quality assurance tools for plugins and skills.

## Features

- Plugin structure validation against marketplace standards
- Skill structure and frontmatter validation
- Marketplace registration and reference resolution checking
- CI/CD integration support

## Installation

### Via Marketplace

```bash
claude plugin install quality-assurance-toolkit@content-platform-marketplace
```

### Manual Installation

Add this plugin to your Claude Code settings (`.claude/settings.json`):

```json
{
  "plugins": [
    "/path/to/content-platform-marketplace/quality-assurance-toolkit"
  ]
}
```

Or add the marketplace to include all Content Platform plugins:

```json
{
  "plugins": [
    "/path/to/content-platform-marketplace"
  ]
}
```

## Prerequisites

- Claude Code CLI

## Quick Start

Validate a plugin against marketplace standards:

```bash
/quality-assurance-toolkit:eval-plugin productivity-toolkit
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `eval-plugin` | Validate plugins and skills against marketplace standards | `/quality-assurance-toolkit:eval-plugin` |

### eval-plugin

Validate plugins and skills to ensure they meet marketplace standards. It serves as the central location for QA-related skills, separating validation concerns from functional workflow tools.

**Capabilities:**
- Plugin structure validation (plugin.json, required fields, naming conventions)
- Skill structure validation (SKILL.md, frontmatter, references)
- Marketplace registration validation
- Reference resolution checking (`@reference/`, `@templates/`)
- CI/CD integration scripts

**Usage examples:**
```bash
# Validate a single plugin
eval-plugin productivity-toolkit

# Validate a specific skill
eval-plugin productivity-toolkit/skills/my-skill

# Validate entire marketplace
eval-plugin --all
```

## Future Skills

This plugin is designed to house additional QA tools such as:
- Linting validators
- Code review automation
- Testing validators
- Style checkers

## Troubleshooting

If validation fails unexpectedly, ensure the plugin or skill path is relative to the marketplace root and that `plugin.json` exists in the target directory. For reference resolution errors, confirm `@reference/` and `@templates/` directories are present in the marketplace root.

## Contributing

Contributions should follow the marketplace authoring standards. Run `eval-plugin` against your changes before submitting a pull request.

## License

MIT

## Version History

| Version | Notes |
|---------|-------|
| 2.0.0 | Current release |
