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
# Note: -e omitted deliberately. The script uses grep/sed in pipelines that
# legitimately return exit 1 on no-match. set -e + pipefail would cause silent
# exits from extract_frontmatter_field/extract_description. Errors are handled
# explicitly where needed (jq validation at the end, etc.).

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
        case "$(uname -s)" in
            Darwin*) file_mtime=$(stat -f '%m' "$OUTPUT_FILE" 2>/dev/null || echo 0) ;;
            Linux*)  file_mtime=$(stat -c '%Y' "$OUTPUT_FILE" 2>/dev/null || echo 0) ;;
            *)       file_mtime=0 ;;
        esac
        now=$(date +%s)
        age=$((now - file_mtime))
        if [ "$age" -lt "$TTL" ]; then
            # Invalidate if installed_plugins.json is newer than registry
            # (plugin install/update/removal means registry is stale)
            stale_plugins=false
            if [ -f "$INSTALLED_PLUGINS" ]; then
                case "$(uname -s)" in
                    Darwin*) plugins_mtime=$(stat -f '%m' "$INSTALLED_PLUGINS" 2>/dev/null || echo 0) ;;
                    Linux*)  plugins_mtime=$(stat -c '%Y' "$INSTALLED_PLUGINS" 2>/dev/null || echo 0) ;;
                    *)       plugins_mtime=0 ;;
                esac
                if [ "$plugins_mtime" -gt "$file_mtime" ]; then
                    stale_plugins=true
                    log "installed_plugins.json is newer than registry — rebuilding."
                fi
            fi
            if [ "$stale_plugins" = false ]; then
                log "Cache valid (${age}s < ${TTL}s TTL). Use --force to rebuild."
                exit 0
            fi
        fi
    fi
fi

# --- Ensure output dir ---
mkdir -p "$REGISTRY_DIR"

# --- Helpers ---

# Word-bounded match — avoids substring false positives
# Usage: word_match "text" "word"
word_match() {
    local text="$1" word="$2"
    [[ "$text" =~ (^|[[:space:][:punct:]])"$word"([[:space:][:punct:]]|$) ]]
}

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
    # Extract first meaningful sentence (ends at . ! or ? followed by space or end),
    # capped at 500 chars to preserve routing signal without mid-word truncation.
    local first_sentence
    first_sentence=$(printf '%s' "$desc" | grep -oE '^[^.!?]*[.!?](\s|$)' | head -1 | sed 's/[[:space:]]*$//')
    if [ -n "$first_sentence" ]; then
        printf '%s' "$first_sentence" | head -c 500
    else
        # No sentence boundary found — fall back to hard cap at 500 chars
        printf '%s' "$desc" | head -c 500
    fi
}

# Get domain tags for a skill file — checks explicit frontmatter first, falls back to inference
get_skill_tags() {
    local skill_file="$1"
    local desc="$2"
    local explicit_tags
    explicit_tags=$(grep -m1 '^domain_tags:' "$skill_file" 2>/dev/null | sed 's/^domain_tags:[[:space:]]*//' | tr -d '[]')
    if [ -n "$explicit_tags" ]; then
        # Parse comma-separated list into JSON array
        printf '%s' "$explicit_tags" | tr ',' '\n' | \
            sed "s/^[[:space:]]*//" | sed "s/[[:space:]]*$//" | \
            grep -v '^$' | jq -R . | jq -s .
        return
    fi
    infer_domain_tags "$desc"
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
        *llm*|*" ai model"*|*" ai agent"*|*" ai system"*|*"ai-powered"*|*"ai/"*|*"ai-"*|*"-ai"*|*embedding*|*" rag "*|*"vector database"*|*"vector search"*|*"language model"*|*"machine learning"*|*openai*|*anthropic*|*"prompt engineer"*|*"prompt templat"*|*"prompt optim"*) tags="${tags}ai," ;;
    esac
    case "$lower" in
        *"data "*|*" data"*|*dataset*|*dataframe*|*datalake*|*"data-"*|*"etl pipeline"*|*"ingestion pipeline"*|*" etl "*|*spark*|*airflow*|*dbt*) tags="${tags}data," ;;
    esac
    case "$lower" in
        *review*|*audit*|*quality*) tags="${tags}review," ;;
    esac
    case "$lower" in
        *"git commit"*|*"git log"*|*" commits "*|*"merge request"*|*"merge conflict"*|*"git merge"*|*"pull request"*|*"pull-request"*|*" pr "*|*" prs "*) tags="${tags}git," ;;
        *git*) case "$lower" in *"gitops"*) ;; *) tags="${tags}git," ;; esac ;;
    esac
    case "$lower" in
        *plugin*|*skill*|*agent*|*claude*code*) tags="${tags}meta," ;;
    esac

    # Workflow/orchestration
    case "$lower" in
        *workflow*|*handoff*|*session*|*orchestrat*|*decompose*|*delegate*) tags="${tags}workflow," ;;
    esac

    # Documentation/writing
    case "$lower" in
        *documentation*|*" doc "*|*" docs "*|*wiki*|*readme*|*article*|*writing*) tags="${tags}documentation," ;;
    esac

    # Search/exploration
    case "$lower" in
        *search*|*explore*|*"find files"*|*"find code"*|*discover*) tags="${tags}search," ;;
    esac

    # Terminal/shell config (separate from shell scripting)
    case "$lower" in
        *terminal*|*ghostty*|*" tty"*|*" zsh"*|*"shell config"*) tags="${tags}terminal," ;;
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
    # subagent_type: the value passed to the Agent tool's subagent_type parameter.
    # - plugin-agent: fully-qualified name (e.g. "shell-scripting:bash-pro")
    # - built-in-subagent: the agent type name itself (e.g. "implementation-agent")
    # - built-in: the agent name (e.g. "general-purpose", "Explore")
    # - user-agent / project-agent: filename stem (e.g. "web-researcher")
    # - skills (user-skill, project-skill, plugin-skill): null — skills layer onto agents
    # - everything else: null
    local subagent_type="${7:-null}"

    ENTRIES=$(printf '%s' "$ENTRIES" | jq \
        --arg name "$name" \
        --arg source "$source" \
        --arg desc "$description" \
        --argjson tags "$domain_tags" \
        --argjson enabled "$enabled" \
        --arg path "$path" \
        --argjson subagent_type "$subagent_type" \
        '. + [{
            name: $name,
            source: $source,
            description: $desc,
            domain_tags: $tags,
            enabled: $enabled,
            path: $path,
            subagent_type: $subagent_type
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
    tags=$(get_skill_tags "$skill_file" "$desc")
    # Skills are layered onto agents — no subagent_type
    add_entry "$skill_name" "user-skill" "$desc" "$tags" "true" "$skill_file" "null"
done

# --- 2. Project skills (.claude/skills/*/SKILL.md in cwd) ---
log "Scanning project skills..."
# Resolve to absolute to avoid duplicating user-level entries when cwd is ~
_project_skills_abs=$(cd -- "$(pwd -P)" && cd .claude/skills 2>/dev/null && pwd -P || true)
_user_skills_abs=$(cd -- "${CLAUDE_DIR}/skills" 2>/dev/null && pwd -P || true)
if [ -n "$_project_skills_abs" ] && [ "$_project_skills_abs" != "$_user_skills_abs" ]; then
    for skill_file in "${_project_skills_abs}"/*/SKILL.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(extract_frontmatter_field "$skill_file" "name")
        if [ -z "$skill_name" ]; then
            skill_name=$(basename "$(dirname "$skill_file")")
        fi
        desc=$(extract_description "$skill_file")
        tags=$(get_skill_tags "$skill_file" "$desc")
        # Skills are layered onto agents — no subagent_type
        add_entry "$skill_name" "project-skill" "$desc" "$tags" "true" "$skill_file" "null"
    done
fi
unset _project_skills_abs _user_skills_abs

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
    # User agents: subagent_type is the filename stem (the Agent tool identifier)
    agent_stem=$(basename "$agent_file" .md)
    add_entry "$agent_name" "user-agent" "$desc" "$tags" "true" "$agent_file" "\"${agent_stem}\""
done

# --- 4. Project agents (.claude/agents/*.md in cwd) ---
log "Scanning project agents..."
# Resolve to absolute to avoid duplicating user-level entries when cwd is ~
_project_agents_abs=$(cd -- "$(pwd -P)" && cd .claude/agents 2>/dev/null && pwd -P || true)
_user_agents_abs=$(cd -- "${CLAUDE_DIR}/agents" 2>/dev/null && pwd -P || true)
if [ -n "$_project_agents_abs" ] && [ "$_project_agents_abs" != "$_user_agents_abs" ]; then
    for agent_file in "${_project_agents_abs}"/*.md; do
        [ -f "$agent_file" ] || continue
        agent_name=$(extract_frontmatter_field "$agent_file" "name")
        if [ -z "$agent_name" ]; then
            agent_name=$(basename "$agent_file" .md)
        fi
        desc=$(extract_description "$agent_file")
        tags=$(infer_domain_tags "$desc")
        # Project agents: subagent_type is the filename stem (the Agent tool identifier)
        agent_stem=$(basename "$agent_file" .md)
        add_entry "$agent_name" "project-agent" "$desc" "$tags" "true" "$agent_file" "\"${agent_stem}\""
    done
fi
unset _project_agents_abs _user_agents_abs

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

    # Plugin container entries have no direct subagent_type (agents are the typed entries below)
    add_entry "$pname" "$source_type" "$pdesc" "$tags" "$enabled" "$plugin_dir" "null"

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
        stags=$(get_skill_tags "$nested_skill" "$sdesc")
        # Plugin skills are layered onto agents — no subagent_type
        add_entry "${pname}:${sname}" "plugin-skill" "$sdesc" "$stags" "$enabled" "$nested_skill" "null"
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
        # Plugin agents: subagent_type is the fully-qualified "plugin:agent" name
        add_entry "${pname}:${aname}" "plugin-agent" "$adesc" "$atags" "$enabled" "$nested_agent" "\"${pname}:${aname}\""
    done
}

# Cache plugins — find .claude-plugin/plugin.json at any depth, skip test fixtures
# Use temp file to avoid subshell from pipe (variable changes would be lost)
_cache_list=$(mktemp) || { echo "ERROR: mktemp failed" >&2; exit 1; }
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
    # Built-in subagents: subagent_type is the agent name (used directly with the Agent tool)
    add_entry "$name" "built-in" "$desc" "$tags" "true" "built-in" "\"${name}\""
}

add_builtin "general-purpose" \
    "General-purpose agent for researching complex questions, searching for code, and executing multi-step tasks" \
    '["meta", "workflow"]'

add_builtin "Explore" \
    "Fast agent specialized for exploring codebases — find files by patterns, search code for keywords, answer questions about codebase structure" \
    '["meta", "search", "exploration"]'

add_builtin "Plan" \
    "Software architect agent for designing implementation plans — returns step-by-step plans, identifies critical files, considers architectural trade-offs" \
    '["meta", "workflow", "planning"]'

add_builtin "implementation-agent" \
    "Production code implementation specialist with autonomous file editing capabilities" \
    '["meta", "implementation"]'

add_builtin "test-runner" \
    "Test execution and failure analysis specialist with autonomous fix capabilities" \
    '["meta", "testing"]'

add_builtin "web-researcher" \
    "Web research agent for gathering facts, comparisons, current information from multiple sources" \
    '["meta", "research"]'

# Infer tags from plugin prefix for built-in-subagent entries
infer_tags_from_plugin_prefix() {
    local plugin_prefix="$1"
    case "$plugin_prefix" in
        shell-scripting)           echo "shell,infrastructure" ;;
        javascript-typescript)     echo "javascript,typescript" ;;
        llm-application-dev)       echo "ai,api" ;;
        database-design|database-*) echo "database,data" ;;
        data-engineering)          echo "data,infrastructure" ;;
        multi-platform-apps|frontend-mobile-*) echo "mobile,frontend" ;;
        security-*|comprehensive-review) echo "security,review" ;;
        performance-*|application-performance) echo "performance,testing" ;;
        agent-teams|orchestration-*) echo "meta,workflow" ;;
        git-pr-workflows)          echo "git" ;;
        framework-migration)       echo "meta,infrastructure" ;;
        full-stack-orchestration)  echo "api,frontend,infrastructure" ;;
        debugging-toolkit)         echo "meta,review" ;;
        plugin-dev)                echo "meta" ;;
        *)                         echo "meta" ;;
    esac
}

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
    "content-marketing:content-marketer" \
    "plugin-dev:agent-creator" \
    "plugin-dev:skill-reviewer" \
    "plugin-dev:plugin-validator"; do

    plugin_part="${agent_type%%:*}"
    agent_part="${agent_type##*:}"

    # Check if the providing plugin is installed
    plugin_enabled="false"
    if is_plugin_installed "$plugin_part"; then
        plugin_enabled="true"
    fi

    # Infer tags from plugin prefix rather than hardcoding ["meta"]
    raw_tags=$(infer_tags_from_plugin_prefix "$plugin_part")
    plugin_tags=$(printf '%s' "$raw_tags" | tr ',' '\n' | jq -R . | jq -s .)

    # built-in-subagent: the fully-qualified "plugin:agent" name is the subagent_type
    add_entry "$agent_type" "built-in-subagent" "Plugin-provided subagent type from ${plugin_part}" "$plugin_tags" "$plugin_enabled" "built-in" "\"${agent_type}\""
done

# --- 7. Dedup by subagent_type (before assembly) ---
# Entries with non-null subagent_type may appear in both the plugin scan (section 5)
# and the built-in-subagent hardcoded list (section 6). Keep the richest source.
# Source priority: user-agent > project-agent > plugin-agent > plugin-cache > built-in-subagent > built-in > others
# Enabled status takes precedence over source rank: an enabled lower-priority source
# beats a disabled higher-priority source (e.g. a blocklisted plugin-agent should not
# shadow the always-enabled built-in-subagent fallback for the same subagent_type).
# Entries with null subagent_type (skills, plugin containers) are all kept as-is.
pre_dedup_count="$entry_count"
ENTRIES=$(printf '%s' "$ENTRIES" | jq '
    # Split into typed (non-null subagent_type) and untyped
    . as $all |
    ($all | map(select(.subagent_type != null))) as $typed |
    ($all | map(select(.subagent_type == null))) as $untyped |
    # Source priority: lower number = higher priority (keep this one)
    # Order matches capability-aware-dispatch.md: user-agent > plugin-agent > built-in-subagent > generic
    def source_rank:
        if . == "user-agent"         then 0
        elif . == "project-agent"    then 1
        elif . == "plugin-agent"     then 2
        elif . == "plugin-cache"     then 3
        elif . == "built-in-subagent" then 4
        elif . == "built-in"         then 5
        else 6
        end;
    # Sort key: enabled entries sort before disabled (false=1 > true=0 numerically,
    # so negate: enabled=true -> 0, enabled=false -> 1), then by source rank.
    # This ensures a disabled plugin-agent does not shadow an enabled built-in-subagent.
    def sort_key: [(.enabled | not | if . then 1 else 0 end), (.source | source_rank)];
    # Deduplicate: for each subagent_type, keep the entry with the best sort_key
    ($typed | group_by(.subagent_type) | map(sort_by(sort_key) | first)) as $deduped |
    $untyped + $deduped
')
entry_count=$(printf '%s' "$ENTRIES" | jq 'length')
dedup_removed=$((pre_dedup_count - entry_count))
if [ "$dedup_removed" -gt 0 ]; then
    log "Deduplication removed ${dedup_removed} duplicate subagent_type entries."
fi

# --- 8. Assemble output ---
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

# Validate JSON
if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
    echo "ERROR: Invalid JSON output" >&2
    exit 1
fi

# Validate domain_tags — all tags must match ^[a-z][a-z0-9-]*$ (no regex metacharacters).
# The dispatch-routing-guard hook uses jq test() with word boundaries on these tags,
# so metacharacters would cause false matches or parse errors.
if ! jq -e '[.capabilities[].domain_tags[]?] | unique | all(test("^[a-z][a-z0-9-]*$"))' "$OUTPUT_FILE" >/dev/null 2>&1; then
    echo "ERROR: domain_tags contain invalid characters (must match ^[a-z][a-z0-9-]*$)" >&2
    # Show offending tags
    jq -r '[.capabilities[].domain_tags[]?] | unique[] | select(test("^[a-z][a-z0-9-]*$") | not)' "$OUTPUT_FILE" 2>/dev/null | while IFS= read -r tag; do
        echo "  invalid tag: \"$tag\"" >&2
    done
    exit 1
fi

log "Registry written: ${OUTPUT_FILE} (${entry_count} entries)"
