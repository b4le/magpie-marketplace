---
name: integrating-mcps
description: "Complete guide to connecting and using Model Context Protocol (MCP) servers with Claude Code. Use when integrating external services, configuring OAuth authentication, managing MCP servers, creating custom servers, or troubleshooting MCP connections. Covers transport types, security, enterprise governance, and advanced workflows."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
version: 1.0.0
created: 2025-11-20
last_updated: 2026-02-28
tags:
  - mcp
  - integration
  - external-services
---

# Integrating MCP Servers with Claude Code

Complete guide to connecting and using Model Context Protocol (MCP) servers with Claude Code.

## What is MCP?

Model Context Protocol (MCP) enables Claude Code to connect with external tools, APIs, and data sources. It provides:

- **External Service Access**: Issue trackers, databases, monitoring tools, cloud providers
- **Custom Tools**: Specialized workflows and domain-specific capabilities
- **Dynamic Resources**: Reference external data using @mentions
- **Server Prompts**: MCP-provided prompts become slash commands

**Key Benefits**:
- Extend Claude Code with external capabilities
- Access real-time data from live systems
- Automate workflows across multiple services
- Integrate with your existing toolchain

## When to Use This Skill

Use this skill when you need to:

1. **Connect External Services**
   - Add issue trackers (Jira, Linear, GitHub)
   - Integrate databases (PostgreSQL, MySQL, MongoDB)
   - Connect design tools (Figma, Sketch)
   - Add monitoring systems (Datadog, New Relic)
   - Integrate cloud providers (AWS, GCP, Azure)

2. **Configure Authentication**
   - Set up OAuth 2.0 authentication
   - Configure API key authentication
   - Implement PKCE and RFC 8707 compliance
   - Manage token refresh and rotation

3. **Manage MCP Servers**
   - Add, remove, or update MCP servers
   - Configure transport types (HTTP, stdio)
   - Set connection scopes (local, project, user, managed)
   - Troubleshoot connection issues

4. **Create Custom MCP Servers**
   - Build domain-specific tools
   - Expose internal APIs to Claude Code
   - Create project-specific integrations

5. **Managed Configuration (Organization-Wide)**
   - Configure allowlists and denylists via `managed-mcp.json`
   - Enforce security policies
   - Manage organization-wide servers

### Do NOT Use This Skill When:
- ❌ Just using existing MCP servers → Use MCP tools directly without invoking skill
- ❌ Creating MCP servers from scratch → See the "Creating Your Own MCP Server" section below, or use the `creating-plugins` skill for bundling MCP servers in plugins
- Security-focused MCP configuration → Refer to your organization's security practices
- ❌ Quick MCP commands → Use `/mcp` command directly

## Quick Start

### Add Your First MCP Server

**For cloud services (HTTP)**:
```bash
claude mcp add --transport http <name> <url>
/mcp  # Authenticate if needed
```

**For local tools (stdio)**:
```bash
claude mcp add --transport stdio <name> -- <command>
```

**Example - Add Jira**:
```bash
# 1. Add the server
claude mcp add --transport http jira https://api.jira.example.com/mcp

# 2. Authenticate (opens browser for OAuth flow)
/mcp

# 3. Use it
# "Create a Jira ticket for the bug we just found"
# "List all open issues assigned to me"
```

**Example - Add Local Database**:
```bash
# 1. Add the server
claude mcp add --transport stdio mydb -- npx mcp-sqlite-server ./data/app.db

# 2. Use it immediately (no auth needed for local)
# "Query the users table for accounts created this week"
# "Show me the schema for the orders table"
```

## Transport Types

MCP servers connect using two primary transport methods:

### HTTP (For Cloud Services)

**Best for**: Cloud-based APIs, SaaS tools, remote services

```bash
claude mcp add --transport http <name> <url>
```

**Advantages**:
- Works with cloud services
- Supports OAuth 2.0 authentication
- Standard web protocol (HTTPS)
- Easy to scale across teams

**Use cases**: Jira, Figma, Datadog, custom HTTP APIs

### Stdio (For Local Processes)

**Best for**: Local command-line tools, development databases, scripts

```bash
claude mcp add --transport stdio <name> -- <command>
```

**Advantages**:
- Direct process communication
- Fast local operations
- No network overhead
- Works offline

**Use cases**: Local databases, project-specific scripts, development tools

**Note**: SSE (Server-Sent Events) transport is deprecated. Use HTTP or stdio instead.

**Detailed information**: @reference/transport-details.md

## Connection Scopes

Configure MCP servers at different levels:

### Local Scope (Project-Specific, Private)
```bash
claude mcp add --transport stdio mydb -- ./scripts/db-mcp.js
```
- Configuration: `~/.claude.json` (stored under your project's path entry)
- Use for: Personal dev servers, experimental configs, sensitive credentials not for sharing

### Project Scope (Shared with Team)
```bash
claude mcp add --scope project --transport http my-service https://api.example.com
```
- Configuration: `.mcp.json` in project root (checked into source control)
- Use for: Team-shared servers, project-specific tools, collaborative services

### User Scope (Personal, Cross-Project)
```bash
claude mcp add --scope user --transport http my-service https://api.example.com
```
- Configuration: `~/.claude.json` (mcpServers field)
- Use for: Personal tools across all projects, your API keys

### Managed Configuration (Organization-Wide)
- Configured by administrators via `managed-mcp.json` in system directories
- Use for: Company-wide services, policy-based allowlists and denylists

**Details**: @reference/configuration-files.md

## Authentication Overview

### OAuth 2.0 (Cloud Services)

**Quick setup**:
```bash
# 1. Add MCP server
claude mcp add --transport http jira https://api.jira.example.com/mcp

# 2. Authenticate (opens browser)
/mcp

# 3. Tokens stored securely and auto-refreshed
```

**Security requirements** (as of June 2025):
- PKCE (Proof Key for Code Exchange) recommended
- HTTPS only (no HTTP)
- RFC 8707 Resource Indicators supported (not documented as mandatory by Claude Code)
- Token rotation and validation

### API Key (Local/Simple Auth)

Use environment variables:
```json
{
  "mcpServers": {
    "myapi": {
      "type": "stdio",
      "command": "node",
      "args": ["server.js"],
      "env": {
        "API_KEY": "${MY_API_KEY}"
      }
    }
  }
}
```

Set environment variable:
```bash
export MY_API_KEY="your-api-key-here"
```

**Complete authentication guide**: @reference/authentication-guide.md

## Using MCP Resources

### Resource References with @

Reference MCP resources using @ mentions:
```
@server:protocol://resource/path
```

**Examples**:
```
Review the design from @figma:file://designs/user-dashboard
Get issue details from @jira:issue://PROJ-123
Check documentation at @notion:file://docs/api-guide
```

### Discovering Resources

```
List all available MCP resources
List resources from the jira server
Read resource from jira server: issue/PROJ-123
```

### MCP Server Tools

MCP servers provide tools that Claude automatically discovers and uses:

**Example**: Database MCP server provides:
- `query_database` tool
- `insert_record` tool
- `update_record` tool

**Example**: Jira MCP server provides:
- `create_issue` tool
- `update_issue` tool
- `search_issues` tool

Claude uses these tools automatically when appropriate for your task.

## Common Use Cases

### 1. Issue Tracker Integration
Connect Jira, Linear, GitHub Issues for:
- Creating tickets from bugs
- Listing and filtering issues
- Updating issue status
- Adding comments and attachments

### 2. Database Access
Connect PostgreSQL, MySQL, SQLite for:
- Querying data
- Analyzing schemas
- Inserting test data
- Database migrations

### 3. Design Tool Integration
Connect Figma, Sketch for:
- Reviewing latest designs
- Extracting design tokens
- Comparing designs with implementation

### 4. Monitoring & Analytics
Connect Datadog, New Relic for:
- Checking error rates
- Analyzing performance metrics
- Investigating incidents

### 5. Documentation Systems
Connect Notion, Confluence for:
- Searching documentation
- Updating guides
- Creating new pages

### 6. Cloud Providers
Connect AWS, GCP, Azure for:
- Managing cloud resources
- Checking service status
- Viewing logs and metrics

**Detailed use case examples**: @reference/use-cases.md

## Configuration Best Practices

### 1. Use Environment Variables for Secrets
```json
{
  "mcpServers": {
    "api": {
      "env": {
        "API_KEY": "${API_KEY}",
        "API_SECRET": "${API_SECRET}"
      }
    }
  }
}
```

### 2. Set Output Token Limits
```bash
export MAX_MCP_OUTPUT_TOKENS=5000
```

Note: The token limit is configured via the `MAX_MCP_OUTPUT_TOKENS` environment variable only — there is no `maxOutputTokens` JSON field in MCP server configuration.

### 3. Use Descriptive Server Names

**Good**: `jira-prod`, `postgres-dev`, `figma-design`
**Bad**: `server1`, `api`, `test`

### 4. Separate by Environment
```json
{
  "mcpServers": {
    "db-dev": { "args": ["postgresql://localhost:5432/dev"] },
    "db-prod": { "args": ["postgresql://prod-db:5432/production"] }
  }
}
```

**Complete configuration guide**: @reference/configuration-files.md

## Security Considerations

### OAuth 2.0 Compliance Checklist

Before deploying an MCP server with OAuth:

- [ ] PKCE enabled for authorization code flow
- [ ] All endpoints use HTTPS (no HTTP)
- [ ] Refresh token rotation implemented
- [ ] RFC 8707 Resource Indicators configured
- [ ] Token validation includes `aud` and `iss` claims
- [ ] Token expiration properly enforced

### Key Security Principles

1. **Verify Trust**: Only connect to trusted MCP servers
2. **Minimal Permissions**: Grant least privilege access
3. **No Wildcards**: MCP permissions require exact specifications
4. **Separate Environments**: Different configs for dev/prod
5. **Review Output**: Always verify MCP server responses

**Important**: No wildcard support in permissions. Must specify exact permissions:
```json
{
  "permissions": [
    "read:users",
    "read:posts",
    "write:users"
  ]
}
```

**Complete security guide**: @reference/security-considerations.md

## Troubleshooting

### Common Issues

**Server Connection Fails**:
- Check server is running
- Verify URL/command is correct
- Review server logs
- Re-authenticate with `/mcp`

**Authentication Fails**:
- Run `/mcp` to re-authenticate
- Check OAuth scopes
- Verify client ID and secrets
- Clear tokens and retry

**Resource Not Found**:
- List available resources first
- Check resource path format
- Verify permissions

**Tool Not Available**:
- Verify server is connected
- Restart Claude Code
- Check server logs

**Performance Issues**:
- Set `MAX_MCP_OUTPUT_TOKENS` limit
- Use more specific queries
- Check network latency

**Complete troubleshooting guide**: @reference/troubleshooting.md

## Advanced Patterns

### 1. Chaining MCP Servers
```
Get issue from @jira:issue://PROJ-123
Update docs in @notion:file://docs/issues
Post notification in @slack:channel://team-channel
```

### 2. Dynamic Resource Discovery
```
List all resources from figma server
Review each design file
Create implementation tickets in jira
```

### 3. Automated Workflows
Create slash commands that leverage MCP tools across multiple services.

### 4. Data Aggregation
```
Compare:
- Error rates from @datadog:metrics://errors
- User reports from @jira:issue://issues/bugs
- Usage stats from @analytics:dashboard://summary
```

**Complete advanced patterns guide**: @reference/advanced-patterns.md

## Creating Your Own MCP Server

### FastMCP (Python)
```python
from fastmcp import FastMCP

mcp = FastMCP("My Custom Server")

@mcp.tool()
def my_custom_tool(param: str) -> str:
    """Description of what this tool does"""
    return f"Processed: {param}"
```

### MCP SDK (TypeScript/Node)
```typescript
import { Server } from "@modelcontextprotocol/sdk/server";

const server = new Server({
  name: "my-custom-server",
  version: "1.0.0"
});
```

**For bundling MCP servers in plugins**: Use the `creating-plugins` skill

## Best Practices Summary

1. **Verify Trust**: Only connect to trusted MCP servers
2. **Use HTTPS**: Prefer HTTP transport with TLS for cloud services
3. **Environment Variables**: Never hardcode secrets
4. **Minimal Permissions**: Grant least privilege access
5. **Separate Environments**: Different configs for dev/staging/prod
6. **Monitor Usage**: Track MCP operations and costs
7. **Set Token Limits**: Control output size with MAX_MCP_OUTPUT_TOKENS
8. **Document Servers**: Note what each server is for
9. **Regular Review**: Periodically audit connected servers
10. **Test Locally**: Verify MCP servers before sharing with team

## Resources

- **MCP Documentation**: https://code.claude.com/docs/en/mcp
- **MCP Specification**: https://modelcontextprotocol.io
- **Example MCP Servers**: https://github.com/modelcontextprotocol
- **Create MCP Servers**: See the "Creating Your Own MCP Server" section above; for plugin bundling see the `creating-plugins` skill
