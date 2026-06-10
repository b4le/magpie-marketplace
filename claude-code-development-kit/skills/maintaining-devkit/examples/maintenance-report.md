<!-- Example output from a `full` maintenance run of the devkit-maintainer agent -->
<!-- Generated: 2026-03-01 | Mode: full -->

DEVKIT-MAINTAINER REPORT
========================
Mode: full
Status: PASSED — 0 errors, 2 warnings, 1 auto-fix
Date: 2026-03-01

---

## Validation Results

### validate-plugin.sh — claude-code-development-kit

File: `claude-code-development-kit/.claude-plugin/plugin.json`

```
[PASS] plugin.json exists
[PASS] plugin.json is valid JSON
[PASS] plugin.json passes schema validation
[PASS] Required field 'name': claude-code-development-kit
[PASS] Field 'version': 2.0.0
[PASS] Field 'description' present
[PASS] README.md exists
[INFO] README.md has 142 lines
[PASS] README contains installation information
[PASS] Skill passed: skills/authoring-skills
[PASS] Skill passed: skills/creating-commands
[PASS] Skill passed: skills/creating-plugins
[PASS] Skill passed: skills/understanding-hooks
[PASS] Skill passed: skills/managing-memory
[PASS] Skill passed: skills/authoring-agents
[PASS] Skill passed: skills/maintaining-devkit
[PASS] Command passed: commands/available-skills.md
[PASS] Command passed: commands/migrate-to-skill.md
[PASS] Command passed: commands/skill-checklist.md
[PASS] Output style passed: output-styles/analytical-documentation.md
[PASS] No personal identifiers found in plugin

Structure Errors: 0
Structure Warnings: 0
Component Failures: 0
VALIDATION PASSED
```

Result: PASS

---

### validate-plugin.sh — knowledge-harvester

File: `knowledge-harvester/.claude-plugin/plugin.json`

```
[PASS] plugin.json exists
[PASS] plugin.json is valid JSON
[PASS] plugin.json passes schema validation
[PASS] Required field 'name': knowledge-harvester
[WARN] Field 'version' missing from plugin.json
[PASS] Field 'description' present
[PASS] README.md exists
[INFO] README.md has 38 lines
[PASS] README contains installation information
[PASS] Skill passed: skills/harvest
[PASS] Agent passed: agents/extractor.md
[PASS] Agent passed: agents/synthesizer.md
[WARN] Agent passed with warning: agents/triage-scorer.md
      [WARN] Model specified without rationale explanation
[PASS] No personal identifiers found in plugin

Structure Errors: 0
Structure Warnings: 2
Component Failures: 0
VALIDATION PASSED WITH WARNINGS
```

Result: PASS WITH WARNINGS
- W1: `knowledge-harvester/.claude-plugin/plugin.json` — `version` field missing
- W2: `knowledge-harvester/agents/triage-scorer.md` — `model: haiku` set without `model_rationale`

---

## Schema Drift

Checked: 2026-03-01
Last sync: 2026-02-15 (per `scripts/expected-fields.json` `_updated` field)
Changelog entries scanned: v2.1.65 through v2.1.69

### agent-frontmatter.schema.json

Status: DRIFT DETECTED

| Field | Expected | Actual | Action |
|-------|----------|--------|--------|
| `context_window` | not present | new field in v2.1.67 | ADD |
| All other fields | match | match | OK |

Details: Claude Code v2.1.67 added a `context_window` field to agent frontmatter,
allowing agents to request a larger context allocation. Current schema does not
include this field; any agent file using it will fail schema validation with
"Additional property not allowed: context_window".

Proposed patch for `schemas/agent-frontmatter.schema.json`:
```json
"context_window": {
  "type": "integer",
  "description": "Maximum context window size in tokens requested for this agent.",
  "minimum": 1024,
  "maximum": 200000,
  "examples": [32000, 100000]
}
```
Status: FLAGGED FOR MANUAL REVIEW (structural addition to a strict schema)

### plugin.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

### command-frontmatter.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

### hooks.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

### skill-frontmatter.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

### output-style-frontmatter.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

### marketplace.schema.json

Status: CLEAN — all fields match expected-fields.json snapshot

---

## Changelog Impact

Changelog range: v2.1.65 – v2.1.69 (since last sync 2026-02-15)

### New features detected

| Version | Feature | Impact |
|---------|---------|--------|
| v2.1.67 | Agent `context_window` frontmatter field | Schema update needed (see Schema Drift above) |
| v2.1.68 | `/team-spawn` command alias for team creation | No schema impact; consider updating `understanding-hooks` skill to mention team lifecycle hooks |
| v2.1.69 | `WorktreeCreate` / `WorktreeRemove` hook events | Already in `hooks.schema.json` — no action needed |

### Deprecations detected

None.

### Breaking changes detected

None.

### Adoption opportunities

- v2.1.68 `/team-spawn` preset support: The `using-commands` skill currently does not
  mention `/team-spawn`. Consider adding a note in the Team Commands section.

---

## Setup Hygiene

Checked: `~/.claude/`

### Stale plugins

```
find ~/.claude/todos -name '*.json' -size -4c | wc -l
→ 3 empty todo files found
```

Empty todo files (safe to delete):
- `~/.claude/todos/session-2026-01-14.json` (0 bytes)
- `~/.claude/todos/session-2026-01-22.json` (2 bytes)
- `~/.claude/todos/session-2026-02-03.json` (3 bytes)

### Disabled plugins

```
grep '"enabled": false' ~/.claude/installed_plugins.json
→ 1 disabled plugin found
```

Disabled plugins:
- `plugin-profile` — disabled since 2026-01-30. If no longer needed, remove the entry to reduce install noise.

### Orphaned teams

No teams with session activity older than 30 days found.

### Disk usage

```
du -sh ~/.claude/
→ 847M  ~/.claude/
```

Breakdown:
| Directory | Size | Notes |
|-----------|------|-------|
| `~/.claude/projects/` | 612M | Project memory and cache files |
| `~/.claude/todos/` | 14K | Includes 3 empty files (see above) |
| `~/.claude/agents/` | 92K | Active custom agents |
| `~/.claude/plugins/` | 228M | Installed plugin source trees |
| Other | 7M | Settings, logs |

No anomalous disk usage detected.

### Settings drift

Compared `~/.claude/settings.json` against project-level `.claude/settings.json` in
`claude-code-development-kit/`:

| Setting | Global | Project | Note |
|---------|--------|---------|------|
| `model` | `sonnet` | not set | OK — project inherits global |
| `autoApprove` | `false` | `true` | Drift — project overrides global |
| `verboseLogging` | `false` | not set | OK |

Drift finding: `autoApprove` is enabled at project level but disabled globally.
This is intentional for the devkit project (reduces friction during schema updates)
but worth confirming.

---

## Auto-Fixes Applied

### Fix 1 of 1

File: `knowledge-harvester/agents/triage-scorer.md`

What changed: Added `model_rationale` field to agent frontmatter.

Before:
```yaml
---
name: triage-scorer
description: Scores and prioritises harvested knowledge items by relevance and quality. Use when ranking a batch of extracted content for downstream synthesis.
tools: [Read, Grep]
model: haiku
---
```

After:
```yaml
---
name: triage-scorer
description: Scores and prioritises harvested knowledge items by relevance and quality. Use when ranking a batch of extracted content for downstream synthesis.
tools: [Read, Grep]
model: haiku
model_rationale: Uses haiku for fast, low-cost scoring of large batches of knowledge items where deep reasoning is not required.
---
```

Why it was safe: `model_rationale` is an optional documentation field with no runtime effect.
Adding it resolves the validator warning without changing agent behaviour. The rationale
text was inferred from the agent's description and is accurate to the use case.

Post-fix re-validation: PASS (warning cleared)

---

## Recommendations

### Manual fixes needed

**REC-01 (MEDIUM): Update `schemas/agent-frontmatter.schema.json` to add `context_window` field**

Claude Code v2.1.67 added `context_window` as a valid agent frontmatter field. The current
schema will reject any agent file that uses it with an additionalProperties error. Review the
proposed patch in the Schema Drift section and apply after confirming field semantics.

Files to change:
- `claude-code-development-kit/schemas/agent-frontmatter.schema.json` — add `context_window` property
- `claude-code-development-kit/scripts/expected-fields.json` — add `context_window` to the
  `agent-frontmatter.schema.json` properties list and update `_updated` to today's date

**REC-02 (LOW): Add `version` field to `knowledge-harvester/.claude-plugin/plugin.json`**

The `version` field is strongly recommended by the plugin schema. Without it, the plugin
cannot participate in version-gated marketplace features. Suggested value: `0.1.0`.

File to change: `knowledge-harvester/.claude-plugin/plugin.json`

### Feature adoption suggestions

**REC-03 (LOW): Mention `/team-spawn` in `skills/using-commands/SKILL.md`**

v2.1.68 added `/team-spawn <preset>` as the canonical way to start multi-agent teams.
The `using-commands` skill's Team Commands section currently only mentions `/team` and
`/team-list`. Add a line noting that `/team-spawn` is the preferred initiation command
for preset-based teams.

File to change: `claude-code-development-kit/skills/using-commands/SKILL.md`

### Cleanup actions

**REC-04 (LOW): Delete 3 empty todo files**

The following files in `~/.claude/todos/` are empty or near-empty and can be safely deleted:
- `~/.claude/todos/session-2026-01-14.json`
- `~/.claude/todos/session-2026-01-22.json`
- `~/.claude/todos/session-2026-02-03.json`

Run: `find ~/.claude/todos -name '*.json' -size -4c -delete`

**REC-05 (LOW): Review disabled `plugin-profile` entry**

`plugin-profile` has been disabled in `~/.claude/installed_plugins.json` since 2026-01-30.
If it is no longer needed, remove the entry to keep the installed plugins list clean.
If it will be re-enabled, no action needed.
