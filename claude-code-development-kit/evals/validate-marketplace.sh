#!/bin/bash
# validate-marketplace.sh - Master validation script for Content Platform Marketplace
# Orchestrates validation of all plugins and their components
# Usage: ./validate-marketplace.sh [options]
# Exit 0 on pass, exit 1 on fail

set -euo pipefail

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

# Colors for output (can be disabled with --no-color)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
PLUGINS_PASSED=0
PLUGINS_FAILED=0
PLUGINS_TOTAL=0
SKILLS_PASSED=0
SKILLS_FAILED=0
SKILLS_TOTAL=0
COMMANDS_PASSED=0
COMMANDS_FAILED=0
COMMANDS_TOTAL=0
HOOKS_PASSED=0
HOOKS_FAILED=0
HOOKS_TOTAL=0
STYLES_PASSED=0
STYLES_FAILED=0
STYLES_TOTAL=0
AGENTS_PASSED=0
AGENTS_FAILED=0
AGENTS_TOTAL=0

# Options
VERBOSE=false
JSON_OUTPUT=false
NO_COLOR=false
SINGLE_PLUGIN=""
MARKETPLACE_ROOT=""

# Error tracking
ERRORS=()
WARNINGS=()

# ============================================
# Helper Functions
# ============================================

disable_colors() {
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
}

log_error() {
    ERRORS+=("$1")
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_warning() {
    WARNINGS+=("$1")
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_success() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"
    fi
}

log_info() {
    if [[ "$JSON_OUTPUT" != "true" && "$VERBOSE" == "true" ]]; then
        echo -e "[INFO] $1"
    fi
}

log_status() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "  $1"
    fi
}

print_header() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${BLUE}${BOLD}=== $1 ===${NC}"
    fi
}

print_plugin_header() {
    local num="$1"
    local total="$2"
    local name="$3"
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${CYAN}[${num}/${total}] ${BOLD}${name}${NC}"
    fi
}

show_help() {
    cat << EOF
validate-marketplace.sh v${VERSION} - Content Platform Marketplace Validator

USAGE:
    ./validate-marketplace.sh [OPTIONS] [MARKETPLACE_ROOT]

DESCRIPTION:
    Validates all plugins in a marketplace, running component validators
    for skills, commands, hooks, output styles, and agents.

ARGUMENTS:
    MARKETPLACE_ROOT    Root directory of the marketplace (default: current directory)

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Show all validation checks, not just errors
    --json              Output results in JSON format for CI/CD integration
    --no-color          Disable colored output
    -p, --plugin NAME   Validate a single plugin by name

EXAMPLES:
    ./validate-marketplace.sh
    ./validate-marketplace.sh --verbose
    ./validate-marketplace.sh --plugin productivity-toolkit
    ./validate-marketplace.sh /path/to/marketplace --json

EXIT CODES:
    0    All validations passed
    1    One or more validations failed
    2    Invalid arguments or configuration error

EOF
}

# ============================================
# JSON Output Functions
# ============================================

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    echo "$s"
}

output_json_results() {
    local status="pass"
    local error_count="${#ERRORS[@]}"
    local warning_count="${#WARNINGS[@]}"

    if [[ $PLUGINS_FAILED -gt 0 || $error_count -gt 0 ]]; then
        status="fail"
    fi

    # Build errors array
    local errors_json=""
    if [[ $error_count -gt 0 ]]; then
        errors_json=$(printf '"%s",' "${ERRORS[@]}" | sed 's/,$//')
    fi

    # Build warnings array
    local warnings_json=""
    if [[ $warning_count -gt 0 ]]; then
        warnings_json=$(printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//')
    fi

    cat << EOF
{
  "version": "${VERSION}",
  "status": "${status}",
  "summary": {
    "plugins": { "passed": ${PLUGINS_PASSED}, "failed": ${PLUGINS_FAILED}, "total": ${PLUGINS_TOTAL} },
    "skills": { "passed": ${SKILLS_PASSED}, "failed": ${SKILLS_FAILED}, "total": ${SKILLS_TOTAL} },
    "commands": { "passed": ${COMMANDS_PASSED}, "failed": ${COMMANDS_FAILED}, "total": ${COMMANDS_TOTAL} },
    "hooks": { "passed": ${HOOKS_PASSED}, "failed": ${HOOKS_FAILED}, "total": ${HOOKS_TOTAL} },
    "outputStyles": { "passed": ${STYLES_PASSED}, "failed": ${STYLES_FAILED}, "total": ${STYLES_TOTAL} },
    "agents": { "passed": ${AGENTS_PASSED}, "failed": ${AGENTS_FAILED}, "total": ${AGENTS_TOTAL} }
  },
  "errors": [${errors_json}],
  "warnings": [${warnings_json}]
}
EOF
}

# ============================================
# Validation Functions
# ============================================

validate_marketplace_json() {
    local marketplace_json="$1"

    if [[ ! -f "$marketplace_json" ]]; then
        log_error "marketplace.json not found at $marketplace_json"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        log_warning "jq not installed - basic validation only"
        if ! python3 -c "import json; json.load(open('$marketplace_json'))" 2>/dev/null; then
            log_error "marketplace.json is not valid JSON"
            return 1
        fi
        log_success "marketplace.json is valid JSON (basic check)"
        return 0
    fi

    if ! jq empty "$marketplace_json" 2>/dev/null; then
        log_error "marketplace.json is not valid JSON"
        return 1
    fi

    log_success "marketplace.json is valid JSON"

    # Check required fields
    local name
    name=$(jq -r '.name // empty' "$marketplace_json")
    if [[ -z "$name" ]]; then
        log_warning "marketplace.json missing 'name' field"
    else
        log_info "Marketplace name: $name"
    fi

    local plugins_count
    plugins_count=$(jq '.plugins | length' "$marketplace_json")
    if [[ "$plugins_count" -eq 0 ]]; then
        log_warning "No plugins defined in marketplace.json"
    fi

    return 0
}

get_plugin_list() {
    local marketplace_json="$1"

    if command -v jq &> /dev/null; then
        jq -r '.plugins[]? | .name' "$marketplace_json" 2>/dev/null
    else
        # Fallback: basic parsing with grep/sed
        grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$marketplace_json" | \
            sed 's/"name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' | \
            tail -n +2  # Skip first match (marketplace name)
    fi
}

get_plugin_source() {
    local marketplace_json="$1"
    local plugin_name="$2"

    if command -v jq &> /dev/null; then
        jq -r --arg name "$plugin_name" '.plugins[]? | select(.name == $name) | .source' "$marketplace_json" 2>/dev/null
    else
        log_warning "Cannot determine plugin source without jq"
        echo ""
    fi
}

find_plugin_json() {
    local plugin_root="$1"

    # Check both locations
    if [[ -f "$plugin_root/plugin.json" ]]; then
        echo "$plugin_root/plugin.json"
    elif [[ -f "$plugin_root/.claude-plugin/plugin.json" ]]; then
        echo "$plugin_root/.claude-plugin/plugin.json"
    else
        echo ""
    fi
}

count_components() {
    local plugin_json="$1"
    local component_type="$2"

    if ! command -v jq &> /dev/null; then
        echo "0"
        return
    fi

    case "$component_type" in
        skills)
            jq -r '.skills | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            ;;
        commands)
            jq -r '.commands | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            ;;
        hooks)
            # Hooks can be object or array
            local hooks_type
            hooks_type=$(jq -r '.hooks | type // "null"' "$plugin_json" 2>/dev/null)
            if [[ "$hooks_type" == "object" ]]; then
                jq -r '.hooks | keys | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            elif [[ "$hooks_type" == "array" ]]; then
                jq -r '.hooks | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            else
                echo "0"
            fi
            ;;
        outputStyles)
            jq -r '.outputStyles | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            ;;
        agents)
            jq -r '.agents | length // 0' "$plugin_json" 2>/dev/null || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

run_validator() {
    local validator="$1"
    local target="$2"
    local component_type="$3"

    local validator_path="$SCRIPT_DIR/$validator"

    if [[ ! -x "$validator_path" ]]; then
        log_warning "$validator not found or not executable - skipping $component_type validation"
        return 2
    fi

    local temp_log="${TMPDIR:-/tmp}/validate_$$.log"

    if "$validator_path" "$target" > "$temp_log" 2>&1; then
        rm -f "$temp_log" 2>/dev/null
        return 0
    else
        if [[ "$VERBOSE" == "true" ]]; then
            # Show first few errors from validator output
            grep -E "^\[ERROR\]" "$temp_log" 2>/dev/null | head -3 | while read -r line; do
                log_status "    $line"
            done
        fi
        rm -f "$temp_log" 2>/dev/null
        return 1
    fi
}

validate_plugin() {
    local plugin_name="$1"
    local plugin_root="$2"
    local plugin_num="$3"
    local total_plugins="$4"

    print_plugin_header "$plugin_num" "$total_plugins" "$plugin_name"

    local plugin_failed=false
    local plugin_json
    plugin_json=$(find_plugin_json "$plugin_root")

    # Validate plugin.json
    if [[ -z "$plugin_json" ]]; then
        log_status "- plugin.json: ${RED}NOT FOUND${NC}"
        log_error "plugin.json not found for $plugin_name"
        plugin_failed=true
    else
        if run_validator "validate-plugin.sh" "$plugin_root" "plugin"; then
            log_status "- plugin.json: ${GREEN}PASS${NC}"
        else
            log_status "- plugin.json: ${RED}FAIL${NC}"
            log_error "Plugin validation failed: $plugin_name"
            plugin_failed=true
        fi
    fi

    # Count and validate skills
    local skills_count=0
    local skills_pass=0

    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        # Get skill paths from plugin.json
        local skill_paths
        skill_paths=$(jq -r '.skills[]? | if type == "object" then .path else . end // empty' "$plugin_json" 2>/dev/null)

        if [[ -n "$skill_paths" ]]; then
            while IFS= read -r skill_path; do
                [[ -z "$skill_path" ]] && continue
                local full_path="$plugin_root/$skill_path"

                if [[ -d "$full_path" ]]; then
                    ((skills_count++))
                    ((SKILLS_TOTAL++))

                    if run_validator "validate-skill.sh" "$full_path" "skill"; then
                        ((skills_pass++))
                        ((SKILLS_PASSED++))
                    else
                        ((SKILLS_FAILED++))
                    fi
                fi
            done <<< "$skill_paths"
        fi
    fi

    # Fallback: check skills directory
    if [[ $skills_count -eq 0 && -d "$plugin_root/skills" ]]; then
        for skill_dir in "$plugin_root/skills"/*/; do
            [[ ! -d "$skill_dir" ]] && continue
            ((skills_count++))
            ((SKILLS_TOTAL++))

            if run_validator "validate-skill.sh" "$skill_dir" "skill"; then
                ((skills_pass++))
                ((SKILLS_PASSED++))
            else
                ((SKILLS_FAILED++))
            fi
        done
    fi

    if [[ $skills_count -gt 0 ]]; then
        if [[ $skills_pass -eq $skills_count ]]; then
            log_status "- skills ($skills_count): ${GREEN}PASS${NC}"
        else
            log_status "- skills ($skills_count): ${RED}$skills_pass/$skills_count passed${NC}"
            plugin_failed=true
        fi
    fi

    # Count and validate commands
    local commands_count=0
    local commands_pass=0

    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        local command_paths
        command_paths=$(jq -r '.commands[]? | if type == "object" then .path else . end // empty' "$plugin_json" 2>/dev/null)

        if [[ -n "$command_paths" ]]; then
            while IFS= read -r cmd_path; do
                [[ -z "$cmd_path" ]] && continue
                local full_path="$plugin_root/$cmd_path"

                if [[ -f "$full_path" ]]; then
                    ((commands_count++))
                    ((COMMANDS_TOTAL++))

                    if run_validator "validate-command.sh" "$full_path" "command"; then
                        ((commands_pass++))
                        ((COMMANDS_PASSED++))
                    else
                        ((COMMANDS_FAILED++))
                    fi
                fi
            done <<< "$command_paths"
        fi
    fi

    # Fallback: check commands directory
    if [[ $commands_count -eq 0 && -d "$plugin_root/commands" ]]; then
        for cmd_file in "$plugin_root/commands"/*.md; do
            [[ ! -f "$cmd_file" ]] && continue
            ((commands_count++))
            ((COMMANDS_TOTAL++))

            if run_validator "validate-command.sh" "$cmd_file" "command"; then
                ((commands_pass++))
                ((COMMANDS_PASSED++))
            else
                ((COMMANDS_FAILED++))
            fi
        done
    fi

    if [[ $commands_count -gt 0 ]]; then
        if [[ $commands_pass -eq $commands_count ]]; then
            log_status "- commands ($commands_count): ${GREEN}PASS${NC}"
        else
            log_status "- commands ($commands_count): ${RED}$commands_pass/$commands_count passed${NC}"
            plugin_failed=true
        fi
    fi

    # Count and validate hooks
    local hooks_count=0
    local hooks_pass=0

    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        local hook_paths
        hook_paths=$(jq -r '
            if .hooks | type == "object" then
                .hooks | to_entries[] | .value | if type == "object" then .command else . end
            elif .hooks | type == "array" then
                .hooks[]? | if type == "object" then (.path // .command) else . end
            else
                empty
            end // empty
        ' "$plugin_json" 2>/dev/null)

        if [[ -n "$hook_paths" ]]; then
            while IFS= read -r hook_path; do
                [[ -z "$hook_path" ]] && continue
                local full_path="$plugin_root/$hook_path"

                if [[ -f "$full_path" ]]; then
                    ((hooks_count++))
                    ((HOOKS_TOTAL++))

                    if run_validator "validate-hook.sh" "$full_path" "hook"; then
                        ((hooks_pass++))
                        ((HOOKS_PASSED++))
                    else
                        ((HOOKS_FAILED++))
                    fi
                fi
            done <<< "$hook_paths"
        fi
    fi

    # Fallback: check hooks/scripts directories
    if [[ $hooks_count -eq 0 ]]; then
        for hook_dir in "$plugin_root/hooks" "$plugin_root/scripts"; do
            if [[ -d "$hook_dir" ]]; then
                for hook_file in "$hook_dir"/*; do
                    [[ ! -f "$hook_file" ]] && continue
                    [[ "$hook_file" =~ \.md$ ]] && continue
                    [[ "$hook_file" =~ \.json$ ]] && continue

                    ((hooks_count++))
                    ((HOOKS_TOTAL++))

                    if run_validator "validate-hook.sh" "$hook_file" "hook"; then
                        ((hooks_pass++))
                        ((HOOKS_PASSED++))
                    else
                        ((HOOKS_FAILED++))
                    fi
                done
            fi
        done
    fi

    if [[ $hooks_count -gt 0 ]]; then
        if [[ $hooks_pass -eq $hooks_count ]]; then
            log_status "- hooks ($hooks_count): ${GREEN}PASS${NC}"
        else
            log_status "- hooks ($hooks_count): ${RED}$hooks_pass/$hooks_count passed${NC}"
            plugin_failed=true
        fi
    fi

    # Count and validate output styles
    local styles_count=0
    local styles_pass=0

    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        local style_paths
        style_paths=$(jq -r '.outputStyles[]? | if type == "object" then .path else . end // empty' "$plugin_json" 2>/dev/null)

        if [[ -n "$style_paths" ]]; then
            while IFS= read -r style_path; do
                [[ -z "$style_path" ]] && continue
                local full_path="$plugin_root/$style_path"

                if [[ -f "$full_path" ]]; then
                    ((styles_count++))
                    ((STYLES_TOTAL++))

                    if run_validator "validate-output-style.sh" "$full_path" "output-style"; then
                        ((styles_pass++))
                        ((STYLES_PASSED++))
                    else
                        ((STYLES_FAILED++))
                    fi
                fi
            done <<< "$style_paths"
        fi
    fi

    # Fallback: check output-styles directory
    if [[ $styles_count -eq 0 && -d "$plugin_root/output-styles" ]]; then
        for style_file in "$plugin_root/output-styles"/*.md; do
            [[ ! -f "$style_file" ]] && continue
            ((styles_count++))
            ((STYLES_TOTAL++))

            if run_validator "validate-output-style.sh" "$style_file" "output-style"; then
                ((styles_pass++))
                ((STYLES_PASSED++))
            else
                ((STYLES_FAILED++))
            fi
        done
    fi

    if [[ $styles_count -gt 0 ]]; then
        if [[ $styles_pass -eq $styles_count ]]; then
            log_status "- output styles ($styles_count): ${GREEN}PASS${NC}"
        else
            log_status "- output styles ($styles_count): ${RED}$styles_pass/$styles_count passed${NC}"
            plugin_failed=true
        fi
    fi

    # Count and validate agents
    local agents_count=0
    local agents_pass=0

    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        local agent_paths
        agent_paths=$(jq -r '.agents[]? | if type == "object" then .path else . end // empty' "$plugin_json" 2>/dev/null)

        if [[ -n "$agent_paths" ]]; then
            while IFS= read -r agent_path; do
                [[ -z "$agent_path" ]] && continue
                local full_path="$plugin_root/$agent_path"

                if [[ -f "$full_path" || -d "$full_path" ]]; then
                    ((agents_count++))
                    ((AGENTS_TOTAL++))

                    # Try validate-agent.sh if it exists
                    if [[ -x "$SCRIPT_DIR/validate-agent.sh" ]]; then
                        if run_validator "validate-agent.sh" "$full_path" "agent"; then
                            ((agents_pass++))
                            ((AGENTS_PASSED++))
                        else
                            ((AGENTS_FAILED++))
                        fi
                    else
                        # Basic validation: check file exists and has content
                        if [[ -f "$full_path" && -s "$full_path" ]]; then
                            ((agents_pass++))
                            ((AGENTS_PASSED++))
                        else
                            ((AGENTS_FAILED++))
                        fi
                    fi
                fi
            done <<< "$agent_paths"
        fi
    fi

    # Fallback: check agents directory
    if [[ $agents_count -eq 0 && -d "$plugin_root/agents" ]]; then
        for agent_file in "$plugin_root/agents"/*.md; do
            [[ ! -f "$agent_file" ]] && continue
            ((agents_count++))
            ((AGENTS_TOTAL++))

            if [[ -x "$SCRIPT_DIR/validate-agent.sh" ]]; then
                if run_validator "validate-agent.sh" "$agent_file" "agent"; then
                    ((agents_pass++))
                    ((AGENTS_PASSED++))
                else
                    ((AGENTS_FAILED++))
                fi
            else
                # Basic validation: check file exists and has content
                if [[ -s "$agent_file" ]]; then
                    ((agents_pass++))
                    ((AGENTS_PASSED++))
                else
                    ((AGENTS_FAILED++))
                fi
            fi
        done
    fi

    if [[ $agents_count -gt 0 ]]; then
        if [[ $agents_pass -eq $agents_count ]]; then
            log_status "- agents ($agents_count): ${GREEN}PASS${NC}"
        else
            log_status "- agents ($agents_count): ${RED}$agents_pass/$agents_count passed${NC}"
            plugin_failed=true
        fi
    fi

    # Check for orphaned components (on disk but not in plugin.json)
    if [[ -n "$plugin_json" ]] && command -v jq &> /dev/null; then
        local orphan_found=false
        local orphan_checks_run=0

        # Helper: collect declared paths for a component type
        declared_paths() {
            local key="$1"
            jq -r --arg k "$key" '.[$k][]? | if type == "object" then .path else . end // empty' "$plugin_json" 2>/dev/null
        }

        # Skills: each subdirectory in skills/ should be declared
        # Skip orphan check if plugin.json has no skills array (auto-discovery mode)
        if [[ -d "$plugin_root/skills" ]]; then
            local declared_skills
            declared_skills=$(declared_paths "skills")
            if [[ -n "$declared_skills" ]]; then
                ((orphan_checks_run++))
                for skill_dir in "$plugin_root/skills"/*/; do
                    [[ ! -d "$skill_dir" ]] && continue
                    local skill_name
                    skill_name=$(basename "$skill_dir")
                    if ! echo "$declared_skills" | grep -q "$skill_name"; then
                        log_warning "$plugin_name: skill directory 'skills/$skill_name/' exists on disk but is not declared in plugin.json"
                        orphan_found=true
                    fi
                done
            fi
        fi

        # Commands: each .md file in commands/ should be declared
        if [[ -d "$plugin_root/commands" ]]; then
            local declared_commands
            declared_commands=$(declared_paths "commands")
            if [[ -n "$declared_commands" ]]; then
                ((orphan_checks_run++))
                for cmd_file in "$plugin_root/commands"/*.md; do
                    [[ ! -f "$cmd_file" ]] && continue
                    local cmd_name
                    cmd_name=$(basename "$cmd_file")
                    if ! echo "$declared_commands" | grep -q "$cmd_name"; then
                        log_warning "$plugin_name: command file 'commands/$cmd_name' exists on disk but is not declared in plugin.json"
                        orphan_found=true
                    fi
                done
            fi
        fi

        # Agents: each .md file in agents/ should be declared
        if [[ -d "$plugin_root/agents" ]]; then
            local declared_agents
            declared_agents=$(declared_paths "agents")
            if [[ -n "$declared_agents" ]]; then
                ((orphan_checks_run++))
                for agent_file in "$plugin_root/agents"/*.md; do
                    [[ ! -f "$agent_file" ]] && continue
                    local agent_name
                    agent_name=$(basename "$agent_file")
                    if ! echo "$declared_agents" | grep -q "$agent_name"; then
                        log_warning "$plugin_name: agent file 'agents/$agent_name' exists on disk but is not declared in plugin.json"
                        orphan_found=true
                    fi
                done
            fi
        fi

        # Output styles: each .md file in output-styles/ should be declared
        if [[ -d "$plugin_root/output-styles" ]]; then
            local declared_styles
            declared_styles=$(declared_paths "outputStyles")
            if [[ -n "$declared_styles" ]]; then
                ((orphan_checks_run++))
                for style_file in "$plugin_root/output-styles"/*.md; do
                    [[ ! -f "$style_file" ]] && continue
                    local style_name
                    style_name=$(basename "$style_file")
                    if ! echo "$declared_styles" | grep -q "$style_name"; then
                        log_warning "$plugin_name: output style 'output-styles/$style_name' exists on disk but is not declared in plugin.json"
                        orphan_found=true
                    fi
                done
            fi
        fi

        if [[ "$orphan_checks_run" -eq 0 ]]; then
            log_info "$plugin_name: orphan check skipped — plugin.json has no component arrays (auto-discovery mode)"
            log_status "- orphan check: ${CYAN}SKIPPED${NC} (no component arrays in plugin.json)"
        elif [[ "$orphan_found" == "true" ]]; then
            log_status "- orphan check: ${YELLOW}WARNINGS${NC} (files on disk not in plugin.json)"
        else
            log_status "- orphan check: ${GREEN}PASS${NC}"
        fi
    fi

    # Update plugin counters
    ((PLUGINS_TOTAL++))
    if [[ "$plugin_failed" == "true" ]]; then
        ((PLUGINS_FAILED++))
        return 1
    else
        ((PLUGINS_PASSED++))
        return 0
    fi
}

validate_cross_references() {
    local marketplace_json="$1"
    local marketplace_root="$2"

    print_header "Cross-Reference Validation"

    if ! command -v jq &> /dev/null; then
        log_warning "jq not installed — skipping cross-reference validation"
        return 0
    fi

    local cross_errors=0

    # 1. Compare marketplace.json names/versions against actual plugin.json values
    local plugin_entries
    plugin_entries=$(jq -r '.plugins[]? | "\(.name)\t\(.version // "")\t\(.source // "")"' "$marketplace_json" 2>/dev/null)

    if [[ -n "$plugin_entries" ]]; then
        while IFS=$'\t' read -r mkt_name mkt_version mkt_source; do
            [[ -z "$mkt_name" ]] && continue

            # Resolve plugin root
            local source_path="${mkt_source#./}"
            local plugin_root="$marketplace_root/$source_path"
            local plugin_json=""

            # Check the plugin directory itself exists on disk
            if [[ -n "$source_path" && ! -d "$plugin_root" ]]; then
                log_error "Cross-ref: marketplace entry '$mkt_name' references directory '$source_path' which does not exist (plugin may have been renamed or deleted)"
                ((cross_errors++))
                continue
            fi

            if [[ -f "$plugin_root/plugin.json" ]]; then
                plugin_json="$plugin_root/plugin.json"
            elif [[ -f "$plugin_root/.claude-plugin/plugin.json" ]]; then
                plugin_json="$plugin_root/.claude-plugin/plugin.json"
            fi

            if [[ -z "$plugin_json" ]]; then
                log_error "Cross-ref: marketplace entry '$mkt_name' has no plugin.json at $source_path"
                ((cross_errors++))
                continue
            fi

            # Check name match
            local actual_name
            actual_name=$(jq -r '.name // empty' "$plugin_json" 2>/dev/null)
            if [[ -n "$actual_name" && "$actual_name" != "$mkt_name" ]]; then
                log_error "Cross-ref: marketplace name '$mkt_name' does not match plugin.json name '$actual_name' at $source_path"
                ((cross_errors++))
            else
                log_success "Cross-ref: name match for '$mkt_name'"
            fi

            # Check version match (if marketplace has a version)
            if [[ -n "$mkt_version" ]]; then
                local actual_version
                actual_version=$(jq -r '.version // empty' "$plugin_json" 2>/dev/null)
                if [[ -n "$actual_version" && "$actual_version" != "$mkt_version" ]]; then
                    log_warning "Cross-ref: marketplace version '$mkt_version' does not match plugin.json version '$actual_version' for '$mkt_name'"
                else
                    log_success "Cross-ref: version match for '$mkt_name' ($mkt_version)"
                fi
            fi

        done <<< "$plugin_entries"
    fi

    # 2. Detect orphan plugin directories (have plugin.json but no marketplace entry)
    local declared_names
    declared_names=$(jq -r '.plugins[]?.name' "$marketplace_json" 2>/dev/null)

    for dir in "$marketplace_root"/*/; do
        [[ ! -d "$dir" ]] && continue
        local dir_name
        dir_name=$(basename "$dir")

        # Skip non-plugin directories
        [[ "$dir_name" == ".claude-plugin" ]] && continue
        [[ "$dir_name" == ".git" ]] && continue
        [[ "$dir_name" == ".github" ]] && continue
        [[ "$dir_name" == "node_modules" ]] && continue

        # Check if this directory has a plugin.json
        if [[ -f "$dir/plugin.json" ]] || [[ -f "$dir/.claude-plugin/plugin.json" ]]; then
            # Check if it's declared in marketplace.json
            if ! echo "$declared_names" | grep -qx "$dir_name"; then
                log_warning "Orphan plugin directory: '$dir_name/' has a plugin.json but is not listed in marketplace.json"
            fi
        fi
    done

    if [[ $cross_errors -gt 0 ]]; then
        log_error "Cross-reference validation found $cross_errors error(s)"
        return 1
    fi

    log_success "Cross-reference validation passed"
    return 0
}

print_summary() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json_results
        return
    fi

    echo ""
    echo -e "${BOLD}=== Summary ===${NC}"

    # Helper function to format counts
    format_count() {
        local passed="$1"
        local total="$2"
        local name="$3"

        if [[ $total -eq 0 ]]; then
            printf "%-14s %s\n" "$name:" "none found"
        elif [[ $passed -eq $total ]]; then
            printf "%-14s ${GREEN}%d/%d passed${NC}\n" "$name:" "$passed" "$total"
        else
            printf "%-14s ${RED}%d/%d passed${NC}\n" "$name:" "$passed" "$total"
        fi
    }

    format_count "$PLUGINS_PASSED" "$PLUGINS_TOTAL" "Plugins"
    format_count "$SKILLS_PASSED" "$SKILLS_TOTAL" "Skills"
    format_count "$COMMANDS_PASSED" "$COMMANDS_TOTAL" "Commands"
    format_count "$HOOKS_PASSED" "$HOOKS_TOTAL" "Hooks"
    format_count "$STYLES_PASSED" "$STYLES_TOTAL" "Output Styles"
    format_count "$AGENTS_PASSED" "$AGENTS_TOTAL" "Agents"

    echo ""

    local total_failed=$((PLUGINS_FAILED + SKILLS_FAILED + COMMANDS_FAILED + HOOKS_FAILED + STYLES_FAILED + AGENTS_FAILED))

    if [[ $total_failed -gt 0 ]]; then
        echo -e "${RED}${BOLD}✗ Content Platform Marketplace validation FAILED${NC}"
        if [[ ${#ERRORS[@]} -gt 0 ]]; then
            echo ""
            echo "Errors:"
            for error in "${ERRORS[@]}"; do
                echo "  - $error"
            done
        fi
        return 1
    elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}✓ Content Platform Marketplace validation PASSED WITH WARNINGS${NC}"
        echo ""
        echo "Warnings:"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
        return 0
    else
        echo -e "${GREEN}${BOLD}✓ Content Platform Marketplace validation PASSED${NC}"
        return 0
    fi
}

# ============================================
# Argument Parsing
# ============================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                disable_colors
                shift
                ;;
            -p|--plugin)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --plugin requires a plugin name"
                    exit 2
                fi
                SINGLE_PLUGIN="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 2
                ;;
            *)
                if [[ -z "$MARKETPLACE_ROOT" ]]; then
                    MARKETPLACE_ROOT="$1"
                else
                    echo "Error: Multiple marketplace roots specified"
                    exit 2
                fi
                shift
                ;;
        esac
    done

    # Default to current directory
    if [[ -z "$MARKETPLACE_ROOT" ]]; then
        MARKETPLACE_ROOT="$(pwd)"
    fi

    # Resolve to absolute path
    if [[ ! "$MARKETPLACE_ROOT" = /* ]]; then
        MARKETPLACE_ROOT="$(pwd)/$MARKETPLACE_ROOT"
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${BOLD}=== Content Platform Marketplace Validation ===${NC}"
        echo ""
    fi

    # Find marketplace.json
    local marketplace_json=""
    if [[ -f "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json" ]]; then
        marketplace_json="$MARKETPLACE_ROOT/.claude-plugin/marketplace.json"
    elif [[ -f "$MARKETPLACE_ROOT/marketplace.json" ]]; then
        marketplace_json="$MARKETPLACE_ROOT/marketplace.json"
    else
        log_error "marketplace.json not found in $MARKETPLACE_ROOT"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json_results
        fi
        exit 1
    fi

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        log_info "Found marketplace.json at: $marketplace_json"
    fi

    # Validate marketplace.json
    if ! validate_marketplace_json "$marketplace_json"; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json_results
        fi
        exit 1
    fi

    # Get plugin list
    local plugins
    plugins=$(get_plugin_list "$marketplace_json")

    if [[ -z "$plugins" ]]; then
        log_warning "No plugins found in marketplace.json"
        print_summary
        exit 0
    fi

    # Count plugins
    local total_plugins
    total_plugins=$(echo "$plugins" | wc -l | tr -d ' ')

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "Found ${BOLD}$total_plugins${NC} plugins"
    fi

    # Filter to single plugin if specified
    if [[ -n "$SINGLE_PLUGIN" ]]; then
        if ! echo "$plugins" | grep -q "^${SINGLE_PLUGIN}$"; then
            log_error "Plugin not found: $SINGLE_PLUGIN"
            if [[ "$JSON_OUTPUT" == "true" ]]; then
                output_json_results
            fi
            exit 1
        fi
        plugins="$SINGLE_PLUGIN"
        total_plugins=1
        if [[ "$JSON_OUTPUT" != "true" ]]; then
            echo "Validating single plugin: $SINGLE_PLUGIN"
        fi
    fi

    # Validate each plugin
    local plugin_num=0
    while IFS= read -r plugin_name; do
        [[ -z "$plugin_name" ]] && continue
        ((plugin_num++))

        # Get plugin source directory
        local plugin_source
        plugin_source=$(get_plugin_source "$marketplace_json" "$plugin_name")

        if [[ -z "$plugin_source" ]]; then
            log_warning "Cannot determine source for plugin: $plugin_name"
            continue
        fi

        # Resolve plugin path relative to marketplace root
        local plugin_root
        # Handle relative paths (./plugin-name or plugin-name)
        plugin_source="${plugin_source#./}"
        plugin_root="$MARKETPLACE_ROOT/$plugin_source"

        if [[ ! -d "$plugin_root" ]]; then
            log_error "Plugin directory not found: $plugin_root"
            ((PLUGINS_TOTAL++))
            ((PLUGINS_FAILED++))
            continue
        fi

        validate_plugin "$plugin_name" "$plugin_root" "$plugin_num" "$total_plugins" || true

    done <<< "$plugins"

    # Cross-reference validation: marketplace.json vs actual plugin.json values
    validate_cross_references "$marketplace_json" "$MARKETPLACE_ROOT" || true

    # Print summary
    print_summary

    # Exit with appropriate code
    local total_failed=$((PLUGINS_FAILED + SKILLS_FAILED + COMMANDS_FAILED + HOOKS_FAILED + STYLES_FAILED + AGENTS_FAILED))
    if [[ $total_failed -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# Run main function
main "$@"
