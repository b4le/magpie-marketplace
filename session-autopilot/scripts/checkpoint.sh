#!/usr/bin/env bash
# checkpoint.sh — PreCompact hook
# Writes a lightweight checkpoint to .claude/handoffs/.checkpoint_{branch}.md
# This is the primary crash-recovery mechanism.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_stdin

project_dir=$(get_project_dir)
[[ -z "$project_dir" ]] && exit 0

branch=$(get_git_branch "$project_dir")
[[ "$branch" == "unknown" ]] && exit 0

safe_branch=$(sanitize_branch "$branch")
handoffs_dir=$(ensure_handoffs_dir "$project_dir")

sha=$(get_git_sha "$project_dir")
status=$(get_git_status "$project_dir")
timestamp=$(iso_timestamp)

content="# Checkpoint
**Updated:** ${timestamp}
**Branch:** ${branch}
**HEAD:** ${sha}

## Git State
${status:-No uncommitted changes}"

atomic_write "${handoffs_dir}/.checkpoint_${safe_branch}.md" "$content"
