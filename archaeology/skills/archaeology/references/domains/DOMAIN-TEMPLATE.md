> **Reference only.** This file documents all available sections for a domain definition.
> To create a new domain, copy an existing domain file — see ADDING-DOMAINS.md for the quick-start guide.

# Domain: [DOMAIN_NAME]

**Status:** `draft` | `active` | `deprecated`
**Maintainer:** [GitHub handle or name]
**Last Updated:** [YYYY-MM-DD]

---

## Overview

**Purpose:** [1-2 sentences describing what this domain covers and why it matters]

**Scope:** [What falls inside/outside this domain's boundaries]

**Key Characteristics:**
- [Bullet points describing what makes this domain distinct]
- [Technical patterns, file types, or structural markers]
- [Common use cases or scenarios]

---

## Search Strategy

### Primary Indicators

[Most reliable signals that content belongs to this domain]

**Required patterns:**
```text
[Grep patterns that MUST be present]
```

**File types:**
- [Extensions or naming patterns]

**Structural markers:**
- [Import statements, class patterns, config structures]

### Secondary Indicators

[Supporting evidence, helpful but not definitive]

**Common co-occurrences:**
- [Patterns that often appear together]

**Naming conventions:**
- [Variable names, function prefixes, file naming]

### Exclusion Filters

[Patterns that indicate content is NOT in this domain despite surface similarities]

**Anti-patterns:**
```text
[Grep patterns that should exclude results]
```

**Disambiguation rules:**
- [How to distinguish from similar domains]

---

## Search Commands

### Discovery Phase

```bash
# Find potential domain files
grep -r "PATTERN" --include="*.ext" .

# Count occurrences
grep -r "PATTERN" --include="*.ext" . | wc -l

# Find by file structure
find . -type f -name "pattern*" -o -name "*suffix"
```

### Validation Phase

```bash
# Verify matches contain required elements
grep -l "PRIMARY_PATTERN" $(find . -name "*.ext") | \
  xargs grep -l "SECONDARY_PATTERN"

# Exclude false positives
grep -r "PATTERN" --include="*.ext" . | \
  grep -v "EXCLUDE_PATTERN"
```

### Extraction Phase

```bash
# Capture relevant sections
grep -A 10 -B 5 "PATTERN" file.ext

# Extract structured data
awk '/START_PATTERN/,/END_PATTERN/' file.ext
```

---

## Content Categories

### Category 1: [Name]

**What it contains:**
[Description of this content type]

**Where to find:**
- [File paths or patterns]

**Search patterns:**
```bash
grep -r "specific_pattern" --include="*.ext"
```

**Analysis focus:**
- [What to look for in these files]
- [Questions to answer]

### Category 2: [Name]

[Repeat structure above]

---

## Analysis Framework

### Key Questions

For each discovered artifact, determine:

1. **Context:** [What was the problem being solved?]
2. **Decision:** [What approach was chosen?]
3. **Rationale:** [Why this approach? (if documented)]
4. **Evolution:** [How has this changed over time?]
5. **Dependencies:** [What does this connect to?]

### Extraction Checklist

- [ ] Identify primary purpose
- [ ] Extract configuration/parameters
- [ ] Document dependencies
- [ ] Note patterns/anti-patterns
- [ ] Capture inline documentation
- [ ] Link to related artifacts
- [ ] Flag deprecated/experimental code

### Output Structure

For this domain, organize findings as:

```markdown
## [Artifact Name]

**Location:** `path/to/artifact`
**Type:** [Category]
**Status:** [Active/Deprecated/Experimental]

**Purpose:**
[What this does]

**Key Details:**
- [Important configuration]
- [Critical dependencies]
- [Notable patterns]

**Context:**
[When/why this was created, if discoverable]

**Related Artifacts:**
- [Links to connected components]
```

---

## Examples

### Example 1: [Scenario Name]

**Situation:**
[Real-world search scenario in this domain]

**Search approach:**
```bash
# Step 1: Find candidates
grep -r "pattern" --include="*.ext" .

# Step 2: Filter
grep -l "pattern" $(find . -name "*.ext") | xargs grep -l "validator"

# Step 3: Extract
for file in $(grep -l "pattern" *.ext); do
  echo "=== $file ==="
  grep -A 5 "pattern" "$file"
done
```

**Expected results:**
[What you'd find and how to interpret it]

### Example 2: [Scenario Name]

[Repeat structure]

---

## Common Patterns

### Pattern 1: [Name]

**Description:**
[What this pattern is]

**When it appears:**
[Context where you'll see this]

**How to identify:**
```bash
grep -r "signature" --include="*.ext"
```

**Interpretation:**
[What this tells you about the codebase]

### Pattern 2: [Name]

[Repeat structure]

---

## Edge Cases & Gotchas

### False Positives

**Pattern:** [What looks like it matches but doesn't]
**Why:** [Reason for confusion]
**Filter:** [How to exclude]

### False Negatives

**Pattern:** [What should match but might be missed]
**Why:** [Reason for missing it]
**Mitigation:** [Additional search strategy]

### Ambiguous Cases

**Scenario:** [When domain boundaries are unclear]
**Decision criteria:** [How to classify]
**Cross-reference:** [Related domains to check]

---

## Maintenance Notes

### Update Triggers

This domain definition should be reviewed when:
- [Specific technology version changes]
- [New frameworks are adopted]
- [Organizational standards change]

### Known Limitations

- [What this domain definition doesn't cover well]
- [Tools or technologies that need specialized handling]

### Related Domains

- **[Domain Name]:** [Relationship and boundaries]
- **[Domain Name]:** [How they interact or overlap]

---

## Validation

### Self-Check Questions

Before publishing findings from this domain:

1. Did you verify primary indicators are present?
2. Did you exclude known false positives?
3. Did you check for deprecated/experimental markers?
4. Did you document uncertainty where applicable?
5. Did you link related artifacts across categories?

### Quality Criteria

**Minimum viable analysis:**
- [ ] At least [N] artifacts documented
- [ ] All categories represented or marked as absent
- [ ] Clear distinction between active and deprecated
- [ ] Dependencies mapped

**Excellent analysis additionally includes:**
- [ ] Historical context from git/comments
- [ ] Patterns across artifacts identified
- [ ] Gaps or inconsistencies noted
- [ ] Recommendations for users

---

## References

### Internal

- [Links to related domain definitions]
- [Links to org documentation about this technology]

### External

- [Official docs for technologies in this domain]
- [Relevant RFCs, blog posts, or standards]

---

## Template Usage

**To create a new domain definition from this template:**

1. Copy this file to `references/domains/YOUR-DOMAIN.md`
2. Replace all `[BRACKETED]` placeholders
3. Delete sections that don't apply (mark as "Not Applicable" if important)
4. Add domain to `references/domains/registry.yaml`
5. Test search commands against real codebase
6. Validate with `scripts/validate-domains.sh`
7. Update Last Updated date
8. Set Status to `active`

**Required sections (cannot be omitted):**
- Overview
- Search Strategy
- Search Commands
- Analysis Framework
- Examples (at least 1)

**Optional sections (omit if not applicable):**
- Content Categories (if domain is simple/homogeneous)
- Common Patterns (if no recurring patterns observed)
- Edge Cases & Gotchas (if domain boundaries are clear)
