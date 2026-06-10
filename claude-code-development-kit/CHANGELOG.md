# Changelog

All notable changes to the Claude Code Development Kit plugin will be documented in this file.

## [2.1.0] - 2026-03-06

### Added
- **devkit-maintainer agent** — maintenance and validation specialist with 5 modes: audit, sync, validate, cleanup, full
- **maintaining-devkit skill** — structured playbooks for each maintenance mode with progressive disclosure to references/
- **`/devkit-maintain` command** — user-invocable command dispatching to maintenance modes
- **SessionStart drift-check hook** — lightweight (<5s) fail-open hook that warns when schemas or structure may be outdated
- **Helper scripts**: fetch-changelog.sh, audit-setup.sh, generate-maintenance-report.sh
- **Reference docs**: changelog-sync-playbook, setup-hygiene-checklist, auto-fix-catalog, feature-adoption-guide

### Changed
- Plugin hooks now reference `hooks/hooks.json` (was inline in plugin.json) for cleaner separation
- Plugin version bumped to 2.1.0
- Plugin schema updated: `hooks` field now accepts string file reference or inline object (oneOf)

---

## [2.0.0] - 2026-02-28

### Changed

#### Schema Overhaul
- Corrected required fields in plugin manifest schema (removed incorrectly required `hooks` and `output-styles`)
- Fixed hook event names to match Claude Code reality (`PostToolUse`, `PreToolUse`, `Stop`, `Notification`)
- Updated handler format from incorrect object shape to correct `{type, command}` structure
- Added missing `matcher` field documentation for hook filtering

#### Missing Feature Coverage
- Added LSP (Language Server Protocol) integration documentation
- Documented all hook types including `Notification` and `Stop`
- Added environment variable reference for hook handlers
- Documented installation scopes (`user`, `project`, `global`)
- Added dynamic context injection patterns to memory skill

#### Skill Quality Uplift
- Updated 12 skills with corrected technical content and schema accuracy
- Fixed broken cross-references between skills
- Standardized frontmatter across all SKILL.md files
- Improved trigger phrases for more reliable skill selection

#### Infrastructure
- Enhanced validation hook with expanded schema checks
- Added new schemas for hook handlers, output styles, and memory files
- Fixed `available-skills` command to reflect accurate skill inventory

### Added

- **authoring-agents** skill (6 files) - Guide to creating custom agents for Claude Code
- **understanding-auto-memory** skill (3 files) - Guide to Claude Code's automatic memory system
- **best-practices-reference** skill - Quick triage guide for choosing the right tool, skill, or feature
- **resolving-claude-code-issues** skill - Troubleshooting guide for common Claude Code problems
- **integrating-mcps** skill - Guide to connecting MCP servers with Claude Code

### Totals

- 14 skills (up from 12 in 1.0.0)
- 4 schemas (plugin, skill-frontmatter, command-frontmatter, hook-handler)

---

## [1.1.0] - 2026-02-19

### Added

- **understanding-hooks** skill - Comprehensive guide to event-driven automation with hooks, hook types, matchers, and handler configuration

---

## [1.0.0] - 2026-02-17

### Added

#### Skills (9)
- **authoring-skills** - Create Claude Code skills with YAML frontmatter, progressive disclosure, and best practices
- **authoring-agent-prompts** - Write effective prompts for agents, skills, and tasks
- **authoring-output-styles** - Define output styles for skills and document templates
- **creating-commands** - Build custom slash commands with proper structure and arguments
- **creating-plugins** - Create, test, publish, and distribute plugins
- **using-commands** - Understand and use slash commands effectively
- **using-tools** - Guide for selecting and using Claude Code tools
- **managing-memory** - Create and manage CLAUDE.md memory files
- **understanding-hooks** - Comprehensive guide to hooks - event-driven automation with shell commands

#### Commands (3)
- `/migrate-to-skill` - Migrate a prompt or file into a properly structured Claude Code skill
- `/skill-checklist` - Quick validation checklist for creating and authoring Claude Code skills
- `/available-skills` - Display all available skills from the Claude Code Development Kit plugin

#### Hooks (1)
- `validate-skill-structure.sh` (PostToolUse, Write matcher) - Validates skill structure and frontmatter after Write tool operations on skill files

#### Output Styles (1)
- **analytical-documentation** - Structured analysis and documentation style with critique, optimization, and stakeholder alignment focus

### Features

- Complete toolkit for building Claude Code extensions
- Skills cover the full extension development lifecycle
- Commands provide rapid scaffolding and validation
- Hook system enables automated quality checks
- Comprehensive skill summaries and usage guides
- MIT licensed for open distribution

