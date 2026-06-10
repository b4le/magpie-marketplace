# MCP Server Issues

Troubleshooting MCP server connections, authentication, resources, and tools.

## Cannot Connect to MCP Server

**Problem**: MCP server connection fails

**Diagnostics**:
```bash
# Check if server process is running
ps aux | grep mcp

# For HTTP servers, test URL
curl https://api.example.com/mcp

# Check config
cat .claude/mcp.json
```

**Solutions**:
1. Verify server is running
2. Check URL is correct
3. Test network connectivity
4. Review server logs
5. Verify authentication
6. Check firewall settings

## MCP Authentication Failures

**Problem**: OAuth authentication fails

**Solutions**:
1. Re-authenticate:
```bash
/mcp
```

2. Check OAuth configuration
3. Verify client ID and secrets
4. Clear stored tokens:
```bash
rm ~/.claude/mcp-tokens.json
```

5. Check server OAuth settings

## MCP Resource Not Found

**Problem**: Cannot access MCP resource

**Solutions**:
1. List available resources
2. Check resource path syntax
3. Verify permissions
4. Confirm server is connected
5. Review server documentation

## MCP Tool Not Available

**Problem**: Expected MCP tool not showing up

**Solutions**:
1. Verify server is connected
2. Check server provides that tool
3. Restart Claude Code
4. Review server logs
5. Check tool permissions
