#!/bin/bash
# validate-plugin.sh - Validates entire Claude Code plugin structure
# Usage: ./validate-plugin.sh <plugin-root>
# Exit 0 on pass, exit 1 on fail with summary

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()
COMPONENT_ERRORS=0

# Get script directory for finding other validators
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared schema validation helper
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_schema-validate.sh"

log_error() {
    ERRORS+=("$1")
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    WARNINGS+=("$1")
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_info() {
    echo -e "[INFO] $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

show_help() {
    cat << 'EOF'
validate-plugin.sh - Validates entire Claude Code plugin structure

USAGE:
    ./validate-plugin.sh <plugin-root>
    ./validate-plugin.sh --help

ARGUMENTS:
    plugin-root    Path to the plugin root directory

DESCRIPTION:
    Validates the structure of a single plugin by checking its plugin.json
    manifest and running component validators for skills, commands, hooks,
    and output styles. Delegates to:
        - validate-skill.sh    for each referenced skill
        - validate-command.sh  for each referenced command
        - validate-hook.sh     for each referenced hook
        - validate-output-style.sh  for each referenced output style

VALIDATION RULES:
    Manifest (plugin.json or .claude-plugin/plugin.json):
        - Must be valid JSON
        - Must contain 'name', 'version', and 'description' fields
        - 'version' should follow semver (x.y.z)
        - All referenced component paths must resolve to existing files

    Documentation:
        - README.md must exist with >10 lines
        - README should mention installation

    Security:
        - No hardcoded personal paths across all plugin files

EXIT CODES:
    0    Validation passed (warnings possible)
    1    One or more validation errors found

EXAMPLES:
    ./validate-plugin.sh ./productivity-toolkit
    ./validate-plugin.sh /path/to/marketplace/my-plugin
EOF
}

# Check for help flag before processing other arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <plugin-root>"
    echo "       $0 --help"
    echo "  plugin-root: Path to the plugin root directory"
    exit 1
fi

PLUGIN_ROOT="$1"

# Resolve to absolute path
if [[ ! "$PLUGIN_ROOT" = /* ]]; then
    PLUGIN_ROOT="$(pwd)/$PLUGIN_ROOT"
fi

echo "=========================================="
echo "Validating Plugin: $PLUGIN_ROOT"
echo "=========================================="

# Check if directory exists
if [[ ! -d "$PLUGIN_ROOT" ]]; then
    log_error "Plugin root is not a directory: $PLUGIN_ROOT"
    exit 1
fi

# ============================================
# Check plugin.json
# ============================================
log_section "Plugin Manifest (plugin.json)"

# plugin.json may be at the root or in .claude-plugin/ (marketplace convention).
# The root location takes precedence; .claude-plugin/ is the published form.
if [[ -f "$PLUGIN_ROOT/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/plugin.json"
elif [[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
    log_info "Found plugin.json at marketplace location: .claude-plugin/plugin.json"
else
    PLUGIN_JSON=""
fi

if [[ -z "$PLUGIN_JSON" ]]; then
    log_error "plugin.json not found in $PLUGIN_ROOT (checked root and .claude-plugin/)"
else
    log_success "plugin.json exists"

    # jq is used for reliable JSON parsing; fall back to a warning if not installed
    if command -v jq &> /dev/null; then
        if jq empty "$PLUGIN_JSON" 2>/dev/null; then
            log_success "plugin.json is valid JSON"

            # Schema validation (field types, patterns, enums, additionalProperties)
            SCHEMA_FILE="$SCRIPT_DIR/../schemas/plugin.schema.json"
            if [[ -f "$SCHEMA_FILE" ]]; then
                SCHEMA_RC=0
                SCHEMA_OUTPUT=$(validate_json_schema "$SCHEMA_FILE" "$PLUGIN_JSON" 2>&1) || SCHEMA_RC=$?
                if [[ $SCHEMA_RC -eq 0 ]]; then
                    log_success "plugin.json passes schema validation"
                elif [[ $SCHEMA_RC -eq 1 ]]; then
                    while IFS= read -r schema_err; do
                        [[ -n "$schema_err" ]] && log_error "$schema_err"
                    done <<< "$SCHEMA_OUTPUT"
                else
                    log_info "${SCHEMA_OUTPUT:-Schema validation skipped (tools not available)}"
                fi
            fi

            # Extract key fields for downstream use and basic presence checks.
            # Schema handles type/pattern/enum validation; these checks ensure
            # the plugin is functional (name is required by schema, version and
            # description are strongly recommended).
            NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
            VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")
            DESCRIPTION=$(jq -r '.description // empty' "$PLUGIN_JSON")

            if [[ -n "$NAME" ]]; then
                log_success "Required field 'name': $NAME"
            else
                log_error "Required field 'name' missing from plugin.json"
            fi

            if [[ -n "$VERSION" ]]; then
                log_success "Field 'version': $VERSION"
            else
                log_warning "Field 'version' missing from plugin.json"
            fi

            if [[ -n "$DESCRIPTION" ]]; then
                log_success "Field 'description' present"
            else
                log_warning "Field 'description' missing from plugin.json"
            fi

            # Extract component paths (handles both string arrays and object arrays with .path).
            # Components may be listed as plain strings or as objects containing a "path" field.

            # Skills: each entry is a directory path containing a SKILL.md
            SKILL_PATHS=$(jq -r '.skills[]? | if type == "object" then .path else . end // empty' "$PLUGIN_JSON" 2>/dev/null)

            # Commands: each entry is a path to a .md command file
            COMMAND_PATHS=$(jq -r '.commands[]? | if type == "object" then .path else . end // empty' "$PLUGIN_JSON" 2>/dev/null)

            # Hooks: can be a string path to hooks.json, an object, an array
            HOOKS_TYPE=$(jq -r '.hooks | type // "null"' "$PLUGIN_JSON" 2>/dev/null)
            HOOKS_STRING_PATH=""
            if [[ "$HOOKS_TYPE" == "string" ]]; then
                HOOKS_STRING_PATH=$(jq -r '.hooks' "$PLUGIN_JSON" 2>/dev/null)
            fi

            HOOK_PATHS=$(jq -r '
                if .hooks | type == "array" then
                    .hooks[]? | if type == "object" then (.path // .command) else . end
                else
                    empty
                end // empty
            ' "$PLUGIN_JSON" 2>/dev/null)

            # Output styles: each entry is a path to a .md style file
            STYLE_PATHS=$(jq -r '.outputStyles[]? | if type == "object" then .path else . end // empty' "$PLUGIN_JSON" 2>/dev/null)

            # Agents: each entry is a path to an agent .md/.yaml file
            AGENT_PATHS=$(jq -r '.agents[]? | if type == "object" then .path else . end // empty' "$PLUGIN_JSON" 2>/dev/null)

            # Warn if the manifest contains explicit component arrays that Claude Code rejects.
            # Claude Code's internal validator does not accept skills, commands, agents, or
            # outputStyles in plugin.json — components are auto-discovered from conventional
            # directories (skills/, commands/, agents/, output-styles/).
            EXPLICIT_FIELDS=()
            for field in skills commands agents outputStyles; do
                if jq -e --arg f "$field" 'has($f)' "$PLUGIN_JSON" &>/dev/null; then
                    EXPLICIT_FIELDS+=("$field")
                fi
            done
            if [[ ${#EXPLICIT_FIELDS[@]} -gt 0 ]]; then
                log_warning "plugin.json contains explicit component field(s): ${EXPLICIT_FIELDS[*]}. These fields are rejected by Claude Code's internal validator. Remove them — components are auto-discovered from conventional directories (skills/, commands/, agents/, output-styles/)."
            fi
        else
            log_error "plugin.json is not valid JSON"
        fi
    else
        log_warning "jq not installed - skipping JSON validation. Install jq for full validation."
    fi
fi

# ============================================
# Check README.md
# ============================================
log_section "Documentation (README.md)"

README="$PLUGIN_ROOT/README.md"

if [[ ! -f "$README" ]]; then
    log_error "README.md not found in $PLUGIN_ROOT"
else
    log_success "README.md exists"

    # Check for minimum content
    README_LINES=$(wc -l < "$README" | tr -d ' ')
    if [[ $README_LINES -lt 10 ]]; then
        log_warning "README.md is very short ($README_LINES lines)"
    else
        log_info "README.md has $README_LINES lines"
    fi

    # Check for installation instructions
    if grep -qi "install" "$README"; then
        log_success "README contains installation information"
    else
        log_warning "README may be missing installation instructions"
    fi
fi

# ============================================
# Validate Skills
# ============================================
log_section "Skills Validation"

if [[ -n "${SKILL_PATHS:-}" ]]; then
    while IFS= read -r skill_path; do
        [[ -z "$skill_path" ]] && continue

        FULL_PATH="$PLUGIN_ROOT/$skill_path"

        if [[ ! -d "$FULL_PATH" ]]; then
            log_error "Referenced skill not found: $skill_path"
            continue
        fi

        log_info "Validating skill: $skill_path"

        if [[ -x "$SCRIPT_DIR/validate-skill.sh" ]]; then
            TEMP_LOG="${TMPDIR:-/tmp}/skill_validation_$$.log"
            if "$SCRIPT_DIR/validate-skill.sh" "$FULL_PATH" > "$TEMP_LOG" 2>&1; then
                log_success "Skill passed: $skill_path"
            else
                log_error "Skill failed validation: $skill_path"
                ((COMPONENT_ERRORS++))
                # Show key errors
                grep -E "^\[ERROR\]" "$TEMP_LOG" 2>/dev/null | head -3 | while read -r line; do
                    echo "    $line"
                done
            fi
            rm -f "$TEMP_LOG" 2>/dev/null
        else
            log_warning "validate-skill.sh not found - skipping skill validation"
        fi
    done <<< "$SKILL_PATHS"
else
    # Look for skills directory
    if [[ -d "$PLUGIN_ROOT/skills" ]]; then
        for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
            [[ ! -d "$skill_dir" ]] && continue

            log_info "Found skill: $(basename "$skill_dir")"

            if [[ -x "$SCRIPT_DIR/validate-skill.sh" ]]; then
                TEMP_LOG="${TMPDIR:-/tmp}/skill_validation_$$.log"
                if "$SCRIPT_DIR/validate-skill.sh" "$skill_dir" > "$TEMP_LOG" 2>&1; then
                    log_success "Skill passed: $(basename "$skill_dir")"
                else
                    log_error "Skill failed: $(basename "$skill_dir")"
                    ((COMPONENT_ERRORS++))
                fi
                rm -f "$TEMP_LOG" 2>/dev/null
            fi
        done
    else
        log_info "No skills directory found"
    fi
fi

# ============================================
# Validate Commands
# ============================================
log_section "Commands Validation"

if [[ -n "${COMMAND_PATHS:-}" ]]; then
    while IFS= read -r cmd_path; do
        [[ -z "$cmd_path" ]] && continue

        FULL_PATH="$PLUGIN_ROOT/$cmd_path"

        if [[ ! -f "$FULL_PATH" ]]; then
            log_error "Referenced command not found: $cmd_path"
            continue
        fi

        log_info "Validating command: $cmd_path"

        if [[ -x "$SCRIPT_DIR/validate-command.sh" ]]; then
            TEMP_LOG="${TMPDIR:-/tmp}/cmd_validation_$$.log"
            if "$SCRIPT_DIR/validate-command.sh" "$FULL_PATH" > "$TEMP_LOG" 2>&1; then
                log_success "Command passed: $cmd_path"
            else
                log_error "Command failed validation: $cmd_path"
                ((COMPONENT_ERRORS++))
            fi
            rm -f "$TEMP_LOG" 2>/dev/null
        fi
    done <<< "$COMMAND_PATHS"
else
    # Look for commands directory
    if [[ -d "$PLUGIN_ROOT/commands" ]]; then
        for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
            [[ ! -f "$cmd_file" ]] && continue

            log_info "Found command: $(basename "$cmd_file")"

            if [[ -x "$SCRIPT_DIR/validate-command.sh" ]]; then
                TEMP_LOG="${TMPDIR:-/tmp}/cmd_validation_$$.log"
                if "$SCRIPT_DIR/validate-command.sh" "$cmd_file" > "$TEMP_LOG" 2>&1; then
                    log_success "Command passed: $(basename "$cmd_file")"
                else
                    log_error "Command failed: $(basename "$cmd_file")"
                    ((COMPONENT_ERRORS++))
                fi
                rm -f "$TEMP_LOG" 2>/dev/null
            fi
        done
    else
        log_info "No commands directory found"
    fi
fi

# ============================================
# Validate Hooks
# ============================================
log_section "Hooks Validation"

if [[ -n "${HOOK_PATHS:-}" ]]; then
    while IFS= read -r hook_path; do
        [[ -z "$hook_path" ]] && continue

        FULL_PATH="$PLUGIN_ROOT/$hook_path"

        if [[ ! -f "$FULL_PATH" ]]; then
            log_error "Referenced hook not found: $hook_path"
            continue
        fi

        log_info "Validating hook: $hook_path"

        if [[ -x "$SCRIPT_DIR/validate-hook.sh" ]]; then
            TEMP_LOG="${TMPDIR:-/tmp}/hook_validation_$$.log"
            if "$SCRIPT_DIR/validate-hook.sh" "$FULL_PATH" > "$TEMP_LOG" 2>&1; then
                log_success "Hook passed: $hook_path"
            else
                log_error "Hook failed validation: $hook_path"
                ((COMPONENT_ERRORS++))
            fi
            rm -f "$TEMP_LOG" 2>/dev/null
        fi
    done <<< "$HOOK_PATHS"
else
    # Only scan the dedicated hooks/ directory. scripts/ is a utility directory
    # and must not be treated as a hook source — doing so causes false positives
    # for plugins that have utility scripts but no hooks.
    if [[ -d "$PLUGIN_ROOT/hooks" ]]; then
        for hook_file in "$PLUGIN_ROOT/hooks"/*; do
            [[ ! -f "$hook_file" ]] && continue
            [[ "$hook_file" =~ \.md$ ]] && continue    # Skip markdown docs
            [[ "$hook_file" =~ \.json$ ]] && continue  # Skip JSON config files
            [[ "$hook_file" =~ \.plist$ ]] && continue # Skip launchd plist files

            log_info "Found hook: $(basename "$hook_file")"

            if [[ -x "$SCRIPT_DIR/validate-hook.sh" ]]; then
                TEMP_LOG="${TMPDIR:-/tmp}/hook_validation_$$.log"
                if "$SCRIPT_DIR/validate-hook.sh" "$hook_file" > "$TEMP_LOG" 2>&1; then
                    log_success "Hook passed: $(basename "$hook_file")"
                else
                    log_error "Hook failed: $(basename "$hook_file")"
                    ((COMPONENT_ERRORS++))
                fi
                rm -f "$TEMP_LOG" 2>/dev/null
            fi
        done
    else
        log_info "No hooks declared — skipping hook validation"
    fi
fi

# ============================================
# Validate hooks.json (when hooks is a string path)
# ============================================
if [[ -n "${HOOKS_STRING_PATH:-}" ]]; then
    log_section "hooks.json Validation"

    HOOKS_JSON_FULL="$PLUGIN_ROOT/$HOOKS_STRING_PATH"

    if [[ ! -f "$HOOKS_JSON_FULL" ]]; then
        log_error "hooks.json not found at: $HOOKS_STRING_PATH"
    else
        log_success "hooks.json exists at $HOOKS_STRING_PATH"

        # Validate JSON syntax
        if command -v jq &> /dev/null; then
            if jq empty "$HOOKS_JSON_FULL" 2>/dev/null; then
                log_success "hooks.json is valid JSON"

                # Schema validation against hooks.schema.json
                HOOKS_SCHEMA="$SCRIPT_DIR/../schemas/hooks.schema.json"
                if [[ -f "$HOOKS_SCHEMA" ]]; then
                    SCHEMA_RC=0
                    SCHEMA_OUTPUT=$(validate_json_schema "$HOOKS_SCHEMA" "$HOOKS_JSON_FULL" 2>&1) || SCHEMA_RC=$?
                    if [[ $SCHEMA_RC -eq 0 ]]; then
                        log_success "hooks.json passes schema validation"
                    elif [[ $SCHEMA_RC -eq 1 ]]; then
                        while IFS= read -r schema_err; do
                            [[ -n "$schema_err" ]] && log_error "$schema_err"
                        done <<< "$SCHEMA_OUTPUT"
                    else
                        log_info "${SCHEMA_OUTPUT:-Schema validation skipped (tools not available)}"
                    fi
                fi

                # ---- Security: HTTP hook type detection ----
                # HTTP hooks POST the full event payload (including env vars listed in
                # allowedEnvVars) to an arbitrary URL.  They are the highest-risk hook
                # type because they can silently exfiltrate credentials with no local
                # script artefact visible in the repo.
                HTTP_HOOK_COUNT=$(jq '[
                    .hooks // {} | to_entries[] | .value[]? | .hooks[]? |
                    select(.type == "http")
                ] | length' "$HOOKS_JSON_FULL" 2>/dev/null || echo 0)

                if [[ "$HTTP_HOOK_COUNT" -gt 0 ]]; then
                    log_error "SECURITY [CRITICAL]: $HTTP_HOOK_COUNT HTTP hook(s) detected in hooks.json — HTTP hooks POST event payloads to external URLs and can exfiltrate credentials"

                    # Surface the URLs for inspection
                    HTTP_URLS=$(jq -r '
                        .hooks // {} | to_entries[] | .value[]? | .hooks[]? |
                        select(.type == "http") | .url // "(no url)"
                    ' "$HOOKS_JSON_FULL" 2>/dev/null || true)
                    while IFS= read -r http_url; do
                        [[ -z "$http_url" ]] && continue
                        log_error "  HTTP hook URL: $http_url"
                    done <<< "$HTTP_URLS"

                    # Check allowedEnvVars for credential-shaped names
                    SENSITIVE_ENV_VARS=$(jq -r '
                        .hooks // {} | to_entries[] | .value[]? | .hooks[]? |
                        select(.type == "http") |
                        (.allowedEnvVars // [])[] |
                        select(test("KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTH"; "i"))
                    ' "$HOOKS_JSON_FULL" 2>/dev/null || true)
                    if [[ -n "$SENSITIVE_ENV_VARS" ]]; then
                        log_error "SECURITY [CRITICAL]: HTTP hook allowedEnvVars contains credential-shaped variable(s):"
                        while IFS= read -r env_var; do
                            [[ -z "$env_var" ]] && continue
                            log_error "  $env_var"
                        done <<< "$SENSITIVE_ENV_VARS"
                    fi
                fi

                # ---- Security: Agent hook tool scope ----
                # Agent hooks that list Bash or Write in their tools array can execute
                # arbitrary commands or modify files on the host.
                DANGEROUS_AGENT_HOOKS=$(jq -r '
                    .hooks // {} | to_entries[] | .value[]? | .hooks[]? |
                    select(.type == "agent") |
                    select((.tools // []) | map(select(test("^(Bash|Write|Edit|MultiEdit)$"))) | length > 0) |
                    "tools: \((.tools // []) | join(", "))"
                ' "$HOOKS_JSON_FULL" 2>/dev/null || true)

                if [[ -n "$DANGEROUS_AGENT_HOOKS" ]]; then
                    log_error "SECURITY [HIGH]: agent hook(s) with powerful tools detected — agent hooks with Bash/Write/Edit can execute arbitrary code:"
                    while IFS= read -r agent_info; do
                        [[ -z "$agent_info" ]] && continue
                        log_error "  $agent_info"
                    done <<< "$DANGEROUS_AGENT_HOOKS"
                fi

                # Check that referenced scripts exist and are executable.
                # Hook commands use ${CLAUDE_PLUGIN_ROOT} which resolves to the plugin root at runtime.
                HOOK_COMMANDS=$(jq -r '
                    .hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty
                ' "$HOOKS_JSON_FULL" 2>/dev/null || true)

                if [[ -n "$HOOK_COMMANDS" ]]; then
                    while IFS= read -r cmd; do
                        [[ -z "$cmd" ]] && continue

                        # Resolve ${CLAUDE_PLUGIN_ROOT} to actual plugin root
                        RESOLVED_CMD="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"

                        # Extract the script path (first token, stripping any arguments)
                        # Handle both "path/to/script" and "python3 path/to/script"
                        SCRIPT_PATH=$(echo "$RESOLVED_CMD" | awk '{print $NF}')
                        # Also try first token for simple commands
                        FIRST_TOKEN=$(echo "$RESOLVED_CMD" | awk '{print $1}')

                        if [[ -f "$SCRIPT_PATH" ]]; then
                            if [[ -x "$SCRIPT_PATH" ]]; then
                                log_success "Hook script exists and executable: $(basename "$SCRIPT_PATH")"
                            else
                                log_warning "Hook script exists but not executable: $SCRIPT_PATH"
                            fi
                        elif [[ -f "$FIRST_TOKEN" ]]; then
                            if [[ -x "$FIRST_TOKEN" ]]; then
                                log_success "Hook script exists and executable: $(basename "$FIRST_TOKEN")"
                            else
                                log_warning "Hook script exists but not executable: $FIRST_TOKEN"
                            fi
                        else
                            # Could be an interpreter command (python3, node, etc.)
                            if command -v "$FIRST_TOKEN" &>/dev/null && [[ -f "$SCRIPT_PATH" || -f "$(echo "$RESOLVED_CMD" | awk '{print $2}')" ]]; then
                                log_success "Hook command resolves via interpreter: $FIRST_TOKEN"
                            else
                                log_warning "Hook script may not resolve: $cmd"
                            fi
                        fi
                    done <<< "$HOOK_COMMANDS"
                fi
            else
                log_error "hooks.json is not valid JSON"
            fi
        else
            log_warning "jq not installed — skipping hooks.json validation"
        fi
    fi
fi

# ============================================
# Validate Output Styles
# ============================================
log_section "Output Styles Validation"

if [[ -n "${STYLE_PATHS:-}" ]]; then
    while IFS= read -r style_path; do
        [[ -z "$style_path" ]] && continue

        FULL_PATH="$PLUGIN_ROOT/$style_path"

        if [[ ! -f "$FULL_PATH" ]]; then
            log_error "Referenced output style not found: $style_path"
            continue
        fi

        log_info "Validating output style: $style_path"

        if [[ -x "$SCRIPT_DIR/validate-output-style.sh" ]]; then
            TEMP_LOG="${TMPDIR:-/tmp}/style_validation_$$.log"
            if "$SCRIPT_DIR/validate-output-style.sh" "$FULL_PATH" > "$TEMP_LOG" 2>&1; then
                log_success "Output style passed: $style_path"
            else
                log_error "Output style failed: $style_path"
                ((COMPONENT_ERRORS++))
            fi
            rm -f "$TEMP_LOG" 2>/dev/null
        fi
    done <<< "$STYLE_PATHS"
else
    # Look for output-styles directory
    if [[ -d "$PLUGIN_ROOT/output-styles" ]]; then
        for style_file in "$PLUGIN_ROOT/output-styles"/*.md; do
            [[ ! -f "$style_file" ]] && continue

            log_info "Found output style: $(basename "$style_file")"

            if [[ -x "$SCRIPT_DIR/validate-output-style.sh" ]]; then
                TEMP_LOG="${TMPDIR:-/tmp}/style_validation_$$.log"
                if "$SCRIPT_DIR/validate-output-style.sh" "$style_file" > "$TEMP_LOG" 2>&1; then
                    log_success "Output style passed: $(basename "$style_file")"
                else
                    log_error "Output style failed: $(basename "$style_file")"
                    ((COMPONENT_ERRORS++))
                fi
                rm -f "$TEMP_LOG" 2>/dev/null
            fi
        done
    else
        log_info "No output-styles directory found"
    fi
fi

# ============================================
# Validate Agents
# ============================================
log_section "Agents Validation"

if [[ -n "${AGENT_PATHS:-}" ]]; then
    while IFS= read -r agent_path; do
        [[ -z "$agent_path" ]] && continue

        FULL_PATH="$PLUGIN_ROOT/$agent_path"

        if [[ ! -f "$FULL_PATH" ]]; then
            log_error "Referenced agent not found: $agent_path"
            continue
        fi

        log_info "Validating agent: $agent_path"

        if [[ -x "$SCRIPT_DIR/validate-agent.sh" ]]; then
            TEMP_LOG="${TMPDIR:-/tmp}/agent_validation_$$.log"
            if "$SCRIPT_DIR/validate-agent.sh" "$FULL_PATH" > "$TEMP_LOG" 2>&1; then
                log_success "Agent passed: $agent_path"
            else
                log_error "Agent failed validation: $agent_path"
                ((COMPONENT_ERRORS++))
                grep -E "^\[ERROR\]" "$TEMP_LOG" 2>/dev/null | head -3 | while read -r line; do
                    echo "    $line"
                done
            fi
            rm -f "$TEMP_LOG" 2>/dev/null
        else
            log_warning "validate-agent.sh not found - skipping agent validation"
        fi
    done <<< "$AGENT_PATHS"
else
    # Look for agents directory
    if [[ -d "$PLUGIN_ROOT/agents" ]]; then
        for agent_file in "$PLUGIN_ROOT/agents"/*.md "$PLUGIN_ROOT/agents"/*.yaml; do
            [[ ! -f "$agent_file" ]] && continue

            log_info "Found agent: $(basename "$agent_file")"

            if [[ -x "$SCRIPT_DIR/validate-agent.sh" ]]; then
                TEMP_LOG="${TMPDIR:-/tmp}/agent_validation_$$.log"
                if "$SCRIPT_DIR/validate-agent.sh" "$agent_file" > "$TEMP_LOG" 2>&1; then
                    log_success "Agent passed: $(basename "$agent_file")"
                else
                    log_error "Agent failed: $(basename "$agent_file")"
                    ((COMPONENT_ERRORS++))
                fi
                rm -f "$TEMP_LOG" 2>/dev/null
            fi
        done
    else
        log_info "No agents directory found"
    fi
fi

# ============================================
# Global Personal Identifier Check
# ============================================
log_section "Global Security Check"

log_info "Scanning for personal identifiers across all files..."

# Exclude common documentation example patterns (username, dev, <username>, yourname, you, example, etc.)
# shellcheck disable=SC1003  # backslash in grep pattern is intentional (literal \\ in regex)
PERSONAL_FILES=$(grep -rE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\' "$PLUGIN_ROOT" 2>/dev/null | grep -v "Binary file" | grep -v '/tests/' | grep -vE '/Users/(username|dev|yourname|you|example|user|name)|/home/(username|dev|yourname|you|example|user|name)|C:\\Users\\(<username>|username|dev|yourname|you|example|user)' | head -10 || true)

if [[ -n "$PERSONAL_FILES" ]]; then
    log_error "Personal identifiers found in plugin files:"
    echo "$PERSONAL_FILES" | while read -r line; do
        echo "    $line"
    done
else
    log_success "No personal identifiers found in plugin"
fi

# ============================================
# MCP Server Config Validation
# ============================================
log_section "MCP Server Security"

if [[ -n "${PLUGIN_JSON:-}" ]] && command -v jq &>/dev/null && [[ -f "${PLUGIN_JSON:-}" ]]; then
    MCP_TYPE=$(jq -r '.mcpServers | type // "null"' "$PLUGIN_JSON" 2>/dev/null || echo "null")

    if [[ "$MCP_TYPE" != "null" ]]; then
        log_info "mcpServers field present (type: $MCP_TYPE)"

        if [[ "$MCP_TYPE" == "object" ]]; then
            # Inline MCP config — inspect each server entry for risky patterns
            # The schema allows additionalProperties: true here, meaning any fields
            # are accepted without validation.  We check for common risk indicators.

            # Servers with 'command' fields can execute arbitrary binaries
            MCP_COMMAND_COUNT=$(jq '[.mcpServers | to_entries[]? | select(.value | type == "object") | select(.value.command != null)] | length' "$PLUGIN_JSON" 2>/dev/null || echo 0)
            if [[ "$MCP_COMMAND_COUNT" -gt 0 ]]; then
                log_warning "SECURITY [HIGH]: inline mcpServers config contains $MCP_COMMAND_COUNT server(s) with 'command' fields — these execute binaries on the host"
                MCP_COMMANDS=$(jq -r '.mcpServers | to_entries[]? | select(.value | type == "object") | select(.value.command != null) | "\(.key): \(.value.command)"' "$PLUGIN_JSON" 2>/dev/null || true)
                while IFS= read -r mcp_cmd; do
                    [[ -z "$mcp_cmd" ]] && continue
                    log_warning "  MCP server command: $mcp_cmd"
                done <<< "$MCP_COMMANDS"
            fi

            # Servers with 'url' fields make outbound network connections
            MCP_URL_COUNT=$(jq '[.mcpServers | to_entries[]? | select(.value | type == "object") | select(.value.url != null)] | length' "$PLUGIN_JSON" 2>/dev/null || echo 0)
            if [[ "$MCP_URL_COUNT" -gt 0 ]]; then
                log_warning "SECURITY [MEDIUM]: inline mcpServers config contains $MCP_URL_COUNT server(s) with 'url' fields — these make outbound connections"
                MCP_URLS=$(jq -r '.mcpServers | to_entries[]? | select(.value | type == "object") | select(.value.url != null) | "\(.key): \(.value.url)"' "$PLUGIN_JSON" 2>/dev/null || true)
                while IFS= read -r mcp_url; do
                    [[ -z "$mcp_url" ]] && continue
                    log_info "  MCP server URL: $mcp_url"
                done <<< "$MCP_URLS"
            fi

            # Servers referencing npm/npx packages from untrusted sources
            MCP_NPX=$(jq -r '.mcpServers | to_entries[]? | select(.value | type == "object") | select((.value.command // "") | test("npx|npm")) | "\(.key): \(.value.command)"' "$PLUGIN_JSON" 2>/dev/null || true)
            if [[ -n "$MCP_NPX" ]]; then
                log_warning "SECURITY [HIGH]: MCP server(s) use npx/npm to launch — supply chain risk if package is not pinned"
                while IFS= read -r npx_entry; do
                    [[ -z "$npx_entry" ]] && continue
                    log_warning "  $npx_entry"
                done <<< "$MCP_NPX"
            fi

        elif [[ "$MCP_TYPE" == "string" || "$MCP_TYPE" == "array" ]]; then
            # Path reference(s) — resolve and check existence
            if [[ "$MCP_TYPE" == "string" ]]; then
                MCP_PATH=$(jq -r '.mcpServers' "$PLUGIN_JSON" 2>/dev/null)
                MCP_FULL="$PLUGIN_ROOT/$MCP_PATH"
                if [[ -f "$MCP_FULL" ]]; then
                    log_success "mcpServers path resolves: $MCP_PATH"
                else
                    log_warning "mcpServers path not found: $MCP_PATH"
                fi
            else
                while IFS= read -r mcp_ref; do
                    [[ -z "$mcp_ref" ]] && continue
                    if [[ -f "$PLUGIN_ROOT/$mcp_ref" ]]; then
                        log_success "mcpServers path resolves: $mcp_ref"
                    else
                        log_warning "mcpServers path not found: $mcp_ref"
                    fi
                done < <(jq -r '.mcpServers[]' "$PLUGIN_JSON" 2>/dev/null)
            fi
        fi
    else
        log_info "No mcpServers field in plugin.json"
    fi
fi

# ============================================
# Plugin Settings Override Detection
# ============================================
log_section "Settings Override Security"

if [[ -n "${PLUGIN_JSON:-}" ]] && command -v jq &>/dev/null && [[ -f "${PLUGIN_JSON:-}" ]]; then
    # Plugins that embed a settings block can override user-level Claude Code settings.
    # This is a supply chain risk if a plugin silently sets permissive values.
    SETTINGS_KEYS=$(jq -r 'keys[] | select(test("^(settings|config|permissions|permissionMode|allowedTools|disabledTools|env)$"))' "$PLUGIN_JSON" 2>/dev/null || true)
    if [[ -n "$SETTINGS_KEYS" ]]; then
        log_error "SECURITY [HIGH]: plugin.json contains settings/permissions key(s) that may override user configuration: $SETTINGS_KEYS"
    else
        log_success "No settings override fields found in plugin.json"
    fi

    # Also scan all JSON files in the plugin for dangerouslyAllowedTools or permissive settings
    DANGEROUS_SETTINGS=$(grep -rE 'dangerouslyAllowedTools|permissionMode.*allow|"allowAll"|"disableSandbox"' \
        "$PLUGIN_ROOT" --include="*.json" 2>/dev/null | grep -v "Binary file" | head -5 || true)
    if [[ -n "$DANGEROUS_SETTINGS" ]]; then
        log_error "SECURITY [HIGH]: dangerous permission settings found in plugin JSON files:"
        while IFS= read -r ds_line; do
            [[ -z "$ds_line" ]] && continue
            log_error "  $ds_line"
        done <<< "$DANGEROUS_SETTINGS"
    fi
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "PLUGIN VALIDATION SUMMARY"
echo "=========================================="
echo "Plugin: $PLUGIN_ROOT"
echo ""
echo "Structure Errors: ${#ERRORS[@]}"
echo "Structure Warnings: ${#WARNINGS[@]}"
echo "Component Failures: $COMPONENT_ERRORS"
echo ""

TOTAL_ERRORS=$((${#ERRORS[@]} + COMPONENT_ERRORS))

if [[ $TOTAL_ERRORS -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED${NC}"
    echo ""
    echo "Errors found:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    if [[ $COMPONENT_ERRORS -gt 0 ]]; then
        echo "  - $COMPONENT_ERRORS component(s) failed validation (see details above)"
    fi
    exit 1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}VALIDATION PASSED WITH WARNINGS${NC}"
    echo ""
    echo "Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
else
    echo -e "${GREEN}VALIDATION PASSED${NC}"
fi

exit 0
