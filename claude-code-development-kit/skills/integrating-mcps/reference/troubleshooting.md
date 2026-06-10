# Troubleshooting

## Server Connection Issues

**Problem**: Cannot connect to MCP server

**Solutions**:
1. Check server is running: `ps aux | grep mcp`
2. Verify URL is correct (for HTTP)
3. Check network connectivity
4. Review server logs
5. Verify authentication (use `/mcp` to re-authenticate)

## Authentication Failures

**Problem**: OAuth authentication fails

**Solutions**:
1. Run `/mcp` to re-authenticate
2. Check OAuth scopes in configuration
3. Verify client ID and secrets
4. Clear stored tokens and re-authenticate
5. Check server OAuth configuration

## Resource Not Found

**Problem**: Cannot access MCP resource

**Solutions**:
1. List available resources to verify path
2. Check resource permissions
3. Verify server is connected
4. Check resource format: `@server:protocol://resource/path`

## Tool Not Available

**Problem**: MCP tool not showing up

**Solutions**:
1. Verify server is connected
2. Check server provides that tool
3. Restart Claude Code to refresh tool list
4. Review server logs for errors

## Performance Issues

**Problem**: MCP operations are slow

**Solutions**:
1. Set `MAX_MCP_OUTPUT_TOKENS` to limit response size
2. Use more specific queries
3. Check network latency (for HTTP servers)
4. Consider caching strategies
5. Optimize server-side processing
