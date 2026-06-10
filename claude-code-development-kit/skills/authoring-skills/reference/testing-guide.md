# Skill Testing Guide

## Overview

Thorough testing ensures your skill is invoked correctly, works as intended, and provides value to users.

## Testing Phases

### Phase 1: Local Development Testing

Create and test skills in project directory first:

```bash
# Create test skill in project
mkdir -p .claude/skills/my-test-skill
cd .claude/skills/my-test-skill

# Create SKILL.md
cat > SKILL.md << 'EOF'
---
name: my-test-skill
description: Test skill for validation
---

# My Test Skill

This is a test skill.
EOF
```

Test in isolation before moving to personal skills or sharing.

### Phase 2: Validation Checklist

Run through this checklist before considering a skill complete:

#### YAML Validation
- [ ] YAML frontmatter has no syntax errors
- [ ] Name is lowercase with hyphens
- [ ] Name is under 64 characters
- [ ] Description is present and focused (no hard character limit)
- [ ] Description is in third person
- [ ] Description includes trigger phrases
- [ ] allowed-tools list is properly formatted (if used)

#### Content Validation
- [ ] SKILL.md is under 500 lines
- [ ] Instructions are step-by-step
- [ ] Examples are included
- [ ] File paths in examples are correct
- [ ] @path imports reference existing files
- [ ] Supporting files are accessible
- [ ] Code examples are syntactically correct

#### Functionality Validation
- [ ] Tool restrictions work as intended
- [ ] Skill can be manually invoked
- [ ] Skill produces expected output
- [ ] Supporting files load correctly
- [ ] Scripts execute without errors (if applicable)

### Phase 3: Manual Invocation Testing

Test the skill by creating scenarios where it should be invoked:

#### Direct Invocation

Ask Claude to use the skill explicitly:

```
User: "Use the my-test-skill skill to demonstrate its functionality"
Claude: [Should invoke the skill and execute its instructions]
```

#### Trigger Phrase Testing

Test each trigger phrase in your description:

If your description says:
```yaml
description: Generates React components with TypeScript. Use when creating new components, scaffolding UI elements, or adding React files.
```

Test these phrases:
- "Create a new React component called UserProfile"
- "Generate a component for the dashboard"
- "Scaffold a UI element for the header"
- "Add a React file for displaying user cards"

#### Negative Testing

Verify the skill is NOT invoked for unrelated requests:

```
User: "Create a Python script for data processing"
Claude: [Should NOT invoke a React component generation skill]
```

### Phase 4: Output Validation

Verify the skill produces correct and consistent output:

#### Code Generation Skills

- [ ] Generated code is syntactically correct
- [ ] Output follows project conventions
- [ ] File paths are appropriate
- [ ] Imports and dependencies are correct
- [ ] Code includes necessary comments
- [ ] Generated tests pass (if applicable)

#### Analysis Skills

- [ ] Analysis is accurate and comprehensive
- [ ] Recommendations are actionable
- [ ] Output format is consistent
- [ ] Edge cases are handled
- [ ] Tool restrictions prevent unwanted modifications

#### Documentation Skills

- [ ] Documentation follows specified format
- [ ] All required sections are included
- [ ] Examples are accurate and helpful
- [ ] Links and references are valid
- [ ] Formatting is correct

### Phase 5: Cross-Model Testing

Test your skill with different models to ensure consistency:

```bash
# Test with Sonnet (default)
claude "Create a React component using my skill"

# Test with Haiku (faster, cheaper)
claude --model haiku "Create a React component using my skill"

# Test with Opus (most capable)
claude --model opus "Create a React component using my skill"
```

**Expected behavior**:
- All models should invoke the skill for appropriate requests
- Opus may handle complex skills better
- Haiku should work for straightforward skills
- Sonnet provides good balance

### Phase 6: Discoverability Testing

Verify Claude can discover your skill:

```
User: "What skills are available for creating React components?"
Claude: [Should mention your skill if the description is effective]
```

```
User: "Can you help me generate API documentation?"
Claude: [Should mention your API documentation skill]
```

## Testing Tools and Techniques

### YAML Validation

Use a YAML linter to catch syntax errors:

```bash
# Install yamllint
pip install yamllint

# Validate SKILL.md
yamllint SKILL.md

# Custom rules for skill files
cat > .yamllint << 'EOF'
extends: default
rules:
  line-length:
    max: 200
  document-start: disable
EOF

yamllint -c .yamllint SKILL.md
```

### Line Count Check

Ensure SKILL.md stays under 500 lines:

```bash
wc -l SKILL.md
# Output should be: XXX SKILL.md (where XXX < 500)
```

### @path Import Verification

Verify all @path imports exist:

```bash
# Extract @path references
grep -o '@[a-zA-Z0-9/_-]*\.md' SKILL.md

# Check each file exists
for file in $(grep -o '@[a-zA-Z0-9/_-]*\.md' SKILL.md | sed 's/@//'); do
  if [ ! -f "$file" ]; then
    echo "Missing: $file"
  fi
done
```

### Tool Restriction Testing

If using `allowed-tools`, verify restrictions work:

```yaml
---
name: analyzing-code
description: Analyzes code without making changes
allowed-tools:
  - Read
  - Grep
  - Glob
---
```

Test:
1. Invoke the skill
2. Attempt to use Edit or Write tools
3. Verify tools are restricted

### Supporting File Accessibility

Verify supporting files can be loaded:

```bash
# Check all supporting files exist
find . -type f -name "*.md" ! -name "SKILL.md"

# Verify file permissions
ls -la templates/ examples/ reference/
```

## Testing Scenarios by Skill Type

### Code Generation Skills

Test cases:
1. Generate with minimal input
2. Generate with full specification
3. Generate with edge case names (special characters, reserved words)
4. Verify generated code compiles/runs
5. Check adherence to project patterns

Example test:
```
User: "Create a React component called User-Profile with props for name and email"
Expected: Component file with proper naming, TypeScript interfaces, and structure
```

### Analysis Skills

Test cases:
1. Analyze simple, well-structured code
2. Analyze complex code with issues
3. Analyze edge cases (empty files, very large files)
4. Verify read-only behavior (no modifications)
5. Check accuracy of findings

Example test:
```
User: "Analyze the performance of the UserList component"
Expected: Analysis report identifying issues, no code modifications
```

### Documentation Skills

Test cases:
1. Document simple API endpoint
2. Document complex endpoint with multiple parameters
3. Document endpoint with authentication
4. Verify output format (OpenAPI, JSDoc, etc.)
5. Check example accuracy

Example test:
```
User: "Document the /api/users endpoint"
Expected: Complete API documentation with schemas and examples
```

### Refactoring/Migration Skills

Test cases:
1. Migrate simple case
2. Migrate complex case with dependencies
3. Handle edge cases (circular dependencies, missing imports)
4. Verify backward compatibility
5. Check test updates (if applicable)

Example test:
```
User: "Convert UserProfile.js to TypeScript"
Expected: Proper TypeScript conversion with interfaces and types
```

## Continuous Testing

### After Updates

Re-run all tests when you update:
- Description (affects discoverability)
- Instructions (affects output)
- Templates (affects generated code)
- Tool restrictions (affects capabilities)

### Regression Testing

Keep a suite of test cases:

```markdown
# test-cases.md

## Test Case 1: Basic Component Generation
Input: "Create a React component called Button"
Expected: Functional component with TypeScript, props interface, basic structure

## Test Case 2: Component with Props
Input: "Create a Card component with title, description, and imageUrl props"
Expected: Component with properly typed props, destructuring, JSDoc comments

## Test Case 3: Edge Case - Reserved Name
Input: "Create a component called Function"
Expected: Warning about reserved word, suggestion for alternative name
```

Run through test cases periodically to catch regressions.

## Common Issues and Solutions

### Issue: Skill Not Being Invoked

**Diagnosis**:
1. Check description specificity
2. Verify YAML syntax
3. Confirm file location
4. Test trigger phrases

**Solution**:
```yaml
# Before (too vague)
description: Helps with React development

# After (specific with triggers)
description: Generates React components with TypeScript. Use when creating new components, scaffolding UI elements, or adding React files.
```

### Issue: Wrong Skill Invoked

**Diagnosis**:
1. Compare descriptions of similar skills
2. Check for overlapping trigger phrases
3. Review skill uniqueness

**Solution**:
Make each skill's description more specific and distinct:

```yaml
# Component generation skill
description: Generates React functional components with TypeScript and hooks. Use when creating new React components.

# Test generation skill
description: Generates Jest tests for React components with Testing Library. Use when adding test coverage for components.

# Story generation skill
description: Creates Storybook stories for React components with controls and variants. Use when documenting component APIs.
```

### Issue: Tool Restrictions Not Working

**Diagnosis**:
1. Check `allowed-tools` syntax
2. Verify tool names are correct
3. Test with explicit tool usage

**Solution**:
```yaml
# Correct format
allowed-tools:
  - Read
  - Grep
  - Glob

# NOT this
allowed-tools: Read, Grep, Glob  # Wrong format
```

### Issue: Supporting Files Not Loading

**Diagnosis**:
1. Verify file paths in @path imports
2. Check file permissions
3. Confirm files exist in skill directory

**Solution**:
```bash
# Check file structure
ls -R

# Verify paths in SKILL.md match actual files
grep '@' SKILL.md
```

### Issue: Inconsistent Output

**Diagnosis**:
1. Review instruction clarity
2. Check for ambiguous steps
3. Verify examples are complete

**Solution**:
Make instructions more specific:

```markdown
# Before (ambiguous)
1. Create the component
2. Add props
3. Export it

# After (specific)
1. Create file in `src/components/{ComponentName}.tsx`
2. Add TypeScript interface for props with JSDoc comments
3. Implement functional component using props interface
4. Export as default export
```

## Performance Testing

### Load Time

Measure how long the skill takes to load:

```bash
time claude "Use my-test-skill"
```

If loading is slow:
- Check SKILL.md line count (should be < 500)
- Move large content to @path imports
- Reduce inline examples

### Context Window Usage

Monitor context usage for skills with large templates:

- Keep SKILL.md focused
- Use @path imports for reference material
- Load detailed docs only when needed

## Version History

### v1.0.0 (2025-11-17)
- Initial creation from skills-authoring-guide.md
- Added comprehensive testing phases
- Included tool validation strategies
- Documented common issues and solutions
