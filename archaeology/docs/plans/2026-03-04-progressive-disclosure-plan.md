# Progressive Disclosure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a 3-tier progressive disclosure reading path to archaeology work-log outputs, optimised for AI agent consumption.

**Architecture:** Enrich findings.json with ordinal scoring + highlights array, restructure patterns.md to lead with highlights, add per-project SUMMARY.md via new Step 6 for cross-domain synthesis, upgrade INDEX.md as routing entry point, and document the consumption contract in a new spec file.

**Tech Stack:** Markdown (skill definitions), YAML (schema), JSON (findings schema)

**Design doc:** `docs/plans/2026-03-04-progressive-disclosure-design.md`

---

### Task 1: Create consumption-spec.md (static reference)

**Files:**
- Create: `~/.claude/skills/archaeology/references/consumption-spec.md`

This is the static contract document. No dependencies on other changes — create first as the north star.

**Step 1: Write the consumption spec**

```markdown
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
| 4. Act | `{project}/{domain}/findings.json` | Building on findings programmatically | — |

## For AI Agents Resuming Work

```
1. Read(INDEX.md)                         → find your project, read one-liner summary
2. Read({project}/SUMMARY.md)             → cross-domain highlights + tag connections
3. Read({project}/{domain}/patterns.md)   → start with ## Highlights, skip All Findings unless needed
4. Parse({project}/{domain}/findings.json) → only if you need structured data
```

Stop at any level once you have what you need.

## For Skills Cross-Referencing Findings

Parse `findings.json` directly. Useful filters:
- `highlights` array → top findings (confidence: high AND relevance: high)
- Filter by `confidence == "high"` for high-certainty findings
- Filter by `relevance == "high"` for actionable findings
- Join across domains via shared `tags` values

## findings.json Schema (v2)

Top-level fields:
- `project` (string) — project name
- `domain` (string) — domain ID
- `extracted_at` (ISO 8601) — extraction timestamp
- `source_session` (string) — git branch or session ID
- `highlights` (string[]) — ordered array of finding IDs, capped at 5
- `findings` (object[]) — array of finding objects

Finding object fields:
- `id` (string) — format: `f-001`, `f-002`, etc.
- `type` (enum) — `pattern` | `decision` | `artifact` | `capability`
- `title` (string)
- `description` (string)
- `evidence` (string[])
- `tags` (string[])
- `date` (string) — YYYY-MM-DD
- `confidence` (enum) — `high` | `medium` | `low`
- `relevance` (enum) — `high` | `medium` | `low`

## Backward Compatibility

v1 findings (before progressive disclosure) lack `confidence`, `relevance`, and `highlights` fields. Consumers should treat missing fields as unscored — do not fail on their absence.

## Schema Versions

| Version | Changes |
|---------|---------|
| v1 | Original: flat findings array, no scoring |
| v2 | Adds confidence, relevance (ordinal), highlights array, restructured patterns.md |
```

Write to: `~/.claude/skills/archaeology/references/consumption-spec.md`

**Step 2: Verify the file exists and reads correctly**

Run: `wc -l ~/.claude/skills/archaeology/references/consumption-spec.md`
Expected: ~60-70 lines

---

### Task 2: Update SCHEMA.md with new finding fields

**Files:**
- Modify: `~/.claude/skills/archaeology/SCHEMA.md` (lines 1-103)

Add `confidence` and `relevance` to the finding object documentation, and document the `highlights` top-level field.

**Step 1: Add new fields to SCHEMA.md**

After the existing `outputs` field documentation (after line 98), add a new section:

```markdown
## Finding Object Schema (v2)

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
```

**Step 2: Verify SCHEMA.md is well-formed**

Run: `head -5 ~/.claude/skills/archaeology/SCHEMA.md && echo "..." && tail -5 ~/.claude/skills/archaeology/SCHEMA.md`
Expected: Title line at top, backward compat note at bottom.

---

### Task 3: Update SKILL.md Step 5a — add scoring + highlights

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (lines 293-328)

Replace the findings mapping in Step 5a to include confidence, relevance, and highlights computation.

**Step 1: Replace the findings_data block (lines 297-314)**

Replace the existing `findings_data = { ... }` block with:

```javascript
// Analyze all_findings and create structured entries
// Each finding gets a unique ID, type classification, scoring, and evidence
findings_data = {
  project: PROJECT_NAME,
  domain: domain,
  extracted_at: new Date().toISOString(),
  source_session: git_branch() || session_id(),
  highlights: [],  // populated below
  findings: all_findings_parsed.map((finding, i) => ({
    id: `f-${String(i + 1).padStart(3, '0')}`,
    type: classify_finding(finding),  // "pattern" | "decision" | "artifact" | "capability"
    title: finding.title,
    description: finding.description,
    evidence: finding.evidence_paths || finding.quotes,
    tags: extract_tags(finding, domain),
    date: finding.date || current_date(),
    confidence: score_confidence(finding),  // "high" | "medium" | "low"
    relevance: score_relevance(finding)     // "high" | "medium" | "low"
  }))
};

// Build highlights: high confidence + high relevance, sorted by type priority, capped at 5
TYPE_PRIORITY = { pattern: 0, decision: 1, artifact: 2, capability: 3 };
findings_data.highlights = findings_data.findings
  .filter(f => f.confidence === 'high' && f.relevance === 'high')
  .sort((a, b) => TYPE_PRIORITY[a.type] - TYPE_PRIORITY[b.type])
  .slice(0, 5)
  .map(f => f.id);
```

**Step 2: Add scoring function docs after the finding type classification table (after line 328)**

Add:

```markdown
**`score_confidence(finding)` heuristics:**
- `"high"` — 2+ evidence items AND code block present
- `"medium"` — 1 evidence item OR context-only (no code)
- `"low"` — inferred with weak or no direct evidence

**`score_relevance(finding)` heuristics:**
- `"high"` — type is `pattern` or `decision` with broad applicability
- `"medium"` — useful in specific contexts, or `artifact` type
- `"low"` — one-off `capability` or narrow technique
```

**Step 3: Check word count is still under budget**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: under 2000 words (started at 1668, added ~80 words net)

---

### Task 4: Update SKILL.md Step 5b — restructure patterns.md template

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (lines 348-376)

Replace the patterns.md template with highlights-first structure.

**Step 1: Replace the patterns.md structure block (lines 348-376)**

Replace:

````markdown
**`patterns.md` structure:**
```markdown
# {Domain} Patterns — {Project}

> Extracted {N} findings on {date}

## Overview
[2-3 sentence summary of what was found]

## Key Patterns
### {Finding Title}
**Type:** {finding.type} | **Tags:** {finding.tags}

{finding.description}

**Evidence:**
- {evidence items}

[Repeat for each finding]

## Cross-Cutting Themes
[Patterns that span multiple findings]

## Open Questions
[Gaps or areas needing deeper investigation]

---
*Generated by archaeology skill — domain: {domain}*
```
````

With:

````markdown
**`patterns.md` structure:**
```markdown
# {Domain} Patterns — {Project}

> Extracted {N} findings on {date} | {H} highlights

## Highlights
[Top 3-5 findings from highlights array. For each: title, type, 1-2 sentence description. No full evidence — this is the skim layer.]

## All Findings
### {Finding Title}
**Type:** {type} | **Confidence:** {confidence} | **Relevance:** {relevance}

{description}

**Evidence:**
- {evidence items}

[Repeat for all findings, ordered by relevance: high → medium → low]

## Cross-Cutting Themes
[Patterns that span multiple findings]

## Open Questions
[Gaps or areas needing deeper investigation]

---
*Generated by archaeology skill — domain: {domain}*
```
````

**Step 2: Verify the template reads correctly**

Run: `grep -c "Highlights" ~/.claude/skills/archaeology/SKILL.md`
Expected: at least 1 match

---

### Task 5: Update SKILL.md Step 5c — upgrade INDEX.md template

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (lines 401-441)

Replace the INDEX.md generation with routing-aware template.

**Step 1: Replace the update_central_index function (lines 404-439)**

Replace the `index_content` template string with:

```javascript
function update_central_index() {
  INDEX_PATH = `${CENTRAL_BASE}/INDEX.md`;

  // Scan all project/domain directories
  all_metadata = Glob(pattern: `${CENTRAL_BASE}/**/metadata.json`)
    .map(f => JSON.parse(Read(f)));

  // Group by project
  by_project = group_by(all_metadata, 'project');

  // Read SUMMARY.md one-liners where they exist
  project_summaries = {};
  for (project_slug of Object.keys(by_project)) {
    summary_path = `${CENTRAL_BASE}/${by_project[project_slug][0].project_slug}/SUMMARY.md`;
    if (exists(summary_path)) {
      summary_content = Read(summary_path);
      // Extract first blockquote line as one-liner
      project_summaries[project_slug] = extract_first_blockquote(summary_content);
    }
  }

  // Read findings.json to get highlight counts
  function get_highlight_count(meta) {
    findings_path = `${CENTRAL_BASE}/${meta.project_slug}/${meta.domain}/findings.json`;
    if (exists(findings_path)) {
      data = JSON.parse(Read(findings_path));
      return (data.highlights || []).length;
    }
    return 0;
  }

  // Generate index
  index_content = `# Archaeology Work-Log Index

> How to use: Read this file first. Find your project below.
> Follow the reading path for the detail level you need.

## Reading Path
- **Quick scan:** Project table below — one-liner summaries
- **Project deep-dive:** Read \`{project-slug}/SUMMARY.md\`
- **Domain detail:** Read \`{project-slug}/{domain}/patterns.md\`
- **Programmatic access:** Parse \`{project-slug}/{domain}/findings.json\`
- **Full spec:** See \`references/consumption-spec.md\`

## Projects

${Object.entries(by_project).map(([project, runs]) => `
### ${project}
${project_summaries[project] || '_No cross-domain summary yet — run more domains to generate._'}

| Domain | Findings | Highlights | Last Run | Path |
|--------|----------|------------|----------|------|
${runs.map(r => `| ${r.domain} | ${r.findings_count} | ${get_highlight_count(r)} | ${r.timestamp.split('T')[0]} | \`${r.project_slug}/${r.domain}/\` |`).join('\n')}
`).join('\n')}

---

Last updated: ${current_date()}
`;

  Write(INDEX_PATH, index_content);
  console.log(`Updated central index: ${INDEX_PATH}`);
}

update_central_index();
```

**Step 2: Check word count**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: under 2200 words

---

### Task 6: Add Step 6 to SKILL.md — Project Synthesis

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (insert after Step 5c, before "If No Results Found")

This is the new step. Insert between the `update_central_index()` call (line 441) and the "### If No Results Found" section (line 444).

**Step 1: Insert Step 6 block**

Insert after line 441 (`update_central_index();`):

```markdown

### Step 6: Project Synthesis

**Skip this step if `--no-export` flag was provided.**

Generate a cross-domain summary for the project. Reads from disk (idempotent — safe under concurrent runs).

```javascript
if (NO_EXPORT) return;  // already skipped in Step 5

// 1. Scan: find all domains exported for this project
domain_metadata = Glob(pattern: `${CENTRAL_BASE}/${PROJECT_SLUG}/*/metadata.json`)
  .map(f => JSON.parse(Read(f)));
domain_findings = Glob(pattern: `${CENTRAL_BASE}/${PROJECT_SLUG}/*/findings.json`)
  .map(f => JSON.parse(Read(f)));

if (domain_metadata.length === 0) return;  // nothing to synthesize

// 2. Merge highlights across domains, sort by type priority
TYPE_PRIORITY = { pattern: 0, decision: 1, artifact: 2, capability: 3 };
all_highlights = [];
for (df of domain_findings) {
  highlight_findings = df.findings.filter(f => (df.highlights || []).includes(f.id));
  all_highlights.push(...highlight_findings.map(f => ({ ...f, domain: df.domain })));
}
cross_highlights = all_highlights
  .sort((a, b) => TYPE_PRIORITY[a.type] - TYPE_PRIORITY[b.type])
  .slice(0, 7);

// 3. Build tag overlap table
tag_map = {};  // tag → { domains: Set, count: number }
for (df of domain_findings) {
  for (finding of df.findings) {
    for (tag of finding.tags) {
      if (!tag_map[tag]) tag_map[tag] = { domains: new Set(), count: 0 };
      tag_map[tag].domains.add(df.domain);
      tag_map[tag].count++;
    }
  }
}
// Keep only tags appearing in 2+ domains
cross_tags = Object.entries(tag_map)
  .filter(([_, v]) => v.domains.size >= 2)
  .sort((a, b) => b[1].count - a[1].count);

// 4. Read first paragraph of each domain's patterns.md for summaries
domain_summaries = {};
for (meta of domain_metadata) {
  patterns_path = `${CENTRAL_BASE}/${PROJECT_SLUG}/${meta.domain}/patterns.md`;
  if (exists(patterns_path)) {
    content = Read(patterns_path);
    // Extract text between "## Highlights" and next "##"
    domain_summaries[meta.domain] = extract_first_section(content, 'Highlights');
  }
}

// 5. Total counts
total_findings = domain_findings.reduce((sum, df) => sum + df.findings.length, 0);

// 6. Write SUMMARY.md
summary_content = `# ${PROJECT_NAME} — Archaeology Summary

> ${domain_metadata.length} domains | ${total_findings} findings | Last updated: ${current_date()}

## Reading Path
1. **You are here** — project overview and cross-domain highlights
2. **Drill into a domain** — \`{domain}/patterns.md\` for domain-specific detail
3. **Raw data** — \`{domain}/findings.json\` for programmatic access

## Cross-Domain Highlights
${cross_highlights.map(f =>
  `- **[${f.domain}]** ${f.title} — ${f.description.split('.')[0]}. (${f.confidence}/${f.relevance})`
).join('\n')}

## Domain Summaries
${domain_metadata.map(meta => `
### ${meta.domain}
${domain_summaries[meta.domain] || '_No summary available_'}
Findings: ${meta.findings_count} | [Detail →](${meta.domain}/patterns.md)
`).join('\n')}

## Connections
${cross_tags.length > 0 ? `
| Tag | Domains | Finding Count |
|-----|---------|---------------|
${cross_tags.map(([tag, v]) =>
  `| ${tag} | ${[...v.domains].join(', ')} | ${v.count} |`
).join('\n')}
` : '_Not enough cross-domain data yet. Run more domains to see connections._'}

---
*Generated by archaeology skill — project synthesis*
`;

Write(`${CENTRAL_BASE}/${PROJECT_SLUG}/SUMMARY.md`, summary_content);
console.log(`Project summary: ${CENTRAL_BASE}/${PROJECT_SLUG}/SUMMARY.md`);

// 7. Re-run index update to pick up SUMMARY.md one-liner
update_central_index();
```

**Step 2: Check word count is under budget**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: under 2800 words (budget is 3000)

---

### Task 7: Update Completion Criteria and Output Display

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (lines 456-496)

**Step 1: Update completion checklist (lines 458-466)**

Add new items:

```markdown
Archaeology run is complete when:
- [ ] Domain definition loaded and validated
- [ ] All search agents completed
- [ ] Findings synthesized with confidence/relevance scoring
- [ ] Output files written to `.claude/archaeology/{domain}/`
- [ ] Local INDEX.md updated with domain listing
- [ ] **(Unless --no-export)** Structured findings exported with highlights array
- [ ] **(Unless --no-export)** Central INDEX.md updated with reading path
- [ ] **(Unless --no-export)** Project SUMMARY.md generated/updated (Step 6)
- [ ] Summary provided with file locations
```

**Step 2: Update output display format (lines 468-484)**

Replace with:

```bash
Archaeology Complete

Local outputs in .claude/archaeology/${domain}/
  - README.md
  - patterns.md
  - [other files...]

Exported to ~/.claude/data/visibility-toolkit/work-log/archaeology/${PROJECT_SLUG}/${domain}/
  - findings.json (${N} findings, ${H} highlights)
  - patterns.md (highlights-first)
  - metadata.json

Project summary: ~/.claude/data/visibility-toolkit/work-log/archaeology/${PROJECT_SLUG}/SUMMARY.md
Central index: ~/.claude/data/visibility-toolkit/work-log/archaeology/INDEX.md
```

**Step 3: Final word count check**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: under 3000 words

---

### Task 8: Verify all files are consistent

**Files:**
- Read: All modified files for cross-reference check

**Step 1: Verify consumption-spec.md references match SKILL.md output**

Read both files. Confirm:
- Schema fields in consumption-spec.md match the findings_data structure in Step 5a
- Reading path levels match the actual files generated (INDEX.md, SUMMARY.md, patterns.md, findings.json)
- Highlight selection criteria match (confidence=high AND relevance=high, capped at 5)

**Step 2: Verify SCHEMA.md fields match Step 5a output**

Read both files. Confirm:
- confidence/relevance enums match (`high` | `medium` | `low`)
- Finding object fields in SCHEMA.md match the `.map()` in Step 5a
- highlights description matches the filter/sort/slice logic

**Step 3: Verify INDEX.md template references SUMMARY.md correctly**

Confirm Step 5c reads SUMMARY.md for one-liner, and Step 6 calls `update_central_index()` after writing SUMMARY.md.

**Step 4: Final word count**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: under 3000 words. If over, extract Step 6 synthesis logic into `references/export-spec.md` and reference from SKILL.md.
