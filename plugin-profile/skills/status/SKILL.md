---
name: status
description: Show current plugin profile configuration status. Displays enabled/disabled plugins and active profile.
---

# Plugin Profile Status

Display the current plugin configuration, including which plugins are enabled, disabled, and which profile is active.

## Usage

```
/plugin-profile:status
```

Shows:
- **Enabled Plugins**: Plugins currently active in `.claude/settings.local.json`
- **Disabled Plugins**: Plugins explicitly disabled in local settings
- **Global Settings**: Comparison with `~/.claude/settings.json` to identify conflicts
- **Detected Profile**: Best guess at which profile is active based on enabled plugins
- **Inheritance Status**: Whether `disableInherited` is in effect
- **Conflicts**: Any plugin conflicts detected

## Workflow

### Step 1: Read Local Settings

Check `.claude/settings.local.json` in the current project:

```bash
if [[ -f ".claude/settings.local.json" ]]; then
    jq '.enabledPlugins // {}' ".claude/settings.local.json"
else
    echo "No local settings found"
fi
```

Parse the JSON output to categorize plugins:
- **Enabled**: Plugins with `value == true`
- **Disabled**: Plugins with `value == false`

### Step 2: Read Global Settings

Check `~/.claude/settings.json` for comparison:

```bash
if [[ -f "$HOME/.claude/settings.json" ]]; then
    jq '.enabledPlugins // {}' "$HOME/.claude/settings.json"
else
    echo "No global settings found"
fi
```

### Step 3: Identify Active Profile

Match enabled plugins against known profiles to identify which is active:

**Profile Detection Logic:**

- **core**: If `superpowers` and `claude-md-management` are enabled
- **python**: If `pyright-lsp` is enabled (extends core)
- **typescript**: If `typescript-lsp` and `context7` are enabled (extends core)
- **javascript**: If `typescript-lsp` and `context7` are enabled, no tsconfig detected
- **go**: If `gopls-lsp` is enabled (extends core)
- **rust**: If `rust-analyzer-lsp` is enabled (extends core)
- **java**: If `jdtls-lsp` is enabled (extends core)
- **data-science**: If python LSP plugins plus data tools are enabled
- **custom**: If no known profile matches (manual configuration)

### Step 4: Check for Inheritance Mode

Determine if `disableInherited` is in effect:

- If global plugins are enabled but local settings has explicitly disabled them → `disableInherited: true` is active
- If global plugins remain enabled in local settings → merge mode (additive)
- Compare enabledPlugins in both files to infer the mode

### Step 5: Detect Conflicts

Check for known plugin conflicts by reading `${CLAUDE_PLUGIN_ROOT}/shared/references/conflicts.md`.

Parse the conflicts file to extract conflict pairs, then check if both plugins from any pair are enabled. Report any matches as conflicts.

If both plugins from a conflict pair are enabled, report it as a conflict.

### Step 6: Generate Report

Format output as:

```
Current Plugin Profile Status
==============================

Local Settings: .claude/settings.local.json
Global Settings: ~/.claude/settings.json

ENABLED PLUGINS
───────────────
- plugin-1@marketplace
- plugin-2@marketplace
  (inherited from global)

DISABLED PLUGINS
────────────────
- plugin-3@marketplace
- plugin-4@marketplace

DETECTED PROFILE
────────────────
Profile: [name]
Confidence: [high|medium|low]
Extends: [parent profile if applicable]
DisableInherited: [true|false|unknown]

Matched Fingerprints:
- plugin-1 (expected)
- plugin-2 (expected)
- plugin-3 (unexpected - check configuration)

CONFLICTS DETECTED
──────────────────
⚠ Conflict: superpowers vs tdd-workflows
  → Both enabled. Recommendation: Keep superpowers, disable tdd-workflows

GLOBAL vs LOCAL COMPARISON
────────────────────────────
Globally Enabled (not in local):
- global-plugin-1

Locally Disabled (globally enabled):
- global-plugin-2
```

## Troubleshooting

### "jq not installed"

The status skill requires `jq` for JSON parsing. Install it:

- **macOS**: `brew install jq`
- **Linux (Debian/Ubuntu)**: `apt install jq`
- **Linux (Fedora/RHEL)**: `dnf install jq`
- **Windows (via Chocolatey)**: `choco install jq`

### "Wrong profile detected"

If the detected profile doesn't match your project, check:

1. Run `/plugin-profile:detect` to see what fingerprints were found
2. Verify the correct profile matches your project stack
3. Use `/plugin-profile:init python` to manually configure the correct profile
4. Check `.claude/settings.local.json` to see what plugins were actually enabled

### "Plugin not working after apply"

If a plugin isn't activating even though it shows as enabled:

1. Verify the plugin name is correct (check marketplace)
2. Restart Claude Code to apply changes
3. Check if there are conflicts preventing the plugin from loading
4. Verify `.claude/settings.local.json` is readable and valid JSON

### Unexpected plugins still active

If plugins you expected to disable are still active:

1. Check global settings (`~/.claude/settings.json`) - plugins enabled globally may override local settings
2. Verify `disableInherited: true` is set in the profile if you want to disable global plugins
3. Run `/plugin-profile:init [profile] --replace` to replace all global plugins with the profile's plugins
4. Check `.claude/settings.local.json` directly to see what's configured

### "Circular inheritance error"

If you see a circular profile inheritance error:

1. Check the profile YAML `extends:` field
2. Ensure it doesn't reference itself or create a cycle (A extends B extends A)
3. Verify parent profiles exist in the `profiles/` directory
4. Use `/plugin-profile:init` to reconfigure with a valid profile

## Related Skills

- `/plugin-profile:init` - Configure profile for your project
- `/plugin-profile:detect` - Detect project type and recommended profile
- `/plugin-profile:list` - View available profiles and their contents

## File Locations

- **Local settings**: `.claude/settings.local.json` (gitignored, personal)
- **Global settings**: `~/.claude/settings.json` (your home directory)
- **Profiles**: `${CLAUDE_PLUGIN_ROOT}/shared/profiles/*.yaml`
