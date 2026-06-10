# Issue Tracker Integration Example

## Scenario

You want to integrate Linear (or Jira) with Claude Code so you can:
- Query issues and tickets directly from Claude
- Create new issues with proper formatting
- Update issue status and assignments
- Link code changes to issues

This example shows complete setup for Linear. Jira setup is similar.

---

## Prerequisites

1. Linear account with workspace access
2. Linear API key (Personal or OAuth)
3. Claude Code installed and configured

---

## Step 1: Get Linear API Credentials

### Option A: Personal API Key (Simpler)

1. Go to Linear Settings → API → Personal API Keys
2. Create new key with name "Claude Code"
3. Copy the key (starts with `lin_api_`)
4. Save to environment:

```bash
export LINEAR_API_KEY="lin_api_YOUR_KEY_HERE"
```

Add to `~/.zshrc` or `~/.bashrc` to persist:

```bash
echo 'export LINEAR_API_KEY="lin_api_YOUR_KEY_HERE"' >> ~/.zshrc
source ~/.zshrc
```

### Option B: OAuth (More Secure)

1. Go to Linear Settings → API → OAuth Applications
2. Create new OAuth app:
   - Name: "Claude Code"
   - Redirect URI: `http://localhost:3000/oauth/callback` (check Claude Code docs)
3. Copy Client ID (OAuth uses authorization flow)
4. Save Client ID:

```bash
export LINEAR_CLIENT_ID="your_client_id_here"
```

---

## Step 2: Install Linear MCP Server

Linear provides an official MCP server via npm:

```bash
# Test installation first
npx -y @linear/mcp-server

# If successful, you're ready to configure
```

---

## Step 3: Configure Claude Code

### Option A: Personal API Key Configuration

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "linear": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": [
          "-y",
          "@linear/mcp-server"
        ]
      },
      "env": {
        "LINEAR_API_KEY": "${LINEAR_API_KEY}"
      }
    }
  }
}
```

### Option B: OAuth Configuration

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "linear": {
      "transport": {
        "type": "http",
        "url": "https://api.linear.app/mcp"
      },
      "oauth": {
        "authorizationUrl": "https://linear.app/oauth/authorize",
        "tokenUrl": "https://api.linear.app/oauth/token",
        "clientId": "${LINEAR_CLIENT_ID}",
        "scopes": ["read", "write"],
        "pkce": true
      },
      "env": {
        "LINEAR_CLIENT_ID": "${LINEAR_CLIENT_ID}"
      }
    }
  }
}
```

---

## Step 4: Restart Claude Code

```bash
# Restart Claude Code to load the new MCP server
# (Method depends on how you run Claude Code)
```

---

## Step 5: Verify Integration

In Claude Code, test the integration:

```
List my open Linear issues
```

Expected response:
- Claude will use the Linear MCP server tools
- You'll see a list of issues assigned to you
- Each issue shows ID, title, status, priority

---

## Example Usage Commands

### Query Issues

```
Show me all P0 issues in the mobile team
```

```
What issues are blocked in the current sprint?
```

```
Find all bugs reported this week
```

### Create Issues

```
Create a new bug: "Login button not responding on iOS"
- Priority: High
- Team: Mobile
- Labels: bug, ios
```

### Update Issues

```
Update issue ENG-123 to "In Progress" and assign to me
```

```
Add comment to ENG-456: "Fixed in PR #789"
```

### Link to Code

```
Create issue from this bug:
[paste error log]

Assign to backend team, link to file /api/auth.ts
```

---

## Configuration Variations

### Multiple Workspaces

```json
{
  "mcpServers": {
    "linear-work": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@linear/mcp-server"]
      },
      "env": {
        "LINEAR_API_KEY": "${LINEAR_WORK_API_KEY}",
        "LINEAR_WORKSPACE": "work-workspace-id"
      }
    },
    "linear-personal": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@linear/mcp-server"]
      },
      "env": {
        "LINEAR_API_KEY": "${LINEAR_PERSONAL_API_KEY}",
        "LINEAR_WORKSPACE": "personal-workspace-id"
      }
    }
  }
}
```

### Custom Filters

```json
{
  "mcpServers": {
    "linear": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@linear/mcp-server"]
      },
      "env": {
        "LINEAR_API_KEY": "${LINEAR_API_KEY}",
        "LINEAR_DEFAULT_TEAM": "ENG",
        "LINEAR_DEFAULT_PROJECT": "Q1-2025"
      }
    }
  }
}
```

---

## Common Issues

### Issue: "Command not found: npx"

**Solution**: Install Node.js:
```bash
# macOS
brew install node

# Or use nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
```

### Issue: "Linear API key invalid"

**Solution**:
- Verify key is correct (starts with `lin_api_`)
- Check environment variable is set: `echo $LINEAR_API_KEY`
- Regenerate key in Linear settings if needed

### Issue: "Permission denied" errors

**Solution**:
- Check API key has correct scopes (read, write)
- Verify workspace access
- For OAuth: Re-authorize and check scopes

### Issue: "MCP server not responding"

**Solution**:
- Test server manually: `npx -y @linear/mcp-server`
- Check Claude Code logs for errors
- Verify network connectivity
- Restart Claude Code

### Issue: "Rate limit exceeded"

**Solution**:
- Linear has rate limits (check Linear docs)
- Reduce query frequency
- Use filters to narrow results
- Consider caching results

---

## Jira Alternative

For Jira, the setup is similar:

```json
{
  "mcpServers": {
    "jira": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@jira/mcp-server"]
      },
      "env": {
        "JIRA_URL": "https://your-company.atlassian.net",
        "JIRA_EMAIL": "your-email@company.com",
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
      }
    }
  }
}
```

Get Jira API token: https://id.atlassian.com/manage-profile/security/api-tokens

---

## Best Practices

1. **Use OAuth for shared environments** - More secure, easier to revoke
2. **Set environment variables** - Never hardcode credentials
3. **Use specific scopes** - Request only needed permissions
4. **Test queries** - Start with simple queries to verify setup
5. **Monitor rate limits** - Be aware of API quotas
6. **Keep MCP server updated** - Run `npm update -g @linear/mcp-server` periodically

---

## Next Steps

- Explore advanced Linear queries (filters, custom fields)
- Set up webhooks for real-time updates
- Integrate with Git commit messages
- Create custom workflows (auto-create issues from errors)
- Combine with other MCP servers (GitHub, Slack)

---

## Resources

- Linear API Documentation: https://developers.linear.app
- Linear MCP Server: https://github.com/linear/mcp-server
- Claude Code MCP Guide: https://docs.anthropic.com/claude-code/mcp
- OAuth 2.0 Specification: https://oauth.net/2.0/
