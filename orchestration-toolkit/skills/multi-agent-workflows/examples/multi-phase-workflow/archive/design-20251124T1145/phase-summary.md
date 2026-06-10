---
phase: design
workflow_id: oauth-integration-20251124
archived_at: 2025-11-24T13:20:00Z
started_at: 2025-11-24T11:45:00Z
completed_at: 2025-11-24T13:15:00Z
duration_minutes: 90
agents_involved: [agent-003]
total_tokens_used: 23000
token_budget: 30000
budget_status: under
---

# Design Phase Summary

## Overview

**Duration**: 90 minutes
**Agents**: 1 agent completed work
**Tokens Used**: 23,000 / 30,000 (77%)
**Status**: ✅ Completed successfully

Design phase created comprehensive OAuth 2.0 flow diagrams incorporating PKCE, database schema with separate refresh_tokens table, API endpoint specifications, and error handling patterns. Multi-file output produced including visual PKCE flow diagram, database migration SQL, and endpoint documentation. Key design decision: separate refresh_tokens table with foreign key to users enables easier token rotation and revocation. Flow diagram will serve as primary reference for execution phase implementation.

---

## Objectives Achieved

- ✅ Create OAuth 2.0 flow diagram with PKCE implementation
- ✅ Design database schema (users, refresh_tokens tables with JSONB metadata)
- ✅ Specify API endpoints (5 routes with Passport.js middleware)
- ✅ Document error handling patterns (OAuth errors, token refresh, Redis failures)
- ✅ Define Passport.js strategy configuration
- ✅ Specify Redis session schema and TTL settings

---

## Key Outputs

### Agent-003: OAuth Flow Design (Multi-File Output)

**Output**: `agent-003-oauth-flow/` directory with 4 files
**Tokens**: 23,000
**Summary**: Complete OAuth 2.0 system design with PKCE flow, database schema, API specifications, and configuration details.

**Files Created**:
1. `READ-FIRST.md` - Overview and navigation guide
2. `oauth-flow-diagram.md` - Visual PKCE flow with 9 steps
3. `database-schema.sql` - PostgreSQL migration script
4. `api-endpoints.md` - 5 endpoint specifications with middleware

**Key Findings**:
1. **PKCE Flow**: 9-step process from code_verifier generation to token validation
2. **Database Schema**: 3 tables (users, refresh_tokens, sessions in Redis)
3. **API Endpoints**: 5 routes (login, callback, profile, logout, refresh)
4. **Error Handling**: 12 error scenarios mapped to user-facing messages

**Decisions Made**:
- **Decision 8**: Separate refresh_tokens table with foreign key
- **Decision 9**: 3 retry attempts with exponential backoff for token refresh
- **Decision 10**: Add user_metadata JSONB field for extensibility

---

## Consolidated Findings

### OAuth 2.0 Flow with PKCE

**Complete Flow** (9 steps):

```
1. User clicks "Login with Google"
   ├─ Generate code_verifier (random 43-128 char string)
   ├─ Calculate code_challenge = BASE64URL(SHA256(code_verifier))
   ├─ Store code_verifier in session (server-side, not exposed to browser)
   └─ Redirect to Google with code_challenge

2. Google Authorization
   ├─ User authenticates with Google
   ├─ User grants consent (scopes: openid, profile, email)
   └─ Google redirects to callback URL with authorization code

3. Authorization Code Exchange
   ├─ Retrieve code_verifier from session
   ├─ Exchange code + code_verifier for tokens (server-to-server)
   ├─ Google validates: SHA256(code_verifier) == stored code_challenge
   └─ Google returns access_token + refresh_token + id_token

4. Token Storage
   ├─ Encrypt tokens with AES-256-GCM
   ├─ Store encrypted tokens in Redis session
   ├─ Store refresh_token in PostgreSQL refresh_tokens table
   └─ Parse id_token for user profile data

5. User Session Creation
   ├─ Create or update user in users table
   ├─ Create session in Redis (7-day TTL)
   ├─ Set httpOnly cookie with session ID
   └─ Redirect to application

6. Authenticated Requests
   ├─ Browser sends cookie with session ID
   ├─ Retrieve session from Redis
   ├─ Decrypt access token
   └─ Make API requests to Google with access token

7. Token Refresh (when access token expires)
   ├─ Retrieve refresh token from database
   ├─ Exchange refresh token for new access token (3 retries)
   ├─ Rotate refresh token (delete old, store new)
   └─ Update session with new access token

8. Logout
   ├─ Revoke refresh token in database (set revoked_at)
   ├─ Delete session from Redis
   ├─ Clear session cookie
   └─ Redirect to homepage

9. Error Handling
   ├─ OAuth errors: Log and show generic message
   ├─ Token refresh fails: Re-authenticate
   └─ Redis connection lost: Graceful degradation
```

**Key Security Properties**:
- Code verifier never exposed to browser (server-side only)
- Authorization code useless without matching code_verifier
- Tokens encrypted at rest in Redis
- Refresh tokens hashed in database

### Database Schema

**users Table** (extended from existing):
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  email_verified BOOLEAN DEFAULT false,
  password_hash TEXT,  -- Existing column, nullable (OAuth users won't have password)
  google_id TEXT UNIQUE,  -- NEW: Google OAuth user ID
  user_metadata JSONB,  -- NEW: Store Google profile data
  created_at TIMESTAMP DEFAULT NOW(),
  last_login_at TIMESTAMP,  -- NEW: Track login activity
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_google_id ON users(google_id);
CREATE INDEX idx_users_email ON users(email);
```

**refresh_tokens Table** (NEW):
```sql
CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,  -- SHA-256 hash of encrypted token
  created_at TIMESTAMP DEFAULT NOW(),
  last_used_at TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP,  -- NULL = active, set = revoked
  user_agent TEXT,  -- For auditing
  ip_address INET  -- For auditing
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at)
  WHERE revoked_at IS NULL;  -- Partial index for active tokens
```

**sessions (Redis)** - Not a PostgreSQL table, stored in Redis:
```javascript
{
  session_id: "uuid-v4",
  user_id: "uuid",
  access_token_encrypted: "base64-encrypted-token",
  csrf_token: "random-string",
  created_at: timestamp,
  expires_at: timestamp,
  pkce_code_verifier: "random-string"  // Temporary, deleted after token exchange
}
```

**user_metadata JSONB Schema** (stored in users table):
```json
{
  "google_profile": {
    "picture_url": "https://lh3.googleusercontent.com/...",
    "locale": "en",
    "verified_email": true
  },
  "auth_source": "google_oauth",
  "account_created_via": "web_signup"
}
```

### API Endpoints

**1. GET /auth/google** (Login Initiation)
- Middleware: None (public)
- Function: Initiate OAuth flow with PKCE
- PKCE: Generate code_verifier, calculate code_challenge, store in session
- Passport: `passport.authenticate('google', { scope: ['openid', 'profile', 'email'] })`

**2. GET /auth/google/callback** (OAuth Callback)
- Middleware: Passport.js
- Function: Exchange authorization code for tokens
- PKCE: Retrieve code_verifier from session, validate
- Passport: `passport.authenticate('google', { failureRedirect: '/login' })`
- Success: Create session, set cookie, redirect to app

**3. GET /auth/profile** (Get Current User)
- Middleware: `ensureAuthenticated` (custom middleware)
- Function: Return current user profile
- Response: `{ user_id, email, email_verified, user_metadata }`

**4. POST /auth/logout** (Logout)
- Middleware: `ensureAuthenticated`
- Function: Revoke refresh token, delete session, clear cookie
- Steps:
  1. Set `revoked_at` on refresh_tokens row
  2. Delete session from Redis
  3. Clear session cookie
  4. Return success

**5. POST /auth/refresh** (Refresh Access Token)
- Middleware: `ensureAuthenticated`
- Function: Get new access token using refresh token
- PKCE: Not used (only for initial authorization)
- Retry Logic: 3 attempts with exponential backoff (1s, 2s, 4s)
- Token Rotation: Delete old refresh token, store new one

### Error Handling Patterns

**12 Error Scenarios**:

1. **OAuth Error: access_denied** (user cancels consent)
   - User Message: "Login cancelled. Please try again if you want to access the application."
   - Log: WARN level
   - Action: Redirect to login page

2. **OAuth Error: invalid_grant** (authorization code expired/invalid)
   - User Message: "Login session expired. Please try again."
   - Log: WARN level
   - Action: Redirect to /auth/google (restart flow)

3. **PKCE Validation Failed** (code_verifier mismatch)
   - User Message: "Security validation failed. Please try again."
   - Log: ERROR level (potential attack)
   - Action: Redirect to login, alert security team

4. **Token Refresh Failed** (all 3 retries exhausted)
   - User Message: "Session expired. Please log in again."
   - Log: WARN level
   - Action: Delete session, redirect to login

5. **Redis Connection Lost**
   - User Message: "Service temporarily unavailable. Please try again."
   - Log: ERROR level
   - Action: Fallback to memory sessions (dev only), alert ops (production)

6. **Database Error** (users or refresh_tokens table)
   - User Message: "Unable to complete login. Please try again later."
   - Log: ERROR level
   - Action: Rollback transaction, return 500

7. **Encryption Key Missing** (`TOKEN_ENCRYPTION_KEY` not set)
   - User Message: "Service configuration error. Contact support."
   - Log: CRITICAL level
   - Action: Refuse to start application (fail fast)

8. **Google API Rate Limit**
   - User Message: "Too many login attempts. Please try again in a few minutes."
   - Log: WARN level
   - Action: Return 429, exponential backoff

9. **Invalid Session Cookie**
   - User Message: (Silent) Redirect to login
   - Log: INFO level
   - Action: Clear invalid cookie, redirect to /auth/google

10. **Expired Access Token** (normal expiration)
    - User Message: (Transparent) Auto-refresh via /auth/refresh
    - Log: DEBUG level
    - Action: Attempt token refresh, fallback to re-authentication

11. **Revoked Refresh Token** (manual revocation or security incident)
    - User Message: "Your session was ended. Please log in again."
    - Log: WARN level
    - Action: Delete session, clear cookie, redirect to login

12. **Network Error** (Google API unreachable)
    - User Message: "Unable to connect to authentication service. Please try again."
    - Log: ERROR level
    - Action: Return 503, retry after 30 seconds

---

## Decisions Made

### Decision 8: Separate refresh_tokens Table

**Decision**: Create separate `refresh_tokens` table with foreign key to `users`, not JSONB array in users table
**Rationale**:
- **Easier rotation**: UPDATE or DELETE specific token by ID
- **Better indexing**: Index on token_hash for fast lookups
- **Audit trail**: created_at, last_used_at, revoked_at timestamps
- **Cleaner schema**: users table not cluttered with token arrays
- **Revocation**: "Revoke all tokens for user" is simple DELETE query

**Schema Benefits**:
```sql
-- Rotate token (delete old, insert new)
DELETE FROM refresh_tokens WHERE token_hash = $1;
INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (...);

-- Revoke all tokens for user (on password change)
UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1;

-- Clean up expired tokens (cron job)
DELETE FROM refresh_tokens
WHERE expires_at < NOW() OR revoked_at < NOW() - INTERVAL '30 days';
```

**Alternatives Considered**:
- JSONB array in users table: Harder to query, no efficient indexes
- Combined sessions and refresh tokens: Mixed concerns, harder to manage

**Decided At**: 2025-11-24T12:30:00Z

### Decision 9: Token Refresh Retry Logic

**Decision**: Implement 3 retry attempts with exponential backoff (1s, 2s, 4s) for token refresh
**Rationale**:
- **Resilience**: Google API transient errors (network blips, rate limiting)
- **Better UX**: Don't log user out on temporary issue
- **Standard practice**: 3 retries common in production systems
- **Exponential backoff**: Prevents overwhelming Google API during incidents

**Implementation**:
```javascript
async function refreshAccessToken(refreshToken, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await google.refreshToken(refreshToken);
      return response;  // Success
    } catch (error) {
      if (attempt === retries) throw error;  // Give up
      const delay = Math.pow(2, attempt - 1) * 1000;  // 1s, 2s, 4s
      await sleep(delay);
    }
  }
}
```

**Alternatives Considered**:
- No retries: Poor UX, unnecessary logouts on transient errors
- Infinite retries: Could mask real issues, waste resources
- Fixed delay: Not ideal, exponential backoff better for API health

**Decided At**: 2025-11-24T12:45:00Z

### Decision 10: User Metadata JSONB Field

**Decision**: Add `user_metadata` JSONB field to users table for extensible profile data storage
**Rationale**:
- **Flexibility**: Store Google profile data without schema changes
- **Future-proof**: If adding GitHub/Microsoft OAuth, can store provider-specific data
- **PostgreSQL JSONB**: Efficient indexing, queryable with SQL
- **Avoid over-normalization**: Profile picture URL doesn't need separate table

**Data to Store**:
```json
{
  "google_profile": {
    "picture_url": "https://lh3.googleusercontent.com/abc123",
    "locale": "en-US",
    "verified_email": true
  },
  "auth_source": "google_oauth",
  "account_created_via": "web_signup",
  "preferences": {
    "theme": "dark",
    "notifications": true
  }
}
```

**Querying Example**:
```sql
-- Find users with unverified emails
SELECT * FROM users
WHERE user_metadata->'google_profile'->>'verified_email' = 'false';

-- Index for efficient queries
CREATE INDEX idx_users_metadata_verified
ON users ((user_metadata->'google_profile'->>'verified_email'));
```

**Alternatives Considered**:
- Separate user_profiles table: Over-engineering for simple data
- Store as TEXT JSON: No querying ability, no validation

**Decided At**: 2025-11-24T13:00:00Z

---

## Questions Resolved

### Q1: Should refresh tokens be in users table or separate table?

**Asked By**: agent-003 (design)
**Answer**: Separate `refresh_tokens` table for easier rotation and revocation
**Rationale**: See Decision 8 above - better indexing, audit trail, cleaner schema
**Answered By**: agent-003 (self-answered during design)
**Answered At**: 2025-11-24T12:30:00Z

---

## Risks and Issues Identified

### Medium Priority

1. **Risk**: Database migration on production (users table alterations)
   - **Likelihood**: Medium (requires downtime or careful migration)
   - **Impact**: Medium (brief unavailability during deployment)
   - **Mitigation**:
     - Use `ADD COLUMN` (fast, no table rewrite)
     - New columns nullable (existing rows unaffected)
     - Run migration during low-traffic window
   - **Owner for Next Phase**: Execution phase (write safe migration script)

2. **Risk**: Refresh token table grows unbounded (no cleanup)
   - **Likelihood**: High without cleanup
   - **Impact**: Low (disk space, slower queries over time)
   - **Mitigation**: Cron job to delete revoked/expired tokens (daily)
   - **Owner for Next Phase**: Execution phase (implement cleanup script)

---

## Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Agents Launched** | 1 | 1 | ✅ Met |
| **Agents Completed** | 1 | 1 | ✅ Met |
| **Agents Failed** | 0 | 0 | ✅ None |
| **Total Tokens** | 23,000 | 30,000 | ✅ Under budget |
| **Duration** | 90 min | 90 min | ✅ On schedule |
| **Questions Asked** | 1 | - | - |
| **Decisions Made** | 3 | - | - |

**Budget Analysis**:
- Actual: 23,000 tokens
- Budget: 30,000 tokens
- Variance: -23% (under budget)
- Reason: Efficient design, clear requirements from research phase, multi-file output reduces redundancy

---

## Handoff to Next Phase

### Context for Execution Phase

**What's Ready**:
- Complete OAuth flow diagram with PKCE (9-step process documented)
- Database schema ready for implementation (users, refresh_tokens tables)
- API endpoint specifications (5 routes with middleware details)
- Error handling patterns (12 scenarios mapped to user messages)
- Passport.js strategy configuration documented

**What's Needed**:
- **Priority 1**: Implement endpoints in THIS ORDER: login → callback → profile → logout → refresh (dependencies)
- **Priority 2**: Reference `oauth-flow-diagram.md` for PKCE implementation (code_verifier generation, code_challenge calculation)
- **Priority 3**: Implement database migration script from `database-schema.sql`
- **Priority 4**: Implement retry logic for token refresh (3 attempts, exponential backoff)

**Critical Files to Reference**:
- `archive/design-20251124T1145/agent-003-oauth-flow/READ-FIRST.md` - Start here for overview
- `archive/design-20251124T1145/agent-003-oauth-flow/oauth-flow-diagram.md` - **PRIMARY REFERENCE for PKCE**
- `archive/design-20251124T1145/agent-003-oauth-flow/database-schema.sql` - Copy for migration
- `archive/design-20251124T1145/agent-003-oauth-flow/api-endpoints.md` - Endpoint specs
- `shared/decisions.md` - All decisions 1-10 for context

**Recommended Execution Order**:
1. Database migration (users, refresh_tokens tables)
2. Passport.js strategy configuration (PKCE enabled)
3. /auth/google endpoint (login initiation with PKCE)
4. /auth/google/callback endpoint (token exchange)
5. /auth/profile endpoint (simple, test authentication)
6. /auth/logout endpoint (session cleanup)
7. /auth/refresh endpoint (token refresh with retry logic)
8. Error handling middleware (12 scenarios)

**Testing Checkpoints**:
- After step 4: Able to complete OAuth flow and create session
- After step 5: Able to retrieve user profile
- After step 6: Able to logout and clear session
- After step 7: Able to refresh access token

---

## Raw Outputs Reference

All agent outputs preserved in:
```
archive/design-20251124T1145/
└── agent-003-oauth-flow/
    ├── READ-FIRST.md (start here)
    ├── oauth-flow-diagram.md (PKCE reference)
    ├── database-schema.sql (migration script)
    └── api-endpoints.md (endpoint specs)
```

**Note**: Execution phase MUST read oauth-flow-diagram.md for PKCE implementation details. This is the authoritative reference.

---

## Lessons Learned

### What Went Well

1. **Multi-File Output Organization**
   - **Why**: Complex design split into focused files (flow, schema, endpoints)
   - **Repeat**: Use multi-file outputs for complex designs (>1000 lines)

2. **Visual Flow Diagram**
   - **Why**: 9-step PKCE flow easier to understand visually than prose
   - **Repeat**: Always create flow diagrams for multi-step processes

3. **Database Schema with Comments**
   - **Why**: SQL comments explain design decisions inline
   - **Repeat**: Include rationale comments in schema files

### What Could Improve

1. **API Response Schemas**
   - **Impact**: Endpoint specs don't include full response schemas (just summary)
   - **Recommendation**: Add JSON schema or TypeScript types for API responses

---

## Timeline

```
Phase: Design
Duration: 2025-11-24T11:45:00Z → 2025-11-24T13:15:00Z (90 minutes)

Milestones:
├─ 11:45  : Design phase started
├─ 11:48  : Agent-003 launched (OAuth flow design)
├─ 12:30  : Decision 8 - Separate refresh_tokens table
├─ 12:45  : Decision 9 - Retry logic (3 attempts, exponential backoff)
├─ 13:00  : Decision 10 - user_metadata JSONB field
├─ 13:12  : Agent-003 completed (multi-file output)
└─ 13:15  : Design phase completed

Next Phase: Execution
Estimated Start: 2025-11-24T14:00:00Z (45-min break for lunch)
```

---

## Summary Statistics

**Phase**: Design
**Workflow**: oauth-integration-20251124
**Status**: ✅ Archived
**Archived**: 2025-11-24T13:20:00Z

**Agents**: 1 total (1 completed, 0 failed)
**Tokens**: 23,000 used / 30,000 budgeted (77%)
**Duration**: 90 minutes

**Key Outputs**: 4 files created (multi-file output)
**Decisions**: 3 decisions made
**Questions**: 1 question resolved
