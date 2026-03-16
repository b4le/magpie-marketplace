---
name: maintaining-devkit
description: This skill should be used when the user asks to "maintain the dev-kit", "audit plugin health", "sync schemas with changelog", "check for schema drift", "cleanup setup", "run devkit maintenance", "find gaps", "check coverage", "what features are missing", or needs structured playbooks for devkit maintenance modes.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebFetch
  - WebSearch
version: 1.0.0
created: 2026-03-05
last_updated: 2026-03-06
tags:
  - maintenance
  - validation
  - schemas
  - devkit
---

# Maintaining the Development Kit

Structured playbooks for maintaining the claude-code-development-kit plugin and ~/.claude/ setup.

## When to Use This Skill

- Running devkit maintenance (audit, sync, validate, cleanup, or full pass)
- Checking plugin health or schema drift
- Syncing schemas with changelog entries
- Cleaning up setup or adopting new features

### Do NOT Use This Skill When

- Authoring new skills, agents, or commands (use the respective authoring skills)
- Debugging Claude Code issues (use `resolving-claude-code-issues`)
- Learning about plugin structure (use `creating-plugins`)

## Mode Quick Reference

| Mode | Trigger | Steps | Output |
|------|---------|-------|--------|
| `audit` | "audit", "validate all", "health check" | Run all validators → aggregate results | Pass/fail per component |
| `sync` | "sync schemas", "check changelog", "update schemas" | Fetch changelog → diff schemas → flag gaps | Schema drift report |
| `validate` | "validate [component]", "check [skill/agent]" | Run targeted validator → report | Component-specific results |
| `cleanup` | "cleanup", "hygiene", "disk usage" | Audit ~/.claude/ → report stale items | Hygiene recommendations |
| `gaps` | "find gaps", "check coverage", "what's missing" | Roadmap + skills vs latest features | Untracked feature report |
| `full` | "full maintenance", "run everything" | All modes in sequence | Comprehensive report |

## Mode: Audit

Run all validators against current plugin components to detect structural issues.

1. Run plugin validator: `bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}`
2. Run schema drift check: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh`
3. Run reference validator: `bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-references.sh ${CLAUDE_PLUGIN_ROOT}`
4. Run structure validator: `bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-structure.sh ${CLAUDE_PLUGIN_ROOT}`
5. Aggregate results into a single report with pass/fail per check

For details on each validator, see the Validator Quick Reference section below.

## Mode: Sync

Automated changelog-to-schema sync analysis. Uses `analyze-sync.sh` to fetch releases, scan for signal phrases, and cross-reference against schemas.

1. Run the automated analysis:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-sync.sh
   ```
   This produces a categorized checklist: Action Required, Needs Review, Already Covered, Informational.
2. Review **Action Required** items — these are confirmed schema gaps. Apply safe patches (new enum values, new optional fields).
3. Review **Needs Review** items — signal phrases matched but the field name could not be auto-extracted. Manually inspect the changelog entry.
4. Run the drift check to update expected-fields.json:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh --update
   ```
5. Re-validate the plugin:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}
   ```

For detailed sync procedures and manual fallback steps, see `references/changelog-sync-playbook.md`.

For guidance on evaluating whether to adopt new features, see `references/feature-adoption-guide.md`.

## Mode: Validate

Run a targeted validator against a specific component.

1. Identify the component type from user input (agent, skill, command, hook, output-style, plugin)
2. Locate the corresponding validator script:
   - Agent: `evals/validate-agent.sh <path>`
   - Skill: `evals/validate-skill.sh <path>`
   - Command: `evals/validate-command.sh <path>`
   - Hook: `evals/validate-hook.sh <path>`
   - Output style: `evals/validate-output-style.sh <path>`
   - Plugin: `evals/validate-plugin.sh <path>`
3. Run the validator and capture output
4. Parse results into structured findings
5. If validation fails: identify the root cause, check if auto-fixable, apply or flag

## Mode: Cleanup

Audit ~/.claude/ for accumulated entropy and recommend cleanup actions.

1. Count stale items:
   - Empty todo files: `find ~/.claude/todos -name '*.json' -size -4c | wc -l`
   - Disabled plugins: grep `"enabled": false` in installed_plugins.json
   - Orphaned teams: teams with no session activity >30 days
2. Measure disk usage: `du -sh ~/.claude/` broken down by subdirectory
3. Check settings drift: compare global settings.json against project-level overrides
4. Identify stale plugin references: plugins in installed_plugins.json that no longer exist on disk
5. Generate prioritized recommendations (HIGH/MEDIUM/LOW)

For detailed cleanup procedures, see `references/setup-hygiene-checklist.md`.

## Mode: Gaps

Cross-reference the roadmap and existing skills against the latest Claude Code releases to find untracked capabilities.

1. **Build coverage inventory:**
   - Read the roadmap: `${CLAUDE_PLUGIN_ROOT}/docs/roadmap.md`
   - List all existing skills: `Glob ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md`
   - Extract each skill's `description` from YAML frontmatter
   - Build combined topic set: roadmap items + existing skill topics

2. **Fetch latest features (last 90 days):**
   - WebSearch: `site:github.com/anthropics/claude-code/releases`
   - WebFetch the releases page; extract feature names by category (tools, hooks, agents, MCP, CLI, UI, settings, plugins, skills)

3. **Cross-reference each feature:**
   - Search skill descriptions and reference file contents for coverage
   - Search roadmap items and sub-problems for tracking
   - If neither → classify as **untracked gap**

4. **Classify each gap:**
   - **Extends existing theme** → recommend adding as sub-problem to relevant roadmap item
   - **New theme needed** → recommend new roadmap theme with problem statement
   - **Existing skill stale** → recommend refresh with specific missing content

5. **Validate before recommending:**
   Before proposing a new roadmap item, confirm:
   - The feature is in a **published release** (not just a PR or issue)
   - The feature is **user-facing** (not internal refactoring or bug fixes)
   - The feature is **not already covered** by reference file content (search content, not just titles)
   - The feature has **enough substance** for at least a reference file (not a one-line config change)

6. **Report** using the Coverage Gaps section of the standard output format.

For the current roadmap and gap analysis context, see:
- Roadmap: `${CLAUDE_PLUGIN_ROOT}/docs/roadmap.md`
- Gap analysis: `${CLAUDE_PLUGIN_ROOT}/docs/2026-03-11-devkit-gap-analysis.md`

## Mode: Full

Run all modes in sequence: audit → sync → validate → cleanup → gaps.

1. Run `audit` mode — capture report section
2. Run `sync` mode — capture report section
3. Run `validate` on any components that failed audit — capture report section
4. Run `cleanup` mode — capture report section
5. Run `gaps` mode — capture report section
6. Merge all sections into comprehensive maintenance report
7. Apply safe auto-fixes; re-validate fixed components
8. Present final report with summary statistics

## Auto-Fix Catalog

Safe to auto-fix without confirmation:

| Pattern | Fix | Example |
|---------|-----|---------|
| Missing `version` field | Add `version: 1.0.0` | Agent without version |
| Field name case mismatch | Normalize to schema case | `max-turns` → `maxTurns` |
| Kebab-case violation in name | Convert to kebab-case | `myAgent` → `my-agent` |
| Missing `model_rationale` | Add placeholder comment | When `model` is set |
| Outdated tool enum ref | Update to current tools-enum.json | Renamed built-in tool |

For the complete auto-fix catalog with examples, see `references/auto-fix-catalog.md`.

## Validator Quick Reference

| Validator | Path | Checks |
|-----------|------|--------|
| validate-plugin.sh | `evals/validate-plugin.sh` | plugin.json, README, referenced components |
| validate-skill.sh | `evals/validate-skill.sh` | SKILL.md, frontmatter, line count, @path imports |
| validate-agent.sh | `evals/validate-agent.sh` | Frontmatter, tools, model, name match |
| validate-command.sh | `evals/validate-command.sh` | Frontmatter, arguments, description |
| validate-hook.sh | `evals/validate-hook.sh` | Shebang, executable bit, safe practices |
| validate-output-style.sh | `evals/validate-output-style.sh` | Structure, headings, directives |
| validate-references.sh | `evals/validate-references.sh` | @path imports resolve |
| validate-structure.sh | `evals/validate-structure.sh` | Directory layout conventions |
| validate-marketplace.sh | `evals/validate-marketplace.sh` | marketplace.json, plugin refs |
| check-schema-drift.sh | `scripts/check-schema-drift.sh` | Schema fields vs expected-fields.json |

## Example Reports

For example output from each mode, see:
- Full maintenance report: `examples/maintenance-report.md`
- Schema sync report: `examples/schema-diff-example.md`

## Related Components

- **Agent:** `devkit-maintainer` — automated maintenance agent that uses this skill
- **Command:** `/devkit-maintain` — slash command entry point for maintenance runs
