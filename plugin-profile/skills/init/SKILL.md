---
name: init
description: Initialize plugin profile configuration for a project. Auto-detects project type or accepts explicit profile. Main entry point.
---

# Plugin Profile Init

Initialize plugin profile configuration for a project. This is the main entry point for setting up project-specific plugin configurations.

## Usage

```
/plugin-profile:init [profile-name]
```

If no profile name is provided, auto-detection will determine the best profile for your project.

## Workflow

### Step 1: Check for Explicit Profile

If the user provided a profile name (e.g., `/plugin-profile:init python`):
- Skip auto-detection
- Verify the profile exists
- Proceed directly to Step 4

If no profile name provided, continue to Step 2.

### Step 2: Detect Project Type

Run the detection script to fingerprint the project:

```bash
"${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect.sh" .
```

This outputs JSON with:
- `profile`: Detected profile name
- `confidence`: Detection confidence level (high, medium, low)
- `fingerprints`: List of matched indicators

### Step 3: Review Detection Results

Display detection results to the user:

> **Detected Project Type:** [profile]
> **Confidence:** [high/medium/low]
> **Matched Fingerprints:**
> - [fingerprint 1]
> - [fingerprint 2]

**If confidence is "high"**: Proceed automatically to Step 4.

**If confidence is "medium" or "low"**: Ask for confirmation:

> "I detected this as a **[profile]** project with [confidence] confidence. Would you like to proceed with this profile, or specify a different one?"

If user wants a different profile, accept their choice and continue.

### Step 4: Apply Configuration

Run the apply script with the selected profile:

```bash
"${CLAUDE_PLUGIN_ROOT}/shared/scripts/apply.sh" "${CLAUDE_PLUGIN_ROOT}/shared/profiles/[profile].yaml" .
```

This writes plugin configuration to `.claude/settings.local.json`.

### Step 5: Display Summary

Report what was configured:

> **Profile Applied:** [profile name]
>
> **Plugins Enabled:**
> - plugin1
> - plugin2
>
> **Plugins Disabled:**
> - plugin3 (if any)
>
> **Configuration written to:** `.claude/settings.local.json`
>
> Restart Claude Code to apply changes.

## Available Profiles

- `core` - Universal plugins (superpowers, claude-md-management)
- `python` - Python + pyright-lsp
- `typescript` - TypeScript + typescript-lsp + context7
- `javascript` - JavaScript + typescript-lsp + context7
- `go` - Go + gopls-lsp
- `rust` - Rust + rust-analyzer-lsp
- `java` - Java + jdtls-lsp
- `data-science` - Notebooks + data tools

## Examples

Auto-detect and configure:
```
/plugin-profile:init
```

Specify a profile directly:
```
/plugin-profile:init typescript
```

Reset to core plugins only:
```
/plugin-profile:init core
```

## Related Skills

- `/plugin-profile:detect` - Detect project type without applying configuration
- `/plugin-profile:list` - List all available profiles
- `/plugin-profile:status` - Show current plugin configuration status
- `/plugin-profile:apply` - Apply a specific profile directly

## Troubleshooting

**"jq not installed"**: Install jq via `brew install jq` (macOS) or `apt install jq` (Linux).

**Wrong profile detected**: Use explicit profile argument: `/plugin-profile:init [correct-profile]`

**Plugin not working after apply**: Restart Claude Code to apply changes.
