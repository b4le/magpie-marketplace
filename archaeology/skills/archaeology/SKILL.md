---
name: archaeology
description: Use when the user says "archaeology", "survey", "workstyle", "how do I work with Claude", "my working style", "excavation", "survey all projects", "portfolio view", "scan all projects", "mine my history", "extract patterns", "scan my history", "what domains", "conserve", "preserve artifacts", "narrative extraction", "tell the story", "project story", "deep dive into", "investigate my history", or "dig". Analyzes past Claude Code sessions to surface reusable patterns, extract learnings from usage history, and conserve narrative artifacts across multiple knowledge domains.
argument-hint: "[survey|workstyle|conserve|dig|excavation|{domain}|list] [project-name] [--no-export] [--global]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Agent
version: 1.4.0
last_updated: 2026-03-09
---

# Archaeology Skill

Extract and document patterns from Claude Code usage history across multiple knowledge domains. Automatically exports structured findings to the central work-log.

## Invocation Patterns

```bash
/archaeology                            # Survey mode (default) — scan project, score domains
/archaeology survey                     # Explicit survey mode
/archaeology survey "Project Name"        # Survey a specific project
/archaeology survey --no-export           # Survey without exporting to central work-log
/archaeology survey "Project Name" --no-export  # Survey specific project, local only
/archaeology list                       # Show available domains
/archaeology {domain}                   # Extract + export (uses current directory)
/archaeology {domain} "Project Name"    # Specify target project explicitly
/archaeology {domain} --no-export       # Extract only, skip export to central work-log
/archaeology workstyle                    # Workstyle for current project
/archaeology workstyle "Project Name"     # Workstyle for specific project
/archaeology workstyle --global           # Aggregate across all projects
/archaeology workstyle --no-export        # Skip export to central work-log
/archaeology conserve                     # Conserve artifacts for current project
/archaeology conserve "Project Name"      # Conserve artifacts for specific project
/archaeology conserve --no-export         # Conserve locally only, skip central work-log
/archaeology excavation                # Excavation mode — survey all projects, generate portfolio
/archaeology excavation --dry-run      # Show what would be surveyed without running
/archaeology excavation --max-concurrent 5  # Override parallel limit (default: 3)
/archaeology excavation --scan-paths "~/Work,~/Side"  # Override scan directories
/archaeology excavation --max-age 14   # Skip surveys fresher than 14 days (default: 7)
/archaeology dig "subject"          # Deep investigation of a specific subject
/archaeology dig "subject" --fresh  # Discard existing state, start over
/archaeology dig "subject" --done   # Export findings and mark dig complete
/archaeology dig "subject" --export # Export current state without marking complete
/archaeology dig list               # Show all in-progress and completed digs
```

## Available Commands

- **survey** (default) - Scan project, score domain signal strength, suggest next steps
- **list** - Display available commands and domains with status and description
- **workstyle** - Analyse working style with Claude (tool usage, session shapes, delegation, communication patterns)
- **conserve** - Extract narrative artifacts from project history, generate default exhibition
- **dig** - Deep investigation of a specific subject across project history
- **{domain}** - Run extraction for specified domain (orchestration, prompting-patterns, python-practices, git-workflows)
- **excavation** - Cross-project portfolio scan: discover projects, survey each, generate portfolio report

## Execution Workflow

### Path Resolution

All paths in this skill and its referenced workflows resolve against these two base variables. Set them once before any command routing. Sub-agents that receive prompts from this skill must receive these as explicit context — they cannot infer the skill directory.

```javascript
// The directory containing this SKILL.md file (follows symlink)
SKILL_DIR = '~/.claude/skills/archaeology';
// The plugin root — two levels up from the skill dir (skills/archaeology/ → archaeology/)
// Resolve via: realpath(SKILL_DIR + '/../..')
PLUGIN_ROOT = realpath(`${SKILL_DIR}/../..`);
```

### Init Banner

Before command routing, display the branded init banner. Read the branding spec from `${SKILL_DIR}/references/branding.md` for the full design language.

```javascript
// Resolve mode label for banner
mode_label = args.command || 'survey';
project_label = user_provided_project_name || basename(cwd);

// Display init banner (see references/branding.md)
// Resolve sigil from branding (references/branding.md)
SIGILS = { survey: '◈', extraction: '◆', workstyle: '●', conserve: '◇', excavation: '✦', dig: '▼', list: '◈' };
sigil = SIGILS[mode_label] || '◈';

// Spaced-letter mode name (mirrors logo rhythm)
spaced_mode = mode_label.toUpperCase().split('').join(' ');

// Mode line: MODE  sigil  project (or just MODE  sigil if no project)
mode_line = project_label && mode_label !== 'list'
  ? `${spaced_mode}  ${sigil}  ${project_label}`
  : `${spaced_mode}  ${sigil}`;

// Display init banner (see references/branding.md)
print(`
░░░▒▒▒▓▓▓███▓▓▓▒▒▒░░░
A R C H A E O L O G Y
·· extract · conserve · preserve

${mode_line}
`);
```

### Command Routing

When invoked with no arguments or `survey`, branch to survey workflow:

```javascript
// Parse command and flags
args = parse_arguments(user_input);

if (args.command === 'list') {
  // Display init banner first, then list output.
  // List output format:
  //
  // ## Commands
  // | Command | Description |
  // |---------|-------------|
  // | survey | Scan project, score domain signal strength, suggest next steps |
  // | list | Display available commands and domains |
  // | ... | ... |
  //
  // ## Domains
  // | Domain | Status | Description |
  // |--------|--------|-------------|
  // | orchestration | active | Agent orchestration patterns... |
  //
  // IMPORTANT: Do NOT put sigils in the domains table — they are for mode states only.
  list_domains();
  return;
}

if (args.command === 'workstyle') {
  // Branch to Workstyle workflow (see references/workstyle-workflow.md)
  execute_workstyle(args);
  return;
}

if (args.command === 'conserve') {
  // Branch to Conservation workflow (see references/conserve-workflow.md)
  execute_conserve(args);
  return;
}

if (args.command === 'dig') {
  if (!args.subject) error("dig requires a subject: /archaeology dig \"subject\"");
  // Branch to Dig workflow (see references/dig-workflow.md)
  execute_dig(args);
  return;
}

if (args.command === 'excavation') {
  // Branch to Excavation workflow (see references/excavation-workflow.md)
  execute_excavation(args);
  return;
}

if (args.command === undefined || args.command === 'survey') {
  // Branch to Survey workflow (see references/survey-workflow.md)
  execute_survey(args);
  return;
}

// Otherwise: continue to Step 1 (domain extraction workflow)
```

### Step 1: Resolve Project Context

```javascript
NO_EXPORT = args.includes('--no-export');

if (user_provided_project_name) {
  PROJECT_NAME = user_provided_project_name;
  PROJECT_PATH_PATTERN = `**/${PROJECT_NAME}/**`;
  matching_paths = Glob(pattern: PROJECT_PATH_PATTERN, path: ~/Developer);
  if (matching_paths.length === 0) error("Project not found in ~/Developer");
  PROJECT_ROOT = matching_paths[0];
} else {
  PROJECT_ROOT = cwd;
  PROJECT_NAME = basename(PROJECT_ROOT);
}

PROJECT_SLUG = PROJECT_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
ARCHAEOLOGY_DIR = `${PROJECT_ROOT}/.claude/archaeology`;
DOMAIN_OUTPUT_DIR = `${ARCHAEOLOGY_DIR}/${domain}`;
WORK_DIR = `${ARCHAEOLOGY_DIR}/.work`;
CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
CENTRAL_OUTPUT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}/${domain}`;
```

Create directories and `.gitignore` (if not exists):
```bash
mkdir -p ${WORK_DIR}/extraction ${DOMAIN_OUTPUT_DIR}
if (!NO_EXPORT) mkdir -p ${CENTRAL_OUTPUT_DIR}
# Write .gitignore with ".work/" if ${ARCHAEOLOGY_DIR}/.gitignore doesn't exist
```

### Step 2: Load Domain Definition

```javascript
DOMAIN_FILE = `${SKILL_DIR}/references/domains/${domain}.md`;
domain_spec = Read(DOMAIN_FILE);
domain_config = parse_frontmatter(domain_spec);

if (!domain_spec) { list_domains(); error(`Domain '${domain}' not found.`); }
if (domain_config.status !== 'active') error(`Domain '${domain}' is not active.`);

// Extract config (see SCHEMA.md for field definitions)
KEYWORDS_PRIMARY = domain_config.keywords.primary;
KEYWORDS_SECONDARY = domain_config.keywords.secondary;
KEYWORDS_EXCLUSION = domain_config.keywords.exclusion;
AGENT_COUNT = domain_config.agent_count;
LOCATIONS = domain_config.locations;
OUTPUTS = domain_config.outputs;
```

#### Step 2 Verification
Before proceeding: confirm `DOMAIN_FILE` was read and `domain_config.status === 'active'`. Hard stop if domain file is missing or status is not active — do not launch agents against an undefined domain spec. Review: does the loaded domain's `KEYWORDS_PRIMARY` match the user's intent? If the domain spec looks mismatched (e.g., user said "orchestration" but the keywords are unrelated), flag it before burning agent calls.

### Step 3: Parallel Search

Launch `AGENT_COUNT` Explore agents. Each searches `LOCATIONS` using domain keywords and writes findings to `${WORK_DIR}/extraction/${domain}-agent-{N}-findings.md`.

> **Agent output convention:** If customising the agent prompt below, follow the format rules in `references/conversation-parser.md#agent-output-format-convention`.

**Agent prompt template:**
```
You are exploring Claude Code history for ${domain} patterns.
PROJECT: ${PROJECT_NAME}
SEARCH LOCATIONS: ${LOCATIONS}
PRIMARY KEYWORDS (must match): ${KEYWORDS_PRIMARY}
SECONDARY KEYWORDS (boost): ${KEYWORDS_SECONDARY}
EXCLUDE: ${KEYWORDS_EXCLUSION}

Search with Grep, focus on successful patterns, capture context.

OUTPUT FORMAT per finding:
## Finding: [Brief Description]
**Context:** [When/where used]
**Pattern:** [What makes this notable]
**Example:** [code block]

Write findings to: ${output_file}
```

Wait for all agents to complete.

#### Step 3 Verification
Before proceeding: confirm all `AGENT_COUNT` agent output files exist at `${WORK_DIR}/extraction/${domain}-agent-*-findings.md`. Hard stop if zero files were written — all agents failed silently. If fewer than `AGENT_COUNT` files exist, continue with what's available but warn the user. Review: do the findings files contain at least one `## Finding:` block? If every agent returned empty output, stop and report rather than synthesizing an empty document.

### Step 4: Synthesize & Output

```javascript
extraction_files = Glob(pattern: `${WORK_DIR}/extraction/${domain}-agent-*-findings.md`);
all_findings = extraction_files.map(f => Read(f)).join('\n\n---\n\n');

// Generate each output file from domain config with frontmatter (see references/output-templates.md#frontmatter)
for (output of OUTPUTS) {
  content = synthesize_findings(all_findings, output.template);
  Write(`${DOMAIN_OUTPUT_DIR}/${output.file}`, frontmatter + content);
}

// Update local INDEX.md (canonical impl: references/survey-workflow.md)
update_local_archaeology_index();
```

#### Step 4 Verification
Before proceeding to export: confirm all expected output files were written to `${DOMAIN_OUTPUT_DIR}/`. Hard stop if any `OUTPUTS` file is missing — do not export an incomplete run. Review: does the synthesized output address the domain's stated extraction goal? If the synthesis document contains only one finding or is under 200 words, flag as potentially thin before exporting to the central work-log.

### Step 4b: Parse Findings for Export

Parse each `## Finding:` block from agent output into structured objects:

```javascript
all_findings_parsed = [];
for (extraction_file of extraction_files) {
  raw = Read(extraction_file);
  blocks = raw.split(/^## Finding: /m).filter(Boolean);
  for (block of blocks) {
    all_findings_parsed.push({
      title: block.split('\n')[0].trim(),
      description: extract_section(block, 'Pattern'),
      evidence_paths: extract_section(block, 'Context'),
      quotes: extract_code_blocks(block),
      date: extract_date(block) || null
    });
  }
}
```

### Step 5: Export to Central Work-Log

**Skip if `--no-export`.** Each run replaces all outputs for this project/domain combo (no merge).

#### 5a: Build Structured Findings

```javascript
findings_data = {
  project: PROJECT_NAME, domain: domain,
  extracted_at: new Date().toISOString(),
  source_session: git_branch() || session_id(),
  highlights: [],
  findings: all_findings_parsed.map((finding, i) => ({
    id: `f-${String(i + 1).padStart(3, '0')}`,
    type: classify_finding(finding),
    title: finding.title, description: finding.description,
    evidence: finding.evidence_paths || finding.quotes,
    tags: extract_tags(finding, domain),
    date: finding.date || current_date(),
    confidence: score_confidence(finding),
    relevance: score_relevance(finding)
  }))
};

// Highlights: high confidence + high relevance, sorted by type priority, capped at 5
TYPE_PRIORITY = { pattern: 0, decision: 1, artifact: 2, capability: 3 };
findings_data.highlights = findings_data.findings
  .filter(f => f.confidence === 'high' && f.relevance === 'high')
  .sort((a, b) => TYPE_PRIORITY[a.type] - TYPE_PRIORITY[b.type])
  .slice(0, 5).map(f => f.id);
```

**Finding type classification:**

| Type | Criteria |
|------|----------|
| `pattern` | Recurring approach seen in 2+ instances or contexts |
| `decision` | Architectural or design choice with explicit rationale/tradeoff |
| `artifact` | Concrete reusable output (prompt template, config, script) |
| `capability` | Single-use technique or tool usage that solved a specific problem |

**`extract_tags(finding, domain)` logic:** Start with the domain name as the first tag. Add any keywords from `KEYWORDS_PRIMARY` that appear in the finding's description or evidence. Add finding type as final tag.

**`score_confidence(finding)` heuristics:**
- `"high"` — 2+ evidence items AND code block present
- `"medium"` — 1 evidence item OR context-only (no code)
- `"low"` — inferred with weak or no direct evidence

**`score_relevance(finding)` heuristics:**
- `"high"` — type is `pattern` or `decision` with broad applicability
- `"medium"` — useful in specific contexts, or `artifact` type
- `"low"` — one-off `capability` or narrow technique

#### 5b: Write Central Output Files

Write three files to `${CENTRAL_OUTPUT_DIR}/`:

1. **findings.json** — `JSON.stringify(findings_data, null, 2)`
2. **patterns.md** — narrative from `generate_narrative(findings_data)` (structure: `references/output-templates.md#patterns-narrative`)
3. **metadata.json** — run stats: `run_id`, `project`, `project_slug`, `domain`, `timestamp`, `agent_count`, `findings_count`, `finding_types`, `source_files_scanned`, `flags`

**`generate_run_id()` format:** `arch-{YYYYMMDD}-{random-4-hex}`

#### 5c: Update Central INDEX.md

```javascript
// Scan for all outputs under ${CENTRAL_BASE}, group by project:
// - metadata.json at ${CENTRAL_BASE}/${project_slug}/${domain}/metadata.json
// Also check for project-level outputs (not just domain metadata.json):
// - survey.md at ${project_dir}/survey.md
// - workstyle.json at ${project_dir}/workstyle.json
// - workstyle-global.json at ${CENTRAL_BASE}/workstyle-global.json
// Include indicators in INDEX.md project entries: [Survey] [Workstyle] [Domains: N]
```

Scan all `metadata.json` files under `${CENTRAL_BASE}`, group by project. For each project:
- Read SUMMARY.md one-liner (first blockquote) if it exists
- Build table: Domain | Findings | Highlights | Last Run | Path
- Include reading path (Quick scan → Project deep-dive → Domain detail → Programmatic access)

Write to `${CENTRAL_BASE}/INDEX.md`. See `references/consumption-spec.md` for the reading levels.

### Step 6: Project Synthesis

**Skip if `--no-export`.** Generate cross-domain SUMMARY.md (idempotent, concurrency-safe — last writer wins).

1. Scan all `metadata.json` and `findings.json` for this project
2. Merge highlights across domains, sort by type priority (`pattern > decision > artifact > capability`), cap at 7
3. Build tag overlap table (tags in 2+ domains)
4. Read Highlights section from each domain's `patterns.md`
5. Write `${CENTRAL_BASE}/${PROJECT_SLUG}/SUMMARY.md` (structure: `references/output-templates.md#summary`)
6. Re-run `update_central_index()` to pick up the new one-liner

### If No Results Found

If extraction yields no findings:

1. Inform user: "No ${domain} patterns found in project history"
2. Suggest alternatives:
   - Check different project: `/archaeology ${domain} "Other Project"`
   - Try different domain: `/archaeology list` to see options
   - Verify search locations contain conversation history
3. Do NOT create empty output files
4. Do NOT export to central work-log (nothing to export)

## Completion Criteria

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

**Output display format:** MUST use the exact template from `references/output-templates.md#extraction-completion`. Do not reformat, add tables, add emoji, or alter the structure.

## Survey Workflow

When invoked with no arguments or `survey`, execute the survey workflow.

Read and follow the full specification in `${SKILL_DIR}/references/survey-workflow.md`.

Survey produces `survey.md` locally and in the central work-log, then updates INDEX.md files.

## Workstyle Workflow

When invoked with `workstyle`, execute the workstyle workflow.

Read and follow the full specification in `${SKILL_DIR}/references/workstyle-workflow.md`.

Workstyle produces `workstyle.md` and `workstyle.json` locally and in the central work-log, then updates INDEX.md files. Supports `--global` flag for cross-project aggregation.

## Conservation Workflow

When invoked with `conserve`, execute the conservation workflow.

Read and follow the full specification in `${SKILL_DIR}/references/conserve-workflow.md`.

Conservation extracts atomic narrative artifacts from project history, generates a default exhibition, and exports to the central work-log. Produces `exhibition.md`, individual artifact files in `artifacts/`, and updates the global artifacts registry. Supports `--no-export` flag.

## Dig Workflow

When invoked with `dig`, execute the dig workflow.

Read and follow the full specification in `${SKILL_DIR}/references/dig-workflow.md`.

Dig is an interactive, multi-turn investigation mode that drills deep into a specific subject across project history. It dispatches spelunker agents to extract nuggets (discrete findings) and connector agents to identify veins (relationships between findings). State persists across sessions via `cavern-map.json`. Supports `--fresh` (restart), `--done` (export and complete), `--export` (checkpoint export), and `--no-export` flags.

## Excavation Workflow

When invoked with `excavation`, execute the excavation workflow.

Read and follow the full specification in `${SKILL_DIR}/references/excavation-workflow.md`.

Excavation discovers all projects, surveys each via independent subprocesses using `scripts/archaeology-excavation.sh`, and generates a cross-project portfolio report at the central work-log root. The `--no-export` flag is not supported because excavation's purpose is cross-project aggregation to the central work-log.

## Adding New Domains

To add a new domain, create `references/domains/{domain}.md` with required frontmatter.

See `references/domains/ADDING-DOMAINS.md` for specification format and examples.

## Domain Registry

Available domains are registered in `references/domains/registry.yaml`.
