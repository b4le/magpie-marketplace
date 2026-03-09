#!/bin/bash
# build-capability-registry.sh — Enumerate all Claude Code capabilities into a JSON registry.
# Bash 3.2 compatible. Requires jq.
#
# Usage:
#   build-capability-registry.sh [--force] [--ttl SECONDS] [--quiet]
#
# Output: ~/.claude/registry/capabilities.json
# Cache: 5-min TTL (300s) by default. --force bypasses. --ttl overrides.

set -uo pipefail

CLAUDE_DIR="${HOME}/.claude"
REGISTRY_DIR="${CLAUDE_DIR}/registry"
OUTPUT_FILE="${REGISTRY_DIR}/capabilities.json"
INSTALLED_PLUGINS="${CLAUDE_DIR}/plugins/installed_plugins.json"
BLOCKLIST="${CLAUDE_DIR}/plugins/blocklist.json"

DEFAULT_TTL=300
TTL="${DEFAULT_TTL}"
FORCE=false
QUIET=false

# --- Argument parsing ---
while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --ttl)   TTL="$2"; shift 2 ;;
        --quiet) QUIET=true; shift ;;
        *)       echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

log() {
    if [ "$QUIET" = false ]; then
        echo "$@" >&2
    fi
}

# --- TTL check ---
if [ "$FORCE" = false ] && [ -f "$OUTPUT_FILE" ]; then
    if command -v stat >/dev/null 2>&1; then
        # macOS stat
        file_mtime=$(stat -f '%m' "$OUTPUT_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$((now - file_mtime))
        if [ "$age" -lt "$TTL" ]; then
            log "Cache valid (${age}s < ${TTL}s TTL). Use --force to rebuild."
            exit 0
        fi
    fi
fi

# --- Ensure output dir ---
mkdir -p "$REGISTRY_DIR"

# --- Helpers ---

# Extract a YAML frontmatter field value (simple single-line values only)
# Usage: extract_frontmatter_field "file" "field_name"
extract_frontmatter_field() {
    local file="$1"
    local field="$2"
    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | \
        grep -E "^${field}:" | \
        head -1 | \
        sed "s/^${field}:[[:space:]]*//" | \
        sed 's/^["'"'"']//' | \
        sed 's/["'"'"']$//' | \
        sed 's/[[:space:]]*$//'
}

# Extract multiline YAML field (description with | or > or just a long line)
extract_description() {
    local file="$1"
    local in_frontmatter=false
    local in_desc=false
    local desc=""
    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            if [ "$in_frontmatter" = true ]; then
                break
            fi
            in_frontmatter=true
            continue
        fi
        if [ "$in_frontmatter" = false ]; then
            continue
        fi
        # Check if this line starts the description field
        case "$line" in
            description:*)
                in_desc=true
                local val
                val=$(echo "$line" | sed 's/^description:[[:space:]]*//')
                # Check for block scalar indicators
                case "$val" in
                    '|'|'>'|'|+'|'>+') continue ;;  # multiline follows
                    *)
                        if [ -n "$val" ]; then
                            desc="$val"
                        fi
                        ;;
                esac
                continue
                ;;
        esac
        if [ "$in_desc" = true ]; then
            # If line starts with a new field (no leading space, has colon), stop
            case "$line" in
                [a-zA-Z_]*)
                    case "$line" in
                        *:*) break ;;
                    esac
                    ;;
            esac
            # Continuation line
            local trimmed
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [ -n "$trimmed" ]; then
                if [ -n "$desc" ]; then
                    desc="${desc} ${trimmed}"
                else
                    desc="${trimmed}"
                fi
            fi
        fi
    done < "$file"
    # Truncate to 300 chars for registry
    printf '%s' "$desc" | head -c 300
}

# Infer domain tags from description text
infer_domain_tags() {
    local desc="$1"
    local tags=""
    local lower
    lower=$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]')

    # Check for domain keywords
    case "$lower" in
        *typescript*|*tsx*) tags="${tags}typescript," ;;
    esac
    case "$lower" in
        *javascript*|*jsx*|*node.js*|*nodejs*) tags="${tags}javascript," ;;
    esac
    case "$lower" in
        *python*|*django*|*flask*) tags="${tags}python," ;;
    esac
    case "$lower" in
        *react*|*next.js*|*nextjs*|*frontend*|*css*|*html*) tags="${tags}frontend," ;;
    esac
    case "$lower" in
        *bash*|*shell*|*posix*|*scripting*) tags="${tags}shell," ;;
    esac
    case "$lower" in
        *sql*|*database*|*postgres*|*mysql*) tags="${tags}database," ;;
    esac
    case "$lower" in
        *test*|*testing*|*tdd*|*bats*) tags="${tags}testing," ;;
    esac
    case "$lower" in
        *security*|*auth*|*owasp*|*vulnerability*) tags="${tags}security," ;;
    esac
    case "$lower" in
        *deploy*|*ci/cd*|*docker*|*kubernetes*|*infrastructure*) tags="${tags}infrastructure," ;;
    esac
    case "$lower" in
        *api*|*rest*|*graphql*|*grpc*|*backend*) tags="${tags}api," ;;
    esac
    case "$lower" in
        *performance*|*optimization*|*benchmark*) tags="${tags}performance," ;;
    esac
    case "$lower" in
        *mobile*|*ios*|*android*|*react*native*|*flutter*) tags="${tags}mobile," ;;
    esac
    case "$lower" in
        *llm*|*ai*|*embedding*|*rag*|*vector*|*prompt*) tags="${tags}ai," ;;
    esac
    case "$lower" in
        *data*|*pipeline*|*etl*|*spark*|*airflow*) tags="${tags}data," ;;
    esac
    case "$lower" in
        *review*|*audit*|*quality*) tags="${tags}review," ;;
    esac
    case "$lower" in
        *git*|*pr*|*pull*request*|*branch*) tags="${tags}git," ;;
    esac
    case "$lower" in
        *plugin*|*skill*|*agent*|*claude*code*) tags="${tags}meta," ;;
    esac

    # Remove trailing comma, format as JSON array
    tags=$(printf '%s' "$tags" | sed 's/,$//')
    if [ -z "$tags" ]; then
        echo "[]"
    else
        printf '%s' "$tags" | tr ',' '\n' | jq -R . | jq -s .
    fi
}

# Check if a plugin is installed (by name@registry key pattern)
is_plugin_installed() {
    local plugin_name="$1"
    if [ ! -f "$INSTALLED_PLUGINS" ]; then
        return 1
    fi
    jq -e --arg name "$plugin_name" '.plugins | keys[] | select(startswith($name))' "$INSTALLED_PLUGINS" >/dev/null 2>&1
}

# Check if a plugin is blocklisted
is_plugin_blocked() {
    local plugin_name="$1"
    if [ ! -f "$BLOCKLIST" ]; then
        return 1
    fi
    jq -e --arg name "$plugin_name" '.plugins[]? | select(.plugin | startswith($name))' "$BLOCKLIST" >/dev/null 2>&1
}

# --- Collection ---

ENTRIES="[]"
entry_count=0

add_entry() {
    local name="$1"
    local source="$2"
    local description="$3"
    local domain_tags="$4"
    local enabled="$5"
    local path="$6"

    ENTRIES=$(printf '%s' "$ENTRIES" | jq \
        --arg name "$name" \
        --arg source "$source" \
        --arg desc "$description" \
        --argjson tags "$domain_tags" \
        --argjson enabled "$enabled" \
        --arg path "$path" \
        '. + [{
            name: $name,
            source: $source,
            description: $desc,
            domain_tags: $tags,
            enabled: $enabled,
            path: $path
        }]')
    entry_count=$((entry_count + 1))
}

# --- 1. User skills (~/.claude/skills/*/SKILL.md) ---
log "Scanning user skills..."
for skill_file in "${CLAUDE_DIR}"/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    skill_name=$(extract_frontmatter_field "$skill_file" "name")
    if [ -z "$skill_name" ]; then
        skill_name=$(basename "$(dirname "$skill_file")")
    fi
    desc=$(extract_description "$skill_file")
    tags=$(infer_domain_tags "$desc")
    add_entry "$skill_name" "user-skill" "$desc" "$tags" "true" "$skill_file"
done

# --- 2. Project skills (.claude/skills/*/SKILL.md in cwd) ---
log "Scanning project skills..."
if [ -d ".claude/skills" ]; then
    for skill_file in .claude/skills/*/SKILL.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(extract_frontmatter_field "$skill_file" "name")
        if [ -z "$skill_name" ]; then
            skill_name=$(basename "$(dirname "$skill_file")")
        fi
        desc=$(extract_description "$skill_file")
        tags=$(infer_domain_tags "$desc")
        add_entry "$skill_name" "project-skill" "$desc" "$tags" "true" "$skill_file"
    done
fi

# --- 3. User agents (~/.claude/agents/*.md) ---
log "Scanning user agents..."
for agent_file in "${CLAUDE_DIR}"/agents/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(extract_frontmatter_field "$agent_file" "name")
    if [ -z "$agent_name" ]; then
        agent_name=$(basename "$agent_file" .md)
    fi
    desc=$(extract_description "$agent_file")
    tags=$(infer_domain_tags "$desc")
    add_entry "$agent_name" "user-agent" "$desc" "$tags" "true" "$agent_file"
done

# --- 4. Project agents (.claude/agents/*.md in cwd) ---
log "Scanning project agents..."
if [ -d ".claude/agents" ]; then
    for agent_file in .claude/agents/*.md; do
        [ -f "$agent_file" ] || continue
        agent_name=$(extract_frontmatter_field "$agent_file" "name")
        if [ -z "$agent_name" ]; then
            agent_name=$(basename "$agent_file" .md)
        fi
        desc=$(extract_description "$agent_file")
        tags=$(infer_domain_tags "$desc")
        add_entry "$agent_name" "project-agent" "$desc" "$tags" "true" "$agent_file"
    done
fi

# --- 5. Plugins (cache + local) ---
log "Scanning plugins..."

scan_plugin_dir() {
    local plugin_json="$1"
    local source_type="$2"

    [ -f "$plugin_json" ] || return 0

    local pname
    pname=$(jq -r '.name // empty' "$plugin_json" 2>/dev/null)
    [ -z "$pname" ] && return 0

    local pdesc
    pdesc=$(jq -r '.description // ""' "$plugin_json" 2>/dev/null)

    local tags
    tags=$(infer_domain_tags "$pdesc")

    # Determine enabled status
    local enabled="true"
    if is_plugin_blocked "$pname"; then
        enabled="false"
    fi

    local plugin_dir
    plugin_dir=$(dirname "$plugin_json")
    # If plugin.json is inside .claude-plugin/, go up one level
    case "$plugin_dir" in
        */.claude-plugin) plugin_dir=$(dirname "$plugin_dir") ;;
    esac

    add_entry "$pname" "$source_type" "$pdesc" "$tags" "$enabled" "$plugin_dir"

    # Scan nested skills
    for nested_skill in "${plugin_dir}"/skills/*/SKILL.md; do
        [ -f "$nested_skill" ] || continue
        local sname
        sname=$(extract_frontmatter_field "$nested_skill" "name")
        if [ -z "$sname" ]; then
            sname=$(basename "$(dirname "$nested_skill")")
        fi
        local sdesc
        sdesc=$(extract_description "$nested_skill")
        local stags
        stags=$(infer_domain_tags "$sdesc")
        add_entry "${pname}:${sname}" "plugin-skill" "$sdesc" "$stags" "$enabled" "$nested_skill"
    done

    # Scan nested agents
    for nested_agent in "${plugin_dir}"/agents/*.md; do
        [ -f "$nested_agent" ] || continue
        local aname
        aname=$(extract_frontmatter_field "$nested_agent" "name")
        if [ -z "$aname" ]; then
            aname=$(basename "$nested_agent" .md)
        fi
        local adesc
        adesc=$(extract_description "$nested_agent")
        local atags
        atags=$(infer_domain_tags "$adesc")
        add_entry "${pname}:${aname}" "plugin-agent" "$adesc" "$atags" "$enabled" "$nested_agent"
    done
}

# Cache plugins — find .claude-plugin/plugin.json at any depth, skip test fixtures
# Use temp file to avoid subshell from pipe (variable changes would be lost)
_cache_list=$(mktemp)
find "${CLAUDE_DIR}/plugins/cache" -path "*/evals/*" -prune -o \
    -path "*/.claude-plugin/plugin.json" -print 2>/dev/null > "$_cache_list"
while IFS= read -r pj; do
    scan_plugin_dir "$pj" "plugin-cache"
done < "$_cache_list"
rm -f "$_cache_list"

# Local plugins
for local_dir in "${CLAUDE_DIR}"/plugins/local/*/; do
    [ -d "$local_dir" ] || continue
    if [ -f "${local_dir}.claude-plugin/plugin.json" ]; then
        scan_plugin_dir "${local_dir}.claude-plugin/plugin.json" "plugin-local"
    elif [ -f "${local_dir}plugin.json" ]; then
        scan_plugin_dir "${local_dir}plugin.json" "plugin-local"
    fi
done

# --- 6. Built-in subagent types ---
log "Adding built-in subagent types..."

add_builtin() {
    local name="$1"
    local desc="$2"
    local tags="$3"
    add_entry "$name" "built-in" "$desc" "$tags" "true" "built-in"
}

add_builtin "general-purpose" \
    "General-purpose agent for researching complex questions, searching for code, and executing multi-step tasks" \
    '["meta"]'

add_builtin "Explore" \
    "Fast agent specialized for exploring codebases — find files by patterns, search code for keywords, answer questions about codebase structure" \
    '["review"]'

add_builtin "Plan" \
    "Software architect agent for designing implementation plans — returns step-by-step plans, identifies critical files, considers architectural trade-offs" \
    '["meta"]'

add_builtin "implementation-agent" \
    "Production code implementation specialist with autonomous file editing capabilities" \
    '["meta"]'

add_builtin "test-runner" \
    "Test execution and failure analysis specialist with autonomous fix capabilities" \
    '["testing"]'

add_builtin "web-researcher" \
    "Web research agent for gathering facts, comparisons, current information from multiple sources" \
    '["meta"]'

# Plugin-provided subagent types
for agent_type in \
    "superpowers:code-reviewer" \
    "code-simplifier:code-simplifier" \
    "agent-teams:team-implementer" \
    "agent-teams:team-lead" \
    "agent-teams:team-debugger" \
    "agent-teams:team-reviewer" \
    "comprehensive-review:code-reviewer" \
    "comprehensive-review:architect-review" \
    "comprehensive-review:security-auditor" \
    "context-management:context-manager" \
    "data-engineering:backend-architect" \
    "data-engineering:data-engineer" \
    "database-design:database-architect" \
    "database-design:sql-pro" \
    "llm-application-dev:prompt-engineer" \
    "llm-application-dev:vector-database-engineer" \
    "llm-application-dev:ai-engineer" \
    "shell-scripting:posix-shell-pro" \
    "shell-scripting:bash-pro" \
    "javascript-typescript:typescript-pro" \
    "javascript-typescript:javascript-pro" \
    "multi-platform-apps:ios-developer" \
    "multi-platform-apps:flutter-expert" \
    "multi-platform-apps:backend-architect" \
    "multi-platform-apps:ui-ux-designer" \
    "multi-platform-apps:mobile-developer" \
    "multi-platform-apps:frontend-developer" \
    "framework-migration:architect-review" \
    "framework-migration:legacy-modernizer" \
    "performance-testing-review:test-automator" \
    "performance-testing-review:performance-engineer" \
    "frontend-mobile-development:mobile-developer" \
    "frontend-mobile-development:frontend-developer" \
    "full-stack-orchestration:test-automator" \
    "full-stack-orchestration:performance-engineer" \
    "full-stack-orchestration:security-auditor" \
    "full-stack-orchestration:deployment-engineer" \
    "git-pr-workflows:code-reviewer" \
    "content-marketing:search-specialist" \
    "content-marketing:content-marketer"; do

    plugin_part="${agent_type%%:*}"
    agent_part="${agent_type##*:}"

    # Check if the providing plugin is installed
    plugin_enabled="false"
    if is_plugin_installed "$plugin_part"; then
        plugin_enabled="true"
    fi

    add_entry "$agent_type" "built-in-subagent" "Plugin-provided subagent type from ${plugin_part}" '["meta"]' "$plugin_enabled" "built-in"
done

# --- 7. Assemble output ---
log "Writing registry (${entry_count} entries)..."

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

OUTPUT=$(jq -n \
    --arg version "1.0" \
    --arg generated "$TIMESTAMP" \
    --argjson count "$entry_count" \
    --argjson entries "$ENTRIES" \
    '{
        schema_version: $version,
        generated_at: $generated,
        total_entries: $count,
        capabilities: $entries
    }')

printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"

# Validate
if jq empty "$OUTPUT_FILE" 2>/dev/null; then
    log "Registry written: ${OUTPUT_FILE} (${entry_count} entries)"
else
    echo "ERROR: Invalid JSON output" >&2
    exit 1
fi
