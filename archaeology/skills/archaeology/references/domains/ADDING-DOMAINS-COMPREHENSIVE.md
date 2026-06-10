# Adding New Domains to Archaeology

This guide walks through creating a new domain definition for the archaeology skill.

---

## Quick Checklist

Before submitting a new domain:

- [ ] Domain covers a distinct technical area (not redundant with existing domains)
- [ ] Domain definition created from DOMAIN-TEMPLATE.md
- [ ] All required sections completed
- [ ] At least 2 working examples included
- [ ] Search commands tested against real codebase
- [ ] Entry added to `registry.yaml`
- [ ] Validation script passes: `${PLUGIN_ROOT}/scripts/validate-domains.sh`
- [ ] Registry sync verified: `${PLUGIN_ROOT}/scripts/check-registry-sync.sh`
- [ ] Status set to `active`
- [ ] Maintainer identified

---

## Step-by-Step Process

### Step 1: Determine Domain Scope

**Ask yourself:**

1. **Is this domain distinct?**
   - Does it have unique file types, patterns, or search strategies?
   - Or is it a subset of an existing domain?

2. **Is it bounded?**
   - Can you clearly define what's in vs. out?
   - Are there reliable technical markers (file extensions, imports, patterns)?

3. **Is it actionable?**
   - Will users actually search for this separately?
   - Does it answer a specific archaeological question?

**Good domain examples:**
- "API Contracts" - OpenAPI/Swagger specs, clear file types, specific use case
- "Feature Flags" - Distinct configuration pattern, clear search strategy
- "Database Migrations" - Specific file naming, sequential ordering matters

**Poor domain examples:**
- "Code" - Too broad, overlaps everything
- "New Features" - Not a technical domain, too vague
- "JavaScript" - Language, not a domain (better: "React Components", "Node Services")

### Step 2: Copy an Existing Domain

```bash
cd ${SKILL_DIR}/references/domains/

# Copy a similar existing domain as your starting point
# (has correct YAML frontmatter format and real working structure)
cp git-workflows.md your-domain-name.md

# Open in editor
$EDITOR your-domain-name.md
```

> **Note:** Start from an existing domain file, not `DOMAIN-TEMPLATE.md`. Existing domains have battle-tested YAML frontmatter and body structure. `DOMAIN-TEMPLATE.md` is a reference for what sections to document, not a copy-paste starting point.

**Naming conventions:**
- Use lowercase-with-hyphens
- Be specific: `rest-apis.md` not `apis.md`
- Avoid abbreviations unless universal: `ci-cd.md` is OK, `int-cfg.md` is not

### Step 3: Fill Required Sections

Complete these sections at minimum:

#### Overview

Clearly state:
- **Purpose:** Why this domain exists (1-2 sentences)
- **Scope:** What's included/excluded (bulleted)
- **Key Characteristics:** What makes this domain unique (3-5 bullets)

**Example:**
```markdown
**Purpose:** Document REST API endpoint definitions, request/response schemas, and routing configuration.

**Scope:**
- ✅ REST endpoint handlers, route definitions, API controllers
- ✅ Request/response validation schemas
- ✅ OpenAPI/Swagger specifications
- ❌ Internal service-to-service RPC (see `grpc-services.md`)
- ❌ GraphQL schemas (see `graphql-schemas.md`)
```

#### Search Strategy

Define how to find content in this domain:

**Primary Indicators** - Must have these:
- Grep patterns that definitively identify domain content
- File extensions or naming patterns
- Structural markers (imports, decorators, keywords)

**Secondary Indicators** - Nice to have:
- Common co-occurrences
- Naming conventions

**Exclusion Filters** - Must NOT have these:
- Patterns that exclude false positives
- Disambiguation from similar domains

**Example:**
```markdown
### Primary Indicators

**Required patterns:**
```text
@RestController
@RequestMapping
@GetMapping|@PostMapping|@PutMapping|@DeleteMapping
```

**File types:**
- `*Controller.java`
- `*Endpoint.kt`
- `routes/*.js`

### Exclusion Filters

**Anti-patterns:**
```text
@Internal  # Internal-only endpoints
@Deprecated  # Don't include deprecated
```
```bash

#### Search Commands

Provide working bash commands for:

1. **Discovery Phase** - Find candidate files
2. **Validation Phase** - Verify they match criteria
3. **Extraction Phase** - Pull out relevant content

Test these commands on a real codebase before committing.

**Example:**
```bash
# Discovery: Find REST controllers
grep -r "@RestController" --include="*Controller.java" src/

# Validation: Must have route mappings
grep -l "@RestController" src/**/*Controller.java | \
  xargs grep -l "@RequestMapping\|@GetMapping"

# Extraction: Get endpoint definitions
grep -A 5 "@GetMapping\|@PostMapping" src/main/controllers/UserController.java
```

#### Examples

Include at least 2 real-world scenarios:

1. **Common case** - Most frequent search need
2. **Edge case** - Handles ambiguity or complexity

Each example should have:
- **Situation:** What the user is looking for
- **Search approach:** Step-by-step commands
- **Expected results:** What they'll find and how to interpret

#### Analysis Framework

Define how to analyze found artifacts:

**Key Questions** - What to determine about each artifact
**Extraction Checklist** - What data to capture
**Output Structure** - How to format findings

### Step 4: Fill Optional Sections

Add these if applicable:

**Content Categories:**
- Use when domain has distinct sub-types
- Example: "API Contracts" might have categories for "OpenAPI Specs", "Route Handlers", "Validation Schemas"

**Common Patterns:**
- Document recurring implementation patterns
- Helps users understand architectural decisions

**Edge Cases & Gotchas:**
- Known false positives/negatives
- Ambiguous boundaries with other domains
- Special handling needed

**Maintenance Notes:**
- When to update this definition
- Known limitations
- Related domains

### Step 5: Register the Domain

Add entry to `references/domains/registry.yaml`:

```yaml
domains:
  - id: your-domain-name
    name: Your Domain Display Name
    file: your-domain-name.md
    version: "1.0.0"
    status: active
    description: Brief description of what this domain covers
    pattern_types:
      - "Category 1"
      - "Category 2"
    keywords:
      - key1
      - key2
```

**Status values:**
- `planned` - Registered but not yet implemented or tested
- `active` - Tested and ready
- `deprecated` - Being phased out, use alternative

**Tags help categorization:**
- Language: `javascript`, `python`, `java`
- Layer: `frontend`, `backend`, `infrastructure`
- Type: `api`, `config`, `data`, `testing`

### Step 6: Validate

Run validation scripts:

```bash
# Check domain file structure
${PLUGIN_ROOT}/scripts/validate-domains.sh

# Verify registry sync
${PLUGIN_ROOT}/scripts/check-registry-sync.sh
```

Fix any errors reported.

### Step 7: Test Against Real Codebase

Before marking as `active`:

1. **Run your search commands** on a real project
2. **Verify you get expected results** (not empty, not overwhelming)
3. **Check for false positives** - Do results actually match the domain?
4. **Check for false negatives** - Are you missing obvious examples?
5. **Refine patterns** based on results

### Step 8: Update Metadata

In your domain file:

```markdown
**Status:** `active`
**Maintainer:** your-name
**Last Updated:** 2026-02-26
```

In `registry.yaml`:

```yaml
status: active
last_updated: "2026-02-26"
```

---

## Common Mistakes

### Mistake 1: Domain Too Broad

**Symptom:** Search commands return thousands of results, hard to analyze.

**Example:** A domain called "Backend Code" that matches all `.java` files.

**Fix:** Split into focused domains:
- `rest-apis.md` - Just REST endpoints
- `database-access.md` - Just data layer
- `business-logic.md` - Service/domain layer

### Mistake 2: Patterns Too Specific

**Symptom:** Only matches your specific project, not generalizable.

**Example:** Pattern `getUserById` that only works if your codebase uses that exact naming.

**Fix:** Use structural patterns not implementation details:
```bash
# Too specific
grep -r "getUserById"

# Better - matches pattern
grep -r "get.*ById"

# Best - matches structure
grep -r "@GetMapping.*/{id}"
```

### Mistake 3: Missing Exclusion Filters

**Symptom:** Results include test files, generated code, or deprecated content.

**Example:** Finding API routes but including mocks and stubs.

**Fix:** Add explicit exclusions:
```bash
grep -r "@GetMapping" src/ | \
  grep -v "/test/" | \
  grep -v "/mock/" | \
  grep -v "@Deprecated"
```

### Mistake 4: Untested Commands

**Symptom:** Search commands have syntax errors or don't work as expected.

**Example:** Regex that needs escaping, pipe that fails.

**Fix:** Test every command in a real shell before adding to domain:
```bash
# Test in real project first
cd ~/projects/example-project
grep -r "@RestController" --include="*.java" src/

# Once working, add to domain definition
```

### Mistake 5: No Examples

**Symptom:** Domain is abstract, users don't know when to use it.

**Example:** Just listing patterns without showing real search scenarios.

**Fix:** Add concrete examples:
```markdown
## Examples

### Example 1: Finding All User Management Endpoints

**Situation:** You need to document all API endpoints related to user operations.

**Search approach:**
```bash
# Find user controllers
grep -l "UserController\|UserEndpoint" src/**/*.java

# Extract endpoints
grep -B 2 -A 10 "@GetMapping\|@PostMapping" src/controllers/UserController.java
```

**Expected results:** List of endpoints with routes, HTTP methods, and handler method names.
```bash

### Mistake 6: Overlapping Domains

**Symptom:** Multiple domains claim the same files, users confused which to use.

**Example:** Both `rest-apis.md` and `http-endpoints.md` match the same controllers.

**Fix:** Check existing domains first:
```bash
# List all domains
ls ${SKILL_DIR}/references/domains/*.md

# Check registry for similar
grep -i "api\|endpoint" ${SKILL_DIR}/references/domains/registry.yaml
```

If overlap is unavoidable, clearly document boundaries in both domains' "Related Domains" section.

---

## Validation Commands

### Check Domain File Structure

```bash
${PLUGIN_ROOT}/scripts/validate-domains.sh
```

**Checks:**
- Required sections present
- Code blocks properly formatted
- Metadata fields complete
- Links not broken

**Exit codes:**
- `0` - All domains valid
- `1` - Validation errors found

### Check Registry Sync

```bash
${PLUGIN_ROOT}/scripts/check-registry-sync.sh
```

**Checks:**
- All `.md` files in `registry.yaml`
- All registry entries have corresponding files
- No orphaned files
- No duplicate IDs

**Exit codes:**
- `0` - Registry in sync
- `1` - Sync issues found

### Manual Sanity Checks

```bash
# Count domains
ls ${SKILL_DIR}/references/domains/*.md | wc -l
grep "^  - id:" ${SKILL_DIR}/references/domains/registry.yaml | wc -l
# These should match (minus template and this guide)

# Find domains missing examples
for f in ${SKILL_DIR}/references/domains/*.md; do
  if ! grep -q "^## Examples" "$f"; then
    echo "Missing examples: $f"
  fi
done

# Find planned domains
grep -B 1 "Status.*planned" ${SKILL_DIR}/references/domains/*.md
```

---

## Getting Help

### Before Creating an Issue

1. Did you test search commands on a real codebase?
2. Did you run validation scripts?
3. Did you check for similar existing domains?
4. Did you review the template comments?

### What to Include

When asking for help:

- Domain name and purpose
- What you've tried
- Validation errors (full output)
- Example search that's not working as expected
- Confusion about boundaries with other domains

### Iteration is Normal

Most domains go through 2-3 revisions:

1. **First draft** - Get basic structure down
2. **Testing** - Run against real code, find gaps
3. **Refinement** - Fix false positives/negatives, clarify boundaries
4. **Polish** - Add examples, edge cases, better docs

Don't aim for perfection on first try. Mark as `planned`, test, iterate.

---

## Domain Lifecycle

### New Domain

1. Status: `planned`
2. Test with at least 2 different codebases
3. Get feedback from one other person
4. Status: `active`

### Updating Existing Domain

1. Make changes to `.md` file
2. Update `last_updated` in both file and `registry.yaml`
3. Run validation scripts
4. Document changes (consider adding changelog section if significant)

### Deprecating Domain

1. Status: `deprecated`
2. Add deprecation notice at top of domain file:
   ```markdown
   > **DEPRECATED:** Use [alternative-domain.md] instead. This domain is no longer maintained.
   ```
3. Update registry with deprecation reason
4. Do NOT delete file (preserve for reference)

### Archiving Domain

After 6 months deprecated with no usage:

1. Move to `references/domains/archived/`
2. Remove from `registry.yaml`
3. Add entry to `references/domains/archived/README.md`

---

## Tips for Success

### Start Simple

Your first domain doesn't need every optional section. Focus on:
- Clear overview
- Working search commands
- 2 good examples

Add complexity as you learn what users need.

### Use Real Examples

Don't invent hypothetical scenarios. Pull from actual projects:
- Commands you've actually run
- Problems you've actually solved
- Files you've actually analyzed

### Test Early, Test Often

Don't write entire domain definition before testing. Iterative approach:
1. Write overview + primary patterns
2. Test search commands
3. Add examples based on results
4. Refine patterns based on false positives
5. Add edge cases as you discover them

### Learn from Existing Domains

Before creating a new domain, read 2-3 existing ones:
```bash
ls ${SKILL_DIR}/references/domains/
```

See how they structure examples, what level of detail they provide, how they handle ambiguity.

### Document Your Uncertainty

If you're not sure about:
- A boundary with another domain → Document both interpretations
- Whether a pattern is reliable → Mark as "experimental" or "needs validation"
- How to handle an edge case → Describe the dilemma

Better to acknowledge gaps than pretend certainty.

---

## Quality Criteria

### Minimum Viable Domain

- [ ] Purpose is clear in 1-2 sentences
- [ ] At least 3 search patterns defined
- [ ] At least 2 working examples
- [ ] Tested against 1 real codebase
- [ ] Validation scripts pass

### High-Quality Domain

Additionally includes:
- [ ] Tested against 3+ codebases
- [ ] Edge cases documented
- [ ] Common patterns identified
- [ ] False positive/negative handling
- [ ] Clear boundaries with related domains
- [ ] Maintenance notes for future updates

### Exemplary Domain

Additionally includes:
- [ ] Multiple examples covering different scenarios
- [ ] Visual diagrams of domain boundaries
- [ ] Historical context (why this domain emerged)
- [ ] Links to external references
- [ ] Troubleshooting section
- [ ] User feedback incorporated

---

## Questions to Ask Yourself

Before marking domain as `active`:

1. **Clarity:** Can someone unfamiliar with this technology use this domain?
2. **Completeness:** Are all common scenarios covered?
3. **Correctness:** Do search commands actually work?
4. **Distinctiveness:** Is this different enough from existing domains?
5. **Maintainability:** Can someone else update this in 6 months?

If any answer is "no", the domain needs more work.

---

## References

- [DOMAIN-TEMPLATE.md](./DOMAIN-TEMPLATE.md) - Template file
- [registry.yaml](./registry.yaml) - Domain registry
- [output-templates.md](../output-templates.md) - Formatting standards
- Validation script: `${PLUGIN_ROOT}/scripts/validate-domains.sh`
- Registry sync script: `${PLUGIN_ROOT}/scripts/check-registry-sync.sh`
