---
domain: git-workflows
status: active
maintainer: archaeology-skill
last_updated: 2026-02-26
version: 1.0.0
agent_count: 4

keywords:
  primary:
    - "git commit"
    - "git push"
    - "gh pr"
    - "git checkout"
    - "git branch"
    - "git switch"
    - "git restore"
  secondary:
    - "git merge"
    - "git rebase"
    - "git stash"
    - "git worktree"
    - HEREDOC
    - "Co-Authored-By"
    - "feat:"
    - "fix:"
    - "chore:"
    - conventional commit
    - pull request
    - PR
    - branch
    - merge conflict
    - "gh pr review"
    - "gh pr merge"
    - "gh workflow"
    - "gh run"
    - "git cherry-pick"
    - "git log --oneline"
    - "git sparse-checkout"
    - "git commit -S"
    - "--draft"
  exclusion:
    - "git config"
    - "--no-verify"
    - "force push"
    - ".git/objects"
    - "git reset --hard"

locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation history with git commands"
    priority: high
  - path: "~/{PROJECT_ROOT}/.git/hooks/"
    purpose: "Git hooks configuration"
    priority: medium
  - path: "~/{PROJECT_ROOT}/.github/"
    purpose: "GitHub workflows and templates"
    priority: medium
  - path: "~/{PROJECT_ROOT}/CLAUDE.md"
    purpose: "Git workflow instructions"
    priority: high
  - path: "~/.claude/skills/managing-git-workflows/reference/"
    purpose: "Git workflow reference documentation"
    priority: medium

outputs:
  - file: README.md
    required: true
    template: readme
  - file: commit-patterns.md
    required: true
    template: prompts
  - file: pr-workflows.md
    required: true
    template: patterns
  - file: branching-strategies.md
    required: false
    template: patterns
  - file: hook-configurations.md
    required: false
    template: patterns
  - file: conflict-resolution.md
    required: false
    template: patterns
  - file: github-actions-patterns.md
    required: false
    template: patterns
---

# Git Workflows Domain

**Description:** Git workflow patterns, commit conventions, PR creation strategies, and branching workflows extracted from Claude Code usage history

---

## Metadata

| Field | Value |
|-------|-------|
| Domain ID | git-workflows |
| Version | 1.0.0 |
| Created | 2026-02-26 |
| Updated | 2026-02-26 |
| Maintainer | archaeology-skill |

## Search Keywords

### Primary Keywords

**Git Commands:**
- `git commit` - Commit creation patterns
- `git push` - Push workflows and flags
- `gh pr` - Pull request creation via GitHub CLI
- `git checkout` - Branch switching patterns
- `git branch` - Branch management

**What they find:**
- Primary keywords capture direct git command invocations in conversation history
- Shows actual command patterns used by Claude Code
- Reveals flags, arguments, and command sequences

### Secondary Keywords

**Advanced Git Operations:**
- `git merge` - Merge strategies
- `git rebase` - Rebase workflows
- `git stash` - Work-in-progress management
- `git worktree` - Parallel development workflows

**Commit Conventions:**
- `HEREDOC` - Multi-line commit message formatting
- `Co-Authored-By` - Pair programming attribution
- `feat:`, `fix:`, `chore:` - Conventional commit prefixes
- `conventional commit` - Commit message standards
- `pull request`, `PR` - PR-related discussions

**Workflow Patterns:**
- `branch` - Branching discussions
- `merge conflict` - Conflict resolution patterns

**What they find:**
- Commit message formatting techniques (HEREDOC for multi-line)
- Co-authoring patterns (Claude + User collaboration)
- Conventional commit adoption
- Advanced workflow patterns
- Problem-solving approaches (conflicts, etc.)

### Exclusion Keywords

**Dangerous Operations:**
- `git config` - Low-level configuration (not workflow)
- `--no-verify` - Hook bypassing (anti-pattern)
- `force push` - Destructive operation
- `.git/objects` - Internal git implementation details
- `git reset --hard` - Destructive reset operations

**Why exclude:**
- Focus on safe, documented workflows
- Exclude internal git mechanics
- Filter out anti-patterns and dangerous operations
- Remove configuration noise from workflow patterns

## Search Locations

| Agent | Location | Purpose | Priority |
|-------|----------|---------|----------|
| Git-History-1 | ~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/ | Conversation *.jsonl files with git commands | High |
| Git-Config-2 | ~/{PROJECT_ROOT}/CLAUDE.md | Project-level git workflow instructions | High |
| Git-Hooks-3 | ~/{PROJECT_ROOT}/.git/hooks/ | Pre-commit, commit-msg, pre-push hooks | Medium |
| GitHub-Config-4 | ~/{PROJECT_ROOT}/.github/ | PR templates, workflows, issue templates | Medium |

**Agent responsibilities:**

- **Git-History-1:** Extract git commands from conversation history, analyze command sequences, identify patterns
- **Git-Config-2:** Parse CLAUDE.md for git workflow instructions, commit message guidelines, PR creation rules
- **Git-Hooks-3:** Document hook configurations, pre-commit checks, validation rules
- **GitHub-Config-4:** Extract PR templates, GitHub Actions workflows, contribution guidelines

## Extraction Pattern

For each git workflow instance, extract:

### Commit Patterns
- **Message format:** HEREDOC vs single-line, conventional commit usage
- **Co-authoring:** `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` patterns
- **Staging strategy:** Individual files vs `git add -A`, what files are staged
- **Pre-commit validation:** What checks run before commit, how failures are handled

### PR Creation Workflows
- **Title conventions:** Length limits, format patterns
- **Body structure:** Summary sections, test plans, checklists
- **Command sequences:** What happens before `gh pr create` (status, diff, log)
- **Base branch:** Default branch targets, feature branch patterns

### Branching Strategies
- **Branch naming:** Prefixes (feature/, fix/, chore/), naming conventions
- **Worktree usage:** When worktrees are created vs traditional branches
- **Branch lifecycle:** Creation, merge, deletion patterns

### Hook Usage
- **Pre-commit:** Linting, formatting, test execution
- **Commit-msg:** Message validation, conventional commit enforcement
- **Pre-push:** Remote checks, test suites

### Merge/Rebase Preferences
- **Strategy choice:** When merge vs rebase is used
- **Conflict resolution:** How conflicts are detected and resolved
- **Interactive rebase:** Squashing, rewording patterns

### PR Review Workflows
- **Review commands:** `gh pr review`, approval patterns, requested changes
- **Review feedback:** Comment patterns, change requests
- **Merge strategies:** When PRs are merged, merge vs squash vs rebase

### Worktree Cleanup Patterns
- **Removal timing:** When worktrees are removed
- **Orphan detection:** How stale worktrees are identified
- **Cleanup commands:** Automated vs manual removal

### Recovery Patterns
- **Reflog usage:** Using `git reflog` for undoing mistakes
- **Commit recovery:** Recovering deleted commits or branches
- **Reset recovery:** Undoing accidental resets

### Commit Signing Patterns
- **Signature usage:** When commits are signed with `-S`
- **GPG configuration:** How signing is set up
- **Verification:** How signatures are verified

## Output Files

| File | Content | Required |
|------|---------|----------|
| README.md | Domain index, extraction summary, key findings | Yes |
| commit-patterns.md | Commit message formats, Co-Authored-By usage, staging patterns | Yes |
| pr-workflows.md | PR creation sequences, title/body templates, review workflows | Yes |
| branching-strategies.md | Branch naming, worktree usage, lifecycle patterns | If found |
| hook-configurations.md | Hook scripts, validation rules, common checks | If found |

## Validation Rules

### Pre-execution Validation
- At least one conversation history directory exists
- Git-related keywords present in history
- Output directory is writable
- No existing extraction from last 24 hours (avoid duplicates)

### Post-execution Validation
- Results found OR no-results.md created
- No destructive commands documented without warnings
- All HEREDOC examples properly formatted
- No hardcoded paths specific to one machine
- Co-Authored-By patterns correctly attributed

### Content Quality Checks
- Commit messages extracted verbatim (no modifications)
- Context preserved: what task prompted the commit
- Evolution tracked: how patterns changed over time
- Anti-patterns flagged with explanations

## Success Criteria

Findings should answer:

1. **What commit message conventions are used?**
   - Conventional commits? Custom formats?
   - HEREDOC for multi-line? Single-line patterns?
   - Co-Authored-By usage frequency?

2. **How are PRs structured?**
   - Title length and format
   - Body sections (Summary, Test Plan, etc.)
   - Commands run before PR creation
   - Base branch selection logic

3. **What branching strategy is preferred?**
   - Feature branches vs worktrees
   - Naming conventions
   - When branches are created vs reused

4. **What hooks are configured?**
   - Pre-commit: linting, formatting, tests
   - Commit-msg: message validation
   - Pre-push: remote validation

5. **How are merge conflicts handled?**
   - Detection methods
   - Resolution strategies
   - When to merge vs rebase

6. **How have git workflows evolved over time?**
   - What patterns were tried and abandoned?
   - What changes were made to improve workflows?
   - How have conventions changed?

7. **What recovery patterns exist?**
   - How are mistakes undone?
   - What reflog patterns are used?
   - How are deleted commits or branches recovered?

## Anti-Patterns

### Do NOT Extract or Document

**Dangerous operations without safety warnings:**
- `git push --force` (except on non-main branches with explicit confirmation)
- `git reset --hard` (destructive, loses work)
- `git clean -f` (deletes untracked files permanently)
- `--no-verify` (skips important hooks)

**Configuration noise:**
- `git config user.name/email` (not workflow, personal setup)
- `.git/objects` internals
- Git implementation details

**Sensitive data:**
- Commit messages containing API keys, secrets
- Branch names with internal project codes
- PR descriptions with confidential information

### Red Flags to Investigate

If you encounter these patterns, flag them as anti-patterns:

- **Force push to main/master:** Almost always wrong
- **Skipping hooks repeatedly:** Indicates broken hooks or misunderstanding
- **Empty commit messages:** Poor documentation
- **Committing directly to main:** Bypass of review process
- **Large binary files in commits:** Git LFS should be used
- **Worktrees sharing the same branch:** Causes conflicts and confusion
- **Missing cleanup of stale worktrees:** Leaves orphaned worktrees consuming disk space

## Quick Extraction Commands

### Find Git Commands in History

```bash
# Find all git commit commands
grep -r "git commit" ~/.claude/projects/ --include="*.jsonl" | head -20

# Find PR creation
grep -r "gh pr create" ~/.claude/projects/ --include="*.jsonl"

# Find HEREDOC commit patterns
grep -A 5 "git commit -m.*cat <<'EOF'" ~/.claude/projects/ --include="*.jsonl"

# Find Co-Authored-By usage
grep -r "Co-Authored-By" ~/.claude/projects/ --include="*.jsonl"
```

### Find Conventional Commits

```bash
# Find feat/fix/chore commits
grep -r "git commit.*feat:\\|fix:\\|chore:" ~/.claude/projects/ --include="*.jsonl"

# Count conventional commit usage
grep -r "feat:\\|fix:\\|chore:" ~/.claude/projects/ --include="*.jsonl" | wc -l
```

### Find Branching Patterns

```bash
# Find branch creation
grep -r "git checkout -b\\|git branch" ~/.claude/projects/ --include="*.jsonl"

# Find worktree usage
grep -r "git worktree" ~/.claude/projects/ --include="*.jsonl"
```

### Find Hook Configurations

```bash
# Find pre-commit hooks
find ~/{PROJECT_ROOT}/.git/hooks/ -name "pre-commit" -type f

# Find hook discussions in CLAUDE.md
grep -r "pre-commit\\|commit-msg\\|pre-push" ~/{PROJECT_ROOT}/CLAUDE.md
```

### Find PR Workflow Patterns

```bash
# Find gh pr create with body
grep -A 10 "gh pr create" ~/.claude/projects/ --include="*.jsonl"

# Find PR template files
find ~/{PROJECT_ROOT}/.github/ -name "*pull_request*" -type f
```

## Example Workflows to Extract

### Workflow 1: Standard Commit with HEREDOC

**Pattern to find:**
```bash
git status
git diff
git add specific-file.js
git commit -m "$(cat <<'EOF'
feat: add user authentication

Implement JWT-based auth with refresh tokens.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**What to extract:**
- Command sequence: status -> diff -> add -> commit
- HEREDOC formatting
- Conventional commit prefix
- Co-Authored-By attribution

### Workflow 2: PR Creation

**Pattern to find:**
```bash
git status
git diff main...HEAD
git log main..HEAD
git push -u origin feature/auth
gh pr create --title "Add user authentication" --body "$(cat <<'EOF'
## Summary
- Implement JWT authentication
- Add refresh token support

## Test plan
- [ ] Unit tests pass
- [ ] Integration tests pass
EOF
)"
```

**What to extract:**
- Pre-PR validation commands
- Push with upstream tracking
- PR title convention
- Body structure with sections

### Workflow 3: Worktree Usage

**Pattern to find:**
```bash
git worktree add ../feature-auth feature/auth
cd ../feature-auth
# work happens
git worktree remove ../feature-auth
```

**What to extract:**
- When worktrees are preferred over branches
- Naming and location patterns
- Cleanup procedures

## Maintenance Notes

### Update Triggers

Review this domain when:
- New git commands added to Claude Code toolkit
- Conventional commit standards change
- GitHub CLI (`gh`) adds new features
- Pre-commit framework updates
- Organization adopts new git workflows

### Known Limitations

- Cannot extract git operations done outside Claude Code sessions
- Some workflows span multiple sessions (may miss context)
- Manual git operations (GUI, IDE) not captured
- Branch deletion patterns may be incomplete

### Related Domains

- **prompting-patterns:** CLAUDE.md instructions for git workflows
- **code-review:** PR review patterns and feedback loops
- **deployment-workflows:** How git integrates with CI/CD
- **collaboration:** Pair programming and co-authoring patterns
