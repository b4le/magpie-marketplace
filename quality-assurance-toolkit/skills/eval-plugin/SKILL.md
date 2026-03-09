---
name: eval-plugin
description: >
  Validate plugins and skills in Claude Code marketplaces.
  Use to check plugin structure, skill formatting, marketplace registration,
  and ensure consistency across the marketplace. Provides checklists and
  validation commands for comprehensive quality assurance.
version: 2.0.0
created: 2026-02-17
last_updated: 2026-02-25
tags:
  - validation
  - quality-assurance
  - plugins
---

# Eval Plugin

Validate plugins and skills to ensure they meet marketplace standards.

## Quick Start

**Invoke:** `/quality-assurance-toolkit:eval-plugin`

1. Specify what to validate:
   - Single plugin: `eval-plugin productivity-toolkit`
   - Single skill: `eval-plugin productivity-toolkit/skills/my-skill`
   - Entire marketplace: `eval-plugin --all`

2. Review the checklist results
3. Fix any issues identified
4. Re-run validation to confirm fixes

## Full Audit Mode

Use `validate-marketplace.sh` for comprehensive validation:

```bash
# Validate entire marketplace
./claude-code-development-kit/evals/validate-marketplace.sh

# With verbose output
./claude-code-development-kit/evals/validate-marketplace.sh --verbose

# Single plugin
./claude-code-development-kit/evals/validate-marketplace.sh --plugin my-plugin

# JSON output for CI/CD
./claude-code-development-kit/evals/validate-marketplace.sh --json
```

## Available Validators

All validators are in `claude-code-development-kit/evals/`:

| Validator | Purpose | Usage |
|-----------|---------|-------|
| `validate-marketplace.sh` | Full marketplace audit | `--verbose`, `--json`, `--plugin NAME` |
| `validate-plugin.sh` | Single plugin structure | `<plugin-root>` |
| `validate-skill.sh` | Skill directory/SKILL.md | `<skill-path>` |
| `validate-command.sh` | Slash command file | `<command-file>` |
| `validate-hook.sh` | Hook script | `<hook-file>` |
| `validate-output-style.sh` | Output style file | `<style-file>` |
| `validate-agent.sh` | Agent definition | `<agent-path>` |
| `validate-references.sh` | Cross-references | `[--verbose] <path>` |

Run any validator with `--help` for detailed options.

## Plugin Structure Checklist

```
{plugin-name}/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED
├── skills/
│   └── {skill-name}/
│       └── SKILL.md         # REQUIRED per skill
├── commands/                 # Optional
│   └── {command-name}.md
├── agents/                   # Optional
│   └── {agent-name}.md
├── hooks/                    # Optional
│   └── {hook-name}.sh
├── output-styles/            # Optional
│   └── {style-name}.md
└── README.md                 # Recommended
```

### plugin.json Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Kebab-case, matches directory name |
| `description` | string | Brief description |
| `version` | string | Semantic version (e.g., "1.0.0") |

### SKILL.md Requirements

| Component | Required |
|-----------|----------|
| YAML frontmatter | Yes |
| `name` field | Yes (matches directory) |
| `description` field | Yes |
| Line count | Max 500 lines |

### Agent Requirements

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Matches filename |
| `description` | Yes | Min 20 characters |
| `tools` | Yes | Comma-separated list |
| `model` | No | opus, sonnet, or haiku |
| `model_rationale` | Conditional | Required if model specified |

**Valid Tools:** Read, Write, Edit, Bash, Glob, Grep, Skill, Task, WebFetch, WebSearch, AskUserQuestion, NotebookEdit, or MCP format `mcp__{service}__{tool}`

## JSON Schema Validation

Schemas are in `claude-code-development-kit/schemas/`:
- `marketplace.schema.json`
- `plugin.schema.json`
- `skill-frontmatter.schema.json`

```bash
# With jq (syntax check)
jq '.' ./my-plugin/.claude-plugin/plugin.json

# With ajv-cli (schema validation)
ajv validate -s schemas/plugin.schema.json -d ./my-plugin/.claude-plugin/plugin.json
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/validate-marketplace.yml`:

```yaml
name: Validate Marketplace
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y jq
      - run: chmod +x claude-code-development-kit/evals/*.sh
      - run: ./claude-code-development-kit/evals/validate-marketplace.sh
```

### Pre-commit Hook

```bash
#!/bin/bash
./claude-code-development-kit/evals/validate-marketplace.sh --no-color || exit 1
```

## Quick Reference

```bash
# Full audit
./claude-code-development-kit/evals/validate-marketplace.sh --verbose

# Single plugin
./claude-code-development-kit/evals/validate-plugin.sh ./my-plugin

# Single skill
./claude-code-development-kit/evals/validate-skill.sh ./my-plugin/skills/my-skill

# Single agent
./claude-code-development-kit/evals/validate-agent.sh ./my-plugin/agents/my-agent.md
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Passed |
| 1 | Failed |
| 2 | Invalid arguments |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "jq not found" | `brew install jq` (macOS) or `apt install jq` (Linux) |
| "Permission denied" | `chmod +x claude-code-development-kit/evals/*.sh` |
| "Name mismatch" | Ensure `name` field matches directory name (kebab-case) |
| "Missing frontmatter" | Add `---` block at file start with name, description |
| "Reference not found" | Create missing file or remove reference |
| "Invalid model" | Use only: opus, sonnet, haiku |
| "Personal identifier" | Replace `/Users/yourname/` with `~/.claude/` or env vars |

## Best Practices

1. **Validate before committing** - Run validation locally
2. **Keep versions in sync** - Update plugin.json and marketplace.json together
3. **Use consistent naming** - Follow kebab-case conventions
4. **Test skill invocation** - Verify `/{plugin-name}:{skill-name}` works
5. **Use JSON output in CI** - Parse for automated checks
