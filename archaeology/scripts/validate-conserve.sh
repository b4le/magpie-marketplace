#!/usr/bin/env bash
# validate-conserve.sh — Structural validation for /archaeology conserve output
#
# Usage: bash scripts/validate-conserve.sh [path-to-archaeology-dir]
# Default: .claude/archaeology relative to current directory
#
# Phase 1 (pure bash): frontmatter fields, sources.sessions structure, enum values,
#                       ID-filename match, URI format, exhibition link integrity (forward + reverse)
# Phase 2 (jq):        index count parity, _exhibition.json cross-check, orphan check
#
# Exit: 0 = all pass, 1 = any failures
#
# Bash 3.2 compatible (macOS default)

set -euo pipefail
shopt -s nullglob

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

ARCH_DIR="${1:-${PWD}/.claude/archaeology}"
ARTIFACTS_DIR="${ARCH_DIR}/artifacts"

PASS=0
FAIL=0

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s — %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
}

# Extract a scalar value from YAML frontmatter.
# Usage: extract_field <frontmatter_text> <field_name>
# Prints the trimmed value, or empty string if not found.
extract_field() {
  local fm="$1"
  local field="$2"
  local val
  val=$(printf '%s\n' "$fm" | grep "^${field}:" | sed "s/^${field}:[[:space:]]*//" | head -1)
  # Strip surrounding quotes (single or double) — YAML allows both
  printf '%s' "$val" | sed 's/^["'"'"']//;s/["'"'"']$//'
}

# --------------------------------------------------------------------------
# Pre-flight: verify archaeology dir exists
# --------------------------------------------------------------------------

if [ ! -d "$ARCH_DIR" ]; then
  printf 'FAIL: archaeology directory not found — %s\n' "$ARCH_DIR"
  printf '\nvalidate-conserve: 0 passed, 1 failed\n'
  exit 1
fi

if [ ! -d "$ARTIFACTS_DIR" ]; then
  printf 'FAIL: artifacts/ directory not found — %s\n' "$ARTIFACTS_DIR"
  printf '\nvalidate-conserve: 0 passed, 1 failed\n'
  exit 1
fi

# --------------------------------------------------------------------------
# Phase 1: Pure bash checks
# --------------------------------------------------------------------------

printf '=== Phase 1: Structure (pure bash) ===\n\n'

# Collect artifact files
artifact_files=("${ARTIFACTS_DIR}"/art-*.md)

# Bug 1 fix: record failure but do NOT early-exit — let remaining checks run
# against an empty set (count parity against 0 is meaningful; Check 8 will
# simply have nothing to iterate).
if [ "${#artifact_files[@]}" -eq 0 ]; then
  fail "artifact files present" "no art-NNN.md files found in ${ARTIFACTS_DIR}"
fi

# ------------------------------------------------------------------
# Check 1-4: Per-artifact frontmatter validation
# ------------------------------------------------------------------

REQUIRED_FIELDS="id project uri type title confidence significance tags conserved_at session_date status revised"

for artifact_file in "${artifact_files[@]}"; do
  filename=$(basename "$artifact_file")
  stem="${filename%.md}"           # e.g. art-003
  label="artifact ${stem}"

  # Bug 4 fix: extract YAML frontmatter between FIRST pair of --- markers only.
  # The old sed '/^---$/,/^---$/' pattern re-triggered on body horizontal rules.
  # This awk counts occurrences of ^---$ and exits after the second, so body
  # rules are never matched. POSIX/bash-3.2 safe.
  frontmatter=$(awk '/^---$/{n++; if(n==1){next} if(n==2){exit}} n==1' "$artifact_file")

  if [ -z "$frontmatter" ]; then
    fail "${label}: frontmatter" "no YAML frontmatter found"
    continue
  fi

  # Check 1: Required fields
  missing_fields=""
  # shellcheck disable=SC2086  # intentional word-split on space-separated constant
  for field in $REQUIRED_FIELDS; do
    if ! printf '%s\n' "$frontmatter" | grep -q "^${field}:"; then
      missing_fields="${missing_fields} ${field}"
    fi
  done

  if [ -n "$missing_fields" ]; then
    fail "${label}: required fields" "missing:${missing_fields}"
  else
    pass "${label}: required fields present"
  fi

  # Check 1b: sources.sessions nested structure
  # The schema requires:
  #   sources:
  #     sessions:
  #       - file: "..."
  # We do pragmatic line-pattern matching (no full YAML parser).
  # Bash 3.2: use [ ] not [[ ]], printf not echo.
  sources_key=""
  sessions_key=""
  sessions_item=""

  if printf '%s\n' "$frontmatter" | grep -q "^sources:"; then
    sources_key="present"
  fi

  if printf '%s\n' "$frontmatter" | grep -q "^  sessions:"; then
    sessions_key="present"
  fi

  # Accept either 4-space indent (under sessions:) or 2-space (flat list)
  # Schema uses {path, label} not {file} — match '- path:' per SCHEMA.md line 222
  if printf '%s\n' "$frontmatter" | grep -qE "^    - path:|^  - path:"; then
    sessions_item="present"
  fi

  if [ -z "$sources_key" ]; then
    fail "${label}: sources structure" "missing top-level 'sources:' key"
  elif [ -z "$sessions_key" ]; then
    fail "${label}: sources structure" "'sources:' present but missing 'sessions:' sub-key"
  elif [ -z "$sessions_item" ]; then
    fail "${label}: sources structure" "'sources.sessions' present but no '- path:' entries found"
  else
    pass "${label}: sources.sessions structure valid"
  fi

  # Check 2: Enum validation
  type_val=$(extract_field "$frontmatter" "type")
  case "$type_val" in
    shipment|decision|incident|discovery|tale|practice)
      pass "${label}: type enum ('${type_val}')"
      ;;
    *)
      fail "${label}: type enum" "'${type_val}' not in shipment|decision|incident|discovery|tale|practice"
      ;;
  esac

  confidence_val=$(extract_field "$frontmatter" "confidence")
  case "$confidence_val" in
    high|medium|low)
      pass "${label}: confidence enum ('${confidence_val}')"
      ;;
    *)
      fail "${label}: confidence enum" "'${confidence_val}' not in high|medium|low"
      ;;
  esac

  status_val=$(extract_field "$frontmatter" "status")
  case "$status_val" in
    draft|refined|published)
      pass "${label}: status enum ('${status_val}')"
      ;;
    *)
      fail "${label}: status enum" "'${status_val}' not in draft|refined|published"
      ;;
  esac

  # Check 3: ID-filename match
  id_val=$(extract_field "$frontmatter" "id")
  if [ "$id_val" = "$stem" ]; then
    pass "${label}: id matches filename ('${id_val}')"
  else
    fail "${label}: id matches filename" "frontmatter id='${id_val}' but filename stem='${stem}'"
  fi

  # Check 4: URI format — must match arch://{slug}/{id}
  uri_val=$(extract_field "$frontmatter" "uri")
  # Strip surrounding quotes if present
  uri_val=$(printf '%s' "$uri_val" | sed 's/^["'"'"']//;s/["'"'"']$//')

  # Validate: starts with arch:// followed by slug/id
  # Slug: lowercase alphanumeric and hyphens; id: art-NNN
  if printf '%s' "$uri_val" | grep -qE '^arch://[a-z0-9][a-z0-9-]*/art-[0-9]+$'; then
    # Also verify the id segment at end matches the file's own id
    uri_id=$(printf '%s' "$uri_val" | sed 's|.*\/||')
    if [ "$uri_id" = "$stem" ]; then
      pass "${label}: URI format ('${uri_val}')"
    else
      fail "${label}: URI format" "URI id segment '${uri_id}' does not match filename stem '${stem}'"
    fi
  else
    fail "${label}: URI format" "'${uri_val}' does not match arch://{slug}/{id}"
  fi

done

# ------------------------------------------------------------------
# Check 5: Exhibition link integrity — forward + reverse
# ------------------------------------------------------------------

exhibition_file="${ARCH_DIR}/exhibition.md"

if [ ! -f "$exhibition_file" ]; then
  fail "exhibition.md exists" "file not found at ${exhibition_file}"
else
  pass "exhibition.md exists"

  # Forward check: every link in exhibition.md must resolve to a file on disk
  broken_links=""
  while IFS= read -r line; do
    # Match markdown links of the form ](artifacts/art-NNN.md)
    link=$(printf '%s' "$line" | sed -n 's/.*](\(artifacts\/art-[^)]*\.md\)).*/\1/p')
    if [ -z "$link" ]; then
      continue
    fi
    target="${ARCH_DIR}/${link}"
    if [ ! -f "$target" ]; then
      broken_links="${broken_links} ${link}"
    fi
  done < "$exhibition_file"

  if [ -n "$broken_links" ]; then
    fail "exhibition.md link integrity (forward)" "broken links:${broken_links}"
  else
    pass "exhibition.md link integrity (forward)"
  fi

  # Gap fix — reverse check: every art-*.md on disk must appear as a link in
  # exhibition.md.  Accumulate all missing files; report once.
  unlinked_files=""
  for artifact_file in "${artifact_files[@]}"; do
    filename=$(basename "$artifact_file")
    # grep -F is POSIX and bash-3.2 safe; no regex needed for a literal filename
    if ! grep -qF "artifacts/${filename}" "$exhibition_file"; then
      unlinked_files="${unlinked_files} artifacts/${filename}"
    fi
  done

  if [ -n "$unlinked_files" ]; then
    fail "exhibition.md link integrity (reverse)" "art files not linked in exhibition.md:${unlinked_files}"
  else
    pass "exhibition.md link integrity (reverse)"
  fi
fi

# --------------------------------------------------------------------------
# Phase 2: jq checks
# --------------------------------------------------------------------------

printf '\n=== Phase 2: JSON integrity (jq) ===\n\n'

if ! command -v jq >/dev/null 2>&1; then
  printf 'NOTE: jq not found — skipping Phase 2 checks\n'
  printf '\nvalidate-conserve: %d passed, %d failed\n' "$PASS" "$FAIL"
  [ "$FAIL" -gt 0 ] && exit 1
  exit 0
fi

index_file="${ARTIFACTS_DIR}/_index.json"
exhibition_json="${ARCH_DIR}/_exhibition.json"

# ------------------------------------------------------------------
# Check 6: Index count parity
# ------------------------------------------------------------------

if [ ! -f "$index_file" ]; then
  fail "_index.json exists" "file not found at ${index_file}"
else
  pass "_index.json exists"

  # Bug 2 fix: explicit JSON validity check before extracting count.
  # The old `|| printf '0'` silently masked parse errors.
  if ! jq empty "$index_file" 2>/dev/null; then
    fail "_index.json valid JSON" "parse error in ${index_file}"
  else
    index_count=$(jq -r '.artifact_count // 0' "$index_file")
    actual_count="${#artifact_files[@]}"

    if [ "$index_count" = "$actual_count" ]; then
      pass "_index.json count parity (${index_count} declared = ${actual_count} files)"
    else
      fail "_index.json count parity" "declared artifact_count=${index_count} but found ${actual_count} art-*.md files"
    fi
  fi
fi

# ------------------------------------------------------------------
# Check 7: _exhibition.json ID cross-check
# ------------------------------------------------------------------

if [ ! -f "$exhibition_json" ]; then
  fail "_exhibition.json exists" "file not found at ${exhibition_json}"
else
  pass "_exhibition.json exists"

  # Extract all artifact_ids from all sections
  exhibition_ids=$(jq -r '.sections[]?.artifact_ids[]?' "$exhibition_json" 2>/dev/null || true)

  if [ -z "$exhibition_ids" ]; then
    fail "_exhibition.json artifact_ids" "no artifact_ids found in any section"
  else
    missing_from_disk=""
    while IFS= read -r art_id; do
      [ -z "$art_id" ] && continue
      if [ ! -f "${ARTIFACTS_DIR}/${art_id}.md" ]; then
        missing_from_disk="${missing_from_disk} ${art_id}"
      fi
    done <<EOF
$exhibition_ids
EOF

    if [ -n "$missing_from_disk" ]; then
      fail "_exhibition.json ID cross-check" "IDs in exhibition have no .md file:${missing_from_disk}"
    else
      pass "_exhibition.json ID cross-check"
    fi
  fi
fi

# ------------------------------------------------------------------
# Check 8: Orphan check — every art-NNN.md must appear in exhibition
# ------------------------------------------------------------------

if [ -f "$exhibition_json" ]; then
  orphans=""
  for artifact_file in "${artifact_files[@]}"; do
    stem=$(basename "$artifact_file" .md)
    # Check whether this id appears anywhere in artifact_ids arrays
    found=$(jq -r --arg id "$stem" '.sections[]?.artifact_ids[]? | select(. == $id)' "$exhibition_json" 2>/dev/null || true)
    if [ -z "$found" ]; then
      orphans="${orphans} ${stem}"
    fi
  done

  if [ -n "$orphans" ]; then
    fail "orphan check" "art files not in any _exhibition.json section:${orphans}"
  else
    pass "orphan check (all artifacts referenced in exhibition)"
  fi
else
  # Bug 3 fix: when _exhibition.json is absent the old code silently skipped
  # this check — producing neither pass nor fail.  Fail explicitly instead.
  fail "orphan check" "_exhibition.json absent — cannot verify orphan status"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

printf '\nvalidate-conserve: %d passed, %d failed\n' "$PASS" "$FAIL"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
