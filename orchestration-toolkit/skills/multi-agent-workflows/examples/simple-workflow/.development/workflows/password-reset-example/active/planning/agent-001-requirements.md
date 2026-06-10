---
phase: planning
author_agent: agent-001
created_at: 2025-11-24T14:15:00Z
updated_at: 2025-11-24T14:45:00Z
topic: password-reset-requirements
status: completed
tokens_used: 12500
context_sources:
  - Industry best practices (OWASP Authentication Cheat Sheet)
  - Existing authentication system documentation
---

# Password Reset Requirements Analysis

## Summary

Analyzed password reset requirements across security, UX, and technical dimensions. Recommend email-based reset with time-limited magic links (1-hour expiry). Identified 3 critical security needs: token uniqueness, rate limiting, and secure email delivery. Implementation should use existing email service and database schema with new `password_reset_tokens` table.

---

## Context

### Inputs Reviewed

Files and sources consulted to produce this output:

- OWASP Authentication Cheat Sheet (password reset section)
- NIST Digital Identity Guidelines SP 800-63B
- Existing authentication system (email/password based)
- User database schema documentation

### Task Assignment

**Assigned by**: Orchestrator
**Assignment**: Analyze password reset requirements including user flows, security constraints, and technical approach
**Scope**: Requirements definition only - implementation in next phase

---

## User Stories

### Primary User Story

**As a** registered user who has forgotten their password
**I want to** reset my password securely via email
**So that** I can regain access to my account without contacting support

**Acceptance Criteria**:
- User can request password reset by entering their email address
- System sends reset link to registered email within 1 minute
- Reset link expires after 1 hour for security
- User can set a new password using the reset link
- Old password is invalidated after successful reset
- User receives confirmation email after password change

### Secondary User Stories

**As a** user attempting password reset
**I want** clear feedback on the reset process
**So that** I understand what to do next

**As a** security-conscious user
**I want** to be notified if someone requests a password reset for my account
**So that** I can detect unauthorized access attempts

---

## Technical Requirements

### Functional Requirements

1. **Request Password Reset**
   - **Input**: User email address
   - **Process**: Generate unique token, store with expiry, send email
   - **Output**: Confirmation message (don't reveal if email exists - security)
   - **Error Handling**: Rate limit to 3 requests per email per hour

2. **Validate Reset Token**
   - **Input**: Token from email link
   - **Process**: Check token exists, not expired, not already used
   - **Output**: Show password reset form OR error message
   - **Edge Cases**: Expired tokens, invalid tokens, already-used tokens

3. **Complete Password Reset**
   - **Input**: New password, token
   - **Process**: Validate password strength, update user password, invalidate token
   - **Output**: Success message, redirect to login
   - **Security**: Hash new password with bcrypt (10+ rounds)

### Non-Functional Requirements

1. **Security**
   - Tokens must be cryptographically random (minimum 32 bytes)
   - Tokens stored hashed in database (not plaintext)
   - HTTPS required for all reset endpoints
   - Password strength validation (8+ chars, mixed case, numbers)
   - Rate limiting on reset requests (prevent abuse)

2. **Performance**
   - Email delivery within 1 minute
   - Token validation in <100ms
   - Password update in <500ms

3. **Availability**
   - Email service must have fallback/retry logic
   - Graceful degradation if email service is down

---

## Security Considerations

### High Priority

1. **Token Uniqueness and Randomness**
   - **Risk**: Predictable tokens allow account takeover
   - **Mitigation**: Use `crypto.randomBytes(32)` for token generation
   - **Validation**: Each token must be globally unique

2. **Token Expiry**
   - **Risk**: Long-lived tokens increase exposure window
   - **Mitigation**: 1-hour expiry (industry standard)
   - **Question for Orchestrator**: Confirm 1-hour expiry is acceptable
   - **Recommendation**: 1 hour balances security and UX

3. **Rate Limiting**
   - **Risk**: Attackers could spam reset requests to user emails
   - **Mitigation**: Limit to 3 requests per email per hour
   - **Implementation**: Use Redis or in-memory cache for rate tracking

### Medium Priority

1. **Email Verification**
   - **Risk**: User enters wrong email, receives reset link
   - **Mitigation**: Send to registered email only, don't reveal if email exists
   - **UX Note**: Show generic "If email exists, link sent" message

2. **Token Single-Use**
   - **Risk**: Token reuse could allow multiple password changes
   - **Mitigation**: Mark token as "used" after successful reset
   - **Database**: Add `used_at` column to track usage

---

## Recommended Technical Approach

### Decision 1: Email-Based vs. SMS vs. Security Questions

**Decision**: Use email-based password reset with magic link

**Rationale**:
- Email already required for user accounts (no new infrastructure)
- More secure than security questions (which are often guessable)
- Better UX than emailed numeric codes (one-click vs. copy/paste)
- Industry standard approach used by major platforms

**Alternatives Considered**:
- SMS-based reset: Requires phone number collection, SMS gateway costs
- Security questions: Weak security (answers often public/guessable)
- Numeric codes via email: Worse UX than clickable link

**Implications**:
- Requires reliable email service (use existing email infrastructure)
- Must handle email delivery failures gracefully
- Timeline: Can implement in current sprint

### Decision 2: Token Storage Strategy

**Decision**: Store hashed tokens in database with expiry timestamp

**Rationale**:
- Hashing tokens protects against database compromise
- Database storage enables token validation and expiry tracking
- Existing database infrastructure (no new dependencies)

**Implementation**:
```sql
CREATE TABLE password_reset_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(64) NOT NULL,  -- SHA-256 hash of token
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_token_hash (token_hash),
  INDEX idx_user_expires (user_id, expires_at)
);
```

### Decision 3: Token Expiry Duration

**Decision**: 1-hour token expiry

**Rationale**:
- OWASP recommends short-lived tokens (15 min - 1 hour)
- 1 hour balances security (limits exposure) with UX (user has time)
- Industry standard (Gmail, GitHub, etc. use 1-hour expiry)

**Edge Case Handling**:
- If token expired, user can request new reset (no penalty)
- Show clear "Link expired" message with re-request option

---

## Password Reset Flow

### Happy Path

1. **User requests reset**
   - User visits `/forgot-password`
   - Enters email address
   - Submits form

2. **System generates token**
   - Validates email format
   - Checks rate limits (3/hour per email)
   - Generates random 32-byte token
   - Hashes token with SHA-256
   - Stores hash in `password_reset_tokens` with 1-hour expiry
   - Sends email with reset link: `/reset-password?token={token}`

3. **User clicks email link**
   - System validates token:
     - Token hash exists in database
     - Token not expired (< 1 hour old)
     - Token not already used
   - Shows password reset form

4. **User sets new password**
   - Validates password strength
   - Hashes new password with bcrypt
   - Updates user password
   - Marks token as used (`used_at = NOW()`)
   - Sends confirmation email
   - Redirects to login with success message

### Edge Cases

1. **Email doesn't exist**: Show generic success (don't reveal non-existence)
2. **Rate limit exceeded**: Show error "Too many requests, try again later"
3. **Token expired**: Show "Link expired" with option to request new reset
4. **Token already used**: Show "Link already used" with option to request new reset
5. **Invalid token**: Show "Invalid link" with option to request new reset
6. **Email service down**: Queue email for retry, show "Reset requested" message

---

## Questions for Orchestrator

### Question 1

**Question**: Is 1-hour token expiry acceptable, or should it be shorter (15 min) or longer (24 hours)?
**Context**: 1 hour is industry standard (OWASP recommendation). Shorter is more secure but worse UX. Longer increases security risk.
**Options**:
- 15 minutes (maximum security)
- 1 hour (balanced - RECOMMENDED)
- 24 hours (maximum convenience)

**Your Recommendation**: 1 hour - balances security and UX, follows industry standards
**Blocking**: No - can proceed with 1 hour if no objection

---

## Next Steps

### For Implementation Phase

Implementation phase should:

1. Create `password_reset_tokens` database table with schema above
2. Implement POST `/api/auth/forgot-password` endpoint
   - Validate email, check rate limits, generate token, send email
3. Implement GET `/api/auth/reset-password/:token` endpoint
   - Validate token, show reset form
4. Implement POST `/api/auth/reset-password` endpoint
   - Validate password, update user, mark token used
5. Create email templates for reset link and confirmation
6. Add rate limiting middleware (3 requests/hour per email)
7. Write tests for happy path and edge cases

### Follow-Up Actions

- [ ] Review token expiry decision (1 hour vs. alternatives)
- [ ] Confirm email service has retry logic for failed sends
- [ ] Verify password strength requirements with security team

---

## References

### Files Modified/Created

Implementation phase should create/modify:

- `migrations/YYYYMMDD_create_password_reset_tokens.sql` - Database migration
- `routes/auth.js` - Add password reset endpoints
- `services/passwordReset.js` - Business logic for reset flow
- `templates/emails/password-reset.html` - Email template for reset link
- `templates/emails/password-changed.html` - Confirmation email
- `middleware/rateLimit.js` - Rate limiting for reset requests
- `tests/auth/passwordReset.test.js` - Test suite

### External References

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#password-reset)
- [NIST SP 800-63B: Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Node.js crypto.randomBytes](https://nodejs.org/api/crypto.html#cryptorandombytessize-callback)

---

## Agent Output Metadata

**Agent ID**: agent-001
**Workflow ID**: password-reset-example
**Phase**: planning
**Topic**: password-reset-requirements
**Started**: 2025-11-24T14:15:00Z
**Completed**: 2025-11-24T14:45:00Z
**Duration**: 30 minutes
**Tokens Used**: 12,500 (approximate)
**Status**: completed

**Return JSON**:
```json
{
  "status": "finished",
  "output_paths": ["active/planning/agent-001-requirements.md"],
  "questions": [
    {
      "question": "Is 1-hour token expiry acceptable, or should it be shorter (15 min) or longer (24 hours)?",
      "context": "1 hour is industry standard (OWASP recommendation). Shorter is more secure but worse UX.",
      "options": ["15 minutes", "1 hour", "24 hours"],
      "recommendation": "1 hour",
      "blocking": false
    }
  ],
  "summary": "Analyzed password reset requirements. Recommend email-based reset with 1-hour token expiry. Defined user stories, security constraints, and database schema. Ready for implementation.",
  "tokens_used": 12500,
  "next_phase_context": "Implementation should focus on creating password_reset_tokens table, implementing 3 API endpoints (/forgot-password, /reset-password GET/POST), and adding rate limiting. Refer to database schema in Decision 2 and flow diagram in Password Reset Flow section."
}
```

---

**Template Version**: 1.0.0
**Last Updated**: 2025-11-24T14:45:00Z
