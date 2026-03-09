---
name: list
description: List all available plugin profiles with their descriptions and included plugins.
---

# List Plugin Profiles

Display all available plugin profiles with their descriptions, inheritance relationships, and key plugins.

## Usage

```
/plugin-profile:list
```

No arguments required.

## Workflow

### Step 1: Enumerate Profiles

List all profile YAML files from the shared profiles directory:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/shared/profiles/"*.yaml 2>/dev/null
```

### Step 2: Parse Each Profile

For each profile file, extract:
- **name** - Profile identifier (filename without extension)
- **description** - From the `description:` field
- **extends** - Parent profile (if any)
- **plugins.enable** - List of plugins to enable
- **plugins.disable** - List of plugins to disable
- **disableInherited** - Whether global plugins are disabled

### Step 3: Display Profile Table

Present profiles in a formatted table:

## Available Profiles

| Profile | Description | Extends | Key Plugins |
|---------|-------------|---------|-------------|
| `core` | Universal plugins that work across all project types | - | superpowers, claude-md-management, slack |
| `python` | Python projects with type checking and development workflows | core | pyright-lsp, python-development |
| `typescript` | TypeScript projects with LSP and documentation | core | typescript-lsp, context7 |
| `javascript` | JavaScript projects with LSP and documentation | core | typescript-lsp, context7 |
| `go` | Go projects with LSP support | core | gopls-lsp |
| `rust` | Rust projects with analyzer | core | rust-analyzer-lsp |
| `java` | Java projects with Eclipse LSP | core | jdtls-lsp |
| `data-science` | Data science and notebook workflows | python | jupyter-tools, pandas-helpers |

### Step 4: Explain Inheritance

After the table, explain the inheritance model:

## Profile Inheritance

Profiles can extend other profiles to inherit their plugin settings:

```
core (base)
  ├── python
  │     └── data-science
  ├── typescript
  ├── javascript
  ├── go
  ├── rust
  └── java
```

When a profile extends another:
1. Parent profile's `enable` list is loaded first
2. Parent profile's `disable` list is loaded
3. Child profile's settings are merged (child takes precedence)

**Example:** The `python` profile extends `core`, so applying `python` gives you:
- All plugins from `core` (superpowers, claude-md-management, slack)
- Plus Python-specific plugins (pyright-lsp, python-development)

### Step 5: Explain disableInherited

Note which profiles use `disableInherited`:

## Global Plugin Behavior

Some profiles use `disableInherited: true` to ensure a clean, focused plugin set:

| Profile | disableInherited | Effect |
|---------|------------------|--------|
| `core` | true | Disables globally-enabled plugins not in core's enable list |
| `python` | false (default) | Inherits behavior from parent (core), adds Python plugins |
| Other profiles | varies | Check individual profile YAML |

**Override behavior with flags:**
- `--mode merge` - Force additive (keep global plugins)
- `--mode replace` - Force exclusive (disable unlisted global plugins)

### Step 6: Suggest Next Steps

Conclude with actionable next steps:

## Next Steps

To apply a profile:

```
/plugin-profile:apply <profile-name> [--mode merge|replace]
```

**Examples:**
- `/plugin-profile:apply python` - Apply Python profile
- `/plugin-profile:apply core --mode merge` - Apply core, keep global plugins
- `/plugin-profile:apply typescript --mode replace` - TypeScript only, disable others

## Profile Details

To view a specific profile's full configuration:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/shared/profiles/<profile>.yaml"
```

## Conflict Awareness

Some plugins conflict with each other. The profiles are designed to avoid conflicts, but if you manually enable additional plugins, check:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/shared/references/conflicts.md"
```

Common conflict pairs:
- `superpowers` vs `tdd-workflows` / `debugging-toolkit` / `comprehensive-review`
- `orchestration-toolkit` vs `agent-teams` / `agent-orchestration`

The `core` profile pre-emptively disables secondary plugins to avoid these conflicts.

## Related Skills

- `/plugin-profile:init` - Initialize profile configuration (main entry point)
- `/plugin-profile:detect` - Preview detection without applying changes
- `/plugin-profile:apply` - Apply a specific profile with mode control
- `/plugin-profile:status` - Show current configuration and diagnostics
