# Advanced Patterns

## 1. Chaining MCP Servers

Use multiple MCP servers together:

```
Get the issue details from @jira:issue://PROJ-123
Then update the documentation in @notion:file://docs/issues
Finally, post update in @slack:channel://team-channel
```

## 2. Dynamic Resource Discovery

```
List all available resources from the figma server
Then review each design file
Create implementation tickets in jira for each
```

## 3. Automated Workflows

Create slash commands that leverage MCP:

```markdown
---
description: Create issue from bug
---

Analyze the bug in $1.

Then:
1. Create a Jira ticket with details
2. Add to current sprint
3. Assign to appropriate team member
4. Post notification in Slack
```

## 4. Data Aggregation

```
Compare data from three sources:
1. Error rates from @datadog:metrics://errors
2. User reports from @jira:issue://issues/bugs
3. Usage stats from @analytics:dashboard://summary

Identify correlations and insights.
```
