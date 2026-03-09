---
name: agent-response
purpose: Standard format for sub-agent communication
category: agent
version: 1.0.0
---

# Agent Response Template

## Summary

[2-3 sentence summary that can be scanned in under 10 seconds. Front-load the most critical information.]

Example: "Analyzed authentication implementation across 8 files in the codebase. Found OAuth 2.0 with JWT tokens, but identified 3 security vulnerabilities in session management. Recommend immediate fix for hard-coded secrets in production config."

---

## Context

### What Was Asked

**Task**: [Brief description of what you were asked to investigate/analyze/implement]
**Scope**: [What was in/out of scope]

### What Was Reviewed

Files and sources consulted:

- `/path/to/file1.ts` - [Brief description of relevance]
- `/path/to/file2.ts` - [Brief description of relevance]
- External references: [Any documentation, articles, or resources used]

---

## Findings

[Main content of your analysis. Use clear structure with evidence.]

### Finding 1: [Title]

**Description**: [What you found]

**Evidence**:
- `/path/to/file.ts:42-58` - [Specific code reference]
- [Supporting data or observations]

**Impact**: [Why this matters, what it affects]

### Finding 2: [Title]

**Description**: [What you found]

**Evidence**:
- `/path/to/file.ts:120-135` - [Specific code reference]
- [Supporting data or observations]

**Impact**: [Why this matters, what it affects]

### Code Examples

When relevant, include specific code references:

```typescript
// From: /src/auth/validator.ts:42-58
function validateCredentials(username: string, password: string): boolean {
  // Validation logic
  return isValid;
}
```

**Issues identified**:
- Line 45: Hard-coded salt value (security risk)
- Line 52: No rate limiting (vulnerability)

---

## Decisions / Recommendations

### Recommendation 1: [Title]

**Recommendation**: [What you recommend]

**Rationale**: [Why this is the best approach]

**Alternatives Considered**:
- Alternative A: [Brief description + why not chosen]
- Alternative B: [Brief description + why not chosen]

**Implementation Impact**:
- Requires: [Dependencies, prerequisites]
- Affects: [What systems/files this touches]
- Estimated effort: [Rough timeline or complexity]

### Recommendation 2: [Title]

[Follow same structure as Recommendation 1]

---

## Questions for Orchestrator

[List questions that require input or clarification. These should also be in your return JSON.]

### Question 1: [Title]

**Question**: [Clear, specific question]

**Context**: [Why you're asking, what you've already considered]

**Options**:
1. Option A - [Description, pros/cons]
2. Option B - [Description, pros/cons]

**Your Recommendation**: [What you think is best and why]

**Blocking**: Yes / No - [Does this block progress?]

---

## Next Steps

### Immediate Actions

What should happen next based on your findings:

1. [Action 1 with specific details]
2. [Action 2 with specific details]
3. [Action 3 with specific details]

### Context for Next Agent/Phase

[What the next agent or orchestrator should know]:

- Key insight 1 that affects downstream work
- Key insight 2 that affects downstream work
- Files to focus on: [List specific paths]
- Areas of concern: [Specific topics to address]

---

## Return JSON

```json
{
  "status": "finished",
  "summary": "[Match the Summary section above - 2-3 sentences]",
  "questions": [
    {
      "question": "[Question text]",
      "blocking": false,
      "options": ["Option A", "Option B"],
      "recommendation": "[Your recommendation]"
    }
  ],
  "next_steps": "[From Next Steps section - what should happen next]",
  "key_files": ["/path/to/important/file1.ts", "/path/to/important/file2.ts"]
}
```

---

## Best Practices

### Information Hierarchy

1. **Front-load critical information** - Summary should contain the most important findings
2. **Synthesis over raw data** - Provide insights, not file dumps
3. **Evidence-based** - Support findings with file paths and line numbers
4. **Actionable** - Clear recommendations and next steps

### Token Efficiency

- Keep total response under 3000 tokens when possible
- Use bullet points and tables for scanability
- Include only relevant code excerpts, not full files
- Put extensive data in appendix or separate files if needed

### File References

Always include specific file paths with line numbers:

- Good: `/src/auth/validator.ts:42-58`
- Bad: "in the validator file"

### Communication Clarity

- Use clear section headers
- Group related findings together
- Highlight blocking issues prominently
- Provide context for why things matter

---

## Template Customization

**Sections to Keep**:
- Summary (always required)
- Context (what was asked/reviewed)
- Main content (Findings/Analysis/Implementation)
- Return JSON (always required)

**Optional Sections**:
- Decisions/Recommendations (include if you're making recommendations)
- Questions for Orchestrator (include if you need clarification)
- Next Steps (include unless this is purely informational)

**When to Add Sections**:
- Risks/Issues - If you identify blockers or concerns
- Comparison Tables - When evaluating multiple options
- Appendix - For detailed data that supports but isn't critical

**Keep It Concise**:
- Remove sections that don't apply
- Don't include boilerplate
- Focus on actionable information
- Aim for clarity over completeness

---

**Template Version**: 1.0.0
**Last Updated**: 2025-12-06
