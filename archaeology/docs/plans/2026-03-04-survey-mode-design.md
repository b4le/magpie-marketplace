# Survey Mode Design — Archaeology Skill

> Approved 2026-03-04. Survey is the default entry point when `/archaeology` is called with no arguments.

## Summary

Survey performs a high-level scan of the current project and produces a consistent, machine-readable `survey.md` with domain signal scores and deep dive suggestions. It does NOT extract full findings — it samples broadly and scores signal strength per domain.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scan scope | Both conversation JSONL + source files | Conversations for domain signal, source files for project profile |
| Signal scoring | Weighted hit count: `(primary×3 + secondary×1) × diversity` | Deterministic, comparable across projects |
| New domain detection | Tool/import frequency → targeted LLM sampling | Concrete evidence for unknowns, LLM only where needed |
| Execution model | Single sequential scan (with size-gate fallback to sub-agent batches) | Fast, context-safe. Batches only when project is large |
| Architecture | Inline in SKILL.md as a branch at the top | Single source of truth, survey isn't a domain |
| Output location | `survey.md` alongside domain directories (local + central) | Not inside a domain dir since survey isn't a domain |

## Entry Point & Routing

When `/archaeology` is called with no args or explicitly `/archaeology survey`:

```javascript
args = parse_arguments(user_input);

if (args.command === 'list') {
  list_domains();
  return;
}

if (args.command === undefined || args.command === 'survey') {
  execute_survey(args);
  return;
}

// Existing domain extraction
execute_domain_extraction(args);
```

Survey shares Step 1's project resolution (PROJECT_ROOT, PROJECT_NAME, PROJECT_SLUG) but skips Step 2 (domain loading). Instead it loads the full registry to enumerate all domains.

## Scan Pipeline

### Phase 0: Size Check

```javascript
conversation_files = Glob(`${HISTORY_DIR}/**/*.jsonl`);
source_files = Glob(`${PROJECT_ROOT}/**/*`);  // exclude .git, node_modules

LARGE_PROJECT = conversation_files.length > 50 || source_files.length > 500;

if (LARGE_PROJECT) {
  // Batch into sub-agents, each handles a file slice, returns counts only
  execute_batched_survey();
} else {
  execute_sequential_survey();
}
```

The threshold (50 JSONL / 500 source) protects the main agent's context window. Sub-agents return numeric counts only, not file contents.

### Phase 1: Domain Keyword Scoring

For each domain in registry.yaml:

```javascript
for (domain of all_domains) {
  domain_def = Read(`references/domains/${domain.file}`);
  keywords = parse_frontmatter(domain_def).keywords;

  primary_score = 0;
  secondary_score = 0;
  session_set = new Set();

  for (keyword of keywords.primary) {
    results = Grep(pattern: keyword, path: HISTORY_DIR, glob: "*.jsonl", output_mode: "count");
    primary_score += results.total_count;
    session_set.add(...results.files);
  }

  for (keyword of keywords.secondary) {
    results = Grep(pattern: keyword, path: HISTORY_DIR, glob: "*.jsonl", output_mode: "count");
    secondary_score += results.total_count;
  }

  raw_score = (primary_score * 3) + (secondary_score * 1);
  diversity = Math.min(1.5, 1.0 + (session_set.size * 0.1));
  final_score = raw_score * diversity;

  signal = final_score >= 20 ? 'strong'
         : final_score >= 8  ? 'moderate'
         : final_score >= 2  ? 'weak'
         : 'none';

  confidence = session_set.size >= 3 ? 'high'
             : session_set.size >= 2 ? 'medium'
             : session_set.size >= 1 ? 'low'
             : '-';

  domain.score = { signal, confidence, raw: final_score, sessions: session_set.size };
}
```

### Signal Scale (contract)

| Signal | Threshold | Meaning |
|--------|-----------|---------|
| strong | score >= 20 | High-value domain, run extraction first |
| moderate | score >= 8 | Worth investigating, likely has findings |
| weak | score >= 2 | Minimal signal, may yield 1-2 findings |
| none | score < 2 | No evidence found |

### Confidence Scale (contract)

| Confidence | Criterion | Meaning |
|------------|-----------|---------|
| high | 3+ distinct sessions | Broad pattern across usage |
| medium | 2 sessions | Some evidence but limited |
| low | 1 session | Single occurrence, may be one-off |
| - | 0 sessions | No signal |

### Phase 2: Project Profiling

```javascript
// File extension counting
extensions = count_file_extensions(PROJECT_ROOT);
total_files = sum(extensions.values());
language_breakdown = Object.entries(extensions)
  .sort((a, b) => b[1] - a[1])
  .map(([ext, count]) => `${ext_to_language(ext)} (${Math.round(count/total_files*100)}%)`);

// Session metadata
session_count = conversation_files.length;
session_dates = conversation_files.map(f => stat(f).mtime).sort();
history_depth = `${format_date(session_dates[0])} → ${format_date(session_dates.at(-1))}`;

// Framework/tool detection from config files and imports
frameworks = detect_frameworks(PROJECT_ROOT);
```

### Phase 3: Unknown Detection

Two-step approach — concrete frequency analysis, then targeted LLM sampling:

```javascript
// Step 1: Extract tool call names from JSONL
tool_counts = {};
tool_results = Grep(pattern: '"name":"[A-Za-z_]+"', path: HISTORY_DIR, glob: "*.jsonl");
for (match of tool_results) {
  tool_name = extract_tool_name(match);
  tool_counts[tool_name] = (tool_counts[tool_name] || 0) + 1;
}

// Step 2: Find high-frequency tools not covered by any domain
all_domain_keywords = flatten(all_domains.map(d => [...d.keywords.primary, ...d.keywords.secondary]));
uncovered_tools = Object.entries(tool_counts)
  .filter(([tool, count]) => count >= 5)
  .filter(([tool]) => !all_domain_keywords.some(kw => tool.includes(kw)))
  .sort((a, b) => b[1] - a[1]);

// Step 3: For top 3 uncovered items, targeted LLM sampling
// Sample 2-3 conversation excerpts where this tool appears
// Lightweight agent characterizes what user was doing
suggested_dives = [];
for (item of uncovered_tools.slice(0, 3)) {
  context = sample_usage_context(item.tool, HISTORY_DIR, sample_size: 3);
  suggested_dives.push({
    theme: context.suggested_theme,
    evidence: `${item.count} references to ${item.tool}`,
    description: context.summary
  });
}
```

The LLM sampling step answers "what was the user doing with this tool?" — not random, but evidence-directed.

## Output Format (Contract)

### survey.md Template

```markdown
# Archaeology Survey — {Project}

> Scanned on {date} | {N} conversation files | {M} source files

## Recommended Domains

| Domain | Signal | Confidence | Score | Rationale |
|--------|--------|------------|-------|-----------|
| {domain} | {signal} | {confidence} | {score} | {rationale} |

### Signal Scale
- **strong** (score >= 20): High-value domain, run extraction first
- **moderate** (score >= 8): Worth investigating, likely has findings
- **weak** (score >= 2): Minimal signal, may yield 1-2 findings
- **none** (score < 2): No evidence found

### Confidence Scale
- **high**: Signal from 3+ distinct sessions
- **medium**: Signal from 2 sessions
- **low**: Signal from 1 session only

## Suggested Deep Dives

- **{Theme}** — {evidence}. {description}

## Project Profile

- **Primary languages:** {language breakdown}
- **Session count:** {N} conversations found
- **History depth:** {earliest} → {latest}
- **Notable tools/frameworks:** {detected list}

## Next Steps

1. `/archaeology {top-domain}` — strongest signal, run first
2. `/archaeology {second-domain}` — {rationale}
3. Consider creating `{suggested-domain}` domain

---
*Generated by archaeology survey — {date}*
```

### Output Locations

**Local:**
```
.claude/archaeology/
  survey.md              ← NEW
  INDEX.md               ← Updated to link survey
  orchestration/         ← existing domain dirs
```

**Central (unless --no-export):**
```
~/.claude/data/visibility-toolkit/work-log/archaeology/
  INDEX.md               ← Updated
  {project-slug}/
    survey.md            ← NEW
    orchestration/       ← existing domain dirs
```

## Completion Display

```
Archaeology Survey Complete

Scanned {N} conversations, {M} source files

Domains with signal:
  orchestration    strong  (score: 42.0, 5 sessions)
  python-practices moderate (score: 12.5, 2 sessions)

Suggested deep dives:
  Async patterns — 8 references, no matching domain

Local:   .claude/archaeology/survey.md
Central: ~/.claude/data/.../archaeology/{slug}/survey.md

Next: /archaeology orchestration
```

## Constraints

- Survey must complete in under 2 minutes on a typical project
- Output format is a contract — table structure doesn't change between versions
- Survey is NOT a domain in registry.yaml — it's a built-in mode
- Respects `--no-export` flag (skip central work-log write)
- Must work without sandbox mode (existing archaeology limitation)
- Size-gate at 50 JSONL / 500 source files triggers sub-agent batching

## Relationship to Progressive Disclosure Design

Survey and Progressive Disclosure are complementary, serving different phases:

| Artifact | Phase | Purpose |
|----------|-------|---------|
| `survey.md` | Pre-extraction | Discovery — "what's worth investigating?" |
| `SUMMARY.md` | Post-extraction | Synthesis — "what did I learn across domains?" |

### Reconciliation Points

1. **Entry point**: Survey is the *user-facing* entry (`/archaeology` with no args). Progressive Disclosure's INDEX.md governs *work-log navigation* after extractions exist.

2. **Output linking**: Survey completion message references INDEX.md for cross-domain views. The "Next Steps" section in survey.md mentions that post-extraction, SUMMARY.md provides the cross-domain synthesis.

3. **Confidence scales**: Survey uses session-count-based confidence (high/medium/low) for domain-level signal. Progressive Disclosure uses finding-level confidence. These are different granularities, not conflicting definitions.

4. **Project profile metadata**: Survey generates language breakdown, session count, history depth, detected frameworks. SUMMARY.md (Progressive Disclosure) can reference survey.md for this metadata rather than duplicating it.

5. **Slug generation**: Both designs share identical slug format (`PROJECT_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-')`). Directory structure: `{project-slug}/survey.md` (pre-extraction) alongside `{project-slug}/SUMMARY.md` (post-extraction) and domain directories.

### Lifecycle Flow

```
/archaeology           → survey.md (discovery)
/archaeology {domain}  → domain extractions → SUMMARY.md regenerated (synthesis)
/archaeology           → survey.md refreshed (re-discovery with new data)
```

## Implementation Notes

- Invocation patterns section in SKILL.md needs updating to show survey as default
- registry.yaml does NOT get a survey entry (it's not a domain)
- ADDING-DOMAINS.md gets a mention that survey auto-detects new domain candidates
- Local INDEX.md update function needs survey awareness
- Survey completion display should reference INDEX.md for cross-domain navigation
- Survey "Next Steps" should mention SUMMARY.md as the post-extraction orientation point
