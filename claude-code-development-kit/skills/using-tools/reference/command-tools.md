# Command Execution Tools - Detailed Reference

Comprehensive documentation for Bash tool and Git operations.

---

## Bash Tool

**Purpose**: Execute terminal commands in persistent shell

**When to use**:
- Git operations: status, diff, commit, push, log
- Package management: npm, pip, cargo, etc.
- Docker commands
- Running tests
- Building projects
- Starting development servers

**When NOT to use**:
- File operations (use Read/Write/Edit instead)
- File searching (use Glob/Grep instead)
- Communicating with user (output text directly)

**Parameters**:
- `command` (required): Shell command to execute
- `description` (optional): Clear 5-10 word description
- `timeout` (optional): Milliseconds (default 120000, max 600000)
- `run_in_background` (optional): Run in background

**Best Practices**:
- Quote paths with spaces: `cd "path with spaces"`
- Use for terminal operations, NOT file operations
- Chain dependent commands with `&&`: `git add . && git commit -m "message"`
- Use `&&` when later commands depend on earlier success
- Use `;` when you don't care if earlier commands fail
- Run independent commands in parallel (multiple Bash calls in one message)
- Don't use newlines to separate commands (except in quoted strings)
- Maintain working directory using absolute paths, avoid `cd`
- Never use for: find, grep, cat, head, tail, sed, awk, echo

**Examples**:
```bash
# Sequential (dependent commands)
git add . && git commit -m "Update feature" && git push

# Parallel (independent commands)
In one message:
- git status
- git diff
- git log --oneline -5

# Background execution
npm run dev (with run_in_background: true)
```

**Anti-patterns**:
- Using for file operations (cat, grep, find, etc.)
- Using echo to communicate with user (output text directly)
- Running dependent commands in parallel

---

## Git Operations via Bash Tool

### Creating Commits

**Process**:
1. Run in parallel: `git status`, `git diff`, `git log`
2. Analyze changes and draft commit message
3. Add files: `git add <files>`
4. Commit with HEREDOC for proper formatting
5. Run `git status` to verify

**Commit Message Format**:
```bash
git commit -m "$(cat <<'EOF'
{Commit message here}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Git Safety Protocol**:
- NEVER update git config
- NEVER run destructive/irreversible commands (push --force, hard reset) unless explicitly requested
- NEVER skip hooks (--no-verify, --no-gpg-sign) unless explicitly requested
- NEVER force push to main/master, warn user if they request it
- Avoid `git commit --amend` unless:
  1. User explicitly requested amend OR
  2. Adding edits from pre-commit hook
- Before amending: ALWAYS check authorship (`git log -1 --format='%an %ae'`)
- NEVER commit changes unless user explicitly asks
- Only commit when explicitly asked (don't be proactive)

**Pre-commit Hook Handling**:
If commit fails due to pre-commit hook changes, retry ONCE. If it succeeds but files were modified:
- Check authorship: `git log -1 --format='%an %ae'`
- Check not pushed: `git status` shows "Your branch is ahead"
- If both true: amend your commit
- Otherwise: create NEW commit (never amend other developers' commits)

**Example - Creating a commit**:
```bash
# Step 1: Gather information (parallel)
git status
git diff
git log --oneline -5

# Step 2: Analyze and prepare

# Step 3: Stage and commit (sequential)
git add src/feature.ts tests/feature.test.ts && git commit -m "$(cat <<'EOF'
Add user authentication feature

Implements JWT-based authentication with login/logout endpoints.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)" && git status
```

---

### Creating Pull Requests (via gh command)

**Process**:
1. Run in parallel: `git status`, `git diff`, `git diff [base-branch]...HEAD`
2. Analyze ALL commits (not just latest) from branch divergence point
3. Push to remote if needed: `git push -u origin <branch>`
4. Create PR: `gh pr create --title "..." --body "$(cat <<'EOF'...EOF)"`

**Important**: Look at ALL commits that will be included in PR, not just the latest commit!

**PR Body Format**:
```bash
gh pr create --title "Feature: Add authentication" --body "$(cat <<'EOF'
## Summary
- Implemented JWT-based authentication
- Added login/logout endpoints
- Created middleware for protected routes

## Test plan
- [ ] Test login with valid credentials
- [ ] Test login with invalid credentials
- [ ] Test protected route access
- [ ] Test logout functionality

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Example - Creating a PR**:
```bash
# Step 1: Understand branch changes (parallel)
git status
git diff main...HEAD
git log main..HEAD --oneline

# Step 2: Analyze all commits and draft summary

# Step 3: Push and create PR (sequential)
git push -u origin feature/auth && gh pr create --title "Add authentication system" --body "$(cat <<'EOF'
## Summary
- JWT-based authentication
- Login/logout endpoints
- Auth middleware

## Test plan
- [ ] Manual testing of auth flow
- [ ] Unit tests passing
- [ ] Integration tests passing

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

### Other GitHub Operations

**View PR comments**:
```bash
gh api repos/owner/repo/pulls/123/comments
```

**Work with issues**:
```bash
gh issue list
gh issue create --title "Bug: Login fails" --body "Description..."
```

**Check runs**:
```bash
gh run list
gh run view 123456
```

---

## Background Execution

**When to use**:
- Long-running commands (dev servers, build watchers)
- Commands that produce continuous output
- Commands you want to monitor periodically

**Usage**:
```bash
# Start in background
npm run dev (with run_in_background: true)

# Monitor output
Use BashOutput tool with bash_id

# Kill if needed
Use KillShell tool with shell_id
```

**Note**: Don't need '&' at end when using `run_in_background` parameter.

---

## Bash Command Patterns

### Chaining Commands

**Sequential with dependencies (&&)**:
```bash
mkdir -p dist && npm run build && npm test
```
All commands run only if previous succeeds.

**Sequential without dependencies (;)**:
```bash
echo "Starting..."; npm run build; echo "Done"
```
All commands run regardless of success.

**Parallel (independent commands)**:
In one message:
- npm run lint
- npm run test
- npm run build:check

### Path Handling

**Good** (absolute paths):
```bash
pytest /foo/bar/tests
npm test --prefix /path/to/project
```

**Bad** (using cd):
```bash
cd /foo/bar && pytest tests
```

**Paths with spaces**:
```bash
cd "/Users/name/My Documents"
python3 "/path with spaces/script.py"
```

---

## Bash Tool Decision Matrix

| Task | Use Bash? | Alternative | Reason |
|------|-----------|-------------|--------|
| Read file | NO | Read tool | Specialized tool better |
| Search file contents | NO | Grep tool | Specialized tool better |
| Find files by pattern | NO | Glob tool | Specialized tool better |
| Edit file | NO | Edit tool | Specialized tool better |
| Run tests | YES | - | Terminal operation |
| Build project | YES | - | Terminal operation |
| Git operations | YES | - | Terminal operation |
| Install packages | YES | - | Terminal operation |
| Docker commands | YES | - | Terminal operation |
| Start dev server | YES | - | Terminal operation |

---

## Common Bash Mistakes

1. **Using cat to read files**:
   - Wrong: `cat src/app.ts`
   - Right: `Read src/app.ts`

2. **Using grep to search**:
   - Wrong: `grep "TODO" src/**/*.ts`
   - Right: `Grep pattern: "TODO" glob: "*.ts"`

3. **Using echo to communicate**:
   - Wrong: `echo "I found 3 files"`
   - Right: Output "I found 3 files" in response text

4. **Running dependent commands in parallel**:
   - Wrong: Multiple tool calls for `mkdir dist`, `cp files dist`
   - Right: Single Bash call: `mkdir -p dist && cp files dist`

5. **Not quoting paths with spaces**:
   - Wrong: `cd /path with spaces`
   - Right: `cd "/path with spaces"`
