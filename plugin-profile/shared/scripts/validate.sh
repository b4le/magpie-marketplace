#!/bin/bash
# Validate plugin configuration for conflicts
# Usage: validate.sh [project-dir]
# Output: JSON with detected conflicts and suggested resolutions
# Exit codes: 0 = no conflicts, 1 = conflicts found (advisory), 2 = error

set -uo pipefail

PROJECT_DIR="${1:-.}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

# Error output helper
error_json() {
    echo "{\"error\": \"$1\", \"conflicts\": []}" >&2
    exit 2
}

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    error_json "jq not installed"
fi

# Check if settings file exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"conflicts": [], "count": 0, "message": "No settings file found"}'
    exit 0
fi

# Validate JSON structure
if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
    error_json "Invalid JSON in settings file"
fi

# Get currently enabled plugins (one per line)
enabled_plugins=$(jq -r '
    (.enabledPlugins // {})
    | to_entries
    | map(select(.value == true) | .key)
    | .[]
' "$SETTINGS_FILE" 2>/dev/null) || enabled_plugins=""

# Exit early if no plugins enabled
if [[ -z "$enabled_plugins" ]]; then
    echo '{"conflicts": [], "count": 0}'
    exit 0
fi

# Helper: check if plugin is enabled (fixed-string matching to avoid regex injection)
is_enabled() {
    echo "$enabled_plugins" | grep -Fxq "$1"
}

# Define conflict rules (primary supersedes secondaries)
# Format: "primary|secondary1 secondary2 secondary3"
declare -a conflict_rules=(
    "superpowers@claude-plugins-official|tdd-workflows@claude-code-workflows debugging-toolkit@claude-code-workflows comprehensive-review@claude-code-workflows"
    "orchestration-toolkit@content-platform-marketplace|agent-teams@claude-code-workflows agent-orchestration@claude-code-workflows"
)

# Collect conflicts
declare -a conflict_pairs=()

for rule in "${conflict_rules[@]}"; do
    primary="${rule%%|*}"
    secondaries="${rule##*|}"

    if is_enabled "$primary"; then
        for secondary in $secondaries; do
            if is_enabled "$secondary"; then
                conflict_pairs+=("${primary}	${secondary}")
            fi
        done
    fi
done

# Output JSON
if [[ ${#conflict_pairs[@]} -eq 0 ]]; then
    echo '{"conflicts": [], "count": 0}'
    exit 0
fi

printf '%s\n' "${conflict_pairs[@]}" | jq -Rsn '
    [inputs | split("\n") | .[] | select(. != "") | split("\t") | {
        primary: .[0],
        secondary: .[1],
        resolution: "Disable \(.[1]) (functionality included in \(.[0]))",
        severity: "high"
    }] | {conflicts: ., count: length}
'

exit 1
