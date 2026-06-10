#!/usr/bin/env bash
# arch-discover.sh — Extract high-frequency terms from conversation history
#                    not covered by existing domains, for domain discovery.
#
# Usage:
#   arch-discover.sh <history-dir> [--registry PATH] [--filter PATH] \
#                    [--top N] [--quiet] [--help]
#
# Arguments:
#   <history-dir>       Directory containing *.jsonl conversation files
#   --registry PATH     Registry YAML file (default: relative to script)
#   --filter PATH       jq filter file for extracting conversation text
#   --top N             Max candidates to output (default: 20)
#   --quiet             Suppress progress output to stderr
#   --help, -h          Print this help and exit
#
# Output:
#   JSON array to stdout, sorted by discovery_score descending:
#   [{"term":"...","total_count":N,"session_spread":N,"discovery_score":N.NN}]
#
# Exit codes:
#   0   Success (including empty directory — outputs [])
#   1   Fatal error (bad args, missing tools, unreadable inputs)
#
# Requires: bash 3.2+, jq (or jaq), awk, tr
# Bash 3.2 compatible (macOS default shell).

set -euo pipefail

# ── Script location ────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

# ── Tool detection ─────────────────────────────────────────────────────

JQ="${JQ:-jaq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"
command -v "$JQ" >/dev/null 2>&1 || {
  printf 'arch-discover: jq or jaq is required\n' >&2
  exit 1
}

command -v awk >/dev/null 2>&1 || {
  printf 'arch-discover: awk is required\n' >&2
  exit 1
}

# ── Defaults ───────────────────────────────────────────────────────────

HISTORY_DIR=""
REGISTRY_PATH="${SCRIPT_DIR}/../skills/archaeology/references/domains/registry.yaml"
FILTER_PATH="${SCRIPT_DIR}/../skills/archaeology/references/jsonl-filter.jq"
TOP_N=20
QUIET=false

# ── Usage ──────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit 0
}

# ── Argument parsing ───────────────────────────────────────────────────

while [ $# -gt 0 ]; do
  case "$1" in
    --registry)
      REGISTRY_PATH="$2"
      shift 2
      ;;
    --filter)
      FILTER_PATH="$2"
      shift 2
      ;;
    --top)
      TOP_N="$2"
      shift 2
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'arch-discover: unknown option: %s\n' "$1" >&2
      printf 'Run with --help for usage.\n' >&2
      exit 1
      ;;
    *)
      if [ -z "$HISTORY_DIR" ]; then
        HISTORY_DIR="$1"
        shift
      else
        printf 'arch-discover: unexpected argument: %s\n' "$1" >&2
        exit 1
      fi
      ;;
  esac
done

# ── Validation ─────────────────────────────────────────────────────────

if [ -z "$HISTORY_DIR" ]; then
  printf 'arch-discover: history directory is required\n' >&2
  printf 'Usage: arch-discover.sh <history-dir> [--registry PATH] [--filter PATH] [--top N] [--quiet]\n' >&2
  exit 1
fi

if [ ! -d "$HISTORY_DIR" ]; then
  printf 'arch-discover: directory not found: %s\n' "$HISTORY_DIR" >&2
  exit 1
fi

if ! printf '%s' "$TOP_N" | grep -qE '^[0-9]+$' || [ "$TOP_N" -lt 1 ]; then
  printf 'arch-discover: --top must be a positive integer, got: %s\n' "$TOP_N" >&2
  exit 1
fi

if [ ! -f "$REGISTRY_PATH" ]; then
  printf 'arch-discover: registry not found: %s\n' "$REGISTRY_PATH" >&2
  exit 1
fi

if [ ! -f "$FILTER_PATH" ]; then
  printf 'arch-discover: jq filter not found: %s\n' "$FILTER_PATH" >&2
  exit 1
fi

# ── Helpers ────────────────────────────────────────────────────────────

# log — print progress to stderr unless --quiet
log() {
  if [ "$QUIET" = false ]; then
    printf 'arch-discover: %s\n' "$1" >&2
  fi
}

# warn — always print warning to stderr
warn() {
  printf 'arch-discover: WARNING: %s\n' "$1" >&2
}

# ── Collect JSONL files ────────────────────────────────────────────────

jsonl_files=""
file_count=0
while IFS= read -r -d '' f; do
  jsonl_files="${jsonl_files}${f}"$'\n'
  file_count=$((file_count + 1))
done < <(find "$HISTORY_DIR" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null)

if [ -z "$jsonl_files" ] || [ "$file_count" -eq 0 ]; then
  log "no .jsonl files found in ${HISTORY_DIR} — outputting empty result"
  printf '[]\n'
  exit 0
fi

log "found ${file_count} session file(s) in ${HISTORY_DIR}"

# ── Step 0: Extract domain keywords from registry + domain .md files ──
#
# Strategy:
#   1. Parse registry.yaml with awk to extract domain file names and inline keywords
#   2. For each domain with a .md file, extract YAML frontmatter keywords.primary
#      and keywords.secondary using awk
#   3. Accumulate all keywords into a single newline-delimited list

DOMAINS_DIR="$(dirname -- "$REGISTRY_PATH")"

# Parse registry.yaml: collect inline keywords and file references.
# awk state machine: track when we're inside a keywords: block and emit values.
domain_keywords_raw=""

domain_keywords_raw="$(awk '
  /^  - id:/ { in_keywords = 0; in_domain = 1 }
  /^    file:/ { if (in_domain) { gsub(/^[ \t]*file:[ \t]*/, ""); gsub(/[ \t]*$/, ""); file = $0 } }
  /^    keywords:/ { if (in_domain) in_keywords = 1 }
  /^    [a-z]/ && !/^    keywords:/ { if (in_domain) in_keywords = 0 }
  /^      - / {
    if (in_keywords) {
      val = $0
      gsub(/^[ \t]*- [ \t]*/, "", val)
      gsub(/[ \t]*$/, "", val)
      if (length(val) >= 3) print val
    }
  }
' "$REGISTRY_PATH" 2>/dev/null || true)"

# For each domain .md file, extract primary and secondary keywords from frontmatter.
# We parse until the closing --- of the frontmatter block.
domain_md_keywords=""

while IFS= read -r md_file; do
  [ -z "$md_file" ] && continue
  full_path="${DOMAINS_DIR}/${md_file}"
  [ -f "$full_path" ] || continue

  # Extract lines between the first and second --- (YAML frontmatter)
  # Then pull values from keywords.primary and keywords.secondary lists
  md_kw="$(awk '
    /^---/ { if (fm_start == 0) { fm_start = 1; next } else { exit } }
    fm_start == 1 {
      if (/^  primary:/ || /^  secondary:/) { in_list = 1; next }
      if (/^  [a-z]/ && !/^  primary:/ && !/^  secondary:/) { in_list = 0 }
      if (in_list && /^    - /) {
        val = $0
        gsub(/^[ \t]*- [ \t]*/, "", val)
        gsub(/[ \t]*$/, "", val)
        if (length(val) >= 3) print val
      }
    }
  ' "$full_path" 2>/dev/null || true)"

  if [ -n "$md_kw" ]; then
    domain_md_keywords="${domain_md_keywords}${md_kw}"$'\n'
  fi
done <<EOF
$(awk '/^    file:/ { gsub(/^[ \t]*file:[ \t]*/, ""); gsub(/[ \t]*$/, ""); print }' "$REGISTRY_PATH" 2>/dev/null || true)
EOF

# Combine all domain keywords: lowercase, 3+ chars, deduplicated
all_domain_keywords="$(
  { printf '%s\n' "$domain_keywords_raw"; printf '%s\n' "$domain_md_keywords"; } \
    | tr 'A-Z' 'a-z' \
    | awk 'length >= 3 && !seen[$0]++' \
    2>/dev/null || true
)"

log "loaded $(printf '%s\n' "$all_domain_keywords" | grep -c . || true) domain keyword(s)"

# ── Step 0: Stopwords, tool names, and meta-terms ──────────────────────

# Built-in Claude Code tool names
TOOL_NAMES="read write edit bash grep glob agent skill webfetch websearch notebookedit taskcreate taskupdate tasklist toolsearch"

# Common English stopwords (100+)
STOPWORDS="the and this that with from for are was were has have had not but all can her his she they them their there then than when who what where how its been will would could should may might must also any about into over after before more most some such only just very even still way get got say said use used make made take took see saw come came give gave find found know knew think thought look looked want wanted need needed feel felt try tried turn turned keep kept let lets leave left show showed tell told ask asked seem seemed much few many same both now here yet again once upon back down your our you you're i'm we're it's don't isn't wasn't doesn't didn't won't can't couldn't wouldn't shouldn't the a an to of in is it be as at by or on do if up out so no he she they we me my you his her its our your their who which had were are was been being have has having will would could should may might must shall do does did doing a an the and or but if while because since although though unless until as when where who what which that than then so yet both either neither each every all some any few more most other such only just very too also quite rather within between among against through during after before above below again further beyond up down"

# Programming language keywords
PROG_KEYWORDS="function class return import export const var let def async await if else while for try catch throw null undefined true false string number boolean object array type interface enum struct void int float double char byte long short uint usize isize new delete this self super static public private protected abstract override readonly final native virtual method module package namespace typedef typename operator template generic where match case switch break continue pass yield from raise except finally with open close begin end until do then elif fi esac done in of at"

# Common Claude Code meta-terms
META_TERMS="file code error output input result response request command tool message content user assistant system prompt context token model task step process run call exec check list path name value key data info log debug test spec config yaml json text block line item note version update add remove create delete change move copy fetch send get set build run make sure need want check look find"

# ── Build combined exclusion set ───────────────────────────────────────

all_exclude_terms="$(
  {
    printf '%s\n' $TOOL_NAMES
    printf '%s\n' $STOPWORDS
    printf '%s\n' $PROG_KEYWORDS
    printf '%s\n' $META_TERMS
    printf '%s\n' "$all_domain_keywords"
  } \
    | tr 'A-Z' 'a-z' \
    | awk 'length >= 3 && !seen[$0]++' \
    2>/dev/null || true
)"

# Write exclusion terms to a temp file for awk lookup (faster than inline)
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR_WORK"' EXIT

exclude_file="${TMPDIR_WORK}/exclude.txt"
printf '%s\n' "$all_exclude_terms" > "$exclude_file"

log "built exclusion list: $(wc -l < "$exclude_file" | tr -d ' ') terms"

# ── Step 0: Corpus extraction and term counting ────────────────────────
#
# Single awk pass over all files:
#   - Applies jq filter to extract conversation text
#   - Tokenizes: lowercase, 3+ char alphanum/underscore/hyphen tokens
#   - Per-file term cap of 8 (prevents single-session dominance)
#   - Outputs: term <TAB> file_index for aggregation

log "extracting terms from ${file_count} session file(s)..."

raw_counts_file="${TMPDIR_WORK}/raw_counts.tsv"
# Format: term TAB total_count TAB files_containing_term

# Process all files, collect per-file term lists, then aggregate with awk
terms_file="${TMPDIR_WORK}/terms.tsv"
# Format per line: file_index TAB term

file_index=0
while IFS= read -r jsonl_path; do
  [ -z "$jsonl_path" ] && continue
  file_index=$((file_index + 1))

  # Extract conversation text through jq filter, tokenize, apply per-file cap
  "$JQ" -r -f "$FILTER_PATH" "$jsonl_path" 2>/dev/null \
    | tr -cs 'a-zA-Z0-9_-' '\n' \
    | tr 'A-Z' 'a-z' \
    | awk -v fi="$file_index" 'length >= 3 {
        count[$0]++
        if (count[$0] == 1) order[++n] = $0
      }
      END {
        for (i = 1; i <= n; i++) {
          t = order[i]
          c = (count[t] > 8) ? 8 : count[t]
          # Emit one line per occurrence (up to cap) so aggregator can sum
          for (j = 1; j <= c; j++) {
            print fi "\t" t
          }
        }
      }' >> "$terms_file"

done <<EOF
$jsonl_files
EOF

log "tokenization complete — aggregating counts..."

# ── Steps 1–3 + 4: Aggregate counts, filter, score ────────────────────
#
# Single awk pass:
#   - Loads exclusion set
#   - Loads terms.tsv: aggregate total_count and session_spread per term
#   - Applies minimum frequency (>= 3) filter
#   - Applies domain/stopword exclusion (substring match in both directions)
#   - Computes TF-IDF discovery_score
#   - Outputs top N as JSON

awk -v top_n="$TOP_N" -v total_files="$file_count" \
    -v exclude_file="$exclude_file" \
    -v terms_file="$terms_file" \
'BEGIN {
  # Load exclusion set
  while ((getline line < exclude_file) > 0) {
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    if (length(line) >= 3) {
      excl[line] = 1
    }
  }
  close(exclude_file)

  # Pass 1: aggregate term counts and file spread from terms.tsv
  total_term_count = 0
  while ((getline line < terms_file) > 0) {
    # line format: file_index TAB term
    n = split(line, parts, "\t")
    if (n < 2) continue
    fi   = parts[1]
    term = parts[2]
    if (length(term) < 3) continue

    corpus_count[term]++
    total_term_count++

    # Track unique files per term
    key = term SUBSEP fi
    if (!file_seen[key]) {
      file_seen[key] = 1
      file_spread[term]++
    }
  }
  close(terms_file)

  # Pass 2: filter and score
  # Build candidate list (term, total_count, session_spread, score)
  cand_n = 0

  for (term in corpus_count) {
    tc = corpus_count[term]
    spread = file_spread[term]

    # Step 1: minimum frequency
    if (tc < 3) continue

    # Step 2: domain overlap filter — exact match and substring match (both directions)
    skip = 0
    if (term in excl) {
      skip = 1
    } else {
      # Check if term contains any exclusion keyword as a substring
      for (kw in excl) {
        if (length(kw) >= 3) {
          if (index(term, kw) > 0 || index(kw, term) > 0) {
            skip = 1
            break
          }
        }
      }
    }
    if (skip) continue

    # Step 4: TF-IDF-like discovery_score
    # tf  = term_count / total_terms_in_corpus
    # idf = log(total_files / files_containing_term)   [natural log via awk log()]
    # score = tf * idf * 1000, rounded to 2dp
    if (total_term_count == 0 || spread == 0) continue

    tf  = tc / total_term_count
    idf = log(total_files / spread)
    if (idf <= 0) continue    # term appears in every file — no discriminative power

    raw_score = tf * idf * 1000
    # Round to 2 decimal places
    score = int(raw_score * 100 + 0.5) / 100

    cand_n++
    cand_term[cand_n]   = term
    cand_count[cand_n]  = tc
    cand_spread[cand_n] = spread
    cand_score[cand_n]  = score
  }

  # Sort candidates by score descending (simple insertion sort — N is small post-filter)
  for (i = 2; i <= cand_n; i++) {
    t  = cand_term[i]
    tc = cand_count[i]
    sp = cand_spread[i]
    sc = cand_score[i]
    j  = i - 1
    while (j >= 1 && cand_score[j] < sc) {
      cand_term[j+1]   = cand_term[j]
      cand_count[j+1]  = cand_count[j]
      cand_spread[j+1] = cand_spread[j]
      cand_score[j+1]  = cand_score[j]
      j--
    }
    cand_term[j+1]   = t
    cand_count[j+1]  = tc
    cand_spread[j+1] = sp
    cand_score[j+1]  = sc
  }

  # Emit top N as JSON array
  limit = (cand_n < top_n) ? cand_n : top_n
  printf "[\n"
  for (i = 1; i <= limit; i++) {
    comma = (i < limit) ? "," : ""
    # JSON-escape the term (replace backslash and double-quote)
    t = cand_term[i]
    gsub(/\\/, "\\\\", t)
    gsub(/"/, "\\\"", t)
    printf "  {\"term\":\"%s\",\"total_count\":%d,\"session_spread\":%d,\"discovery_score\":%.2f}%s\n",
      t, cand_count[i], cand_spread[i], cand_score[i], comma
  }
  printf "]\n"
}
'
