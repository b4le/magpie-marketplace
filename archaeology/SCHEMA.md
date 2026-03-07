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
