# Schema Maintenance Guide

Reference for maintaining the schema layer in this marketplace.

---

## Schema Inventory

### CCDK Schemas (`claude-code-development-kit/schemas/`)

| File | Purpose | Validates |
|------|---------|-----------|
| `agent-frontmatter.schema.json` | Agent configuration | YAML frontmatter in agent `.md` and `.yaml` files |
| `skill-frontmatter.schema.json` | Skill metadata | YAML frontmatter in `SKILL.md` files |
| `command-frontmatter.schema.json` | Command metadata | YAML frontmatter in command `.md` files |
| `plugin.schema.json` | Plugin manifest | `.claude-plugin/plugin.json` |
| `hooks.schema.json` | Hook event handlers | `hooks.json` files and inline hook config in plugin manifests |
| `marketplace.schema.json` | Marketplace registry | `.claude-plugin/marketplace.json` |
| `output-style-frontmatter.schema.json` | Output style metadata | YAML frontmatter in output style `.md` files |

`tools-enum.json` is a supporting file referenced by schema `$ref`; it is not a standalone schema.

### Knowledge Harvester Schemas (`knowledge-harvester/schemas/`)

| File | Purpose |
|------|---------|
| `harvest-config.schema.json` | Configuration for a harvest run — sources, triage settings, limits |
| `candidates.schema.json` | Stage 1 output — enumerated candidate sources |
| `ranked.schema.json` | Stage 2 output — triaged and scored candidates |
| `extractions.schema.json` | Stage 4 output — extracted findings (JSONL line format) |
| `checkpoint.schema.json` | Resume state — current stage, progress, stage history |

---

## Source of Truth

The canonical upstream for Claude Code field names and semantics is the official documentation at https://docs.anthropic.com/en/docs/claude-code.

**Our schemas are a local source of truth for this marketplace.** They extend Claude Code's base specification with marketplace-specific fields and enforce conventions (naming patterns, character limits, allowed enum values) that the official docs leave unspecified.

Every field in the CCDK schemas falls into one of two categories:

- **OFFICIAL** — field name and semantics match Claude Code's documented specification
- **EXTENSION** — field added by this marketplace; not part of the Claude Code spec

Extension fields are annotated in the schema `description` with the `[Extension]` prefix so they are easy to identify. When Claude Code ships a new official field that conflicts with one of our extensions, the extension must be reconciled (usually by renaming the extension or dropping it in favour of the official field).

---

## Naming Conventions

Naming follows the convention set by Claude Code for each component type. Extensions generally follow the same convention as the OFFICIAL fields in that component.

### Agent frontmatter

- **OFFICIAL fields** use camelCase: `maxTurns`, `permissionMode`
- **Extension fields** use snake_case: `model_rationale`, `system_prompt`
- Exception: `user-invocable`, `allowed-tools`, and `tools` use kebab-case / lowercase because they were established before the camelCase convention was confirmed

### Skill frontmatter

- **OFFICIAL fields** use kebab-case: `allowed-tools`, `disable-model-invocation`, `user-invocable`, `argument-hint`
- **Extension date fields** use snake_case: `last_updated`, `created`
- Other extension fields use kebab-case to match the OFFICIAL pattern: `auto-invoke` (deprecated), `categories`, `tags`, `dependencies`, `author`, `version`

### Plugin manifest (`plugin.json`)

- All fields use camelCase: `mcpServers`, `lspServers`, `outputStyles`, `keywords`, `homepage`, `repository`

### Hook handlers (`hooks.json`)

- Handler properties use camelCase: `statusMessage`, `allowedEnvVars`, `async`, `timeout`, `once`
- Event names use PascalCase: `SessionStart`, `PostToolUse`, `PreCompact`

---

## Extension Fields

Fields added beyond the Claude Code specification.

### Agent frontmatter extensions

| Field | Type | Notes |
|-------|------|-------|
| `model_rationale` | string | Explains why a specific model was chosen. Recommended when `model` is set. |
| `color` | enum string | Display color for UI contexts. Values: `blue`, `cyan`, `green`, `yellow`, `magenta`, `red`. |
| `system_prompt` | string | System prompt body for YAML-format agent definitions. |
| `user-invocable` | boolean | Controls whether users can directly invoke this agent. Defaults to `true`. |
| `version` | semver string | Semantic version of the agent definition. |

### Skill frontmatter extensions

| Field | Type | Notes |
|-------|------|-------|
| `last_updated` | date string | ISO 8601 date of last modification. |
| `created` | date string | ISO 8601 date of creation. |
| `categories` | string array | Taxonomy categories for organisation and discovery. |
| `author` | string | Skill author name. |
| `tags` | string array | Free-form tags for search. |
| `dependencies` | string array | Names of other skills this skill depends on. |
| `auto-invoke` | boolean | **Deprecated.** Use `disable-model-invocation` (the OFFICIAL inverse) instead. |
| `version` | semver string | Semantic version of the skill definition. |

### Command frontmatter extensions

| Field | Type | Notes |
|-------|------|-------|
| `arguments` | object array | Declared arguments with `name`, `description`, `required`, and `type`. Used for documentation and completion. |
| `version` | semver string | Semantic version of the command definition. |

---

## How to Update a Schema

Use this process when Claude Code documents a new parameter, or when we need to add a marketplace extension.

1. **Check the upstream.** Review https://docs.anthropic.com/en/docs/claude-code for the new parameter's official name, type, and semantics. Check the changelog if available.

2. **Edit the schema file.** Open the relevant `.schema.json` file in `claude-code-development-kit/schemas/`. Add the new property in the `properties` block with `type`, `description`, and `examples`. For OFFICIAL fields, match the upstream name exactly. For extension fields, prefix the description with `[Extension]`.

3. **Update `expected-fields.json`.** If the repository has a `scripts/expected-fields.json` tracking file, add the new field name under the relevant component key.

4. **Run drift detection.** If `scripts/check-schema-drift.sh` exists, run it to confirm no untracked fields remain:
   ```bash
   bash scripts/check-schema-drift.sh
   ```

5. **Add test fixtures.** See the next section. At minimum, add one valid fixture that uses the new field and one invalid fixture that tests rejection of a bad value.

6. **Run the full eval suite.**
   ```bash
   REQUIRE_SCHEMA_VALIDATION=1 bash run-all-evals.sh --verbose
   ```
   All tests must pass before committing.

7. **Record the change.** Add a row to the Schema Changelog at the bottom of this file.

---

## How to Add Test Fixtures

Fixtures live under `claude-code-development-kit/evals/tests/fixtures/`. The test runner for each component picks up files by naming convention.

### Directory layout

```
evals/tests/fixtures/
  agents/
    good-agent.md               # valid .md agent (must pass)
    good-agent.yaml             # valid .yaml agent (must pass)
    good-agent-optional-fields.md
    invalid-extra-field.md      # rejected: unknown top-level field
    invalid-permission-mode.md  # rejected: invalid enum value
    missing-description.md      # rejected: required field absent
    ...
  skills/
    good/                       # valid skill directory (must pass)
    missing-description/        # rejected: description absent
    ...
  commands/
    good.md                     # valid command (must pass)
    missing-description.md      # rejected
    ...
  plugins/
    good/                       # valid plugin directory (must pass)
    invalid-json/               # rejected
    missing-name/               # rejected
    ...
```

### Naming conventions

- **Valid fixtures** — prefix with `good-` for files, or use a plain directory name like `good/`. The validator test expects these to produce exit code 0.
- **Invalid fixtures** — prefix with `invalid-` for field-level rejections. Use a descriptive name for structural rejections (`missing-description`, `no-frontmatter`, `personal-path`). The validator test expects these to produce a non-zero exit code.

### Adding a fixture

1. Create the file at the appropriate path using the naming convention above.
2. For agent and command fixtures, use a `.md` file with a YAML frontmatter block:
   ```markdown
   ---
   name: my-agent
   description: Does something useful when you need to do that thing.
   tools: [Read, Grep]
   invalid-new-field: oops
   ---
   Body text here.
   ```
3. For skill fixtures, create a directory containing a `SKILL.md` file.
4. Run the relevant test script directly to confirm the expected outcome:
   ```bash
   bash claude-code-development-kit/evals/tests/test-validate-agent.sh
   ```

---

## Validation Pipeline

### Component validators

Each component type has a dedicated validator in `claude-code-development-kit/evals/`:

| Script | Validates |
|--------|-----------|
| `validate-agent.sh` | Agent `.md` and `.yaml` files |
| `validate-skill.sh` | `SKILL.md` files and skill directory structure |
| `validate-command.sh` | Command `.md` files |
| `validate-plugin.sh` | `plugin.json` manifests |
| `validate-hook.sh` | `hooks.json` files |
| `validate-output-style.sh` | Output style `.md` files |
| `validate-structure.sh` | Directory layout and required file presence |
| `validate-references.sh` | Internal link and cross-reference integrity |

### Shared schema functions

`_schema-validate.sh` is sourced by all component validators. It provides two functions:

- `validate_json_schema <schema-file> <json-file>` — validates a JSON file against a JSON Schema
- `validate_frontmatter_schema <schema-file> <md-file>` — extracts YAML frontmatter from a markdown file and validates it

Return codes:

| Code | Meaning |
|------|---------|
| `0` | Validation passed |
| `1` | Validation failed (schema errors found) |
| `2` | Validation tool unavailable (fail-open) |

### Fail-open vs fail-closed

Without `REQUIRE_SCHEMA_VALIDATION=1`, missing tools (Python `jsonschema` library) produce RC=2 and the caller treats the check as skipped. This is the default for local development where the dependency may not be installed.

Set `REQUIRE_SCHEMA_VALIDATION=1` to make the pipeline fail-closed: RC=2 becomes RC=1. The eval runner sets this automatically so CI always enforces schema validation.

### Orchestration

`validate-marketplace.sh` calls all component validators across all plugins in the marketplace. This is the entry point called by the pre-commit hook on every commit.

---

## Schema Changelog

Track schema changes here. Reference the Claude Code version when updating an OFFICIAL field; leave it blank for extension-only changes.

| Date | Schema | Change | Claude Code Version | Branch |
|------|--------|--------|---------------------|--------|
| 2026-03-05 | `agent-frontmatter` | `max_turns` renamed to `maxTurns`; `permissionMode` added with enum values | - | fix/schema-validation-audit |
| 2026-03-05 | `agent-frontmatter` | `additionalProperties: false` enforced; `system_prompt`, `color`, `user-invocable`, `version`, `model_rationale` formalised as extensions | - | fix/schema-validation-audit |
| 2026-03-05 | `skill-frontmatter` | `disable-model-invocation`, `user-invocable`, `context`, `agent`, `hooks` added as OFFICIAL fields; `auto-invoke` deprecated in favour of `disable-model-invocation` | - | fix/schema-validation-audit |
| 2026-03-05 | `command-frontmatter` | `arguments` array extension added; `user-invocable` added | - | fix/schema-validation-audit |
