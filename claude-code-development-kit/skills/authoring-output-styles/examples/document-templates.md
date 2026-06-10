# Document Template Examples

Complete, realistic examples demonstrating how to use document templates effectively.

---

## Product Brief Example

### Two-Factor Authentication (2FA) Implementation

**Owner:** Security Team
**Status:** Planning
**Timeline:** Q1 2025
**Priority:** P0

#### Problem Statement

Users currently authenticate with only username/password, creating security vulnerabilities. We've seen a 23% increase in account compromise incidents over the past quarter, with 87% of breaches involving credential stuffing attacks. Our enterprise customers (representing 65% of ARR) have explicitly requested 2FA as a requirement for contract renewals.

#### Goals

1. Reduce account compromise incidents by 80% within 3 months of launch
2. Achieve 60% 2FA adoption among active users within 6 months
3. Meet SOC 2 Type II compliance requirements for authentication
4. Enable enterprise SSO integration as a follow-on capability

#### Non-Goals

- Biometric authentication (fingerprint, Face ID) - deferred to Q2
- Hardware security key support (YubiKey) - future consideration
- Password-less authentication - separate initiative

#### Proposed Solution

Implement TOTP-based (Time-based One-Time Password) two-factor authentication with the following features:

**Core Capabilities:**
- QR code enrollment flow with authenticator apps (Google Authenticator, Authy, 1Password)
- SMS-based backup codes for account recovery (10 single-use codes)
- Remember device option (30-day trust period)
- Admin dashboard for organization-wide 2FA enforcement policies

**User Experience:**
- Optional 2FA during initial rollout (3 weeks)
- Progressive enrollment prompts for high-value actions
- Mandatory for admin accounts immediately
- Grace period for standard users (configurable by organization)

**Technical Approach:**
- TOTP implementation using RFC 6238 standard
- Server-side secret generation with AES-256 encryption at rest
- Rate limiting: 5 verification attempts per 15-minute window
- Audit logging for all 2FA events (enrollment, verification, recovery)

#### Success Metrics

- 2FA enrollment rate: 60% of active users within 6 months
- Account compromise reduction: 80% decrease in incidents
- Support ticket volume: <2% increase during rollout
- Login flow latency: <200ms additional verification time
- Recovery success rate: >95% of users can recover via backup codes

#### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| User friction causing adoption resistance | High | Gradual rollout, clear benefits messaging, in-app education |
| SMS delivery failures in some regions | Medium | Provide authenticator app as primary method, regional SMS provider partnerships |
| Support burden from locked-out users | Medium | Self-service recovery flow, comprehensive admin tools, escalation playbook |
| Clock drift causing TOTP failures | Low | 30-second time window tolerance, server NTP synchronization |

#### Open Questions

1. Should we enforce 2FA for all users or keep it optional indefinitely?
2. What's the backup strategy if a user loses both their device and recovery codes?
3. Do we need different policies for different user tiers (free vs. paid)?

---

## Technical Specification Example

### Real-Time Notification System via WebSocket

**Author:** Backend Team
**Reviewers:** @frontend-team, @platform-team, @security
**Status:** Design Review
**Last Updated:** 2025-12-06

#### Overview

Replace polling-based notification checks with WebSocket connections to deliver real-time updates for comments, mentions, task assignments, and system alerts. This will reduce server load by 40% while improving notification latency from ~30 seconds to <500ms.

#### Requirements

**Functional Requirements:**
- FR1: Establish persistent WebSocket connections for authenticated users
- FR2: Deliver notifications within 500ms of triggering event
- FR3: Support notification types: comments, mentions, assignments, alerts
- FR4: Handle connection recovery with exponential backoff
- FR5: Provide connection status indicators in UI

**Non-Functional Requirements:**
- NFR1: Support 50,000 concurrent WebSocket connections per server
- NFR2: 99.9% message delivery success rate
- NFR3: Graceful degradation to polling if WebSocket unavailable
- NFR4: End-to-end encryption for sensitive notifications

#### Architecture

**System Components:**

```
┌─────────────┐      WSS       ┌──────────────┐      Redis Pub/Sub    ┌─────────────┐
│   Browser   │ ◄─────────────► │  WS Gateway  │ ◄──────────────────► │   API Node  │
└─────────────┘                 └──────────────┘                       └─────────────┘
                                       │                                      │
                                       │                                      │
                                       ▼                                      ▼
                                ┌──────────────┐                      ┌─────────────┐
                                │  Connection  │                      │  PostgreSQL │
                                │    Store     │                      │  (Events)   │
                                │   (Redis)    │                      └─────────────┘
                                └──────────────┘
```

**Component Responsibilities:**
- **WS Gateway:** Manages WebSocket connections, authentication, heartbeat
- **API Nodes:** Publish events to Redis when notifications are created
- **Redis Pub/Sub:** Event distribution across gateway instances
- **Connection Store:** Maps user IDs to active WebSocket connections
- **PostgreSQL:** Persistent storage for notification history

#### API Design

**WebSocket Connection:**

```javascript
// Client initiates connection
const ws = new WebSocket('wss://api.example.com/notifications');

// Authentication via initial message
ws.send(JSON.stringify({
  type: 'auth',
  token: '<jwt_token>'
}));

// Server responds with confirmation
{
  type: 'auth_success',
  userId: '12345',
  connectionId: 'conn_abc123'
}
```

**Message Format:**

```javascript
// Server → Client: Notification event
{
  type: 'notification',
  id: 'notif_xyz789',
  category: 'mention',
  timestamp: '2025-12-06T10:30:00Z',
  payload: {
    userId: '12345',
    actorId: '67890',
    actorName: 'Alice Johnson',
    message: 'mentioned you in a comment',
    resourceType: 'task',
    resourceId: 'task_456',
    resourceUrl: '/tasks/456#comment-789'
  }
}

// Client → Server: Acknowledgment
{
  type: 'ack',
  notificationId: 'notif_xyz789'
}

// Server → Client: Heartbeat (every 30 seconds)
{
  type: 'ping',
  timestamp: '2025-12-06T10:30:30Z'
}

// Client → Server: Heartbeat response
{
  type: 'pong',
  timestamp: '2025-12-06T10:30:30Z'
}
```

#### Data Models

**Connection Registry (Redis):**

```javascript
// Key: user:{userId}:connections
// Value: Set of connection IDs
SET user:12345:connections ["conn_abc123", "conn_def456"]

// Key: connection:{connectionId}
// Value: Connection metadata (30-minute TTL)
HASH connection:conn_abc123 {
  userId: "12345",
  connectedAt: "2025-12-06T10:00:00Z",
  lastHeartbeat: "2025-12-06T10:30:00Z",
  userAgent: "Mozilla/5.0...",
  ipAddress: "192.0.2.1"
}
```

**Notification Events (PostgreSQL):**

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  category VARCHAR(50) NOT NULL, -- 'mention', 'comment', 'assignment', 'alert'
  actor_id UUID,
  resource_type VARCHAR(50),
  resource_id UUID,
  payload JSONB NOT NULL,
  delivered_at TIMESTAMP,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_user_created (user_id, created_at DESC),
  INDEX idx_undelivered (user_id, delivered_at) WHERE delivered_at IS NULL
);
```

#### Connection Lifecycle

**Establishment:**
1. Client opens WebSocket connection with `wss://api.example.com/notifications`
2. Server assigns connection ID, waits for authentication
3. Client sends JWT token in `auth` message
4. Server validates token, registers connection in Redis
5. Server sends `auth_success` confirmation

**Maintenance:**
- Server sends `ping` every 30 seconds
- Client must respond with `pong` within 10 seconds
- Missing 3 consecutive pongs triggers connection closure

**Reconnection:**
- Client detects disconnection via `onclose` event
- Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s (max)
- On reconnection, client requests missed notifications since last `ack`

**Graceful Shutdown:**
- Server sends `shutdown` message 30 seconds before closure
- Client acknowledges and reconnects to different instance
- Load balancer removes instance from pool

#### Testing Strategy

**Unit Tests:**
- WebSocket authentication logic
- Message serialization/deserialization
- Heartbeat timeout handling
- Exponential backoff calculation

**Integration Tests:**
- Redis pub/sub message routing
- Multi-instance connection distribution
- Notification delivery across gateways
- Failover scenarios

**Load Tests:**
- 50,000 concurrent connections per instance
- 1,000 notifications/second throughput
- Connection churn (1,000 connects/disconnects per minute)
- Redis cluster performance under load

**End-to-End Tests:**
- User creates comment → recipient receives notification <500ms
- User disconnects → reconnects → receives missed notifications
- WebSocket unavailable → falls back to polling
- Server shutdown → graceful migration to new instance

---

## Status Report Example

### Platform Team - Q4 2025 Sprint 3 Status

**Reporting Period:** Nov 25 - Dec 6, 2025
**Team:** Platform Engineering (8 engineers)
**Sprint Goal:** Launch real-time notifications, complete API rate limiting upgrade

---

#### Accomplishments

**Shipped to Production:**
- WebSocket notification gateway deployed to staging (100% success rate over 72 hours)
- API rate limiting upgraded from 100 req/min to tiered limits (1000/5000/unlimited)
- Database connection pooling optimized - reduced pool exhaustion events by 95%
- Security audit findings remediated (3 high-severity issues closed)

**Significant Progress:**
- Real-time notifications: Frontend integration 90% complete, pending final UX review
- GraphQL schema migration: 64 of 89 endpoints converted (72% complete)
- Monitoring dashboards: New SLO tracking for notification delivery latency

**Team Development:**
- Sarah completed AWS Solutions Architect certification
- Team completed incident response training (tabletop exercise)

---

#### In Progress

**Active Work:**
- WebSocket production rollout (targeting Dec 10 launch)
  - Remaining: load testing at 50K concurrent connections
  - Blocker: need DevOps support for autoscaling group configuration
- API v3 deprecation communications (emails drafted, pending marketing review)
- Database migration to Aurora PostgreSQL (planning phase, execution in Sprint 4)

**Code Review Queue:**
- 3 PRs pending review (notification UI components)
- 1 PR blocked on security team review (authentication middleware changes)

---

#### Blockers

1. **WebSocket Load Balancer Config (P0)**
   - Need: ALB sticky session configuration for WebSocket support
   - Owner: DevOps team
   - Impact: Blocking production launch (Dec 10 deadline at risk)
   - Action: Escalated to engineering leadership, meeting scheduled Dec 7

2. **GraphQL Schema Breaking Changes (P1)**
   - Need: Decision on deprecation timeline for legacy fields
   - Owner: Product team + API consumers
   - Impact: Delaying schema migration completion by 1 sprint
   - Action: Scheduled architecture review Dec 8

3. **Staging Environment Instability (P2)**
   - Issue: Redis cluster experiencing intermittent connection timeouts
   - Impact: Slowing QA validation cycles
   - Action: Investigating root cause, temporary mitigation in place

---

#### Metrics

| Metric | Target | Actual | Trend |
|--------|--------|--------|-------|
| Sprint Velocity | 40 points | 38 points | ↓ (-5%) |
| Story Completion Rate | 90% | 85% | ↓ (WebSocket blocker) |
| Bug Escape Rate | <5% | 3% | ↑ (Improved) |
| API Error Rate (P95) | <0.5% | 0.3% | → (Stable) |
| Deploy Frequency | 2x/week | 3x/week | ↑ (Exceeded) |

---

#### Next Sprint (Sprint 4: Dec 9 - Dec 20)

**Planned Deliverables:**
1. WebSocket notifications production launch (Dec 10)
2. Complete GraphQL migration to 100%
3. Database migration to Aurora (execution phase)
4. API v2 end-of-life communications sent
5. Holiday on-call rotation finalized

**Risks:**
- Reduced capacity: 3 engineers on vacation Dec 16-20 (40% team availability)
- Year-end code freeze starts Dec 21 (hard deadline for risky changes)

**Dependencies:**
- DevOps: WebSocket load balancer config (needed by Dec 9)
- Security: Final sign-off on Aurora migration plan (needed by Dec 11)
- Product: GraphQL deprecation timeline decision (needed by Dec 8)

---

## Incident Report Example

### Incident #2024-11-28-001: Database Connection Pool Exhaustion

**Severity:** P1 (Service Degradation)
**Status:** Resolved
**Incident Commander:** Alex Chen
**Duration:** 42 minutes (14:23 - 15:05 UTC)
**User Impact:** 23% of API requests returned 503 errors

---

#### Executive Summary

On November 28, 2024, at 14:23 UTC, our production API experienced elevated error rates (23% of requests) due to database connection pool exhaustion. The root cause was a code change deployed 3 hours earlier that introduced a connection leak in the user authentication middleware. The issue was mitigated by rolling back the deployment and resolved fully by implementing connection lifecycle fixes. No data loss occurred, but approximately 12,000 user requests failed during the incident window.

---

#### Timeline

**14:23 UTC** - PagerDuty alert: API error rate threshold exceeded (>5%)
**14:25 UTC** - Incident declared, Alex Chen assigned as IC
**14:27 UTC** - Initial investigation: Database connection pool at 100% utilization
**14:30 UTC** - Identified pattern: connections not being released after auth checks
**14:35 UTC** - Correlated with deployment at 11:15 UTC (PR #3421)
**14:38 UTC** - Decision: rollback deployment to previous version
**14:42 UTC** - Rollback initiated via CI/CD pipeline
**14:48 UTC** - Rollback complete, monitoring recovery
**14:52 UTC** - Connection pool utilization dropping (80% → 60% → 40%)
**14:55 UTC** - Error rate back to baseline (<0.5%)
**15:05 UTC** - Incident resolved, monitoring period complete
**15:30 UTC** - Post-incident review meeting scheduled

---

#### Root Cause Analysis

**Immediate Cause:**
A code change in PR #3421 modified the authentication middleware to add request tracing. The implementation used `async/await` incorrectly, causing the database connection to not be released back to the pool when authentication failed (invalid tokens, expired sessions).

**Code Diff (Problematic):**

```javascript
// Before (working)
async function authenticate(req, res, next) {
  const connection = await pool.getConnection();
  try {
    const user = await connection.query('SELECT * FROM users WHERE token = ?', [req.token]);
    if (!user) return res.status(401).send('Unauthorized');
    req.user = user;
    next();
  } finally {
    connection.release(); // ✓ Always released
  }
}

// After (broken - deployed in PR #3421)
async function authenticate(req, res, next) {
  const connection = await pool.getConnection();
  const user = await connection.query('SELECT * FROM users WHERE token = ?', [req.token]);
  if (!user) return res.status(401).send('Unauthorized'); // ✗ Early return, no release
  req.user = user;
  connection.release();
  next();
}
```

**Contributing Factors:**
1. Code review did not catch the missing `try/finally` block removal
2. Integration tests did not validate connection pool behavior under failure scenarios
3. Deployment occurred during high-traffic period without gradual rollout
4. Connection pool monitoring alerts were set too high (95% threshold vs. recommended 80%)

---

#### Resolution

**Immediate Mitigation:**
Rolled back deployment to previous version (commit `a3f9d21`), restoring original authentication middleware logic.

**Permanent Fix:**
1. Restored `try/finally` pattern in authentication middleware (PR #3445)
2. Added ESLint rule to enforce `try/finally` for resource management
3. Created integration test suite for connection pool lifecycle (15 new test cases)
4. Lowered connection pool alert threshold to 80% utilization

**Verification:**
- Load testing with 10,000 concurrent requests (mixed success/failure auth)
- Connection pool utilization remained stable at 45-55%
- Zero connection leaks detected over 2-hour test period

---

#### Prevention Measures

**Short-term (Completed):**
- [x] Add connection pool monitoring dashboard (Grafana)
- [x] Lower alert threshold to 80% utilization
- [x] Implement ESLint rule for resource management patterns
- [x] Update deployment runbook with gradual rollout procedure

**Long-term (In Progress):**
- [ ] Implement automated connection leak detection in CI/CD pipeline (Sprint 4)
- [ ] Require integration tests for all middleware changes (Sprint 4)
- [ ] Adopt canary deployment strategy for API changes (Q1 2025)
- [ ] Migrate to connection pool with built-in leak detection (Q1 2025)

---

#### Lessons Learned

**What Went Well:**
- Monitoring alerted within 2 minutes of threshold breach
- Incident response team assembled quickly (5 minutes)
- Rollback decision made decisively without prolonged debugging
- Communication to stakeholders was clear and timely

**What Could Be Improved:**
- Code review process should include resource management checklist
- Integration tests should cover failure paths, not just happy paths
- Deployment timing should avoid peak traffic periods
- Monitoring should include connection pool metrics in pre-deployment checks

**Action Items:**
1. Create code review checklist for resource management (Owner: Alex Chen, Due: Dec 13)
2. Update testing standards to require failure path coverage (Owner: QA Team, Due: Dec 20)
3. Implement deployment time windows policy (Owner: DevOps, Due: Dec 15)
4. Add connection pool metrics to deployment gate criteria (Owner: Platform Team, Due: Jan 10)

---

**Report Author:** Alex Chen
**Contributors:** Platform Team, DevOps, QA
**Distribution:** Engineering leadership, Product, Customer Support
**Last Updated:** 2025-11-29
