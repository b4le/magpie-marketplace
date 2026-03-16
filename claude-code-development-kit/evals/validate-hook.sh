#!/usr/bin/env bash
# validate-hook.sh - Validates a Claude Code hook script
# Usage: ./validate-hook.sh [--security] <hook-path>
# Exit 0: clean, 1: critical findings, 2: warnings only (no criticals)

set -Eeuo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

ERRORS=()
WARNINGS=()
SECURITY_ONLY=false

# --------------------------------------------------------------------------
# Logging helpers
# --------------------------------------------------------------------------

log_error() {
    ERRORS+=("$1")
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

log_warning() {
    WARNINGS+=("$1")
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[PASS]${NC} %s\n" "$1"
}

log_info() {
    printf "[INFO] %s\n" "$1"
}

log_section() {
    printf "\n${CYAN}--- %s ---${NC}\n" "$1"
}

# --------------------------------------------------------------------------
# Help
# --------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
validate-hook.sh - Validates a Claude Code hook script

USAGE:
    ./validate-hook.sh [OPTIONS] <hook-path>
    ./validate-hook.sh --help

ARGUMENTS:
    hook-path    Path to the hook script file (any executable script)

OPTIONS:
    --security   Run only security checks (skip style/quality checks)
    --help, -h   Show this help message

VALIDATION RULES:
    Structure (unless --security):
        - File must exist
        - File must have a shebang line (#!) or be marked executable
        - Shebang points to a recognised interpreter (bash, sh, python, node)
        - Script uses error handling (set -e, set -o errexit, or || exit patterns)
        - No hardcoded personal paths (e.g., /Users/yourname/)
        - Script length check (>200 lines triggers a warning)

    Security (always):
        NETWORK      curl, wget, nc, netcat, /dev/tcp, python.*http, socat, dns exfil
        DYNAMIC      eval, exec, bash/sh -c with $var, source with variable, backticks
        ENCODING     base64 decode piped to shell (CRITICAL), bare base64 -d, hex escapes
        FS_ESCAPE    ../ traversal, /etc/passwd|shadow, ~/.ssh/, /proc/, /dev/tcp
        ENV_ACCESS   ANTHROPIC_API_KEY, GITHUB_TOKEN, AWS_*, SSH_AUTH_SOCK, GIT_ASKPASS
        PERSISTENCE  launchctl, crontab, .bashrc/.zshrc, loginitems, LaunchAgent
        SUPPLY_CHAIN npm/pip/cargo/go/gem/yarn install at runtime
        SANDBOX_ESC  dangerouslyDisableSandbox, osascript, xattr -d quarantine
        SYMLINK      ln -s, symlink() in executable contexts

EXIT CODES:
    0    Clean — no findings
    1    Critical findings (blocks)
    2    Warnings only (no criticals)

EXAMPLES:
    ./validate-hook.sh ./hooks/pre-tool-use.sh
    ./validate-hook.sh --security /path/to/plugin/hooks/checkpoint-detector.sh
EOF
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --security) SECURITY_ONLY=true; shift ;;
        --) shift; break ;;
        -*) printf "Unknown option: %s\n" "$1" >&2; exit 1 ;;
        *) break ;;
    esac
done

if [[ $# -lt 1 ]]; then
    printf "Usage: %s [--security] <hook-path>\n" "$0"
    printf "       %s --help\n" "$0"
    exit 1
fi

HOOK_PATH="$1"

# Resolve to absolute path
if [[ "$HOOK_PATH" != /* ]]; then
    HOOK_PATH="$(pwd)/$HOOK_PATH"
fi

printf "==========================================\n"
printf "Validating Hook: %s\n" "$HOOK_PATH"
printf "==========================================\n"

# Check if file exists
if [[ ! -f "$HOOK_PATH" ]]; then
    log_error "Hook file not found: $HOOK_PATH"
    exit 1
fi
log_success "Hook file exists"

# Read first line; full content is accessed via grep helpers (_has_pattern/_match_lines)
FIRST_LINE=$(head -1 "$HOOK_PATH")

# --------------------------------------------------------------------------
# SECURITY CHECKS
# All functions populate ERRORS[] or WARNINGS[]; callers print section header.
# Each function uses grep against $CONTENT (already in memory — no subshells
# inside loops over lines).
# --------------------------------------------------------------------------

# Helper: find matching lines for a pattern, return count + excerpt
_match_lines() {
    local pattern="$1"
    grep -nE "$pattern" "$HOOK_PATH" 2>/dev/null || true
}

_has_pattern() {
    local pattern="$1"
    grep -qE "$pattern" "$HOOK_PATH" 2>/dev/null
}

# NETWORK — outbound connections, DNS exfil
check_network_patterns() {
    local findings

    # CRITICAL: direct network exfil tools
    local -a critical_net=(
        '\bcurl\b'
        '\bwget\b'
        '\bsocat\b'
        'python[23]?\s.*[Hh]ttp[Ss]?[Cc]lient|urllib|http\.server|requests\.'
        '\bfetch\s.*https?://'
    )
    for pat in "${critical_net[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -3)
            log_error "NETWORK [CRITICAL]: outbound network tool detected — pattern '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # HIGH: network tools that may have benign uses but are suspicious in hooks
    local -a high_net=(
        '\bnc\b|\bnetcat\b|\bncat\b'
        '/dev/tcp/'
        '/dev/udp/'
    )
    for pat in "${high_net[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -3)
            log_error "NETWORK [HIGH]: raw socket/device detected — pattern '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # MEDIUM: DNS-based exfiltration tools
    local -a medium_net=(
        '\bnslookup\b'
        '\bdig\b'
        '\bhost\b\s'
    )
    for pat in "${medium_net[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_warning "NETWORK [MEDIUM]: DNS tool detected (potential exfil) — pattern '$pat'"
            printf "    %s\n" "$findings"
        fi
    done
}

# DYNAMIC — code execution with runtime-controlled input
check_dynamic_patterns() {
    local findings

    # CRITICAL: eval/exec with variable content — near-certain injection vector
    local -a critical_dyn=(
        'eval\s+\$'
        'eval\s+"\$'
        'eval\s+`'
        '\bexec\s+\$'
        '\bexec\s+"\$'
    )
    for pat in "${critical_dyn[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -3)
            log_error "DYNAMIC [CRITICAL]: eval/exec with variable input — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # HIGH: bash/sh -c with variable argument, or shell spawned inside command substitution
    local -a high_dyn=(
        'bash\s+-c\s+["\047]?\s*\$'
        'sh\s+-c\s+["\047]?\s*\$'
        '\$\((bash|sh|zsh)\s'
    )
    for pat in "${high_dyn[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "DYNAMIC [HIGH]: shell invocation with variable argument — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # HIGH: source/dot with variable path
    if _has_pattern '^\s*(\.|source)\s+\$'; then
        findings=$(_match_lines '^\s*(\.|source)\s+\$' | head -2)
        log_error "DYNAMIC [HIGH]: source/dot with variable path — potential hijack"
        printf "    %s\n" "$findings"
    fi

    # MEDIUM: bare eval (may be benign, still worth flagging)
    if _has_pattern '\beval\b'; then
        if ! _has_pattern 'eval\s+\$|eval\s+"\$|eval\s+`'; then
            findings=$(_match_lines '\beval\b' | head -2)
            log_warning "DYNAMIC [MEDIUM]: 'eval' detected — ensure not used with user-controlled input"
            printf "    %s\n" "$findings"
        fi
    fi

    # MEDIUM: backtick subshells (style issue + harder to audit)
    # shellcheck disable=SC2016  # \$ in single quotes is intentional: grep regex for literal dollar sign
    if _has_pattern '`[^`]*\$[A-Za-z_][^`]*`'; then
        # shellcheck disable=SC2016
        findings=$(_match_lines '`[^`]*\$[A-Za-z_][^`]*`' | head -2)
        log_warning "DYNAMIC [MEDIUM]: backtick subshell with variable — prefer \$() and review for injection"
        printf "    %s\n" "$findings"
    fi
}

# ENCODING — obfuscated payload delivery
check_encoding_patterns() {
    local findings

    # CRITICAL: base64 decode piped directly to a shell — classic payload delivery
    if _has_pattern 'base64\s.*-d.*\|\s*(bash|sh|zsh|python|perl|ruby)' || \
       _has_pattern '\|\s*(bash|sh|zsh)\s*<\s*\(.*base64'; then
        findings=$(_match_lines 'base64' | head -3)
        log_error "ENCODING [CRITICAL]: base64 decode piped to shell — classic payload delivery"
        printf "    %s\n" "$findings"
    fi

    # HIGH: bare base64 decode (may feed decoded content to another command)
    if _has_pattern 'base64\s+(-d|--decode|--ignore-garbage)'; then
        # Only flag if not already caught as CRITICAL above
        if ! _has_pattern 'base64\s.*-d.*\|\s*(bash|sh|zsh|python|perl|ruby)'; then
            findings=$(_match_lines 'base64\s+(-d|--decode)' | head -2)
            log_error "ENCODING [HIGH]: base64 decode detected — review what decoded content is used for"
            printf "    %s\n" "$findings"
        fi
    fi

    # HIGH: xxd / od hex decode pipelines
    if _has_pattern '\bxxd\s+-r\b|\bod\b.*\|\s*(bash|sh)'; then
        findings=$(_match_lines '\bxxd\b|\bod\b' | head -2)
        log_error "ENCODING [HIGH]: hex decode pipeline detected"
        printf "    %s\n" "$findings"
    fi

    # MEDIUM: hex escape sequences in strings (e.g., $'\x41\x42')
    if _has_pattern "\\$'(\\\\x[0-9a-fA-F]{2}){3,}'"; then
        findings=$(_match_lines "\\$'(\\\\x[0-9a-fA-F]{2})+" | head -2)
        log_warning "ENCODING [MEDIUM]: hex escape sequence in string — review for obfuscated content"
        printf "    %s\n" "$findings"
    fi
}

# FS_ESCAPE — filesystem traversal and sensitive file access
check_fs_escape_patterns() {
    local findings

    # CRITICAL: path traversal
    if _has_pattern '\.\./\.\./|/\.\./'; then
        findings=$(_match_lines '\.\./\.\.' | head -2)
        log_error "FS_ESCAPE [CRITICAL]: path traversal sequence detected (../../)"
        printf "    %s\n" "$findings"
    fi

    # CRITICAL: sensitive system files
    local -a critical_fs=(
        '/etc/passwd'
        '/etc/shadow'
    )
    for pat in "${critical_fs[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "FS_ESCAPE [CRITICAL]: access to sensitive system file — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # HIGH: SSH credentials and auth sockets via filesystem
    # shellcheck disable=SC2088  # tilde is intentional here: matching literal ~/\.ssh/ in script text
    if _has_pattern '~/\.ssh/|/\.ssh/(id_|authorized_keys|known_hosts)'; then
        findings=$(_match_lines '\.ssh/' | head -2)
        log_error "FS_ESCAPE [HIGH]: SSH credential path access detected"
        printf "    %s\n" "$findings"
    fi

    # HIGH: proc/dev filesystem access (potential sandbox escape, exfil via /dev/tcp)
    if _has_pattern '/proc/[0-9]+|/proc/self'; then
        findings=$(_match_lines '/proc/' | head -2)
        log_error "FS_ESCAPE [HIGH]: /proc filesystem access detected"
        printf "    %s\n" "$findings"
    fi

    if _has_pattern '/dev/tcp/|/dev/udp/'; then
        findings=$(_match_lines '/dev/tcp/|/dev/udp/' | head -2)
        log_error "FS_ESCAPE [HIGH]: /dev/tcp or /dev/udp shell redirect detected"
        printf "    %s\n" "$findings"
    fi
}

# ENV_ACCESS — credential harvesting via environment
check_env_access_patterns() {
    local findings

    # CRITICAL: Anthropic API key exfil
    if _has_pattern '\$\{?ANTHROPIC_API_KEY\}?'; then
        findings=$(_match_lines 'ANTHROPIC_API_KEY' | head -3)
        log_error "ENV_ACCESS [CRITICAL]: ANTHROPIC_API_KEY accessed — potential credential exfil"
        printf "    %s\n" "$findings"
    fi

    # HIGH: other known credential env vars
    local -a high_env=(
        '\$\{?GITHUB_TOKEN\}?'
        '\$\{?GH_TOKEN\}?'
        '\$\{?AWS_ACCESS_KEY_ID\}?'
        '\$\{?AWS_SECRET_ACCESS_KEY\}?'
        '\$\{?AWS_SESSION_TOKEN\}?'
        '\$\{?GIT_ASKPASS\}?'
        '\$\{?GOOGLE_APPLICATION_CREDENTIALS\}?'
        '\$\{?FIREBASE_TOKEN\}?'
        '\$\{?NPM_TOKEN\}?'
        '\$\{?PYPI_TOKEN\}?'
    )
    for pat in "${high_env[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "ENV_ACCESS [HIGH]: credential environment variable accessed — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # MEDIUM: SSH agent and generic secret patterns
    local -a medium_env=(
        '\$\{?SSH_AUTH_SOCK\}?'
        '\$\{?SSH_AGENT_PID\}?'
        '\$[A-Z_]*TOKEN[A-Z_]*\b|\$[A-Z_]*SECRET[A-Z_]*\b|\$[A-Z_]*PASSWORD[A-Z_]*\b'
    )
    for pat in "${medium_env[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_warning "ENV_ACCESS [MEDIUM]: credential-shaped env var accessed — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done
}

# PERSISTENCE — establishing footholds between sessions
check_persistence_patterns() {
    local findings

    # CRITICAL: launchd persistence (macOS)
    local -a critical_persist=(
        '\blaunchctl\b'
        'LaunchAgent'
        'LaunchDaemon'
        '\blaunchd\b'
    )
    for pat in "${critical_persist[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "PERSISTENCE [CRITICAL]: launchd/LaunchAgent manipulation detected — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done

    # HIGH: shell startup file modification
    local -a high_persist=(
        '\.bashrc|\.zshrc|\.bash_profile|\.zprofile|\.profile'
        '\bcrontab\b'
        'loginitems'
    )
    for pat in "${high_persist[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "PERSISTENCE [HIGH]: shell startup or cron manipulation detected — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done
}

# SUPPLY_CHAIN — runtime package installation
check_supply_chain_patterns() {
    local findings

    # HIGH: runtime package installs (supply chain risk)
    local -a supply_chain=(
        '\bnpm\s+(install|i\b|ci\b)'
        '\bpip[23]?\s+install\b'
        '\bcargo\s+(build|install)\b'
        '\bgo\s+(get|install)\b'
        '\bgem\s+install\b'
        '\byarn\s+add\b'
        '\bbun\s+add\b'
        '\bpnpm\s+(add|install)\b'
        '\bbrew\s+install\b'
    )
    for pat in "${supply_chain[@]}"; do
        if _has_pattern "$pat"; then
            findings=$(_match_lines "$pat" | head -2)
            log_error "SUPPLY_CHAIN [HIGH]: runtime package installation detected — '$pat'"
            printf "    %s\n" "$findings"
        fi
    done
}

# SANDBOX_ESC — bypassing macOS security mechanisms
check_sandbox_escape_patterns() {
    local findings

    # CRITICAL: explicit sandbox disable flag
    if _has_pattern 'dangerouslyDisableSandbox'; then
        findings=$(_match_lines 'dangerouslyDisableSandbox' | head -2)
        log_error "SANDBOX_ESC [CRITICAL]: dangerouslyDisableSandbox detected"
        printf "    %s\n" "$findings"
    fi

    # HIGH: osascript (AppleScript automation — can launch apps, read UI)
    if _has_pattern '\bosascript\b'; then
        findings=$(_match_lines 'osascript' | head -2)
        log_error "SANDBOX_ESC [HIGH]: osascript (AppleScript) detected — can bypass security prompts"
        printf "    %s\n" "$findings"
    fi

    # HIGH: opening applications
    if _has_pattern '\bopen\s+-a\b'; then
        findings=$(_match_lines 'open\s+-a' | head -2)
        log_error "SANDBOX_ESC [HIGH]: 'open -a' (launch application) detected"
        printf "    %s\n" "$findings"
    fi

    # MEDIUM: quarantine attribute removal
    if _has_pattern 'xattr\s+-d\s+com\.apple\.quarantine'; then
        findings=$(_match_lines 'xattr.*quarantine' | head -2)
        log_warning "SANDBOX_ESC [MEDIUM]: quarantine attribute removal detected"
        printf "    %s\n" "$findings"
    fi
}

# SYMLINK — symlink attacks
check_symlink_patterns() {
    local findings

    # MEDIUM: symlink creation in a hook (can redirect sensitive paths)
    if _has_pattern '\bln\s+-s\b|\bln\s+-sf\b'; then
        findings=$(_match_lines '\bln\s+-s' | head -2)
        log_warning "SYMLINK [MEDIUM]: symbolic link creation detected — verify target safety"
        printf "    %s\n" "$findings"
    fi

    if _has_pattern '\bsymlink\b|\breadlink\b'; then
        findings=$(_match_lines '\bsymlink\b|\breadlink\b' | head -2)
        log_warning "SYMLINK [LOW]: symlink/readlink usage — review for redirect attacks"
        printf "    %s\n" "$findings"
    fi
}

# ENCODING_EVASION — Unicode homoglyphs and character-level obfuscation
check_encoding_evasion_patterns() {
    local findings

    # HIGH: non-ASCII bytes — potential Unicode homoglyph substitution
    if LC_ALL=C grep -Pn '[^\x00-\x7F]' "$HOOK_PATH" >/dev/null 2>&1; then
        findings=$(LC_ALL=C grep -Pn '[^\x00-\x7F]' "$HOOK_PATH" | head -5)
        log_error "ENCODING_EVASION [HIGH]: Non-ASCII bytes detected — potential Unicode homoglyph evasion"
        printf "    %s\n" "$findings"
    fi

    # HIGH: dollar-quoted hex escapes ($'\xNN') — potential command obfuscation
    if _has_pattern "\\\$'[^']*\\\\x[0-9a-fA-F]{2}"; then
        findings=$(_match_lines "\\\$'[^']*\\\\x[0-9a-fA-F]{2}" | head -3)
        log_error "ENCODING_EVASION [HIGH]: Dollar-quoted hex escape detected — potential command obfuscation"
        printf "    %s\n" "$findings"
    fi

    # HIGH: dollar-quoted octal escapes ($'\NNN') — potential command obfuscation
    if _has_pattern "\\\$'[^']*\\\\[0-7]{3}"; then
        findings=$(_match_lines "\\\$'[^']*\\\\[0-7]{3}" | head -3)
        log_error "ENCODING_EVASION [HIGH]: Dollar-quoted octal escape detected — potential command obfuscation"
        printf "    %s\n" "$findings"
    fi
}

# --------------------------------------------------------------------------
# Run security checks
# --------------------------------------------------------------------------

log_section "Security: Network"
check_network_patterns

log_section "Security: Dynamic Execution"
check_dynamic_patterns

log_section "Security: Encoding/Obfuscation"
check_encoding_patterns

log_section "Security: Filesystem Escape"
check_fs_escape_patterns

log_section "Security: Credential Env Access"
check_env_access_patterns

log_section "Security: Persistence"
check_persistence_patterns

log_section "Security: Supply Chain"
check_supply_chain_patterns

log_section "Security: Sandbox Escape"
check_sandbox_escape_patterns

log_section "Security: Symlink"
check_symlink_patterns

log_section "Security: Encoding Evasion"
check_encoding_evasion_patterns

# --------------------------------------------------------------------------
# QUALITY / STRUCTURE CHECKS (skipped with --security)
# --------------------------------------------------------------------------

if [[ "$SECURITY_ONLY" != "true" ]]; then
    log_section "Structure & Quality"

    # Shebang check
    if [[ "$FIRST_LINE" =~ ^#! ]]; then
        log_success "Shebang present: $FIRST_LINE"

        if [[ "$FIRST_LINE" =~ ^#!/bin/bash ]] || \
           [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ bash ]] || \
           [[ "$FIRST_LINE" =~ ^#!/bin/sh ]] || \
           [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ sh ]] || \
           [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ python ]] || \
           [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ node ]]; then
            log_success "Valid interpreter in shebang"
        else
            log_warning "Unusual shebang: $FIRST_LINE — verify interpreter exists"
        fi
    else
        if [[ -x "$HOOK_PATH" ]]; then
            log_warning "File is executable but has no shebang — may fail on some systems"
        else
            log_error "File has no shebang and is not executable"
        fi
    fi

    # Executability
    if [[ -x "$HOOK_PATH" ]]; then
        log_success "File is executable"
    else
        log_warning "File is not executable. Run: chmod +x \"$HOOK_PATH\""
    fi

    # Error handling detection
    HAS_ERROR_HANDLING=false

    if grep -q "set -e" "$HOOK_PATH"; then
        log_success "Uses 'set -e' for error handling"
        HAS_ERROR_HANDLING=true
    fi

    if grep -q "set -o errexit" "$HOOK_PATH"; then
        log_success "Uses 'set -o errexit' for error handling"
        HAS_ERROR_HANDLING=true
    fi

    if grep -q "set -o pipefail" "$HOOK_PATH"; then
        log_success "Uses 'set -o pipefail' for pipeline error handling"
    fi

    if grep -qE '\|\|\s*(exit|return|die|error|fatal)' "$HOOK_PATH"; then
        log_info "Has explicit error handling with || exit/return patterns"
        HAS_ERROR_HANDLING=true
    fi

    if grep -qE 'if\s+\[\[.*\]\].*then|if\s+\[.*\].*then' "$HOOK_PATH"; then
        log_info "Has conditional checks"
        HAS_ERROR_HANDLING=true
    fi

    if [[ "$HAS_ERROR_HANDLING" == "false" ]]; then
        log_warning "No explicit error handling found. Consider adding 'set -Eeuo pipefail'."
    fi

    # Variable quoting heuristic
    QUOTED_VARS=$(grep -oE '"\$[a-zA-Z_][a-zA-Z0-9_]*"|\$\{[a-zA-Z_][a-zA-Z0-9_]*\}' "$HOOK_PATH" | wc -l | tr -d ' ')
    UNQUOTED_VARS=$(grep -oE '[^"]\$[a-zA-Z_][a-zA-Z0-9_]*[^"}]' "$HOOK_PATH" 2>/dev/null | wc -l | tr -d ' ')

    if [[ $QUOTED_VARS -gt 0 ]]; then
        log_info "Found $QUOTED_VARS quoted variable references (good practice)"
    fi

    if [[ $UNQUOTED_VARS -gt 5 ]]; then
        log_warning "Found potentially unquoted variables. Consider quoting all variable expansions."
    fi

    # Personal path check
    PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\[a-zA-Z]+' "$HOOK_PATH" 2>/dev/null \
        | grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' \
        | sort -u || true)

    if [[ -n "$PERSONAL_MATCHES" ]]; then
        log_error "Personal/hardcoded path found: $PERSONAL_MATCHES"
    else
        log_success "No hardcoded personal paths found"
    fi

    # Environment variable path usage
    # shellcheck disable=SC2016  # \$ in single quotes is intentional: grep regex for literal dollar sign
    if grep -qE '\$HOME|\$\{HOME\}|\$USER|\$\{USER\}' "$HOOK_PATH"; then
        log_success "Uses environment variables for paths (good practice)"
    fi

    # JSON handling
    if grep -q 'jq' "$HOOK_PATH"; then
        log_info "Script uses jq for JSON processing"
        if grep -qE 'jq\s+-r' "$HOOK_PATH"; then
            log_info "Uses jq -r for raw output"
        fi
    fi

    # Script length
    LINE_COUNT=$(wc -l < "$HOOK_PATH" | tr -d ' ')
    if [[ $LINE_COUNT -gt 200 ]]; then
        log_warning "Script is long ($LINE_COUNT lines). Consider breaking into functions or separate scripts."
    else
        log_info "Script length: $LINE_COUNT lines"
    fi
fi

# --------------------------------------------------------------------------
# Summary and exit
# --------------------------------------------------------------------------

printf "\n==========================================\n"
printf "Validation Summary\n"
printf "==========================================\n"
printf "Errors (critical/high): %d\n" "${#ERRORS[@]}"
printf "Warnings:               %d\n" "${#WARNINGS[@]}"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf "\nFailed checks:\n"
    for error in "${ERRORS[@]}"; do
        printf "  - %s\n" "$error"
    done
    exit 1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf "\n%bHook validation passed with warnings.%b\n" "${YELLOW}" "${NC}"
    exit 2
fi

printf "\n%bHook validation passed!%b\n" "${GREEN}" "${NC}"
exit 0
