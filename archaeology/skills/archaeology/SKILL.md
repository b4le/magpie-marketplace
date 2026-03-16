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
/archaeology discover                  # Discover new domain candidates from history
/archaeology confirm <name>            # Promote a discovered candidate to confirmed domain
```

## Available Commands

- **survey** (default) - Scan project, score domain signal strength, suggest next steps
- **list** - Display available commands and domains with status and description
- **workstyle** - Analyse working style with Claude (tool usage, session shapes, delegation, communication patterns)
- **conserve** - Extract narrative artifacts from project history, generate default exhibition
- **dig** - Deep investigation of a specific subject across project history
- **discover** - Discover new domain candidates from conversation history without running a full survey
- **confirm** - Promote a discovered or suggested domain candidate to confirmed status in the registry
- **{domain}** - Run extraction for specified domain. Supports three tiers: curated (full spec), confirmed (registry with defaults), suggested (survey candidates). Run `list` to see available domains at all tiers
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
SIGILS = { survey: '◈', extraction: '◆', workstyle: '●', conserve: '◇', excavation: '✦', dig: '▼', list: '◈', discover: '◈', confirm: '◈' };
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

  // Display graduation candidates when available
  CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
  GRAD_PATH = `${CENTRAL_BASE}/graduation-candidates.md`;
  if (exists(GRAD_PATH)) {
    grad_content = Read(GRAD_PATH);
    // Parse candidate sections: each starts with "## {id}"
    candidates = grad_content.split(/^## /m).filter(Boolean).slice(1); // skip header
    if (candidates.length > 0) {
      print(`\n## Graduation Candidates\n`);
      print(`> Candidates appearing in 3+ projects — ready for promotion.\n`);
      print(`| Candidate | Projects | Action |`);
      print(`|-----------|----------|--------|`);
      for (c of candidates) {
        id = c.split('\n')[0].trim();
        projects_line = c.match(/\*\*Projects:\*\* (.+)/);
        project_count = projects_line ? projects_line[1].split(',').length : '?';
        print(`| ${id} | ${project_count} projects | \`/archaeology ${id}\` to extract, then \`/archaeology confirm ${id}\` |`);
      }
    }
  }
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

if (args.command === 'discover') {
  // Lightweight discovery: runs S1 (context), S2 (size check), S3 (scoring for KNOWN_DOMAIN_TERMS),
  // and S3.5 (discovery) from survey-workflow.md, then displays results.
  // Skips S4 (profiling), S5 (unknown detection), S6-S8 (full survey output/export).
  //
  // Read and follow the survey-workflow.md for S1, S2, S3 (keyword scoring), and S3.5 (discovery).
  // After S3.5 completes, display discovered signals directly:
  //
  // {SIGIL_SURVEY} Archaeology Discover Complete
  //
  // Discovered {discovered_signals.length} domain candidates from {project_size.conversations} conversations
  //
  // Candidates:
  //   {s.name}  {s.signal}  {s.coherence} coherence  ({s.term_count} terms, {s.session_spread} sessions)
  //   → /archaeology {s.id}
  //
  // To promote a candidate: /archaeology confirm <name>
  // To run full survey:      /archaeology survey
  //
  // {SIGNOFF}
  //
  // If no candidates found: "No new domain candidates discovered. Existing domains have good coverage."
  // Write survey-candidates.json (S7) so candidates are available for extraction.
  execute_discover(args);
  return;
}

if (args.command === 'confirm') {
  if (!args.subject) error("confirm requires a name: /archaeology confirm <name>");
  // Promote a candidate to confirmed domain in the registry.
  //
  // Resolution order:
  // 1. Check survey-candidates.json for a matching discovered signal
  // 2. Check graduation-candidates.md for a matching cross-project candidate
  // 3. If neither found, error with suggestion to run /archaeology discover first
  //
  // When found, write a confirmed entry to registry.yaml:
  // {
  //   id: slugified_name,
  //   name: candidate.name,
  //   file: null,
  //   version: "0.1.0",
  //   status: "confirmed",
  //   description: candidate.description,
  //   pattern_types: [],
  //   keywords: {
  //     primary: candidate.terms.slice(0, 5) || [],
  //     secondary: candidate.terms.slice(5) || [],
  //     exclusion: []
  //   },
  //   discovered_from: source,  // "survey" or "excavation"
  //   confirmed_at: current_date(),
  //   extraction_count: 0
  // }
  //
  // Display:
  //   {SIGIL_SURVEY} Domain Confirmed
  //
  //   {name} added to registry as confirmed domain
  //   Keywords: {primary_keywords}
  //
  //   Next: /archaeology {id} to extract patterns
  //
  //   {SIGNOFF}
  //
  execute_confirm(args);
  return;
}

if (args.command === undefined || args.command === 'survey') {
  // Branch to Survey workflow (see references/survey-workflow.md)
  execute_survey(args);
  return;
}

// Otherwise: branch to Domain Extraction workflow (see references/extraction-workflow.md)
```

## Domain Extraction Workflow

When invoked with a domain name (falls through command routing), execute the domain extraction workflow.

Read and follow the full specification in `${SKILL_DIR}/references/extraction-workflow.md`.

Domain extraction resolves project context, loads domain definitions (three-tier: curated, confirmed, suggested), launches parallel search agents, synthesizes findings, and exports to the central work-log. Supports `--no-export` flag.

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
