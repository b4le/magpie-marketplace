# Survey Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full survey workflow (Steps S1-S7).
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

// Log project size for rationale generation
project_size = {
  conversations: conversation_files.length,
  source_files: source_files.length,
  is_large: LARGE_PROJECT
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

// Scoring strategy depends on project size (determined in S2)
// For LARGE_PROJECT: batch conversation_files into slices of ~10,
// spawn sub-agents per S2 batching prompt, aggregate returned counts.
// For normal projects: use sequential per-file counting loop below.
//
// The batching path uses the same scoring formula — only the file scanning
// differs. Sub-agents return { keyword: count } JSON, which feeds into
// primary_score/secondary_score the same way. Sub-agents MUST use the
// jq filter (see batching prompt update in S2).

if (LARGE_PROJECT) {
  // Batch files into slices and spawn counting sub-agents
  // Each sub-agent uses the prompt template from S2
  // Sub-agent prompt MUST include: "For each file, run:
  //   jq -r -f ${JQ_FILTER_PATH} <file> | grep -oi '\b<keyword>\b' | wc -l"
  // Aggregate returned counts into primary_score, secondary_score, session_set
  // Then continue with scoring below
}

// Per-keyword-per-session caps prevent any single keyword from dominating.
// Even with tool_result exclusion in the jq filter, assistant text can still
// contain long quoted code blocks or file content summaries.
PRIMARY_CAP_PER_SESSION = 5;
SECONDARY_CAP_PER_SESSION = 3;

// Score each domain
domain_scores = [];
for (domain of all_domains) {
  // Load domain definition to get full keyword lists
  domain_def = Read(`${SKILL_DIR}/references/domains/${domain.file}`);
  keywords = parse_frontmatter(domain_def).keywords;

  primary_score = 0;
  secondary_score = 0;
  session_set = new Set();  // Track unique sessions (files) for confidence

  // Count primary keyword hits using jq-filtered content
  // For each file: pipe through jq filter to extract conversation text,
  // then count keyword occurrences in the filtered output.
  // Bash equivalent per file:
  //   jq -r -f $JQ_FILTER_PATH $file 2>/dev/null | grep -oi '\bkeyword\b' | wc -l
  for (keyword of keywords.primary) {
    for (file of conversation_files) {
      count = count_filtered(file, keyword, JQ_FILTER_PATH);
      capped = Math.min(count, PRIMARY_CAP_PER_SESSION);
      primary_score += capped;
      if (count > 0) session_set.add(file);  // each matching file = one session
    }
  }

  // Count secondary keyword hits (same jq-filtered approach)
  for (keyword of keywords.secondary) {
    for (file of conversation_files) {
      count = count_filtered(file, keyword, JQ_FILTER_PATH);
      capped = Math.min(count, SECONDARY_CAP_PER_SESSION);
      secondary_score += capped;
    }
  }

  // Compute weighted score with file-diversity multiplier
  raw_score = (primary_score * 3) + (secondary_score * 1);
  diversity_factor = Math.min(1.5, 1.0 + (session_set.size * 0.1));
  final_score = Math.round(raw_score * diversity_factor * 10) / 10;  // 1 decimal place

  // Classify signal strength
  signal = final_score >= 20 ? 'strong'
         : final_score >= 8  ? 'moderate'
         : final_score >= 2  ? 'weak'
         : 'none';

  // Session-count cap (contract invariant — see Signal Scale below)
  // A single session cannot produce 'strong' signal regardless of score.
  if (session_set.size === 0) signal = 'none';
  else if (session_set.size === 1 && signal === 'strong') signal = 'moderate';

  // Classify confidence based on session spread
  confidence = session_set.size >= 3 ? 'high'
             : session_set.size >= 2 ? 'medium'
             : session_set.size >= 1 ? 'low'
             : '-';

  // Build rationale string for the output table
  rationale = build_rationale(primary_score, secondary_score, session_set.size, keywords);

  domain_scores.push({
    id: domain.id,
    name: domain.name,
    signal: signal,
    confidence: confidence,
    score: final_score,
    sessions: session_set.size,
    rationale: rationale
  });
}

// Sort by score descending
domain_scores.sort((a, b) => b.score - a.score);
```

**`count_filtered()` helper:**

Pipes a single JSONL file through the jq conversation filter, then counts case-insensitive keyword occurrences:

```bash
# count_filtered(file, keyword, jq_filter_path)
# Returns integer count of keyword matches in filtered conversation text
jq -r -f "$jq_filter_path" "$file" 2>/dev/null | grep -oi "\b${keyword}\b" | wc -l
```

**`build_rationale()` function:**

Generate a concise human-readable explanation. Examples:
- "14 primary hits across 5 sessions"
- "6 pytest refs in 2 sessions"
- "1 CLAUDE.md edit found"
- "No matching keywords detected"

```javascript
function build_rationale(primary_count, secondary_count, session_count, keywords) {
  if (primary_count === 0 && secondary_count === 0) {
    return "No matching keywords detected";
  }

  parts = [];
  if (primary_count > 0) {
    parts.push(`${primary_count} primary keyword hit${primary_count > 1 ? 's' : ''}`);
  }
  if (secondary_count > 0) {
    parts.push(`${secondary_count} secondary hit${secondary_count > 1 ? 's' : ''}`);
  }

  session_info = session_count > 0 ? ` across ${session_count} session${session_count > 1 ? 's' : ''}` : '';
  return parts.join(', ') + session_info;
}
```

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

### Survey Step S4: Project Profiling (Phase 2)

Characterize the project based on source files and session metadata:

```javascript
// File extension counting for language breakdown
extensions = {};
for (file of source_files) {
  ext = path.extname(file);
  if (ext && ext !== '') {
    extensions[ext] = (extensions[ext] || 0) + 1;
  }
}
total_source = source_files.length;

// Map extensions to language names and compute percentages
EXT_TO_LANG = {
  '.py': 'Python', '.js': 'JavaScript', '.ts': 'TypeScript', '.tsx': 'TypeScript',
  '.jsx': 'JavaScript', '.java': 'Java', '.go': 'Go', '.rs': 'Rust',
  '.rb': 'Ruby', '.sh': 'Shell', '.bash': 'Shell', '.zsh': 'Shell',
  '.yaml': 'YAML', '.yml': 'YAML', '.json': 'JSON', '.md': 'Markdown',
  '.html': 'HTML', '.css': 'CSS', '.scss': 'SCSS', '.sql': 'SQL',
  '.swift': 'Swift', '.kt': 'Kotlin', '.c': 'C', '.cpp': 'C++',
  '.h': 'C/C++ Header', '.toml': 'TOML', '.ini': 'INI', '.cfg': 'Config',
  '.xml': 'XML', '.proto': 'Protobuf', '.graphql': 'GraphQL'
};

// Aggregate by language (not extension) and sort by count
lang_counts = {};
for ([ext, count] of Object.entries(extensions)) {
  lang = EXT_TO_LANG[ext] || ext;
  lang_counts[lang] = (lang_counts[lang] || 0) + count;
}

language_breakdown = Object.entries(lang_counts)
  .sort((a, b) => b[1] - a[1])
  .slice(0, 5)  // Top 5 languages
  .map(([lang, count]) => `${lang} (${Math.round(count / total_source * 100)}%)`)
  .join(', ');

// Session metadata from conversation files
session_count = conversation_files.length;
// Get file modification times for date range
// Use: stat -f %m <file> on macOS to get mtime
session_dates = conversation_files.map(f => stat(f).mtime).sort();
if (session_dates.length > 0) {
  earliest = format_date(session_dates[0]);
  latest = format_date(session_dates[session_dates.length - 1]);
  history_depth = `${earliest} → ${latest}`;
} else {
  history_depth = 'No session history found';
}

// Framework/tool detection from well-known config files
FRAMEWORK_INDICATORS = {
  'package.json': 'Node.js',
  'requirements.txt': 'Python (pip)',
  'pyproject.toml': 'Python (modern)',
  'Cargo.toml': 'Rust',
  'go.mod': 'Go',
  'Gemfile': 'Ruby',
  'pom.xml': 'Java (Maven)',
  'build.gradle': 'Java (Gradle)',
  'docker-compose.yml': 'Docker',
  'Dockerfile': 'Docker',
  '.github/workflows': 'GitHub Actions',
  'Makefile': 'Make',
  'tsconfig.json': 'TypeScript',
  'jest.config': 'Jest',
  'pytest.ini': 'pytest',
  'setup.cfg': 'Python (setuptools)',
  '.pre-commit-config.yaml': 'pre-commit'
};

detected_frameworks = [];
for ([indicator, framework] of Object.entries(FRAMEWORK_INDICATORS)) {
  matches = Glob(`${PROJECT_ROOT}/${indicator}*`);
  if (matches.length > 0) {
    detected_frameworks.push(framework);
  }
}

project_profile = {
  languages: language_breakdown,
  session_count: session_count,
  history_depth: history_depth,
  source_file_count: total_source,
  frameworks: [...new Set(detected_frameworks)]  // Deduplicate
};
```

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

### Survey Step S7: Export to Central Work-Log

**Skip this step if `--no-export` flag was provided.**

```javascript
if (NO_EXPORT) {
  console.log("Skipping export (--no-export flag)");
  // Jump to completion display
} else {
  // Write survey.md to central location
  Write(`${CENTRAL_PROJECT_DIR}/survey.md`, survey_content);
  console.log(`Exported to: ${CENTRAL_PROJECT_DIR}/survey.md`);

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
- [ ] Project profile generated (languages, sessions, frameworks)
- [ ] Unknown detection completed (tool frequency + LLM sampling)
- [ ] `survey.md` written to `.claude/archaeology/`
- [ ] Local `INDEX.md` updated with survey link
- [ ] **(Unless --no-export)** `survey.md` exported to central work-log
- [ ] **(Unless --no-export)** Central `INDEX.md` updated
- [ ] Completion summary displayed with file locations and next step
