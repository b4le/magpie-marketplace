---
name: detect
description: Detect project type without applying configuration. Shows fingerprints and confidence level.
---

# Plugin Profile Detect

Detect the project type based on file fingerprints without applying any configuration changes. Useful for previewing what would be configured or debugging detection issues.

## Usage

```
/plugin-profile:detect
```

## Workflow

### Step 1: Run Detection

Execute the detection script to analyze the project:

```bash
"${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect.sh" .
```

### Step 2: Parse Detection Output

The script outputs JSON with the following structure:

```json
{
  "profile": "typescript",
  "confidence": "high",
  "fingerprints": [
    "tsconfig.json",
    "package.json with typescript dependency",
    ".ts files in src/"
  ]
}
```

### Step 3: Display Results

Present the detection results in a human-readable format:

> **Detected Profile:** [profile]
>
> **Confidence Level:** [high/medium/low]
>
> **Matched Fingerprints:**
> - [fingerprint 1]
> - [fingerprint 2]
> - [fingerprint 3]

### Step 4: Show What Would Be Configured

Read the detected profile YAML from `${CLAUDE_PLUGIN_ROOT}/shared/profiles/[profile].yaml` and display what would be configured:

> **If applied, this profile would:**
>
> **Enable:**
> - plugin1
> - plugin2
>
> **Disable:**
> - plugin3 (if any)
>
> **Extends:** [base profile] (if applicable)

### Step 5: Suggest Next Steps

Provide guidance on how to proceed:

> **Next Steps:**
> - To apply this configuration: `/plugin-profile:init` or `/plugin-profile:apply [profile]`
> - To use a different profile: `/plugin-profile:init [profile-name]`
> - To see all available profiles: `/plugin-profile:list`

## Confidence Levels

- **high**: Multiple strong indicators matched (e.g., tsconfig.json + package.json with typescript)
- **medium**: Some indicators matched but not definitive
- **low**: Few indicators matched, manual selection recommended

## Examples

Run detection on current project:
```
/plugin-profile:detect
```

Example output:
```
Detected Profile: python
Confidence Level: high

Matched Fingerprints:
- pyproject.toml
- requirements.txt
- .py files in src/

If applied, this profile would:

Enable:
- pyright-lsp
- superpowers
- claude-md-management

Extends: core

Next Steps:
- To apply this configuration: /plugin-profile:init
- To use a different profile: /plugin-profile:init [profile-name]
```

## Related Skills

- `/plugin-profile:init` - Initialize configuration (auto-detect + apply)
- `/plugin-profile:apply` - Apply a specific profile directly
- `/plugin-profile:list` - List all available profiles
- `/plugin-profile:status` - Show current plugin configuration status

## Troubleshooting

**"jq not installed"**: Install jq via `brew install jq` (macOS) or `apt install jq` (Linux).

**No profile detected**: The project may use a stack not covered by available profiles. Use `/plugin-profile:list` to see options and `/plugin-profile:init [profile]` to apply manually.

**Unexpected detection result**: Check the fingerprints list to understand what was matched. You can override by specifying a profile explicitly with `/plugin-profile:init [profile]`.
