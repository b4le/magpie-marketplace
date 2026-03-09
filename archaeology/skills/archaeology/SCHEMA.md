# Domain File Schema v1.0

All domain files MUST use this YAML frontmatter structure.

## Required Fields

```yaml
---
domain: string           # Domain ID (must match filename without .md)
status: enum             # active | planned | deprecated | archived
maintainer: string       # Owner/team name
last_updated: date       # YYYY-MM-DD format
version: semver          # e.g., 1.0.0

agent_count: integer     # Number of parallel Explore agents (1-6)

keywords:
  primary: [string]      # Must appear for match
  secondary: [string]    # Boost relevance
  exclusion: [string]    # Filter false positives

locations:               # Search locations for agents
  - path: string         # Path pattern with {PROJECT_ROOT}, {PROJECT_PATH_PATTERN}
    purpose: string      # What to find here
    priority: enum       # high | medium | low

outputs:
  - file: string         # Output filename
    required: boolean    # true = always create, false = if found
    template: string     # Reference to output-templates.md anchor (readme, prompts, patterns, etc.)
---
```

## Example

```yaml
---
domain: orchestration
status: active
maintainer: archaeology-skill
last_updated: 2026-02-26
version: 1.0.0
agent_count: 4
keywords:
  primary: [Task, subagent_type, TeamCreate, SendMessage]
  secondary: [parallel, orchestrat, agent, spawn]
  exclusion: []
locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation history"
    priority: high
outputs:
  - file: README.md
    required: true
    template: readme
---
```

## Field Descriptions

### domain
Domain identifier. Must match filename (e.g., `orchestration.md` → `domain: orchestration`).

### status
Lifecycle stage:
- `active`: Fully operational, maintained
- `planned`: Not yet implemented
- `deprecated`: No longer recommended
- `archived`: Historical reference only, no longer in active use

### maintainer
Individual or team responsible for domain updates.

### last_updated
Date of last schema modification (YYYY-MM-DD format).

### version
Semantic version (major.minor.patch). Increment on schema changes.

### agent_count
Number of parallel Explore agents to spawn (1-6). Higher count for larger search spaces. Each agent searches ALL locations — agents do not map 1:1 to locations.

### keywords
Search term configuration:
- `primary`: MUST appear in file for match
- `secondary`: Boost relevance scoring
- `exclusion`: Filter false positives

### locations
Search paths for agents. Each location has:
- `path`: Glob pattern with `{PROJECT_ROOT}`, `{PROJECT_PATH_PATTERN}` placeholders
- `purpose`: Human-readable explanation
- `priority`: `high | medium | low` - affects search order

### outputs
Artifacts to generate. Each output has:
- `file`: Output filename (relative to domain output directory)
- `required`: `true` = always create, `false` = only if relevant content found
- `template`: Anchor ID from `output-templates.md` (e.g., `readme`, `prompts`, `patterns`)

## Validation

Run `scripts/validate-domains.sh` to check compliance.

---

# Finding Object Schema (v2)

**Canonical schema for `findings.json` output.** For how to consume these findings, see `references/consumption-spec.md`.

Findings exported to `findings.json` use this structure:

### Required Fields (v1)

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique ID within run, format: `f-001` |
| `type` | enum | `pattern` \| `decision` \| `artifact` \| `capability` |
| `title` | string | Brief description of the finding |
| `description` | string | Detailed explanation |
| `evidence` | string[] | File paths, quotes, or references |
| `tags` | string[] | Domain name + matched keywords + finding type |
| `date` | string | YYYY-MM-DD format |

### Scoring Fields (v2)

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `confidence` | enum | `high` \| `medium` \| `low` | How certain the finding is real |
| `relevance` | enum | `high` \| `medium` \| `low` | How useful for future work |

**Confidence heuristics:**
- `high` — 2+ evidence items with code block
- `medium` — 1 evidence item or context-only
- `low` — inferred with weak evidence

**Relevance heuristics:**
- `high` — reusable pattern or decision with broad applicability
- `medium` — useful in specific contexts
- `low` — one-off capability or narrow technique

### Top-Level findings.json Fields (v2)

| Field | Type | Description |
|-------|------|-------------|
| `highlights` | string[] | Ordered finding IDs where confidence=high AND relevance=high, capped at 5. Sorted by type priority: pattern > decision > artifact > capability |

### Backward Compatibility

v1 findings lack `confidence`, `relevance`, and `highlights`. Consumers must treat missing fields as unscored.

---

# Workstyle Object Schema (v1)

**Canonical schema for `workstyle.json` output.** Workstyle data is structurally different from findings — it describes working dimensions and scores, not discrete findings.

### Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version, `"1.0"` |
| `generated_at` | ISO string | When the analysis ran |
| `project` | string | Project name (or `"global"` for --global) |
| `project_slug` | string | URL-safe project identifier |
| `scope` | enum | `"project"` \| `"global"` |
| `session_count` | integer | Number of sessions analysed |
| `session_range` | object | `{ earliest, latest }` ISO timestamps |
| `confidence` | enum | `"high"` (10+) \| `"medium"` (5-9) \| `"low"` (3-4) |
| `summary` | string | 2-3 sentence working style characterisation |

### Dimension Fields

| Field | Type | Description |
|-------|------|-------------|
| `session_patterns` | object | Pattern percentages + `dominant_pattern` |
| `tool_usage` | object | `total_tool_calls`, `unique_tools`, `top_tools[]`, `skill_usage[]`, `agent_types[]` |
| `delegation` | object | `solo_pct`, `delegated_pct`, `team_pct`, `avg_agents_per_delegated_session` |
| `communication` | object | `instruction_style`, `avg_instruction_length`, `feedback_style`, `correction_frequency` |
| `session_shape` | object | `avg_duration_minutes`, `avg_exchanges`, `avg_tool_calls_per_session`, `typical_arc` |
| `preferences` | object | `confirmed[]`, `detected[]`, `contradicted[]` |
| `evolution` | object | `trend`, `early_dominant_pattern`, `recent_dominant_pattern`, `delegation_trend` |

### Confidence Scoring

- `"high"` — 10+ sessions with diverse patterns
- `"medium"` — 5-9 sessions
- `"low"` — 3-4 sessions (or override from minimum threshold check)

---

# Artifact Object Schema (v1)

**Canonical schema for artifact `.md` files and `_index.json`.** Artifacts are atomic narrative objects (150-300 words) that tell one story about a project.

### Artifact Types

| Type | What it is | Natural sections |
|------|-----------|-----------------|
| `shipment` | A feature, launch, or milestone delivered | What was built / Why it matters / The result |
| `decision` | A choice made and why | The options / The constraints / The choice / What happened next |
| `incident` | Something broke and what we learned | What broke / The response / The fix / The systemic change |
| `discovery` | A surprise, insight, or busted assumption | The assumption / The evidence / The new understanding |
| `tale` | A story worth telling for its arc | The setup / The complication / The resolution |
| `practice` | How we work -- a process or workflow | What we do / Why it emerged / What problem it solves |

### Artifact Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Project-scoped ID, format `art-NNN` |
| `project` | string | yes | Project slug, matches directory name |
| `uri` | string | yes | Global address `arch://{project}/{id}` |
| `type` | enum | yes | `shipment` \| `decision` \| `incident` \| `discovery` \| `tale` \| `practice` |
| `title` | string | yes | Human-readable headline, max 80 chars |
| `confidence` | enum | yes | `high` \| `medium` \| `low` |
| `significance` | integer | yes | 1-10 editorial weight for exhibition curation |
| `tags` | string[] | yes | At least one tag, free-form shared vocabulary |
| `conserved_at` | date | yes | When the artifact was created (YYYY-MM-DD) |
| `session_date` | date | yes | When the source event occurred (YYYY-MM-DD) |
| `sources.findings` | object[] | no | Finding references: `{id, title}` |
| `sources.sessions` | object[] | yes | Session references: `{path, label}` |
| `status` | enum | yes | `draft` \| `refined` \| `published` |
| `revised` | date/null | yes | Last human edit date, null if unedited |
| `related` | object[] | no | Cross-references: `{uri, relation}` |
| `exhibitions` | string[] | no | Back-references from exhibitions |

### Confidence Scoring (Source-Grounded)

| Level | Criteria |
|-------|----------|
| `high` | Direct quote or specific session reference with concrete detail |
| `medium` | Inferred from multiple sessions, no single clear source |
| `low` | Synthesized from general patterns, no specific evidence |

### Per-Project Index (`_index.json`) Fields

| Field | Type | Description |
|-------|------|-------------|
| `project` | string | Project slug |
| `generated_at` | ISO string | When the index was generated |
| `artifact_count` | integer | Total artifacts |
| `reading_order` | string[] | Suggested artifact IDs for project comprehension |
| `artifacts` | object[] | Array of artifact metadata (frontmatter fields, no body) |
| `by_type` | object | Map of type -> artifact ID arrays |

### Global Registry (`artifacts-registry.json`) Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | integer | Schema version, `1` |
| `last_updated` | ISO string | When the registry was last updated |
| `total_artifacts` | integer | Total across all projects |
| `artifacts` | object[] | Flat list of artifact metadata with `project` field |
| `tag_index` | object | Map of tag -> artifact URI arrays |
| `type_index` | object | Map of type -> artifact URI arrays |

### Relation Types

| Relation | Meaning |
|----------|---------|
| `preceded-by` | This artifact follows from the referenced one |
| `followed-by` | The referenced artifact came after this one |
| `similar-pattern` | Same approach in a different context |
| `contradicts` | Opposite conclusion or approach |
| `builds-on` | Extends or improves the referenced artifact |
| `supersedes` | Replaces the referenced artifact |

---

# Cavern Map Schema (v1)

**Canonical schema for `cavern-map.json`.** The cavern map is the central state file for a dig. It is a tree rooted at the subject, where each node is a tunnel. The decision log records every routing choice made across all sessions.

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | yes | Schema version, `"1.0"` |
| `subject` | string | yes | The user's original subject string, unmodified |
| `subject_slug` | string | yes | URL-safe slug derived from subject, used for directory naming |
| `project` | string | yes | Project slug, matches directory name |
| `started_at` | ISO string | yes | Timestamp of the first dig cycle |
| `last_modified` | ISO string | yes | Timestamp of the most recent state write |
| `total_nuggets` | integer | yes | Running count of all nuggets across all tunnels |
| `total_veins` | integer | yes | Running count of all veins in `veins.json` |
| `root` | object | yes | The root tunnel node (see Tunnel Node Fields) |
| `tunnel_nodes` | object | yes | Map of tunnel ID to tunnel node object. All non-root nodes stored here for ID-based lookup |
| `decision_log` | object[] | yes | Ordered record of every routing decision (see Decision Log Entry Fields) |
| `expanded_terms` | string[] | no | Search terms generated during subject expansion |
| `session_count` | integer | no | Total sessions found in scope during subject expansion |
| `prior_outputs` | object | no | `{ survey: bool, domains: string[], artifacts: bool }` — prior archaeology outputs detected |

### Tunnel Node Fields

Each tunnel is a node in the tree. The root node represents the subject itself (`depth: 0`). Child tunnels are branches that spelunkers surfaced during a dig cycle.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique slug within this dig, e.g. `tunnel-oauth`, `tunnel-pkce-flow` |
| `label` | string | yes | Human-readable tunnel name, used in cavern map display |
| `status` | enum | yes | `unexplored` \| `active` \| `exhausted` \| `paused` |
| `depth` | integer | yes | Hops from root. Root node is `0`, direct children are `1`, etc. |
| `parent_id` | string\|null | yes | ID of the parent tunnel. `null` for the root node |
| `children` | string[] | yes | Array of child tunnel IDs discovered from this tunnel |
| `nugget_ids` | string[] | yes | Array of nugget filenames (e.g. `nug-001.md`) belonging to this branch |
| `sessions_searched` | string[] | yes | Absolute paths of session files already covered by spelunkers for this tunnel |
| `discovered_at` | ISO string | yes | When this tunnel was first surfaced (by recon or by a spelunker) |
| `last_dug` | ISO string\|null | yes | When spelunkers were last dispatched into this tunnel. `null` if unexplored |

### Status Vocabulary

- `unexplored` — not yet investigated
- `active` — spelunkers have been dispatched at least once
- `exhausted` — all sessions covered, 2+ consecutive cycles with 0 new nuggets
- `paused` — user explicitly paused this branch

No other status values are permitted. The concept "explored with nuggets" is derived: `status === 'active' && nugget_ids.length > 0`. The display layer uppercases for presentation only.

**Status transitions:**

```
unexplored → active       (spelunkers dispatched)
active     → exhausted    (all sessions covered, 2+ consecutive cycles with 0 new nuggets)
active     → paused       (user explicitly pauses this branch)
paused     → active       (user resumes)
```

### Decision Log Entry Fields

Every routing decision — including automated ones — is appended to the decision log. This is the mechanism that makes cold-session resumption coherent.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `turn` | integer | yes | Monotonically increasing turn number, starting at `1` |
| `timestamp` | ISO string | yes | When this decision was recorded |
| `user_said` | string | yes | The user's instruction verbatim, quoted. `"(automated)"` for recon-only turns |
| `action` | string | yes | Concise description of what the skill did this turn |
| `rationale` | string | yes | Why this action was taken (1–2 sentences) |
| `tunnels_explored` | string[] | yes | IDs of tunnels spelunkers entered this turn |
| `nuggets_found` | integer | yes | Count of new nuggets added this turn |

### Node Lookup Convention

The root node is at `cavern_map.root`. All other tunnel nodes are in `cavern_map.tunnel_nodes[id]`. Helper functions (`find_tunnel_by_id`, `flatten_tunnel_tree`) accept the full cavern map and resolve nodes from both locations.

### Example

```json
{
  "schema_version": "1.0",
  "subject": "OAuth token refresh strategy",
  "subject_slug": "oauth-token-refresh-strategy",
  "project": "workspace-mcp",
  "started_at": "2026-03-09T10:14:00Z",
  "last_modified": "2026-03-09T11:42:00Z",
  "total_nuggets": 7,
  "total_veins": 3,
  "expanded_terms": ["OAuth", "token", "refresh", "silent-refresh", "PKCE"],
  "session_count": 12,
  "prior_outputs": {
    "survey": true,
    "domains": ["auth"],
    "artifacts": false
  },
  "root": {
    "id": "root",
    "label": "OAuth token refresh strategy",
    "status": "active",
    "depth": 0,
    "parent_id": null,
    "children": ["tunnel-silent-refresh", "tunnel-pkce-flow"],
    "nugget_ids": ["nug-001.md", "nug-002.md"],
    "sessions_searched": [
      "~/.claude/projects/-Users-benpurslow-Developer-workspace-mcp/abc123.jsonl"
    ],
    "discovered_at": "2026-03-09T10:14:00Z",
    "last_dug": "2026-03-09T10:22:00Z"
  },
  "tunnel_nodes": {
    "tunnel-silent-refresh": {
      "id": "tunnel-silent-refresh",
      "label": "Silent refresh",
      "status": "active",
      "depth": 1,
      "parent_id": "root",
      "children": [],
      "nugget_ids": ["nug-003.md", "nug-004.md", "nug-005.md"],
      "sessions_searched": [
        "~/.claude/projects/-Users-benpurslow-Developer-workspace-mcp/def456.jsonl"
      ],
      "discovered_at": "2026-03-09T10:14:00Z",
      "last_dug": "2026-03-09T10:22:00Z"
    },
    "tunnel-pkce-flow": {
      "id": "tunnel-pkce-flow",
      "label": "PKCE flow",
      "status": "unexplored",
      "depth": 1,
      "parent_id": "root",
      "children": [],
      "nugget_ids": [],
      "sessions_searched": [],
      "discovered_at": "2026-03-09T10:14:00Z",
      "last_dug": null
    }
  },
  "decision_log": [
    {
      "turn": 1,
      "timestamp": "2026-03-09T10:14:00Z",
      "user_said": "(automated)",
      "action": "Ran reconnaissance, identified 3 tunnels from survey.md signals",
      "rationale": "No prior state found. Survey.md present — used as initial surface map.",
      "tunnels_explored": [],
      "nuggets_found": 0
    },
    {
      "turn": 2,
      "timestamp": "2026-03-09T10:22:00Z",
      "user_said": "dig into the silent refresh approach",
      "action": "Dispatched 2 spelunker agents into tunnel-silent-refresh across 4 sessions",
      "rationale": "User directed toward silent refresh. Strongest keyword signal in 4 sessions.",
      "tunnels_explored": ["tunnel-silent-refresh"],
      "nuggets_found": 5
    }
  ]
}
```

---

# Nugget Object Schema (v1)

**Canonical schema for nugget files.** Each nugget is a markdown file with YAML frontmatter stored in `spelunk/{subject-slug}/nuggets/`. Filename format: `nug-NNN.md` (zero-padded to 3 digits, e.g. `nug-007.md`).

A nugget is a single discrete finding — one fact about the subject, grounded in a specific conversation. It is not a summary. It is not a theme. It contains named entities (tool names, error messages, decisions, file paths, metric values) and explains why that fact matters.

### Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Nugget ID, format `nug-NNN`. Matches filename without extension |
| `subject` | string | yes | Subject slug. Must match the parent dig's `subject_slug` |
| `tunnel_id` | string | yes | ID of the tunnel that produced this nugget. Must exist in `cavern-map.json` |
| `session` | string | yes | Absolute path to the source session file |
| `session_date` | string | yes | Date of the source session, YYYY-MM-DD |
| `slab` | string | yes | Message range read when this nugget was found, format `"msg:{start}-{end}"` |
| `confidence` | enum | yes | `high` \| `medium` \| `low` |
| `weight` | integer | yes | Importance score 1–10 (1 = minor detail, 10 = pivotal finding) |
| `tags` | string[] | yes | 2–5 tags using `domain/specific` hierarchy (e.g., `mcp/caching`, `perf/latency`). Include parent tag when useful for clustering |
| `discovered_at` | ISO string | yes | When this nugget was written |

### Field Descriptions

#### slab
Message range read when this nugget was found. Format: `msg:{start}-{end}` where `{start}` and `{end}` are 1-based JSONL message indices (first message is 1). For whole-file slabs, use `all`.

#### tags
Tags use `domain/specific` format: `mcp/caching`, `perf/latency`, `auth/oauth`. Include the parent tag when useful for clustering (e.g., both `mcp` and `mcp/caching`).

### Confidence Heuristics

| Level | Criteria |
|-------|----------|
| `high` | Direct quote or specific named artefact in the source slab |
| `medium` | Inferred from context with at least one concrete reference |
| `low` | Synthesised from pattern across the slab, no single clear anchor |

### Body Structure

The nugget body is markdown, not frontmatter. Two required sections:

**`## What`** — The concrete finding. Must contain named entities: tool names, error messages, explicit decisions, file paths, metric values, or quoted text. Minimum 30 characters. This section answers: what specifically happened or was decided?

**`## Why`** — The reasoning about the finding. Must reference at least one specific noun from the `## What` section. Answers: why does this matter, what was the context or motivation, what were the consequences?

### Validation Rules

- `## What` section body must be >= 30 characters
- `## Why` section must reference at least one named entity from `## What`
- `confidence` must be one of `high | medium | low`
- `weight` must be an integer from 1 to 10 inclusive
- `tunnel_id` must exist as a node ID in `cavern-map.json`
- `session` must be a resolvable file path

### Example

```markdown
---
id: nug-004
subject: oauth-token-refresh-strategy
tunnel_id: tunnel-silent-refresh
session: /Users/benpurslow/.claude/projects/-Users-benpurslow-Developer-workspace-mcp/abc123.jsonl
session_date: 2026-02-14
slab: "msg:41-80"
confidence: high
weight: 8
tags: [oauth, auth/token-refresh, infra/valkey, infra/session-storage]
discovered_at: 2026-03-09T10:23:14Z
---

## What

The team decided to store refresh tokens in Valkey (not in-memory) after a Cloud Run instance restart silently invalidated all active sessions. The specific session file where this decision was made: `workspace-mcp/abc123.jsonl`, messages 55-60.

## Why

Storing refresh tokens in Valkey means restarts no longer log users out — session continuity became a hard requirement after the February 14 incident. This decision directly shaped the Valkey key schema (`rt:{user_id}:{device_id}`) adopted in the following week's implementation sprint.
```

---

# Vein Object Schema (v1)

**Canonical schema for `veins.json`.** Veins are connections between two nuggets, identified by a connector agent after a dig cycle completes. All veins for a subject are stored in a single array in `spelunk/{subject-slug}/veins.json`.

A vein is not a theme or a vague similarity. It must be anchored to a specific named element — the `bridge` — that appears in both nuggets. The bridge must be a proper noun (tool name, file path, config key, error message), not a theme. The connector agent is responsible for naming that element precisely.

### Vein Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Vein ID, format `vein-NNN` (zero-padded 3 digits) |
| `nugget_a` | string | yes | First nugget ID. Must exist in `nuggets/` |
| `nugget_b` | string | yes | Second nugget ID. Must exist in `nuggets/` |
| `link_type` | enum | yes | `evolution` \| `recurrence` \| `contradiction` \| `consequence` \| `reference` |
| `direction` | enum | yes | `a_before_b` \| `b_before_a` \| `contemporaneous` |
| `bridge` | string | yes | The specific named element appearing in both nuggets. Must be a concrete proper noun, not a vague theme |
| `narrative` | string | yes | One paragraph explaining the relationship, grounded in the bridge element |
| `confidence` | enum | yes | `high` \| `medium` \| `low` |
| `discovered_at` | ISO string | yes | When this vein was identified |

### Link Type Definitions

| Type | Definition |
|------|-----------|
| `evolution` | `nugget_b` postdates `nugget_a`, same concept with a detectable change in approach, scope, or outcome |
| `recurrence` | The same concept appears across sessions with no clear causal link — a pattern claim, not a causal one |
| `contradiction` | Two nuggets assert incompatible things about the same topic |
| `consequence` | `nugget_b` is plausibly caused by `nugget_a`. The connector must name the causal mechanism explicitly |
| `reference` | `nugget_b` explicitly builds on or refers to `nugget_a`'s subject matter |

### Validation Rules

- Both `nugget_a` and `nugget_b` must exist as files in `nuggets/`
- `bridge` must name a specific element (tool name, file path, decision, config key, error message) — not a vague theme like "authentication approach"
- `link_type` must be a valid enum value
- `direction` must be a valid enum value
- Maximum 3 veins per connector run (enforced at generation time, not validated against the schema)

### Example

```json
{
  "id": "vein-002",
  "nugget_a": "nug-002",
  "nugget_b": "nug-004",
  "link_type": "consequence",
  "direction": "a_before_b",
  "bridge": "Cloud Run instance restart",
  "narrative": "nug-002 documents the February 14 incident in which a Cloud Run instance restart invalidated all active sessions — exposing the in-memory token store as a single point of failure. nug-004 records the direct response: the team moved refresh token storage to Valkey, with the restart incident cited explicitly as the motivation. The bridge is the restart event itself: it appears in nug-002 as the cause and in nug-004 as the named reason for the architecture change.",
  "confidence": "high",
  "discovered_at": "2026-03-09T11:41:00Z"
}
```
