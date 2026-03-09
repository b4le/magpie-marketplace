---
phase: planning
purpose: Define password reset requirements and security approach
created_at: 2025-11-24T14:00:00Z
inputs_from_phases: []
expected_outputs: [requirements.md, security-constraints.yaml]
token_budget: 50000
sub_agents_expected: 1
---

# Planning Phase: Password Reset Feature

## Objective

Establish clear requirements for password reset functionality including user flows, security constraints, and technical approach. Analyze industry best practices and define success criteria for implementation.

---

## Prerequisites

### Context Required

Before working in this phase, read:

- **Project Context**:
  - Existing authentication system (assumed to use email/password)
  - User database schema
  - Email service configuration

### Tools and Access

- [x] Read access to authentication codebase
- [x] Write access to `.development/workflows/password-reset-example/active/planning/`
- [x] Tool permissions: Read, Write, Edit, Grep, Glob
- [ ] (Optional) Access to security compliance documentation

---

## Instructions for Sub-Agents

### What You Should Do

1. **Read Context**: Review existing authentication system
2. **Understand Scope**: Analyze password reset requirements
3. **Execute Task**: Define requirements, user stories, security approach
4. **Write Outputs**: Create requirements document in this directory
5. **Update Status**: Modify `STATUS.yaml` to reflect completion
6. **Signal Completion**: Return JSON with outputs and summary

### Output Naming Conventions

**Single-file output:**
```
active/planning/agent-001-requirements.md
```

---

## Expected Outputs

This phase should produce:

1. **Requirements Analysis**: User stories, technical requirements, security considerations
   - Format: Markdown
   - Example: `agent-001-requirements.md`

### Quality Criteria

Outputs should be:
- ✅ **Complete**: Cover all aspects of password reset flow
- ✅ **Security-Focused**: Address token expiry, rate limiting, email verification
- ✅ **Structured**: Clear sections for user stories, technical specs, decisions
- ✅ **Referenced**: Include industry best practices and security standards
- ✅ **Token-Efficient**: Aim for 2000-3000 tokens

---

## Boundaries and Constraints

### What You CAN Do

- ✅ Research industry best practices for password reset
- ✅ Define security constraints (token expiry, rate limits)
- ✅ Create user stories and acceptance criteria
- ✅ Recommend technical approach
- ✅ Ask questions about business requirements

### What You CANNOT Do

- ❌ Implement code (that's for implementation phase)
- ❌ Modify existing authentication system
- ❌ Make final decisions on UX without orchestrator approval

---

## Success Criteria

This phase is considered successful when:

- [ ] User stories defined for password reset flow
- [ ] Security constraints documented (token expiry, rate limits)
- [ ] Technical approach recommended (email-based vs SMS vs security questions)
- [ ] Edge cases identified (expired tokens, invalid emails)
- [ ] Next phase has clear context for implementation

---

**Phase README Version**: 1.0.0
**Last Updated**: 2025-11-24T14:00:00Z
