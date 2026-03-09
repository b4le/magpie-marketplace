# Plugin Profile

**Version:** 2.0.0

Automatically configure Claude Code plugins based on your project's technology stack. This plugin provides profile-based configuration with auto-detection, inheritance, and conflict resolution.

## Features

- Auto-detects project type from fingerprint files (package.json, pyproject.toml, go.mod, etc.) and selects the appropriate plugin profile
- Profile inheritance system allows specialised profiles (e.g., data-science) to extend base profiles (e.g., python) without duplication
- Merge and replace modes give fine-grained control over how profiles interact with globally-enabled plugins
- Conflict resolution handles known plugin incompatibilities automatically, with a configurable reference for custom rules

## Installation

```bash
claude plugin install plugin-profile@magpie-marketplace
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `init` | Auto-detect project type and configure plugins (main entry point) | `/plugin-profile:init` |
| `detect` | Detection only - preview what would be configured | `/plugin-profile:detect` |
| `apply` | Apply a specific profile with optional mode control | `/plugin-profile:apply` |
| `list` | Show all available profiles with descriptions | `/plugin-profile:list` |
| `status` | Display current plugin configuration and active profile | `/plugin-profile:status` |

## Usage

### Quick Start

Auto-detect and configure your project:
```
/plugin-profile:init
```

Specify a profile directly:
```
/plugin-profile:init python
```

### Detailed Skill Usage

#### `/plugin-profile:init [profile-name]`

The main entry point for setting up project-specific plugin configurations.

```
/plugin-profile:init              # Auto-detect and configure
/plugin-profile:init typescript   # Force TypeScript profile
/plugin-profile:init core         # Reset to core plugins only
```

**Workflow:**
1. If no profile specified, auto-detects project type based on fingerprint files
2. Shows detection results with confidence level
3. For high confidence, applies automatically; otherwise asks for confirmation
4. Writes configuration to `.claude/settings.local.json`

#### `/plugin-profile:detect`

Detect project type without applying any changes. Useful for previewing configuration or debugging detection issues.

```
/plugin-profile:detect
```

**Output includes:**
- Detected profile name
- Confidence level (high/medium/low)
- Matched fingerprints (e.g., tsconfig.json, pyproject.toml)
- Preview of what would be configured

#### `/plugin-profile:apply <profile> [--mode merge|replace]`

Apply a specific profile with fine-grained control over plugin inheritance.

```
/plugin-profile:apply python                  # Apply with default mode
/plugin-profile:apply core --mode merge       # Keep global plugins, add profile
/plugin-profile:apply typescript --mode replace  # Replace all with profile's plugins
```

#### `/plugin-profile:list`

Display all available profiles with their descriptions, inheritance relationships, and key plugins.

```
/plugin-profile:list
```

Shows a formatted table of profiles plus inheritance tree visualization.

#### `/plugin-profile:status`

Show current plugin configuration status.

```
/plugin-profile:status
```

**Displays:**
- Currently enabled plugins
- Explicitly disabled plugins
- Detected active profile
- Global vs local settings comparison
- Any plugin conflicts detected

## How It Works

1. **Detection**: Scans for fingerprint files (package.json, pyproject.toml, go.mod, etc.)
2. **Matching**: Maps detected stack to a profile (python, typescript, go, etc.)
3. **Inheritance**: Resolves profile inheritance (e.g., python extends core)
4. **Validation**: Checks for plugin conflicts
5. **Inherited Plugin Handling**: Checks the profile's `disableInherited` setting or mode flag
6. **Configuration**: Writes `enabledPlugins` to `.claude/settings.local.json`

## Profiles

| Profile | Detected By | Enables | Extends |
|---------|-------------|---------|---------|
| `core` | (default) | superpowers, claude-md-management, slack | - |
| `python` | pyproject.toml, requirements.txt | pyright-lsp, python-development | core |
| `typescript` | tsconfig.json | typescript-lsp, context7 | core |
| `javascript` | package.json (no tsconfig) | typescript-lsp, context7 | core |
| `go` | go.mod | gopls-lsp | core |
| `rust` | Cargo.toml | rust-analyzer-lsp | core |
| `java` | pom.xml, build.gradle | jdtls-lsp | core |
| `data-science` | *.ipynb | data tools, jupyter-tools | python |

## Profile Inheritance

Profiles can extend other profiles to inherit their plugin settings:

```
core (base)
  |-- python
  |     `-- data-science
  |-- typescript
  |-- javascript
  |-- go
  |-- rust
  `-- java
```

When a profile extends another:
1. Parent profile's `enable` list is loaded first
2. Parent profile's `disable` list is loaded
3. Child profile's settings are merged (child takes precedence)

**Example:** The `python` profile extends `core`, so applying `python` gives you:
- All plugins from `core` (superpowers, claude-md-management, slack)
- Plus Python-specific plugins (pyright-lsp, python-development)

## Mode Options

Control how profiles interact with globally-enabled plugins:

| Mode | Behavior |
|------|----------|
| *(default)* | Uses the profile's `disableInherited` setting |
| `--mode merge` | Additive only - keeps all global plugins active, adds profile's settings |
| `--mode replace` | Exclusive - disables all global plugins not explicitly enabled by the profile |

**Examples:**
```
/plugin-profile:apply core --mode merge      # Keep all global plugins, add core's settings
/plugin-profile:apply python --mode replace  # Only python profile's plugins will be active
```

## Conflict Resolution

The plugin automatically handles known conflicts:

- `superpowers` includes TDD, debugging, and code review - standalone plugins disabled
- `orchestration-toolkit` is preferred over `agent-teams` for multi-agent workflows

See `shared/references/conflicts.md` for full conflict documentation.

## Requirements

- **jq**: Required for JSON processing. Install via `brew install jq` (macOS) or `apt install jq` (Linux).

## Customization

Create custom profiles in `shared/profiles/` directory following the YAML schema:

```yaml
name: My Custom Profile
description: Description here
extends: core  # Optional: inherit from another profile
disableInherited: false  # If true, disable global plugins not in enable list

plugins:
  enable:
    - plugin-name@marketplace
  disable:
    - other-plugin@marketplace
```

## File Structure

```
plugin-profile/
|-- .claude-plugin/plugin.json
|-- hooks/
|   |-- hooks.json
|   `-- scripts/
|       `-- session-start.sh
|-- shared/
|   |-- profiles/*.yaml
|   |-- scripts/
|   |   |-- detect.sh
|   |   |-- apply.sh
|   |   `-- validate.sh
|   `-- references/conflicts.md
|-- skills/
|   |-- init/SKILL.md
|   |-- detect/SKILL.md
|   |-- apply/SKILL.md
|   |-- list/SKILL.md
|   `-- status/SKILL.md
`-- README.md
```

## Session Start Hook

The plugin includes a SessionStart hook that automatically detects when you're in a new project without plugin configuration. When triggered, it suggests running `/plugin-profile:init` to set up appropriate plugins for your project.

## Troubleshooting

**"jq not installed"**: Install jq via `brew install jq` (macOS) or `apt install jq` (Linux).

**Wrong profile detected**: Use explicit profile argument: `/plugin-profile:init [correct-profile]`

**Plugin not working after apply**: Restart Claude Code to apply changes.

**Unexpected plugins still active**: Check global settings (`~/.claude/settings.json`). Use `--mode replace` to override.

## Contributing

Contributions welcome. Please follow the existing patterns for profiles and skills.

## License

MIT

## Version History

| Version | Changes |
|---------|---------|
| 2.0.0 | Added profile inheritance, merge/replace modes, and conflict resolution |
| 1.0.0 | Initial release with auto-detection and profile application |
