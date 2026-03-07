# Survey Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add survey mode as the default entry point for `/archaeology` (no args) — scans a project, scores domain signal strength, detects unknowns, produces a consistent `survey.md`.

**Architecture:** Survey is a new code path inline in SKILL.md, branching before the existing domain workflow. It reads all domain definitions from registry.yaml, runs a 4-phase sequential scan (size check → keyword scoring → project profiling → unknown detection), and writes `survey.md` to both local and central locations.

**Tech Stack:** SKILL.md (skill definition language), YAML (registry), Markdown (output template)

**Design doc:** `docs/plans/2026-03-04-survey-mode-design.md`

---

### Task 1: Update SKILL.md Frontmatter and Invocation Patterns

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md:1-24`

**Step 1: Update frontmatter argument-hint**

In SKILL.md line 4, change:
```yaml
argument-hint: "[domain|list] [project-name] [--no-export]"
```
to:
```yaml
argument-hint: "[survey|domain|list] [project-name] [--no-export]"
```

**Step 2: Update Invocation Patterns section**

Replace the existing Invocation Patterns block (lines 13-18) with:
```bash
/archaeology                            # Survey mode (default) — scan project, score domains
/archaeology survey                     # Explicit survey mode
/archaeology list                       # Show available domains
/archaeology {domain}                   # Extract + export (uses current directory)
/archaeology {domain} "Project Name"    # Specify target project explicitly
/archaeology {domain} --no-export       # Extract only, skip export to central work-log
```

**Step 3: Update Available Commands section**

Replace lines 22-23 with:
```markdown
## Available Commands

- **survey** (default) - Scan project, score domain signal strength, suggest next steps
- **list** - Display all domains with their status and description
- **{domain}** - Run extraction for specified domain (orchestration, prompting-patterns, python-practices, git-workflows)
```

**Step 4: Verify changes read correctly**

Read SKILL.md lines 1-30 and confirm the frontmatter, invocation patterns, and available commands are correct.

**Step 5: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): update invocation patterns for survey mode"
```

---

### Task 2: Add Survey Routing Logic to SKILL.md

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md:25-27` (insert before "### Step 1: Resolve Project Context")

**Step 1: Insert Survey Mode routing section**

Insert the following new section between "## Execution Workflow" (line 25) and "### Step 1: Resolve Project Context" (line 27):

```markdown
### Survey Mode Routing

When invoked with no arguments or `survey`, branch to survey workflow:

\`\`\`javascript
// Parse command and flags
args = parse_arguments(user_input);
NO_EXPORT = args.includes('--no-export');

if (args.command === 'list') {
  list_domains();
  return;
}

if (args.command === undefined || args.command === 'survey') {
  // Branch to Survey workflow (see "Survey Workflow" section below)
  execute_survey(args);
  return;
}

// Otherwise: continue to Step 1 (domain extraction workflow)
\`\`\`
```

**Step 2: Verify the routing section sits before Step 1**

Read SKILL.md and confirm "Survey Mode Routing" appears between "## Execution Workflow" and "### Step 1: Resolve Project Context".

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey routing before domain workflow"
```

---

### Task 3: Add Survey Workflow — Project Context and Size Check (Survey Steps S1-S2)

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (insert before "## Adding New Domains" near the bottom)

**Step 1: Insert Survey Workflow section**

Add the following new section before "## Adding New Domains" (currently line 498):

````markdown
## Survey Workflow

When survey mode is triggered, execute these steps instead of the domain extraction workflow (Steps 1-5).

### Survey Step S1: Resolve Project Context

Reuses the same project resolution logic as domain extraction Step 1, but without domain-specific paths:

```javascript
NO_EXPORT = args.includes('--no-export');

// Project resolution (same logic as Step 1)
if (user_provided_project_name) {
  PROJECT_NAME = user_provided_project_name;
  PROJECT_PATH_PATTERN = `**/${PROJECT_NAME}/**`;
  matching_paths = Glob(pattern: PROJECT_PATH_PATTERN, path: ~/Developer);
  if (matching_paths.length === 0) {
    error("Project not found in ~/Developer");
  }
  PROJECT_ROOT = matching_paths[0];
} else {
  PROJECT_ROOT = cwd;
  PROJECT_NAME = basename(PROJECT_ROOT);
}

PROJECT_SLUG = PROJECT_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
ARCHAEOLOGY_DIR = `${PROJECT_ROOT}/.claude/archaeology`;

// Central work-log location (survey.md lives at project level, not domain level)
CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
CENTRAL_PROJECT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;

// Conversation history location
HISTORY_DIR = `~/.claude/projects/-Users-*-${PROJECT_PATH_PATTERN}/`;
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
````

**Step 2: Verify the Survey Workflow section is correctly placed**

Read the end of SKILL.md and confirm "## Survey Workflow" appears before "## Adding New Domains".

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey steps S1-S2 (project context, size check)"
```

---

### Task 4: Add Survey Phase 1 — Domain Keyword Scoring (Survey Step S3)

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (append after Survey Step S2)

**Step 1: Add Survey Step S3 section**

Insert after Survey Step S2:

````markdown
### Survey Step S3: Domain Keyword Scoring (Phase 1)

Load all domains from registry and score each against conversation history:

```javascript
// Read registry
REGISTRY_PATH = `~/.claude/skills/archaeology/references/domains/registry.yaml`;
registry = Read(REGISTRY_PATH);
all_domains = parse_yaml(registry).domains.filter(d => d.status === 'active');

// Score each domain
domain_scores = [];
for (domain of all_domains) {
  // Load domain definition to get full keyword lists
  domain_def = Read(`~/.claude/skills/archaeology/references/domains/${domain.file}`);
  keywords = parse_frontmatter(domain_def).keywords;

  primary_score = 0;
  secondary_score = 0;
  session_set = new Set();  // Track unique sessions (files) for confidence

  // Count primary keyword hits
  for (keyword of keywords.primary) {
    results = Grep(pattern: keyword, path: HISTORY_DIR, glob: "*.jsonl", output_mode: "count");
    primary_score += results.total_count;
    // Each file with a match = one session
    session_set.add(...results.matching_files);
  }

  // Count secondary keyword hits
  for (keyword of keywords.secondary) {
    results = Grep(pattern: keyword, path: HISTORY_DIR, glob: "*.jsonl", output_mode: "count");
    secondary_score += results.total_count;
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

| Signal | Threshold | Meaning |
|--------|-----------|---------|
| strong | score >= 20 | High-value domain, run extraction first |
| moderate | score >= 8 | Worth investigating, likely has findings |
| weak | score >= 2 | Minimal signal, may yield 1-2 findings |
| none | score < 2 | No evidence found |

#### Confidence Scale (Contract — do not change between versions)

| Confidence | Criterion | Meaning |
|------------|-----------|---------|
| high | 3+ distinct sessions | Broad pattern across usage |
| medium | 2 sessions | Some evidence but limited |
| low | 1 session | Single occurrence, may be one-off |
| - | 0 sessions | No signal |
````

**Step 2: Verify the scoring section is complete**

Read the new section and confirm the scoring formula, thresholds, and rationale builder are present.

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey step S3 (domain keyword scoring)"
```

---

### Task 5: Add Survey Phase 2 — Project Profiling (Survey Step S4)

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (append after Survey Step S3)

**Step 1: Add Survey Step S4 section**

Insert after Survey Step S3:

````markdown
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
````

**Step 2: Verify project profiling section is complete**

Read the new section and confirm extension mapping, session metadata, and framework detection are present.

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey step S4 (project profiling)"
```

---

### Task 6: Add Survey Phase 3 — Unknown Detection (Survey Step S5)

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (append after Survey Step S4)

**Step 1: Add Survey Step S5 section**

Insert after Survey Step S4:

````markdown
### Survey Step S5: Unknown Detection (Phase 3)

Identify high-frequency tools/patterns not covered by any existing domain. Two-step: concrete frequency analysis, then targeted LLM sampling for top unknowns.

**Step 1 — Tool frequency extraction:**

```javascript
// Extract tool call names from conversation JSONL
// Pattern matches: "name":"ToolName" in JSONL content
tool_results = Grep(
  pattern: '"name":"[A-Za-z_]+"',
  path: HISTORY_DIR,
  glob: "*.jsonl",
  output_mode: "content"
);

// Count occurrences of each tool name
tool_counts = {};
for (match of tool_results) {
  // Extract tool name from match like "name":"Read"
  tool_name = match.match(/"name":"([A-Za-z_]+)"/)?.[1];
  if (tool_name) {
    tool_counts[tool_name] = (tool_counts[tool_name] || 0) + 1;
  }
}
```

**Step 2 — Filter to uncovered tools:**

```javascript
// Collect all keywords from all domains
all_domain_keywords = [];
for (domain of all_domains) {
  domain_def = Read(`~/.claude/skills/archaeology/references/domains/${domain.file}`);
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

Output format:
THEME: [theme name]
SUMMARY: [one sentence]`
  });

  // Parse agent response
  theme = extract_after(agent_result, 'THEME:').trim();
  summary = extract_after(agent_result, 'SUMMARY:').trim();

  suggested_dives.push({
    theme: theme || `${tool_name} usage`,
    evidence: `${count} references to ${tool_name} not covered by existing domains`,
    description: summary || `Frequent use of ${tool_name} detected`
  });
}
```

If `LARGE_PROJECT` is true, skip the LLM sampling step (Step 3) and use the tool name directly as the theme to avoid additional context consumption.
````

**Step 2: Verify unknown detection section is complete**

Read the new section and confirm all three steps (extraction, filtering, LLM sampling) are present.

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey step S5 (unknown detection)"
```

---

### Task 7: Add Survey Output Generation and Export (Survey Steps S6-S7)

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (append after Survey Step S5)

**Step 1: Add Survey Steps S6 and S7**

Insert after Survey Step S5:

````markdown
### Survey Step S6: Generate survey.md

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

// Assemble survey.md content
survey_content = `# Archaeology Survey — ${PROJECT_NAME}

> Scanned on ${current_date()} | ${project_size.conversations} conversation files | ${project_size.source_files} source files

## Recommended Domains

| Domain | Signal | Confidence | Score | Rationale |
|--------|--------|------------|-------|-----------|
${domain_table_rows}

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
function update_local_archaeology_index() {
  INDEX_PATH = `${ARCHAEOLOGY_DIR}/INDEX.md`;

  // Check if survey exists
  has_survey = exists(`${ARCHAEOLOGY_DIR}/survey.md`);

  // Find all domain directories
  domain_dirs = Glob(pattern: `${ARCHAEOLOGY_DIR}/*/README.md`)
    .map(f => dirname(f).split('/').pop())
    .filter(d => d !== '.work');

  index_content = `# Archaeology Index

${has_survey ? '## Survey\n- [survey.md](./survey.md) — Project survey and domain recommendations\n\n' : ''}## Domains extracted:

${domain_dirs.length > 0
  ? domain_dirs.map(d => `- [${d}/](./${d}/) — Extracted patterns`).join('\n')
  : '_No domains extracted yet. Run survey recommendations above._'}

Last updated: ${current_date()}
`;

  Write(INDEX_PATH, index_content);
  console.log(`Updated: ${INDEX_PATH}`);
}

update_local_archaeology_index();
```

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

```
Archaeology Survey Complete

Scanned {N} conversations, {M} source files

Domains with signal:
  {domain}    {signal}  (score: {score}, {sessions} sessions)
  ...

Suggested deep dives:
  {theme} — {evidence}
  ...

Local:   .claude/archaeology/survey.md
         .claude/archaeology/INDEX.md
Central: ~/.claude/data/visibility-toolkit/work-log/archaeology/{slug}/survey.md

Next: /archaeology {top-domain}
```

**If --no-export:**
```
Archaeology Survey Complete (export skipped)

Scanned {N} conversations, {M} source files
[same domain/dive info]

Local: .claude/archaeology/survey.md
Next: /archaeology {top-domain}
```

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
````

**Step 2: Verify the output generation and export sections are complete**

Read the full Survey Workflow section end-to-end and confirm Steps S6-S7 plus completion criteria are present.

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): add survey steps S6-S7 (output generation, export, completion)"
```

---

### Task 8: Update ADDING-DOMAINS.md with Survey Cross-Reference

**Files:**
- Modify: `~/.claude/skills/archaeology/references/domains/ADDING-DOMAINS.md:67-70`

**Step 1: Add survey tip to "Choose Domain Scope" section**

After the "Choose Domain Scope" bullet points (line 70), add:

```markdown
**Tip:** Run `/archaeology` (survey mode) first to see if your proposed domain has signal in the project. Survey auto-detects high-frequency tools/patterns not covered by existing domains and suggests them as "deep dive" candidates.
```

**Step 2: Add survey mention to Domain Lifecycle section**

After "3. **Deprecated** — Replaced by newer domain, kept for reference" (line 143), add:

```markdown

## Discovering New Domains

Use survey mode (`/archaeology` with no arguments) to discover potential new domains. Survey scans conversation history for high-frequency tools and patterns not covered by existing domains, and lists them under "Suggested Deep Dives" in the output. If a suggested theme appears consistently across projects, it's a strong candidate for a new domain.
```

**Step 3: Verify changes**

Read ADDING-DOMAINS.md and confirm both additions are correctly placed and read naturally.

**Step 4: Commit**

```bash
git add ~/.claude/skills/archaeology/references/domains/ADDING-DOMAINS.md
git commit -m "docs(archaeology): add survey cross-references to ADDING-DOMAINS.md"
```

---

### Task 9: Update Existing Completion Criteria and INDEX.md Function

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md` (the existing `update_local_archaeology_index` function around line 227)

**Step 1: Update existing INDEX.md function**

The existing `update_local_archaeology_index()` function (in Step 4) needs to be aware of survey.md. Replace the existing function body with one that checks for survey.md:

Find:
```javascript
  // Generate index content
  index_content = `# Archaeology Index

Domains extracted for this project:

${domain_dirs.map(d => `- [${d}/](./${d}/) - Extracted patterns`).join('\n')}

Last updated: ${current_date()}
`;
```

Replace with:
```javascript
  // Check if survey exists
  has_survey = exists(`${ARCHAEOLOGY_DIR}/survey.md`);

  // Generate index content
  index_content = `# Archaeology Index

${has_survey ? '## Survey\n- [survey.md](./survey.md) — Project survey and domain recommendations\n\n' : ''}## Domains extracted:

${domain_dirs.length > 0
  ? domain_dirs.map(d => `- [${d}/](./${d}/) — Extracted patterns`).join('\n')
  : '_No domains extracted yet._'}

Last updated: ${current_date()}
`;
```

**Step 2: Verify the updated function**

Read the modified function and confirm it handles both survey-present and survey-absent cases.

**Step 3: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "fix(archaeology): make INDEX.md function survey-aware"
```

---

### Task 10: Update Restructure Todos Memory File

**Files:**
- Modify: `~/.claude/projects/-Users-benpurslow/memory/archaeology-restructure-todos.md`

**Step 1: Move survey from "Future" to "Done"**

In the restructure todos, move the Survey entry from "Future: Invocation Modes" to "Done", marking it complete. Update the "In Progress: Testing" section to add survey testing tasks.

Add to Done section:
```markdown
- [x] Survey mode implemented — `/archaeology` (no args) scans project, scores domains, detects unknowns
```

Add to Testing section:
```markdown
- [ ] **Survey test (strong signal)** — run `/archaeology` on a project with known orchestration/python usage. Verify domain scores, rationale text, project profile, and output format.
- [ ] **Survey test (weak signal)** — run `/archaeology` on a minimal/config-only project. Verify all domains show `none` signal, no false positives.
- [ ] **Survey test (--no-export)** — run `/archaeology --no-export` and verify central export is skipped.
- [ ] **Survey format stability** — compare survey.md from two different projects, verify identical table structure.
```

**Step 2: Commit**

```bash
git add ~/.claude/projects/-Users-benpurslow/memory/archaeology-restructure-todos.md
git commit -m "docs: update archaeology restructure todos with survey progress"
```

---

## Parallelisation Strategy

```
Tasks 1-7: Sequential (SKILL.md — single file, each task builds on previous)
Task 8:    Independent (ADDING-DOMAINS.md — can run parallel with Tasks 1-7)
Task 9:    After Task 7 (modifies existing SKILL.md function, needs survey context)
Task 10:   Independent (memory file — can run parallel)
```

**Practical parallel split:**
- **Agent 1** (SKILL.md owner): Tasks 1, 2, 3, 4, 5, 6, 7, 9
- **Agent 2** (docs owner): Tasks 8, 10

---

## Testing Plan (Post-Implementation)

After all tasks complete, test on 2+ projects:

1. **Strong signal project** (e.g., one with heavy orchestration + Python):
   - Run `/archaeology` → verify survey.md has strong/moderate signals
   - Check rationale text is human-readable
   - Verify project profile detects correct languages and frameworks
   - Run `/archaeology {recommended-domain}` → verify extraction finds what survey predicted

2. **Weak/no signal project** (e.g., a simple config repo):
   - Run `/archaeology` → verify all domains show `none` or `weak`
   - Verify "Suggested Deep Dives" section is empty or shows generic tools

3. **Format stability check**:
   - Compare survey.md from both projects
   - Table structure (headers, columns) must be identical
   - Only data values should differ

4. **Flag testing**:
   - Run `/archaeology --no-export` → verify no central output
   - Run `/archaeology survey` → verify explicit survey invocation works same as no-args
