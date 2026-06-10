# Integrating MCPs

Complete guide to connecting and using Model Context Protocol (MCP) servers with Claude Code.

## Overview

This skill provides comprehensive guidance for integrating external services with Claude Code through the Model Context Protocol. Learn to connect issue trackers, databases, cloud services, and custom tools with proper authentication and security.

## Installation

This is a user-level skill located at:
```
~/.claude/skills/integrating-mcps/
```

## Usage

Activate this skill by requesting:
- "Help me integrate an MCP server"
- "Set up OAuth for my MCP connection"
- "Connect a database to Claude Code"
- "Create a custom MCP server"
- "Troubleshoot my MCP connection"

## Contents

- **SKILL.md** - Main skill file (483 lines)
- **templates/** - Configuration templates (2 files)
  - `mcp-config-template.json` - Complete mcp.json configuration examples
  - `oauth-server-template.json` - OAuth 2.1 authentication template
- **examples/** - Practical examples (3 files)
  - `issue-tracker-setup.md` - Jira/Linear integration guide
  - `database-integration.md` - PostgreSQL/SQLite setup
  - `custom-mcp-server.md` - Building your own MCP server
- **reference/** - Detailed reference (7 files)
  - `transport-details.md` - HTTP and stdio transport configuration
  - `authentication-guide.md` - OAuth 2.1 and API key authentication
  - `configuration-files.md` - Project, user, and enterprise configs
  - `use-cases.md` - Common integration scenarios
  - `security-considerations.md` - Security best practices
  - `troubleshooting.md` - Common issues and solutions
  - `advanced-patterns.md` - Chaining servers, workflows, automation

## Quick Links

- [OAuth Authentication](reference/authentication-guide.md)
- [Security Best Practices](reference/security-considerations.md)
- [Common Use Cases](reference/use-cases.md)
- [Troubleshooting](reference/troubleshooting.md)

## Version History

**v1.0.0** (2025-11-18)
- Initial skill creation from mcp-integration-guide.md
- 6 core capabilities documented
- 13 total files (1 SKILL.md + 12 supporting)
- 7 @path imports for progressive disclosure
- Complete OAuth 2.1 and RFC 8707 coverage
