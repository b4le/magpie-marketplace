# Progressive Disclosure for Archaeology Outputs

**Date:** 2026-03-04
**Status:** Design approved
**Goal:** Optimise archaeology work-log outputs for AI agent consumption via a 3-tier progressive disclosure reading path.

## Problem

Archaeology outputs have no reading-order signals. An agent landing in the work-log must read everything to find anything. Specifically:

- No explicit entry point or "start here" signal
- patterns.md is monolithic — no way to skim
- findings.json is flat — no ranking or highlights
- No cross-domain view connecting multiple domain runs for the same project
- No documented consumption contract

## Design: Summary Pyramid

Three-tier reading path with explicit routing:

```
Tier 1: INDEX.md           → route to project (always read first)
Tier 2: SUMMARY.md         → cross-domain highlights + connections (per-project)
Tier 3: patterns.md / findings.json → domain detail (per-domain)
```

### 1. Enriched findings.json (Step 5a change)

Each finding gains ordinal scoring:

```json
{
  "id": "f-001",
  "type": "pattern",
  "title": "...",
  "description": "...",
  "evidence": [...],
  "tags": [...],
  "date": "2026-03-04",
  "confidence": "high",
  "relevance": "high"
}
```

| Field | Values | Meaning |
|-------|--------|---------|
| `confidence` | `high` / `medium` / `low` | How certain the finding is real (not a false positive) |
| `relevance` | `high` / `medium` / `low` | How useful the finding is for future work |

**Scoring heuristics:**
- **Confidence:** `high` = 2+ evidence items + code block, `medium` = 1 evidence item or context-only, `low` = inferred with weak evidence
- **Relevance:** `high` = reusable pattern or decision with broad applicability, `medium` = useful in specific contexts, `low` = one-off capability or narrow technique

**New top-level field:**

```json
{
  "project": "...",
  "domain": "...",
  "extracted_at": "...",
  "highlights": ["f-003", "f-001", "f-012"],
  "findings": [...]
}
```

`highlights` — ordered array of finding IDs where `confidence == "high" AND relevance == "high"`, sorted by type priority (pattern > decision > artifact > capability), capped at 5.

### 2. Restructured patterns.md (Step 5b change)

Highlights-first structure:

```markdown
# {Domain} Patterns — {Project}

> Extracted {N} findings on {date} | {H} highlights

## Highlights
[Top 3-5 findings from highlights array. Brief: title, type, 1-2 sentence description.]

## All Findings
### {Finding Title}
**Type:** {type} | **Confidence:** {confidence} | **Relevance:** {relevance}

{description}

**Evidence:**
- {evidence items}

## Cross-Cutting Themes
[Patterns spanning multiple findings]

## Open Questions
[Gaps needing deeper investigation]
```

Agent can stop after "Highlights" for quick orientation.

### 3. New SUMMARY.md (Step 6 — new step)

Generated at `{project-slug}/SUMMARY.md`. Cross-domain synthesis.

```markdown
# {Project} — Archaeology Summary

> {N} domains | {total findings} findings | Last updated: {date}

## Reading Path
1. You are here — project overview and cross-domain highlights
2. Drill into a domain — `{domain}/patterns.md` for domain-specific detail
3. Raw data — `{domain}/findings.json` for programmatic access

## Cross-Domain Highlights
[Top 5-7 findings across ALL domains, pulled from each domain's highlights
array, re-sorted by type priority. Each entry includes domain label.]

- **[orchestration]** {title} — {one-liner} (confidence: high, relevance: high)
- **[python-practices]** {title} — {one-liner} (confidence: high, relevance: high)

## Domain Summaries
### {domain}
{First paragraph of that domain's patterns.md Overview section}
Findings: {count} | Highlights: {highlight_count} | [Detail →]({domain}/patterns.md)

## Connections
[Structured tag-overlap table — mechanical, not narrative]

| Tag | Domains | Finding Count |
|-----|---------|---------------|
| async | orchestration, python-practices | 7 |
| error-handling | python-practices, git-workflows | 4 |
```

### 4. Upgraded INDEX.md (Step 5c change)

```markdown
# Archaeology Work-Log Index

> How to use: Read this file first. Find your project below.
> Follow the reading path for the detail level you need.

## Reading Path
- **Quick scan:** Project table below — one-liner summaries
- **Project deep-dive:** Read `{project-slug}/SUMMARY.md`
- **Domain detail:** Read `{project-slug}/{domain}/patterns.md`
- **Programmatic access:** Parse `{project-slug}/{domain}/findings.json`

## Projects

### {Project Name}
{One-liner from SUMMARY.md}

| Domain | Findings | Highlights | Last Run | Path |
|--------|----------|------------|----------|------|
| orchestration | 12 | 3 | 2026-03-04 | `project/orchestration/` |

---
Last updated: {date}
```

### 5. Consumption Spec (new static reference)

`references/consumption-spec.md` — documents the reading path contract.

| Level | File | When to use | Stop here if... |
|-------|------|-------------|-----------------|
| 1. Route | INDEX.md | Always | You just need to know what domains exist |
| 2. Orient | {project}/SUMMARY.md | Resuming work on a project | Cross-domain highlights answer your question |
| 3. Understand | {project}/{domain}/patterns.md | Need domain-specific detail | Highlights section is enough |
| 4. Act | {project}/{domain}/findings.json | Building on findings programmatically | — |

For AI agents: Read(INDEX.md) → Read(SUMMARY.md) → Read(patterns.md) Highlights → findings.json only if needed.

For skills: Parse findings.json directly. Filter on highlights array or `confidence == "high"`.

Backward compatibility: v1 findings (without scores) treated as unscored — missing fields don't cause failures.

### 6. Step 6 Parallelisation Strategy

Step 6 reads from disk, not from the current run's memory. This makes it idempotent.

```
1. Scan:  Glob all metadata.json + findings.json for PROJECT_SLUG
2. Rank:  Extract highlights arrays, merge cross-domain, sort by type priority
3. Write: SUMMARY.md (overwrite — idempotent)
4. Update: INDEX.md project one-liner from SUMMARY.md
```

**Concurrency safety:** Two concurrent runs both scan disk → both derive SUMMARY.md from the same state (plus their own domain). Last writer wins. Content is equivalent. No locking needed. Self-healing on next run.

## Deliverables

1. `references/consumption-spec.md` — agent reading path spec
2. Updated `SCHEMA.md` — new finding fields (confidence, relevance)
3. Updated `SKILL.md` — modified Step 5a/5b/5c + new Step 6
4. Updated INDEX.md template — routing entry point

## Constraints

- SKILL.md stays under 3,000 words (current: 1,668, budget: ~1,300 for changes)
- `--no-export` flag skips Steps 5 and 6 entirely
- Central work-log structure `{project-slug}/{domain}/` unchanged
- SUMMARY.md lives at `{project-slug}/SUMMARY.md` (project level, not domain level)
