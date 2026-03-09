# Detailed Memory Location Specifications

## Overview

This document provides comprehensive specifications for all memory file locations, search orders, and loading behavior in Claude Code.

## Memory Loading Order

Claude Code loads memory files from most specific to least specific. More specific locations take precedence over broader ones:

```
1. Managed Policy (Highest Priority)
   System-deployed, cannot be overridden or excluded
   ↓
2. Project Memory
   .claude/CLAUDE.md or ./CLAUDE.md — committed to git, team-shared
   ↓
3. User Memory
   ~/.claude/CLAUDE.md — personal, applies to all projects
   ↓
4. Local Project Memory
   ./CLAUDE.local.md — personal project-specific, NOT committed to git
```

**Conflict behaviour:** If two instructions conflict, Claude may pick one arbitrarily. Review all active CLAUDE.md files and `.claude/rules/` periodically to eliminate contradictions. Use `claudeMdExcludes` in `.claude/settings.local.json` to skip CLAUDE.md files from other teams in monorepos.

**Tree walk behaviour:** When you run Claude Code in a directory, it walks UP the directory tree loading ALL CLAUDE.md (and CLAUDE.local.md) files found at each level — it does not stop at the first match. CLAUDE.md files in subdirectories below your working directory are loaded on-demand when Claude reads files in those subdirectories.

---

## Quick Reference

| Memory Type | Location | Priority | Shared? |
|-------------|----------|----------|---------|
| Managed Policy | System location (OS-dependent) | Highest (1) | Organization-wide |
| Project Memory | `.claude/CLAUDE.md` or `./CLAUDE.md` | High (2) | Team (via git) |
| User Memory | `~/.claude/CLAUDE.md` | Low (3) | Personal only |
| Local Project | `./CLAUDE.local.md` | Low (4) | Personal only (auto-gitignored) |
| Project Rules | `.claude/rules/*.md` | Same as project | Team (via git) |
| User Rules | `~/.claude/rules/*.md` | Loaded before project rules | Personal only |

---

## 1. Managed Policy Memory

### Priority
**Highest** — cannot be overridden or excluded by individual user settings

### Purpose
Organization-wide policies, standards, and compliance requirements enforced across all users on a machine.

### Locations (OS-Dependent)

**macOS:**
```
/Library/Application Support/ClaudeCode/CLAUDE.md
```

**Linux and WSL:**
```
/etc/claude-code/CLAUDE.md
```

**Windows:**
```
C:\Program Files\ClaudeCode\CLAUDE.md
```

### Management
- **Managed By:** System administrators
- **Deployment:** MDM, Group Policy, Ansible, or similar configuration management tools
- **User Access:** Read-only
- **Cannot be excluded:** Unlike regular project CLAUDE.md files, managed policy files cannot be skipped via `claudeMdExcludes`

### Common Contents
- Company-wide coding standards
- Required security practices (e.g., "Never commit secrets")
- Compliance requirements (GDPR, HIPAA, SOC2)
- Approved/prohibited libraries and tools
- Mandatory code review requirements
- Data handling policies

### Example

```markdown
# Enterprise Security Policy

## Security Requirements

### Secrets Management
- NEVER commit API keys, passwords, or tokens to version control
- Use environment variables for all secrets
- Required: Secrets scanning in CI/CD (detect-secrets)

### Dependencies
- All dependencies must be from approved registries
- Automatic security scanning required (Snyk/Dependabot)

## Compliance (GDPR)
- Log all data access for EU users
- Implement data deletion workflows
- User consent required for data collection
```

---

## 2. Project Memory

### Priority
**Second** — overrides user memory but not managed policy

### Purpose
Team-shared, project-specific context committed to version control.

### Locations

Claude Code searches for project memory in your working directory and all ancestor directories:

1. `./.claude/CLAUDE.md` (recommended)
2. `./CLAUDE.md` (alternative)

Both locations are checked at each level as Claude walks up the tree. **All found files are loaded**, not just the first one encountered.

### Recommended Structure
```
your-project/
├── .claude/
│   ├── CLAUDE.md         # Main project instructions
│   └── rules/
│       ├── testing.md    # Testing conventions
│       └── security.md   # Security requirements
├── src/
└── package.json
```

### Sharing via Version Control

```bash
# Create and commit
mkdir -p .claude
touch .claude/CLAUDE.md
git add .claude/CLAUDE.md
git commit -m "docs: add project memory"
```

Team members automatically get it on clone or pull.

---

## 3. User Memory

### Priority
**Third** — applies when no project or managed setting specifies otherwise

### Purpose
Personal preferences that apply across **all projects** on your machine.

### Location
```
~/.claude/CLAUDE.md
```

**Expanded paths:**
- **macOS/Linux:** `/Users/<username>/.claude/CLAUDE.md`
- **Windows:** `C:\Users\<username>\.claude\CLAUDE.md`

### Management
- **Managed By:** Individual user
- **User Access:** Full read/write control
- **Distribution:** Not shared (personal only)

---

## 4. Local Project Memory

### Priority
**Fourth** — personal project overrides that are not shared

### Purpose
Personal project-specific preferences that should NOT be committed to version control.

### Location
```
./CLAUDE.local.md
```

(in the project root, alongside `CLAUDE.md`)

### Key Characteristics
- Automatically added to `.gitignore` by Claude Code when created
- Never shared with teammates
- Loaded alongside project CLAUDE.md files
- Ideal for: sandbox URLs, local server addresses, personal test data, machine-specific settings

### Worktree behaviour
`CLAUDE.local.md` only exists in one worktree. If you work across multiple git worktrees and need personal instructions available in all of them, use a home-directory import in each worktree's CLAUDE.local.md:

```markdown
# Individual Preferences
@~/.claude/my-project-instructions.md
```

---

## 5. Project Rules (.claude/rules/)

### Purpose
Modular, optionally path-scoped instructions for larger projects. Keeps the main CLAUDE.md focused while allowing fine-grained topic files.

### Location
```
.claude/rules/
```

All `.md` files discovered recursively. Supports subdirectories:

```
your-project/
├── .claude/
│   ├── CLAUDE.md
│   └── rules/
│       ├── testing.md          # Loads at launch
│       ├── security.md         # Loads at launch
│       └── frontend/
│           └── components.md   # Loads at launch
```

### Path-Specific Rules

Rules can be scoped to specific files using YAML frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "lib/**/*.ts"
---
# API Development Rules
- All endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

Rules with a `paths` field only load when Claude reads files matching those patterns. Rules without `paths` load at every session launch (same priority as `.claude/CLAUDE.md`).

**Supported glob patterns:**

| Pattern | Matches |
|---------|---------|
| `**/*.ts` | All TypeScript files in any directory |
| `src/**/*` | All files under src/ |
| `*.md` | Markdown files in the project root |
| `src/**/*.{ts,tsx}` | TypeScript and TSX files under src/ |

### Sharing Rules Across Projects (Symlinks)

`.claude/rules/` supports symlinks — both to directories and individual files:

```bash
# Link a shared rule directory
ln -s ~/shared-claude-rules .claude/rules/shared

# Link a single rule file
ln -s ~/company-standards/security.md .claude/rules/security.md
```

Circular symlinks are detected and handled gracefully.

### Sharing
Committed to version control. Part of the team's project configuration.

---

## 6. User-Level Rules (~/.claude/rules/)

### Purpose
Personal rules that apply to every project on your machine. Use for preferences that are not project-specific.

### Location
```
~/.claude/rules/
```

### Loading Order
User-level rules are loaded **before** project rules, so project rules take higher priority.

### Example
```
~/.claude/rules/
├── preferences.md    # Personal coding style preferences
└── workflows.md      # Preferred workflows
```

---

## Memory Loading Behaviour

### Tree Walk

When Claude Code starts in a directory, it:

1. Checks the current working directory for `CLAUDE.md`, `.claude/CLAUDE.md`, and `CLAUDE.local.md`
2. Walks UP each parent directory, checking for the same files at each level
3. Loads ALL files found (does not stop at the first match)
4. Also discovers CLAUDE.md files in subdirectories, loading them on-demand when Claude reads files in those subdirectories

**Example — working directory is `/Users/dev/projects/myapp/src/components/`:**
```
/Users/dev/projects/myapp/src/components/CLAUDE.md  (if exists, loaded)
/Users/dev/projects/myapp/src/CLAUDE.md             (if exists, loaded)
/Users/dev/projects/myapp/.claude/CLAUDE.md         (if exists, loaded)
/Users/dev/projects/myapp/CLAUDE.md                 (if exists, loaded)
/Users/dev/projects/CLAUDE.md                       (if exists, loaded)
... (continues to root)
```

### Monorepo Considerations

In a monorepo, Claude loads CLAUDE.md files at multiple levels:

```
monorepo/
├── .claude/
│   └── CLAUDE.md      (loaded — shared monorepo context)
└── apps/
    └── web/
        └── .claude/
            └── CLAUDE.md  (also loaded — web app specific)
```

Both files are active when working in `apps/web/`. Use `claudeMdExcludes` to skip files from other teams:

```json
{
  "claudeMdExcludes": [
    "**/other-team/.claude/rules/**"
  ]
}
```

Add this to `.claude/settings.local.json` to keep it local to your machine.

Use `@path` imports to combine shared + app-specific memory within a single file if you prefer a single-file approach.

### File Size Guidance
- **Target:** Under 200 lines per CLAUDE.md file
- Longer files consume more context and reduce adherence
- Use `@path` imports or `.claude/rules/` to split large files

### Encoding
- **Required:** UTF-8 encoding
- Other encodings may cause parsing errors

---

## Debugging Memory Loading

### Check What's Loaded

Add a unique identifier to each memory file:

**User memory (`~/.claude/CLAUDE.md`):**
```markdown
<!-- MEMORY_SOURCE: USER -->
# My Preferences
...
```

**Project memory (`.claude/CLAUDE.md`):**
```markdown
<!-- MEMORY_SOURCE: PROJECT_MYAPP -->
# MyApp Project
...
```

Then ask Claude: "What memory sources are loaded?"

### Verify File Locations

```bash
# Check if project memory exists
ls -la .claude/CLAUDE.md
ls -la CLAUDE.md
ls -la CLAUDE.local.md

# Check if user memory exists
ls -la ~/.claude/CLAUDE.md

# Check project rules
ls -la .claude/rules/

# View current directory (where Claude looks first)
pwd
```

### Common Issues

1. **Wrong working directory:** Claude looks for project memory starting from current directory. Verify you're in the project root.
2. **File name typo:** Must be exactly `CLAUDE.md` (case-sensitive). Not `claude.md` or `Claude.md`.
3. **Wrong location:** User memory must be in `~/.claude/`. Project memory must be in project tree.
4. **CLAUDE.local.md missing from .gitignore:** Claude Code should auto-add it, but verify if it was created manually.

---

## File Permissions

### Project Memory
- **Recommended permissions:** 644 (rw-r--r--)
- **Owner:** User's account
- **Must be readable** by the user running Claude Code

### User Memory
- **Recommended permissions:** 644 (rw-r--r--)
- **Owner:** User's account
- **Location:** User's home directory

### Managed Policy
- **Typical permissions:** 644 (rw-r--r--)
- **Owner:** root/administrator
- **Users:** Read-only access

---

## Best Practices Summary

### Do
- Use `.claude/CLAUDE.md` for project memory (recommended)
- Commit project memory and `.claude/rules/` to version control
- Use `CLAUDE.local.md` for personal project-specific preferences
- Keep each CLAUDE.md file under 200 lines
- Use `.claude/rules/` with path-scoped rules for large projects
- Use `@path` imports to pull in additional documentation

### Do Not
- Put team conventions in user memory
- Put personal preferences in project memory
- Use `.clauderc` or `claude.json` (these are not supported memory formats)
- Commit `CLAUDE.local.md` to version control
- Store secrets in any memory file
- Let CLAUDE.md files grow past 200 lines without splitting them
