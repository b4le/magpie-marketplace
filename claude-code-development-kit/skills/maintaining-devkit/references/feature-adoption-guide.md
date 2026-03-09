# Feature Adoption Guide

**Purpose**: Structured process for evaluating whether a new Claude Code feature should be adopted into the dev-kit, with adoption steps and testing approach for each feature category.

---

## Evaluation Framework

Before adopting any new feature, answer these four questions:

1. **Gap**: Does the dev-kit currently have a gap that this feature fills?
2. **Fit**: Does the feature align with the dev-kit's purpose (authoring, validating, and maintaining plugins)?
3. **Effort**: Is the adoption cost proportionate to the benefit?
4. **Risk**: Could adopting this feature break existing users or validators?

Rate each 1–3. Adopt if total score ≥ 8/12. Flag for later review if 5–7. Skip if < 5.

---

## Category 1: New Schema Fields

**When**: A changelog entry mentions a new field available in agent, skill, command, hook, or plugin frontmatter.

### Detection

> **Automated:** `analyze-sync.sh` detects new schema fields automatically via signal phrase scanning and reports them as "Action Required" when the field is absent from the schema.

```bash
# Check if the field is already in the relevant schema
python3 -c "
import json
schema = 'schemas/agent-frontmatter.schema.json'  # adjust as needed
with open(schema) as f:
    s = json.load(f)
print('Current properties:', sorted(s.get('properties', {}).keys()))
"

# Check if expected-fields.json already records it
python3 -c "
import json
with open('scripts/expected-fields.json') as f:
    data = json.load(f)
for schema, info in data['schemas'].items():
    print(schema, info['properties'])
"
```

### Adoption Steps

1. Identify which schema file needs the new property.
2. Determine the correct JSON Schema type, constraints, and description by reading the changelog entry carefully.
3. Add the property to `properties` in the schema file. Do not add it to `required` unless the changelog explicitly states it is required.
4. Update the `description` field of `hooksMap` if the new field is a hook event name.
5. Run the drift check to confirm the schema and expected-fields.json are now in sync:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh
   ```
6. If drift is reported, update expected-fields.json:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh --update
   ```
7. Run the full plugin validator to confirm nothing is broken:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}
   ```

### Testing Approach

- Write a minimal fixture file that uses the new field and confirm it passes validation.
- Write a fixture file that uses an invalid value for the new field and confirm it fails validation.
- Add both fixtures to `evals/tests/fixtures/` if they are broadly useful.

---

## Category 2: New Hook Events

**When**: A changelog entry introduces a new lifecycle event that hooks can listen to (e.g., `WorktreeCreate`, `PreCompact`).

### Detection

> **Automated:** `analyze-sync.sh` detects new hook events by scanning for PascalCase identifiers near "event" signal phrases and checking them against the `hooksMap` pattern regex.

Check whether the new event name is already listed in `hooks.schema.json`:

```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/hooks.schema.json') as f:
    s = json.load(f)
pattern = list(s['definitions']['hooksMap']['patternProperties'].keys())[0]
print('Current hook event pattern:')
print(pattern)
"
```

If the new event name is absent from the regex alternation, the schema will reject hooks that use it.

### Adoption Steps

1. Open `schemas/hooks.schema.json`.
2. Find the `patternProperties` key under `definitions.hooksMap`. It is a single regex like:
   ```
   ^(SessionStart|UserPromptSubmit|...)(\\/[a-zA-Z0-9_*-]+)?$
   ```
3. Add the new event name(s) to the alternation group inside the outer parentheses.
4. Also update the `description` field of `hooksMap` — it contains a prose list of known events for human reference.
5. Run the drift check:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh
   ```
6. Run the plugin validator:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}
   ```
7. Consider whether any existing dev-kit hooks should listen to the new event (e.g., a new `WorktreeCreate` event might trigger a workspace setup hook).

### Testing Approach

- Create a minimal `hooks.json` fixture that uses the new event and confirm it passes the hook validator.
- Confirm that a `hooks.json` using a typo of the event name still fails validation.

---

## Category 3: New Tool Capabilities

**When**: A changelog entry adds a new built-in tool, renames an existing tool, or changes the signature/behavior of an existing tool.

### Detection

> **Automated:** `analyze-sync.sh` detects new or renamed tools by matching PascalCase identifiers near "tool" signal phrases against the `tools-enum.json` enum list.

```bash
# List current valid tool names
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/tools-enum.json') as f:
    data = json.load(f)
print(sorted(data['definitions']['toolName']['enum']))
"
```

### Adoption Steps: New tool added

1. Open `schemas/tools-enum.json`.
2. Add the new tool name to `definitions.toolName.enum`.
3. Run the drift check and re-validate.
4. If the new tool is useful for any dev-kit agents (e.g., a new `WebSearch` capability), update those agents' `tools` or `allowed-tools` fields.

### Adoption Steps: Tool renamed

1. Update `schemas/tools-enum.json`: add the new name, retain the old name temporarily if backward compatibility is needed.
2. Search all agent and skill files for the old tool name:
   ```bash
   grep -r "OldToolName" ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/ 2>/dev/null
   ```
3. Update each file using FIX-05 from `auto-fix-catalog.md`.
4. After all files are updated, remove the old name from `tools-enum.json`.
5. Re-validate all agents:
   ```bash
   for f in $(find ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/agents -name '*.md'); do
     bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh "$f"
   done
   ```

### Testing Approach

- Confirm an agent file using the new tool name passes validation.
- Confirm an agent file using the old (removed) name now fails validation.

---

## Category 4: New Plugin Features

**When**: A changelog entry adds a new top-level field to `plugin.json`, adds a new component type (e.g., `lspServers`), or changes how plugins are installed/loaded.

### Detection

> **Automated:** `analyze-sync.sh` detects new plugin fields by matching "plugin.json" or "plugin field" signal phrases and cross-referencing against `plugin.schema.json` properties.

```bash
# Compare plugin.json fields against schema
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/plugin.schema.json') as f:
    s = json.load(f)
print('Current plugin.json properties:', sorted(s.get('properties', {}).keys()))
"
```

### Adoption Steps

1. Determine if the new feature is applicable to the dev-kit plugin:
   - New component type (e.g., `lspServers`): probably not unless the dev-kit has an LSP use case.
   - New metadata field (e.g., `funding`, `settings`): add to schema for completeness.
   - New behavioral field (e.g., `autoLoad`, `priority`): evaluate whether it improves dev-kit UX.

2. Add the new field to `schemas/plugin.schema.json` under `properties`.
3. If the feature requires a new directory or file convention (e.g., a `settings/` folder), update `evals/validate-structure.sh` and `evals/validate-plugin.sh` accordingly.
4. Run the full suite:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh --update
   ```

### Testing Approach

- Add the new field to a fixture `plugin.json` and confirm it passes validation.
- Confirm that a `plugin.json` with an unknown field (not in schema) still fails validation due to `additionalProperties: false`.

---

## Recent Features to Evaluate

> **WARNING — CANDIDATES ONLY**: The entries below are *candidates pending evaluation*, not confirmed or implemented features. Do not treat anything in this section as a working feature, an existing command, or a completed adoption step unless it explicitly says **Status: Evaluated & Adopted** and has a corresponding entry in the [Adoption Log](#adoption-log). Items marked **Pending Evaluation** have not been verified against the schema and may not exist in the current Claude Code release.

The following features were introduced in recent Claude Code releases. Evaluate each against the framework above before the next maintenance cycle.

### HTTP Hooks (`type: http`)

**What it is**: A new hook handler type that POSTs event JSON to an HTTP endpoint instead of running a shell command.

**Already in schema**: Yes — `hooks.schema.json` includes `type: http` with `url`, `headers`, `allowedEnvVars`, `timeout`, `statusMessage`, and `once` properties.

**Evaluation**:
- Gap: The dev-kit uses shell hooks. HTTP hooks enable integrations with external services (Slack, CI, etc.)
- Fit: Medium — relevant for plugin authors who want webhook-based notifications
- Effort: Schema already added. Consider adding an example in the `hooks` skill.
- Risk: Low — additive only.

**Status**: Evaluated & Adopted — schema updated 2026-03-05. See Adoption Log. Consider adding an HTTP hook example to the authoring-skills skill.

---

### `pathPattern` in Hook Entries

**What it is**: An optional `pathPattern` field on `hookEntry` that restricts a hook to fire only when the matched tool operates on files matching a glob pattern.

**Schema check**:
```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/hooks.schema.json') as f:
    s = json.load(f)
entry = s['definitions']['hookEntry']['properties']
print('hookEntry properties:', list(entry.keys()))
"
```

**Evaluation**:
- Gap: Without `pathPattern`, hooks fire on all matching tool calls regardless of which file is affected.
- Fit: High — post-tool-use hooks in the dev-kit (e.g., validating SKILL.md on write) would benefit.
- Effort: Add `pathPattern` to `definitions.hookEntry.properties` in `hooks.schema.json`.
- Risk: Low — purely additive.

**Status**: Pending Evaluation — run the schema check above to confirm whether `pathPattern` is already present before taking any action.

**Adoption (if not yet in schema)**: Apply using Category 1 steps above.

---

### `CLAUDE_SKILL_DIR` Environment Variable

**What it is**: An environment variable injected by Claude Code that contains the path to the currently active skill's directory. Available inside skill hook scripts.

**Schema impact**: None — this is a runtime variable, not a schema field.

**Evaluation**:
- Gap: Hook scripts currently use `${CLAUDE_PLUGIN_ROOT}` to reference plugin assets. `CLAUDE_SKILL_DIR` enables skill-local paths.
- Fit: High — useful for skills that have their own hook scripts.
- Effort: Update skill hook script examples in the `understanding-hooks` skill to demonstrate `CLAUDE_SKILL_DIR`.
- Risk: None — purely documentation/example update.

**Status**: Pending Evaluation — verify that `CLAUDE_SKILL_DIR` is injected in the current Claude Code release before updating any examples.

**Adoption (if confirmed available)**: No schema change needed. Update example hook scripts to reference `CLAUDE_SKILL_DIR` where appropriate.

---

### `/reload-plugins` Command

**What it is**: A slash command that reloads all installed plugins without restarting Claude Code.

**Schema impact**: None — this is a Claude Code built-in command.

**Evaluation**:
- Gap: Developers editing plugin files had to restart Claude Code to test changes.
- Fit: High — would be valuable for the dev-kit maintenance workflow if the command exists.
- Effort: If confirmed, update `SKILL.md` to mention `/reload-plugins` as a post-fix step.
- Risk: None.

**Status**: Pending Evaluation — `/reload-plugins` has NOT been verified as a working Claude Code command. Do not reference it in procedures or examples until confirmed. Check the current Claude Code release notes or test the command interactively before treating it as available.

**Adoption (if confirmed available)**: Add `/reload-plugins` as a step in the Mode: Validate section of `SKILL.md` and in any example that shows a fix-and-revalidate cycle.

---

### Plugin `settings.json`

**What it is**: A `settings.json` file inside the plugin directory (or a `settings` object in `plugin.json`) that allows plugins to declare user-configurable settings.

**Schema check**:
```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/plugin.schema.json') as f:
    s = json.load(f)
print('settings in plugin.schema.json:', 'settings' in s.get('properties', {}))
"
```

**Evaluation**:
- Gap: The dev-kit has no settings yet, but plugin authors need to know the pattern.
- Fit: Medium — more relevant to the `creating-plugins` skill than this one.
- Effort: Add `settings` to `plugin.schema.json` if not present. Add an example to the plugin authoring skill.
- Risk: Low.

**Status**: Pending Evaluation — run the schema check above to confirm whether `settings` is already present in `plugin.schema.json` before taking any action.

**Adoption (if not yet in schema)**: Apply Category 4 steps.

---

### Worktree Isolation

**What it is**: Claude Code now creates isolated git worktrees per task in multi-agent scenarios. The `WorktreeCreate` and `WorktreeRemove` hook events fire at worktree lifecycle boundaries.

**Schema check**:
```bash
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/hooks.schema.json') as f:
    s = json.load(f)
pattern = list(s['definitions']['hooksMap']['patternProperties'].keys())[0]
print('WorktreeCreate in pattern:', 'WorktreeCreate' in pattern)
print('WorktreeRemove in pattern:', 'WorktreeRemove' in pattern)
"
```

**Evaluation**:
- Gap: If the dev-kit needs to run setup/teardown logic in worktree contexts, it needs these events.
- Fit: Medium — useful for advanced plugin authors, less critical for the dev-kit itself.
- Effort: Apply Category 2 steps if not yet in schema.
- Risk: Low — additive only.

**Status**: Evaluated & Adopted — schema updated 2026-03-05. See Adoption Log.

---

## Adoption Log

Record completed adoptions here so future sync cycles don't re-evaluate the same features.

| Feature | Changelog version | Date adopted | Schema change | Notes |
|---------|------------------|--------------|---------------|-------|
| HTTP hooks | — | 2026-03-05 | `hooks.schema.json` | `type: http` handler added |
| WorktreeCreate/Remove events | — | 2026-03-05 | `hooks.schema.json` | Added to hooksMap pattern |
| PreCompact event | — | 2026-03-05 | `hooks.schema.json` | Added to hooksMap pattern |
| `once` hook property | — | 2026-03-05 | `hooks.schema.json` | Added to all handler types |
| `permissionMode` agent field | — | 2026-03-05 | `agent-frontmatter.schema.json` | Added with enum |
| `maxTurns` agent field | — | 2026-03-05 | `agent-frontmatter.schema.json` | Added with min/max |
| `InstructionsLoaded` event | v2.1.69 | 2026-03-07 | `hooks.schema.json`, `skill-frontmatter.schema.json` | Added to hooksMap pattern + description |
