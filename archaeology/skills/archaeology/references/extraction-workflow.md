# Domain Extraction Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full domain extraction pipeline (Steps 1-6).
> Context variables (`SKILL_DIR`, `PLUGIN_ROOT`) are set by SKILL.md Path Resolution before this workflow executes.
> The `domain` variable and `args` (including flags like `--no-export`) are set by SKILL.md command routing before this workflow executes.

## Step 1: Resolve Project Context

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

## Step 2: Load Domain Definition (Tier-Aware)

Three-tier fallback: curated domain file → confirmed registry entry → survey candidate. Existing curated domains load exactly as before; the new tiers provide defaults for domains without full `.md` files.

```javascript
REGISTRY_PATH = `${SKILL_DIR}/references/domains/registry.yaml`;

// System defaults for non-curated domains
DEFAULT_LOCATIONS = [
  {
    path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/",
    purpose: "Conversation history",
    priority: "high"
  },
  {
    path: "~/{PROJECT_ROOT}/",
    purpose: "Project source files",
    priority: "medium"
  }
];

DEFAULT_OUTPUTS = [
  { file: "README.md", required: true, template: "readme" },
  { file: "patterns.md", required: false, template: "patterns" }
];

// Tier 1: Curated — full .md file exists
DOMAIN_FILE = `${SKILL_DIR}/references/domains/${domain}.md`;
if (exists(DOMAIN_FILE)) {
  domain_spec = Read(DOMAIN_FILE);
  domain_config = parse_frontmatter(domain_spec);
  if (domain_config.status === 'active') {
    domain_tier = 'curated';
    domain_body = domain_spec;  // body text used as agent guidance
    KEYWORDS_PRIMARY = domain_config.keywords.primary;
    KEYWORDS_SECONDARY = domain_config.keywords.secondary;
    KEYWORDS_EXCLUSION = domain_config.keywords.exclusion;
    AGENT_COUNT = domain_config.agent_count;
    LOCATIONS = domain_config.locations;
    OUTPUTS = domain_config.outputs;
  }
}

// Tier 2: Confirmed — registry entry with status: confirmed
if (!domain_tier) {
  registry = parse_yaml(Read(REGISTRY_PATH));
  registry_entry = registry.domains.find(d => d.id === domain && d.status === 'confirmed');
  if (registry_entry) {
    domain_tier = 'confirmed';
    domain_body = null;
    KEYWORDS_PRIMARY = registry_entry.keywords?.primary || registry_entry.keywords || [];
    KEYWORDS_SECONDARY = registry_entry.keywords?.secondary || [];
    KEYWORDS_EXCLUSION = registry_entry.keywords?.exclusion || [];
    AGENT_COUNT = 2;
    LOCATIONS = DEFAULT_LOCATIONS;
    OUTPUTS = DEFAULT_OUTPUTS;
  }
}

// Tier 3: Suggested — check survey-candidates.json
if (!domain_tier) {
  CANDIDATES_PATH = `${ARCHAEOLOGY_DIR}/survey-candidates.json`;
  if (exists(CANDIDATES_PATH)) {
    candidates = JSON.parse(Read(CANDIDATES_PATH));
    candidate = candidates.candidates.find(c => c.id === domain);
    if (candidate) {
      domain_tier = 'suggested';
      domain_body = null;
      KEYWORDS_PRIMARY = candidate.terms.slice(0, 5);   // top 5 terms as primary
      KEYWORDS_SECONDARY = candidate.terms.slice(5);      // remainder as secondary
      KEYWORDS_EXCLUSION = [];
      AGENT_COUNT = 1;
      LOCATIONS = DEFAULT_LOCATIONS;
      OUTPUTS = DEFAULT_OUTPUTS;
    }
  }
}

// Not found at any tier
if (!domain_tier) {
  list_domains();
  error(`Domain '${domain}' not found. Run /archaeology survey to discover new domains.`);
}
```

### Step 2 Verification
Before proceeding: confirm `domain_tier` is set and keywords are non-empty. For curated tier, verify `domain_config.status === 'active'` — do not launch agents against an undefined domain spec. For confirmed/suggested tiers, verify `KEYWORDS_PRIMARY` has at least one entry. Review: does the loaded domain's `KEYWORDS_PRIMARY` match the user's intent? If the domain spec looks mismatched, flag it before burning agent calls.

Log the tier for user awareness:
```javascript
if (domain_tier === 'confirmed') {
  log(`Using confirmed domain '${domain}' with system defaults (${AGENT_COUNT} agents). Create a domain file for targeted extraction.`);
}
if (domain_tier === 'suggested') {
  log(`Using suggested domain '${domain}' from survey candidates (exploratory, 1 agent). Run /archaeology survey to refresh candidates.`);
}
```

## Step 3: Parallel Search

Launch `AGENT_COUNT` Explore agents. Each searches `LOCATIONS` using domain keywords and writes findings to `${WORK_DIR}/extraction/${domain}-agent-{N}-findings.md`.

> **Agent output convention:** If customising the agent prompt below, follow the format rules in `references/conversation-parser.md#agent-output-format-convention`.

**Agent prompt template:**
```
You are exploring Claude Code history for ${domain} patterns.
PROJECT: ${PROJECT_NAME}
DOMAIN TIER: ${domain_tier}
SEARCH LOCATIONS: ${LOCATIONS}
PRIMARY KEYWORDS (must match): ${KEYWORDS_PRIMARY}
SECONDARY KEYWORDS (boost): ${KEYWORDS_SECONDARY}
EXCLUDE: ${KEYWORDS_EXCLUSION}

${tier_guidance}

Search with Grep, focus on successful patterns, capture context.

OUTPUT FORMAT per finding:
## Finding: [Brief Description]
**Context:** [When/where used]
**Pattern:** [What makes this notable]
**Example:** [code block]

Write findings to: ${output_file}
```

**Tier-specific guidance (`tier_guidance`):**

- **curated:** Uses the domain body text as guidance (existing behavior). Append the domain `.md` body content after keywords.
- **confirmed:** `"This is a confirmed domain without detailed extraction guidance. Cast a wider net:\n- Search for recurring patterns involving these keywords\n- Look for decisions, configurations, and workflows\n- Note tool usage patterns and integration approaches\n- Capture any reusable techniques or notable outcomes"`
- **suggested:** `"This is a newly discovered domain candidate. Your extraction is exploratory:\n- Verify these keywords actually cluster around a coherent practice area\n- Extract only high-confidence findings with clear evidence\n- If the keywords seem scattered across unrelated contexts, note that\n- Prioritize patterns and decisions over single-use capabilities"`

Wait for all agents to complete.

### Step 3 Verification
Before proceeding: confirm all `AGENT_COUNT` agent output files exist at `${WORK_DIR}/extraction/${domain}-agent-*-findings.md`. Hard stop if zero files were written — all agents failed silently. If fewer than `AGENT_COUNT` files exist, continue with what's available but warn the user. Review: do the findings files contain at least one `## Finding:` block? If every agent returned empty output, stop and report rather than synthesizing an empty document.

## Step 4: Synthesize & Output

```javascript
extraction_files = Glob(pattern: `${WORK_DIR}/extraction/${domain}-agent-*-findings.md`);
all_findings = extraction_files.map(f => Read(f)).join('\n\n---\n\n');

// Generate each output file from domain config with frontmatter (see references/output-templates.md#frontmatter)
// Frontmatter includes domain_tier for all tiers; coverage_note for non-curated tiers only
COVERAGE_NOTES = {
  confirmed: "Extracted with system defaults. Create a domain file for targeted extraction.",
  suggested: "Exploratory extraction from survey candidate. Results may be incomplete."
};

for (output of OUTPUTS) {
  content = synthesize_findings(all_findings, output.template);
  fm = { domain: domain, domain_tier: domain_tier, extracted_at: current_date() };
  if (domain_tier !== 'curated') fm.coverage_note = COVERAGE_NOTES[domain_tier];
  Write(`${DOMAIN_OUTPUT_DIR}/${output.file}`, build_frontmatter(fm) + content);
}

// Update local INDEX.md (canonical impl: references/survey-workflow.md)
update_local_archaeology_index();
```

### Step 4 Verification
Before proceeding to export: confirm all expected output files were written to `${DOMAIN_OUTPUT_DIR}/`. Hard stop if any `OUTPUTS` file is missing — do not export an incomplete run. Review: does the synthesized output address the domain's stated extraction goal? If the synthesis document contains only one finding or is under 200 words, flag as potentially thin before exporting to the central work-log.

## Step 4b: Parse Findings for Export

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

## Step 4c: Auto-Promotion (Suggested to Confirmed)

When a suggested-tier extraction yields 3+ findings, automatically promote the domain to `confirmed` in the registry. This closes the gap between survey discovery and repeatable extraction — no manual authoring needed.

```javascript
if (domain_tier === 'suggested' && all_findings_parsed.length >= 3) {
  registry = parse_yaml(Read(REGISTRY_PATH));
  registry.domains.push({
    id: domain,
    name: domain.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
    file: null,
    version: "0.1.0",
    status: "confirmed",
    description: `Auto-promoted from survey candidate. ${all_findings_parsed.length} findings extracted.`,
    pattern_types: [],
    keywords: {
      primary: KEYWORDS_PRIMARY,
      secondary: KEYWORDS_SECONDARY,
      exclusion: []
    },
    discovered_from: "survey",
    confirmed_at: current_date(),
    extraction_count: 1
  });
  Write(REGISTRY_PATH, serialize_yaml(registry));
  log(`Promoted '${domain}' to confirmed domain (${all_findings_parsed.length} findings).`);
}
```

No auto-promotion from `confirmed` to `active`. The `active` status requires a hand-authored `.md` file — that is a deliberate quality gate.

## Step 5: Export to Central Work-Log

**Skip if `--no-export`.** Each run replaces all outputs for this project/domain combo (no merge).

### 5a: Build Structured Findings

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

### 5b: Write Central Output Files

Write three files to `${CENTRAL_OUTPUT_DIR}/`:

1. **findings.json** — `JSON.stringify(findings_data, null, 2)`
2. **patterns.md** — narrative from `generate_narrative(findings_data)` (structure: `references/output-templates.md#patterns-narrative`)
3. **metadata.json** — run stats: `run_id`, `project`, `project_slug`, `domain`, `timestamp`, `agent_count`, `findings_count`, `finding_types`, `source_files_scanned`, `flags`

**`generate_run_id()` format:** `arch-{YYYYMMDD}-{random-4-hex}`

### 5c: Update Central INDEX.md

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

## Step 6: Project Synthesis

**Skip if `--no-export`.** Generate cross-domain SUMMARY.md (idempotent, concurrency-safe — last writer wins).

1. Scan all `metadata.json` and `findings.json` for this project
2. Merge highlights across domains, sort by type priority (`pattern > decision > artifact > capability`), cap at 7
3. Build tag overlap table (tags in 2+ domains)
4. Read Highlights section from each domain's `patterns.md`
5. Write `${CENTRAL_BASE}/${PROJECT_SLUG}/SUMMARY.md` (structure: `references/output-templates.md#summary`)
6. Re-run `update_central_index()` to pick up the new one-liner

## If No Results Found

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
