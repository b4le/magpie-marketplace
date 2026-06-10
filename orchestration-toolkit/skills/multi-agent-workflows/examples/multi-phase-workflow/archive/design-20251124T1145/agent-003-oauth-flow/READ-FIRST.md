---
phase: design
author_agent: agent-003
created_at: 2025-11-24T11:48:00Z
updated_at: 2025-11-24T13:12:00Z
topic: oauth-flow-design
status: completed
tokens_used: 23000
context_sources:
  - archive/planning-20251124T0900/phase-summary.md
  - archive/research-20251124T1015/phase-summary.md
  - shared/decisions.md (decisions 1-7)
---

# OAuth 2.0 Flow Design - READ FIRST

## Summary

Designed complete OAuth 2.0 authentication flow with PKCE implementation, database schema (users, refresh_tokens tables), API endpoint specifications (5 routes), and comprehensive error handling patterns. Multi-file output created for clarity: flow diagram (PKCE reference), database schema (migration SQL), API endpoints (specs), and this overview. Key design decision: separate refresh_tokens table with foreign key to users enables easier token rotation and revocation.

---

## Multi-File Output Structure

This agent produced **4 files** for different purposes:

```
agent-003-oauth-flow/
├── READ-FIRST.md (this file)      ← Start here for overview
├── oauth-flow-diagram.md          ← PRIMARY REFERENCE for PKCE implementation
├── database-schema.sql            ← Copy for database migration
└── api-endpoints.md               ← API endpoint specifications
```

### How to Use These Files

**For Execution Phase**:
1. **Start with**: `oauth-flow-diagram.md` - Authoritative PKCE implementation reference
2. **Database first**: Copy `database-schema.sql` for migration
3. **Then endpoints**: Implement routes per `api-endpoints.md` specifications
4. **Reference back**: Use this file for context and decisions

**For Review Phase**:
1. **Verify PKCE**: Check implementation against `oauth-flow-diagram.md` steps
2. **Verify Schema**: Ensure `database-schema.sql` matches execution migration
3. **Verify Endpoints**: Confirm all 5 routes from `api-endpoints.md` implemented

---

## Context

### Inputs Reviewed

**Planning Phase Summary**:
- Google OAuth 2.0 selected as provider
- Redis session storage selected
- Refresh token rotation required
- User requirements: G Suite integration, session persistence, MFA support

**Research Phase Summary**:
- PKCE required even for confidential clients (OWASP recommendation)
- Token encryption at rest (AES-256-GCM in Redis)
- Cookie security: httpOnly, secure, sameSite=lax
- Passport.js with passport-google-oauth20 selected

**Existing Decisions** (from shared/decisions.md):
- Decision 1: Google OAuth 2.0 as provider
- Decision 2: Redis for session storage
- Decision 3: Refresh token rotation
- Decision 4: Passport.js with passport-google-oauth20
- Decision 5: PKCE implementation
- Decision 6: httpOnly + secure + sameSite cookies
- Decision 7: Token encryption at rest

### Task Assignment

**Assigned by**: Orchestrator (after research phase completion)
**Assignment**: Design OAuth 2.0 flow with PKCE, database schema, API endpoints, error handling
**Scope**:
- ✅ In scope: Flow diagrams, database schema, endpoint specs, PKCE details
- ❌ Out of scope: Implementation code, testing, deployment

---

## Design Overview

### OAuth 2.0 Flow (9 Steps)

**High-Level Flow**:
```
User → Login Button → Google Auth → Consent → Callback → Token Exchange (PKCE) → Session → Authenticated
```

**With PKCE Security** (see `oauth-flow-diagram.md` for details):
1. Generate `code_verifier` (random 43-128 char string)
2. Calculate `code_challenge` = BASE64URL(SHA256(code_verifier))
3. Store `code_verifier` server-side (never exposed to browser)
4. Send `code_challenge` to Google with authorization request
5. Google stores `code_challenge`, returns authorization code
6. Exchange code + `code_verifier` for tokens
7. Google validates: SHA256(code_verifier) == stored code_challenge
8. Tokens issued if validation passes

**Why PKCE Matters** (even for server-side):
- Protects against authorization code interception attacks
- Defense in depth (extra security layer)
- OWASP recommendation for all OAuth 2.0 flows
- Minimal implementation complexity with passport-google-oauth20

---

## Database Schema

### Tables Designed

**1. users Table** (extended from existing):
- ✅ Extend existing table (don't recreate)
- ✅ Add `google_id` column (Google OAuth user ID)
- ✅ Add `user_metadata` JSONB (Google profile data)
- ✅ Add `last_login_at` timestamp (audit trail)
- ✅ Make `password_hash` nullable (OAuth users won't have passwords)

**2. refresh_tokens Table** (NEW):
- ✅ Separate table (not JSONB in users table)
- ✅ Foreign key to users (CASCADE delete)
- ✅ `token_hash` for encrypted storage
- ✅ Audit fields: `created_at`, `last_used_at`, `revoked_at`
- ✅ Indexes for fast lookups

**3. sessions** (Redis, not PostgreSQL table):
- Stored in Redis with 7-day TTL
- Contains encrypted access token
- Session ID in httpOnly cookie

**See `database-schema.sql` for full DDL.**

---

## API Endpoints

### 5 Routes Designed

| Method | Path | Purpose | PKCE |
|--------|------|---------|------|
| GET | `/auth/google` | Initiate OAuth flow | Generate code_verifier/code_challenge |
| GET | `/auth/google/callback` | OAuth callback | Validate with code_verifier |
| GET | `/auth/profile` | Get current user | No |
| POST | `/auth/logout` | Logout | No |
| POST | `/auth/refresh` | Refresh access token | No (only for initial auth) |

**Implementation Order** (dependencies):
1. `/auth/google` (no dependencies)
2. `/auth/google/callback` (depends on #1)
3. `/auth/profile` (test authentication works)
4. `/auth/logout` (cleanup)
5. `/auth/refresh` (token refresh logic)

**See `api-endpoints.md` for full specifications.**

---

## Key Design Decisions

### Decision 8: Separate refresh_tokens Table

**Decided**: Create `refresh_tokens` table instead of JSONB array in users table

**Rationale**:
- Easier token rotation: `DELETE` old token, `INSERT` new token
- Better indexing: Index on `token_hash` for O(1) lookups
- Audit trail: `created_at`, `last_used_at`, `revoked_at` timestamps
- Cleaner schema: users table not cluttered

**Schema Benefits**:
```sql
-- Fast token lookup (indexed)
SELECT * FROM refresh_tokens WHERE token_hash = $1 AND revoked_at IS NULL;

-- Revoke all tokens for user (security incident)
UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1;

-- Cleanup expired tokens (cron job)
DELETE FROM refresh_tokens WHERE expires_at < NOW();
```

**Alternatives Rejected**:
- JSONB array in users: No efficient queries, no indexes
- Combined sessions+tokens: Mixed concerns

**Decided At**: 2025-11-24T12:30:00Z

### Decision 9: Token Refresh Retry Logic

**Decided**: 3 retry attempts with exponential backoff (1s, 2s, 4s)

**Rationale**:
- Resilience: Google API transient errors (network blips)
- Better UX: Don't log out on temporary issue
- Standard practice: 3 retries common in production

**Implementation**:
```javascript
for (let attempt = 1; attempt <= 3; attempt++) {
  try {
    return await refreshToken();
  } catch (error) {
    if (attempt === 3) throw error;
    await sleep(Math.pow(2, attempt - 1) * 1000);  // 1s, 2s, 4s
  }
}
```

**Decided At**: 2025-11-24T12:45:00Z

### Decision 10: User Metadata JSONB Field

**Decided**: Add `user_metadata` JSONB field to users table

**Rationale**:
- Flexibility: Store Google profile without schema changes
- Future-proof: Support GitHub/Microsoft OAuth later
- PostgreSQL JSONB: Indexable, queryable

**Data Stored**:
```json
{
  "google_profile": {
    "picture_url": "https://...",
    "locale": "en",
    "verified_email": true
  },
  "auth_source": "google_oauth"
}
```

**Decided At**: 2025-11-24T13:00:00Z

---

## Error Handling Patterns

### 12 Error Scenarios Designed

All errors mapped to user-facing messages (no sensitive info leaked):

1. **User denies consent**: "Login cancelled. Please try again."
2. **Authorization code expired**: "Login session expired. Please try again."
3. **PKCE validation failed**: "Security validation failed." + alert security team
4. **Token refresh failed (3 retries)**: "Session expired. Please log in again."
5. **Redis connection lost**: "Service unavailable." + fallback or alert
6. **Database error**: "Unable to complete login." + rollback transaction
7. **Encryption key missing**: Refuse to start (fail fast)
8. **Google API rate limit**: "Too many attempts. Try in a few minutes."
9. **Invalid session cookie**: Silent redirect to login
10. **Expired access token**: Transparent auto-refresh
11. **Revoked refresh token**: "Session ended. Please log in again."
12. **Network error**: "Unable to connect. Please try again."

**See `api-endpoints.md` for implementation details.**

---

## Handoff to Execution Phase

### Implementation Priorities

**Priority 1: PKCE Implementation** ⭐
- **Critical**: Follow `oauth-flow-diagram.md` exactly
- code_verifier: crypto.randomBytes(32).toString('base64url')
- code_challenge: SHA-256 hash of code_verifier, base64url encoded
- Store code_verifier in session (server-side only, never browser)
- Passport.js handles validation if `usePKCE: true` configured

**Priority 2: Database Migration**
- **Start here**: Copy `database-schema.sql`
- Run migration in dev environment first
- Verify indexes created (users.google_id, refresh_tokens.token_hash)
- Test: Create user, insert refresh token, verify foreign key CASCADE

**Priority 3: Endpoint Implementation**
- **Order matters**: Implement login → callback → profile → logout → refresh
- Test after each endpoint (progressive validation)
- Reference `api-endpoints.md` for request/response schemas

**Priority 4: Error Handling**
- Implement all 12 scenarios from `api-endpoints.md`
- Test error paths (deny consent, network failure, etc.)
- Verify user-facing messages don't leak sensitive data

### Testing Checkpoints

After each implementation step:

✅ **After database migration**:
- User with google_id can be created
- Refresh token can be inserted and retrieved
- Foreign key CASCADE works (delete user → deletes tokens)

✅ **After /auth/google + /auth/google/callback**:
- Can initiate OAuth flow
- PKCE code_verifier generated and stored
- Google redirects back with authorization code
- Tokens exchanged successfully
- Session created in Redis
- User created/updated in PostgreSQL

✅ **After /auth/profile**:
- Authenticated request returns user data
- Unauthenticated request redirects to login

✅ **After /auth/logout**:
- Session deleted from Redis
- Refresh token revoked in PostgreSQL
- Cookie cleared
- Subsequent requests unauthenticated

✅ **After /auth/refresh**:
- Expired access token triggers refresh
- New access token obtained (3 retries if needed)
- Old refresh token deleted, new one stored
- Session updated with new access token

---

## Files Reference

### 1. oauth-flow-diagram.md
**Purpose**: Visual PKCE flow diagram (authoritative reference)
**Use for**: Understanding flow, implementing PKCE, verifying execution
**Key content**: 9-step flow with PKCE code_verifier/code_challenge

### 2. database-schema.sql
**Purpose**: Database migration script
**Use for**: Creating users and refresh_tokens tables
**Key content**: DDL with indexes, foreign keys, JSONB fields

### 3. api-endpoints.md
**Purpose**: API endpoint specifications
**Use for**: Implementing routes, request/response schemas, middleware
**Key content**: 5 endpoints with Passport.js middleware details

---

## Agent Output Metadata

**Agent ID**: agent-003
**Workflow ID**: oauth-integration-20251124
**Phase**: design
**Topic**: oauth-flow-design
**Started**: 2025-11-24T11:48:00Z
**Completed**: 2025-11-24T13:12:00Z
**Duration**: 84 minutes
**Tokens Used**: 23,000 (approximate)
**Status**: completed

**Return JSON**:
```json
{
  "status": "finished",
  "output_paths": [
    "active/design/agent-003-oauth-flow/READ-FIRST.md",
    "active/design/agent-003-oauth-flow/oauth-flow-diagram.md",
    "active/design/agent-003-oauth-flow/database-schema.sql",
    "active/design/agent-003-oauth-flow/api-endpoints.md"
  ],
  "questions": [
    {
      "question": "Should refresh tokens be in users table or separate table?",
      "options": ["Separate table", "JSONB in users table"],
      "recommendation": "Separate table for easier rotation and indexing",
      "blocking": false,
      "answer": "Separate table (Decision 8)"
    }
  ],
  "summary": "Designed complete OAuth 2.0 flow with PKCE (9 steps), database schema (users + refresh_tokens tables), and 5 API endpoints. Key decision: separate refresh_tokens table for easier rotation. Multi-file output created: flow diagram (PKCE reference), database schema (migration SQL), endpoint specs. All 12 error scenarios from research mapped to implementations.",
  "tokens_used": 23000,
  "next_phase_context": "Execution phase should implement endpoints in order: login → callback → profile → logout → refresh. Primary reference: oauth-flow-diagram.md for PKCE implementation. Database schema ready in database-schema.sql. All error handling patterns specified in api-endpoints.md."
}
```
