# Communication Style Patterns

Best practices for shaping how Claude communicates progress, findings, and results.

**When to use these patterns:**
- Complex prompts with multiple requirements
- Tasks where output format matters
- Multi-part instructions needing clear structure
- Visual or spatial requirements

## Request Concise Progress Updates

**Pattern:**
```
Refactor the data layer to use the repository pattern.

Provide brief progress updates after each major step, but don't explain every detail unless there's an issue.
```

**Why it works:** Reduces verbosity while maintaining transparency.

**Tip:** Add "brief updates" or "concise progress" to prevent overly detailed explanations of simple operations.

## Ask for Thinking When Needed

**Pattern:**
```
This is a complex architectural decision about state management.

Use extended thinking to:
1. Analyze our current patterns
2. Consider trade-offs of different approaches
3. Recommend the best solution with justification
```

**When to request extended thinking:**
- Architectural decisions with long-term impact
- Complex trade-off analysis
- Technology selection
- Performance optimization strategies

**Related:** See @advanced-techniques.md "Triggering Extended Thinking" for detailed guidance.

## Focus on Action Items

| Quality | Example |
|---------|---------|
| **Good** ✅ | `Found 5 type errors. Fixing them now.`<br>`[makes edits]`<br>`All type errors resolved.` |
| **Bad** ❌ | `I found type errors in the code. Let me explain what type errors are and why they occur. TypeScript is a statically typed language that... [lengthy explanation] ...now I'll fix them.` |

**Why it works:** Action-focused responses save time and reduce noise.

**Tip:** Request "explain only if there's an issue or unexpected finding" to minimize unnecessary explanations.

## Use XML Tags for Complex Structure

For complex, multi-part instructions, use XML-style tags for clarity.

**Pattern:**
```
Review the authentication system and provide a security analysis.

<requirements>
- Check for SQL injection vulnerabilities
- Review password hashing
- Verify session management
- Check CSRF protection
</requirements>

<output_format>
Provide findings in this format:
1. Critical Issues (must fix immediately)
2. High Priority (fix before production)
3. Recommendations (nice to have)

For each issue include:
- File and line number
- Description of vulnerability
- Specific fix recommendation
</output_format>

<constraints>
- Focus on OWASP Top 10
- Don't suggest changes that break backward compatibility
- Provide working code examples for fixes
</constraints>
```

**Why XML tags help:**
- **Clear separation** - Distinct sections for requirements, format, constraints
- **Easy parsing** - Claude can identify and follow each section independently
- **Reduced ambiguity** - No confusion about which instruction applies where
- **Better organization** - Natural structure for complex multi-part tasks

**Best Practice:** Use consistent tag names across prompts (e.g., always use `<requirements>` not alternating with `<needs>`).

## Visual References

When working with UI/UX, reference visual patterns clearly.

**Pattern:**
```
Implement a dashboard layout with:

<layout>
+----------------------------------+
|         Header (60px)             |
+--------+-------------------------+
|        |                         |
| Sidebar|     Main Content        |
| (200px)|                         |
|        |                         |
+--------+-------------------------+
|         Footer (40px)             |
+----------------------------------+
</layout>

<colors>
- Header: #1a202c (dark gray)
- Sidebar: #2d3748 (gray)
- Main: #ffffff (white)
- Footer: #f7fafc (light gray)
</colors>

<responsive>
Mobile (<768px): Stack vertically, hide sidebar
Tablet (768-1024px): Collapsible sidebar
Desktop (>1024px): Fixed sidebar
</responsive>
```

**ASCII diagrams for data flow**:
```
Implement authentication flow:

User → Login Form → API → Validate → Generate JWT → Response
                            ↓
                        Database
                            ↓
                    Verify Credentials

On success: Return JWT + User Data
On failure: Return 401 + Error Message
```
