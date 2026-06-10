# Security Considerations

## OAuth 2.0 Compliance Checklist

Before deploying an MCP server with OAuth:

- [ ] PKCE enabled for authorization code flow
- [ ] All endpoints use HTTPS (no HTTP)
- [ ] Refresh token rotation implemented
- [ ] RFC 8707 Resource Indicators configured
- [ ] Token validation includes `aud` and `iss` claims
- [ ] Token expiration properly enforced
- [ ] Audience matching validated on every request

## 1. Verify Server Trustworthiness

Before connecting to an MCP server:
- Verify the source and author
- Review the server's code if open source
- Check permissions the server requests
- Understand what data the server can access

**Never connect to untrusted MCP servers.**

## 2. Use Minimal Permissions

Grant only necessary permissions:

```json
{
  "mcpServers": {
    "read-only-db": {
      "type": "stdio",
      "command": "mcp-postgres",
      "args": ["--read-only", "postgresql://localhost/mydb"]
    }
  }
}
```

## No Wildcard Support

MCP permissions do NOT support wildcards. You must specify exact permissions:

**This does NOT work**:
```json
{
  "permissions": ["read:*", "write:*"]
}
```

**Do this instead**:
```json
{
  "permissions": [
    "read:users",
    "read:posts",
    "write:users",
    "write:posts"
  ]
}
```

## 3. Separate Production and Development

Don't use production credentials in development:

```bash
# Development
claude mcp add --transport stdio db-dev -- mcp-db --env dev

# Production (separate profile/configuration)
claude mcp add --scope user --transport stdio db-prod -- mcp-db --env prod
```

## 4. Review MCP Server Output

Always review what MCP servers return before using the data.

## 5. Managed Configuration Controls

For teams, use managed configuration via `managed-mcp.json`:
- Allowlist approved servers
- Denylist unauthorized servers
- Centrally manage credentials
- Monitor MCP usage
