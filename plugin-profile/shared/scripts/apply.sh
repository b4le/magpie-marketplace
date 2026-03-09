#!/bin/bash
# Apply a profile to .claude/settings.local.json
# Usage: apply.sh <profile-yaml-path> [project-dir] [--mode=profile|merge|replace]
#
# Supports profile inheritance via 'extends:' field
# Supports disableInherited to disable globally-enabled plugins not in profile
#
# Mode options:
#   profile (default): Use the profile's disableInherited setting
#   merge: Force additive merge (ignore disableInherited, current legacy behavior)
#   replace: Force disable all inherited/global plugins not explicitly enabled
#
# Exit codes: 0 = success, 1 = error

set -uo pipefail

# Argument validation
if [[ $# -lt 1 ]]; then
    echo "Usage: apply.sh <profile-yaml-path> [project-dir] [--mode=profile|merge|replace]" >&2
    exit 1
fi

PROFILE_PATH="$1"
PROJECT_DIR="${2:-.}"

# Parse optional --mode argument (can be 2nd or 3rd argument)
MODE="profile"
for arg in "${@:2}"; do
    if [[ "$arg" == --mode=* ]]; then
        MODE="${arg#--mode=}"
        if [[ "$MODE" != "profile" && "$MODE" != "merge" && "$MODE" != "replace" ]]; then
            echo "Error: Invalid mode '$MODE'. Must be one of: profile, merge, replace" >&2
            exit 1
        fi
    elif [[ "$arg" != "$PROJECT_DIR" && ! "$arg" == --* ]]; then
        # Non-flag argument that's not PROJECT_DIR - treat as PROJECT_DIR
        PROJECT_DIR="$arg"
    fi
done

SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
GLOBAL_SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/../profiles"

# Track visited profiles for cycle detection
declare -a VISITED_PROFILES=()

# Check for jq dependency (required)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first." >&2
    exit 1
fi

if [[ ! -f "$PROFILE_PATH" ]]; then
    echo "Error: Profile not found: $PROFILE_PATH" >&2
    exit 1
fi

# Create .claude directory if needed
mkdir -p "$PROJECT_DIR/.claude"

# Initialize settings file if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Function to extract plugins from a profile YAML
# Uses awk for more robust YAML section extraction
extract_plugins() {
    local profile_file="$1"
    local section="$2"  # "enable" or "disable"

    # Use awk to extract just the section, stopping at next section or end of plugins block
    awk -v section="  $section:" '
        $0 == section { capture=1; next }
        capture && /^  [a-z]+:/ { exit }
        capture && /^[^ ]/ { exit }
        capture && /^[[:space:]]+-/ {
            gsub(/^[[:space:]]+-[[:space:]]*/, "")
            gsub(/#.*/, "")
            gsub(/[[:space:]]/, "")
            if ($0 != "") print
        }
    ' "$profile_file" 2>/dev/null || true
}

# Function to get parent profile
get_parent_profile() {
    local profile_file="$1"
    grep -E '^extends:' "$profile_file" 2>/dev/null | sed 's/extends:[[:space:]]*//' | tr -d ' ' || true
}

# Function to get disableInherited setting from a profile
# Returns "true", "false", or empty string if not set
get_disable_inherited() {
    local profile_file="$1"
    local value
    value=$(grep -E '^disableInherited:' "$profile_file" 2>/dev/null | sed 's/disableInherited:[[:space:]]*//' | tr -d ' ' || true)
    # Normalize to lowercase
    echo "$value" | tr '[:upper:]' '[:lower:]'
}

# Function to get globally-enabled plugins from ~/.claude/settings.json
get_global_enabled_plugins() {
    if [[ ! -f "$GLOBAL_SETTINGS_FILE" ]]; then
        return
    fi
    jq -r '.enabledPlugins // {} | to_entries | map(select(.value == true)) | .[].key' "$GLOBAL_SETTINGS_FILE" 2>/dev/null || true
}

# Collect all plugins (handling inheritance with cycle detection)
collect_all_plugins() {
    local profile_file="$1"
    local profile_basename
    profile_basename=$(basename "$profile_file")

    # Cycle detection
    for visited in "${VISITED_PROFILES[@]:-}"; do
        if [[ "$visited" == "$profile_basename" ]]; then
            echo "Error: Circular inheritance detected: $profile_basename" >&2
            exit 1
        fi
    done
    VISITED_PROFILES+=("$profile_basename")

    local enable_list=""
    local disable_list=""

    # Check for parent profile
    local parent
    parent=$(get_parent_profile "$profile_file")
    if [[ -n "$parent" ]]; then
        local parent_path="$PROFILES_DIR/$parent.yaml"
        if [[ ! -f "$parent_path" ]]; then
            echo "Error: Parent profile '$parent' not found (referenced by $profile_file)" >&2
            exit 1
        fi
        # Recursively get parent plugins first
        local parent_result
        parent_result=$(collect_all_plugins "$parent_path")
        enable_list=$(echo "$parent_result" | sed -n '1,/^---SEPARATOR---$/p' | grep -v '^---SEPARATOR---$' || true)
        disable_list=$(echo "$parent_result" | sed -n '/^---SEPARATOR---$/,$p' | grep -v '^---SEPARATOR---$' || true)
    fi

    # Add current profile's plugins (child overrides parent)
    local current_enable
    local current_disable
    current_enable=$(extract_plugins "$profile_file" "enable")
    current_disable=$(extract_plugins "$profile_file" "disable")

    # Merge: append current to parent
    if [[ -n "$current_enable" ]]; then
        if [[ -n "$enable_list" ]]; then
            enable_list="$enable_list"$'\n'"$current_enable"
        else
            enable_list="$current_enable"
        fi
    fi
    if [[ -n "$current_disable" ]]; then
        if [[ -n "$disable_list" ]]; then
            disable_list="$disable_list"$'\n'"$current_disable"
        else
            disable_list="$current_disable"
        fi
    fi

    # Output with separator
    echo "$enable_list"
    echo "---SEPARATOR---"
    echo "$disable_list"
}

# Collect plugins with inheritance
all_plugins=$(collect_all_plugins "$PROFILE_PATH")
enable_plugins=$(echo "$all_plugins" | sed -n '1,/^---SEPARATOR---$/p' | grep -v '^---SEPARATOR---$' | sort -u | grep -v '^$' || true)
disable_plugins=$(echo "$all_plugins" | sed -n '/^---SEPARATOR---$/,$p' | grep -v '^---SEPARATOR---$' | sort -u | grep -v '^$' || true)

# Determine if disableInherited should be applied
disable_inherited_effective="false"
if [[ "$MODE" == "replace" ]]; then
    disable_inherited_effective="true"
elif [[ "$MODE" == "profile" ]]; then
    # Check the profile's disableInherited setting
    profile_disable_inherited=$(get_disable_inherited "$PROFILE_PATH")
    if [[ "$profile_disable_inherited" == "true" ]]; then
        disable_inherited_effective="true"
    fi
fi
# MODE == "merge" leaves disable_inherited_effective as "false"

# If disableInherited is effective, add globally-enabled plugins to disable list
if [[ "$disable_inherited_effective" == "true" ]]; then
    global_plugins=$(get_global_enabled_plugins)
    if [[ -n "$global_plugins" ]]; then
        while IFS= read -r global_plugin; do
            [[ -z "$global_plugin" ]] && continue
            # Check if this global plugin is in the enable list
            if ! echo "$enable_plugins" | grep -Fxq "$global_plugin"; then
                # Not in enable list, add to disable list
                if [[ -n "$disable_plugins" ]]; then
                    disable_plugins="$disable_plugins"$'\n'"$global_plugin"
                else
                    disable_plugins="$global_plugin"
                fi
            fi
        done <<< "$global_plugins"
        # Re-sort and dedupe
        disable_plugins=$(echo "$disable_plugins" | sort -u | grep -v '^$' || true)
    fi
fi

# Build JSON object efficiently using jq
# Convert plugin lists to JSON in single operations
enable_json=$(echo "$enable_plugins" | grep -v '^$' | jq -Rn '[inputs] | map({(.): true}) | add // {}' 2>/dev/null || echo '{}')
disable_json=$(echo "$disable_plugins" | grep -v '^$' | jq -Rn '[inputs] | map({(.): false}) | add // {}' 2>/dev/null || echo '{}')

# Merge: enable wins over disable
json_obj=$(jq -n --argjson e "$enable_json" --argjson d "$disable_json" '$d + $e')

# Filter out any plugins that are in both enable and disable (enable wins, already handled above)
# Remove disabled plugins that are also enabled
for plugin in $enable_plugins; do
    [[ -z "$plugin" ]] && continue
    # Use fixed-string matching to avoid regex injection
    if echo "$disable_plugins" | grep -Fxq "$plugin"; then
        json_obj=$(echo "$json_obj" | jq --arg p "$plugin" '.[$p] = true')
    fi
done

# Merge into existing settings (preserving other settings)
existing=$(cat "$SETTINGS_FILE")
TEMP_FILE="$SETTINGS_FILE.tmp.$$"
trap 'rm -f "$TEMP_FILE" 2>/dev/null' EXIT

echo "$existing" | jq --argjson plugins "$json_obj" '. + {enabledPlugins: ((.enabledPlugins // {}) + $plugins)}' > "$TEMP_FILE"
mv "$TEMP_FILE" "$SETTINGS_FILE"

echo "Applied profile to $SETTINGS_FILE"
