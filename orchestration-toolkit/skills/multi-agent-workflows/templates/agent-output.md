---
phase: REPLACE_WITH_PHASE         # planning | research | design | execution | review
author_agent: REPLACE_WITH_AGENT_ID  # e.g., agent-001, agent-exploration-abc123
created_at: REPLACE_WITH_TIMESTAMP   # YYYY-MM-DDTHH:MM:SSZ
updated_at: REPLACE_WITH_TIMESTAMP   # YYYY-MM-DDTHH:MM:SSZ
topic: REPLACE_WITH_TOPIC            # Brief topic description, e.g., requirements-analysis
status: REPLACE_WITH_STATUS          # completed | in-progress | blocked
tokens_used: 0                       # Approximate token count for this output
context_sources: []                  # Files read to produce this output
---

# [Topic Title]

## Summary

[2-3 sentence summary of findings, decisions, or outputs. This should be scannable in under 10 seconds.]

Example: "Analyzed authentication requirements across 8 user personas. Identified 3 critical security needs: MFA support, session management, and OAuth integration. Recommend starting with OAuth 2.0 + JWT approach."

---

## Context

### Inputs Reviewed

Files and sources consulted to produce this output:

- `archive/planning-20251124T1430/phase-summary.md` - Planning phase summary
- `shared/decisions.md` - Existing architectural decisions
- External sources: [List any documentation, articles, or references used]

### Task Assignment

**Assigned by**: [Orchestrator or previous agent]
**Assignment**: [Brief description of what you were asked to do]
**Scope**: [What was in scope vs out of scope]

---

## [Main Content Section 1]

[Primary content of your output goes here. Use clear headers, lists, and tables for structure.]

### Sub-Section Example

Key findings:

1. **Finding 1**: [Description]
   - **Evidence**: [File paths, line numbers, or data supporting this]
   - **Impact**: [Why this matters]

2. **Finding 2**: [Description]
   - **Evidence**: [File paths, line numbers, or data supporting this]
   - **Impact**: [Why this matters]

---

## [Main Content Section 2]

### Tables for Comparison

Use tables when comparing options or listing structured data:

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Option A | Pro 1, Pro 2 | Con 1 | ✅ Recommended |
| Option B | Pro 1 | Con 1, Con 2 | ❌ Not recommended |
| Option C | Pro 1, Pro 2, Pro 3 | Con 1 | ⚠️ Consider if... |

### Code Examples

When referencing code, include file paths and line numbers:

```typescript
// From: src/auth/validator.ts:42-58
function validateCredentials(username: string, password: string): boolean {
  // Validation logic
  return isValid;
}
```

**Issues identified**:
- Line 45: Hard-coded salt value (security risk)
- Line 52: No rate limiting (vulnerability)

---

## [Decisions / Recommendations]

### Decision 1: [Decision Title]

**Decision**: [What was decided]
**Rationale**: [Why this decision was made]
**Alternatives Considered**:
- Alternative A: [Why rejected]
- Alternative B: [Why rejected]

**Implications**:
- Impacts [X, Y, Z]
- Requires [A, B, C]
- Timeline: [Estimated effort]

### Decision 2: [Decision Title]

[Follow same structure as Decision 1]

---

## [Risks / Issues]

### High Priority

1. **Risk 1**: [Description]
   - **Likelihood**: High | Medium | Low
   - **Impact**: High | Medium | Low
   - **Mitigation**: [How to address]

### Medium Priority

1. **Risk 2**: [Description]
   - **Likelihood**: High | Medium | Low
   - **Impact**: High | Medium | Low
   - **Mitigation**: [How to address]

---

## Questions for Orchestrator

[If you have questions requiring input, list them here. These should also be in your return JSON.]

### Question 1

**Question**: [Clear, specific question]
**Context**: [Why you're asking, what you've considered]
**Options**: [List 2-4 options if applicable]
**Your Recommendation**: [What you think is best and why]
**Blocking**: Yes | No - Does this block progress?

### Question 2

[Follow same structure]

---

## Next Steps

### For Next Phase

[What should the next phase/agent know or do based on your work?]

Example:
- Implementation phase should use the OAuth 2.0 flow documented in Section 3
- Refer to `schema.json` for database table structure
- Security review should focus on session management (identified as high risk)

### Follow-Up Actions

[Any immediate actions needed before moving forward]

- [ ] Action 1: [Description]
- [ ] Action 2: [Description]
- [ ] Action 3: [Description]

---

## References

### Files Modified/Created

[List any files you created or would recommend modifying]

- `src/auth/oauth-handler.ts` - New file to implement OAuth flow
- `src/config/auth.config.ts` - Modify to add OAuth settings
- `.env.example` - Add OAuth client ID/secret placeholders

### External References

[List any external documentation, articles, or resources referenced]

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- Project documentation: `docs/authentication.md`

---

## Appendix (Optional)

### Detailed Data

[If you have extensive data (logs, test results, full API responses), include here or in separate files]

### Code Snippets

[Additional code examples that support main content but aren't critical]

### Calculations

[Show work for any estimates, sizing, or performance calculations]

---

## Agent Output Metadata

**Agent ID**: REPLACE_WITH_AGENT_ID
**Workflow ID**: REPLACE_WITH_WORKFLOW_ID
**Phase**: REPLACE_WITH_PHASE
**Topic**: REPLACE_WITH_TOPIC
**Started**: REPLACE_WITH_TIMESTAMP
**Completed**: REPLACE_WITH_TIMESTAMP
**Duration**: [Calculate from start to completion]
**Tokens Used**: 0 (approximate)
**Status**: completed | in-progress | blocked

**Return JSON** (v1.1.0):
```json
{
  "status": "finished",
  "output_paths": ["active/[phase]/agent-[id]-[topic].md"],
  "questions": [],
  "summary": "[2-3 sentence summary matching Summary section above]",
  "tokens_used": 0,
  "next_phase_context": "[From Next Steps section above]",
  "protocol_version": "1.1.0",
  "agent_id": "agent-[id]",
  "confidence": "high | medium | low",
  "handoff": {
    "key_files": ["[most important output files]"],
    "decisions": ["[key decisions made]"],
    "blockers": [],
    "next_focus": "[what successor should prioritize]"
  }
}
```

**New Fields (v1.1.0, all optional)**:
- `protocol_version`: Set to "1.1.0" if using new fields (default: "1.0.0")
- `agent_id`: Your unique identifier (e.g., "agent-abc123")
- `confidence`: Your confidence in output quality ("high", "medium", "low")
- `handoff`: Structured alternative to `next_phase_context` (can use both)

---

## Template Notes

**Customization**:
- Replace all REPLACE_WITH_* placeholders
- Remove sections not applicable to your output
- Add sections as needed for your specific analysis
- Keep total length under 3000 tokens when possible (for token efficiency)

**Best Practices**:
- Front-load critical information (Summary, Decisions)
- Use tables and lists for scanability
- Include file paths with line numbers for code references
- Be concise but complete
- Provide clear next steps for subsequent phases

---

**Template Version**: 1.1.0
**Last Updated**: 2025-02-24
**Protocol Version**: 1.1.0
