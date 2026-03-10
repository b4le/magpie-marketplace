# MCP Delegation Pattern (Dual Return)

Delegate all MCP fetching to foreground sub-agents. The orchestrator must never call MCP tools directly. Sub-agents write full results to disk and return only a concise summary + file path.

## Model

Each MCP result adds ~25KB+ to the calling context window irreversibly. When the orchestrator fetches directly, that bloat accumulates in the main session — the most expensive context to pollute. Background sub-agents cannot access MCP tools at all (GitHub #13254, #19964).

The dual return pattern solves both problems:
- **Context cost:** MCP bloat stays contained in the sub-agent's context. The orchestrator receives ~200 tokens (summary + path) instead of ~25KB.
- **Data fidelity:** Summarization alone retains ~37% of information across compression cycles. Writing full results to disk preserves 98% fidelity. Later agents can read the raw files if they need detail the summary omits.
- **Background agent access:** Any agent in the pipeline can read `local-state/prefetch/` files with the Read tool, regardless of MCP access.

## Template

Add this as Phase 0 before any fan-out that needs external data.

```
### Phase 0: MCP Delegation

1. List all MCP queries the pipeline will need:
   - {query_1}: {source} → {what it returns}
   - {query_2}: {source} → {what it returns}

2. Spawn foreground sub-agent(s) to execute queries:
   - One agent per MCP source, or one agent for all queries if few
   - Agent prompt must include: queries to run, output directory, dual return contract
   - Use ToolSearch inside the sub-agent to load MCP tools

3. Sub-agent executes the dual return:
   a. Run each query, write full results to local-state/prefetch/{session-id}/
      - Use descriptive filenames: {source}-{topic}.json, {source}-{topic}.md
      - One file per query result
      - JSON files: consistent schema {"source":"...","query":"...","timestamp":"...","result_count":N,"data":[...]}
      - Plain text files: .md with YAML frontmatter (source, query, timestamp, result_count)
   b. Return to orchestrator: concise summary of each result + file path
      - Summary: 2-3 sentences per query — what was found, key highlights, result count
      - Path: absolute path to the full result file

4. Orchestrator receives summaries and passes file paths to downstream agents:
   - "Pre-fetched data available at: local-state/prefetch/{session-id}/{filename}"
   - Downstream agents read these files with the Read tool
```

## Decision Tree

```
Need external data for sub-agents?
├── No → skip Phase 0
└── Yes
    ├── Foreground work agent can fetch its own MCP data inline → let it
    └── Orchestrator needs MCP data or multiple agents need it
        → delegate to foreground sub-agent with dual return
        → pass summaries + file paths to downstream agents
```

**Key principle:** The orchestrator never calls MCP tools. If only one downstream agent needs MCP data and it runs in the foreground, it can fetch its own data inline. The delegation pattern is for when the orchestrator would otherwise be the one fetching, or when multiple agents need the same data.

## Guidance

- **Check before re-fetching.** If `local-state/prefetch/{session-id}/` already has results (resume scenario), skip re-enumeration. Check file existence and recency.
- **Use descriptive filenames.** `slack-eng-general-recent.json` not `result1.json`. Agents need to know what they're reading.
- **Staleness window: 4 hours.** Results in `local-state/prefetch/` persist across sessions. Skip re-fetch if the file exists and is <4h old; re-fetch if older.
- **Size-check results.** If a single MCP result is >50KB, the sub-agent should summarize it in the written file as well. Large inputs degrade downstream agent performance.
- **Structured format pays off.** Use JSON with a consistent schema so downstream agents can parse reliably without guessing the format.
- **Model selection for fetch agents.** MCP fetching is mechanical — use `haiku` for the sub-agent unless it also needs to synthesize or filter results, in which case use `sonnet`.

## Example: Research Task with Slack + Drive + Code Search

```
# Phase 0: Delegate MCP fetching
# Spawn a foreground sub-agent with this prompt:

"Fetch the following MCP data and write results to local-state/prefetch/research-{session-id}/:

1. Slack: search for 'auth migration' in #eng-general (last 30 days)
   → write to slack-auth-discussions.json
2. Google Drive: find design docs matching 'auth redesign'
   → write to drive-auth-design-doc.md
3. Code search: find auth middleware implementations
   → write to code-auth-middleware.json

For each query:
- Write full raw results to the file
- Return a 2-3 sentence summary + the file path"

# Sub-agent returns:
# "Slack: 12 messages found, most active discussion on March 3 re: OAuth2 migration timeline.
#  → local-state/prefetch/research-1741234567/slack-auth-discussions.json
#  Drive: Found 2 docs — 'Auth Redesign RFC' (draft) and 'Auth Migration Runbook' (approved).
#  → local-state/prefetch/research-1741234567/drive-auth-design-doc.md
#  Code: 4 files match, primary middleware at src/auth/middleware.ts.
#  → local-state/prefetch/research-1741234567/code-auth-middleware.json"

# Phase 2: Spawn work agents with file paths
Agent prompt: "Pre-fetched data at local-state/prefetch/research-1741234567/.
Read the files to understand current auth state..."
```

## Rationale

The dual return pattern is an application of the scatter-gather model from distributed systems, adapted for the constraint that AI agent context windows are append-only and expensive. Research across multiple AI agent frameworks (Manus, Factory.ai, JetBrains, Google ADK) converged on the same finding: keeping raw data on disk while routing only summaries through orchestration layers is the optimal trade-off between context cost and information fidelity. The knowledge-harvester plugin validates this pattern in production, using `sources/<id>/` directories for pre-fetched content with resume support.
