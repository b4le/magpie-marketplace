#!/usr/bin/env bash
# auto-resume.sh — SessionStart hook
# Finds best available handoff and returns it via additionalContext.
# Only fires for "startup" and "clear" sources.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_stdin

# Filter to startup and clear sources only
source_type=$(get_field "source")
if [[ -n "$source_type" && "$source_type" != "startup" && "$source_type" != "clear" ]]; then
  exit 0
fi

project_dir=$(get_project_dir)
[[ -z "$project_dir" ]] && exit 0

branch=$(get_git_branch "$project_dir")
[[ "$branch" == "unknown" ]] && exit 0

safe_branch=$(sanitize_branch "$branch")
handoffs_dir="${project_dir}/.claude/handoffs"
[[ -d "$handoffs_dir" ]] || exit 0

# Prune old handoffs (> 7 days)
prune_old_handoffs "$handoffs_dir"

# --- Lookup priority ---
handoff_file=""
handoff_type=""
collision_detected=false

# Priority 1: Most recent branch handoff
newest=$(find "$handoffs_dir" -maxdepth 1 -name "${safe_branch}_*.md" -print0 2>/dev/null \
  | xargs -0 ls -t 2>/dev/null | head -1 || true)
if [[ -n "$newest" ]]; then
  handoff_file="$newest"
  handoff_type="handoff"

  # Collision detection: multiple files within 1 hour
  second=$(find "$handoffs_dir" -maxdepth 1 -name "${safe_branch}_*.md" -print0 2>/dev/null \
  | xargs -0 ls -t 2>/dev/null | sed -n '2p' || true)
  if [[ -n "$second" ]]; then
    first_mtime=$(stat -f %m "$newest" 2>/dev/null || stat -c %Y "$newest" 2>/dev/null || echo 0)
    second_mtime=$(stat -f %m "$second" 2>/dev/null || stat -c %Y "$second" 2>/dev/null || echo 0)
    if (( first_mtime - second_mtime < 3600 )); then
      # Collision: don't load content, let /pickup handle selection
      handoff_file=""
      handoff_type="collision"
      collision_detected=true

      # Build collision summary listing each file (newline-safe loop)
      collision_summary=""
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        f_mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
        f_ts=$(date -r "${f_mtime}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null \
          || date -d "@${f_mtime}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null \
          || echo "unknown")
        f_heading=$(head -n 1 -- "$f" 2>/dev/null || true)
        [[ -z "$f_heading" ]] && f_heading="(empty)"
        collision_summary="${collision_summary}
- **${f_ts}** — ${f_heading} (\`$(basename -- "$f")\`)"
      done < <(find "$handoffs_dir" -maxdepth 1 -name "${safe_branch}_*.md" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null)
    fi
  fi
fi

# Priority 2: Checkpoint (skip if collision detected)
if [[ "$collision_detected" == false && -z "$handoff_file" && -f "${handoffs_dir}/.checkpoint_${safe_branch}.md" ]]; then
  handoff_file="${handoffs_dir}/.checkpoint_${safe_branch}.md"
  handoff_type="checkpoint"
fi

# Priority 3: Git inference (skip if collision detected)
sha=""
status=""
recent_commits=""
if [[ "$collision_detected" == false && -z "$handoff_file" ]]; then
  sha=$(get_git_sha "$project_dir")
  status=$(get_git_status "$project_dir")
  recent_commits=$(get_git_recent_commits "$project_dir")
  if [[ -n "$status" || -n "$recent_commits" ]]; then
    handoff_type="git-inference"
  fi
fi

# --- Build context string ---
context=""
if [[ "$handoff_type" == "collision" ]]; then
  context="## Multiple Handoffs Found

Multiple sessions were detected on branch **${branch}** within the last hour. Run \`/pickup\` to choose which session to resume.
${collision_summary}"
elif [[ "$handoff_type" == "handoff" || "$handoff_type" == "checkpoint" ]]; then
  file_content=$(cat "$handoff_file" 2>/dev/null) || { exit 0; }
  context="## Previous Session Context (${handoff_type})

${file_content}"
elif [[ "$handoff_type" == "git-inference" ]]; then
  context="## Previous Session Context (inferred from git)

**Branch:** ${branch}
**HEAD:** ${sha}

### Modified Files
${status:-None}

### Recent Commits
${recent_commits:-None}"
fi

# --- Output JSON ---
if [[ -n "$context" ]]; then
  encoded=$(json_encode "$context")
  printf '{"additionalContext": %s}\n' "$encoded"
fi
