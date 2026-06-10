# Architectural Decisions Log

**Workflow**: Real-Time Notification System for E-Commerce Platform (notification-system-20251124)
**Created**: 2025-11-24T10:00:00Z
**Last Updated**: 2025-11-25T05:45:00Z

This document tracks all key architectural decisions made during the notification system workflow across all phases, including the critical resumption decision after the production database interruption.

---

## Planning Phase Decisions (2025-11-24 Morning)

### Decision 1: Microservices Architecture
**Decided**: Implement 4 separate microservices (WebSocket, Push, Email, SMS)
**Rationale**:
- Independent scaling based on load (WebSocket has highest traffic)
- Fault isolation (email service down doesn't affect real-time notifications)
- Technology flexibility (different runtime requirements per service)
- Team autonomy (separate teams can own services)
**Alternatives Considered**:
- Monolithic notification service: Simpler deployment, but poor scaling granularity
- 2-tier split (real-time vs batch): Mid-level complexity, still couples different concerns
- Serverless functions: Cold start latency unacceptable for real-time requirements
**Decided At**: 2025-11-24T10:45:00Z
**Decided By**: agent-001 (planning)
**Impact**: Requires service orchestration, API gateway, increased operational complexity

### Decision 2: WebSocket Service for Real-Time Updates
**Decided**: Build dedicated WebSocket service for order status and inventory updates
**Rationale**:
- <500ms latency requirement for order updates (customer expectation)
- Inventory changes need instant propagation to prevent overselling
- Persistent connections reduce overhead vs polling
- Bi-directional communication enables instant notifications
**Alternatives Considered**:
- Server-Sent Events (SSE): One-way only, browser compatibility issues
- HTTP long polling: Higher latency, more server resources
- Push notifications only: Requires app to be open, no web support
**Decided At**: 2025-11-24T11:00:00Z
**Decided By**: agent-001 (planning)

### Decision 3: Message Queue for Asynchronous Processing
**Decided**: Use RabbitMQ for service-to-service messaging
**Rationale**:
- Decouples notification services from core e-commerce platform
- Retry logic for failed deliveries (email bounces, SMS failures)
- Rate limiting enforcement (prevent spam, comply with carrier limits)
- Existing infrastructure already runs RabbitMQ
**Alternatives Considered**:
- Apache Kafka: Overkill for current scale, higher operational overhead
- Redis Pub/Sub: No persistence, messages lost if consumer down
- Direct HTTP calls: Tight coupling, no retry mechanism
**Decided At**: 2025-11-24T11:15:00Z
**Decided By**: agent-001 (planning)

---

## Research Phase Decisions (2025-11-24 Late Morning)

### Decision 4: Firebase Cloud Messaging (FCM) for Android
**Decided**: Use FCM for Android push notifications
**Rationale**:
- 60% of mobile users are on Android (from user analytics)
- Industry standard with 100B+ messages/day globally
- Free tier sufficient for current scale (no cost pressure)
- Excellent documentation and SDKs
- Topic-based messaging for broadcast scenarios (flash sales)
**Alternatives Considered**:
- OneSignal: Additional abstraction layer, unnecessary complexity
- Custom XMPP implementation: High development cost, reinventing wheel
- Amazon SNS: Additional AWS dependency, less Android-specific
**Decided At**: 2025-11-24T12:45:00Z
**Decided By**: agent-002 (research)

### Decision 5: Apple Push Notification Service (APNs) for iOS
**Decided**: Use APNs for iOS push notifications
**Rationale**:
- 40% of mobile users are on iOS
- Native Apple service, required for iOS apps
- Certificate-based auth (p8 tokens) for simplicity
- Reliable delivery with feedback service
**Alternatives Considered**:
- No alternative: APNs is mandatory for iOS push
**Decided At**: 2025-11-24T12:45:00Z
**Decided By**: agent-002 (research)

### Decision 6: SendGrid for Transactional Email
**Decided**: Use SendGrid as email service provider
**Rationale**:
- 99.97% deliverability rate (critical for transactional emails)
- Webhook events for tracking (delivered, opened, bounced)
- Template management with dynamic content
- Existing relationship with SendGrid (volume discounts)
- Email validation API included
**Alternatives Considered**:
- Amazon SES: Lower cost but requires more IP warming
- Mailgun: Good alternative, but team prefers SendGrid UX
- Postmark: Excellent for transactional, but higher cost at scale
**Decided At**: 2025-11-24T13:00:00Z
**Decided By**: agent-002 (research)
**Impact**: SendGrid integration requires webhook endpoint setup

### Decision 7: Twilio for SMS Notifications
**Decided**: Use Twilio for SMS delivery
**Rationale**:
- Global coverage (190+ countries)
- 99.95% uptime SLA
- Programmable messaging API with rich features
- Webhook support for delivery status
- Short code and long code number support
- Existing Twilio account (voice calls already use Twilio)
**Alternatives Considered**:
- Amazon SNS SMS: Lower cost but limited features
- Vonage (Nexmo): Good alternative but less reliable in our testing
- Plivo: Cost-effective but team less familiar
**Decided At**: 2025-11-24T13:05:00Z
**Decided By**: agent-002 (research)

### Decision 8: Socket.io for WebSocket Implementation
**Decided**: Use Socket.io library for WebSocket service
**Rationale**:
- Automatic reconnection with exponential backoff
- Room management for targeted broadcasts (user-specific, order-specific)
- Fallback to HTTP long polling if WebSocket unavailable
- Redis adapter for horizontal scaling (multi-server broadcasting)
- Strong TypeScript support
- Battle-tested (100M+ weekly downloads)
**Alternatives Considered**:
- Raw ws library: Lower-level, would require building reconnection logic
- µWebSockets: Fastest performance, but immature ecosystem
- SockJS: Older technology, Socket.io has better maintenance
**Decided At**: 2025-11-24T13:10:00Z
**Decided By**: agent-003 (research)
**Impact**: Requires Redis for multi-server scaling (Socket.io adapter)

### Decision 9: Bull Queue for Email/SMS Processing
**Decided**: Use Bull queue library for job processing in email/SMS services
**Rationale**:
- Redis-backed queue (existing Redis infrastructure)
- Built-in retry logic with exponential backoff
- Job prioritization (urgent vs non-urgent)
- Rate limiting support (carrier restrictions, API limits)
- UI dashboard for monitoring (bull-board)
- Cron job support for scheduled sends
**Alternatives Considered**:
- BeeQueue: Simpler but fewer features
- Agenda: MongoDB-based, would require new infrastructure
- Custom Redis queue: Reinventing wheel, high maintenance
**Decided At**: 2025-11-24T13:15:00Z
**Decided By**: agent-003 (research)

---

## Design Phase Decisions (2025-11-24 Early Afternoon)

**Note**: Design phase was skipped - architecture defined in planning phase, no complex data modeling required. Decisions from planning/research were sufficient to begin execution.

---

## Execution Phase Decisions (2025-11-24 Afternoon & Post-Resumption)

### Decision 10: Handlebars for Email Templates
**Decided**: Use Handlebars template engine for email HTML
**Rationale**:
- Logic-less templates prevent complex business logic in views
- Partials support for reusable components (header, footer)
- Helpers for date formatting, currency display
- Precompilation support for performance
- Wide adoption, familiar to team
**Alternatives Considered**:
- EJS: Too much logic allowed in templates
- Pug: Unfamiliar syntax, team prefers HTML-like templates
- MJML: Email-specific, but adds compilation step
**Decided At**: 2025-11-24T14:30:00Z
**Decided By**: agent-004 (execution)
**Implementation**: Located in email service sections 4-5

### Decision 11: E.164 Phone Number Format
**Decided**: Enforce E.164 format for all phone numbers
**Rationale**:
- International standard (ITU-T recommendation)
- Twilio requires E.164 format
- Unambiguous representation (+1234567890)
- Easier validation and storage
**Format**: `+[country code][subscriber number]`
**Example**: `+14155552671` (US number)
**Decided At**: 2025-11-25T03:00:00Z
**Decided By**: agent-004 (execution, post-resumption)
**Implementation**: SMS service section 3 (validation)

### Decision 12: Opt-Out Management for SMS
**Decided**: Implement STOP/START keyword handling for SMS opt-outs
**Rationale**:
- Legal requirement (TCPA compliance in US)
- Carrier requirement (AT&T, Verizon mandate support)
- Best practice for user experience
- Prevents spam complaints
**Keywords**:
- STOP/UNSUBSCRIBE: Opt-out
- START/YES: Opt-in
- HELP: Information message
**Storage**: PostgreSQL `user_notification_preferences` table
**Decided At**: 2025-11-25T03:30:00Z
**Decided By**: agent-004 (execution, post-resumption)
**Implementation**: SMS service section 7 (opt-out handling)

---

## Interruption & Resumption Decisions (2025-11-25 Early Morning)

### Decision 13: Resume Agent-004 from Checkpoint (Critical Decision)
**Decided**: Continue agent-004 from checkpoint instead of restarting from scratch
**Context**: Production database failure interrupted workflow at T+5:45 (2h 15m into execution, 50% complete)
**Rationale**:
- **Work Preservation**: 2 services complete (WebSocket, Push), 1 service 60% complete (Email sections 1-5)
- **Time Savings**: Estimated 2 hours saved vs full restart (57% reduction)
- **Token Savings**: Estimated 9.4K tokens saved vs full restart (59% reduction)
- **Quality Preservation**: Completed services follow established patterns, restarting risks inconsistency
- **Filesystem State**: All work preserved in STATUS.yaml, agent outputs, progress markers
**Alternatives Considered**:
1. **Restart agent-004 from scratch** (Option A - rejected):
   - Pro: Clean slate, no risk of confusion
   - Con: Waste 2.25h of completed work, duplicate effort, inconsistent patterns
2. **Start new agent-005 for remaining work** (Option B - rejected):
   - Pro: Isolates interruption impact
   - Con: Lacks context from completed services, architectural inconsistency risk
3. **Resume agent-004 from checkpoint** (Option C - selected):
   - Pro: Preserves completed work, consistent architecture, efficient resource use
   - Con: Requires careful context construction (mitigated by STATUS.yaml, READ-FIRST.md)
**Implementation Strategy**:
- Resume with continuation context: "You were interrupted, here's what's complete, here's what remains"
- Reference STATUS.yaml for detailed progress
- Review completed service files to understand patterns
- Complete Email service sections 6-9
- Implement full SMS service
**Decided At**: 2025-11-25T02:00:00Z (T+14:00, after 8h 15m interruption)
**Decided By**: orchestrator
**Actual Results**:
- Time to complete: 1.5h (vs 3.5h estimated for restart)
- Tokens used: 6.2K (vs 15.6K estimated for restart)
- Time saved: ~2h (actual 57% reduction)
- Tokens saved: ~9.4K (actual 59% reduction)
- Quality: Consistent architecture across all 4 services
**Impact**: Validated framework's interruption-resilience capability

---

## Review Phase Decisions (2025-11-25 Morning)

### Decision 14: Production Readiness Acceptance
**Decided**: Accept all 4 services as production-ready with 2 post-launch enhancements
**Rationale**:
- All core features implemented (4 services with complete API definitions)
- Consistent architecture across services (shared patterns documented)
- Error handling comprehensive (retry logic, fallbacks, monitoring hooks)
- Configuration validated (environment variables, secrets management)
- Integration points documented (RabbitMQ, PostgreSQL, Redis)
- Security reviewed (API authentication, rate limiting, input validation)
**Minor Items to Address Post-Launch**:
1. Add Prometheus metrics endpoints (low-priority monitoring enhancement)
2. Implement circuit breaker pattern for external APIs (nice-to-have resilience)
**Decided At**: 2025-11-25T05:30:00Z
**Decided By**: agent-005 (review)

---

## Decision Impact Analysis

### High Impact (Architecture-Defining)
- Decision 1: Microservices architecture (affects all services)
- Decision 2: WebSocket for real-time (core requirement)
- Decision 3: RabbitMQ message queue (service communication pattern)
- Decision 8: Socket.io implementation (WebSocket service foundation)
- Decision 13: Resume from checkpoint (workflow efficiency pattern)

### Medium Impact (Implementation Details)
- Decision 4: FCM for Android (platform choice)
- Decision 5: APNs for iOS (platform choice)
- Decision 6: SendGrid for email (provider choice)
- Decision 7: Twilio for SMS (provider choice)
- Decision 9: Bull queue (job processing)

### Low Impact (Quality Improvements)
- Decision 10: Handlebars templates (templating engine)
- Decision 11: E.164 format (validation standard)
- Decision 12: Opt-out management (compliance feature)
- Decision 14: Production acceptance (quality gate)

---

## Cross-Phase Decision Dependencies

```
Decision 1 (Microservices)
    ├─> Decision 2 (WebSocket service)
    ├─> Decision 3 (RabbitMQ for service communication)
    └─> Decision 8 (Socket.io for WebSocket implementation)

Decision 3 (RabbitMQ)
    └─> Decision 9 (Bull queue for email/SMS processing)

Decision 4 & 5 (FCM & APNs)
    └─> Push service implementation (platform-specific payloads)

Decision 6 (SendGrid)
    └─> Decision 10 (Handlebars templates)

Decision 7 (Twilio)
    ├─> Decision 11 (E.164 format requirement)
    └─> Decision 12 (Opt-out management)

Decision 13 (Resume from checkpoint)
    └─> Framework validation (interruption-resilience pattern)
```

---

## Interruption-Specific Analysis

### Interruption Event
**Timestamp**: 2025-11-24T15:45:00Z (T+5:45)
**Cause**: Production database failure requiring all-hands response
**Duration**: 8 hours 15 minutes
**Work Status at Interruption**:
- WebSocket service: 100% complete (842 lines)
- Push notification service: 100% complete (657 lines)
- Email service: 60% complete (sections 1-5 of 9, ~630 lines)
- SMS service: 0% complete

### Resumption Strategy Decision Process
**Question**: How to handle partial work when resuming?
**Options Evaluated**:
1. Discard partial work, restart agent-004 from scratch
2. Preserve partial work, start new agent for remaining tasks
3. Preserve partial work, resume agent-004 with continuation context

**Evaluation Criteria**:
- Time efficiency (minimize rework)
- Token efficiency (minimize redundant context)
- Quality consistency (maintain architectural patterns)
- Implementation risk (complexity of resumption)

**Selected Option**: #3 (Resume agent-004 from checkpoint)
**Key Success Factors**:
- Clear progress markers (-INCOMPLETE, -TODO file suffixes)
- Detailed STATUS.yaml with section-level granularity
- READ-FIRST.md documenting shared patterns
- Agent's ability to review completed work to understand patterns

---

## Future Decision Points

These items were discussed but deferred for post-launch:

1. **Monitoring & Alerting Enhancement**
   - Decision needed: Prometheus vs Datadog vs custom metrics
   - Timeline: 2 weeks post-launch

2. **Circuit Breaker Implementation**
   - Decision needed: Resilience4j vs custom implementation
   - Timeline: 1 month post-launch

3. **Multi-Region Deployment**
   - Decision needed: Active-active vs active-passive
   - Timeline: Q1 2026

4. **Notification Preferences UI**
   - Decision needed: Admin portal vs customer-facing settings
   - Timeline: Q2 2026

---

## Lessons Learned

### What Worked Well
- Early technology decisions (Socket.io, SendGrid, Twilio) proved correct during implementation
- Microservices split provided clear boundaries for agent work
- File-based state preservation enabled seamless interruption recovery
- Progress markers (-INCOMPLETE, -TODO) made resumption trivial
- STATUS.yaml provided perfect resumption reference

### What Could Be Improved
- Could have addressed monitoring requirements earlier (surfaced in review)
- Design phase skip was correct, but could have formalized that decision earlier
- Circuit breaker pattern should have been in initial design

### Interruption-Resilience Framework Validation
- **Hypothesis**: File-based state can preserve workflow progress across interruptions
- **Test**: 8-hour production incident mid-execution
- **Result**: Zero data loss, successful resumption, 57% time savings vs restart
- **Conclusion**: Framework successfully validated for interruption-resilience

---

**Document Status**: Complete
**Total Decisions**: 14 across 4 phases (planning, research, execution, review)
**Critical Decision**: #13 (Resume from checkpoint) - validated framework's core value
**Last Updated**: 2025-11-25T05:45:00Z (Workflow completion)
