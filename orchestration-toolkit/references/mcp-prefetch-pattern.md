# MCP Pre-Fetch Pattern (Scatter-Gather)

Gather all external data in the orchestrator before spawning sub-agents. Sub-agents receive file paths, not MCP tool access.

## Model

Background sub-agents cannot access MCP tools — this is a platform limitation, not a configuration issue (GitHub #13254, #19964). Additionally, each MCP search result adds ~25KB to the main context window irreversibly. Pre-fetching solves both problems: agents get the data they need without tool access, and the orchestrator controls context costs.

## Template

Add this as Phase 0 before any fan-out that needs external data.

```
### Phase 0: MCP Pre-Fetch

1. List all MCP queries sub-agents will need:
   - {query_1}: {source} → {what it returns}
   - {query_2}: {source} → {what it returns}

2. Execute all queries in the orchestrator (main session):
   - Use ToolSearch to load MCP tools if needed
   - Run each query, capture results

3. Write results to /tmp/prefetch/{session-id}/:
   - Use descriptive filenames: {source}-{topic}.json, {source}-{topic}.md
   - One file per query result
   - JSON files: use consistent schema `{"source":"...","query":"...","timestamp":"...","result_count":N,"data":[...]}`
   - Plain text files: use .md with YAML frontmatter (source, query, timestamp, result_count)

4. Pass file paths to sub-agents in their prompts:
   - "Pre-fetched data available at: /tmp/prefetch/{session-id}/{filename}"
   - Sub-agents read these files with the Read tool
```

## Decision Tree

```
Need external data for sub-agents?
├── No → skip Phase 0
└── Yes → How many MCP sources?
    ├── 1-2 sources, few queries → query directly in main session, pass inline
    ├── 3+ sources → delegate ALL research to a single sub-agent first
    └── Sub-agents need the data → must pre-fetch to /tmp/prefetch/
```

**Key distinction:** The MCP search delegation rule (3+ sources → sub-agent) is about protecting the main context window. The pre-fetch rule is about giving background agents data they literally cannot fetch themselves. Both can apply to the same task.

## Guidance

- **Check before re-fetching.** If `/tmp/prefetch/{session-id}/` already has results (resume scenario), skip re-enumeration. Check file existence and recency.
- **Use descriptive filenames.** `slack-eng-general-recent.json` not `result1.json`. Agents need to know what they're reading.
- **Clean up at session end.** `/tmp/prefetch/` is ephemeral. Don't rely on it persisting across sessions.
- **Foreground agents are exempt.** Agents running in the foreground (default) inherit MCP access. Only pre-fetch for background agents or when delegating to teams.
- **Size-check results.** If a single MCP result is >50KB, summarize it before passing to sub-agents. Large inputs degrade agent performance.
- **Structured format pays off.** Use JSON with a consistent schema so sub-agents can parse reliably without guessing the format.

## Example: Research Task with Slack + Drive + Code Search

```
# Phase 0: Pre-fetch
session_id="research-$(date +%s)"
mkdir -p /tmp/prefetch/$session_id

# Query 1: Slack
→ /tmp/prefetch/$session_id/slack-auth-discussions.json

# Query 2: Google Drive
→ /tmp/prefetch/$session_id/drive-auth-design-doc.md

# Query 3: Code search
→ /tmp/prefetch/$session_id/code-auth-middleware.json

# Phase 2: Spawn agents with paths
Agent prompt: "Pre-fetched data at /tmp/prefetch/$session_id/. Read the files to understand current auth state..."
```

## Rationale

The scatter-gather pattern is well-established in distributed systems. Applied to AI agents, it addresses a concrete platform constraint (no MCP in background agents) while also serving as a context budget optimization. The knowledge-harvester plugin validates this pattern in production, using `sources/<id>/` directories for pre-fetched content with resume support.
