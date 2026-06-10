# Archaeology

> Dig through Claude Code session history — survey projects, extract domain patterns, analyse workstyles, conserve narrative artifacts, and investigate subjects in depth.

**Version:** 1.4.0

Archaeology is a Claude Code plugin for mining your session history. It surveys projects to score domain signal strength, extracts structured findings across configurable knowledge domains, analyses your working style with Claude, conserves narrative artifacts worth preserving, runs deep multi-turn investigations into specific subjects, and orchestrates portfolio-wide scans across all your projects. All output is dual-written: locally per-project and centrally to a shared work-log for cross-project consumption.

## Features

- **Survey mode** — scan a project's session history, score signal strength across all registered domains, and suggest extraction targets
- **Domain extraction** — parallel agent search with configurable keywords, confidence/relevance scoring, and structured JSON export
- **Workstyle analysis** — characterise tool usage, session shapes, delegation patterns, and communication style (per-project or global)
- **Conservation** — extract atomic narrative artifacts (shipments, decisions, incidents, discoveries, tales, practices) and generate curated exhibitions
- **Dig mode** — interactive multi-turn investigation with spelunker agents, nugget extraction, vein discovery, and persistent cavern map state
- **Excavation** — cross-project portfolio scan that discovers all projects, surveys each in parallel, and generates an aggregate portfolio report
- **Pluggable domain system** — four active domains with a template and registry for adding more
- **Dual output** — local `.claude/archaeology/` tree plus central `~/.claude/data/visibility-toolkit/work-log/archaeology/` work-log
- **Branded output** — strata-mark logo, mode sigils, and consistent visual language across all modes
- **Validation suite** — 5 shell scripts and 18 eval cases for structural, content, and domain compliance

## Quick Start

```bash
/archaeology                        # Survey current project (default mode)
/archaeology list                   # Show available commands and domains
/archaeology orchestration          # Extract orchestration patterns
/archaeology workstyle              # Analyse working style for current project
/archaeology workstyle --global     # Aggregate workstyle across all projects
/archaeology conserve               # Conserve narrative artifacts
/archaeology dig "OAuth strategy"   # Deep investigation of a specific subject
/archaeology excavation             # Portfolio scan across all projects
```

## Architecture

### Mode Router

User invocation flows through a single command router that branches to six mode pipelines, each with its own step sequence:

```text
                          +---------------------+
                          |  /archaeology [cmd]  |
                          +---------+-----------+
                                    |
                                    v
                          +---------------------+
                          |   Command Router    |
                          |  (SKILL.md routing) |
                          +---------------------+
                           |   |   |   |   |   |
            +--------------+   |   |   |   |   +-------------+
            |         +--------+   |   |   +-------+         |
            v         v            v   v           v         v
      +---------+ +--------+ +--------+ +-------+ +-----+ +------+
      | Survey  | | Domain | | Work-  | |Conserve| | Dig | |Excav-|
      | S1-S7   | | 1-6    | | style  | | C1-C7 | |D1-D7| |ation |
      |         | |        | | W1-W7  | |       | |     | |E1-E6|
      +---------+ +--------+ +--------+ +-------+ +-----+ +------+
          |           |           |          |        |        |
          v           v           v          v        v        v
      survey.md  findings.json workstyle exhibition cavern  portfolio
                 patterns.md  .json     .md + arts  -map    -report
                 metadata.json          artifacts/  .json   .md
```

### Dig Mode Pipeline

Dig is a multi-turn investigation loop. Each cycle dispatches spelunker agents into tunnels, extracts nuggets, identifies veins (connections), and updates the cavern map. The user steers between cycles.

```text
      +------------------+
      | D1: State        |
      |    Resolution    |
      +--------+---------+
               |
               v
      +------------------+
      | D2: Subject      |
      |    Expansion     |
      +--------+---------+
               |
               v
      +------------------+
      | D3: Tunnel       |
      |    Construction  |
      +--------+---------+
               |
               v
  +-->+------------------+
  |   | D4: Cavern Map   |<----------+
  |   |    Display       |           |
  |   +--------+---------+           |
  |            |                     |
  |            v                     |
  |   +------------------+           |
  |   | D5: Rig Operator |           |
  |   | + Spelunker      |           |
  |   |   Fan-out        |           |
  |   +--------+---------+           |
  |            |                     |
  |            v                     |
  |   +------------------+           |
  |   | D6: Connector    |           |
  |   |    Pass          |           |
  |   +--------+---------+           |
  |            |                     |
  |            v                     |
  |   +------------------+           |
  |   | D7: Trove Update |           |
  |   |    + State Write +-----------+
  |   +------------------+   (loop back
  |                           to D4)
  |
  +--- user steers / --done / --export
```

### Data Flow

Archaeology writes to two locations: a local per-project tree and a central work-log. Modes produce different artifacts at each level.

```text
  Per-project (local)                    Central work-log
  {project}/.claude/archaeology/         ~/.claude/data/visibility-toolkit/
                                           work-log/archaeology/
  +-------------------------------+      +-------------------------------+
  | survey.md                     |      | INDEX.md                      |
  | workstyle.md                  |      | {project-slug}/               |
  | workstyle.json                |      |   SUMMARY.md                  |
  | {domain}/                     |      |   survey.md                   |
  |   README.md                   |      |   workstyle.json              |
  |   patterns.md (if generated)  |      |   workstyle.md                |
  | artifacts/                    |      |   {domain}/                   |
  |   art-001.md ...              |      |     findings.json             |
  |   _index.json                 |      |     patterns.md               |
  | exhibition.md                 |      |     metadata.json             |
  | spelunk/{subject-slug}/       |      |   artifacts/                  |
  |   cavern-map.json             |      |     art-001.md ...            |
  |   nuggets/nug-001.md ...      |      |     _index.json               |
  |   veins.json                  |      |   exhibition.md               |
  |   trove.md                    |      | artifacts-registry.json       |
  | .work/ (transient)            |      | workstyle-global.json         |
  | INDEX.md                      |      | portfolio-report.md           |
  +-------------------------------+      +-------------------------------+
```

## Modes Reference

| Mode | Sigil | Invocation | Description |
|------|-------|------------|-------------|
| Survey | `◈` | `/archaeology` or `/archaeology survey` | Scan project, score domain signal strength, suggest next steps |
| Domain extraction | `◆` | `/archaeology {domain}` | Run parallel agent extraction for a specific domain |
| Workstyle | `●` | `/archaeology workstyle` | Analyse working style — tool usage, delegation, session shape |
| Conserve | `◇` | `/archaeology conserve` | Extract narrative artifacts, generate exhibition |
| Dig | `▼` | `/archaeology dig "subject"` | Multi-turn deep investigation with persistent state |
| Excavation | `✦` | `/archaeology excavation` | Cross-project portfolio scan and aggregate report |
| List | `◈` | `/archaeology list` | Display available commands and domains |

All modes except excavation support `--no-export` to skip central work-log writes. Workstyle supports `--global` for cross-project aggregation. Dig supports `--fresh`, `--done`, and `--export` flags.

## Dig Mode Glossary

Dig mode uses a mining/spelunking vocabulary:

| Term | Meaning |
|------|---------|
| **Tunnel** | A branch of investigation — a sub-topic discovered during a dig |
| **Nugget** | A single discrete finding with YAML frontmatter (`nug-NNN.md`) |
| **Vein** | A connection between two nuggets, anchored to a concrete bridge element |
| **Spelunker** | An Explore agent dispatched into a tunnel to extract nuggets from sessions |
| **Rig operator** | The orchestration layer that partitions sessions across spelunkers |
| **Cavern map** | The persistent state tree (`cavern-map.json`) tracking all tunnels, nuggets, and decisions |
| **Trove** | The human-readable accumulated findings document, regenerated each cycle from nuggets + veins |
| **Slab** | A message range within a session file (e.g., `msg:41-80`) |

## Domain System

Domains are pluggable knowledge extraction targets. Each domain has a definition file with keywords, agent configuration, and output templates.

### Active Domains

| Domain | Description | Agent count |
|--------|-------------|-------------|
| `orchestration` | Agent orchestration patterns (sub-agents, teams, parallel execution) | 4 |
| `prompting-patterns` | Claude usage patterns, prompt engineering, CLAUDE.md evolution | — |
| `python-practices` | Python coding patterns, testing practices, type hints | — |
| `git-workflows` | Git commit patterns, PR workflows, branching strategies | — |

### Adding Domains

1. Create `skills/archaeology/references/domains/{domain}.md` using the template in `ADDING-DOMAINS.md`
2. Add an entry to `references/domains/registry.yaml`
3. Run `scripts/validate-domains.sh` and `scripts/check-registry-sync.sh`

See `references/domains/DOMAIN-TEMPLATE.md` for the required YAML frontmatter schema.

## Output Structure

```text
Per-project local output:
{project}/.claude/archaeology/
+-- survey.md                        # Survey results
+-- workstyle.md                     # Workstyle narrative
+-- workstyle.json                   # Workstyle structured data
+-- {domain}/                        # Per-domain extraction output
|   +-- README.md
|   +-- patterns.md
+-- artifacts/                       # Conservation artifacts
|   +-- art-001.md ... art-NNN.md
|   +-- _index.json
+-- exhibition.md                    # Curated exhibition
+-- spelunk/{subject-slug}/          # Dig state (per subject)
|   +-- cavern-map.json
|   +-- nuggets/nug-001.md ...
|   +-- veins.json
|   +-- trove.md
+-- INDEX.md                         # Local index
+-- .work/                           # Transient working files

Central work-log:
~/.claude/data/visibility-toolkit/work-log/archaeology/
+-- INDEX.md                         # Cross-project index with reading path
+-- artifacts-registry.json          # Global artifact registry
+-- workstyle-global.json            # Global workstyle aggregation
+-- portfolio-report.md              # Excavation portfolio report
+-- {project-slug}/
    +-- SUMMARY.md                   # Cross-domain project summary
    +-- survey.md
    +-- workstyle.json / workstyle.md
    +-- {domain}/
    |   +-- findings.json            # Structured findings with scoring
    |   +-- patterns.md              # Narrative patterns document
    |   +-- metadata.json            # Run metadata
    +-- artifacts/ ...
    +-- exhibition.md
```

## Scripts and Validation

### Shell Scripts

| Script | Purpose |
|--------|---------|
| `scripts/archaeology-excavation.sh` | Discovery and subprocess management for excavation mode |
| `scripts/validate-domains.sh` | Validate domain definition files against schema |
| `scripts/check-registry-sync.sh` | Verify registry.yaml matches actual domain files |
| `scripts/validate-conserve.sh` | Validate conservation artifact structure |
| `scripts/validate-dig.sh` | Validate dig state files (cavern map, nuggets, veins) |

### Eval Suite

18 YAML eval cases across 4 categories:

| Category | Files | Coverage |
|----------|-------|----------|
| Invocation | `INVOKE-01` through `INVOKE-06` | Command routing, argument parsing, flag handling |
| Output | `OUTPUT-01` through `OUTPUT-04` | Output format compliance, schema validation |
| Edge cases | `EDGE-01` through `EDGE-03` | Missing history, empty domains, error handling |
| Structure | `STRUCT-01` | Plugin file structure validation |

### Validation Scripts

| Script | Purpose |
|--------|---------|
| `evals/validate-structure.sh` | Full plugin structure validation (11 checks) |
| `evals/validate-scripts.sh` | Script existence and executability checks |
| `evals/validate-skill-content.sh` | SKILL.md content and frontmatter validation |

## File Structure

```text
archaeology/
+-- .claude-plugin/
|   +-- plugin.json                  # Plugin manifest (name, version, keywords)
+-- skills/
|   +-- archaeology/
|       +-- SKILL.md                 # Main skill entry point (command router, workflows)
|       +-- SCHEMA.md               # Output schemas (findings, workstyle, artifacts, cavern map, nuggets, veins)
|       +-- references/
|           +-- branding.md          # Visual identity (sigils, logo, design language)
|           +-- survey-workflow.md   # Survey mode steps S1-S7
|           +-- workstyle-workflow.md # Workstyle mode steps W1-W7
|           +-- conserve-workflow.md # Conservation mode steps C1-C7
|           +-- dig-workflow.md      # Dig mode steps D1-D7
|           +-- excavation-workflow.md # Excavation mode steps E1-E6
|           +-- output-templates.md  # Output format templates
|           +-- consumption-spec.md  # Reading levels for work-log consumers
|           +-- conversation-parser.md # Session file parsing conventions
|           +-- jsonl-filter.jq      # jq filter for session JSONL files
|           +-- jsonl-tool-names.jq  # jq filter for tool name extraction
|           +-- domains/
|               +-- registry.yaml    # Domain registry (schema v1.0.0)
|               +-- orchestration.md # Orchestration patterns domain
|               +-- prompting-patterns.md # Prompting patterns domain
|               +-- python-practices.md # Python practices domain
|               +-- git-workflows.md # Git workflows domain
|               +-- DOMAIN-TEMPLATE.md # Template for new domains
|               +-- ADDING-DOMAINS.md # Guide for adding domains
|               +-- ADDING-DOMAINS-COMPREHENSIVE.md # Extended domain authoring guide
+-- scripts/
|   +-- archaeology-excavation.sh    # Excavation discovery + subprocess manager
|   +-- validate-domains.sh         # Domain file validation
|   +-- check-registry-sync.sh      # Registry sync check
|   +-- validate-conserve.sh        # Conservation artifact validation
|   +-- validate-dig.sh             # Dig state validation
+-- evals/
|   +-- validate-structure.sh       # Plugin structure validation
|   +-- validate-scripts.sh         # Script validation
|   +-- validate-skill-content.sh   # Skill content validation
|   +-- STRUCT-01.yaml              # Structure eval
|   +-- INVOKE-01.yaml ... INVOKE-06.yaml  # Invocation evals
|   +-- OUTPUT-01.yaml ... OUTPUT-04.yaml  # Output evals
|   +-- EDGE-01.yaml ... EDGE-03.yaml     # Edge case evals
+-- docs/
|   +-- showcase.html               # Visual showcase
|   +-- plans/                       # Design documents and planning artifacts
|       +-- 2026-03-04-survey-mode-design.md
|       +-- 2026-03-04-workstyle-mode-design.md
|       +-- 2026-03-04-excavation-mode-design.md
|       +-- 2026-03-06-conserve-command-design.md
|       +-- 2026-03-07-conserve-implementation-prompt.md
|       +-- 2026-03-07-xml-output-format-migration.md
|       +-- 2026-03-09-dig-mode-design.md
|       +-- 2026-03-09-rig-operator-design.md
|       +-- 2026-03-10-rig-operator-plan.md
|       +-- dig-design-sections/     # Dig mode design breakdown
|       +-- ...                      # Additional planning artifacts
+-- README.md                        # This file
+-- .gitignore
```

## Installation

### Via Marketplace

```bash
claude plugin install archaeology@magpie-marketplace
```

### Manual Installation

Clone or copy the `archaeology/` directory into `~/.claude/plugins/archaeology/` and ensure `.claude-plugin/plugin.json` is present. The plugin registers the `archaeology` skill with all six modes.

## Version History

| Version | Description |
|---------|-------------|
| 1.0.0 | Initial release — survey mode, domain extraction (orchestration), parallel agent search |
| 1.1.0 | Workstyle analysis mode, domain registry system, 3 additional domains |
| 1.2.0 | Excavation mode — cross-project portfolio scanning with subprocess management |
| 1.3.0 | Conservation mode — narrative artifact extraction, exhibitions, global artifact registry |
| 1.4.0 | Dig mode — multi-turn interactive investigation with spelunker agents, nuggets, veins, and cavern map state persistence. Rig operator design for session partitioning. 5 validation scripts, 18 eval cases |
