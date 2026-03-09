# Memory Troubleshooting Guide

## Overview

Comprehensive troubleshooting guide for common memory-related issues in Claude Code.

---

## Issue 1: Memory Not Being Loaded

### Symptoms
- Changes to memory file not reflected in Claude's behavior
- Claude doesn't follow documented conventions
- New memory file seems to be ignored

### Diagnostic Steps

#### Step 1: Verify File Location

**Check project memory:**
```bash
# From your project directory
pwd
ls -la .claude/CLAUDE.md
ls -la CLAUDE.md
```

**Check user memory:**
```bash
ls -la ~/.claude/CLAUDE.md
```

**Expected:** At least one file should exist and be readable.

#### Step 2: Verify File Name

The file name must be **exactly** `CLAUDE.md`:
- ✅ `CLAUDE.md`
- ❌ `claude.md`
- ❌ `Claude.md`
- ❌ `CLAUDE.MD`
- ❌ `claude-memory.md`

**Check with:**
```bash
ls -la | grep -i claude
```

#### Step 3: Check File Permissions

```bash
# Project memory
ls -l .claude/CLAUDE.md
# Should show: -rw-r--r-- or similar (readable)

# User memory
ls -l ~/.claude/CLAUDE.md
# Should show: -rw-r--r-- or similar (readable)
```

**Fix permissions if needed:**
```bash
chmod 644 .claude/CLAUDE.md
chmod 644 ~/.claude/CLAUDE.md
```

#### Step 4: Verify File Encoding

Memory files must be UTF-8 encoded.

**Check encoding:**
```bash
file -I .claude/CLAUDE.md
# Should show: charset=utf-8
```

**Convert if needed:**
```bash
iconv -f ISO-8859-1 -t UTF-8 CLAUDE.md > CLAUDE.utf8.md
mv CLAUDE.utf8.md CLAUDE.md
```

#### Step 5: Check for Syntax Errors

While CLAUDE.md is markdown (forgiving), certain errors can cause issues:

**Common problems:**
- Unclosed code blocks (missing \`\`\`)
- Malformed @path imports
- Special characters in headers

**Validate markdown:**
```bash
# Using markdownlint if installed
markdownlint CLAUDE.md

# Manual check
cat CLAUDE.md | grep '```' | wc -l
# Should be even number (each block opens and closes)
```

#### Step 6: Restart Claude Code

After making changes:
1. Save the memory file
2. Close Claude Code completely
3. Restart Claude Code
4. Test again

### Solutions

**Solution 1: File Not Found**
```bash
# Create the file in correct location
mkdir -p .claude
touch .claude/CLAUDE.md
# Edit with your preferred editor
```

**Solution 2: Wrong Permissions**
```bash
chmod 644 .claude/CLAUDE.md
```

**Solution 3: Wrong Encoding**
```bash
# Save file as UTF-8 in your editor
# Or convert as shown above
```

**Solution 4: Wrong Location**
```bash
# Move to correct location
mv CLAUDE.md .claude/CLAUDE.md
git add .claude/CLAUDE.md
git commit -m "docs: move memory to correct location"
```

**Solution 5: Cache Issue**
```bash
# Clear cache (if applicable)
rm -rf ~/.cache/claude-code
# Restart Claude Code
```

---

## Issue 2: Memory Conflicts

### Symptoms
- Conflicting instructions from different memory files
- Unclear which instruction takes precedence
- Unexpected behavior due to memory overrides

### Understanding Priority

Remember the hierarchy:
1. **Enterprise Policy** (highest)
2. **Project Memory**
3. **User Memory**
4. **Local Project** (deprecated, lowest)

**Higher priority overrides lower priority.**

### Diagnostic Steps

#### Step 1: Identify All Loaded Memory

Check which memory files exist:

```bash
# Enterprise (varies by system)
ls -la /Library/Application\ Support/Claude/enterprise-policy.md  # macOS
ls -la /etc/claude/enterprise-policy.md  # Linux

# Project
ls -la .claude/CLAUDE.md
ls -la CLAUDE.md

# User
ls -la ~/.claude/CLAUDE.md
```

#### Step 2: Search for Conflicting Instructions

Example: If you want to use tabs but Claude uses spaces.

**Search all memory files:**
```bash
# Project memory
grep -i "indent\|tab\|space" .claude/CLAUDE.md

# User memory
grep -i "indent\|tab\|space" ~/.claude/CLAUDE.md

# Enterprise (if accessible)
grep -i "indent\|tab\|space" /etc/claude/enterprise-policy.md
```

#### Step 3: Determine Which Takes Precedence

**Example scenario:**
- Enterprise: "Use 2 spaces for indentation"
- Project: "Use 4 spaces for indentation"
- User: "Use tabs for indentation"

**Result:** Enterprise policy wins (uses 2 spaces)

### Solutions

**Solution 1: Align with Higher Priority**

If enterprise policy conflicts with your preference:
- **Action:** Accept enterprise policy (you cannot override it)
- **Alternative:** Request policy change through proper channels

**Solution 2: Move Settings to Correct Level**

Team convention belongs in project memory, not user:
```bash
# Remove from user memory
vim ~/.claude/CLAUDE.md
# Delete team-specific settings

# Add to project memory
vim .claude/CLAUDE.md
# Add team-specific settings

git add .claude/CLAUDE.md
git commit -m "docs: move team settings to project memory"
```

**Solution 3: Use More Specific Instructions**

Instead of conflicting rules, make them contextual:

**Bad (conflicting):**
```markdown
# User memory
Use tabs for indentation

# Project memory
Use 2 spaces for indentation
```

**Good (contextual):**
```markdown
# User memory
For personal projects, prefer tabs

# Project memory
For this project, always use 2 spaces (enforced by prettier)
```

Project memory (higher priority) wins, but user memory doesn't create conflict.

---

## Issue 3: Too Much Memory

### Symptoms
- Memory file is very large (>10KB)
- Claude Code loads slowly
- Hard to maintain and navigate
- Difficult to find relevant information

### Diagnostic Steps

#### Step 1: Check File Size

```bash
# Check size in bytes
wc -c .claude/CLAUDE.md

# Check size in lines
wc -l .claude/CLAUDE.md

# Human-readable size
ls -lh .claude/CLAUDE.md
```

**Guidelines:**
- Under 5KB: Excellent
- 5-10KB: Good
- 10-20KB: Consider refactoring
- Over 20KB: Definitely refactor

#### Step 2: Identify Large Sections

```bash
# Count lines per section (manual analysis)
grep -n "^##" .claude/CLAUDE.md
# Shows line numbers of each ## heading
```

### Solutions

**Solution 1: Extract with @path Imports**

Move large sections to separate files.

**Before:**
```markdown
# Project Memory

## Architecture
[300 lines of architecture documentation]

## API Reference
[500 lines of API documentation]
```

**After:**

CLAUDE.md:
```markdown
# Project Memory

## Architecture
@docs/architecture.md

## API Reference
@docs/api-reference.md
```

Create files:
```bash
mkdir -p docs
# Move content to docs/architecture.md and docs/api-reference.md
```

**Solution 2: Remove Outdated Information**

```bash
# Review and remove:
# - Deprecated patterns
# - Old version information
# - Superseded conventions
# - Unused examples
```

**Solution 3: Consolidate Repetitive Content**

**Before:**
```markdown
## TypeScript Conventions
- Use strict mode
- Explicit return types
- No any types

## JavaScript Conventions
- Use strict mode
- Explicit return types
- No any types
```

**After:**
```markdown
## Code Conventions (TypeScript/JavaScript)
- Use strict mode
- Explicit return types
- No any types
```

**Solution 4: Use Tables Instead of Prose**

**Before (verbose):**
```markdown
The dev command starts the development server. The test command runs
the test suite. The build command creates a production build.
```

**After (compact):**
```markdown
| Command | Purpose |
|---------|---------|
| `npm run dev` | Start development server |
| `npm test` | Run test suite |
| `npm run build` | Create production build |
```

---

## Issue 4: Memory Not Specific Enough

### Symptoms
- Claude doesn't follow memory instructions consistently
- Instructions are vague or open to interpretation
- Behavior varies from expected

### Diagnostic Examples

**Symptom:** "Claude doesn't use my preferred error handling pattern"

**Problem in memory:**
```markdown
## Error Handling
Handle errors properly.
```

**Why it fails:** Too vague. What does "properly" mean?

### Solutions

**Solution 1: Be Specific and Prescriptive**

**Bad:**
```markdown
Use good naming conventions.
```

**Good:**
```markdown
## Naming Conventions
- Variables: camelCase (`userName`, `isActive`)
- Constants: UPPER_SNAKE_CASE (`API_BASE_URL`, `MAX_RETRIES`)
- Components: PascalCase (`UserProfile`, `LoginForm`)
- Files: Match export (`UserProfile.tsx` exports `UserProfile`)
```

**Solution 2: Provide Code Examples**

**Bad:**
```markdown
Use try-catch for error handling.
```

**Good:**
```markdown
## Error Handling Pattern

All async functions must use this pattern:

\`\`\`typescript
async function fetchData<T>(url: string): Promise<T> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(\`HTTP \${response.status}: \${response.statusText}\`);
    }
    return await response.json();
  } catch (error) {
    logger.error('Fetch failed', { url, error });
    throw error; // Re-throw after logging
  }
}
\`\`\`
```

**Solution 3: Include Decision Criteria**

**Bad:**
```markdown
Organize your files well.
```

**Good:**
```markdown
## File Organization Rules

- **Components:** `src/components/{ComponentName}/{ComponentName}.tsx`
- **Hooks:** `src/hooks/use{HookName}.ts`
- **Utils:** `src/utils/{category}/{functionName}.ts`
- **Types:** `src/types/{domain}.ts`

Tests co-located with source:
- `Component.tsx` → `Component.test.tsx` (same directory)
```

**Solution 4: Add "Why" Context**

**Bad:**
```markdown
Use Zustand for state management.
```

**Good:**
```markdown
## State Management

Use Zustand instead of Redux:
- **Why:** Simpler API, less boilerplate
- **Why:** Better TypeScript support
- **Why:** Smaller bundle size (3KB vs 40KB+)

Pattern:
\`\`\`typescript
export const useStore = create<StoreState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
}));
\`\`\`
```

---

## Issue 5: @path Imports Not Working

### Symptoms
- Content from imported files not appearing
- Errors about missing files
- Imports seem to be ignored

### Diagnostic Steps

#### Step 1: Verify Import Syntax

**Correct syntax:**
```markdown
@docs/api-reference.md
@reference/troubleshooting.md
@templates/
```

**Incorrect syntax:**
```markdown
@/docs/api-reference.md          ← Extra /
docs/api-reference.md            ← Missing @
@docs/api-reference              ← Missing .md
\`@docs/api-reference.md\`       ← In code block (ignored)
```

#### Step 2: Check File Exists

```bash
# From CLAUDE.md location
ls -la docs/api-reference.md
# Should exist and be readable
```

#### Step 3: Verify Relative Path

@path imports are **relative to the memory file**, not project root.

**Example:**
```
project/
├── .claude/
│   └── CLAUDE.md        (contains @docs/api.md)
└── docs/
    └── api.md
```

**Correct path from `.claude/CLAUDE.md`:**
```markdown
@../docs/api.md
```

**Why:** `.claude/CLAUDE.md` needs to go up one level to reach `docs/`

#### Step 4: Check Import Depth

Maximum recursion depth: 5 hops

```
CLAUDE.md
  → @file1.md (hop 1)
    → @file2.md (hop 2)
      → @file3.md (hop 3)
        → @file4.md (hop 4)
          → @file5.md (hop 5)
            → @file6.md (hop 6) ← NOT LOADED
```

### Solutions

**Solution 1: Fix Path**

```bash
# Check relative path from CLAUDE.md
cd .claude  # Where CLAUDE.md is
ls ../docs/api.md  # Should work

# If it works, use @../docs/api.md
```

**Solution 2: Move Files**

Organize so imports are simpler:

**Before:**
```
project/
├── .claude/
│   └── CLAUDE.md
└── documentation/
    └── deep/
        └── nested/
            └── api.md
```

Import: `@../documentation/deep/nested/api.md` (complex)

**After:**
```
project/
├── .claude/
│   ├── CLAUDE.md
│   └── docs/
│       └── api.md
```

Import: `@docs/api.md` (simple)

**Solution 3: Reduce Recursion Depth**

If hitting 5-hop limit, flatten the import structure.

**Solution 4: Verify Not in Code Block**

Imports in code blocks are **ignored** (by design):

```markdown
# This import works:
@docs/api.md

# This import is ignored:
\`\`\`markdown
@docs/api.md
\`\`\`

# This inline code is also ignored:
Use \`@path/file.md\` syntax
```

---

## Issue 6: Team Members Not Getting Memory

### Symptoms
- New team member doesn't have project conventions
- Team member's Claude behaves differently
- Memory working for you but not others

### Diagnostic Steps

#### Step 1: Verify Memory Is in Version Control

```bash
git status .claude/CLAUDE.md
# Should NOT show as untracked
# Should be committed to repo
```

#### Step 2: Check .gitignore

```bash
cat .gitignore | grep claude
# Should NOT ignore .claude/CLAUDE.md
```

**Bad (excludes project memory):**
```
.claude/
```

**Good (allows project memory, excludes local files):**
```
.claude/local.md
.claude/personal.md
```

#### Step 3: Verify Team Member Pulled Latest

```bash
# Team member runs:
git pull
ls -la .claude/CLAUDE.md
# Should exist after pull
```

### Solutions

**Solution 1: Add to Version Control**

```bash
# If currently ignored
git add -f .claude/CLAUDE.md

# If never tracked
git add .claude/CLAUDE.md

git commit -m "docs: add project memory"
git push
```

**Solution 2: Fix .gitignore**

Update .gitignore:
```bash
# Remove this if present:
# .claude/

# Add specific ignores if needed:
.claude/local.md
.claude/.env
```

**Solution 3: Document in README**

Add to project README:
```markdown
## Setup

1. Clone repository
2. Install dependencies
3. **Project memory is in `.claude/CLAUDE.md`** (automatically loaded by Claude Code)
```

**Solution 4: Team Member Restart**

After pulling, team member must:
1. Close Claude Code completely
2. Restart Claude Code
3. Memory now loaded

---

## Issue 7: Memory Changes Not Taking Effect

### Symptoms
- Edited memory file but changes not reflected
- Claude still using old patterns
- Changes seem to be ignored

### Solutions

**Solution 1: Restart Claude Code**

Most common solution:
1. Save memory file
2. Close Claude Code completely
3. Reopen Claude Code
4. Test again

**Solution 2: Check Auto-Reload Settings**

Some IDEs/editors support auto-reload:
- VS Code: Check Claude extension settings
- JetBrains: Check plugin settings

**Solution 3: Verify Saved**

```bash
# Check last modified time
ls -l .claude/CLAUDE.md

# View actual content
cat .claude/CLAUDE.md | head -20
```

**Solution 4: Clear Cache**

```bash
# If applicable (varies by installation)
rm -rf ~/.cache/claude-code
# Restart
```

**Solution 5: Check Priority**

Your changes might be overridden by higher-priority memory:
- Enterprise policy overrides everything
- Project memory overrides user memory

Check if conflicting instruction exists in higher-priority memory.

---

## Common Error Messages

### "Memory file not found"

**Cause:** File doesn't exist at expected location

**Fix:**
```bash
mkdir -p .claude
touch .claude/CLAUDE.md
```

### "Invalid @path import"

**Cause:** Referenced file doesn't exist or path is wrong

**Fix:**
```bash
# Check file exists
ls -la docs/api.md

# Fix path in CLAUDE.md
# Ensure relative to CLAUDE.md location
```

### "Memory file too large"

**Cause:** File exceeds recommended size

**Fix:** Extract content using @path imports (see Issue 3)

### "Circular import detected"

**Cause:** File A imports File B, which imports File A

**Fix:** Restructure to remove circular dependency

---

## Prevention Checklist

Avoid common issues by following these practices:

### When Creating Memory
- [ ] Use correct file name: `CLAUDE.md`
- [ ] Use UTF-8 encoding
- [ ] Set permissions: `chmod 644`
- [ ] Validate markdown syntax
- [ ] Test imports work

### When Sharing Team Memory
- [ ] Commit to version control
- [ ] Check not in .gitignore
- [ ] Document in README
- [ ] Notify team to pull
- [ ] Verify team members can access

### When Using @path
- [ ] Use relative paths
- [ ] Verify files exist
- [ ] Keep under 5-hop depth
- [ ] Don't use in code blocks
- [ ] Test imports load

### When Editing
- [ ] Save file
- [ ] Restart Claude Code
- [ ] Test changes
- [ ] Update version history
- [ ] Commit changes (if project memory)

---

## Getting Help

If issues persist after troubleshooting:

1. **Check documentation:** https://code.claude.com/docs/en/memory
2. **Verify installation:** Ensure Claude Code is up to date
3. **Collect diagnostics:**
   ```bash
   ls -la .claude/CLAUDE.md
   ls -la ~/.claude/CLAUDE.md
   cat .claude/CLAUDE.md | head -50
   ```
4. **Report issue:** Include diagnostics and specific symptoms

---

## Quick Diagnostic Script

Run this to check common issues:

```bash
#!/bin/bash
echo "=== Memory Diagnostic ==="
echo ""
echo "Working Directory:"
pwd
echo ""
echo "Project Memory:"
ls -lh .claude/CLAUDE.md 2>/dev/null || ls -lh CLAUDE.md 2>/dev/null || echo "NOT FOUND"
echo ""
echo "User Memory:"
ls -lh ~/.claude/CLAUDE.md 2>/dev/null || echo "NOT FOUND"
echo ""
echo "Project Memory Size:"
wc -l .claude/CLAUDE.md 2>/dev/null || wc -l CLAUDE.md 2>/dev/null || echo "N/A"
echo ""
echo "Git Status:"
git status .claude/CLAUDE.md 2>/dev/null || git status CLAUDE.md 2>/dev/null || echo "Not in git"
echo ""
echo "=== End Diagnostic ==="
```

Save as `check-memory.sh`, run with `bash check-memory.sh`
