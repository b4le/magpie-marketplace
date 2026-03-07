# Adding New Archaeology Domains

Quick guide for adding a new domain to the archaeology skill. For the full schema spec, see [SCHEMA.md](../../SCHEMA.md). For detailed process guidance, see [ADDING-DOMAINS-COMPREHENSIVE.md](./ADDING-DOMAINS-COMPREHENSIVE.md).

## Domain Definition Structure

Each domain is defined in `references/domains/{domain}.md` with YAML frontmatter:

```yaml
---
domain: {domain-id}              # Must match filename (without .md)
status: active                   # active | planned | deprecated
maintainer: archaeology-skill    # Owner/team name
last_updated: 2026-03-04         # YYYY-MM-DD
version: 1.0.0                   # Semantic version

agent_count: 4                   # Parallel Explore agents (1-6)

keywords:
  primary:                       # Must appear for match
    - keyword1
    - keyword2
  secondary:                     # Boost relevance
    - related-term1
    - related-term2
  exclusion:                     # Filter false positives
    - noise-term

locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation history"
    priority: high
  - path: "~/{PROJECT_ROOT}/**/*.py"
    purpose: "Source files"
    priority: medium

outputs:
  - file: README.md
    required: true               # true = always create
    template: readme             # Anchor in output-templates.md
  - file: patterns.md
    required: false              # false = only if relevant content found
    template: patterns
---

# Domain-Specific Content

Body content below frontmatter is reference material for extraction agents.
```

## Required Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `domain` | string | Must match filename without `.md` |
| `status` | enum | `active`, `planned`, or `deprecated` |
| `maintainer` | string | Owner/team responsible for updates |
| `last_updated` | date | YYYY-MM-DD format |
| `version` | semver | e.g., `1.0.0` |
| `agent_count` | integer | 1-6, higher for larger search spaces |
| `keywords.primary` | [string] | Must appear in file for match |
| `keywords.secondary` | [string] | Boost relevance scoring |
| `keywords.exclusion` | [string] | Filter false positives |
| `locations` | array | Objects with `path`, `purpose`, `priority` |
| `outputs` | array | Objects with `file`, `required`, `template` |

## Step-by-Step

### 1. Choose Domain Scope

- **Good**: "Prompting Patterns" (focused, unique keywords)
- **Bad**: "Everything about AI" (too broad, noisy keywords)

**Tip:** Run `/archaeology` (survey mode) first to see if your proposed domain has signal in the project. Survey auto-detects high-frequency tools/patterns not covered by existing domains and suggests them as "deep dive" candidates.

### 2. Define Keywords

Split into three tiers:
- **Primary** (5-10): Terms that definitively identify domain content
- **Secondary** (10-20): Related terms that boost relevance
- **Exclusion** (2-5): Terms that filter false positives

### 3. Specify Search Locations

Use path objects with placeholders:
- `{PROJECT_ROOT}` — resolved project root directory
- `{PROJECT_PATH_PATTERN}` — glob pattern for project path matching

Each location needs `path`, `purpose`, and `priority` (high/medium/low).

### 4. Design Outputs

Each output references an anchor in `output-templates.md`:
- `readme` — Summary index of findings
- `patterns` — Reusable patterns document
- `prompts` — Prompt templates and examples

Set `required: true` for files that should always be created, `false` for conditional outputs.

### 5. Create the File

```bash
# Copy an existing domain as a starting point (has correct YAML frontmatter format)
cp git-workflows.md {domain}.md
# Replace frontmatter values and body content
```

> **Note:** `DOMAIN-TEMPLATE.md` is a reference for what sections to document, not a copy-paste template. Always start from an existing domain file to get the correct YAML frontmatter structure.

### 6. Register in registry.yaml

```yaml
- id: {domain}
  name: Human Readable Name
  file: {domain}.md
  version: "1.0.0"
  status: active
  description: Brief description of what this domain covers
  pattern_types:
    - "Category 1"
    - "Category 2"
  keywords:
    - key1
    - key2
```

### 7. Follow Agent Output Convention

If your domain customises agent prompts (e.g. adding structured output fields), use XML tags — not `KEY: value` format. See the **Agent Output Format Convention** section in [`conversation-parser.md`](../conversation-parser.md#agent-output-format-convention) for format rules and the `extract_xml_field()` helper.

### 8. Test

```bash
/archaeology {domain} "TestProject"
```

Verify: agents find relevant content, outputs are useful, no false positives from broad keywords.

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| No results | Keywords too specific | Broaden primary keywords |
| Too many irrelevant results | Keywords too broad | Add exclusion terms, narrow locations |
| Output is disorganized | Missing focus in body content | Add extraction guidance in domain body |

## Domain Lifecycle

1. **Planned** — Registered in registry, not yet implemented
2. **Active** — Fully functional, tested
3. **Deprecated** — Replaced by newer domain, kept for reference

## Discovering New Domains

Use survey mode (`/archaeology` with no arguments) to discover potential new domains. Survey scans conversation history for high-frequency tools and patterns not covered by existing domains, and lists them under "Suggested Deep Dives" in the output. If a suggested theme appears consistently across projects, it's a strong candidate for a new domain.
