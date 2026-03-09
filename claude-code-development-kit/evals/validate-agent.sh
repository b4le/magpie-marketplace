#!/bin/bash
# validate-agent.sh - Validates a Claude Code agent.md file
# Usage: ./validate-agent.sh <agent-path>
# Exit 0 on pass, exit 1 on fail

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()

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

show_help() {
    cat << 'EOF'
validate-agent.sh - Validates a Claude Code agent.md file

USAGE:
    ./validate-agent.sh <agent-path>
    ./validate-agent.sh --help

ARGUMENTS:
    agent-path    Path to the agent .md file (e.g., agents/my-agent.md)

EXAMPLES:
    ./validate-agent.sh ./agents/cocam-advisor.md
    ./validate-agent.sh /path/to/plugin/agents/my-agent.md

VALIDATION RULES:
    File Structure:
        - Must be a .md file
        - Must have YAML frontmatter (between --- markers)

    Required Fields:
        - name: Must match filename (minus .md extension)
        - description: Minimum 20 characters
        - tools: Valid tool references (comma-separated)

    Optional Fields:
        - model: Must be opus, sonnet, or haiku if present
        - model_rationale: Explanation if model specified (comment or field)

    Tool Validation:
        - Built-in tools: sourced from schemas/tools-enum.json
        - MCP tools: Format mcp__{service}__{tool}

    Personal Identifier Check:
        - No hardcoded paths like /Users/username/

EXIT CODES:
    0    Validation passed
    1    Validation failed
EOF
    exit 0
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <agent-path>"
    echo "       $0 --help"
    echo ""
    echo "  agent-path: Path to the agent .md file"
    exit 1
fi

AGENT_PATH="$1"

# Get script directory for finding schemas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared schema validation helper
# shellcheck source=_schema-validate.sh
source "$SCRIPT_DIR/_schema-validate.sh"

# Resolve to absolute path
if [[ ! "$AGENT_PATH" = /* ]]; then
    AGENT_PATH="$(pwd)/$AGENT_PATH"
fi

echo "=========================================="
echo "Validating Agent: $AGENT_PATH"
echo "=========================================="

# Check if file exists
if [[ ! -f "$AGENT_PATH" ]]; then
    log_error "Agent file does not exist: $AGENT_PATH"
    exit 1
fi

# Check if file is .md or .yaml
if [[ ! "$AGENT_PATH" =~ \.(md|yaml)$ ]]; then
    log_error "Agent file must have .md or .yaml extension: $AGENT_PATH"
    exit 1
fi
log_success "File has valid extension"

# Extract filename without extension
FILENAME=$(basename "$AGENT_PATH" | sed -E 's/\.(md|yaml)$//')

# Read file content
CONTENT=$(cat "$AGENT_PATH")

# For .yaml files, the entire file is structured YAML (no frontmatter delimiters)
# For .md files, expect YAML frontmatter between --- markers
if [[ "$AGENT_PATH" =~ \.yaml$ ]]; then
    log_success "YAML agent file detected (no frontmatter delimiters expected)"
    FRONTMATTER="$CONTENT"
else
    # Check for YAML frontmatter
    if [[ ! "$CONTENT" =~ ^--- ]]; then
        log_error "YAML frontmatter not found (file must start with ---)"
        exit 1
    fi

    # Check for closing frontmatter
    if ! echo "$CONTENT" | awk 'NR>1' | grep -q "^---$"; then
        log_error "YAML frontmatter not properly closed (missing closing ---)"
        exit 1
    fi
    log_success "YAML frontmatter present and closed"

    # Extract frontmatter (content between first --- and second ---)
    FRONTMATTER=$(echo "$CONTENT" | awk '/^---$/{p++; next} p==1{print}')
fi

# Schema validation (field names, types, patterns, enums, additionalProperties)
SCHEMA_FILE="$SCRIPT_DIR/../schemas/agent-frontmatter.schema.json"
if [[ -f "$SCHEMA_FILE" ]]; then
    SCHEMA_RC=0
    if [[ "$AGENT_PATH" =~ \.yaml$ ]]; then
        # For .yaml files, write YAML content as temp JSON for validation
        YAML_JSON_TMP=$(mktemp)
        trap 'rm -f "$YAML_JSON_TMP"' EXIT
        if python3 -c "
import sys, json, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
with open(sys.argv[2], 'w') as f:
    json.dump(data if data else {}, f)
" "$AGENT_PATH" "$YAML_JSON_TMP" 2>/dev/null; then
            SCHEMA_OUTPUT=$(validate_json_schema "$SCHEMA_FILE" "$YAML_JSON_TMP" 2>&1) || SCHEMA_RC=$?
        else
            SCHEMA_RC=2
            SCHEMA_OUTPUT="Schema validation skipped (pyyaml not available)"
        fi
    else
        SCHEMA_OUTPUT=$(validate_frontmatter_schema "$SCHEMA_FILE" "$AGENT_PATH" 2>&1) || SCHEMA_RC=$?
    fi
    if [[ $SCHEMA_RC -eq 0 ]]; then
        log_success "Frontmatter passes schema validation"
    elif [[ $SCHEMA_RC -eq 1 ]]; then
        while IFS= read -r schema_err; do
            [[ -n "$schema_err" ]] && log_error "$schema_err"
        done <<< "$SCHEMA_OUTPUT"
    else
        log_info "${SCHEMA_OUTPUT:-Schema validation skipped (tools not available)}"
    fi
fi

# Validate required field: name
if echo "$FRONTMATTER" | grep -q "^name:"; then
    log_success "Required field 'name' present"

    # Extract name value
    NAME_VALUE=$(echo "$FRONTMATTER" | grep "^name:" | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Check if name matches filename
    if [[ "$NAME_VALUE" == "$FILENAME" ]]; then
        log_success "Field 'name' matches filename ($FILENAME)"
    else
        log_error "Field 'name' ($NAME_VALUE) does not match filename ($FILENAME)"
    fi
else
    log_error "Required field 'name' missing from frontmatter"
fi

# Validate required field: description
if echo "$FRONTMATTER" | grep -q "^description:"; then
    log_success "Required field 'description' present"

    # Extract description value (handles both inline and YAML block scalar formats)
    DESC_RAW=$(echo "$FRONTMATTER" | grep "^description:" | sed 's/^description:[[:space:]]*//' | tr -d '"' | tr -d "'")
    if [[ "$DESC_RAW" == "|" || "$DESC_RAW" == ">" || "$DESC_RAW" == "|+" || "$DESC_RAW" == "|-" || "$DESC_RAW" == ">-" ]]; then
        # Block scalar: use Python to extract the full value
        if command -v python3 >/dev/null 2>&1; then
            DESC_VALUE=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
fm = content.split('---')[1]
data = yaml.safe_load(fm)
print(data.get('description', ''))
" "$AGENT_PATH" 2>/dev/null || echo "$DESC_RAW")
        else
            DESC_VALUE="$DESC_RAW"
            log_info "Block scalar description detected but python3 not available for parsing"
        fi
    else
        DESC_VALUE="$DESC_RAW"
    fi
    DESC_LENGTH=${#DESC_VALUE}

    # Check minimum length
    if [[ $DESC_LENGTH -ge 20 ]]; then
        log_success "Description length is valid ($DESC_LENGTH characters, min 20)"
    else
        log_error "Description is too short ($DESC_LENGTH characters, minimum 20 required)"
    fi
else
    log_error "Required field 'description' missing from frontmatter"
fi

# Validate required field: tools or allowed-tools
if echo "$FRONTMATTER" | grep -q "^tools:\|^allowed-tools:"; then
    log_success "Tools field present (tools or allowed-tools)"

    # Validate individual tool names against tools-enum.json
    TOOLS_ENUM="$SCRIPT_DIR/../schemas/tools-enum.json"
    VALID_TOOLS=()

    # Try to read valid tools from tools-enum.json using jq
    if command -v jq >/dev/null 2>&1 && [[ -f "$TOOLS_ENUM" ]]; then
        while IFS= read -r t; do
            [[ -n "$t" ]] && VALID_TOOLS+=("$t")
        done < <(jq -r '.definitions.toolName.oneOf[] | select(.enum) | .enum[]' "$TOOLS_ENUM" 2>/dev/null || true)
    fi

    # Fallback to hardcoded list if jq unavailable or failed
    if [[ ${#VALID_TOOLS[@]} -eq 0 ]]; then
        VALID_TOOLS=(Read Write Edit Glob Grep Bash WebFetch WebSearch Agent Skill AskUserQuestion SendMessage EnterPlanMode ExitPlanMode EnterWorktree ToolSearch Task Tasks TaskCreate TaskUpdate TaskGet TaskList TaskStop NotebookEdit TeamCreate TeamDelete ListMcpResourcesTool ReadMcpResourceTool)
        log_info "Using fallback tool list (jq or tools-enum.json not available)"
    fi

    # Extract tool names from frontmatter (handles YAML list or comma-separated)
    TOOL_LINE=$(echo "$FRONTMATTER" | grep -E "^(tools|allowed-tools):" | head -1)
    TOOL_VALUE=$(echo "$TOOL_LINE" | sed -E 's/^(tools|allowed-tools):[[:space:]]*//')

    # Collect tool names into array from YAML list or inline comma-separated
    TOOL_NAMES=()
    if [[ "$TOOL_VALUE" =~ ^\[ ]] || [[ -z "$TOOL_VALUE" ]]; then
        # YAML array format: extract items starting with "- "
        IN_TOOLS=false
        while IFS= read -r line; do
            if echo "$line" | grep -qE "^(tools|allowed-tools):"; then
                IN_TOOLS=true
                continue
            fi
            if [[ "$IN_TOOLS" == "true" ]]; then
                if echo "$line" | grep -q "^- "; then
                    TOOL=$(echo "$line" | sed 's/^- //' | tr -d '"' | tr -d "'")
                    TOOL=${TOOL## }; TOOL=${TOOL%% }
                    [[ -n "$TOOL" ]] && TOOL_NAMES+=("$TOOL")
                elif echo "$line" | grep -q "^[a-zA-Z]"; then
                    break
                fi
            fi
        done <<< "$FRONTMATTER"
    else
        # Comma-separated or single value
        cleaned=$(echo "$TOOL_VALUE" | tr -d '[]"' | tr -d "'")
        IFS=',' read -ra SPLIT_TOOLS <<< "$cleaned"
        for t in "${SPLIT_TOOLS[@]}"; do
            t=${t## }; t=${t%% }
            [[ -n "$t" ]] && TOOL_NAMES+=("$t")
        done
    fi

    # Validate each tool name
    for tool in ${TOOL_NAMES[@]+"${TOOL_NAMES[@]}"}; do
        [[ -z "$tool" ]] && continue

        # MCP tools match pattern mcp__*
        if [[ "$tool" =~ ^mcp__ ]]; then
            log_success "Valid MCP tool reference: $tool"
            continue
        fi

        # Check against valid built-in tools
        found=false
        for valid in "${VALID_TOOLS[@]}"; do
            if [[ "$tool" == "$valid" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "true" ]]; then
            log_success "Valid tool: $tool"
        else
            log_warning "Unknown tool name: $tool (not in tools-enum.json)"
        fi
    done
else
    log_error "Required field 'tools' (or 'allowed-tools') missing from frontmatter"
fi

# Validate optional field: model
if echo "$FRONTMATTER" | grep -q "^model:"; then
    MODEL_VALUE=$(echo "$FRONTMATTER" | grep "^model:" | sed 's/^model:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Check if model is valid
    if [[ "$MODEL_VALUE" == "opus" || "$MODEL_VALUE" == "sonnet" || "$MODEL_VALUE" == "haiku" || "$MODEL_VALUE" == "inherit" ]]; then
        log_success "Model value is valid: $MODEL_VALUE"

        # Check for model_rationale when model is specified
        # Look for either a model_rationale field or a comment after model
        if echo "$FRONTMATTER" | grep -q "model_rationale:"; then
            log_success "Model rationale field present"
        elif echo "$CONTENT" | grep -q "# Model rationale:"; then
            log_success "Model rationale comment present"
        elif echo "$CONTENT" | grep -q "#.*rationale"; then
            log_success "Model rationale comment present"
        else
            log_warning "Model specified without rationale explanation"
        fi
    else
        log_error "Invalid model value: $MODEL_VALUE (must be opus, sonnet, haiku, or inherit)"
    fi
else
    log_info "Optional field 'model' not specified (will use default)"
fi

# Check for personal identifiers
# Exclude common documentation example patterns
PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z0-9_-]+|/home/[a-zA-Z0-9_-]+|C:\\Users\\[a-zA-Z0-9_-]+' "$AGENT_PATH" 2>/dev/null | \
    grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' | \
    sort -u || true)

if [[ -n "$PERSONAL_MATCHES" ]]; then
    log_error "Personal identifier found: $PERSONAL_MATCHES"
else
    log_success "No personal identifiers found"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Errors: ${#ERRORS[@]}"
echo "Warnings: ${#WARNINGS[@]}"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Failed checks:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Agent validation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Agent validation passed!${NC}"
exit 0
