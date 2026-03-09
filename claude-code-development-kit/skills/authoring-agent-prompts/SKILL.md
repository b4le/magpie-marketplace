---
name: authoring-agent-prompts
description: >
  Comprehensive guidance for writing effective prompts when working with Claude Code agents,
  skills, and tasks. Covers core principles, tool usage patterns, research synthesis,
  error prevention, communication strategies, and workflow templates. Use when crafting
  agent prompts, structuring complex tasks, debugging agent behaviors, or improving
  prompt quality.
tags:
  - prompt-engineering
  - agent-patterns
  - best-practices
  - workflows
  - communication
version: 1.0.0
created: 2025-11-20
last_updated: 2026-02-28
---

## When to Use This Skill

Use this skill when:
- Crafting prompts for agents, skills, or tasks that aren't producing desired results
- Structuring multi-step workflows or complex task breakdowns
- Debugging unexpected agent behaviors or hallucinations
- Improving prompt quality to reduce back-and-forth clarification
- Learning prompt engineering patterns optimized for Claude Code

### Do NOT Use This Skill When:
- ❌ Writing simple, one-off prompts for basic tasks → Just write the prompt directly
- ❌ Need hands-on implementation guidance → Use `authoring-skills` or `creating-commands` instead
- ❌ Troubleshooting technical issues with Claude Code → Use `resolving-claude-code-issues` instead
- ❌ Need git-specific prompt patterns → Use `managing-git-workflows` instead

## Core Principles

### 1. Be Explicit and Specific

Claude performs best with clear, detailed instructions.

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `Make the code better` |
| **Good** ✅ | `Refactor the UserProfile component to:`<br>`1. Extract the data fetching logic into a custom hook`<br>`2. Add loading and error states`<br>`3. Implement proper TypeScript types for the user data`<br>`4. Add unit tests for the new hook` |

**Why it works:** Specific instructions leave no ambiguity about what "better" means.

**Tip:** Front-load important keywords in your prompts. Put the most critical action or file path first.

### 2. Provide Context and Motivation

Explain WHY something is important, not just WHAT to do.

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `Add error handling` |
| **Good** ✅ | `Add error handling to the API calls because users are experiencing silent failures when the network is unstable. We need to:`<br>`1. Show user-friendly error messages`<br>`2. Log errors for debugging`<br>`3. Implement retry logic for transient failures` |

**Why it works:** Context helps Claude make better decisions about implementation details.

**Best Practice:** Include the business value or user impact to help Claude prioritize edge cases.

### 3. Request Action, Not Suggestions

Be direct when you want Claude to do something.

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `Could you maybe suggest some ways we might improve the performance?` |
| **Good** ✅ | `Analyze the performance of the Dashboard component and implement optimizations. Focus on:`<br>`- Reducing unnecessary re-renders`<br>`- Optimizing data fetching`<br>`- Implementing virtualization for long lists` |

**Why it works:** Direct requests lead to action rather than just discussion.

**Common Pitfall:** Avoid tentative language like "maybe", "could you", "perhaps". Use imperative verbs instead.


## Error Prevention

### Request Investigation First

**Pattern:**
```
Before answering the question about how authentication works in this app:
1. Search for auth-related files
2. Read the auth configuration
3. Examine the middleware
4. Check the session handling

Then explain how it works based on the actual implementation, not assumptions.
```

**Why it works:** Prevents hallucinations by grounding responses in actual code.

**Warning:** Never let Claude assume patterns or configurations. Always request explicit investigation.

### Avoid Hard-Coding

| Quality | Example |
|---------|---------|
| **Bad** ❌ | `Add the API endpoint to the code` |
| **Good** ✅ | `Add the API endpoint, but:`<br>`1. First check if there's an environment variable for the API base URL`<br>`2. Use the existing pattern for endpoint configuration`<br>`3. Don't hard-code URLs - use the project's configuration approach` |

**Why it works:** Ensures implementation follows project patterns and is maintainable.

**Best Practice:** Always request Claude to check existing patterns before implementing new features.

### Emphasize Principled Implementation

**Example:**
```
Implement pagination for the user list.

Requirements:
- Don't hard-code page size - make it configurable
- Follow the existing pagination pattern in the codebase
- Handle edge cases (empty results, last page, etc.)
- Implement client-side caching to avoid redundant fetches
```

**Why it works:** Encourages thoughtful implementation rather than quick hacks.

**Related:** See @reference/anti-patterns.md for common mistakes to avoid.


## Measuring Effectiveness

Good prompts lead to:
- ✅ Correct implementation on first try
- ✅ Minimal back-and-forth clarification
- ✅ Code that follows project patterns
- ✅ Comprehensive solution (not missing pieces)
- ✅ Appropriate tool usage

Poor prompts result in:
- ❌ Need for multiple corrections
- ❌ Implementation doesn't match expectations
- ❌ Missing edge cases
- ❌ Code that doesn't follow project style
- ❌ Incomplete solutions


## Supporting Documentation

### Detailed References
@reference/agent-workflows.md - Best practices for working with Claude Code's specialized agents and tools
@reference/communication-patterns.md - Patterns for shaping how Claude communicates progress, findings, and results
@reference/research-patterns.md - Patterns for prompting Claude to research, investigate, and synthesize information from multiple sources
@reference/advanced-techniques.md - Advanced prompt engineering techniques for complex scenarios and optimal results
@reference/anti-patterns.md - Common mistakes in prompt engineering and how to avoid them
@reference/long-horizon-patterns.md - Patterns for structuring multi-step tasks that require state tracking across multiple interactions

### Templates
@templates/feature-implementation.md - Structured approach to implementing new features with clear requirements, constraints, and success criteria
@templates/code-review.md - Comprehensive checklist for reviewing code quality, functionality, testing, performance, and security
@templates/debugging.md - Systematic approach to debugging issues with reproduction steps, expected vs actual behavior, and investigation methodology
@templates/documentation.md - Comprehensive guide for creating effective documentation with clear audience, structure, and practical examples
@templates/refactoring.md - Structured approach to refactoring code while maintaining functionality and ensuring quality through incremental changes


## Version History

**v1.0** - 2025-11-17
- Initial skill creation from prompt-engineering-for-agents.md
- 7 core capabilities documented
- 11 supporting files created (6 reference + 5 templates)
- 11 @path imports for progressive disclosure
- ~350 lines targeting 500-line limit
- Comprehensive coverage of agent prompt engineering patterns
