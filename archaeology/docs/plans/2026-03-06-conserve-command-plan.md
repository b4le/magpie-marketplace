# `/archaeology conserve` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `/archaeology conserve` command that extracts atomic narrative artifacts from project history and generates a default exhibition.

**Architecture:** New workflow spec (`conserve-workflow.md`) following the workstyle/survey pattern (C1-C7 steps). SKILL.md routes to it. Artifacts stored as markdown+frontmatter with generated JSON indices. Integration touchpoints in 4 existing reference files.

**Tech Stack:** Markdown with YAML frontmatter, JSON indices, Explore sub-agents for narrative extraction.

**Design doc:** `docs/plans/2026-03-06-conserve-command-design.md`

---

## Execution Strategy

### Agent Routing

| Task | Agent Type | Skills | Mode | Model |
|------|-----------|--------|------|-------|
| 1-4 (parallel edits) | `implementation-agent` | None | Background, all 4 simultaneously | sonnet |
| 5 (create workflow) | `implementation-agent` | `superpowers:executing-plans` | Foreground, blocked on Task 1 | sonnet |
| 6 (SKILL.md edits) | `implementation-agent` | `superpowers:verification-before-completion` | Foreground, blocked on Task 5 | sonnet |
| 7a (static validation) | `Explore` | None | Foreground | opus |
| 7b (live test) | Main session | archaeology skill | Foreground, user confirmation required | — |
| 8 (validation script) | `shell-scripting:bash-pro` | `shell-scripting:bash-defensive-patterns` | Foreground | sonnet |
| Post-review | `plugin-dev:skill-reviewer` | `skill-checklist` | Foreground | sonnet |

### C4 Runtime Agents (within the workflow itself)

All 5 extraction agents use `Explore` (read-only). They receive XML-formatted output contracts (`<artifact>...</artifact>`) and one-shot examples. Type-specific seed context filtering ensures each agent gets relevant findings via `build_seed_context()`.

### Orchestration

Main session orchestrates using `superpowers:executing-plans` + `superpowers:dispatching-parallel-agents`. No team-lead agent — dependency graph is simple (one fork, then linear chain). Task 7b (live test) must run in main session (skill invocation cannot be delegated).

### Session Budget

| Task | Complexity | Points |
|------|-----------|--------|
| Tasks 1-4 (parallel) | Simple x4 | 1 each (parallel = 1 slot) |
| Task 5 | Complex | 3 |
| Task 6 | Medium | 2 |
| Task 7a+b | Medium | 2 |
| Task 8 | Medium | 2 |
| Post-review | Simple | 1 |
| **Total** | | **~8 points** |

---

### Task 1: Add conserve-completion and exhibition templates to output-templates.md

**Files:**
- Modify: `~/.claude/skills/archaeology/references/output-templates.md`

**Context:** All completion displays follow a strict contract format defined in output-templates.md. We need to add the `{#conserve-completion}` template and the `{#exhibition}` template for `exhibition.md` output.

**Step 1: Read the file**

Read `~/.claude/skills/archaeology/references/output-templates.md` to understand the current structure and find the insertion point (after `{#workstyle-completion}`).

**Step 2: Add the exhibition template**

Insert after the Workstyle Profile Template (`{#workstyle}`) section and before the No Results Template (`{#no-results}`) section:

```markdown
---

## Exhibition Template {#exhibition}

Structure for `exhibition.md` output (default per-project exhibition):

```markdown
# {Project} -- Conservation

> {N} artifacts conserved on {date} | {type_summary}

## Shipments
- [{title}](artifacts/{id}.md) -- {tags}

## Decisions
- [{title}](artifacts/{id}.md) -- {tags}

## Incidents
- [{title}](artifacts/{id}.md) -- {tags}

## Discoveries
- [{title}](artifacts/{id}.md) -- {tags}

## Tales
- [{title}](artifacts/{id}.md) -- {tags}

## Practices
- [{title}](artifacts/{id}.md) -- {tags}

---
*Conserved by archaeology skill -- command: conserve*
```

**Variables:**
- `{type_summary}` — e.g. "3 shipments, 2 decisions, 1 incident"
- Only include sections for types that have artifacts (omit empty type sections)
- `{tags}` — first 3 tags from artifact, comma-separated
```

**Step 3: Add the conserve completion display template**

Insert after the `{#workstyle-completion}` section (at the very end of the Completion Display Templates area, before the final `*Last updated*` line):

```markdown
### Conservation Completion Display {#conserve-completion}

```
Archaeology Conservation Complete

Conserved {artifact_count} artifacts | {high_count} high confidence, {medium_count} medium, {low_count} low

Artifacts by type:
  {type}  {count}

Local:   .claude/archaeology/artifacts/
         .claude/archaeology/exhibition.md
Central: ~/.claude/data/visibility-toolkit/work-log/archaeology/{PROJECT_SLUG}/artifacts/
         ~/.claude/data/visibility-toolkit/work-log/archaeology/{PROJECT_SLUG}/exhibition.md

Next: /archaeology curate (when available)
```

**Variables:**
- `{artifact_count}` — total artifacts conserved
- `{high_count}`, `{medium_count}`, `{low_count}` — confidence distribution
- `{type}` / `{count}` — one line per type that has artifacts, indented 2 spaces. Type name lowercase.
- `{PROJECT_SLUG}` — from C1

**If `--no-export`:** Use title `Archaeology Conservation Complete (export skipped)`, omit Central paths.

**If 0 artifacts extracted:** Do not show this template. Instead display:
```
Archaeology Conservation Complete

No artifacts extracted. Project history may lack sufficient narrative content.

Suggestions:
  Run /archaeology survey to check domain signal strength
  Run /archaeology {domain} to extract findings first
  Try a project with more session history (5+ sessions recommended)
```
```

**Step 4: Update the last-updated date**

Change the final line `*Last updated: 2026-03-04*` to `*Last updated: 2026-03-06*`.

---

### Task 2: Add Artifact Object Schema to SCHEMA.md

**Files:**
- Modify: `~/.claude/skills/archaeology/SCHEMA.md`

**Context:** SCHEMA.md defines the Finding Object Schema and Workstyle Object Schema. We need to add the Artifact Object Schema in the same format.

**Step 1: Read the file**

Read `~/.claude/skills/archaeology/SCHEMA.md`.

**Step 2: Append the Artifact Object Schema**

Add after the Workstyle Object Schema section (at the end of the file):

```markdown
---

# Artifact Object Schema (v1)

**Canonical schema for artifact `.md` files and `_index.json`.** Artifacts are atomic narrative objects (150-300 words) that tell one story about a project.

### Artifact Types

| Type | What it is | Natural sections |
|------|-----------|-----------------|
| `shipment` | A feature, launch, or milestone delivered | What was built / Why it matters / The result |
| `decision` | A choice made and why | The options / The constraints / The choice / What happened next |
| `incident` | Something broke and what we learned | What broke / The response / The fix / The systemic change |
| `discovery` | A surprise, insight, or busted assumption | The assumption / The evidence / The new understanding |
| `tale` | A story worth telling for its arc | The setup / The complication / The resolution |
| `practice` | How we work -- a process or workflow | What we do / Why it emerged / What problem it solves |

### Artifact Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Project-scoped ID, format `art-NNN` |
| `project` | string | yes | Project slug, matches directory name |
| `uri` | string | yes | Global address `arch://{project}/{id}` |
| `type` | enum | yes | `shipment` \| `decision` \| `incident` \| `discovery` \| `tale` \| `practice` |
| `title` | string | yes | Human-readable headline, max 80 chars |
| `confidence` | enum | yes | `high` \| `medium` \| `low` |
| `significance` | integer | yes | 1-10 editorial weight for exhibition curation |
| `tags` | string[] | yes | At least one tag, free-form shared vocabulary |
| `conserved_at` | date | yes | When the artifact was created (YYYY-MM-DD) |
| `session_date` | date | yes | When the source event occurred (YYYY-MM-DD) |
| `sources.findings` | object[] | no | Finding references: `{id, title}` |
| `sources.sessions` | object[] | yes | Session references: `{path, label}` |
| `status` | enum | yes | `draft` \| `refined` \| `published` |
| `revised` | date/null | yes | Last human edit date, null if unedited |
| `related` | object[] | no | Cross-references: `{uri, relation}` |
| `exhibitions` | string[] | no | Back-references from exhibitions |

### Confidence Scoring (Source-Grounded)

| Level | Criteria |
|-------|----------|
| `high` | Direct quote or specific session reference with concrete detail |
| `medium` | Inferred from multiple sessions, no single clear source |
| `low` | Synthesized from general patterns, no specific evidence |

### Per-Project Index (`_index.json`) Fields

| Field | Type | Description |
|-------|------|-------------|
| `project` | string | Project slug |
| `generated_at` | ISO string | When the index was generated |
| `artifact_count` | integer | Total artifacts |
| `reading_order` | string[] | Suggested artifact IDs for project comprehension |
| `artifacts` | object[] | Array of artifact metadata (frontmatter fields, no body) |
| `by_type` | object | Map of type -> artifact ID arrays |

### Global Registry (`artifacts-registry.json`) Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | integer | Schema version, `1` |
| `last_updated` | ISO string | When the registry was last updated |
| `total_artifacts` | integer | Total across all projects |
| `artifacts` | object[] | Flat list of artifact metadata with `project` field |
| `tag_index` | object | Map of tag -> artifact URI arrays |
| `type_index` | object | Map of type -> artifact URI arrays |

### Relation Types

| Relation | Meaning |
|----------|---------|
| `preceded-by` | This artifact follows from the referenced one |
| `followed-by` | The referenced artifact came after this one |
| `similar-pattern` | Same approach in a different context |
| `contradicts` | Opposite conclusion or approach |
| `builds-on` | Extends or improves the referenced artifact |
| `supersedes` | Replaces the referenced artifact |
```

---

### Task 3: Add Level 3.5 Narrate to consumption-spec.md

**Files:**
- Modify: `~/.claude/skills/archaeology/references/consumption-spec.md`

**Context:** consumption-spec.md defines reading levels 1-6. We need to add Level 3.5 Narrate between Understand (3) and Act (4).

**Step 1: Read the file**

Read `~/.claude/skills/archaeology/references/consumption-spec.md`.

**Step 2: Update the Reading Levels table**

In the `## Reading Levels` table, add a new row between level 3 (Understand) and level 4 (Act):

```markdown
| 3.5 Narrate | `{project}/artifacts/` + `exhibition.md` | Need to explain what was built to someone else | The exhibition gives you enough to write from |
```

**Step 3: Update the "For AI Agents Resuming Work" section**

Insert between step 3 and step 4:

```markdown
3.5 Read({project}/exhibition.md)          → conserved narrative artifacts, grouped by type
    Read({project}/artifacts/{id}.md)       → only if you need the full story of a specific artifact
```

Renumber subsequent steps (4 becomes 4, 5 becomes 5, 6 becomes 6 — no change needed since 3.5 slots in).

**Step 4: Add a section for consuming artifacts**

After the "For Skills Adapting to User Workstyle" section, add:

```markdown
## For Skills Consuming Narrative Artifacts

Read `exhibition.md` for a project overview. Parse `artifacts/_index.json` for programmatic access. Useful fields:
- `by_type` → filter artifacts by narrative shape (shipment, decision, incident, discovery, tale, practice)
- `artifacts[].significance` → editorial weight (1-10) for curation
- `artifacts[].confidence` → evidence quality
- `artifacts[].tags` → cross-reference with findings tags

For cross-project discovery, parse `artifacts-registry.json` at the central work-log root:
- `tag_index` → find artifacts by topic across all projects
- `type_index` → find all artifacts of a specific narrative type
```

**Step 5: Update Schema Versions table**

Add a new row:

```markdown
| artifact v1 | Initial: 6 narrative types, per-project index, global registry, exhibition manifest |
```

---

### Task 4: Update `update_local_archaeology_index()` in survey-workflow.md

**Files:**
- Modify: `~/.claude/skills/archaeology/references/survey-workflow.md`

**Context:** The `update_local_archaeology_index()` function in survey-workflow.md is the canonical definition for the local INDEX.md builder. It currently detects survey and workstyle outputs. It needs to also detect artifacts and exhibitions.

**Step 1: Read the relevant section**

Read `~/.claude/skills/archaeology/references/survey-workflow.md` lines 556-587 (the `update_local_archaeology_index()` function).

**Step 2: Update the function**

In the `update_local_archaeology_index()` function, add artifact and exhibition detection. Replace the existing function body:

Find:
```javascript
  // Check if survey and workstyle exist
  has_survey = exists(`${ARCHAEOLOGY_DIR}/survey.md`);
  has_workstyle = exists(`${ARCHAEOLOGY_DIR}/workstyle.md`);
```

Replace with:
```javascript
  // Check if survey, workstyle, and conservation outputs exist
  has_survey = exists(`${ARCHAEOLOGY_DIR}/survey.md`);
  has_workstyle = exists(`${ARCHAEOLOGY_DIR}/workstyle.md`);
  has_artifacts = exists(`${ARCHAEOLOGY_DIR}/artifacts/_index.json`);
  has_exhibition = exists(`${ARCHAEOLOGY_DIR}/exhibition.md`);
```

Find the `index_content` template string and add after the workstyle block and before the `## Domains extracted:` line:

```javascript
${has_artifacts ? '## Conservation\n- [exhibition.md](./exhibition.md) — Project conservation exhibition\n- [artifacts/](./artifacts/) — Conserved narrative artifacts\n\n' : ''}
```

---

### Task 5: Create conserve-workflow.md

**Files:**
- Create: `~/.claude/skills/archaeology/references/conserve-workflow.md`

**Context:** This is the main workflow specification, following the same pattern as `survey-workflow.md` (S1-S7) and `workstyle-workflow.md` (W1-W7). Steps are C1-C7. The full pseudocode is in the design doc at `docs/plans/2026-03-06-conserve-command-design.md`.

**Step 1: Write the full workflow spec**

Create `~/.claude/skills/archaeology/references/conserve-workflow.md` with the complete C1-C7 workflow. The content is the entire "Conserve Workflow (C1-C7)" section from the design doc, reformatted to match the style of `workstyle-workflow.md`:

- Header with reference note (same as workstyle: "This file is referenced from SKILL.md...")
- Each step as `### Conservation Step C{N}: {Name}`
- Pseudocode in fenced `javascript` blocks
- Agent prompt templates as fenced blocks
- Error handling table
- Completion criteria checklist
- Completion display section referencing `output-templates.md#conserve-completion`

Copy the full C1-C7 content from the design doc sections: C1 (Resolve Project Context), C2 (Load Prior Extractions), C3 (Session Selection), C4 (Narrative Extraction), C5 (Artifact Assembly), C6 (Exhibition Generation), C7 (Export + Index Updates), plus the `update_artifacts_registry()` helper function.

**Important:** The design doc uses XML tags (`<artifact>...</artifact>`) for C4 agent output format and C5 parsing. Ensure the workflow spec matches the design doc's XML format exactly, including the `extract_xml_field()` helper, `build_seed_context()` with type-specific filtering, `distribute_sessions()` with anchored overlap, the one-shot example in agent prompts, and the per-agent failure diagnostics in C5.

Add the following sections at the end:

**Error handling table** (from design doc "Error Handling" section).

**Conservation Completion Criteria:**
```markdown
### Conservation Completion Criteria

Conservation run is complete when:
- [ ] Project context resolved (C1)
- [ ] Prior extractions scanned for narrative seeds (C2)
- [ ] Sessions selected (findings-guided or heuristic fallback) (C3)
- [ ] All 5 extraction agents completed (C4)
- [ ] Artifacts assembled with IDs, frontmatter, and body (C5)
- [ ] Default exhibition generated (C6)
- [ ] **(Unless --no-export)** Artifacts exported to central work-log
- [ ] **(Unless --no-export)** Global artifacts registry updated
- [ ] **(Unless --no-export)** SUMMARY.md updated with Key Narratives
- [ ] **(Unless --no-export)** Central INDEX.md updated
- [ ] Local INDEX.md updated with conservation entry
- [ ] Completion summary displayed with file locations
```

**Conservation Completion Display:**
```markdown
### Conservation Completion Display

**MUST use the exact template from `output-templates.md#conserve-completion`.** Do not reformat, add tables, add emoji, or alter the structure.

Key variable mappings:
- `{artifact_count}` — total artifacts from C5
- `{high_count}`, `{medium_count}`, `{low_count}` — confidence distribution from C5
- `{type}` / `{count}` — one line per type with artifacts, from C5 grouping
- `{PROJECT_SLUG}` — from C1
```

---

### Task 6: Update SKILL.md with conserve command

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md`

**Context:** SKILL.md needs 4 changes: (1) add "conserve" to the description trigger phrases, (2) add invocation patterns, (3) add to Available Commands list, (4) add command routing, (5) add a Conservation Workflow section.

**Step 1: Read SKILL.md**

Read `~/.claude/skills/archaeology/SKILL.md`.

**Step 2: Update the description frontmatter**

In the `description:` field (line 3), add trigger phrases. Find:
```
"communication patterns", or "delegation patterns"
```
Replace with:
```
"communication patterns", "delegation patterns", "conserve", "conservation", "preserve artifacts", "create artifacts", "narrative extraction", "what did I build", "tell the story", or "project story"
```

**Step 3: Update the argument-hint**

Find:
```
argument-hint: "[survey|workstyle|excavation|{domain}|list] [project-name] [--no-export] [--global]"
```
Replace with:
```
argument-hint: "[survey|workstyle|conserve|excavation|{domain}|list] [project-name] [--no-export] [--global]"
```

**Step 4: Add conserve invocation patterns**

In the `## Invocation Patterns` code block, add after the workstyle patterns and before the excavation patterns:

```bash
/archaeology conserve                     # Conserve artifacts for current project
/archaeology conserve "Project Name"      # Conserve artifacts for specific project
/archaeology conserve --no-export         # Conserve locally only, skip central work-log
```

**Step 5: Add to Available Commands**

In the `## Available Commands` list, add after workstyle and before `{domain}`:

```markdown
- **conserve** - Extract narrative artifacts from project history, generate default exhibition
```

**Step 6: Add command routing**

In the `### Command Routing` code block, add a conserve check after the workstyle check and before the excavation check:

```javascript
if (args.command === 'conserve') {
  // Branch to Conservation workflow (see references/conserve-workflow.md)
  execute_conserve(args);
  return;
}
```

**Step 7: Add Conservation Workflow section**

After the `## Workstyle Workflow` section and before `## Excavation Workflow`, add:

```markdown
## Conservation Workflow

When invoked with `conserve`, execute the conservation workflow.

Read and follow the full specification in `references/conserve-workflow.md`.

Conservation extracts atomic narrative artifacts from project history, generates a default exhibition, and exports to the central work-log. Produces `exhibition.md`, individual artifact files in `artifacts/`, and updates the global artifacts registry. Supports `--no-export` flag.
```

---

### Task 7a: Static validation

**Agent type:** `Explore` (read-only — validation agents must not have write access).

**Files:**
- Read: All modified files for consistency check

**Step 1: Cross-reference check**

Verify all cross-references are consistent:
- `SKILL.md` references `references/conserve-workflow.md` ✓
- `conserve-workflow.md` references `output-templates.md#conserve-completion` ✓
- `consumption-spec.md` references `artifacts/` and `exhibition.md` ✓
- `SCHEMA.md` artifact types match `conserve-workflow.md` agent types ✓
- `survey-workflow.md` `update_local_archaeology_index()` detects artifacts ✓
- XML format consistent between C4 prompts and C5 parsing ✓

**Step 2: Read all modified files end-to-end**

Read each modified file to check for:
- Broken markdown formatting
- Inconsistent type names (must be: shipment, decision, incident, discovery, tale, practice)
- Missing template anchors
- Frontmatter field mismatches between SCHEMA.md and conserve-workflow.md
- XML tag names match between agent prompts and `extract_xml_field()` calls

**Step 3: Run existing validation scripts**

```bash
cd ~/.claude/skills/archaeology
bash scripts/validate-domains.sh 2>&1 || true
```

Confirm existing domains still validate (we didn't break anything).

---

### Task 7b: Live command test

**Requires:** User confirmation before proceeding. This writes real artifact files.

**Agent type:** Main session (skill invocation cannot be delegated to sub-agents).

**Step 1: Confirm with user**

Before running, confirm: "Static validation passed. Ready to test live on `content-management-planning`? This will write artifact files to `.claude/archaeology/`."

**Step 2: Run the command**

Run `/archaeology conserve` on `content-management-planning` (has orchestration and prompting-patterns findings).

**Step 3: Validate output**

Check that:
- `artifacts/` directory contains `art-NNN.md` files with valid frontmatter
- `artifacts/_index.json` exists and `artifact_count` matches file count
- `exhibition.md` exists and links resolve to real artifact files
- Completion display matches the template from `output-templates.md#conserve-completion`

---

### Task 8: Create validate-conserve.sh

**Files:**
- Create: `~/.claude/skills/archaeology/scripts/validate-conserve.sh`

**Agent type:** `shell-scripting:bash-pro` with `shell-scripting:bash-defensive-patterns` skill.

**Context:** Structural validation script for conserve output. Must be bash 3.2 compatible (macOS). Follow patterns from existing `validate-domains.sh`. Two-phase design: Phase 1 (pure bash) runs without dependencies; Phase 2 (jq) runs with graceful degradation if jq is absent.

**Checks:**
1. Artifact frontmatter required fields (`id`, `type`, `title`, `confidence`, `significance`, `conserved_at`, `status`)
2. Enum validation (`type`, `confidence`, `status` against valid values)
3. ID-filename match (frontmatter `id` matches `art-NNN.md` stem)
4. URI format (`arch://{project-slug}/{id}`)
5. Index count parity (`_index.json` `.artifact_count` vs actual `.md` file count) — requires jq
6. Exhibition link integrity (referenced `art-NNN.md` files exist)
7. `_exhibition.json` ID cross-check (all `artifact_ids` have corresponding files) — requires jq
8. Orphan check (every `art-NNN.md` appears in `_exhibition.json`)

**Requirements:**
- `set -euo pipefail` with error accumulation (not early exit on first failure)
- jq guard with graceful degradation (Phase 2 skipped with warning if jq absent)
- `nullglob` for safe globbing
- Exit 0 on pass, exit 1 on any errors
- ~120-150 lines estimated

---

### Post-Review: Skill quality review

**Agent type:** `plugin-dev:skill-reviewer` with `skill-checklist` skill.

**Runs after:** All tasks complete and Task 7b passes.

**Scope:** Review all modified files for:
- Cross-file consistency (type names, template anchors, frontmatter fields)
- Style consistency between conserve-workflow.md and existing workstyle/survey workflows
- SKILL.md routing correctness (command order, trigger phrases, argument-hint)
- Output template compliance

---

## Dependency Graph

```
Task 1 (output-templates.md) ──┐
Task 2 (SCHEMA.md)            ──┤
Task 3 (consumption-spec.md)  ──┼── Task 5 (conserve-workflow.md) ── Task 6 (SKILL.md) ──┬── Task 7a (static) ── Task 7b (live test)
Task 4 (survey-workflow.md)   ──┘                                                         └── Task 8 (validate-conserve.sh)
                                                                                                         │
                                                                                                   Post-Review
```

Tasks 1-4 are independent and can run in parallel. Task 5 depends on templates (Task 1). Task 6 depends on workflow (Task 5). Tasks 7a and 8 can run in parallel after Task 6. Task 7b follows 7a. Post-review follows everything.

## Execution Notes

- **No TDD** — this is a skill (prompt-driven workflow spec), not code with unit tests. Validation is running the command on a real project + validate-conserve.sh.
- **No git** — the skill directory is not a git repo.
- **Parallel opportunity** — Tasks 1-4 are independent file edits dispatched as 4 parallel `implementation-agent` sub-agents.
- **Task 5 is the bulk** — The workflow spec is ~400 lines. Uses `superpowers:executing-plans` for internal step tracking. Source: design doc C1-C7 sections with XML format, type-filtered seed context, anchored overlap distribution, one-shot examples, and per-agent failure diagnostics.
- **Task 6 is surgical** — 7 small edits to SKILL.md. Uses `superpowers:verification-before-completion` to re-read and verify all 7 edits landed.
- **Task 7a is read-only** — `Explore` agent, no write access. Reports issues without fixing them.
- **Task 7b requires user confirmation** — Live test writes real files. Cannot be delegated to sub-agent.
- **Task 8 is new** — validation script for conserve output structure. `shell-scripting:bash-pro` agent.
- **Post-review** — `plugin-dev:skill-reviewer` catches cross-file inconsistencies and style drift.
- **Design doc gaps resolved** — XML tags (not `---ARTIFACT---`), `distribute_sessions()` with anchored overlap, type-specific seed filtering, one-shot examples, per-agent failure diagnostics with 3/5 threshold, `validate_artifact()` layer.
- **XML migration** — Separate plan at `docs/plans/2026-03-07-xml-output-format-migration.md` for converting survey/workstyle to XML format for consistency.
