# Authentication

## OAuth 2.0 Authentication

For cloud-based MCP servers:

```bash
# Add MCP server
claude mcp add --transport http jira https://api.jira.example.com/mcp

# Authenticate (opens browser for OAuth flow)
/mcp
```

**Process**:
1. Add MCP server
2. Use `/mcp` command to authenticate
3. Complete OAuth flow in browser
4. Tokens stored securely and auto-refreshed

## OAuth 2.0 Security Requirements

As of June 2025, Claude Code requires OAuth 2.0 compliance:

### PKCE (Proof Key for Code Exchange)
**Recommended** for all authorization code flows.

The official Claude Code MCP documentation documents two fields in the `oauth` JSON
config object: `clientId` and `callbackPort`. Fields such as `authorizationUrl`,
`tokenUrl`, `pkce`, `resource`, `scopes`, and `audience` are not part of the documented
configuration schema — implementation support may vary.

The documented way to add a server with pre-configured OAuth credentials is:

```bash
claude mcp add-json my-server \
  '{"type":"http","url":"https://mcp.example.com/mcp","oauth":{"clientId":"your-client-id","callbackPort":8080}}' \
  --client-secret
```

Or using flags:

```bash
claude mcp add --transport http \
  --client-id your-client-id --client-secret --callback-port 8080 \
  my-server https://mcp.example.com/mcp
```

### HTTPS Only
All OAuth endpoints MUST use HTTPS. HTTP endpoints will be rejected.

### Token Rotation
Refresh tokens must support rotation. Expired refresh tokens should return appropriate errors.

### Token Validation
Claude Code validates:
- Token expiration (`exp` claim)
- Audience matching (`aud` claim must match server)
- Issuer verification (`iss` claim)

## RFC 8707 Resource Indicators

RFC 8707 resource indicators allow a token request to specify which resource server(s)
the access token is intended for. This can improve security by scoping tokens to specific
services.

Note: The official Claude Code MCP documentation does not document RFC 8707 support as
mandatory. Whether a given MCP server implements or requires resource indicators depends
on the server and OAuth provider configuration. The fields below are not part of the
documented `oauth` configuration schema.

**Key points**:
- `resource` parameter can be sent in the token request to identify the target API
- `aud` claim in JWT identifies the intended audience
- Prevents token misuse across different APIs when supported
- Not required by Claude Code itself — depends on the server implementation

## API Key Authentication

For servers requiring API keys, use environment variables:

```bash
claude mcp add --transport stdio myapi -- node server.js
```

In your `~/.claude.json`:
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
