# Analysis Skill Template

Template for skills that analyze code without making modifications (performance analysis, security audits, code quality checks).

## Template

```yaml
---
name: analyzing-{aspect}
description: Analyzes {what} for {issues/patterns}. Use when {context}, user requests {analysis type}, or {trigger phrase}.
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Analyzing {Aspect}

Brief description of what this skill analyzes and why it's valuable.

## Analysis Process

1. Scan codebase for relevant files
2. Read and parse code structures
3. Identify issues/patterns against checklist
4. Categorize findings by severity
5. Generate report with recommendations

## Analysis Checklist

### Critical Issues
- [ ] Issue type 1
- [ ] Issue type 2

### Performance Issues
- [ ] Performance issue 1
- [ ] Performance issue 2

### Code Quality
- [ ] Quality check 1
- [ ] Quality check 2

## Report Format

\`\`\`
# {Aspect} Analysis Report

## Summary
- Files analyzed: X
- Issues found: Y
- Critical: Z

## Critical Issues

### Issue 1: {Title}
**Location**: {file}:{line}
**Severity**: Critical
**Description**: What's wrong
**Recommendation**: How to fix

## Performance Issues

[Similar format]

## Code Quality

[Similar format]

## Recommendations

1. Priority recommendation
2. Secondary recommendation
\`\`\`

## Examples

### Example 1: {Simple Case}

**User Request**: "Analyze {something simple}"

**Analysis Output**:
[Example report]

### Example 2: {Complex Case}

**User Request**: "Analyze {something complex}"

**Analysis Output**:
[Example report]

## Detailed Patterns

@reference/{aspect}-patterns.md

## Version History

### v1.0.0 (YYYY-MM-DD)
- Initial release
```

## Usage Instructions

1. Replace `{aspect}` with what you're analyzing (performance, security, accessibility)
2. Define checklist items specific to the analysis type
3. Create report format template
4. Add real examples of analysis output
5. Ensure read-only tool restrictions

## Complete Example: Performance Analysis

```yaml
---
name: analyzing-performance
description: Analyzes React code for performance issues including N+1 queries, missing memoization, and unnecessary re-renders. Use when optimizing performance, investigating slow renders, or user requests performance analysis.
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Analyzing Performance

Identifies performance bottlenecks and optimization opportunities in React applications.

## Analysis Process

1. Scan for React components (`**/*.tsx`, `**/*.jsx`)
2. Read component implementations
3. Check against performance checklist
4. Categorize findings by impact
5. Generate prioritized recommendations

## Performance Checklist

### Critical Issues
- [ ] Inline function creation in render (causes re-renders)
- [ ] Missing React.memo for expensive components
- [ ] Large lists without virtualization
- [ ] Unnecessary context re-renders

### Moderate Issues
- [ ] Missing useMemo for expensive calculations
- [ ] Missing useCallback for callbacks passed to children
- [ ] Large bundle imports without code splitting
- [ ] Inefficient state updates

### Minor Issues
- [ ] Console logs in production code
- [ ] Unused imports
- [ ] Suboptimal re-render triggers

## Report Format

\`\`\`
# Performance Analysis Report

## Summary
- Components analyzed: 24
- Issues found: 12
- Critical: 3
- Moderate: 6
- Minor: 3

## Critical Issues

### Issue 1: Inline Function in UserList Component
**Location**: src/components/UserList.tsx:42
**Severity**: Critical
**Impact**: Component re-renders on every parent update

**Code**:
\`\`\`typescript
<UserCard onClick={() => handleClick(user.id)} />
\`\`\`

**Recommendation**: Use useCallback to memoize the handler:
\`\`\`typescript
const handleUserClick = useCallback((id) => {
  handleClick(id);
}, [handleClick]);

<UserCard onClick={handleUserClick} />
\`\`\`

**Estimated Impact**: 40% reduction in re-renders

## Moderate Issues

### Issue 4: Missing Memoization in Dashboard
**Location**: src/pages/Dashboard.tsx:28
**Severity**: Moderate
**Impact**: Expensive calculation runs on every render

**Code**:
\`\`\`typescript
const stats = calculateStatistics(users, orders, products);
\`\`\`

**Recommendation**: Use useMemo:
\`\`\`typescript
const stats = useMemo(
  () => calculateStatistics(users, orders, products),
  [users, orders, products]
);
\`\`\`

**Estimated Impact**: 25% faster renders

## Recommendations

1. **High Priority**: Fix critical re-render issues in UserList and ProductGrid
2. **Medium Priority**: Add memoization to Dashboard and Analytics components
3. **Low Priority**: Remove console.logs and clean up unused imports
4. **Next Steps**: Consider adding React DevTools Profiler to monitor performance
\`\`\`

## Examples

### Example 1: Component with Re-render Issues

**User Request**: "Analyze the UserList component for performance issues"

**Analysis Output**:
\`\`\`
# UserList Performance Analysis

## Issues Found

### Critical: Inline Function Creation
**Location**: Line 42
**Problem**: New function created on every render
**Fix**: Use useCallback

### Moderate: Missing React.memo
**Location**: Component definition
**Problem**: Re-renders when parent re-renders, even with same props
**Fix**: Wrap in React.memo

## Recommendations
1. Apply useCallback to event handlers
2. Wrap component in React.memo
3. Consider virtualization for large lists (>100 items)

**Estimated Performance Gain**: 60% reduction in render time
\`\`\`

### Example 2: Expensive Calculation

**User Request**: "Why is the Dashboard slow to render?"

**Analysis Output**:
\`\`\`
# Dashboard Performance Analysis

## Root Cause
Expensive calculation runs on every render without memoization

**Location**: src/pages/Dashboard.tsx:28
**Calculation**: aggregateAnalytics() - processes 10,000+ data points
**Frequency**: Every render (100+ times per session)

## Fix
\`\`\`typescript
// Before
const analytics = aggregateAnalytics(data);

// After
const analytics = useMemo(
  () => aggregateAnalytics(data),
  [data]
);
\`\`\`

**Estimated Impact**: 80% reduction in render time (from 250ms to 50ms)
\`\`\`

## Customization Points

1. **Analysis Scope**: Add database query analysis, API call optimization
2. **Severity Levels**: Adjust critical/moderate/minor thresholds
3. **Report Format**: Change to JSON, CSV, or other formats
4. **Metrics**: Add bundle size analysis, lighthouse scores
5. **Framework**: Adapt for Vue, Angular, or vanilla JavaScript

## Version History

### v1.0.0 (2025-01-15)
- Initial release
- React-specific performance analysis
- Memoization and re-render detection
```

## Key Features of Analysis Skills

1. **Read-Only**: Never modify code, only analyze
2. **Structured Reports**: Consistent format for findings
3. **Severity Categorization**: Critical, moderate, minor
4. **Actionable Recommendations**: Not just "what" but "how to fix"
5. **Impact Estimates**: Quantify expected improvements
6. **Examples**: Show real analysis output

## Common Patterns

### Security Analysis

```yaml
name: analyzing-security
description: Analyzes code for security vulnerabilities including XSS, SQL injection, and exposed secrets
allowed-tools: [Read, Grep, Glob]
```

### Accessibility Analysis

```yaml
name: analyzing-accessibility
description: Checks React components for WCAG 2.1 AA compliance and accessibility issues
allowed-tools: [Read, Grep, Glob]
```

### Code Quality Analysis

```yaml
name: analyzing-code-quality
description: Reviews code for maintainability, complexity, and adherence to best practices
allowed-tools: [Read, Grep, Glob]
```

### Bundle Analysis

```yaml
name: analyzing-bundle-size
description: Analyzes JavaScript bundle size and identifies optimization opportunities
allowed-tools: [Read, Bash, Grep, Glob]
```

## Version History

### v1.0.0 (2025-11-17)
- Initial template creation
- Added performance analysis example
- Included report format guidelines
