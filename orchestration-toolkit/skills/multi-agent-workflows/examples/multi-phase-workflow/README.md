# Multi-Phase Workflow Example: OAuth 2.0 Integration

## Overview

This example demonstrates a complete orchestrated workflow implementing Google OAuth 2.0 authentication through all 5 phases of the multi-agent-workflows framework.

**Scenario**: "Integrate OAuth 2.0 authentication with Google for our Node.js/Express application"

**Total Duration**: 7.5 hours
**Total Agents**: 5 (1 per phase)
**Total Tokens**: 148,500 tokens
**Status**: Completed successfully

---

## The 5 Phases

### Phase 1: Planning (90 minutes)
**Agent**: `agent-001-requirements`
**Objective**: Define requirements, assess current state, and create implementation roadmap

**Key Outputs**:
- User authentication requirements (MFA, session management, OAuth scopes)
- Current system analysis (Express app with basic auth middleware)
- Technology decisions (Google OAuth 2.0, Passport.js, Redis sessions)
- Task breakdown with 12 discrete implementation steps

**Critical Decisions**:
- Use Google OAuth 2.0 (supports enterprise G Suite accounts)
- Store sessions in Redis (horizontal scalability)
- Implement refresh token rotation (security best practice)

**Handoff**: Research phase should investigate OAuth 2.0 security patterns and Passport.js integration approaches.

---

### Phase 2: Research (90 minutes)
**Agent**: `agent-002-oauth-security`
**Objective**: Research OAuth 2.0 best practices, security patterns, and implementation approaches

**Key Outputs**:
- OAuth 2.0 flow analysis (Authorization Code with PKCE)
- Security requirements (CSRF protection, state validation, token encryption)
- Passport.js strategy evaluation (passport-google-oauth20)
- OWASP compliance checklist

**Critical Decisions**:
- Implement PKCE (Proof Key for Code Exchange) for enhanced security
- Use httpOnly cookies for session tokens (XSS mitigation)
- Implement token encryption at rest (Redis storage)

**Handoff**: Design phase should create OAuth flow diagrams and data models incorporating PKCE and token encryption.

---

### Phase 3: Design (90 minutes)
**Agent**: `agent-003-oauth-flow`
**Objective**: Design OAuth flow, database schema, API endpoints, and error handling

**Key Outputs**:
- OAuth 2.0 flow diagram with PKCE implementation
- Database schema (users, sessions, refresh_tokens tables)
- API endpoint specifications (5 routes)
- Error handling and edge case documentation

**Critical Decisions**:
- Use separate table for refresh tokens (easier rotation/revocation)
- Implement 3 retry attempts for token refresh (resilience)
- Add user_metadata JSONB field (extensibility)

**Handoff**: Execution phase should implement endpoints in this order: login → callback → profile → logout → refresh. Reference flow diagram for PKCE implementation details.

---

### Phase 4: Execution (150 minutes)
**Agent**: `agent-004-implementation`
**Objective**: Implement OAuth 2.0 integration with all security patterns

**Key Outputs**:
- 8 new files created (routes, middleware, config, models)
- Passport.js strategy configured with PKCE
- Redis session store integration
- Environment configuration (.env.example)

**Critical Decisions**:
- Use helmet.js for security headers (added dependency)
- Implement graceful Redis connection handling (fallback to memory store in dev)
- Add comprehensive logging (Winston logger integration)

**Handoff**: Review phase should focus on security validation: PKCE implementation, token encryption, session security, and error handling completeness.

---

### Phase 5: Review (60 minutes)
**Agent**: `agent-005-security-review`
**Objective**: Security audit, code quality review, and production readiness assessment

**Key Outputs**:
- Security audit report (18 checks, 2 medium-priority findings)
- Code quality analysis (ESLint, TypeScript strict mode recommendations)
- Production readiness checklist (12 items, 10 complete)
- Testing recommendations (unit, integration, E2E)

**Critical Findings**:
- Medium: Rate limiting not implemented (recommend express-rate-limit)
- Medium: No monitoring/alerting for failed auth attempts
- Low: Consider adding OAuth consent screen customization

**Status**: Production-ready with 2 recommended enhancements (not blocking)

---

## Key Learning: Cross-Phase Context Handoff

This example demonstrates **effective context transfer** between phases:

### 1. Phase Summaries as Primary Handoff
Each phase creates a comprehensive summary that the next phase reads:
- Planning → Research: "Investigate OAuth 2.0 security patterns and Passport.js"
- Research → Design: "Incorporate PKCE and token encryption in flow design"
- Design → Execution: "Implement endpoints in specified order, reference PKCE diagram"
- Execution → Review: "Focus on PKCE, token encryption, session security"

### 2. Shared Decision Log
All architectural decisions accumulate in `shared/decisions.md`:
- Planning adds: OAuth provider choice, session storage strategy
- Research adds: PKCE requirement, cookie security settings
- Design adds: Database schema decisions
- Execution adds: Library choices (helmet.js, Winston)
- Review adds: Production recommendations

### 3. Glossary Evolution
Domain terminology is captured in `shared/glossary.md`:
- Planning: Basic OAuth terms (authorization code, access token)
- Research: Security terms (PKCE, code verifier, code challenge)
- Design: Implementation terms (refresh token rotation, session fingerprinting)

### 4. Minimal Context Transfer
Each agent receives **only what it needs**:
- Agent 2 doesn't read Agent 1's full output (3,200 tokens)
- Agent 2 reads Planning phase summary (800 tokens) - **4x more efficient**
- Agent 3 reads Research phase summary (850 tokens)
- Pattern continues through all phases

**Result**: Main orchestrator context never exceeded 15K tokens despite 148K total workflow tokens.

---

## Workflow State Progression

Three snapshots show workflow evolution:

### 1. Initial State (`workflow-state-initial.yaml`)
- Just started planning phase
- All phases pending
- No agents completed
- No decisions made

### 2. Midpoint State (`workflow-state-midpoint.yaml`)
- Design phase just completed
- 3 agents completed (planning, research, design)
- 83,500 tokens used (56% of budget)
- 8 key decisions made
- Ready to begin execution

### 3. Final State (`workflow-state-final.yaml`)
- All phases completed
- 5 agents completed successfully
- 148,500 tokens used (99% of budget - excellent planning!)
- 14 total decisions made
- 2 follow-up recommendations for future work

---

## Navigation Guide

### Start Here
1. **This README** - Overview and phase summary
2. **workflow-state-final.yaml** - Final workflow metrics

### Explore Each Phase
Each phase archive contains:
- `phase-summary.md` - Comprehensive phase overview (read this first)
- Agent outputs - Detailed findings and decisions

**Recommended Reading Order**:
```
1. archive/planning-20251124T0900/phase-summary.md
2. archive/research-20251124T1015/phase-summary.md
3. archive/design-20251124T1145/phase-summary.md
4. archive/execution-20251124T1400/phase-summary.md
5. archive/review-20251124T1630/phase-summary.md
```

### Deep Dive into Specific Agents
- **Planning**: `archive/planning-20251124T0900/agent-001-requirements.md`
- **Design**: `archive/design-20251124T1145/agent-003-oauth-flow/READ-FIRST.md` (multi-file output)
- **Review**: `archive/review-20251124T1630/agent-005-security-review.md`

### Cross-Phase References
- **shared/decisions.md** - All architectural decisions chronologically
- **shared/glossary.md** - OAuth and security terminology

---

## File Structure

```
multi-phase-workflow/
├── README.md (this file)
├── workflow-state-initial.yaml
├── workflow-state-midpoint.yaml
├── workflow-state-final.yaml
│
├── archive/
│   ├── planning-20251124T0900/
│   │   ├── phase-summary.md
│   │   └── agent-001-requirements.md
│   │
│   ├── research-20251124T1015/
│   │   ├── phase-summary.md
│   │   └── agent-002-oauth-security.md
│   │
│   ├── design-20251124T1145/
│   │   ├── phase-summary.md
│   │   └── agent-003-oauth-flow/
│   │       ├── READ-FIRST.md
│   │       ├── oauth-flow-diagram.md
│   │       ├── database-schema.sql
│   │       └── api-endpoints.md
│   │
│   ├── execution-20251124T1400/
│   │   ├── phase-summary.md
│   │   └── agent-004-implementation.md
│   │
│   └── review-20251124T1630/
│       ├── phase-summary.md
│       └── agent-005-security-review.md
│
└── shared/
    ├── decisions.md
    └── glossary.md
```

---

## Key Takeaways

### What Worked Well

1. **Progressive Refinement**: Each phase built on previous decisions without re-investigating
2. **Token Efficiency**: 148K tokens across 5 agents; main orchestrator used only 15K
3. **Clear Handoffs**: Phase summaries provided exactly the context needed
4. **Decision Tracking**: `shared/decisions.md` prevented decision thrashing
5. **Security Focus**: Research phase findings influenced all subsequent phases

### Orchestration Patterns Demonstrated

1. **One Agent Per Phase**: Simple, clear ownership
2. **Phase Summaries**: 800-token summaries instead of 3K+ full outputs
3. **Shared State**: Decisions and glossary accumulated across phases
4. **Sequential Dependencies**: Each phase needed previous phase complete
5. **No Parallel Agents**: OAuth implementation required sequential understanding

### When to Use This Pattern

**Good fit**:
- Complex features requiring research → design → implementation
- Security-sensitive implementations
- New technology integration (OAuth, payment providers, etc.)
- Multi-week projects with clear phases

**Not a good fit**:
- Simple CRUD features
- Bug fixes (use single execution agent)
- Parallel work (use parallel agent pattern instead)
- Urgent hotfixes (too much overhead)

---

## Adapting This Example

To adapt this for your own multi-phase workflow:

1. **Copy the structure**: Use the 5-phase folders and state files
2. **Customize phase objectives**: Replace OAuth content with your feature
3. **Adjust agent count**: Some phases may need 2-3 agents for parallel work
4. **Maintain handoff pattern**: Always create phase summaries for next phase
5. **Use shared files**: Track decisions and glossary across phases

---

**Example Version**: 1.0.0
**Created**: 2025-11-24
**Framework**: multi-agent-workflows v1.0.0
