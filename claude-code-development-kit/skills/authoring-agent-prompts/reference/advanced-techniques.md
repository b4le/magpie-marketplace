# Advanced Techniques

Advanced prompt engineering techniques for complex scenarios and optimal results.

**When to use these techniques:**
- Complex decision-making scenarios
- Critical production implementations
- Multi-option trade-off analysis
- Tasks requiring high reliability

## Conditional Logic

**Pattern:**
```
Analyze the codebase and determine if we're using Redux or Context API for state management.

Based on what you find:
- If Redux: Follow the existing slice pattern
- If Context: Follow the existing context provider pattern
- If neither: Recommend and implement the most appropriate solution given our stack

Then implement the user preferences feature using the identified pattern.
```

**Why it works:** Conditional logic allows Claude to adapt to different codebases without hardcoding assumptions.

**Best Practice:** Always include a fallback case ("If neither:") to handle unexpected situations.

## Staged Verification

**Pattern:**
```
Implement the payment processing feature in stages with verification:

Stage 1: Create API endpoint
- Implement endpoint
- Run tests
- STOP if tests fail

Stage 2: Add validation
- Implement validation
- Test validation
- STOP if tests fail

Stage 3: Integrate payment provider
- Add provider integration
- Test integration
- STOP if tests fail

Only proceed to next stage if current stage's tests pass.
```

**Why it works:** Catches errors early before they compound across stages.

**Tip:** Use explicit "STOP if" conditions to create gate checks between stages.

**Related:** See @long-horizon-patterns.md for multi-phase task structures.

## Comparative Analysis

**Pattern:**
```
Compare three approaches to implementing real-time updates:

1. WebSockets
2. Server-Sent Events
3. Polling

For each, analyze:
- Implementation complexity
- Performance characteristics
- Browser compatibility
- Scalability
- Fit with our current architecture

Recommend the best approach with justification.
```

**Why it works:** Structured comparison forces thorough evaluation across consistent criteria.

**Best Practice:** Define evaluation criteria upfront to ensure apples-to-apples comparison.

**Tip:** Request extended thinking for complex comparative analyses to get deeper reasoning.

## Exploration with Constraints

**Pattern:**
```
Explore the codebase to understand our current testing approach.

Focus on:
- Test frameworks and libraries used
- Test file organization
- Mocking patterns
- Coverage requirements

Look in:
- package.json for dependencies
- Existing test files
- CI/CD configuration
- Test scripts

Limit exploration to testing-related files to stay focused.
```

**Why it works:** Constraints prevent scope creep and keep exploration targeted.

**Best Practice:** Specify both what to focus on AND what to ignore/limit.

## Response Prefilling

Guide Claude's response by starting it for them.

**Pattern:**
```
Analyze the performance issues in the Dashboard component.

Start your response with:

"I've identified the following performance issues:

1. "
```

**Why it works:**
- **Format consistency** - Ensures responses follow your expected structure
- **Reduces fluff** - Gets straight to the point
- **Predictable output** - Makes parsing/processing easier

**Tip:** Combine with XML tags for even more structured output.

**Example - Code review**:
```
Review this pull request for security issues.

Begin with: "Security Review Results:

Critical Issues:
1. "
```

**Example - Structured analysis**:
```
Compare React vs Vue for our project.

Respond with: "Framework Comparison:

| Criteria | React | Vue |
|----------|-------|-----|
| Learning curve | "
```

## Prompt Generator Pattern

For complex recurring tasks, have Claude generate the perfect prompt:

**Meta-prompt**:
```
I need to create a prompt template for code reviews. The prompt should:
- Check for security issues
- Verify test coverage
- Check code quality
- Suggest improvements

Generate a reusable prompt template I can use for all code reviews. Include placeholders for the file path and specific areas to focus on.
```

**Claude generates**:
```
Review {FILE_PATH} for code quality and security.

<focus_areas>
{SPECIFIC_AREAS}
</focus_areas>

<checklist>
Security:
- [ ] No SQL injection vulnerabilities
- [ ] Input validation present
- [ ] Authentication/authorization checked

Quality:
- [ ] Follows project conventions
- [ ] No code duplication
- [ ] Clear naming

Testing:
- [ ] Unit tests present
- [ ] Edge cases covered
- [ ] Integration tests if needed
</checklist>

Provide specific feedback with file:line references.
```

**Then save as slash command** for reuse.

## Triggering Extended Thinking

For complex decisions, explicitly request extended thinking:

**Pattern**:
```
This is a complex architectural decision with long-term implications.

Use extended thinking to:
1. Analyze our current architecture
2. Consider 3-5 different approaches
3. Weigh pros and cons of each
4. Consider future scalability
5. Recommend the best solution with detailed justification

Then provide your recommendation.
```

**When to request extended thinking**:
- Architectural decisions
- Complex refactoring approaches
- Technology selection
- Performance optimization strategies
- Security architecture design

**Example**:
```
We need to implement caching for our API.

Use extended thinking to evaluate:
- Redis vs Memcached vs in-memory
- Cache invalidation strategies
- Distributed caching considerations
- Cost/performance tradeoffs

Provide detailed recommendation with implementation approach.
```

## Self-Correction Chain

For critical tasks, build in verification steps:

**Pattern**:
```
Implement user authentication with JWT tokens.

After implementation:
1. Review your code for security vulnerabilities
2. Check against OWASP Top 10
3. Verify all edge cases are handled
4. If you find issues, fix them before marking complete
5. Provide a security checklist of what was implemented
```

**Multi-stage verification**:
```
Refactor the data access layer.

Process:
1. Analyze current implementation and identify issues
2. Design new approach
3. Implement changes
4. Review your implementation for issues
5. Run tests and fix any failures
6. Review again - did you introduce any bugs?
7. Only then mark as complete
```

**Why this works**:
- Catches mistakes before user sees them
- Encourages thorough testing
- Improves output quality
- Reduces back-and-forth
