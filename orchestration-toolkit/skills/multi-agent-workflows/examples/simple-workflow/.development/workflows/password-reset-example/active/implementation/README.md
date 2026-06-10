---
phase: implementation
purpose: Implement password reset feature based on planning phase requirements
created_at: 2025-11-24T15:00:00Z
inputs_from_phases: [planning]
expected_outputs: [implementation-summary.md, test-results.md]
token_budget: 60000
sub_agents_expected: 1
---

# Implementation Phase: Password Reset Feature

## Objective

Implement password reset functionality based on requirements from planning phase. Create database migration, API endpoints, email templates, rate limiting, and comprehensive tests. Ensure implementation follows security best practices defined in planning.

---

## Prerequisites

### Context Required

Before working in this phase, read:

- **From Previous Phases**:
  - `archive/planning-20251124T1500/phase-summary.md` - Planning phase summary
  - `archive/planning-20251124T1500/agent-001-requirements.md` - Detailed requirements (for database schema and API specs)

- **Project Context**:
  - Existing authentication system structure
  - Email service configuration
  - Database migration conventions

### Tools and Access

- [x] Read access to codebase
- [x] Write access to `.development/workflows/password-reset-example/active/implementation/`
- [x] Tool permissions: Read, Write, Edit, Grep, Glob, Bash
- [x] Database access for migration testing (if available)

---

## Instructions for Sub-Agents

### What You Should Do

1. **Read Context**: Load planning phase summary and requirements
2. **Understand Scope**: Implement 3 API endpoints, database migration, email templates, tests
3. **Execute Task**: Create/modify files as specified in planning requirements
4. **Write Outputs**: Document implementation details, files modified, test results
5. **Update Status**: Modify `STATUS.yaml` to reflect completion
6. **Signal Completion**: Return JSON with outputs and summary

### Output Naming Conventions

**Single-file output:**
```
active/implementation/agent-002-password-reset.md
```

---

## Expected Outputs

This phase should produce:

1. **Implementation Summary**: Files created/modified, implementation notes, testing results
   - Format: Markdown
   - Example: `agent-002-password-reset.md`

### Quality Criteria

Outputs should be:
- ✅ **Complete**: All files from planning requirements created/modified
- ✅ **Tested**: Happy path and edge cases validated
- ✅ **Documented**: Implementation notes explain any deviations from plan
- ✅ **Referenced**: Clear file paths and line numbers for all changes
- ✅ **Token-Efficient**: Aim for 2000-4000 tokens

---

## Boundaries and Constraints

### What You CAN Do

- ✅ Create database migrations
- ✅ Implement API endpoints
- ✅ Create email templates
- ✅ Add rate limiting middleware
- ✅ Write tests for password reset flow
- ✅ Document implementation details

### What You CANNOT Do

- ❌ Modify existing authentication endpoints (unless required)
- ❌ Change database schema beyond planned `password_reset_tokens` table
- ❌ Deviate from security constraints (1-hour expiry, hashed tokens, rate limiting)

---

## Success Criteria

This phase is considered successful when:

- [ ] Database migration created for `password_reset_tokens` table
- [ ] 3 API endpoints implemented (POST forgot-password, GET/POST reset-password)
- [ ] Rate limiting middleware added (3 requests/hour per email)
- [ ] Email templates created (reset link + confirmation)
- [ ] Tests written and passing (happy path + edge cases)
- [ ] Implementation documented with file paths and notes

---

**Phase README Version**: 1.0.0
**Last Updated**: 2025-11-24T15:00:00Z
