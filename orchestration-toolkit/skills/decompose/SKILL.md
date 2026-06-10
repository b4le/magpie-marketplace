---
name: decompose
description: Use when the user says "decompose", "break this down", "work breakdown", "plan the work", "create work items", "structure this task", "make an execution plan", "decompose this goal", "split into work packets", or needs to turn a fuzzy goal into structured, agent-ready work items with file ownership and dependency ordering.
argument-hint: "[goal text | file path | handoff path]"
version: 1.0.0
last_updated: 2026-03-13
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Agent
  - Edit
---

# Decompose Skill

Turn a goal into an execution-ready plan with structured work items, specialist agent assignments, and a validation layer. Produces dual output: human-readable markdown + machine-readable JSON.

**This is a heavyweight operation. Explicit invocation only.**

## Quick Reference

```
/decompose "Add user authentication with OAuth"
/decompose ~/specs/feature-design.md
/decompose ~/.claude/handoffs/auth-feature.md
```

## Seven-Phase Workflow

### Phase 1: Parse Input

Accept the goal from one of three sources:

| Source | Detection | Action |
|--------|-----------|--------|
| Inline text | Argument is not a file path | Use directly as goal statement |
| File path | Argument resolves to existing file | Read file, extract goal + requirements |
| Handoff | Path is in `~/.claude/handoffs/` | Read handoff, inherit scope + context |

**Output:** A clear goal statement and a numbered list of requirements.

If the input is ambiguous, ask the user to clarify before proceeding. Do not guess requirements.

---

### Phase 2: Refresh Registry

Run the capability registry to get a fresh view of all available tools:

```bash
~/.claude/scripts/build-capability-registry.sh --quiet
```

After the registry is built, do NOT read the full `capabilities.json` (264KB, ~33K tokens). Instead, use targeted Grep searches for domains relevant to the goal:

1. Identify the primary domains from Phase 1 (e.g., "typescript", "sql", "python", "shell")
2. For each domain, Grep `~/.claude/registry/capabilities.json` for matching `domain_tags`
3. Read only the matching entries to build your agent assignment pool

This reduces registry context from ~33K tokens to ~2-5K tokens depending on domain count.

#### Phase 2 Verification
Before proceeding:
- **Tier 1:** Confirm `~/.claude/registry/capabilities.json` exists and is non-empty. Hard stop if this fails — report that the registry script failed and suggest `--force`.
- **Tier 2:** Review that the registry has a reasonable number of entries (expect 100+). Flag if suspiciously low but proceed.

---

### Phase 3: Codebase Exploration (specialist-assisted)

Map the existing codebase structure relevant to the goal. This phase uses **domain specialist sub-agents** to produce realistic work items — experts in each domain know what files are actually needed, what the real dependencies are, and what realistic complexity looks like.

#### Step 3a: Initial scan
Run a quick Glob/Grep pass to identify the primary domains involved (e.g., TypeScript frontend, Python backend, SQL migrations, infrastructure). Group the goal's requirements by domain.

**Claude Code domain recognition:** Files in these paths constitute a distinct "claude-code" domain and should be tagged as such:
- `~/.claude/skills/`, `~/.claude/hooks/`, `~/.claude/commands/`, `~/.claude/agents/`, `~/.claude/rules/`
- `.claude-plugin/` directories, `CLAUDE.md` project files
- Files named `SKILL.md`, `SCHEMA.md`, `plugin.json`, `settings.json` (when in a Claude Code plugin/skill context)

Tag these as domain `claude-code` so that Step 3b dispatches an agent with CCDK conventions knowledge rather than a generic markdown or JSON specialist.

#### Step 3b: Dispatch domain specialists
For each domain identified, spawn a specialist sub-agent from the registry to explore and assess their domain's portion of the work:

For each domain identified in Step 3a, spawn a specialist sub-agent. Example for a TypeScript domain:

```json
{
  "name": "explore-typescript",
  "subagent_type": "typescript-pro",
  "model": "haiku",
  "description": "Explore TypeScript files for auth refactor",
  "prompt": "You are exploring the TypeScript portion of this codebase for:\nGoal: Add OAuth authentication\nRequirements: support Google + GitHub providers, session handling, protected routes\n\nYour task:\n1. Read the files in src/auth/, src/middleware/, src/routes/\n2. For each file that needs changes, produce a manifest entry:\n   - path, action (create|modify|delete), description, depends_on[], complexity\n3. Flag realistic gotchas and hidden dependencies\n\nReturn a JSON array of manifest entries."
}
```

Adapt `name`, `subagent_type`, `description`, and `prompt` for each domain (backend, sql, infra, etc.). Use the best Explore-capable specialist from the registry for each domain.

Collect all specialist outputs. Merge into a single file manifest. Resolve cross-domain dependencies (e.g., frontend → backend API types).

**When to use specialists vs. self:** If the goal touches ≤2 domains or ≤5 files total, skip sub-agents and do the exploration directly. Sub-agents add value when domain expertise matters for realistic estimates.

#### Step 3c: Merge and reconcile
Combine specialist outputs into a single file manifest. Resolve cross-domain dependencies (e.g., a frontend file depending on a backend API type). Flag conflicts where specialists disagree on boundaries.

**Output:** A file manifest — one entry per file that will be created or modified:

```
path, action (create|modify|delete), domain, description, depends_on[], complexity (low|medium|high)
```

Guidelines:
- Follow existing project conventions for file placement and naming
- Check for related test files — if modifying `foo.ts`, check if `foo.test.ts` exists
- Include configuration files if the feature requires new config
- Mark `depends_on` when a file imports types/functions from another file in the manifest
- Trust specialist assessments on complexity — they know their domain's gotchas

---

### Phase 4: Agent Matching (Intent-Driven)

You are the router. Instead of mechanical file-extension lookups, reason about what expertise each group of files actually needs, then find the best specialist.

#### Step 4a: Intent classification

For each logical group of files from the manifest (grouped by domain from Phase 3), write a 1-sentence intent statement describing what expertise the work requires. Operate at the group level, not per-file. Examples:
- "Author a Claude Code skill with SKILL.md and reference files"
- "Write a defensive shell script for a SessionStart hook"
- "Implement TypeScript React components for the settings page"
- "Create database migration SQL files"
- "Design a REST API contract with OpenAPI schema"

#### Step 4b: Semantic registry search

For each intent statement, extract 2-4 keywords and Grep `~/.claude/registry/capabilities.json` for them across both `description` and `domain_tags` fields. Read the top 5-10 matching capability entries. The registry has hundreds of entries with rich descriptions — use them.

```bash
# Example: intent is "Write a defensive shell script for a SessionStart hook"
# Search for: "shell", "bash", "hook", "defensive"
```

This replaces exact domain_tag matching with semantic search that leverages the registry's detailed descriptions.

#### Step 4c: Agent + skill selection

From the registry matches, reason about the best fit for each group:

- **Agent:** Which agent best matches the work intent? Prefer specialists (`*-pro`, domain-specific) over generic types. Consider the agent's description, not just its name.
- **Skills:** Which skills should layer on? Skills are additive — select all that are relevant to the intent.
- **Model tier:** Use specialist-routing heuristics — opus for complex reasoning/design, sonnet for standard implementation, haiku for mechanical/formatting tasks.

**Fallback chain:**

Agent selection MUST follow the specialist-routing.md decision tree (Steps 2A→2D). The fallback chain below applies only after exhausting all steps.

1. If semantic search returns good matches with `enabled: true` → use them.
2. If search is inconclusive → consult `references/domain-routing.md` as a heuristic fallback.
3. If nothing matches after exhausting specialist-routing.md Steps 2A→2D → `general-purpose` (sonnet) for implementation, `general-purpose` (opus) for design/research. Set `missing_specialist: true` and log: "No specialist match: [reason]. Falling back to [agent]."

#### Step 4d: Produce agent_config

For each file group, produce an `agent_config`:
```json
{
  "subagent_type": "shell-scripting:bash-pro",
  "skills": ["claude-code-development-kit:understanding-hooks", "shell-scripting:bash-defensive-patterns"],
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 30,
  "missing_specialist": false,
  "isolation": "none"
}
```

Set `missing_specialist: true` when a good specialist was found but is disabled/unavailable.

Set `isolation: "worktree"` when multiple agents in the same execution phase will edit files in overlapping directory trees — this signals the orchestrator to check out separate git worktrees so agents don't stomp each other's writes.

#### Phase 4 Verification
Before proceeding:
- **Tier 1:** Every file in the manifest has an `agent_config` with a non-empty `subagent_type`. Every group has an intent statement. Hard stop if any file is unassigned.
- **Tier 2:** Check that agent assignments are not uniformly generic. If >70% of work items use `general-purpose`, the semantic search likely underperformed — go back to Step 4b with broader keywords and re-run. Flag and self-correct mismatches.

---

### Phase 5: Work Item Grouping

Group files into work items by agent + domain affinity, respecting dependencies:

**Rules:**
1. **Single-owner:** Every file appears in exactly one work item. No shared files.
2. **Agent coherence:** All files in a work item use the same agent config.
3. **Dependency respect:** If file A depends on file B, either put them in the same work item OR ensure B's work item is in an earlier execution phase.
4. **Size cap:** 1-8 files per work item. Split if too large.
5. **Test co-location:** Prefer grouping implementation files with their test files.

For each work item, define:
- `id`: `WI-{N}` (sequential)
- `title`: Short descriptive name
- `scope`: One-sentence statement of what this item produces
- `files[]`: Owned files from the manifest
- `agent_config`: From Phase 4
- `pipeline[]`: Ordered steps (typically: read context → implement → test → verify)
- `inputs`: Context files the agent should read (read-only, not owned)
- `interface_contracts`: What this item exports (for dependents) and imports (from dependencies)
- `done_criteria[]`: Verifiable completion checks
- `depends_on[]`: Other work item IDs that must complete first
- `estimated_minutes`: 5-35 minute range

**Execution phases:** Topologically sort work items by dependencies. Items with no mutual dependencies go in the same phase and can run in parallel.

---

### Phase 6: Validation Layer

For each implementation work item, assign a review agent:

| Implementation agent | Review agent | Review skills |
|---------------------|-------------|---------------|
| Any `*-pro` type | Explore | comprehensive-review |
| general-purpose | Explore | comprehensive-review |
| test-runner | Explore | — |
| general-purpose | Explore | — |

*Fallback agents (`general-purpose`, `general-purpose`) should appear only with `missing_specialist: true`. If >30% of work items use fallback agents, revisit Phase 4 agent matching.*

**Validation mode:**
- `after_complete` (default): Review runs immediately after the implementation agent finishes. Use for items that block other items.
- `batch`: Review runs after all items in the execution phase complete. Use for independent items in the same phase.

For each validation entry, define specific checks based on the work item's domain:
- Type safety (TypeScript/typed languages)
- Test coverage (implementation files)
- Security review (auth, crypto, permissions)
- API contract compliance (API endpoints)
- Convention adherence (all files)

---

### Phase 7: Plan Assembly

Produce two output files:

**Location:** `~/.claude/decompose/plans/{plan-id}/`

Each plan gets its own directory. The `plan-id` is `decompose-{YYYYMMDD}-{HHMMSS}`. If a collision occurs (two decompose runs in the same second), append a 4-character random suffix: `decompose-{YYYYMMDD}-{HHMMSS}-{xxxx}`.

#### 7a. Markdown output (`plan.md`)

```markdown
# Decompose Plan: {goal summary}

**Plan ID:** {plan-id}
**Created:** {timestamp}
**Total work items:** {N}
**Execution phases:** {N}
**Estimated duration:** {N} minutes

## Goal
{goal statement}

## Requirements
{numbered requirements list}

## File Manifest
| File | Action | Domain | Complexity | Work Item |
|------|--------|--------|------------|-----------|
{one row per file}

## Work Items

### WI-1: {title}
**Agent:** {subagent_type} (model: {model})
**Files:** {file list}
**Depends on:** {dependency list or "none"}
**Pipeline:**
1. {step}
2. {step}
**Done criteria:**
- [ ] {criterion}

{repeat for each work item}

## Execution Phases

### Phase 1 (parallel)
{work items in this phase}

### Phase 2 (parallel)
{work items in this phase}

## Validation
{validation assignments}

## Execution Options
- **Fan-out:** Use `{plugin}/references/fan-out-pattern.md` — each phase becomes a parallel Agent dispatch
- **Team-spawn:** Use `/team-spawn feature` — work items become TaskCreate entries with dependencies
- **Manual:** Execute work items one at a time in phase order
```

#### 7b. JSON output (`plan.json`)

Follow the schema defined in `references/plan-schema.md` exactly.

- Write `"schema_version": "1.0"` as the first field in the JSON output.
- Populate `"source"` from the Phase 1 input type detection: `{"type": "inline|file|handoff", "path": "<file path if applicable, omit for inline>"}`.

#### Phase 7 Verification
Before finishing:
- **Tier 1:** Both output files exist and are non-empty. JSON validates with `jq empty`. Hard stop if either fails.
- **Tier 2:** Every file in the manifest appears in exactly one work item. No work item exceeds 35 minutes estimated. Agent assignments match domain-routing expectations. Execution phases respect all dependency ordering.

---

## Invariants

These must hold in the final output. If any are violated, self-correct before producing the plan:

1. **Single-owner files:** Every manifest file appears in exactly one work item
2. **Complete coverage:** Every manifest file is in a work item
3. **DAG validity:** No circular dependencies between work items
4. **Phase ordering:** Execution phases respect all `depends_on` relationships
5. **Size bounds:** Every work item has 1-8 files and ≤35 min estimated duration
6. **Agent validity:** Every `subagent_type` is in the registry or is a known built-in
7. **Validation coverage:** Every implementation work item has a validation entry
