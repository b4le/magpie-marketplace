#!/bin/bash
# validate-dig.sh — validate a spelunk directory for a given subject slug
#
# Usage: scripts/validate-dig.sh <archaeology-dir> <subject-slug>
#
# Exit 0: all checks pass
# Exit 1: critical failure — corrupt JSON, missing required files, schema violation
# Exit 2: warnings only — orphaned nuggets, non-fatal structural issues
#
# Bash 3.2 compatible (macOS default)

# --------------------------------------------------------------------------
# Pre-flight: jq required
# --------------------------------------------------------------------------

command -v jq >/dev/null 2>&1 || { printf "validate-dig: jq is required\n"; exit 1; }

# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------

if [ $# -lt 2 ]; then
  printf "Usage: validate-dig.sh <archaeology-dir> <subject-slug>\n"
  exit 1
fi

ARCHAEOLOGY_DIR="$1"
SUBJECT_SLUG="$2"
SPELUNK_DIR="${ARCHAEOLOGY_DIR}/spelunk/${SUBJECT_SLUG}"
NUGGETS_DIR="${SPELUNK_DIR}/nuggets"
CAVERN_MAP="${SPELUNK_DIR}/cavern-map.json"

# --------------------------------------------------------------------------
# Counters
# --------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_CHECKS=11

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

pass() { printf "  [PASS] %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf "  [FAIL] %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { printf "  [WARN] %s\n" "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }

printf "validate-dig: checking %s\n" "${SUBJECT_SLUG}"

# --------------------------------------------------------------------------
# Check 1 — cavern-map.json exists and is valid JSON
# --------------------------------------------------------------------------

if [ ! -f "${CAVERN_MAP}" ]; then
  fail "cavern-map.json not found"
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

if ! jq empty "${CAVERN_MAP}" 2>/dev/null; then
  fail "cavern-map.json is not valid JSON"
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "cavern-map.json valid JSON"

# --------------------------------------------------------------------------
# Check 2 — Required top-level fields + schema_version == "1.0"
# --------------------------------------------------------------------------

REQUIRED_FIELDS="schema_version subject subject_slug project started_at last_modified total_nuggets total_veins root tunnel_nodes decision_log"

check2_failed=0
for field in $REQUIRED_FIELDS; do
  present=$(jq -r --arg f "$field" 'has($f)' "${CAVERN_MAP}" 2>/dev/null)
  if [ "$present" != "true" ]; then
    fail "cavern-map.json missing required field: ${field}"
    check2_failed=1
  fi
done

if [ "$check2_failed" -eq 1 ]; then
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

schema_version=$(jq -r '.schema_version' "${CAVERN_MAP}" 2>/dev/null)
if [ "$schema_version" != "1.0" ]; then
  fail "schema_version is \"${schema_version}\", expected \"1.0\""
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "required top-level fields present"

# --------------------------------------------------------------------------
# Check 3 — Root tunnel node has required fields
# --------------------------------------------------------------------------

ROOT_REQUIRED="id label status children"
check3_failed=0
for field in $ROOT_REQUIRED; do
  present=$(jq -r --arg f "$field" '.root | has($f)' "${CAVERN_MAP}" 2>/dev/null)
  if [ "$present" != "true" ]; then
    fail "root tunnel node missing required field: ${field}"
    check3_failed=1
  fi
done

if [ "$check3_failed" -eq 1 ]; then
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "root tunnel node has required fields"

# --------------------------------------------------------------------------
# Check 4 — All tunnel nodes reachable from root
# --------------------------------------------------------------------------

# Use jq to recursively collect all IDs reachable from root by walking children.
# The walk: start at .root, for each node look up .tunnel_nodes[child_id], recurse.
# We delegate the full traversal to jq via a recursive def.

reachable_ids=$(jq -r '
  def reachable(node):
    node.id,
    (node.children[]? as $cid
     | .tunnel_nodes[$cid] as $child
     | if $child != null then reachable($child) else empty end);
  reachable(.root)
' "${CAVERN_MAP}" 2>/dev/null)

all_node_ids=$(jq -r '.tunnel_nodes | keys[]' "${CAVERN_MAP}" 2>/dev/null)

check4_failed=0
while IFS= read -r node_id; do
  [ -z "$node_id" ] && continue
  found=0
  while IFS= read -r rid; do
    if [ "$rid" = "$node_id" ]; then
      found=1
      break
    fi
  done <<EOF
$reachable_ids
EOF
  if [ "$found" -eq 0 ]; then
    fail "unreachable tunnel node: ${node_id}"
    check4_failed=1
  fi
done <<EOF
$all_node_ids
EOF

if [ "$check4_failed" -eq 1 ]; then
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "all tunnel nodes reachable from root"

# --------------------------------------------------------------------------
# Check 5 — All nugget files referenced in tunnel nodes exist
# --------------------------------------------------------------------------

# Collect nugget_ids from root and all tunnel_nodes
all_nugget_refs=$(jq -r '
  (.root.nugget_ids[]? // empty),
  (.tunnel_nodes | to_entries[] | .value.nugget_ids[]? // empty)
' "${CAVERN_MAP}" 2>/dev/null)

check5_failed=0
while IFS= read -r nugget_ref; do
  [ -z "$nugget_ref" ] && continue
  if [ ! -f "${NUGGETS_DIR}/${nugget_ref}" ]; then
    # Determine which tunnel references this nugget for the error message
    tunnel_id=$(jq -r --arg nid "$nugget_ref" '
      if (.root.nugget_ids[]? == $nid) then .root.id
      else (.tunnel_nodes | to_entries[] | select(.value.nugget_ids[]? == $nid) | .key)
      end
    ' "${CAVERN_MAP}" 2>/dev/null | head -1)
    fail "tunnel ${tunnel_id} references missing nugget: ${nugget_ref}"
    check5_failed=1
  fi
done <<EOF
$all_nugget_refs
EOF

if [ "$check5_failed" -eq 1 ]; then
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "all referenced nugget files exist"

# --------------------------------------------------------------------------
# Check 6 — No orphan nuggets (warning)
# --------------------------------------------------------------------------

if [ -d "${NUGGETS_DIR}" ]; then
  # Build a newline-separated list of all referenced nugget filenames
  referenced_nuggets=$(jq -r '
    (.root.nugget_ids[]? // empty),
    (.tunnel_nodes | to_entries[] | .value.nugget_ids[]? // empty)
  ' "${CAVERN_MAP}" 2>/dev/null)

  # Iterate over .md files in nuggets/
  for nugget_file in "${NUGGETS_DIR}"/*.md; do
    [ -f "$nugget_file" ] || continue
    nugget_basename=$(basename "$nugget_file")
    found=0
    while IFS= read -r ref; do
      if [ "$ref" = "$nugget_basename" ]; then
        found=1
        break
      fi
    done <<EOF
$referenced_nuggets
EOF
    if [ "$found" -eq 0 ]; then
      nugget_stem="${nugget_basename%.md}"
      warn "orphan nugget: ${nugget_stem} not referenced by any tunnel"
    fi
  done
fi

pass "orphan nugget check complete"

# --------------------------------------------------------------------------
# Check 7 — Nugget frontmatter valid
# --------------------------------------------------------------------------

NUGGET_REQUIRED_FIELDS="id subject tunnel_id confidence weight"

check7_failed=0

if [ -d "${NUGGETS_DIR}" ]; then
  for nugget_file in "${NUGGETS_DIR}"/*.md; do
    [ -f "$nugget_file" ] || continue
    nugget_basename=$(basename "$nugget_file")
    nugget_stem="${nugget_basename%.md}"

    # Extract YAML frontmatter between first pair of --- delimiters (awk, bash 3.2 safe)
    frontmatter=$(awk '/^---$/{n++; if(n==1){next} if(n==2){exit}} n==1' "$nugget_file")

    if [ -z "$frontmatter" ]; then
      fail "nugget ${nugget_stem} has no YAML frontmatter"
      check7_failed=1
      continue
    fi

    # Check required fields
    for field in $NUGGET_REQUIRED_FIELDS; do
      if ! printf '%s\n' "$frontmatter" | grep -q "^${field}:"; then
        fail "nugget ${nugget_stem} missing frontmatter field: ${field}"
        check7_failed=1
      fi
    done

    # Check id matches filename
    id_val=$(printf '%s\n' "$frontmatter" | grep "^id:" | sed 's/^id:[[:space:]]*//' | head -1 | sed 's/^["'"'"']//;s/["'"'"']$//')
    if [ -n "$id_val" ] && [ "$id_val" != "$nugget_stem" ]; then
      fail "nugget ${nugget_basename} has mismatched id field: ${id_val}"
      check7_failed=1
    fi
  done
fi

if [ "$check7_failed" -eq 1 ]; then
  printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
  exit 1
fi

pass "nugget frontmatter valid"

# --------------------------------------------------------------------------
# Check 8 — veins.json validation (conditional on nugget count)
# --------------------------------------------------------------------------

VEINS_FILE="${SPELUNK_DIR}/veins.json"

# Count nuggets on disk
nugget_count=0
if [ -d "${NUGGETS_DIR}" ]; then
  for f in "${NUGGETS_DIR}"/*.md; do
    [ -f "$f" ] && nugget_count=$((nugget_count + 1))
  done
fi

if [ "$nugget_count" -lt 5 ]; then
  # veins.json not expected — skip if absent, validate if present
  if [ -f "${VEINS_FILE}" ]; then
    if ! jq empty "${VEINS_FILE}" 2>/dev/null; then
      fail "veins.json is not valid JSON"
      printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
      exit 1
    fi
    pass "veins.json valid JSON (${nugget_count} nuggets, connector optional)"
  else
    pass "veins.json absent — ${nugget_count} nuggets, connector not eligible"
  fi
else
  # nuggets >= 5
  if [ ! -f "${VEINS_FILE}" ]; then
    warn "veins.json missing — ${nugget_count} nuggets exist but no connections have been identified"
    pass "veins.json check complete (absent, warned)"
  else
    if ! jq empty "${VEINS_FILE}" 2>/dev/null; then
      fail "veins.json is not valid JSON"
      printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
      exit 1
    fi
    pass "veins.json valid JSON"
  fi
fi

# --------------------------------------------------------------------------
# Check 9 — Vein references are valid
# --------------------------------------------------------------------------

if [ -f "${VEINS_FILE}" ]; then
  vein_ids=$(jq -r 'keys[]' "${VEINS_FILE}" 2>/dev/null)
  check9_failed=0

  while IFS= read -r vein_id; do
    [ -z "$vein_id" ] && continue
    nugget_a=$(jq -r --arg vid "$vein_id" '.[$vid].nugget_a // empty' "${VEINS_FILE}" 2>/dev/null)
    nugget_b=$(jq -r --arg vid "$vein_id" '.[$vid].nugget_b // empty' "${VEINS_FILE}" 2>/dev/null)

    if [ -n "$nugget_a" ] && [ ! -f "${NUGGETS_DIR}/${nugget_a}.md" ]; then
      fail "vein ${vein_id} references non-existent nugget: ${nugget_a}"
      check9_failed=1
    fi
    if [ -n "$nugget_b" ] && [ ! -f "${NUGGETS_DIR}/${nugget_b}.md" ]; then
      fail "vein ${vein_id} references non-existent nugget: ${nugget_b}"
      check9_failed=1
    fi
  done <<EOF
$vein_ids
EOF

  if [ "$check9_failed" -eq 1 ]; then
    printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
    exit 1
  fi
  pass "vein references valid"
else
  pass "vein reference check skipped — veins.json absent"
fi

# --------------------------------------------------------------------------
# Check 10 — Vein bridge is non-empty
# --------------------------------------------------------------------------

if [ -f "${VEINS_FILE}" ]; then
  vein_ids=$(jq -r 'keys[]' "${VEINS_FILE}" 2>/dev/null)
  check10_failed=0

  while IFS= read -r vein_id; do
    [ -z "$vein_id" ] && continue
    bridge=$(jq -r --arg vid "$vein_id" '.[$vid].bridge // empty' "${VEINS_FILE}" 2>/dev/null)
    if [ -z "$bridge" ]; then
      fail "vein ${vein_id} has empty or missing bridge field"
      check10_failed=1
    fi
  done <<EOF
$vein_ids
EOF

  if [ "$check10_failed" -eq 1 ]; then
    printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"
    exit 1
  fi
  pass "vein bridge fields non-empty"
else
  pass "vein bridge check skipped — veins.json absent"
fi

# --------------------------------------------------------------------------
# Check 11 — trove.md exists if nuggets exist (warning)
# --------------------------------------------------------------------------

TROVE_FILE="${SPELUNK_DIR}/trove.md"

if [ "$nugget_count" -gt 0 ] && [ ! -f "${TROVE_FILE}" ]; then
  warn "trove.md missing — ${nugget_count} nuggets exist but no synthesis has been written"
fi

pass "trove.md check complete"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

printf "Result: %d/%d checks passed, %d warnings\n" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${WARN_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 1
elif [ "${WARN_COUNT}" -gt 0 ]; then
  exit 2
else
  exit 0
fi
