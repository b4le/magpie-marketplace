# Plugin Directory Structure

## Minimum Plugin Structure

A plugin can consist of just a directory with content files — Claude Code auto-discovers commands, skills, agents, and output styles by convention. A manifest is optional but recommended for metadata and hook registration:

```
my-plugin/
└── .claude-plugin/
    └── plugin.json
```

## Complete Plugin Structure

Full plugin structure with all supported components:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json
├── commands/
│   ├── command1.md
│   └── command2.md
├── skills/
│   ├── skill1/
│   │   └── SKILL.md
│   └── skill2/
│       └── SKILL.md
├── agents/
│   ├── custom-agent.md
│   └── another-agent.md
├── hooks/
│   ├── pre-commit.sh
│   └── post-edit.sh
└── README.md
```

## Directory Purposes

| Path | Purpose | Required |
|------|---------|----------|
| `.claude-plugin/plugin.json` | Plugin manifest (metadata, hooks, component lists) | No — directory is optional; auto-discovery works without it |
| `commands/` | Custom slash commands (.md files) | No |
| `skills/` | Specialized capabilities (SKILL.md) | No |
| `agents/` | Custom sub-agents (flat .md files, one per agent) | No |
| `hooks/` | Event handlers (shell scripts) | No |
| `.mcp.json` | MCP server configuration at the plugin root | No |

## Common Variations

### Testing Plugin

```
testing-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── test-unit.md
│   ├── test-integration.md
│   └── coverage.md
├── skills/
│   └── test-generator/
│       └── SKILL.md
└── README.md
```

### API Development Plugin

```
api-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── new-endpoint.md
│   ├── generate-docs.md
│   └── test-api.md
├── skills/
│   ├── api-generator/
│   │   └── SKILL.md
│   └── openapi-docs/
│       └── SKILL.md
└── templates/
    ├── endpoint.ts
    ├── test.spec.ts
    └── openapi.yaml
```

### Full-Stack Plugin

```
fullstack-kit/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json
├── commands/
│   ├── frontend/
│   │   ├── component.md
│   │   └── page.md
│   └── backend/
│       ├── endpoint.md
│       └── model.md
├── skills/
│   ├── component-generator/
│   ├── api-generator/
│   └── db-migration/
└── hooks/
    ├── pre-commit.sh
    └── pre-push.sh
```

## Best Practices

### Command Organization

Use subdirectories to namespace commands:

```
commands/
├── api/
│   ├── create.md
│   └── test.md
└── db/
    ├── migrate.md
    └── seed.md
```

Usage: `/my-plugin:api:create`, `/my-plugin:db:migrate`

### Template Organization

Include reusable templates:

```
templates/
├── component.tsx
├── test.spec.ts
└── styles.module.css
```

### Script Organization

Organize utility scripts:

```
scripts/
├── generate-options.sh
├── validate.sh
└── deploy.sh
```

## Additional Files

Recommended files for documentation and licensing:

- `README.md` - Plugin documentation
- `LICENSE` - License file
- `CHANGELOG.md` - Version history
- `.gitignore` - Git ignore rules
