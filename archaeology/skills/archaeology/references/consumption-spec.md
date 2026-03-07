# Archaeology Consumption Spec v1.0

How to read and act on archaeology work-log outputs. This contract is for AI agents resuming work, skills cross-referencing findings, and humans scanning manually.

## Entry Point

Always start here:

```
~/.claude/data/visibility-toolkit/work-log/archaeology/INDEX.md
```

## Reading Levels

| Level | File | When to use | Stop here if... |
|-------|------|-------------|-----------------|
| 1. Route | `INDEX.md` | Always — first read | You just need to know what domains exist for a project |
| 2. Orient | `{project}/SUMMARY.md` | Resuming work on a project | Cross-domain highlights answer your question |
| 3. Understand | `{project}/{domain}/patterns.md` | Need domain-specific detail | The Highlights section gives you enough |
| 3.5 Narrate | `{project}/artifacts/` + `exhibition.md` | Need to explain what was built to someone else | The exhibition gives you enough to write from |
| 4. Act | `{project}/{domain}/findings.json` | Building on findings programmatically | — |
| 5. Adapt | `{project}/workstyle.md` | Adapting to user's working style | The summary characterisation answers your question |
| 6. Automate | `{project}/workstyle.json` | Building on workstyle programmatically | — |

## For AI Agents Resuming Work

```
1. Read(INDEX.md)                         → find your project, read one-liner summary
2. Read({project}/SUMMARY.md)             → cross-domain highlights + tag connections
3. Read({project}/{domain}/patterns.md)   → start with ## Highlights, skip All Findings unless needed
3.5 Read({project}/exhibition.md)          → conserved narrative artifacts, grouped by type
    Read({project}/artifacts/{id}.md)       → only if you need the full story of a specific artifact
4. Parse({project}/{domain}/findings.json) → only if you need structured data
5. Read({project}/workstyle.md)             → only if you need to understand the user's working style
6. Parse({project}/workstyle.json)           → only if adapting behaviour to user preferences
```

Stop at any level once you have what you need.

## For Skills Cross-Referencing Findings

Parse `findings.json` directly. Useful filters:
- `highlights` array → top findings (confidence: high AND relevance: high)
- Filter by `confidence == "high"` for high-certainty findings
- Filter by `relevance == "high"` for actionable findings
- Join across domains via shared `tags` values

## findings.json Schema

See `SCHEMA.md` (Finding Object Schema section) for the canonical schema definition.

Key fields for consumers:
- `highlights` (string[]) — ordered array of top finding IDs for quick access
- `findings[].confidence` / `findings[].relevance` — ordinal scoring (`high` | `medium` | `low`)
- Filter by `confidence == "high"` for high-certainty findings
- Filter by `relevance == "high"` for actionable findings
- Join across domains via shared `tags` values

## For Skills Adapting to User Workstyle

Parse `workstyle.json` directly. Useful fields:
- `summary` → quick characterisation
- `session_patterns.dominant_pattern` → how the user typically starts sessions
- `communication.instruction_style` → how detailed to be in responses
- `delegation.solo_pct` vs `team_pct` → whether to suggest agent teams
- `preferences.detected` → patterns not yet in CLAUDE.md (suggest adding)

## For Skills Consuming Narrative Artifacts

Read `exhibition.md` for a project overview. Parse `artifacts/_index.json` for programmatic access. Useful fields:
- `by_type` → filter artifacts by narrative shape (shipment, decision, incident, discovery, tale, practice)
- `artifacts[].significance` → editorial weight (1-10) for curation
- `artifacts[].confidence` → evidence quality
- `artifacts[].tags` → cross-reference with findings tags

For cross-project discovery, parse `artifacts-registry.json` at the central work-log root:
- `tag_index` → find artifacts by topic across all projects
- `type_index` → find all artifacts of a specific narrative type

## Backward Compatibility

v1 findings (before progressive disclosure) lack `confidence`, `relevance`, and `highlights` fields. Consumers should treat missing fields as unscored — do not fail on their absence.

## Schema Versions

| Version | Changes |
|---------|---------|
| v1 | Original: flat findings array, no scoring |
| v2 | Adds confidence, relevance (ordinal), highlights array, restructured patterns.md |
| workstyle v1 | Initial: dimension scores, session patterns, tool usage, delegation, communication, preferences, evolution |
| artifact v1 | Initial: 6 narrative types, per-project index, global registry, exhibition manifest |
