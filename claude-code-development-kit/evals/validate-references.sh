#!/bin/bash
# validate-references.sh - Validates @path references in SKILL.md files
#
# Scans SKILL.md files for @reference/, @templates/, @examples/, and similar
# @path imports. Resolves each reference relative to the skill's directory,
# reports broken references in file:line format, and exits non-zero if any
# references are unresolvable.
#
# Usage:
#   ./validate-references.sh [--help] [--verbose] [directory]
#
# Exit codes:
#   0 - All references resolved (or no references found)
#   1 - One or more references could not be resolved
#
# Performance note: the hot path is a single bulk awk pass across all SKILL.md
# files. awk strips fenced code blocks, extracts @scope/path tokens, filters
# npm scoped packages and unknown prefixes, and emits TSV rows. Bash then
# resolves each row with one [-e] test — no per-line subshell forks.

# Do not use set -e here; we handle errors explicitly and need safe counter
# arithmetic (((n++)) returns 1 when n was 0, which would abort with set -e).

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TOTAL_REFS=0
RESOLVED=0
BROKEN=0

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
VERBOSE=false
SCAN_DIR=""

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
validate-references.sh - Validates @path references in SKILL.md files

USAGE:
    ./validate-references.sh                  # Scan all SKILL.md files under skills/
    ./validate-references.sh <directory>      # Scan SKILL.md files under <directory>
    ./validate-references.sh --verbose        # Show passing references as well
    ./validate-references.sh --help           # Show this help

DESCRIPTION:
    Finds all @path references in SKILL.md files. A reference is any token of
    the form:

        @category/path/to/file.md

    where the token appears outside a fenced code block (``` ... ```) and is
    not an npm-scoped package (e.g. @testing-library/react, @types/node).

    Valid reference prefixes checked:
        @reference/   @templates/   @examples/   @guides/
        @skills/      @sources/     @docs/

    For each reference the script resolves the path relative to the SKILL.md
    file's directory. References beginning with @skills/ are resolved relative
    to the plugin root's skills/ directory.

REFERENCE FORMATS:
    Standard (relative to the SKILL.md's directory):
        @reference/troubleshooting.md
        @templates/command-template.md
        @examples/api-documentation-skill.md

    Plugin-root-relative:
        @skills/resolving-claude-code-issues/reference/tool-issues.md

OUTPUT FORMAT:
    Broken references are reported as:
        path/to/SKILL.md:42: [BROKEN] @reference/missing.md

EXIT CODES:
    0 - All references resolve, or no references found
    1 - One or more references are broken

EXAMPLES:
    ./validate-references.sh
    ./validate-references.sh skills/creating-commands
    ./validate-references.sh --verbose skills/authoring-skills
EOF
}

# ---------------------------------------------------------------------------
# find_skill_files <directory>
#
# Prints absolute paths to all SKILL.md files under the given directory.
# ---------------------------------------------------------------------------
find_skill_files() {
    local dir="$1"
    find "$dir" -name "SKILL.md" -type f 2>/dev/null | sort
}

# ---------------------------------------------------------------------------
# extract_refs <plugin_root> <skill_file> [<skill_file> ...]
#
# Bulk awk pass across all SKILL.md files. For each qualifying @scope/path
# token found outside a fenced code block, emits a tab-separated row:
#
#   <file> TAB <line> TAB <scope> TAB <rest>
#
# where <rest> is everything after the first slash (the path component after
# the scope). The caller resolves the full filesystem path.
#
# Filtering done entirely in awk (no subshell per token):
#   - Fenced code block stripping (``` and ~~~ styles)
#   - Extract all @scope/path tokens per line with gsub+match loop
#   - Strip trailing punctuation (.,;:)> up to two passes)
#   - Drop tokens whose scope contains a hyphen (npm convention)
#   - Drop tokens not in the 7 known skill prefixes
# ---------------------------------------------------------------------------
extract_refs() {
    # $@ is the list of SKILL.md files; awk receives them as ARGV.
    awk '
    BEGIN {
        # Known skill reference prefixes (all single-word, no hyphens)
        known["reference"] = 1
        known["templates"] = 1
        known["examples"]  = 1
        known["guides"]    = 1
        known["skills"]    = 1
        known["sources"]   = 1
        known["docs"]      = 1

        in_block = 0
        FS = "\t"
    }

    # Track which file we are processing and reset block state per file.
    FNR == 1 { in_block = 0 }

    # Toggle fenced code block state; suppress lines inside a block.
    /^```/ { in_block = !in_block; next }
    /^~~~/ { in_block = !in_block; next }
    in_block { next }

    # For every non-block line, find all @scope/path tokens.
    {
        line = $0
        # Work through the line consuming each @token we find.
        while (match(line, /@[a-zA-Z][a-zA-Z0-9_-]*\/[a-zA-Z0-9_.\/\-]*/)) {
            token = substr(line, RSTART, RLENGTH)

            # Advance past this match so we do not re-process it.
            line = substr(line, RSTART + RLENGTH)

            # Strip trailing punctuation (two passes to catch e.g. ").")
            sub(/[.,;:)>]$/, "", token)
            sub(/[.,;:)>]$/, "", token)

            # Remove leading @
            ref = substr(token, 2)

            # Split into scope and rest at first slash
            slash = index(ref, "/")
            if (slash == 0) continue
            scope = substr(ref, 1, slash - 1)
            rest  = substr(ref, slash + 1)

            # Drop npm scoped packages: scope contains a hyphen
            if (index(scope, "-") > 0) continue

            # Drop unknown prefixes
            if (!(scope in known)) continue

            # Emit TSV row: file, line number, scope, rest-of-path
            print FILENAME "\t" FNR "\t" scope "\t" rest
        }
    }
    ' "$@"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
        *)
            SCAN_DIR="$1"
            shift
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve scan directory and plugin root
# ---------------------------------------------------------------------------

# Determine the script's own directory so we can locate the plugin root even
# when the script is invoked from a different working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The plugin root is the parent of the evals/ directory.
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default scan target: the skills/ directory under the plugin root.
if [[ -z "$SCAN_DIR" ]]; then
    SCAN_DIR="${PLUGIN_ROOT}/skills"
fi

# Resolve to absolute path if relative
if [[ ! "$SCAN_DIR" = /* ]]; then
    SCAN_DIR="$(pwd)/${SCAN_DIR}"
fi

if [[ ! -d "$SCAN_DIR" ]]; then
    echo -e "${RED}[ERROR]${NC} Directory not found: ${SCAN_DIR}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=========================================="
echo "SKILL.md Reference Validation"
echo "=========================================="
echo "Scan directory : ${SCAN_DIR}"
echo "Plugin root    : ${PLUGIN_ROOT}"
if [[ "$VERBOSE" == "true" ]]; then
    echo "Mode           : verbose"
fi
echo ""

# Collect SKILL.md files
SKILL_FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && SKILL_FILES+=("$f")
done < <(find_skill_files "$SCAN_DIR")

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}[WARN]${NC} No SKILL.md files found under ${SCAN_DIR}"
    exit 0
fi

echo "Found ${#SKILL_FILES[@]} SKILL.md file(s)"

# ---------------------------------------------------------------------------
# Bulk extraction: one awk pass across all files produces TSV rows.
# Then resolve paths and report in a single bash read loop — no subshells.
# ---------------------------------------------------------------------------

# Track the last file we announced a header for (used in both modes).
last_announced_file=""

if [[ "$VERBOSE" == "true" ]]; then
    echo ""
fi

while IFS=$'\t' read -r skill_file line_num scope rest; do
    TOTAL_REFS=$((TOTAL_REFS + 1))

    # Reconstruct the original @token for display
    ref="@${scope}/${rest}"

    # Resolve the filesystem path:
    #   @skills/... -> <plugin_root>/skills/<rest>
    #   anything else -> <skill_dir>/<scope>/<rest>
    skill_dir="$(dirname "$skill_file")"
    if [[ "$scope" == "skills" ]]; then
        resolved_path="${PLUGIN_ROOT}/skills/${rest}"
    else
        resolved_path="${skill_dir}/${scope}/${rest}"
    fi

    if [[ -e "$resolved_path" ]]; then
        RESOLVED=$((RESOLVED + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            # Print "Scanning: <file>" header once per file
            if [[ "$skill_file" != "$last_announced_file" ]]; then
                echo ""
                echo -e "${BLUE}Scanning:${NC} ${skill_file}"
                last_announced_file="$skill_file"
            fi
            echo -e "  ${GREEN}[OK]${NC}   ${skill_file}:${line_num}: ${ref} -> ${resolved_path}"
        fi
    else
        BROKEN=$((BROKEN + 1))
        # Print file header once per file in both modes
        if [[ "$skill_file" != "$last_announced_file" ]]; then
            echo ""
            echo -e "${BLUE}${skill_file}${NC}"
            last_announced_file="$skill_file"
        fi
        echo -e "  ${RED}[BROKEN]${NC} ${skill_file}:${line_num}: ${ref}"
        echo -e "          -> ${resolved_path}"
    fi

done < <(extract_refs "${SKILL_FILES[@]}")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "  SKILL.md files scanned : ${#SKILL_FILES[@]}"
echo "  Total @path references : ${TOTAL_REFS}"
echo "  Resolved               : ${RESOLVED}"
echo "  Broken                 : ${BROKEN}"
echo ""

if [[ $BROKEN -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED${NC} - ${BROKEN} broken reference(s) found"
    exit 1
else
    echo -e "${GREEN}VALIDATION PASSED${NC} - All ${TOTAL_REFS} reference(s) resolved"
    exit 0
fi
