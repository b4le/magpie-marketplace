#!/bin/bash
# migrate-plans.sh — Migrate decompose plans from old location to new.
#
# Moves plan files from ~/.claude/plans/ into ~/.claude/decompose/plans/{plan-id}/
# where each plan-id is the stem of the .json or .md filename.
#
# Usage:
#   migrate-plans.sh [--dry-run]
#
# Idempotent: safe to run multiple times. Already-migrated plans are skipped.
# Does NOT delete ~/.claude/plans/ after migration.

set -uo pipefail

OLD_DIR="${HOME}/.claude/plans"
NEW_DIR="${HOME}/.claude/decompose/plans"

DRY_RUN=false

# --- Argument parsing ---
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Helpers ---

log() {
    echo "$@"
}

warn() {
    echo "WARN: $@" >&2
}

run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

# --- Pre-flight checks ---

if [ ! -d "$OLD_DIR" ]; then
    log "Nothing to migrate: ${OLD_DIR} does not exist."
    exit 0
fi

# Collect all .json and .md files (exclude directories)
_file_list=$(mktemp)
find "$OLD_DIR" -maxdepth 1 \( -name "*.json" -o -name "*.md" \) -type f > "$_file_list" 2>/dev/null || true

if [ ! -s "$_file_list" ]; then
    rm -f "$_file_list"
    log "Nothing to migrate: ${OLD_DIR} contains no .json or .md files."
    exit 0
fi

# --- Ensure new base directory exists ---
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$NEW_DIR" || { echo "ERROR: Cannot create ${NEW_DIR}" >&2; rm -f "$_file_list"; exit 1; }
fi

# --- Collect unique plan stems ---
_stems_list=$(mktemp)
while IFS= read -r filepath; do
    filename=$(basename -- "$filepath")
    # Strip extension to get stem (handles .json and .md)
    stem="${filename%.json}"
    stem="${stem%.md}"
    echo "$stem"
done < "$_file_list" | sort -u > "$_stems_list"
rm -f "$_file_list"

# --- Migrate plans ---
moved=0
skipped=0

while IFS= read -r stem; do
    [ -z "$stem" ] && continue

    plan_dest="${NEW_DIR}/${stem}"

    # Determine which source files exist for this stem
    json_src="${OLD_DIR}/${stem}.json"
    md_src="${OLD_DIR}/${stem}.md"
    has_json=false
    has_md=false
    [ -f "$json_src" ] && has_json=true
    [ -f "$md_src" ]   && has_md=true

    # Check if already fully migrated: dest dir exists AND neither source file remains
    if [ -d "$plan_dest" ] && [ "$has_json" = false ] && [ "$has_md" = false ]; then
        log "  skip  ${stem}  (already migrated)"
        skipped=$((skipped + 1))
        continue
    fi

    # If dest dir exists but source files still present, a previous run was interrupted — resume
    if [ "$DRY_RUN" = false ]; then
        if ! mkdir -p "$plan_dest" 2>/dev/null; then
            warn "Cannot create ${plan_dest} — skipping ${stem}"
            skipped=$((skipped + 1))
            continue
        fi
    fi

    plan_moved=false

    if [ "$has_json" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log "[dry-run] mv \"${json_src}\" \"${plan_dest}/\""
            plan_moved=true
        else
            if mv -- "$json_src" "${plan_dest}/" 2>/dev/null; then
                plan_moved=true
            else
                warn "Failed to move ${json_src} — check permissions"
            fi
        fi
    fi

    if [ "$has_md" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log "[dry-run] mv \"${md_src}\" \"${plan_dest}/\""
            plan_moved=true
        else
            if mv -- "$md_src" "${plan_dest}/" 2>/dev/null; then
                plan_moved=true
            else
                warn "Failed to move ${md_src} — check permissions"
            fi
        fi
    fi

    if [ "$plan_moved" = true ]; then
        log "  moved  ${stem}"
        moved=$((moved + 1))
    else
        skipped=$((skipped + 1))
    fi

done < "$_stems_list"
rm -f "$_stems_list"

# --- Summary ---
if [ "$DRY_RUN" = true ]; then
    log ""
    log "[dry-run] Would move ${moved} plan(s), skip ${skipped} already-migrated."
else
    log ""
    log "Moved ${moved} plan(s), skipped ${skipped} already-migrated."
fi
