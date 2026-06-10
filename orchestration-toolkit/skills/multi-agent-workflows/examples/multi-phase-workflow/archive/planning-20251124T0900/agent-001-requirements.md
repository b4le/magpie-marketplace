---
phase: planning
author_agent: agent-001
created_at: 2025-11-24T09:05:00Z
updated_at: 2025-11-24T10:28:00Z
topic: requirements-analysis
status: completed
tokens_used: 28500
context_sources:
  - Interviews with product team (3 stakeholders)
  - User feedback analysis (87 support tickets)
  - Existing codebase analysis (src/auth/ directory)
  - Analytics data (user demographics)
---

# Requirements Analysis: Google OAuth 2.0 Integration

## Summary

Analyzed current authentication system (basic username/password with in-memory sessions) and identified critical need for Google OAuth 2.0 integration to support enterprise users. Recommended architecture: Google OAuth 2.0 + Redis session storage + refresh token rotation. Key finding: 78% of current users already have Google accounts, making OAuth adoption low-friction. Implementation roadmap created with 12 tasks across 4 phases (research, design, execution, review).

---

## Context

### Inputs Reviewed

**Stakeholder Interviews**:
- Product Manager (Sarah Chen): "Enterprise customers are blocked on G Suite requirement"
- Engineering Lead (David Kim): "In-memory sessions don't scale, need Redis"
- Security Team (Alex Rivera): "Must support MFA, prefer delegating to OAuth provider"

**User Feedback Analysis**:
- 87 support tickets analyzed (past 6 months)
- Top request (34 tickets): "Add Google login option"
- Common complaint (23 tickets): "Lost session after server restart"
- Security concern (12 tickets): "Want to use Google's 2FA instead of separate password"

**Existing Codebase**:
- Files reviewed:
  - `src/auth/middleware.js` (basic auth, 142 lines)
  - `src/auth/routes.js` (login, logout, 98 lines)
  - `src/models/user.js` (Sequelize model, 67 lines)
  - `src/server.js` (Express app initialization, 203 lines)

**Analytics Data**:
- Current users: 4,872 active accounts
- Google account holders: 78% (analytics pixel data)
- Enterprise users: 23% (paid tier)
- Session duration: avg 4.2 hours (poor, should be days)

### Task Assignment

**Assigned by**: Orchestrator (user request: "Integrate Google OAuth 2.0 authentication")
**Assignment**: Analyze current system, define requirements, select technologies, create implementation roadmap
**Scope**:
- ✅ In scope: Google OAuth 2.0, session management, refresh tokens, task breakdown
- ❌ Out of scope: Multi-provider OAuth (GitHub, Microsoft), password migration, UI design

---

## Current System Analysis

### Existing Authentication Architecture

**Stack**:
- Node.js 18, Express 4.18
- PostgreSQL 14 (users table)
- express-session with in-memory store (MemoryStore)
- bcrypt for password hashing

**Authentication Flow** (current):
```
1. POST /login with { email, password }
2. Lookup user in PostgreSQL
3. Compare password with bcrypt.compare()
4. Create session in MemoryStore (in-memory)
5. Set session cookie
6. Return success
```

**users Table Schema** (existing):
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,  -- bcrypt hash
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Session Configuration** (current):
```javascript
app.use(session({
  store: new MemoryStore(),  // ⚠️ Lost on restart
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: false,  // ⚠️ Not HTTPS-only
    maxAge: 3600000  // 1 hour
  }
}));
```

### Limitations Identified

**Critical Issues**:
1. **In-Memory Sessions** ⚠️:
   - Lost on server restart (users logged out)
   - No horizontal scaling (single server only)
   - Impact: 23 support tickets in 6 months

2. **No OAuth Support** ⚠️:
   - Enterprise users can't use G Suite login
   - Blocking 3 enterprise sales deals
   - Impact: $120K ARR pipeline blocked

3. **Short Session Duration** ⚠️:
   - 1-hour sessions too short (industry standard: 7 days)
   - Users complain about frequent re-authentication
   - Impact: Poor UX, 34 support tickets

4. **No MFA** ⚠️:
   - Basic auth doesn't support 2FA
   - Security team concerned
   - Impact: Security audit flagged as medium risk

**Non-Critical Issues**:
- Cookie not secure (HTTPS-only) in production config
- No refresh token support
- Password reset flow fragile (relies on email, no backup)

---

## User Requirements

### From Product Team

**Enterprise Users** (Priority P0):
- "Need G Suite login to avoid managing separate passwords"
- "Want SSO experience like other SaaS tools"
- "Must work with Google Workspace admin controls"

**Security Team** (Priority P0):
- "Require MFA support (Google provides this)"
- "Prefer delegating authentication to established provider"
- "Need audit trail for login events"

**Ops Team** (Priority P0):
- "Sessions must persist across deployments"
- "Need horizontal scaling for multi-server setup (Q1 2026 roadmap)"
- "Redis already available (used for caching)"

**Development Team** (Priority P1):
- "Well-documented solution (OAuth libraries, not custom)"
- "Maintainable long-term (active library updates)"
- "Easy local development setup"

### From User Feedback

**Top Requests** (from 87 support tickets):
1. "Add Google login option" (34 tickets, 39%)
2. "Lost session after server restart" (23 tickets, 26%)
3. "Want to use Google's 2FA" (12 tickets, 14%)
4. "Session timeout too short" (8 tickets, 9%)
5. "Forgot password flow broken" (6 tickets, 7%)

**User Quotes**:
> "I use Google login for everything else, why not here?"
> — Enterprise user (support ticket #4821)

> "Got logged out during deployment yesterday, lost my work."
> — Power user (support ticket #4756)

> "Please add 2FA, I have sensitive data in my account."
> — Security-conscious user (support ticket #4692)

---

## Technology Decisions

### Decision 1: OAuth Provider Selection

**Chosen**: Google OAuth 2.0

**Evaluation Matrix**:

| Provider | Pros | Cons | Score |
|----------|------|------|-------|
| **Google OAuth 2.0** ✅ | G Suite support, 78% user coverage, free tier, excellent docs | Vendor lock-in (mitigated by OAuth 2.0 standard) | 9/10 |
| Auth0 | Multi-provider, good DX | $240/month (unnecessary cost), overkill for 5K users | 6/10 |
| Okta | Enterprise features | $8/user/month ($3,200/month), enterprise-focused | 5/10 |
| Custom OAuth | Full control | Massive security risk, maintenance burden | 2/10 |

**Rationale**:
- 78% of users already have Google accounts (low adoption friction)
- Enterprise customers specifically requested G Suite integration
- Free tier sufficient (up to 100K users)
- Excellent documentation (better than Auth0 for Node.js)

**Risk Mitigation**:
- OAuth 2.0 is standard protocol (can switch providers later if needed)
- Not locked into Google-specific features (using standard OAuth)

**Decision Made**: 2025-11-24T09:45:00Z

### Decision 2: Session Storage Strategy

**Chosen**: Redis cluster (existing infrastructure)

**Evaluation Matrix**:

| Storage | Pros | Cons | Score |
|---------|------|------|-------|
| **Redis** ✅ | Already deployed, horizontal scaling, persistence, <1ms performance | Additional infrastructure dependency | 9/10 |
| PostgreSQL | Single infrastructure dependency | 10-50ms latency, unnecessary DB load | 6/10 |
| In-Memory | Simple, fast | Lost on restart, no horizontal scaling | 3/10 |
| JWT-only (no sessions) | Stateless, scalable | Hard to revoke, larger payload, less secure | 5/10 |

**Rationale**:
- Redis already running (used for caching, no new infrastructure)
- Sub-millisecond performance (10-100x faster than PostgreSQL)
- Horizontal scaling requirement (Q1 2026 multi-server deployment)
- Session persistence (solves restart logout issue)

**Configuration**:
- Redis cluster: 3 nodes (existing setup, used for caching)
- Session TTL: 7 days (industry standard, user request)
- Failover: Automatic (Redis Sentinel)

**Decision Made**: 2025-11-24T10:15:00Z

### Decision 3: Refresh Token Strategy

**Chosen**: Refresh token rotation (OAuth 2.0 best practice)

**Evaluation**:
- ✅ Refresh tokens: Long-lived sessions without storing access tokens
- ✅ Token rotation: Security best practice per RFC 6749
- ❌ Static refresh tokens: Security risk if leaked

**Rationale**:
- Security audit requirement (limit impact of token theft)
- OAuth 2.0 Security Best Practices recommendation (draft-ietf-oauth-security-topics)
- Industry standard (implemented by Auth0, Okta, Google)

**Implementation**:
- Refresh token lifetime: 90 days
- Rotation on each use (old token invalidated, new token issued)
- Detection of token reuse (security incident indicator)

**Decision Made**: 2025-11-24T10:20:00Z

---

## Implementation Roadmap

### Task Breakdown (12 Tasks)

**Research Phase** (2 tasks, ~90 min):
1. **OAuth 2.0 Security Patterns** (60 min)
   - Research: PKCE requirement, token encryption, cookie security
   - Deliverable: Security best practices document

2. **Passport.js Library Evaluation** (30 min)
   - Compare: passport-google-oauth20 vs google-auth-library vs custom
   - Deliverable: Library recommendation with rationale

**Design Phase** (3 tasks, ~90 min):
3. **OAuth Flow Diagram** (40 min)
   - Design: Login → Callback → Token Exchange → Session Creation
   - Deliverable: Visual flow diagram with PKCE

4. **Database Schema Design** (30 min)
   - Design: users table updates, refresh_tokens table
   - Deliverable: Migration SQL script

5. **API Endpoint Specification** (20 min)
   - Design: /auth/google, /auth/google/callback, /auth/profile, /auth/logout, /auth/refresh
   - Deliverable: Endpoint specs with request/response schemas

**Execution Phase** (5 tasks, ~150 min):
6. **Database Migration** (20 min)
   - Create: Migration script, run against dev/staging
   - Deliverable: users and refresh_tokens tables

7. **Passport.js Strategy Configuration** (30 min)
   - Implement: passport-google-oauth20 strategy with PKCE
   - Deliverable: src/auth/passport-config.js

8. **OAuth Route Handlers** (60 min)
   - Implement: 5 endpoints (login, callback, profile, logout, refresh)
   - Deliverable: src/auth/routes.js

9. **Redis Session Store Integration** (25 min)
   - Implement: connect-redis configuration, encryption
   - Deliverable: src/config/redis-session.js

10. **Environment Configuration** (15 min)
    - Create: .env.example with all OAuth variables
    - Deliverable: Configuration documentation

**Review Phase** (2 tasks, ~60 min):
11. **Security Audit** (40 min)
    - Verify: PKCE implementation, token encryption, OWASP checklist
    - Deliverable: Security audit report

12. **Code Quality Review** (20 min)
    - Review: Code organization, error handling, testing recommendations
    - Deliverable: Production readiness assessment

**Total Estimated Effort**: 390 minutes (6.5 hours)

---

## Questions for Orchestrator

### Question 1

**Question**: Should we use session-based or token-based authentication after OAuth?
**Context**: OAuth gives us tokens from Google, but we need to decide how our app manages sessions afterward. Options:
1. Store OAuth tokens in Redis sessions (hybrid approach)
2. Use OAuth tokens directly (stateless, but harder to revoke)
3. Issue our own JWT after OAuth (double-token approach)

**Options**:
- **Option 1 (Hybrid)**: OAuth tokens from Google → Our Redis sessions
  - Pros: Easy revocation, familiar pattern, refresh tokens enable long sessions
  - Cons: Additional storage (Redis)

- **Option 2 (Stateless)**: Use Google OAuth tokens directly
  - Pros: No session storage needed
  - Cons: Hard to revoke, must hit Google API for every request (rate limits)

- **Option 3 (Double Token)**: OAuth → Our JWT
  - Pros: Stateless, scalable
  - Cons: Hard to revoke, larger payload, unnecessary complexity

**My Recommendation**: Option 1 (Hybrid) - Use Google OAuth for initial authentication, create our own Redis-backed session. This gives us revocation control, long-lived sessions via refresh tokens, and familiar session management.

**Blocking**: No - Can proceed with hybrid approach, but good to confirm

---

## Next Steps

### For Next Phase (Research)

**Priority Tasks**:
1. **OAuth 2.0 Security Patterns Research**:
   - PKCE requirement for server-side implementations
   - Token encryption at rest (Redis storage)
   - Cookie security settings (httpOnly, secure, sameSite)
   - OWASP OAuth 2.0 compliance checklist

2. **Passport.js Library Evaluation**:
   - passport-google-oauth20 features and limitations
   - PKCE support verification
   - Community activity and maintenance
   - Integration examples

**Expected Deliverables**:
- Security best practices document (PKCE, encryption, cookies)
- Library recommendation (passport-google-oauth20 likely choice)
- OWASP compliance checklist

**Handoff Context**:
- Google OAuth 2.0 selected (decision 1)
- Redis sessions selected (decision 2)
- Refresh token rotation selected (decision 3)
- User requirements documented (enterprise G Suite support)
- Current system analyzed (basic auth, in-memory sessions)

---

## References

### Files Reviewed

**Current Implementation**:
- `src/auth/middleware.js` - Basic auth middleware (142 lines)
- `src/auth/routes.js` - Login/logout routes (98 lines)
- `src/models/user.js` - User model (67 lines)
- `src/server.js` - Express app (203 lines)

**Configuration**:
- `.env` - Environment variables (SESSION_SECRET, DATABASE_URL, etc.)
- `package.json` - Dependencies (express, express-session, bcrypt, pg, sequelize)

### External References

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749) - Core OAuth 2.0 spec
- [Google OAuth 2.0 Docs](https://developers.google.com/identity/protocols/oauth2) - Google implementation
- [Passport.js](http://www.passportjs.org/) - Authentication middleware
- [Redis Session Store](https://github.com/tj/connect-redis) - connect-redis library
- [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics) - IETF security guidelines

---

## Agent Output Metadata

**Agent ID**: agent-001
**Workflow ID**: oauth-integration-20251124
**Phase**: planning
**Topic**: requirements-analysis
**Started**: 2025-11-24T09:05:00Z
**Completed**: 2025-11-24T10:28:00Z
**Duration**: 83 minutes
**Tokens Used**: 28,500 (approximate)
**Status**: completed

**Return JSON**:
```json
{
  "status": "finished",
  "output_paths": ["active/planning/agent-001-requirements.md"],
  "questions": [
    {
      "question": "Should we use session-based or token-based authentication after OAuth?",
      "options": ["Hybrid (OAuth + Redis sessions)", "Stateless (OAuth tokens only)", "Double token (OAuth + our JWT)"],
      "recommendation": "Hybrid (OAuth + Redis sessions)",
      "blocking": false
    }
  ],
  "summary": "Analyzed current authentication system and identified Google OAuth 2.0 + Redis sessions + refresh token rotation as recommended architecture. 78% of users already have Google accounts. Created 12-task implementation roadmap across 4 phases. Three key decisions made: (1) Google OAuth 2.0 as provider, (2) Redis for session storage, (3) Refresh token rotation for security.",
  "tokens_used": 28500,
  "next_phase_context": "Research phase should investigate OAuth 2.0 security patterns (PKCE, token encryption, cookie security) and evaluate Passport.js integration approaches. Google OAuth 2.0 confirmed as provider, Redis sessions confirmed as storage strategy."
}
```
