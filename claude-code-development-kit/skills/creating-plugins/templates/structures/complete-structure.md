```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Required plugin manifest
├── commands/                 # Legacy: slash commands (still supported)
│   ├── command1.md          # Note: prefer skills/ for new development
│   └── command2.md
├── skills/                   # Preferred: reusable skills (new development)
│   ├── skill1/
│   │   └── SKILL.md
│   └── skill2/
│       └── SKILL.md
├── .claude/
│   └── agents/              # Sub-agent definitions (markdown files)
│       └── custom-agent.md
├── hooks/
│   ├── pre-commit.sh
│   └── post-edit.sh
├── .mcp.json                 # MCP server configuration (root of plugin)
├── .lsp.json                 # LSP server configuration (root of plugin)
├── settings.json             # Default plugin settings (merged with user/project settings)
└── README.md
```

## Notes

- **`commands/` vs `skills/`**: The `commands/` directory is the legacy mechanism for slash commands and remains supported. For new development, prefer `skills/` which provides richer context and automatic invocation.
- **`.mcp.json`**: Lives at the plugin root (not `mcp/servers.json`). Follows the standard MCP configuration format.
- **`.lsp.json`**: Optional. Declares Language Server Protocol servers bundled with the plugin. See the LSP documentation in the adding-components guide.
- **`settings.json`**: Optional. Provides default settings that are merged with user and project-level settings. Plugin defaults have the lowest precedence.
- **`.claude/agents/`**: Agent definitions are markdown files (`.md`), not JSON. Each file describes a sub-agent persona and capabilities.
