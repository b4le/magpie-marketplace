---
name: apply
description: "Apply a specific profile to the project. Usage: /plugin-profile:apply <profile-name> [--mode merge|replace]"
---

# Apply Plugin Profile

Apply a specific plugin profile to configure the project's plugin settings.

## Usage

```
/plugin-profile:apply <profile-name> [--mode merge|replace]
```

**Required:** Profile name must be provided as an argument.

### Mode Options

Control how the profile interacts with globally-enabled plugins:

| Mode | Behavior |
|------|----------|
| `--mode merge` | Additive only - keeps all global plugins active, adds profile's settings |
| `--mode replace` | Exclusive - disables all global plugins not explicitly enabled by the profile |
| *(default)* | Uses the profile's `disableInherited` setting |

## Workflow

### Step 1: Parse Arguments

Extract the profile name and optional mode flag from the user's command.

**Examples:**
- `/plugin-profile:apply python` - Apply python profile with default mode
- `/plugin-profile:apply core --mode merge` - Apply core profile, keeping global plugins
- `/plugin-profile:apply typescript --mode replace` - Apply typescript, disable unlisted plugins

### Step 2: Load Profile

Load the profile YAML from the shared profiles directory:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/shared/profiles/<profile-name>.yaml"
```

**Profile structure:**
```yaml
name: Profile Name
description: Description of the profile
extends: parent-profile    # Optional: inherit from another profile
disableInherited: true     # Optional: disable unlisted global plugins

plugins:
  enable:
    - plugin1@marketplace
    - plugin2@marketplace
  disable:
    - plugin3@marketplace
```

If the profile is not found, list available profiles and inform the user:

> Profile `<name>` not found. Available profiles:
> - core, python, typescript, javascript, go, rust, java, data-science
>
> Use `/plugin-profile:list` to see details about each profile.

### Step 3: Resolve Inheritance

If the profile has an `extends` field, the parent profile's plugins are loaded first, then the child profile's settings override them.

**Example:** `python` extends `core`, so `core`'s plugins are loaded first, then `python` adds `pyright-lsp`.

### Step 4: Validate Configuration

Run the validation script to check for plugin conflicts:

```bash
"${CLAUDE_PLUGIN_ROOT}/shared/scripts/validate.sh" .
```

**Exit codes:**
- `0` - No conflicts
- `1` - Conflicts found (review and confirm with user)
- `2` - Error (missing jq, invalid JSON)

If conflicts are found, consult the conflicts reference:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/shared/references/conflicts.md"
```

Inform the user about any conflicts:

> **Conflict detected:** This profile enables `superpowers@claude-plugins-official` which overlaps with `tdd-workflows@claude-code-workflows`. The profile will disable `tdd-workflows` because its functionality is included in `superpowers`. Proceed?

### Step 5: Handle disableInherited

The `disableInherited` feature controls how globally-enabled plugins are handled:

| Setting | Behavior |
|---------|----------|
| `disableInherited: true` | Plugins enabled in `~/.claude/settings.json` but NOT in profile's enable list are disabled |
| `disableInherited: false` or not set | Global plugins remain active (additive merge) |
| `--mode replace` flag | Forces `disableInherited: true` behavior regardless of profile setting |
| `--mode merge` flag | Forces `disableInherited: false` behavior regardless of profile setting |

If `disableInherited` will disable user's global plugins, warn them:

> **Note:** This profile uses `disableInherited: true`. The following globally-enabled plugins will be disabled:
> - `some-global-plugin@marketplace`
>
> Use `--mode merge` to keep these plugins active.

### Step 6: Apply Configuration

Run the apply script:

```bash
"${CLAUDE_PLUGIN_ROOT}/shared/scripts/apply.sh" "${CLAUDE_PLUGIN_ROOT}/shared/profiles/<profile>.yaml" . [--mode=<mode>]
```

**Mode argument mapping:**
- No flag provided: `--mode=profile` (default)
- `--mode merge`: `--mode=merge`
- `--mode replace`: `--mode=replace`

### Step 7: Display Summary

Report what was configured:

> **Profile Applied:** `<profile name>`
>
> **Plugins Enabled:**
> - plugin1@marketplace
> - plugin2@marketplace
>
> **Plugins Disabled:**
> - plugin3@marketplace
> - plugin4@marketplace
>
> **Mode:** `<merge|replace|profile>`
>
> **Conflicts Resolved:** [if any]
>
> Settings written to `.claude/settings.local.json`. Restart Claude Code to apply changes.

## Error Handling

| Error | Resolution |
|-------|------------|
| Profile not found | List available profiles, suggest `/plugin-profile:list` |
| jq not installed | Prompt user: `brew install jq` (macOS) or `apt install jq` (Linux) |
| Circular inheritance | Check profile YAML - A cannot extend B if B extends A |
| Parent profile not found | Verify the `extends:` field references an existing profile |
| Invalid YAML | Check profile syntax, ensure proper indentation |

## Available Profiles

| Profile | Description | Extends |
|---------|-------------|---------|
| `core` | Universal plugins (superpowers, claude-md-management) | - |
| `python` | Python + pyright-lsp | core |
| `typescript` | TypeScript + typescript-lsp + context7 | core |
| `javascript` | JavaScript + typescript-lsp + context7 | core |
| `go` | Go + gopls-lsp | core |
| `rust` | Rust + rust-analyzer-lsp | core |
| `java` | Java + jdtls-lsp | core |
| `data-science` | Notebooks + data tools | python |

## Next Steps

- `/plugin-profile:list` - View all profiles with detailed plugin lists
- Restart Claude Code to apply changes

## Related Skills

- `/plugin-profile:init` - Initialize profile configuration (main entry point)
- `/plugin-profile:detect` - Preview detection without applying changes
- `/plugin-profile:list` - View all available profiles with descriptions
- `/plugin-profile:status` - Show current configuration and diagnostics
