# Research and Synthesis Patterns

Best practices for prompting Claude to research, investigate, and synthesize information from multiple sources.

**When to use these patterns:**
- Understanding unfamiliar codebases
- Investigating bugs with unknown root causes
- Comparing implementation approaches
- Verifying assumptions before implementation

## Provide Success Criteria

**Pattern:**
```
Research best practices for React error boundaries.

Success criteria:
- Find at least 3 authoritative sources
- Include code examples
- Cover both class and functional component approaches
- Address TypeScript typing
- Include testing strategies

Cite sources for verification.
```

**Why it works:** Clear success criteria prevent incomplete or unfocused research.

**Tip:** Quantify expectations (e.g., "at least 3 sources", "cover both X and Y") to ensure thoroughness.

**Warning:** Without success criteria, Claude may stop research prematurely or include irrelevant information.

## Encourage Investigation Over Assumptions

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `The API is probably using REST, so...` |
| **Good** ✅ | `Before implementing the client:`<br>`1. Examine the API documentation`<br>`2. Check existing API calls in the codebase`<br>`3. Identify the API pattern (REST, GraphQL, etc.)`<br>`4. Verify authentication method`<br><br>`Then implement the client based on actual findings.` |

**Why it works:** Investigation-first approach grounds implementation in reality, not assumptions.

**Common Pitfall:** Allowing Claude to make assumptions about "typical" patterns leads to mismatches with your actual codebase.

## Source Verification

**Pattern:**
```
Research the latest React Server Components best practices.

Requirements:
- Use official React documentation as primary source
- Cross-reference with community best practices
- Verify information is current (2024-2025)
- Note any conflicting recommendations and why
```

**Why it works:** Source prioritization ensures authoritative, current information.

**Best Practice:** Always specify time boundaries for "latest" or "current" information to avoid outdated advice.

**Related:** See @../SKILL.md "Error Prevention" section for grounding techniques.
