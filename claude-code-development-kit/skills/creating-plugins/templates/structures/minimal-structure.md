```
my-plugin/
└── .claude-plugin/
    └── plugin.json
```

## Minimal Plugin

The only required file is `.claude-plugin/plugin.json`. All other directories and files are optional and added as needed.

A minimal `plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Brief description of what this plugin does"
}
```

From this base, add components incrementally:

- Add `skills/` for reusable skills (preferred for new development)
- Add `commands/` for slash commands (legacy, still supported)
- Add `.mcp.json` for MCP server configuration
- Add `.lsp.json` for LSP server configuration
- Add `settings.json` for default plugin settings
- Add `hooks/` for lifecycle event hooks
- Add `.claude/agents/` for sub-agent definitions (markdown files)
