# Anti-Patterns to Avoid

Common mistakes in prompt engineering and how to avoid them.

**Use this reference to:**
- Debug prompts that aren't working
- Review prompts before submitting
- Train team members on what NOT to do
- Understand why certain approaches fail

## 1. Vague Requests

| Anti-Pattern ❌ | Better Approach ✅ |
|----------------|-------------------|
| `Make it better` | `Improve performance by implementing memoization for expensive calculations` |
| `Fix the bugs` | `Fix the TypeError on line 45 when user is null` |
| `Optimize this` | `Optimize the query by adding an index on user_id column` |

**Why this matters:** Vague requests lead to misaligned solutions and wasted iterations.

**Related:** See @../SKILL.md "Core Principles" for specificity techniques.

## 2. Assuming Context

| Anti-Pattern ❌ | Better Approach ✅ |
|----------------|-------------------|
| `Add authentication like we usually do` | `Add JWT-based authentication following the pattern in the existing auth module (src/auth/)` |

**Why this matters:** Claude doesn't have implicit knowledge of "how we usually do things" unless explicitly told.

**Tip:** Always reference specific files, patterns, or conventions when mentioning "existing" approaches.

## 3. Requesting Explanations Instead of Action

| Anti-Pattern ❌ | Better Approach ✅ |
|----------------|-------------------|
| `Can you explain how we might add a search feature?` | `Implement a search feature for the user list with:`<br>`- Text input for search query`<br>`- Filter by name and email`<br>`- Debounced search (300ms)`<br>`- Clear search button` |

**Why this matters:** Question-based requests trigger explanatory responses, not implementation.

**Common Pitfall:** Using "can you", "could you", "how might we" when you actually want action, not discussion.

## 4. Omitting Success Criteria

| Anti-Pattern ❌ | Better Approach ✅ |
|----------------|-------------------|
| `Add tests for the authentication` | `Add tests for authentication covering:`<br>`- Successful login`<br>`- Failed login (wrong password)`<br>`- Token expiration`<br>`- Logout`<br>`- Protected route access`<br>`Aim for >90% coverage of auth module` |

**Why this matters:** Without success criteria, Claude doesn't know when the task is complete.

**Best Practice:** Quantify expectations wherever possible (coverage %, number of test cases, performance targets).

## 5. Not Using Available Tools

| Anti-Pattern ❌ | Better Approach ✅ |
|----------------|-------------------|
| `Based on typical React apps, you should...` | `First, read the existing React components in src/components/ to understand our patterns, then implement the new feature following those patterns.` |

**Why this matters:** Assumptions about "typical" patterns lead to code that doesn't match your codebase.

**Warning:** Always request explicit investigation using tools (Read, Grep, Glob) before implementation.

**Related:** See @research-patterns.md for investigation strategies.
