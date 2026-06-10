# Transport Types

MCP servers can connect via three transport methods:

## 1. HTTP (Recommended for Cloud Services)

Best for cloud-based servers with HTTP APIs.

```bash
claude mcp add --transport http <name> <url>
```

**Example**:
```bash
claude mcp add --transport http jira https://api.jira.example.com/mcp
```

**Advantages**:
- Works with cloud services
- Supports OAuth 2.0 authentication
- Standard web protocol
- Easy to scale

## 2. Stdio (For Local Processes)

Best for local command-line tools and scripts.

```bash
claude mcp add --transport stdio <name> -- <command>
```

**Example**:
```bash
claude mcp add --transport stdio database -- npx mcp-database-server
```

**Advantages**:
- Direct process communication
- Fast local operations
- No network overhead
- Works offline

## 3. SSE (Deprecated)

Server-Sent Events transport is deprecated. Use HTTP or stdio instead.
