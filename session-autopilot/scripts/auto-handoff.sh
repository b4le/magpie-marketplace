#!/usr/bin/env bash
# auto-handoff.sh — SessionEnd hook
# Writes a skeleton handoff to .claude/handoffs/{branch}_{timestamp}.md
# Skips if a manual /handoff was written in the last 60 seconds.
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

# Skip if a handoff file was written in the last 60 seconds (manual /handoff ran)
newest=$(find "$handoffs_dir" -maxdepth 1 -name "${safe_branch}_*.md" -print0 2>/dev/null \
  | xargs -0 ls -t 2>/dev/null | head -1 || true)
if [[ -n "$newest" ]]; then
  now=$(date +%s)
  # macOS stat uses -f %m, Linux uses -c %Y
  file_mtime=$(stat -f %m "$newest" 2>/dev/null || stat -c %Y "$newest" 2>/dev/null || echo 0)
  if (( now - file_mtime < 60 )); then
    exit 0
  fi
fi

sha=$(get_git_sha "$project_dir")
status=$(get_git_status "$project_dir")
diff_stat=$(get_git_diff_stat "$project_dir")
recent_commits=$(get_git_recent_commits "$project_dir")
timestamp=$(iso_timestamp)
file_timestamp=$(utc_timestamp)
session_id=$(get_field "session_id")

content="# Session Handoff (auto)
**Updated:** ${timestamp}
**Branch:** ${branch}
**HEAD:** ${sha}
**Session:** ${session_id:-unknown}

## Git State
${status:-No uncommitted changes}

## Changes
${diff_stat:-No staged/unstaged changes}

## Recent Commits
${recent_commits:-No commits}"

atomic_write "${handoffs_dir}/${safe_branch}_${file_timestamp}.md" "$content"
