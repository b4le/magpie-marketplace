# Excavation Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full excavation workflow (Steps E1-E6).
> The shell script `scripts/archaeology-excavation.sh` handles discovery and subprocess management.
> This workflow handles the skill-side aggregation after the script completes.
> Path variables `SKILL_DIR` and `PLUGIN_ROOT` are set by SKILL.md Path Resolution before this workflow executes.

## Excavation Workflow

When excavation mode is triggered, execute these steps.

### Excavation Step E1: Launch Shell Script

Run the excavation script with user-provided flags:

```javascript
// Parse flags from user input
DRY_RUN = args.includes('--dry-run');
MAX_CONCURRENT = extract_flag_value(args, '--max-concurrent') || 3;
SCAN_PATHS = extract_flag_value(args, '--scan-paths') || null;
MAX_AGE = extract_flag_value(args, '--max-age') || 7;

SCRIPT_PATH = `${PLUGIN_ROOT}/scripts/archaeology-excavation.sh`;

// Build command
cmd = `${SCRIPT_PATH}`;
if (SCAN_PATHS) cmd += ` --scan-paths "${SCAN_PATHS}"`;
if (MAX_CONCURRENT !== 3) cmd += ` --max-concurrent ${MAX_CONCURRENT}`;
if (MAX_AGE !== 7) cmd += ` --max-age ${MAX_AGE}`;
if (DRY_RUN) cmd += ' --dry-run';

// Execute via Bash tool (captures stdout as JSON manifest, stderr shows progress)
manifest_json = Bash(cmd);
manifest = JSON.parse(manifest_json);
```

#### E1 Verification

```javascript
// Check manifest parsed successfully
if (!manifest || typeof manifest !== 'object') {
  HARD STOP: "Excavation failed — manifest could not be parsed from script output. Check script stderr for details."
}

// Check at least one project was discovered
if (!manifest.results || manifest.results.length === 0) {
  HARD STOP: "Excavation found zero projects. Verify --scan-paths is correct or that ~/.claude/data/visibility-toolkit/work-log/archaeology exists."
}
```

If `DRY_RUN`, display the discovery results and stop:
```
Excavation Dry Run

Discovered {N} projects | {S} would skip (fresh survey) | {M} would survey

Projects to survey:
  {slug} — {path}
  ...

Skipped (fresh survey):
  {slug} — last surveyed < {MAX_AGE} days ago

Run without --dry-run to execute surveys.
```

### Excavation Step E2: Read Survey Results

For each project with status `success` in the manifest, read its survey.md from the central work-log:

```javascript
CENTRAL_BASE = '~/.claude/data/visibility-toolkit/work-log/archaeology';

surveys = {};
for (result of manifest.results.filter(r => r.status === 'success' || r.status === 'skipped')) {
  survey_path = `${CENTRAL_BASE}/${result.slug}/survey.md`;
  if (exists(survey_path)) {
    surveys[result.slug] = Read(survey_path);
  }
}
```

#### E2 Verification

```javascript
// Log per-project read outcomes
readable = Object.keys(surveys);
failed = manifest.results
  .filter(r => r.status === 'success' || r.status === 'skipped')
  .map(r => r.slug)
  .filter(slug => !surveys[slug]);

if (failed.length > 0) {
  log(`Warning: Could not read surveys for: ${failed.join(', ')}`);
}
if (readable.length > 0) {
  log(`Surveys loaded for: ${readable.join(', ')}`);
}

// Hard stop if no surveys could be read at all
if (Object.keys(surveys).length === 0) {
  HARD STOP: "Excavation aborted — no survey.md files could be read from the central work-log. Projects attempted: " + manifest.results.map(r => r.slug).join(', ')
}
```

### Excavation Step E3: Parse Survey Data

Extract structured data from each survey.md. The survey contract format (from survey-workflow.md S6) has stable, parseable sections:

```javascript
project_data = [];
for ([slug, survey_content] of Object.entries(surveys)) {
  // Parse header: "> Scanned on {date} | {N} conversation files | {M} source files"
  header = extract_blockquote(survey_content);
  scan_date = extract_date(header);
  session_count = extract_number(header, 'conversation files');

  // Parse domain scores table
  // Format: | domain | signal | confidence | score | rationale |
  domain_rows = extract_table_rows(survey_content, 'Recommended Domains');
  top_domain = domain_rows[0] || null;  // Already sorted by score desc

  // Parse project profile section
  profile = extract_key_values(survey_content, 'Project Profile');

  // Parse suggested deep dives
  deep_dives = extract_bullet_items(survey_content, 'Suggested Deep Dives');

  // Parse discovered signals and survey-candidates.json
  candidates_path = `${CENTRAL_BASE}/${result.slug}/survey-candidates.json`;
  candidate_signals = [];
  if (exists(candidates_path)) {
    candidates_data = JSON.parse(Read(candidates_path));
    candidate_signals = candidates_data.candidates.map(c => ({
      id: c.id,
      signal: c.signal,
      terms: c.terms,
      coherence: c.coherence,
      source: 'survey'
    }));
  } else {
    // Fallback: parse Discovered Signals table from survey.md if available
    discovered_signals = extract_table_rows(survey_content, 'Discovered Signals');
    candidate_signals = discovered_signals.map(d => ({
      id: d.candidate || d.name,
      signal: d.signal,
      terms: [],
      coherence: 'unknown',
      source: 'survey_table'
    }));
  }

  project_data.push({
    slug: slug,
    scan_date: scan_date,
    sessions: session_count,
    top_domain: top_domain ? { id: top_domain.domain, signal: top_domain.signal } : null,
    languages: profile['Primary languages'] || 'Unknown',
    deep_dives: deep_dives,
    all_domains: domain_rows,
    candidate_signals: candidate_signals
  });
}
```

### Excavation Step E4: Synthesise Portfolio

Using the parsed data, generate the cross-project portfolio. The Project Overview table is mechanical (from parsed data). The Cross-Project Patterns and Recommended Next Steps sections use LLM synthesis.

```javascript
// Build Project Overview table
overview_rows = project_data
  .sort((a, b) => (b.sessions || 0) - (a.sessions || 0))
  .map(p => {
    action = p.top_domain && p.top_domain.signal !== 'none'
      ? `/archaeology ${p.top_domain.id}`
      : 'skip';
    return `| ${p.slug} | ${p.sessions || '?'} | ${p.top_domain?.id || '-'} | ${p.top_domain?.signal || 'none'} | ${p.scan_date} | \`${action}\` |`;
  }).join('\n');

// Aggregate domain signals across projects for cross-project analysis
domain_cross = {};
for (p of project_data) {
  for (d of p.all_domains) {
    if (d.signal === 'none') continue;
    if (!domain_cross[d.domain]) domain_cross[d.domain] = [];
    domain_cross[d.domain].push({ project: p.slug, signal: d.signal, score: d.score });
  }
}

// Aggregate uncovered themes from deep dives
all_deep_dives = project_data.flatMap(p =>
  p.deep_dives.map(d => ({ ...d, project: p.slug }))
);

// Aggregate candidate signals across projects
candidate_cross = {};
for (p of project_data) {
  for (c of p.candidate_signals || []) {
    if (!candidate_cross[c.id]) {
      candidate_cross[c.id] = {
        id: c.id,
        projects: [],
        total_signal_score: 0,
        all_terms: new Set()
      };
    }
    candidate_cross[c.id].projects.push(p.slug);
    candidate_cross[c.id].total_signal_score += (c.signal === 'moderate' ? 2 : 1);
    for (term of c.terms) {
      candidate_cross[c.id].all_terms.add(term);
    }
  }
}

// Emergence threshold: 3+ projects
emerged_candidates = Object.values(candidate_cross)
  .filter(c => c.projects.length >= 3)
  .sort((a, b) => b.total_signal_score - a.total_signal_score);

// Build failed/skipped table
skipped_failed = manifest.results
  .filter(r => r.status === 'skipped' || r.status === 'failed')
  .map(r => `| ${r.slug} | ${r.reason === 'fresh_survey' ? 'Fresh survey (< ' + MAX_AGE + ' days)' : r.reason} |`)
  .join('\n');
```

**LLM synthesis prompt (internal — used to generate the cross-project sections):**

The skill should use its own reasoning to generate:
1. **Cross-Project Patterns** — which domains appear across multiple projects, what that means, any uncovered themes appearing in 2+ projects
2. **Recommended Next Steps** — ranked list of which project+domain to run first (strongest signal * most sessions), new domains to create, projects to skip; also surface graduation candidates from `emerged_candidates` when any exist

These sections are written directly by the skill's LLM capabilities based on the `domain_cross`, `all_deep_dives`, `candidate_cross`, `emerged_candidates`, and `project_data` context.

### Excavation Step E5: Write Portfolio

```javascript
PORTFOLIO_PATH = `${CENTRAL_BASE}/portfolio.md`;

// Build Domain Landscape rows
// Established: domains with status 'active' in registry
established_rows = Object.entries(domain_cross)
  .filter(([domain]) => registry_status(domain) === 'active')
  .map(([domain, entries]) => {
    projects_with_signal = entries.length;
    strongest = entries.sort((a, b) => (b.score || 0) - (a.score || 0))[0]?.signal || '-';
    avg_score = (entries.reduce((sum, e) => sum + (parseFloat(e.score) || 0), 0) / entries.length).toFixed(1);
    return `| ${domain} | ${projects_with_signal} | ${strongest} | ${avg_score} |`;
  }).join('\n') || '| _(none)_ | | | |';

// Emerging: domains with status 'confirmed' in registry
emerging_rows = Object.entries(domain_cross)
  .filter(([domain]) => registry_status(domain) === 'confirmed')
  .map(([domain, entries]) => {
    projects = entries.map(e => e.project).join(', ');
    findings = entries.reduce((sum, e) => sum + (e.findings || 0), 0);
    confirmed_at = registry_confirmed_at(domain) || '-';
    return `| ${domain} | ${projects} | ${findings} | ${confirmed_at} |`;
  }).join('\n') || '| _(none)_ | | | |';

// Candidate: all entries in candidate_cross
candidate_rows = Object.values(candidate_cross)
  .map(c => {
    projects = c.projects.join(', ');
    coherence = candidate_coherence(c.id) || '-';
    terms = [...c.all_terms].join(', ') || '-';
    return `| ${c.id} | ${projects} | ${coherence} | ${terms} |`;
  }).join('\n') || '| _(none)_ | | | |';

portfolio_content = `# Archaeology Portfolio — ${current_date()}

> Scanned ${manifest.projects_discovered} projects | ${manifest.projects_surveyed} newly surveyed | ${manifest.projects_skipped} skipped | ${manifest.projects_failed} failed

## Project Overview

| Project | Sessions | Top Domain | Signal | Last Survey | Action |
|---------|----------|------------|--------|-------------|--------|
${overview_rows}

## Cross-Project Patterns

${cross_project_patterns}

## Domain Landscape

### Established (curated, active extraction)

| Domain | Projects with Signal | Strongest Signal | Avg Score |
|--------|---------------------|------------------|-----------|
${established_rows}

### Emerging (confirmed, validated by extraction)

| Domain | Projects | Findings | Confirmed At |
|--------|----------|----------|-------------|
${emerging_rows}

### Candidate (discovered by survey, not yet extracted)

| Candidate | Projects | Coherence | Terms |
|-----------|----------|-----------|-------|
${candidate_rows}

## Recommended Next Steps

${recommended_next_steps}

## Skipped & Failed

| Project | Reason |
|---------|--------|
${skipped_failed || '| _(none)_ | |'}

---
*Generated by archaeology excavation — ${current_date()}*
`;

Write(PORTFOLIO_PATH, portfolio_content);

if (emerged_candidates.length > 0) {
  grad_content = `# Graduation Candidates — ${current_date()}

> Candidates appearing in 3+ projects. Consider promoting to confirmed domains.

${emerged_candidates.map(c => `## ${c.id}

- **Projects:** ${c.projects.join(', ')}
- **Signal score:** ${c.total_signal_score}
- **Terms:** ${[...c.all_terms].join(', ')}
- **Action:** \`/archaeology ${c.id}\` to run suggested-tier extraction
`).join('\n')}

---
*Generated by archaeology excavation — ${current_date()}*
`;
  Write(`${CENTRAL_BASE}/graduation-candidates.md`, grad_content);
}
```

### Excavation Step E6: Completion Display

**MUST use the exact template from `output-templates.md#excavation-completion`.** Do not reformat, add tables, add emoji, or alter the structure.

Key variable mappings:
- `manifest.*` — from E1 shell script JSON output
- Top recommendations — from E4 synthesis, one per line, max 3

### Excavation Completion Criteria

Excavation run is complete when:
- [ ] Shell script executed successfully (or --dry-run displayed results)
- [ ] All survey.md files read from central work-log
- [ ] Survey data parsed (domain scores, profiles, deep dives)
- [ ] Survey candidate signals parsed from survey-candidates.json (E3)
- [ ] Portfolio.md generated with cross-project synthesis
- [ ] Domain Landscape section included in portfolio (E5)
- [ ] Portfolio.md written to central work-log root
- [ ] graduation-candidates.md written when candidates cross 3-project threshold (E5)
- [ ] Completion summary displayed with recommendations

> **Note:** `--no-export` is not supported for excavation mode. Excavation's purpose is cross-project aggregation to the central work-log — local-only mode would be meaningless.
