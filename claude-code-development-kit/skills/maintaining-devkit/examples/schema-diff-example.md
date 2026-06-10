<!-- Example output from a `sync` maintenance run of the devkit-maintainer agent -->
<!-- Generated: 2026-03-01 | Mode: sync -->

DEVKIT-MAINTAINER REPORT
========================
Mode: sync
Status: 1 schema drift detected, 1 patch proposed, 1 manual review flag
Date: 2026-03-01

---

## Changelog Fetch

Source: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
Last sync: 2026-02-15 (per `scripts/expected-fields.json` `_updated` field)
New entries since last sync: 1 version

---

## Changelog Entry: v2.1.70

Release date: 2026-02-28

```
### v2.1.70

#### New Features

- **Hooks**: Added `PostToolUseFailure` event — fires after a tool call returns
  an error. Allows hooks to react to failed Bash commands, read errors, etc.
  The event payload includes `tool_name`, `error_message`, and `exit_code`.

- **Hooks**: Added `statusMessage` property to all hook handler types (`command`,
  `http`, `prompt`, `agent`). When set, displays a custom spinner message in the
  UI while the hook runs instead of the generic "Running hook..." text.

- **Agents**: Added `context_window` frontmatter field. Agents can now declare
  a preferred context window size in tokens. Valid range: 1024–200000. When
  omitted, the agent inherits the session default.

#### Breaking Changes

None.

#### Deprecations

- `PostToolUse` event: The `output` field in the event payload has been renamed
  to `tool_output` for consistency with other events. The old name continues to
  work but will be removed in v2.2.0. Update hooks that read `event.output` to
  use `event.tool_output`.
```

---

## Schema Diff

Comparing extracted changelog changes against schemas in `claude-code-development-kit/schemas/`.

### hooks.schema.json

#### Finding 1: New hook event `PostToolUseFailure`

Type: New enum value in `hooksMap.patternProperties`
Category: New optional field (safe to add)

Current `patternProperties` regex:
```
^(SessionStart|UserPromptSubmit|PreToolUse|PermissionRequest|PostToolUse|
  PostToolUseFailure|Notification|SubagentStart|SubagentStop|Stop|TeammateIdle|
  TaskCompleted|ConfigChange|WorktreeCreate|WorktreeRemove|PreCompact|SessionEnd)
  (\/[a-zA-Z0-9_*-]+)?$
```

Checked: `PostToolUseFailure` is already present in the pattern.
Result: CLEAN — schema already covers this event. No update needed.

Note: The event was likely added to the schema in anticipation. The `_updated` date
in `expected-fields.json` predates the changelog release, which suggests this was
a forward-compatible addition made during a previous sync.

---

#### Finding 2: New `statusMessage` property on hook handlers

Type: New optional property on all four hook handler types
Category: New optional field (safe to add)

Checked each `hookHandler` variant in `hooks.schema.json`:

| Handler type | Has `statusMessage`? |
|-------------|----------------------|
| `command` | YES — already present |
| `http` | YES — already present |
| `prompt` | YES — already present |
| `agent` | YES — already present |

Result: CLEAN — `statusMessage` is already defined on all handler types. No update needed.

---

### agent-frontmatter.schema.json

#### Finding 3: New `context_window` frontmatter field

Type: New optional property
Category: Structural addition to a strict schema (`additionalProperties: false`)
Status: SCHEMA DRIFT — field not present in current schema

Current properties in `agent-frontmatter.schema.json`:
```
allowed-tools, color, description, maxTurns, model, model_rationale,
name, permissionMode, system_prompt, tools, user-invocable, version
```

Field `context_window` is absent.

Impact: Any agent file that includes `context_window` in its frontmatter will fail
schema validation with:
```
[ERROR] Additional property not allowed: context_window
```

Proposed patch:

Add the following property definition to `schemas/agent-frontmatter.schema.json`
under `"properties"`:

```json
"context_window": {
  "type": "integer",
  "description": "Preferred context window size in tokens for this agent. When omitted, the agent inherits the session default.",
  "minimum": 1024,
  "maximum": 200000,
  "examples": [32000, 100000, 200000]
}
```

Also add to `scripts/expected-fields.json` under `agent-frontmatter.schema.json.properties`:

```json
"context_window"
```

And update `_updated` to `"2026-03-01"`.

AUTO-APPLY ELIGIBLE: No — structural addition to an `additionalProperties: false` schema.
Manual review required to confirm field semantics and acceptable range before patching.

---

#### Finding 4: Deprecation of `output` field in `PostToolUse` event payload

Type: Runtime event payload change (not a schema field)
Category: Hook author impact — does not affect any JSON schema files
Status: INFORMATIONAL — no schema update needed

The `output` field in `PostToolUse` event payloads is deprecated in favour of
`tool_output`. This affects hook scripts that parse the event JSON from stdin,
not the schema files in `schemas/`.

Affected files to audit manually:
- `claude-code-development-kit/.claude-plugin/plugin.json` inline hooks — the
  `PostToolUse` hook calls `evals/validate-skill.sh --hook-mode`. That script
  does not read event payload fields, so it is unaffected.
- Any custom hook scripts in other plugins that parse `event.output` from stdin.

Recommendation: Search for `event.output` or `\.output` in hook scripts before v2.2.0:
```bash
grep -r 'event\.output\|\.output' claude-code-development-kit/hooks/ knowledge-harvester/hooks/ 2>/dev/null
```

No matches found in current codebase. No action required before v2.2.0.

---

## Schema Patch Summary

| Schema | Finding | Auto-apply? | Action |
|--------|---------|-------------|--------|
| `hooks.schema.json` | `PostToolUseFailure` already present | N/A | None — clean |
| `hooks.schema.json` | `statusMessage` already present | N/A | None — clean |
| `agent-frontmatter.schema.json` | `context_window` missing | No | Manual review required |
| Runtime (PostToolUse payload) | `output` → `tool_output` deprecation | N/A | Informational — no scripts affected |

---

## Manual Review Flag

### FLAG-01: Add `context_window` to `agent-frontmatter.schema.json`

Priority: MEDIUM
Reason: Without this field, any devkit user who writes an agent with `context_window`
will hit a false-positive validation error. The field is low-risk (integer with bounded
range) but the schema uses `additionalProperties: false`, so adding it requires deliberate
confirmation that the field name and constraints match the production implementation.

Steps to resolve:
1. Confirm field name is `context_window` (snake_case) not `contextWindow` (camelCase)
   by checking the Claude Code release notes or testing with a real agent file.
2. Apply the proposed patch above to `schemas/agent-frontmatter.schema.json`.
3. Add `context_window` to the `properties` list in `scripts/expected-fields.json`.
4. Update `_updated` in `expected-fields.json` to today's date.
5. Run `bash evals/validate-plugin.sh claude-code-development-kit/` to confirm no
   regressions.

Estimated effort: 10 minutes.

---

## Updated expected-fields.json (after applying FLAG-01)

If FLAG-01 is approved, `scripts/expected-fields.json` should be updated as follows:

```json
{
  "_comment": "Expected top-level properties for each schema. Run scripts/check-schema-drift.sh to compare.",
  "_updated": "2026-03-01",
  "schemas": {
    "agent-frontmatter.schema.json": {
      "properties": [
        "allowed-tools",
        "color",
        "context_window",
        "description",
        "maxTurns",
        "model",
        "model_rationale",
        "name",
        "permissionMode",
        "system_prompt",
        "tools",
        "user-invocable",
        "version"
      ],
      "additionalProperties": false
    }
  }
}
```

(All other schema entries in `expected-fields.json` remain unchanged.)
