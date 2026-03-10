#!/bin/bash
# arch-profile.sh — profile a project directory for languages, frameworks, and session history
#
# Usage:
#   arch-profile.sh <project-dir> [history-dir] [--json] [--quiet] [--help]
#
# Arguments:
#   project-dir   Path to the project directory to profile (required)
#   history-dir   Path to the Claude session history directory (optional)
#                 When provided, adds session_count and history_depth_months to output
#
# Options:
#   --json        Output JSON (default)
#   --quiet       Suppress progress messages on stderr
#   --help        Show this help and exit
#
# Output (stdout):
#   JSON object with keys: project_dir, languages, frameworks,
#   session_count (if history-dir provided), history_depth_months (if history-dir provided),
#   profiled_at
#
# Exit codes:
#   0  success
#   1  fatal error (missing project-dir, unreadable directory, jq unavailable)
#
# Requires: jq (or jaq), find, stat, date
# Bash 3.2 compatible (macOS default)

# --------------------------------------------------------------------------
# jq / jaq setup
# --------------------------------------------------------------------------

JQ="${JQ:-jaq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"
command -v "$JQ" >/dev/null 2>&1 || {
  printf "arch-profile: jq or jaq is required\n" >&2
  exit 1
}

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------

PROJECT_DIR=""
HISTORY_DIR=""
OUTPUT_JSON=1
QUIET=0

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      printf "arch-profile.sh — profile a project directory for languages, frameworks, and session history\n\n" >&2
      printf "Usage:\n  arch-profile.sh <project-dir> [history-dir] [--json] [--quiet] [--help]\n\n" >&2
      printf "Arguments:\n" >&2
      printf "  project-dir   Path to the project directory to profile (required)\n" >&2
      printf "  history-dir   Path to the Claude session history directory (optional)\n" >&2
      printf "                Adds session_count and history_depth_months to output\n\n" >&2
      printf "Options:\n" >&2
      printf "  --json        Output JSON (default)\n" >&2
      printf "  --quiet       Suppress progress messages on stderr\n" >&2
      printf "  --help        Show this help and exit\n\n" >&2
      printf "Output (stdout): JSON with project_dir, languages, frameworks, profiled_at\n" >&2
      printf "  + session_count and history_depth_months when history-dir is provided\n\n" >&2
      printf "Exit codes: 0 success, 1 fatal error\n" >&2
      exit 0
      ;;
    --json)
      OUTPUT_JSON=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf "arch-profile: unknown option: %s\n" "$1" >&2
      exit 1
      ;;
    *)
      if [ -z "$PROJECT_DIR" ]; then
        PROJECT_DIR="$1"
      elif [ -z "$HISTORY_DIR" ]; then
        HISTORY_DIR="$1"
      else
        printf "arch-profile: unexpected argument: %s\n" "$1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

if [ -z "$PROJECT_DIR" ]; then
  printf "arch-profile: project directory is required\n" >&2
  printf "Usage: arch-profile.sh <project-dir> [history-dir] [--quiet]\n" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  printf "arch-profile: project directory not found: %s\n" "$PROJECT_DIR" >&2
  exit 1
fi

if [ ! -r "$PROJECT_DIR" ]; then
  printf "arch-profile: project directory not readable: %s\n" "$PROJECT_DIR" >&2
  exit 1
fi

if [ -n "$HISTORY_DIR" ] && [ ! -d "$HISTORY_DIR" ]; then
  printf "arch-profile: history directory not found: %s\n" "$HISTORY_DIR" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# log — print progress to stderr (suppressed by --quiet)
log() {
  [ "$QUIET" -eq 1 ] && return 0
  printf "arch-profile: %s\n" "$1" >&2
}

# warn — always print to stderr
warn() {
  printf "arch-profile: WARNING: %s\n" "$1" >&2
}

# ext_to_lang — map a file extension to a language name
# Prints the language name, or empty string if unknown
ext_to_lang() {
  local ext="$1"
  case "$ext" in
    js|jsx|mjs)          printf 'JavaScript' ;;
    ts|tsx)              printf 'TypeScript' ;;
    py)                  printf 'Python' ;;
    rb)                  printf 'Ruby' ;;
    go)                  printf 'Go' ;;
    rs)                  printf 'Rust' ;;
    java)                printf 'Java' ;;
    kt)                  printf 'Kotlin' ;;
    swift)               printf 'Swift' ;;
    c|h)                 printf 'C' ;;
    cpp|hpp)             printf 'C++' ;;
    cs)                  printf 'C#' ;;
    php)                 printf 'PHP' ;;
    sh|bash|zsh)         printf 'Shell' ;;
    sql)                 printf 'SQL' ;;
    r)                   printf 'R' ;;
    scala)               printf 'Scala' ;;
    ex|exs)              printf 'Elixir' ;;
    hs)                  printf 'Haskell' ;;
    lua)                 printf 'Lua' ;;
    dart)                printf 'Dart' ;;
    yml|yaml)            printf 'YAML' ;;
    md)                  printf 'Markdown' ;;
    html|htm)            printf 'HTML' ;;
    css|scss|sass|less)  printf 'CSS' ;;
    *)                   printf '' ;;
  esac
}

# --------------------------------------------------------------------------
# Language detection
# --------------------------------------------------------------------------

log "detecting languages in: $PROJECT_DIR"

# Collect extension counts using find with depth limit.
# Excludes: node_modules, .git, .venv, vendor, dist, build
# Output format per line: "<count> <extension>"
#
# Strategy: find all files, extract extensions via sed, sort+count.
# We use a temp file to accumulate lang:count pairs as "lang<TAB>count" lines,
# then aggregate in a second pass.

ext_counts_tmp=$(mktemp /tmp/arch-profile-ext.XXXXXX)
lang_pairs_tmp=$(mktemp /tmp/arch-profile-lang.XXXXXX)

# Cleanup on exit
trap 'rm -f -- "$ext_counts_tmp" "$lang_pairs_tmp"' EXIT

find "$PROJECT_DIR" \
  -maxdepth 5 \
  -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/.venv/*" \
  ! -path "*/vendor/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  -print 2>/dev/null \
| while IFS= read -r filepath; do
    # Extract extension: everything after the last dot in the filename
    base=$(basename -- "$filepath")
    case "$base" in
      *.*)
        ext="${base##*.}"
        # Lowercase the extension for consistent matching
        ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
        lang=$(ext_to_lang "$ext")
        if [ -n "$lang" ]; then
          printf '%s\n' "$lang"
        fi
        ;;
    esac
  done | sort | uniq -c | sort -rn > "$ext_counts_tmp"

# ext_counts_tmp now contains lines like: "  145 TypeScript"
# Build total file count for percentage calculation
total_lang_files=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  count=$(printf '%s' "$line" | awk '{print $1}')
  total_lang_files=$((total_lang_files + count))
done < "$ext_counts_tmp"

log "found $total_lang_files language-mapped source files"

# Build JSON array of top-5 languages
# Each entry: {"name": "TypeScript", "file_count": 145, "percentage": 42.3}
languages_json="[]"
if [ -s "$ext_counts_tmp" ] && [ "$total_lang_files" -gt 0 ]; then
  lang_entries=""
  lang_rank=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$lang_rank" -ge 5 ] && break
    count=$(printf '%s' "$line" | awk '{print $1}')
    lang=$(printf '%s' "$line" | awk '{$1=""; sub(/^ /, ""); print}')
    # Calculate percentage with one decimal place using awk
    pct=$(awk "BEGIN { printf \"%.1f\", ($count / $total_lang_files) * 100 }")
    entry=$(
      "$JQ" -n \
        --arg name "$lang" \
        --argjson file_count "$count" \
        --argjson percentage "$pct" \
        '{"name": $name, "file_count": $file_count, "percentage": $percentage}'
    )
    if [ -z "$lang_entries" ]; then
      lang_entries="$entry"
    else
      lang_entries="${lang_entries}
${entry}"
    fi
    lang_rank=$((lang_rank + 1))
  done < "$ext_counts_tmp"

  if [ -n "$lang_entries" ]; then
    languages_json=$(printf '%s\n' "$lang_entries" | "$JQ" -s '.')
  fi
fi

# --------------------------------------------------------------------------
# Framework detection
# --------------------------------------------------------------------------

log "detecting frameworks in: $PROJECT_DIR"

# Check for indicator files/dirs in the project root.
# Format: "<indicator_path>|<framework_name>"
# Indicators with a trailing * are checked with glob presence via find.
FRAMEWORK_CHECKS="
package.json|Node.js
tsconfig.json|TypeScript
next.config.js|Next.js
next.config.mjs|Next.js
next.config.ts|Next.js
vite.config.ts|Vite
vite.config.js|Vite
webpack.config.js|Webpack
requirements.txt|Python/pip
setup.py|Python/setuptools
pyproject.toml|Python
Cargo.toml|Rust/Cargo
go.mod|Go Modules
Gemfile|Ruby/Bundler
pom.xml|Java/Maven
build.gradle|Java/Gradle
docker-compose.yml|Docker Compose
Dockerfile|Docker
.github/workflows|GitHub Actions
Makefile|Make
CMakeLists.txt|CMake
flutter.yaml|Flutter
pubspec.yaml|Flutter/Dart
"

detected_frameworks=""

while IFS='|' read -r indicator framework; do
  # Strip whitespace from blank lines in the heredoc
  indicator=$(printf '%s' "$indicator" | tr -d ' \t')
  framework=$(printf '%s' "$framework" | tr -d ' \t')
  [ -z "$indicator" ] && continue

  target="${PROJECT_DIR}/${indicator}"

  if [ -e "$target" ]; then
    # Deduplicate: only add if not already in the list
    case "$detected_frameworks" in
      *"|${framework}|"*) ;;  # already present
      *)
        if [ -z "$detected_frameworks" ]; then
          detected_frameworks="${framework}"
        else
          detected_frameworks="${detected_frameworks}
${framework}"
        fi
        ;;
    esac
  fi
done <<EOF
$FRAMEWORK_CHECKS
EOF

# Build deduplicated JSON array of framework names
if [ -z "$detected_frameworks" ]; then
  frameworks_json="[]"
else
  frameworks_json=$(printf '%s\n' "$detected_frameworks" | "$JQ" -R '.' | "$JQ" -s 'unique')
fi

log "detected frameworks: $(printf '%s' "$detected_frameworks" | tr '\n' ',' | sed 's/,$//')"

# --------------------------------------------------------------------------
# Session history metadata (optional)
# --------------------------------------------------------------------------

session_count_json="null"
history_depth_json="null"

if [ -n "$HISTORY_DIR" ] && [ -d "$HISTORY_DIR" ]; then
  log "reading session history from: $HISTORY_DIR"

  # Count .jsonl files
  session_count=0
  earliest_mtime=""
  latest_mtime=""

  while IFS= read -r jsonl_file; do
    [ -z "$jsonl_file" ] && continue
    session_count=$((session_count + 1))

    # Get mtime as unix timestamp (portable: macOS stat -f %m, GNU stat -c %Y)
    if stat --version >/dev/null 2>&1; then
      # GNU stat
      mtime=$(stat -c '%Y' -- "$jsonl_file" 2>/dev/null) || continue
    else
      # BSD/macOS stat
      mtime=$(stat -f '%m' -- "$jsonl_file" 2>/dev/null) || continue
    fi

    if [ -z "$earliest_mtime" ]; then
      earliest_mtime="$mtime"
      latest_mtime="$mtime"
    else
      if [ "$mtime" -lt "$earliest_mtime" ]; then
        earliest_mtime="$mtime"
      fi
      if [ "$mtime" -gt "$latest_mtime" ]; then
        latest_mtime="$mtime"
      fi
    fi
  done <<EOF2
$(find "$HISTORY_DIR" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null)
EOF2

  session_count_json="$session_count"

  if [ "$session_count" -gt 0 ] && [ -n "$earliest_mtime" ] && [ -n "$latest_mtime" ]; then
    # Calculate history depth in months (float, one decimal)
    # depth_seconds = latest_mtime - earliest_mtime
    # depth_months  = depth_seconds / (30.44 * 86400)
    history_depth_json=$(awk "BEGIN { printf \"%.1f\", ($latest_mtime - $earliest_mtime) / (30.44 * 86400) }")
  else
    history_depth_json="0.0"
  fi

  log "found $session_count session file(s)"
fi

# --------------------------------------------------------------------------
# Assemble final JSON output
# --------------------------------------------------------------------------

profiled_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

# Resolve project_dir to absolute path
if command -v realpath >/dev/null 2>&1; then
  abs_project_dir=$(realpath -- "$PROJECT_DIR" 2>/dev/null || printf '%s' "$PROJECT_DIR")
else
  # Fallback for macOS without realpath (use pwd -P approach)
  abs_project_dir=$(cd -- "$PROJECT_DIR" && pwd -P)
fi

# Build the output object, conditionally including session fields
if [ "$session_count_json" = "null" ]; then
  "$JQ" -n \
    --arg project_dir "$abs_project_dir" \
    --argjson languages "$languages_json" \
    --argjson frameworks "$frameworks_json" \
    --arg profiled_at "$profiled_at" \
    '{
      project_dir:  $project_dir,
      languages:    $languages,
      frameworks:   $frameworks,
      profiled_at:  $profiled_at
    }'
else
  "$JQ" -n \
    --arg project_dir "$abs_project_dir" \
    --argjson languages "$languages_json" \
    --argjson frameworks "$frameworks_json" \
    --argjson session_count "$session_count_json" \
    --argjson history_depth_months "$history_depth_json" \
    --arg profiled_at "$profiled_at" \
    '{
      project_dir:          $project_dir,
      languages:            $languages,
      frameworks:           $frameworks,
      session_count:        $session_count,
      history_depth_months: $history_depth_months,
      profiled_at:          $profiled_at
    }'
fi
