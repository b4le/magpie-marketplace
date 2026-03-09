# Memory Maintenance Guide

## Overview

Memory files require regular maintenance to stay effective. This guide provides schedules, checklists, and best practices for keeping memory current and useful.

---

## Maintenance Philosophy

### Core Principles

1. **Living Documentation** - Memory should reflect current reality, not past intentions
2. **Regular Reviews** - Scheduled maintenance prevents decay
3. **Team Responsibility** - Entire team keeps memory current
4. **Version History** - Track what changed and why
5. **Ruthless Pruning** - Remove outdated content aggressively

### Signs Memory Needs Maintenance

- Claude doesn't follow documented patterns (patterns changed but memory didn't)
- Team members ask questions answered in memory (information is outdated or hard to find)
- File size growing significantly (accumulating without pruning)
- Conflicting instructions (old and new patterns both documented)
- Referencing deprecated tools or libraries

---

## Maintenance Schedule

### Daily Maintenance (Lightweight)

**Who:** Individual developers as they work

**Time:** 2-5 minutes when relevant

**Tasks:**
- [ ] Note outdated sections (don't fix immediately, just flag)
- [ ] Update version numbers when dependencies change
- [ ] Add new patterns as they're established
- [ ] Fix obvious typos or errors

**Example workflow:**
```bash
# Just merged a PR that changes a pattern
# Quickly update CLAUDE.md

vim .claude/CLAUDE.md
# Update the pattern
git add .claude/CLAUDE.md
git commit --amend --no-edit
# Or create separate commit if PR already merged
```

---

### Weekly Maintenance (Regular)

**Who:** Rotating team member or tech lead

**Time:** 15-30 minutes

**Tasks:**
- [ ] Review flagged outdated sections
- [ ] Update command documentation
- [ ] Add new team agreements
- [ ] Remove deprecated patterns
- [ ] Update dependencies and versions

**Checklist:**

```markdown
## Weekly Memory Maintenance - [Date]

### Commands
- [ ] All commands still work?
- [ ] Any new commands to document?
- [ ] Any removed commands to delete?

### Dependencies
- [ ] Package versions current?
- [ ] Any major version updates?
- [ ] Deprecated packages removed?

### Patterns
- [ ] New patterns from this week?
- [ ] Deprecated patterns to remove?
- [ ] Conflicting guidance to resolve?

### Links
- [ ] All @path imports still work?
- [ ] External links still valid?
- [ ] Documentation links current?

### Notes
[Any observations or planned changes]
```

**Example session:**
```bash
# Start weekly maintenance
cd project
vim .claude/CLAUDE.md

# Check commands still work
npm run dev     # ✓ Works
npm run build   # ✓ Works
npm run deploy  # ✗ Changed to `npm run release`

# Update in CLAUDE.md
# Change "npm run deploy" → "npm run release"

# Check dependencies
cat package.json | grep react
# "react": "18.2.0" → Update to 18.3.0

# Commit changes
git add .claude/CLAUDE.md
git commit -m "docs: weekly memory maintenance - update commands and deps"
git push
```

---

### Monthly Maintenance (Comprehensive)

**Who:** Team lead or assigned owner

**Time:** 1-2 hours

**Tasks:**
- [ ] Full file review
- [ ] Reorganize structure if needed
- [ ] Update architecture documentation
- [ ] Align with team changes (new members, role changes)
- [ ] Extract large sections to @path imports
- [ ] Review and update version history
- [ ] Ensure consistency with project reality

**Comprehensive checklist:**

```markdown
## Monthly Memory Maintenance - [Month Year]

### Content Audit
- [ ] All sections still relevant?
- [ ] Any missing topics to add?
- [ ] Information accurate and current?
- [ ] Examples still work?
- [ ] Code samples up to date?

### Structure Review
- [ ] File under 10KB (or using @path)?
- [ ] Logical organization?
- [ ] Easy to navigate?
- [ ] Consistent formatting?
- [ ] Clear headings?

### Quality Check
- [ ] No conflicting instructions?
- [ ] Specific, not vague?
- [ ] Includes "why" not just "what"?
- [ ] Examples are concrete?
- [ ] Commands are copy-pasteable?

### Team Alignment
- [ ] Reflects current team size?
- [ ] Reflects current roles?
- [ ] Reflects current workflows?
- [ ] New team members onboarded?
- [ ] Feedback incorporated?

### Technical Accuracy
- [ ] Dependencies current?
- [ ] APIs still available?
- [ ] Tools still in use?
- [ ] File paths correct?
- [ ] Links not broken?

### Action Items
- [ ] Schedule any needed restructuring
- [ ] Assign updates to team members
- [ ] Plan @path extraction if needed
```

---

### Quarterly Maintenance (Strategic)

**Who:** Tech lead + team collaboration

**Time:** 2-4 hours (team meeting + async work)

**Tasks:**
- [ ] Major structure review
- [ ] Alignment with project evolution
- [ ] Import/export optimization
- [ ] Team retrospective on memory effectiveness
- [ ] Plan improvements for next quarter

**Process:**

1. **Preparation (async, before meeting)**
   ```bash
   # Collect metrics
   wc -l .claude/CLAUDE.md
   git log --since="3 months ago" .claude/CLAUDE.md
   # Review change frequency, contributors
   ```

2. **Team meeting (1-2 hours)**
   - What's working well?
   - What's confusing or missing?
   - What's outdated or wrong?
   - Structural improvements needed?

3. **Implementation (async, after meeting)**
   - Implement agreed changes
   - Restructure if needed
   - Extract to @path imports
   - Update examples

4. **Review (1 week later)**
   - Team reviews changes
   - Approves or suggests refinements
   - Merges updates

---

## Maintenance Tasks by Category

### Updating Dependencies

**When:** After any dependency update

**How:**
```markdown
## Technology Stack

Before:
- React 18.2.0
- TypeScript 5.0.0

After:
- React 18.3.0
- TypeScript 5.3.0

## Version History

### 2025-01-15
- Updated React 18.2 → 18.3
- Updated TypeScript 5.0 → 5.3
- No breaking changes
```

---

### Removing Deprecated Content

**Identify deprecated content:**
- Tools no longer used
- Patterns explicitly superseded
- Old version documentation (when fully migrated)
- Temporary workarounds (when proper fix deployed)

**How to remove:**

**Bad (leaves confusion):**
```markdown
## State Management

~~Use Redux~~ (deprecated)

Use Zustand instead
```

**Good (clean removal):**
```markdown
## State Management

Use Zustand for all state management:
[Current pattern documentation]

## Version History

### 2025-01-15
- Removed Redux documentation (fully migrated to Zustand)
```

---

### Updating File Structure

**When structure changes:**

**Before:**
```markdown
## File Structure
\`\`\`
src/
├── components/
├── pages/
└── utils/
\`\`\`
```

**After (structure evolved):**
```markdown
## File Structure
\`\`\`
src/
├── features/         # Feature-based organization (new)
│   ├── auth/
│   ├── dashboard/
│   └── settings/
├── shared/           # Shared components (renamed from components/)
└── utils/
\`\`\`

## Version History

### 2025-01-15
- Reorganized to feature-based structure
- Moved shared components to shared/
- Migration guide: @docs/migrations/feature-based-reorg.md
```

---

### Managing @path Imports

**Audit imports monthly:**

```bash
# List all @path imports
grep -r "@" .claude/CLAUDE.md

# Check each file exists
grep -r "@" .claude/CLAUDE.md | while read line; do
  file=$(echo "$line" | grep -o '@[^ ]*' | sed 's/@//')
  if [ ! -f ".claude/$file" ]; then
    echo "MISSING: $file"
  fi
done
```

**Optimize import structure:**

**Before (redundant imports):**
```markdown
## Architecture
@docs/architecture.md

## Frontend Architecture
@docs/frontend-arch.md

## Backend Architecture
@docs/backend-arch.md
```

**After (consolidated):**
```markdown
## Architecture
@docs/architecture.md
(Now includes frontend and backend in subsections)
```

---

## Version History Best Practices

### Format

```markdown
## Version History

### YYYY-MM-DD
- [Category] Brief description of change
- [Category] Another change

### Earlier Date
- Initial version
```

### Categories

- **Added:** New content
- **Updated:** Modified existing content
- **Removed:** Deleted content
- **Fixed:** Corrected errors
- **Migrated:** Moved to new location/format

### Example

```markdown
## Version History

### 2025-01-15
- [Updated] React 18.2 → 18.3
- [Added] Performance monitoring guidelines
- [Removed] Redux documentation (migrated to Zustand)

### 2025-01-01
- [Updated] TypeScript 5.0 → 5.3
- [Fixed] Incorrect build command

### 2024-12-15
- [Migrated] Large architecture section to @docs/architecture.md
- [Added] New API patterns

### 2024-12-01
- Initial project memory created
```

---

## Team Collaboration on Maintenance

### Distributed Ownership

**Assign sections to team members:**

```markdown
# Project Memory

## Ownership

- **Architecture:** @alice
- **Frontend Patterns:** @bob
- **Backend Patterns:** @carol
- **DevOps:** @dave
- **Testing:** @eve

Each owner responsible for keeping their section current.
Last reviewed: [Date]
```

### Pull Request Reviews

**When reviewing PRs that change patterns:**

```markdown
PR Checklist:
- [ ] Code changes
- [ ] Tests updated
- [ ] CLAUDE.md updated (if pattern changes)
- [ ] Version history updated
```

**Example PR comment:**
```
This PR changes our error handling pattern. Please update .claude/CLAUDE.md to reflect the new pattern before merging.
```

---

## Migration Strategies

### Small Changes

**Process:**
1. Make change
2. Update immediately
3. Commit with code changes

```bash
# Making a small change
vim src/utils/api.ts
vim .claude/CLAUDE.md  # Update pattern
git add src/utils/api.ts .claude/CLAUDE.md
git commit -m "refactor: improve error handling pattern"
```

---

### Large Reorganizations

**Process:**
1. Plan structure
2. Create tracking issue
3. Migrate in phases
4. Keep both patterns during transition
5. Remove old pattern when migration complete

**Example transition:**

```markdown
## State Management

### Current (Zustand) - Use for New Code

[New pattern documentation]

### Legacy (Redux) - Deprecated, Migrate ASAP

Still in use in:
- Dashboard (TICKET-123)
- Settings (TICKET-124)

Migration guide: @docs/migrations/redux-to-zustand.md

Target completion: 2025-03-01

## Version History

### 2025-01-15
- Added Zustand as new standard
- Marked Redux as deprecated
- Created migration guide
```

After migration complete:

```markdown
## State Management

Use Zustand for all state management:

[Pattern documentation]

## Version History

### 2025-03-01
- Removed Redux documentation (migration complete)

### 2025-01-15
- Added Zustand as new standard
- Marked Redux as deprecated
```

---

## Quality Metrics

### Size Monitoring

**Target:** Keep main file under 10KB

```bash
# Check size regularly
ls -lh .claude/CLAUDE.md

# Monitor over time
git log --all --pretty=format:"%h %ai" -- .claude/CLAUDE.md | while read commit date time tz; do
  size=$(git show $commit:.claude/CLAUDE.md | wc -c)
  echo "$date $size"
done
```

**If growing too large:**
- Extract to @path imports
- Remove redundant content
- Consolidate similar sections

---

### Update Frequency

**Healthy update frequency:**
- Weekly: 1-3 commits
- Monthly: 4-12 commits
- Quarterly: 15-40 commits

**Too infrequent (red flag):**
- Monthly: 0 commits
- Project is evolving but memory isn't

**Too frequent (potential issue):**
- Daily: Multiple commits
- May indicate instability or micro-management

---

### Effectiveness Metrics

**Measure effectiveness:**

1. **Onboarding time:** New team members productive faster?
2. **Question frequency:** Fewer questions about conventions?
3. **Pattern adherence:** Code reviews find fewer convention violations?
4. **Self-service:** Team finds answers in memory vs asking?

**Quarterly check:**
```markdown
## Effectiveness Review - Q1 2025

### Metrics
- New developer onboarding: 3 days (previous: 5 days) ↑
- Convention questions: 12/month (previous: 25/month) ↑
- Memory references in code reviews: 18 (using memory as reference) ↑

### Feedback
- "Memory helped me understand project structure quickly" - New hire
- "Would like more examples for testing patterns" - Team feedback

### Actions
- Add more testing examples
- Create onboarding checklist
```

---

## Automation Opportunities

### Automated Checks

**Pre-commit hook:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check CLAUDE.md size
size=$(wc -c < .claude/CLAUDE.md)
if [ $size -gt 10240 ]; then  # 10KB
  echo "Warning: CLAUDE.md is larger than 10KB ($size bytes)"
  echo "Consider extracting content to @path imports"
fi

# Check for broken @path imports
grep -r "@" .claude/CLAUDE.md | while read line; do
  file=$(echo "$line" | grep -o '@[^ ]*' | sed 's/@//')
  if [ ! -f ".claude/$file" ]; then
    echo "Error: Missing import: $file"
    exit 1
  fi
done
```

### CI Checks

**GitHub Actions:**
```yaml
name: Memory Checks

on: [pull_request]

jobs:
  check-memory:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Check CLAUDE.md exists
        run: |
          if [ ! -f .claude/CLAUDE.md ]; then
            echo "Error: .claude/CLAUDE.md not found"
            exit 1
          fi

      - name: Check @path imports
        run: |
          cd .claude
          for import in $(grep -o '@[^ ]*' CLAUDE.md); do
            file="${import#@}"
            if [ ! -f "$file" ]; then
              echo "Error: Missing import: $file"
              exit 1
            fi
          done

      - name: Check file size
        run: |
          size=$(wc -c < .claude/CLAUDE.md)
          if [ $size -gt 10240 ]; then
            echo "Warning: CLAUDE.md is ${size} bytes (over 10KB)"
          fi
```

---

## Troubleshooting Maintenance Issues

### Issue: Memory Updates Not Being Made

**Symptoms:** Team changes patterns but doesn't update memory

**Solutions:**
1. Add CLAUDE.md to PR template checklist
2. Make memory updates part of code review
3. Assign ownership (specific people responsible)
4. Automate reminders (CI comment on PRs)

---

### Issue: Too Much Duplication

**Symptoms:** Same information in multiple places

**Solutions:**
1. Consolidate into single source of truth
2. Use @path imports to reference, not duplicate
3. Link to canonical location
4. Remove redundant copies

---

### Issue: Conflicting Information

**Symptoms:** Different sections give different guidance

**Solutions:**
1. Search for all instances of topic
2. Determine correct current pattern
3. Update all instances or consolidate
4. Add version history noting resolution

---

## Best Practices Summary

### ✅ Do

- Schedule regular maintenance
- Track changes in version history
- Remove outdated content immediately
- Use @path imports for large sections
- Assign ownership of sections
- Incorporate memory updates into workflow
- Measure effectiveness periodically

### ❌ Don't

- Let memory become stale
- Accumulate without pruning
- Keep deprecated and current patterns together long-term
- Ignore broken @path imports
- Skip version history
- Update without team communication
- Keep memory "just because"

---

## Quick Maintenance Checklist

Copy this for regular use:

```markdown
## Memory Maintenance - [Date]

### Quick Checks
- [ ] All commands still work
- [ ] Dependencies up to date
- [ ] No broken @path imports
- [ ] File size reasonable (<10KB)
- [ ] No obvious outdated content

### Content Review
- [ ] Recent changes reflected
- [ ] Deprecated content removed
- [ ] New patterns documented
- [ ] Examples still accurate

### Cleanup
- [ ] Version history updated
- [ ] Changes committed
- [ ] Team notified if significant changes

### Next Actions
- [ ] [Any follow-up tasks]
```

---

## Resources

- Main memory documentation: https://code.claude.com/docs/en/memory
- Project memory examples: @examples/
- Advanced patterns: @reference/advanced-patterns.md
