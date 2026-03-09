# Code Review Template

## Purpose
A comprehensive checklist for reviewing code quality, functionality, testing, performance, and security.

## Usage
Use this template when conducting code reviews to ensure thorough evaluation across all critical dimensions.

**Best for:**
- Pull request reviews
- Pre-merge code audits
- Security assessments
- Quality gate checks

## Template

```
Review [file/feature] for:

Code Quality:
- [ ] Follows project conventions
- [ ] Proper TypeScript types
- [ ] No code duplication
- [ ] Clear naming

Functionality:
- [ ] Implements requirements correctly
- [ ] Handles edge cases
- [ ] Proper error handling
- [ ] Input validation

Testing:
- [ ] Unit tests present
- [ ] Tests cover edge cases
- [ ] Integration tests if needed

Performance:
- [ ] No obvious performance issues
- [ ] Efficient algorithms
- [ ] Proper data structures

Security:
- [ ] No XSS vulnerabilities
- [ ] No SQL injection risks
- [ ] Proper authentication/authorization
- [ ] Sensitive data handled securely

Provide specific feedback with file:line references.
```
