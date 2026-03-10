# Survey Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full survey workflow (Steps S1-S8).
> Context variables (`PROJECT_NAME`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, `CENTRAL_BASE`, etc.) are set by SKILL.md Step 1 / routing logic before this workflow executes.
> Path variables `SKILL_DIR` and `PLUGIN_ROOT` are set by SKILL.md Path Resolution before this workflow executes.

## Survey Workflow

When survey mode is triggered, execute these steps instead of the domain extraction workflow (Steps 1-5).

### Survey Step S1: Resolve Project Context

Reuses the same project resolution logic as domain extraction Step 1, but without domain-specific paths:

```javascript
NO_EXPORT = args.includes('--no-export');

// Sandbox detection — if sandbox mode restricts writes outside the project,
// force local-only mode and warn the user upfront (don't fail silently later).
CENTRAL_BASE_TEST = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
if (!NO_EXPORT) {
  try {
    // Test if we can write to the central work-log location
    test_result = Bash(`mkdir -p ${CENTRAL_BASE_TEST}/.sandbox-test && rmdir ${CENTRAL_BASE_TEST}/.sandbox-test`);
  } catch (e) {
    // Sandbox is blocking writes outside the project directory
    NO_EXPORT = true;
    console.log("⚠ Sandbox mode detected — central export is not available.");
    console.log("  Running in local-only mode (equivalent to --no-export).");
    console.log("  To enable export, add ~/.claude/data/ to your sandbox allowlist.");
  }
}

// Project resolution (same logic as Step 1)
if (user_provided_project_name) {
  PROJECT_NAME = user_provided_project_name;
  PROJECT_PATH_PATTERN = `**/${PROJECT_NAME}/**`;
  matching_paths = Glob(pattern: PROJECT_PATH_PATTERN, path: ~/Developer);
  if (matching_paths.length === 0) {
    error("Project not found in ~/Developer");
  }
  PROJECT_ROOT = matching_paths[0];
  // For explicit project name, use wildcard pattern for history directory
  HISTORY_DIR = `~/.claude/projects/-Users-*-${PROJECT_PATH_PATTERN}/`;
} else {
  PROJECT_ROOT = cwd;
  PROJECT_NAME = basename(PROJECT_ROOT);
  // Encode absolute path to match Claude Code project directory naming convention
  // Convention: replace every / with - (e.g., /Users/username/myproject → -Users-username-myproject)
  encoded_path = PROJECT_ROOT.replace(/\//g, '-');
  HISTORY_DIR = `~/.claude/projects/${encoded_path}/`;
}

PROJECT_SLUG = PROJECT_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
ARCHAEOLOGY_DIR = `${PROJECT_ROOT}/.claude/archaeology`;

// Central work-log location (survey.md lives at project level, not domain level)
CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
CENTRAL_PROJECT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;
```

Verify output directories exist:
```bash
mkdir -p ${ARCHAEOLOGY_DIR}
if (!NO_EXPORT) {
  mkdir -p ${CENTRAL_PROJECT_DIR}
}
```

### Survey Step S2: Size Check

Determine scan strategy based on project size. Large projects use sub-agent batches to protect the main agent's context window:

```javascript
// Count conversation files
conversation_files = Glob(`${HISTORY_DIR}/**/*.jsonl`);
// Count source files (exclude noise)
source_files = Glob(`${PROJECT_ROOT}/**/*`, exclude: ['.git', 'node_modules', '__pycache__', '.venv', 'venv']);

LARGE_PROJECT = conversation_files.length > 50 || source_files.length > 500;

// Discovery activates when corpus has enough data for meaningful term extraction
discovery_enabled = conversation_files.length >= 3;
// Below 3 files, term extraction produces noise — skip S3.5 entirely

// Log project size for rationale generation
project_size = {
  conversations: conversation_files.length,
  source_files: source_files.length,
  is_large: LARGE_PROJECT,
  discovery_enabled: discovery_enabled
};
```

If `LARGE_PROJECT` is true, Phase 1 (keyword scoring) and Phase 3 (unknown detection) use sub-agents that each handle a slice of files and return numeric counts only — never raw file content. The sub-agent prompt should be:

```
You are counting keyword occurrences for an archaeology survey.
FILES TO SCAN: [list of assigned file paths]
KEYWORDS: [list of keywords to count]
Return ONLY a JSON object: { "keyword": count, ... }
Do NOT return file contents. Do NOT return matches. Just counts.
```

### Survey Step S3: Domain Keyword Scoring (Phase 1)

Load all domains from registry and score each against conversation history.

**IMPORTANT:** Raw Grep on JSONL files produces inflated scores because JSONL records contain system prompts, tool definitions, skill listings, `toolUseResult` dumps, and `tool_result` blocks (raw file contents from Read/Glob/Bash calls) alongside real conversation content. All keyword counting MUST pre-filter through the jq conversation filter to extract only real user/assistant text. The filter excludes `tool_result` blocks entirely because they cause self-referential score inflation — especially when archaeology reads its own domain files during surveys.

```javascript
// Read registry
REGISTRY_PATH = `${SKILL_DIR}/references/domains/registry.yaml`;
registry = Read(REGISTRY_PATH);
all_domains = parse_yaml(registry).domains.filter(d => d.status === 'active');

// jq filter for extracting conversation text (excludes system prompts, meta, toolUseResult)
JQ_FILTER_PATH = `${SKILL_DIR}/references/jsonl-filter.jq`;
// Script directory for delegated scoring/profiling/discovery
SCRIPT_DIR = `${PLUGIN_ROOT}/scripts`;

// Domain keyword scoring — delegates to arch-score.sh for reproducible, cacheable scoring
// The script replicates the exact formula: (primary * 3) + (secondary * 1), diversity multiplier,
// per-session caps (PRIMARY_CAP=5, SECONDARY_CAP=3), signal classification thresholds.
//
// Scoring formula reference (implemented in arch-score.sh):
//   raw_score = (primary_score * 3) + (secondary_score * 1)
//   diversity_factor = min(1.5, 1.0 + (session_count * 0.1))
//   final_score = round(raw_score * diversity_factor, 1dp)
//   Signal: strong (>=20, 2+ sessions) | moderate (>=8) | weak (>=2) | none (<2)
//
// Per-keyword-per-session caps prevent any single keyword from dominating.
// Even with tool_result exclusion in the jq filter, assistant text can still
// contain long quoted code blocks or file content summaries.
//   PRIMARY_CAP_PER_SESSION = 5
//   SECONDARY_CAP_PER_SESSION = 3
//
// Session-count invariant (enforced by script):
//   0 sessions -> signal = 'none'
//   1 session  -> signal capped at 'moderate' (never 'strong')
//
// Confidence classification (enforced by script):
//   3+ sessions -> 'high' | 2 sessions -> 'medium' | 1 session -> 'low' | 0 -> '-'
//
// Rationale strings follow these patterns:
//   "14 primary hits across 5 sessions"
//   "6 pytest refs in 2 sessions"
//   "No matching keywords detected"
//
// For LARGE_PROJECT: the script handles batching internally using parallel
// jq invocations. The scoring formula is identical regardless of project size.

SCORE_OUTPUT = Bash(`${SCRIPT_DIR}/arch-score.sh "${HISTORY_DIR}" --registry "${REGISTRY_PATH}" --filter "${JQ_FILTER_PATH}" --quiet`);
domain_scores = JSON.parse(SCORE_OUTPUT);

// Build comprehensive known-terms set for discovery exclusion (S3.5)
KNOWN_DOMAIN_TERMS = new Set();
for (domain of domain_scores) {
  // Load domain file keywords to build exclusion set
  domain_def = Read(`${SKILL_DIR}/references/domains/${domain.file}`);
  keywords = parse_frontmatter(domain_def).keywords;
  for (kw of [...keywords.primary, ...keywords.secondary]) {
    KNOWN_DOMAIN_TERMS.add(kw.toLowerCase());
  }
}
```

> **Algorithm reference:** The scoring logic previously inlined here is now executed by `arch-score.sh`. The script reads the domain registry, loads keyword lists from each domain file, pipes conversation files through the jq filter, applies per-session caps, computes weighted scores with diversity multipliers, classifies signal/confidence, and builds rationale strings. The exact formula and thresholds are documented in the comment block above and in the script itself. See the Signal Scale and Confidence Scale tables below for the classification contract.

#### Signal Scale (Contract — do not change between versions)

| Signal | Threshold | Session Cap | Meaning |
|--------|-----------|-------------|---------|
| strong | score >= 20 | requires 2+ sessions | High-value domain, run extraction first |
| moderate | score >= 8 | — | Worth investigating, likely has findings |
| weak | score >= 2 | — | Minimal signal, may yield 1-2 findings |
| none | score < 2 | forced if 0 sessions | No evidence found |

**Session-count invariant:** Signal is capped after score classification. A project with 0 matching sessions always gets `none`. A project with exactly 1 matching session is capped at `moderate` (never `strong`). This prevents inflated labels from single-session projects.

#### Confidence Scale (Contract — do not change between versions)

| Confidence | Criterion | Meaning |
|------------|-----------|---------|
| high | 3+ distinct sessions | Broad pattern across usage |
| medium | 2 sessions | Some evidence but limited |
| low | 1 session | Single occurrence, may be one-off |
| - | 0 sessions | No signal |

### Survey Step S3.5: Domain Discovery (Phase 1.5)

**Gate:** Only runs when `discovery_enabled === true` (>=3 conversation files). When skipped, set `discovered_signals = []` and note in survey output: "Discovery requires 3+ sessions."

**Purpose:** Extract terms from conversation history not covered by existing domains, cluster them into potential domain candidates, and assess coherence. All statistical work is programmatic; LLM reserved for semantic clustering only.

**Signal ceiling:** Discovered signals NEVER exceed `moderate` signal strength, regardless of raw scores. This prevents uncurated domains from appearing more authoritative than curated ones.

```javascript
if (!discovery_enabled) {
  discovered_signals = [];
  // Note in output: "Discovery requires 3+ sessions."
  // Skip to S4
} else {

  // Step 1: Programmatic term extraction via arch-discover.sh
  DISCOVER_OUTPUT = Bash(`${SCRIPT_DIR}/arch-discover.sh "${HISTORY_DIR}" --registry "${REGISTRY_PATH}" --filter "${JQ_FILTER_PATH}" --top 30 --quiet`);
  raw_candidates = JSON.parse(DISCOVER_OUTPUT);

  if (raw_candidates.length === 0) {
    discovered_signals = [];
    // Note in output: "No uncovered terms found — existing domains have good coverage."
    // Skip to S4
  } else {

    // Step 2: LLM semantic assessment (single Explore agent call)
    // This is the ONLY LLM call in the discovery pipeline.
    // Purpose: group related terms into coherent domain clusters.
    cluster_result = Agent({
      subagent_type: "Explore",
      model: "haiku",
      prompt: `You are assessing whether a set of high-frequency terms from developer conversations
form coherent domain clusters.

TERMS (sorted by relevance score):
${raw_candidates.map(c => `  ${c.term} (${c.total_count} occurrences, ${c.session_spread} sessions)`).join('\n')}

EXISTING DOMAINS (do not duplicate these):
${domain_scores.map(d => `  ${d.domain}: ${d.name}`).join('\n')}

Instructions:
1. Group related terms into clusters. Maximum 4 clusters.
2. For each cluster, provide:
   - A 2-4 word domain name (noun phrase, not a verb)
   - The terms that belong to it
   - A one-sentence description of what practice area this represents
   - Coherence assessment: high / medium / low
     - high: 4+ terms with clear semantic relationship, distinct from existing domains
     - medium: 3+ terms with plausible relationship
     - low: terms grouped by proximity but no clear practice area

3. Discard terms that don't fit any cluster (noise).
4. Do NOT create clusters that substantially overlap existing domains.

Return ONLY XML blocks:
<cluster>
<name>domain name</name>
<terms>term1, term2, term3</terms>
<description>what this practice area covers</description>
<coherence>high|medium|low</coherence>
</cluster>`
    });

    // Step 3: Parse clusters and build discovered_signals[]
    discovered_signals = [];
    for (cluster of parse_xml_clusters(cluster_result)) {
      // Signal ceiling: cap at 'moderate' regardless of term scores
      signal = cluster.coherence === 'high' ? 'moderate' : 'weak';

      discovered_signals.push({
        name: cluster.name,
        terms: cluster.terms,
        description: cluster.description,
        coherence: cluster.coherence,
        signal: signal,  // never exceeds 'moderate'
        term_count: cluster.terms.length,
        session_spread: max_session_spread(cluster.terms, raw_candidates)
      });
    }

    // Sort by coherence (high first), then term_count descending
    discovered_signals.sort((a, b) => {
      const coherence_order = { high: 0, medium: 1, low: 2 };
      return (coherence_order[a.coherence] - coherence_order[b.coherence])
        || (b.term_count - a.term_count);
    });
  }
}
```

**`parse_xml_clusters()` helper:**

Extracts cluster elements from the agent's XML response:

```javascript
function parse_xml_clusters(xml_text) {
  clusters = [];
  // Match each <cluster>...</cluster> block
  for (match of xml_text.matchAll(/<cluster>([\s\S]*?)<\/cluster>/g)) {
    block = match[1];
    clusters.push({
      name: extract_xml_field(block, 'name'),
      terms: extract_xml_field(block, 'terms').split(',').map(t => t.trim()),
      description: extract_xml_field(block, 'description'),
      coherence: extract_xml_field(block, 'coherence').trim().toLowerCase()
    });
  }
  return clusters;
}
```

**`max_session_spread()` helper:**

Returns the maximum session_spread value across all raw_candidates that belong to a cluster:

```javascript
function max_session_spread(cluster_terms, raw_candidates) {
  return Math.max(...cluster_terms.map(term => {
    candidate = raw_candidates.find(c => c.term === term);
    return candidate ? candidate.session_spread : 0;
  }));
}
```

### Survey Step S4: Project Profiling (Phase 2)

Characterize the project based on source files and session metadata:

```javascript
// Project profiling — delegates to arch-profile.sh for reusable profiling
PROFILE_OUTPUT = Bash(`${SCRIPT_DIR}/arch-profile.sh "${PROJECT_ROOT}" "${HISTORY_DIR}" --quiet`);
project_profile = JSON.parse(PROFILE_OUTPUT);
```

> **Algorithm reference:** The profiling logic previously inlined here is now executed by `arch-profile.sh`. The script performs the following steps, documented here for reference:
>
> - **Language breakdown:** Counts file extensions in the project (excluding `.git`, `node_modules`, `__pycache__`, `.venv`, `venv`), maps them to language names via a built-in extension-to-language table, aggregates by language, and returns the top 5 by percentage.
> - **Session metadata:** Counts conversation files, extracts file modification times for date range (`earliest -> latest`), formats as `history_depth`.
> - **Framework detection:** Checks for well-known config files (`package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`, `build.gradle`, `docker-compose.yml`, `Dockerfile`, `.github/workflows`, `Makefile`, `tsconfig.json`, `jest.config`, `pytest.ini`, `setup.cfg`, `.pre-commit-config.yaml`) and maps each to its framework name. Results are deduplicated.
>
> The script returns a JSON object with the following shape:
> ```json
> {
>   "languages": "TypeScript (45%), JavaScript (20%), ...",
>   "session_count": 12,
>   "history_depth": "2025-11-01 -> 2026-03-10",
>   "source_file_count": 342,
>   "frameworks": ["Node.js", "TypeScript", "Jest", "Docker"]
> }
> ```

### Survey Step S5: Unknown Detection (Phase 3)

Identify high-frequency tools/patterns not covered by any existing domain. Two-step: concrete frequency analysis, then targeted LLM sampling for top unknowns.

**Step 1 — Tool frequency extraction:**

**IMPORTANT:** Raw Grep for `"name":"ToolName"` on JSONL files matches both real tool invocations and tool definitions embedded in system prompts. Use the structured jq filter to extract only actual tool_use invocations from assistant messages.

```javascript
// Extract tool call names using jq structured filter
// This extracts .name from tool_use content blocks in non-meta assistant records only.
// Excludes system prompt tool definitions and meta injections.
JQ_TOOL_FILTER_PATH = `${SKILL_DIR}/references/jsonl-tool-names.jq`;

// Bash equivalent:
//   find $HISTORY_DIR -name "*.jsonl" -print0 |
//     xargs -0 -P 8 -I{} jq -r -f $JQ_TOOL_FILTER_PATH {} 2>/dev/null |
//     sort | uniq -c | sort -rn

tool_counts = {};
for (file of conversation_files) {
  tool_names = run_jq(JQ_TOOL_FILTER_PATH, file);  // returns array of tool name strings
  for (name of tool_names) {
    tool_counts[name] = (tool_counts[name] || 0) + 1;
  }
}
```

**Step 2 — Filter to uncovered tools:**

```javascript
// Collect all keywords from all domains
all_domain_keywords = [];
for (domain of all_domains) {
  domain_def = Read(`${SKILL_DIR}/references/domains/${domain.file}`);
  kw = parse_frontmatter(domain_def).keywords;
  all_domain_keywords.push(...kw.primary, ...kw.secondary);
}

// Common built-in tools to exclude (not interesting for domain detection)
BUILTIN_TOOLS = ['Read', 'Write', 'Edit', 'Glob', 'Grep', 'Bash', 'Agent',
                 'AskUserQuestion', 'Skill', 'TaskCreate', 'TaskUpdate', 'TaskList',
                 'TaskGet', 'EnterPlanMode', 'ExitPlanMode', 'WebFetch', 'WebSearch',
                 'NotebookEdit', 'ToolSearch'];

// Find tools with 5+ uses that aren't covered by any domain and aren't builtins
uncovered_tools = Object.entries(tool_counts)
  .filter(([tool, count]) => count >= 5)
  .filter(([tool]) => !BUILTIN_TOOLS.includes(tool))
  .filter(([tool]) => !all_domain_keywords.some(kw =>
    tool.toLowerCase().includes(kw.toLowerCase())
  ))
  .sort((a, b) => b[1] - a[1]);
```

**Step 3 — Targeted LLM sampling for top unknowns:**

For the top 3 uncovered tools, spawn a lightweight Explore agent that samples 2-3 conversation excerpts where the tool appears and characterizes what the user was doing:

```javascript
suggested_dives = [];

for ([tool_name, count] of uncovered_tools.slice(0, 3)) {
  // Find files containing this tool
  files_with_tool = Grep(
    pattern: `"name":"${tool_name}"`,
    path: HISTORY_DIR,
    glob: "*.jsonl",
    output_mode: "files_with_matches",
    head_limit: 3  // Sample from at most 3 files
  );

  // Spawn lightweight agent to characterize usage
  agent_result = Agent({
    subagent_type: "Explore",
    prompt: `You are analyzing usage of the "${tool_name}" tool in Claude Code conversations.

Read these files and find instances of "${tool_name}" being called:
${files_with_tool.join('\n')}

For each instance found (up to 3), note:
1. What was the user trying to accomplish?
2. What kind of pattern/workflow does this represent?

Then provide:
- A 2-4 word THEME name (e.g., "Async patterns", "API integration", "Data pipeline")
- A one-sentence SUMMARY of how this tool was typically used

Return ONLY the XML tags below — no prose, no headers, no explanation outside the tags. Do NOT use KEY: value format.
<theme>[theme name]</theme>
<summary>[one sentence]</summary>`
  });

  // Parse agent response
  theme = extract_xml_field(agent_result, 'theme');
  summary = extract_xml_field(agent_result, 'summary');

  suggested_dives.push({
    theme: theme || `${tool_name} usage`,
    evidence: `${count} references to ${tool_name} not covered by existing domains`,
    description: summary || `Frequent use of ${tool_name} detected`
  });
}
```

If `LARGE_PROJECT` is true, skip the LLM sampling step (Step 3) and use the tool name directly as the theme to avoid additional context consumption.

### Survey Step S6: Generate survey.md

> **Output Contract:** The `survey.md` file format below is a stable contract used by excavation mode and cross-project comparison. The file MUST be written as a markdown table exactly matching the template below. Do NOT use ASCII box-drawing characters, indented plain text, or any alternative format. The completion display (shown in terminal after writing) is a SEPARATE format defined in `output-templates.md#survey-completion`.

Assemble all collected data into the contract output format:

```javascript
// Build the Recommended Domains table rows
domain_table_rows = domain_scores.map(d =>
  `| ${d.id} | ${d.signal} | ${d.confidence} | ${d.score} | ${d.rationale} |`
).join('\n');

// Build Suggested Deep Dives section
deep_dives_section = suggested_dives.length > 0
  ? suggested_dives.map(d =>
      `- **${d.theme}** — ${d.evidence}. ${d.description}`
    ).join('\n')
  : '_No uncovered patterns detected. All high-frequency tools are covered by existing domains._';

// Build Discovered Signals section
if (discovered_signals.length > 0) {
  discovered_section = `## Discovered Signals

Terms not covered by existing domains, clustered by semantic similarity.
Signal ceiling: discovered signals are capped at \`moderate\` — run extraction to validate.

| Cluster | Signal | Coherence | Terms | Description |
|---------|--------|-----------|-------|-------------|
${discovered_signals.map(s => `| ${s.name} | ${s.signal} | ${s.coherence} | ${s.terms.join(', ')} | ${s.description} |`).join('\n')}

To extract against a discovered signal: \`/archaeology extract <cluster-name>\``;
} else if (discovery_enabled) {
  discovered_section = `## Discovered Signals

No uncovered domain signals detected — existing domains have good coverage.`;
} else {
  discovered_section = `## Discovered Signals

Discovery requires 3+ conversation sessions (found ${conversation_files.length}).`;
}

// Build Next Steps section
domains_with_signal = domain_scores.filter(d => d.signal !== 'none');
next_steps = [];
if (domains_with_signal.length > 0) {
  next_steps.push(`1. \`/archaeology ${domains_with_signal[0].id}\` — strongest signal, run first`);
}
if (domains_with_signal.length > 1) {
  next_steps.push(`2. \`/archaeology ${domains_with_signal[1].id}\` — ${domains_with_signal[1].rationale}`);
}
if (suggested_dives.length > 0) {
  next_steps.push(`${next_steps.length + 1}. Consider creating \`${suggested_dives[0].theme.toLowerCase().replace(/\s+/g, '-')}\` domain`);
}
if (next_steps.length === 0) {
  next_steps.push('1. No strong signals found — try running on a different project');
}

// Always append SUMMARY.md reference for post-extraction orientation
next_steps.push(`\nAfter running domain extractions, see \`SUMMARY.md\` for cross-domain synthesis.`);

// Assemble survey.md content
survey_content = `# Archaeology Survey — ${PROJECT_NAME}

> Scanned on ${current_date()} | ${project_size.conversations} conversation files | ${project_size.source_files} source files

## Recommended Domains

| Domain | Signal | Confidence | Score | Rationale |
|--------|--------|------------|-------|-----------|
${domain_table_rows}

### Signal Scale
- **strong** (score >= 20, requires 2+ sessions): High-value domain, run extraction first
- **moderate** (score >= 8): Worth investigating, likely has findings
- **weak** (score >= 2): Minimal signal, may yield 1-2 findings
- **none** (score < 2, or 0 sessions): No evidence found

### Confidence Scale
- **high**: Signal from 3+ distinct sessions
- **medium**: Signal from 2 sessions
- **low**: Signal from 1 session only

${discovered_section}

## Suggested Deep Dives

${deep_dives_section}

## Project Profile

- **Primary languages:** ${project_profile.languages}
- **Session count:** ${project_profile.session_count} conversations found
- **History depth:** ${project_profile.history_depth}
- **Notable tools/frameworks:** ${project_profile.frameworks.join(', ') || 'None detected'}

## Next Steps

${next_steps.join('\n')}

---
*Generated by archaeology survey — ${current_date()}*
`;

// Write local survey.md
SURVEY_LOCAL_PATH = `${ARCHAEOLOGY_DIR}/survey.md`;
Write(SURVEY_LOCAL_PATH, survey_content);
console.log(`Created: ${SURVEY_LOCAL_PATH}`);
```

**Update local INDEX.md with survey awareness:**

```javascript
// CANONICAL DEFINITION — also called from SKILL.md Step 4.
// This is the single source of truth. SKILL.md references this location.
function update_local_archaeology_index() {
  INDEX_PATH = `${ARCHAEOLOGY_DIR}/INDEX.md`;

  // Check if survey, workstyle, and conservation outputs exist
  has_survey = exists(`${ARCHAEOLOGY_DIR}/survey.md`);
  has_workstyle = exists(`${ARCHAEOLOGY_DIR}/workstyle.md`);
  has_artifacts = exists(`${ARCHAEOLOGY_DIR}/artifacts/_index.json`);
  has_exhibition = exists(`${ARCHAEOLOGY_DIR}/exhibition.md`);

  // Find all domain directories
  // Find domain directories by looking for any output files (not just README.md)
  domain_dirs = Glob(pattern: `${ARCHAEOLOGY_DIR}/*/*.md`)
    .map(f => f.split('/').slice(-2, -1)[0])
    .filter((d, i, arr) => d !== '.work' && arr.indexOf(d) === i);

  index_content = `# Archaeology Index

${has_survey ? '## Survey\n- [survey.md](./survey.md) — Project survey and domain recommendations\n\n' : ''}${has_workstyle ? '## Workstyle\n- [workstyle.md](./workstyle.md) — Working style profile\n- [workstyle.json](./workstyle.json) — Structured workstyle data\n\n' : ''}${has_artifacts ? '## Conservation\n- [exhibition.md](./exhibition.md) — Project conservation exhibition\n- [artifacts/](./artifacts/) — Conserved narrative artifacts\n\n' : ''}## Domains extracted:

${domain_dirs.length > 0
  ? domain_dirs.map(d => `- [${d}/](./${d}/) — Extracted patterns`).join('\n')
  : '_No domains extracted yet. Run \`/archaeology\` to survey domain signal._'}

Last updated: ${current_date()}
`;

  Write(INDEX_PATH, index_content);
  console.log(`Updated: ${INDEX_PATH}`);
}

update_local_archaeology_index();
```

### Shared Function: update_central_index()

> This function is defined in SKILL.md Step 5c and reused here. It scans all `metadata.json` files
> in the central work-log to rebuild `INDEX.md`. For the full implementation, see SKILL.md Step 5c.
> Survey calls it to ensure the central index reflects the latest state after export.

```javascript
// Abbreviated — see SKILL.md Step 5c for full implementation
function update_central_index() {
  INDEX_PATH = `${CENTRAL_BASE}/INDEX.md`;
  // Scan all project/domain directories for metadata.json
  // Also check for survey.md at project level
  // Group by project, build reading-path index
  // Write INDEX_PATH
}
```

> **Note:** `update_central_index()` currently scans for `metadata.json` files only (created by domain extractions).
> On a survey-only run (no prior domain extractions), the central INDEX.md won't list this project.
> The survey.md file still exists at `${CENTRAL_PROJECT_DIR}/survey.md` and is discoverable directly.
> This is by design — the central INDEX focuses on extraction results. Survey is a discovery step.

### Survey Step S7: Write Structured Intermediates

Write `survey-candidates.json` alongside `survey.md` for consumption by dig, excavation, and conserve modes:

```javascript
survey_candidates = {
  generated: new Date().toISOString(),
  project: PROJECT_NAME,
  discovery_enabled: discovery_enabled,
  domain_scores: domain_scores,
  discovered_signals: discovered_signals,
  known_domain_terms: Array.from(KNOWN_DOMAIN_TERMS)
};

// Write alongside survey.md
Write(`${ARCHAEOLOGY_DIR}/survey-candidates.json`, JSON.stringify(survey_candidates, null, 2));
console.log(`Created: ${ARCHAEOLOGY_DIR}/survey-candidates.json`);
```

**Schema:**
```json
{
  "generated": "2026-03-10T14:00:00Z",
  "project": "magpie-marketplace",
  "discovery_enabled": true,
  "domain_scores": [
    {"domain": "orchestration", "name": "Orchestration Patterns", "score": 34.5, "signal": "strong", "confidence": "high", "sessions": 5}
  ],
  "discovered_signals": [
    {"name": "MCP Integration", "terms": ["mcp__", "mcp-server", "stdio"], "description": "MCP tool integration patterns", "coherence": "high", "signal": "moderate", "term_count": 3, "session_spread": 4}
  ],
  "known_domain_terms": ["orchestration", "sub-agent", "TeamCreate"]
}
```

### Survey Step S8: Export to Central Work-Log

**Skip this step if `--no-export` flag was provided.**

```javascript
if (NO_EXPORT) {
  console.log("Skipping export (--no-export flag)");
  // Jump to completion display
} else {
  // Write survey.md to central location
  Write(`${CENTRAL_PROJECT_DIR}/survey.md`, survey_content);
  console.log(`Exported to: ${CENTRAL_PROJECT_DIR}/survey.md`);

  // Write survey-candidates.json to central location
  Write(`${CENTRAL_PROJECT_DIR}/survey-candidates.json`, JSON.stringify(survey_candidates, null, 2));
  console.log(`Exported to: ${CENTRAL_PROJECT_DIR}/survey-candidates.json`);

  // Update central INDEX.md (add survey info to project entry)
  update_central_index();
}
```

### Survey Completion Display

**MUST use the exact template from `output-templates.md#survey-completion`.** Do not reformat, add tables, add emoji, or alter the structure. The template is a contract — reproduce it character-for-character, substituting only the documented `{variable}` placeholders.

Key variable mappings for this workflow:
- `{project_size.conversations}` → `project_size.conversations` (from S2)
- `{project_size.source_files}` → `project_size.source_files` (from S2)
- `{d.*}` → iterate `domain_scores.filter(d => d.signal !== 'none')` (from S3)
- `{d.signal}` → classification string: one of `strong`, `moderate`, `weak` (from S3 thresholds)
- `{d.score}` → use `d.score.toFixed(1)` to ensure 1 decimal place
- `{dive.*}` → iterate `suggested_dives` (from S5)
- `{domains_with_signal[0].id}` → first domain with signal (from S3)
- `{PROJECT_SLUG}` → from S1

### Survey Completion Criteria

Survey run is complete when:
- [ ] Registry loaded and all active domains enumerated
- [ ] Size check performed (sequential vs batched determined)
- [ ] All domains scored with signal/confidence/rationale
- [ ] S3.5 discovery ran (or noted skip reason) when discovery_enabled
- [ ] Discovered signals table present in survey.md (or skip note)
- [ ] Signal ceiling enforced: no discovered signal exceeds 'moderate'
- [ ] Project profile generated (languages, sessions, frameworks)
- [ ] Unknown detection completed (tool frequency + LLM sampling)
- [ ] `survey.md` written to `.claude/archaeology/`
- [ ] `survey-candidates.json` written alongside survey.md
- [ ] Local `INDEX.md` updated with survey link
- [ ] **(Unless --no-export)** `survey.md` exported to central work-log
- [ ] **(Unless --no-export)** `survey-candidates.json` exported to central work-log
- [ ] **(Unless --no-export)** Central `INDEX.md` updated
- [ ] Completion summary displayed with file locations and next step
