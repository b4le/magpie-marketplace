#!/bin/bash
# Validate worktree safety before expert operations
# Called before spawning modifier agents

set -e
set -u

# Check Python version (required >= 3.9 for reliable path handling)
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required but not found" >&2
  exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)" 2>/dev/null; then
  echo "Error: Python >= 3.9 required (found $PYTHON_VERSION)" >&2
  exit 1
fi

WORKTREE_PATH="$1"

# Validate input
if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: WORKTREE_PATH argument required" >&2
  exit 1
fi

# Explicit check for path traversal attempts
if [[ "$WORKTREE_PATH" == *".."* ]]; then
  echo "Error: WORKTREE_PATH contains path traversal sequence (..)" >&2
  exit 1
fi

# Strict character validation (alphanumeric, slashes, dots, dashes, underscores only)
if ! [[ "$WORKTREE_PATH" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
  echo "Error: WORKTREE_PATH contains invalid characters" >&2
  exit 1
fi

# Normalize path (resolve ../ - create canonical form without requiring path to exist)
# Use Python for cross-platform path normalization
# Pass path via sys.argv to prevent command injection
WORKTREE_PATH_CANONICAL=$(python3 -c "import sys,os.path; print(os.path.abspath(os.path.normpath(sys.argv[1])))" "$WORKTREE_PATH" 2>/dev/null) || {
  echo "Error: Invalid path" >&2
  exit 1
}

# Prevent escaping project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || PROJECT_ROOT=""
if [ -n "$PROJECT_ROOT" ] && [[ ! "$WORKTREE_PATH_CANONICAL" == "$PROJECT_ROOT"* ]] && [[ ! "$WORKTREE_PATH_CANONICAL" == /tmp/* ]]; then
  echo "Error: Worktree path must be within project or /tmp/" >&2
  exit 1
fi

# Check for excessive expert-review worktrees in /tmp/
if [[ "$WORKTREE_PATH_CANONICAL" == /tmp/* ]]; then
  EXISTING_EXPERT_WORKTREES=$(git worktree list | grep -c "/tmp/expert-review-" || true)

  # Hard limit: Block at 10 worktrees
  if [ "$EXISTING_EXPERT_WORKTREES" -ge 10 ]; then
    echo "Error: Maximum worktree limit (10) reached. Found $EXISTING_EXPERT_WORKTREES expert-review worktrees in /tmp/" >&2
    echo "Please clean up old worktrees before creating new ones:" >&2
    echo "  git worktree remove <path>  # Remove specific worktree" >&2
    echo "  git worktree prune           # Clean up stale metadata" >&2
    exit 1
  fi

  # Warning: Alert at 5 worktrees
  if [ "$EXISTING_EXPERT_WORKTREES" -gt 5 ]; then
    echo "Warning: Found $EXISTING_EXPERT_WORKTREES expert-review worktrees in /tmp/" >&2
    echo "Consider cleaning up old worktrees: git worktree prune" >&2
  fi
fi

# Check if git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a git repository" >&2
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "Warning: Uncommitted changes in working directory" >&2
  echo "Expert modifications may conflict with local changes" >&2
fi

# Check worktree doesn't already exist
if [ -d "$WORKTREE_PATH_CANONICAL" ]; then
  echo "Error: Worktree path already exists: $WORKTREE_PATH_CANONICAL" >&2
  exit 1
fi

# Check for protected paths (using canonical path)
# Use path component matching to avoid false positives from substring matches
PROTECTED_PATHS=(".git" "node_modules" ".claude" "dist" "build")
for protected in "${PROTECTED_PATHS[@]}"; do
  # Check if protected path appears as a complete path component (delimited by /)
  if [[ "$WORKTREE_PATH_CANONICAL" == *"/$protected" ]] || \
     [[ "$WORKTREE_PATH_CANONICAL" == *"/$protected/"* ]] || \
     [[ "$WORKTREE_PATH_CANONICAL" == "$protected" ]] || \
     [[ "$WORKTREE_PATH_CANONICAL" == "$protected/"* ]]; then
    echo "Error: Cannot create worktree in protected path: $protected" >&2
    exit 1
  fi
done

# List current worktrees for reference
echo "Current worktrees:"
git worktree list

exit 0
