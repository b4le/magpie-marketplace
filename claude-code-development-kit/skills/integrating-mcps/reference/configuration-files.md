# Configuration Files

## Project Configuration

**Location**: `.mcp.json` (in project root, checked into source control)

Shared with your team. Claude Code prompts for approval before using project-scoped servers.

```json
{
  "mcpServers": {
    "project-db": {
      "type": "stdio",
      "command": "npx",
      "args": ["mcp-sqlite-server", "./data/project.db"]
    }
  }
}
```

## User and Local Configuration

**Location**: `~/.claude.json`

Both `user` and `local` scope servers are stored in `~/.claude.json`:

- **local scope** (default): Private to you, accessible only in the current project directory. Stored under your project's path entry in `~/.claude.json`.
- **user scope**: Private to you, accessible across all projects on your machine. Stored in the `mcpServers` field of `~/.claude.json`.

```json
{
  "mcpServers": {
    "personal-notes": {
      "type": "http",
      "url": "https://notes.example.com/mcp",
      "oauth": {
        "clientId": "your-client-id",
        "scopes": ["read", "write"]
      }
    }
  }
}
```

## Managed Configuration (Organization-Wide)

Managed centrally by administrators via `managed-mcp.json` in system directories. Includes:
- Allowlist: Permitted servers
- Denylist: Blocked servers
- Shared configurations enforced across all users

See [Managed MCP configuration](https://code.claude.com/docs/en/mcp#managed-mcp-configuration) in the official docs.
