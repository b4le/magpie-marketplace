# Changelog Sync Playbook

**Purpose**: Step-by-step procedure for fetching the Claude Code changelog, comparing it against the devkit schemas, and producing a schema drift report with concrete patch recommendations.

---

## 1. Locate the Changelog

Claude Code publishes its changelog in three places. The Releases API is preferred because it includes dates and structured bodies:

| Source | URL | Notes |
|--------|-----|-------|
| GitHub Releases API (primary) | `api.github.com/repos/anthropics/claude-code/releases` | Has `published_at` dates, structured JSON |
| GitHub releases page | `https://github.com/anthropics/claude-code/releases` | Human-readable |
| Raw CHANGELOG.md (fallback) | `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` | May lack dates |

Use the built-in fetch script rather than curling manually — it handles auth, retries, and fallback URLs automatically:

```bash
# Show entries since the last sync date recorded in expected-fields.json
bash ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-changelog.sh --since 2026-03-05

# Show the 3 most recent versions (no --since flag)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-changelog.sh

# Show raw markdown for manual inspection
bash ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-changelog.sh --since 2026-01-01 --raw

# Authenticate to avoid GitHub rate-limiting
GITHUB_TOKEN=ghp_xxx bash ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-changelog.sh --since 2026-03-01
```

The `--since` date should match the `_updated` field in `scripts/expected-fields.json`. This ensures you only process versions released after the last sync.

---

## 2. Determine the Last Sync Date

Read the `_updated` field from `expected-fields.json` to find when the devkit was last synced against the changelog:

```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/scripts/expected-fields.json') as f:
    data = json.load(f)
print('Last sync:', data.get('_updated', 'not recorded'))
"
```

Pass this date to `fetch-changelog.sh --since <date>` to retrieve only new entries.

---

## 2.5 Automated Sync Analysis

For most sync runs, use `analyze-sync.sh` which automates steps 3–7 below:

```bash
# Run with default since-date from expected-fields.json
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-sync.sh

# Override since-date
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-sync.sh --since 2026-03-04

# JSON output for programmatic use
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-sync.sh --json

# Write report to file
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-sync.sh --output /tmp/sync-report.md
```

The script runs a five-stage pipeline:
1. Reads the sync window from `expected-fields.json`
2. Fetches changelog entries via `fetch-changelog.sh --json`
3. Scans each bullet line for signal phrases (hook events, fields, tools, models, etc.)
4. Cross-references matches against current schemas to classify as gap vs already-covered
5. Generates a categorized checklist (Action Required / Needs Review / Already Covered / Informational)

**After running**: review the Action Required items, apply patches, then run `check-schema-drift.sh --update` and `validate-plugin.sh`.

---

## 3. Parse Version Entries and Extract Feature Deltas (Manual Fallback)

> **Note:** Steps 3–4 are automated by `analyze-sync.sh`. Use the manual procedure below only if the automated script is unavailable or for edge cases it cannot handle.

Each changelog version entry follows this structure:

```
## [1.2.3] - 2026-02-15

### Features
- New hook event: WorktreeCreate fires when a git worktree is created
- pathPattern support in hooks for tool-name matching

### Bug Fixes
- Fixed SessionStart not firing on plugin reload

### Breaking Changes
- Renamed PostToolUseFailure to PostToolError (reverted in 1.2.4)
```

Extract changes relevant to the devkit by scanning for these signal phrases:

| Signal phrase | Schema area to check |
|---------------|---------------------|
| "hook event" / "new event" | `hooks.schema.json` → `hooksMap` pattern |
| "hook type" / "new hook type" | `hooks.schema.json` → `hookHandler.oneOf` |
| "hook property" | `hooks.schema.json` → `hookHandler` definitions |
| "agent field" / "agent property" | `agent-frontmatter.schema.json` |
| "skill field" / "skill property" | `skill-frontmatter.schema.json` |
| "plugin field" / "plugin.json" | `plugin.schema.json` |
| "command field" | `command-frontmatter.schema.json` |
| "tool name" / "renamed tool" | `schemas/tools-enum.json` |
| "model" / "new model" | `agent-frontmatter.schema.json` → `model.enum` |
| "permissionMode" | `agent-frontmatter.schema.json` |
| "settings" / "settings.json" | `plugin.schema.json` (check for new top-level field) |

---

## 4. Schema-to-Changelog Mapping (Manual Fallback)

> **Note:** This mapping is automated by `analyze-sync.sh`. Use manually only as a reference or fallback.

Use this table to translate changelog mentions into specific schema locations:

### hooks.schema.json

| Changelog mention | Schema location | What to update |
|-------------------|-----------------|----------------|
| New hook event (e.g., WorktreeCreate) | `definitions.hooksMap.patternProperties` key regex | Add event name to the regex alternation |
| New hook type (e.g., `http`) | `definitions.hookHandler.oneOf` | Add a new oneOf entry with required/properties |
| New hook property on existing type | `definitions.hookHandler.oneOf[*].properties` | Add property to the matching type object |
| pathPattern support | `definitions.hookEntry.properties` | Add `pathPattern` string property |
| `once` property | `definitions.hookHandler.oneOf[*].properties` | Already present — verify it is listed |

### agent-frontmatter.schema.json

| Changelog mention | Schema location | What to update |
|-------------------|-----------------|----------------|
| New model shorthand | `properties.model.enum` | Add new shorthand string |
| New permissionMode value | `properties.permissionMode.enum` | Add new string |
| New top-level agent field | `properties` | Add new property definition |

### skill-frontmatter.schema.json

| Changelog mention | Schema location | What to update |
|-------------------|-----------------|----------------|
| New skill field | `properties` | Add new property definition |
| CLAUDE_SKILL_DIR variable | `properties` (environment docs only) | No schema change required — document in SKILL.md |

### plugin.schema.json

| Changelog mention | Schema location | What to update |
|-------------------|-----------------|----------------|
| New plugin.json field | `properties` | Add new property definition |
| Plugin settings.json | `properties.settings` | Add settings object if not present |

### tools-enum.json

| Changelog mention | Location | What to update |
|-------------------|----------|----------------|
| Tool renamed | `definitions.toolName.enum` | Update old name → new name, add alias if needed |
| New built-in tool | `definitions.toolName.enum` | Add new tool name string |

---

## 5. Run the Schema Drift Check

After identifying candidate changes, run the drift checker to see what the current schemas declare vs what `expected-fields.json` records:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh
```

Interpret the output:

- `OK` — schema matches expected-fields.json (no drift)
- `NEW <field>` — schema has a field not yet in expected-fields.json; likely a change you added
- `MISS <field>` — expected-fields.json has a field the schema no longer declares; likely a removal

---

## 6. Generate a Schema Patch for New Optional Fields

For **new optional fields** (safe to add without confirmation), follow this pattern:

1. Open the relevant schema file.
2. Add the new property inside `"properties": { ... }` with the correct type, description, and constraints.
3. Do NOT add it to `"required"` unless the changelog says it is required.
4. Do NOT change `"additionalProperties"` — it is already `false` for all devkit schemas.
5. Update `scripts/expected-fields.json` to include the new field:

```bash
# Regenerate expected-fields.json from current schemas (after editing the schema)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh --update
```

**Example: adding a new optional `pathPattern` field to hook entries**

Before (in `hooks.schema.json`):
```json
"hookEntry": {
  "type": "object",
  "required": ["hooks"],
  "additionalProperties": false,
  "properties": {
    "matcher": { "type": "string" },
    "hooks": { ... }
  }
}
```

After:
```json
"hookEntry": {
  "type": "object",
  "required": ["hooks"],
  "additionalProperties": false,
  "properties": {
    "matcher": { "type": "string" },
    "pathPattern": {
      "type": "string",
      "description": "Glob pattern matched against the file path argument of the triggering tool call. Only fires the hook when both matcher and pathPattern match.",
      "examples": ["**/*.ts", "src/**"]
    },
    "hooks": { ... }
  }
}
```

---

## 7. Flag Structural Changes for Manual Review

The following types of changes are NOT safe to auto-apply. Flag them in the maintenance report with severity `MANUAL-REVIEW`:

| Change type | Reason | Example |
|-------------|---------|---------|
| Required field added | Would break existing valid files | New required field in `plugin.schema.json` |
| Field renamed | Old files become invalid | `PostToolError` replacing `PostToolUseFailure` |
| Field type changed | Existing values may not validate | `model` changing from enum to string |
| `additionalProperties` changed | Affects all downstream validators | `false` → `true` or vice versa |
| Schema file added or removed | Requires validator script updates | New `worktree.schema.json` |
| Tool enum value removed | Agents using the removed tool fail validation | `FileStat` removed from tools-enum.json |

When flagging, include:
- The schema file affected
- The changelog version that introduced the change
- The specific diff (before/after)
- The impact on existing plugin files

---

## 8. Example: Detecting a New Hook Event Type

**Scenario**: The changelog for version 1.5.0 says:

> Added `WorktreeCreate` and `WorktreeRemove` hook events that fire when git worktrees are created or removed.

**Step 1**: Check if these events are already in `hooks.schema.json`:

```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/hooks.schema.json') as f:
    s = json.load(f)
pattern = list(s['definitions']['hooksMap']['patternProperties'].keys())[0]
print(pattern)
"
```

**Step 2**: If absent, locate the regex in `hooks.schema.json`:

```json
"^(SessionStart|UserPromptSubmit|PreToolUse|...)(\\/[a-zA-Z0-9_*-]+)?$"
```

**Step 3**: Add the new events to the alternation group:

```json
"^(SessionStart|UserPromptSubmit|PreToolUse|PermissionRequest|PostToolUse|PostToolUseFailure|Notification|SubagentStart|SubagentStop|Stop|TeammateIdle|TaskCompleted|ConfigChange|WorktreeCreate|WorktreeRemove|PreCompact|SessionEnd)(\\/[a-zA-Z0-9_*-]+)?$"
```

**Step 4**: Also update the `description` field of `hooksMap` which lists known events as a human-readable comment:

```json
"description": "Map of hook event names to arrays of matcher/handler entries. Known events: SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure, Notification, SubagentStart, SubagentStop, Stop, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove, PreCompact, SessionEnd."
```

**Step 5**: Run the drift check and re-validate:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}
```

**Step 6**: Update `scripts/expected-fields.json` with `--update` flag:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh --update
```

---

## 9. Complete Sync Checklist

Run through this checklist after each changelog fetch:

- [ ] Read `_updated` date from `expected-fields.json`
- [ ] Fetch changelog entries since that date
- [ ] Scan for hook events, hook types, hook properties
- [ ] Scan for agent frontmatter fields
- [ ] Scan for skill frontmatter fields
- [ ] Scan for plugin.json fields
- [ ] Scan for renamed or new tool names
- [ ] Scan for new model shorthands or permissionMode values
- [ ] Apply safe patches (new optional fields, new enum values)
- [ ] Flag structural changes for manual review
- [ ] Run `check-schema-drift.sh` to verify no unintended drift
- [ ] Run `validate-plugin.sh` to confirm the plugin still passes
- [ ] Update `expected-fields.json` with `--update` flag
- [ ] Record new sync date in the maintenance report
