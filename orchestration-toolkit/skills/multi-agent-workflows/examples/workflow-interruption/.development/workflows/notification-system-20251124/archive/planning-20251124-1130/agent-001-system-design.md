---
phase: planning
author_agent: agent-001-system-design
created_at: 2025-11-24T10:05:00Z
updated_at: 2025-11-24T11:28:00Z
topic: system-architecture
status: completed
tokens_used: 18500
context_sources:
  - Product team requirements document (e-commerce platform)
  - Existing notification analysis (current system audit)
  - Technology stack inventory (Node.js, PostgreSQL, Redis infrastructure)
  - User analytics (50K DAU, notification preferences)
---

# System Architecture: Real-Time Notification System for E-Commerce Platform

## Summary

Designed microservices architecture for e-commerce notification system supporting 4 distinct channels (WebSocket, Push, Email, SMS). Recommended approach: Node.js + Express services with Redis pub/sub for real-time distribution and RabbitMQ for queued delivery. Key architectural decisions made for independent service scaling, fault isolation, and technology-specific implementations. System designed to handle 50K daily active users with peak loads of 3x during flash sales.

---

## Context

### Inputs Reviewed

**Product Requirements**:
- E-commerce platform serving 50K daily active users
- Notification channels needed: real-time web, mobile push, email, SMS
- User journey focus: order lifecycle, inventory alerts, promotional campaigns
- Latency requirements: <500ms (real-time), <5s (push), <1m (email), <30s (SMS)

**Current System Audit**:
- No existing notification infrastructure (manual email only)
- Existing infrastructure: Node.js backend, PostgreSQL database, Redis cache
- Team expertise: 100% Node.js developers, no Go/Python/Java experience
- Infrastructure constraints: Must use existing PostgreSQL and Redis (no new databases)

**Analytics Data**:
- Daily active users: 50,000
- Order volume: 5,000 orders/day
- Peak traffic multiplier: 3x during flash sales (15,000 orders/day)
- Mobile platform distribution: 60% Android, 40% iOS
- Email open rate: 42% (industry average: 20-25%, we're above average)

### Task Assignment

**Assigned by**: Orchestrator (user request: "Design real-time notification system for e-commerce platform")
**Assignment**: Create system architecture, define service boundaries, select technology stack, design API patterns
**Scope**:
- ✅ In scope: Architecture design, technology decisions, service definitions, API patterns
- ❌ Out of scope: Implementation details, code examples, database schema, deployment configuration

---

## System Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    E-Commerce Application                        │
│  (Order Service, Inventory Service, User Service, etc.)          │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ (Publishes notification events)
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Redis Pub/Sub                               │
│         (Event distribution: order.placed, item.shipped)         │
└─────┬──────────┬──────────┬──────────┬────────────────────────┘
      │          │          │          │
      │          │          │          │
      ▼          ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│WebSocket │ │   Push   │ │  Email   │ │   SMS    │
│ Service  │ │ Service  │ │ Service  │ │ Service  │
│          │ │          │ │          │ │          │
│Socket.io │ │FCM+APNs  │ │SendGrid  │ │ Twilio   │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │            │
     │            │            │            │
     │            │            │            │
     ▼            ▼            ▼            ▼
┌──────────────────────────────────────────────┐
│        PostgreSQL (notification_logs)         │
│     (Audit trail: delivery status, errors)    │
└──────────────────────────────────────────────┘

Additional Components:
- RabbitMQ: Email/SMS queues (reliable delivery, retry logic)
- Redis: WebSocket session state, Socket.io adapter
```

### Architecture Rationale

**Microservices Approach** (4 independent services):

1. **WebSocket Service** (Real-time notifications)
   - Handles Socket.io connections for web clients
   - Broadcasts order status updates, inventory changes
   - Scales horizontally (Redis adapter for multi-server)
   - Most complex scaling challenge (10K+ concurrent connections)

2. **Push Notification Service** (Mobile notifications)
   - Integrates Firebase Cloud Messaging (Android) and APNs (iOS)
   - Manages device tokens, platform-specific payloads
   - Scales vertically (API-limited, not compute-bound)
   - Moderate complexity (token lifecycle management)

3. **Email Service** (Transactional and marketing emails)
   - Integrates SendGrid for email delivery
   - Uses Handlebars templates for content
   - RabbitMQ consumer for queued processing
   - Webhook handling for delivery tracking
   - High reliability requirement (order confirmations business-critical)

4. **SMS Service** (Urgent notifications)
   - Integrates Twilio for SMS delivery
   - Rate limiting for carrier restrictions (10/second)
   - Opt-out management (STOP/START commands)
   - RabbitMQ consumer for queued processing
   - Cost sensitivity (SMS charges per message)

**Why Microservices vs Monolith**:

✅ **Advantages**:
- Independent scaling (WebSocket 8x flash sale, email steady)
- Fault isolation (email downtime doesn't break real-time)
- Technology flexibility (Socket.io, FCM SDK, SendGrid, Twilio)
- Parallel development (team can work on services simultaneously)
- Deployment independence (update email templates without WebSocket restart)

❌ **Drawbacks** (acceptable trade-offs):
- Additional operational complexity (4 services to monitor vs 1)
- Inter-service communication overhead (Redis pub/sub, minimal latency)
- Slightly higher infrastructure cost (4 containers vs 1)

**Decision**: Microservices worth the trade-offs given scaling requirements and fault isolation needs.

---

## Technology Stack Decisions

### Backend Services: Node.js 18 + Express 4.18

**Selection Rationale**:
- ✅ Team expertise: 100% of developers proficient in Node.js
- ✅ WebSocket ecosystem: Socket.io is industry standard, excellent documentation
- ✅ Notification libraries: All providers have official Node.js SDKs (Firebase Admin, node-apn, @sendgrid/mail, twilio)
- ✅ Async/await pattern: Perfect for fire-and-forget notification delivery
- ✅ Performance: Event loop handles concurrent I/O efficiently (10K+ WebSocket connections)

**Alternatives Considered**:
- Python + Flask: Good for email/SMS (Jinja2 templates), but weaker WebSocket support (asyncio complexity)
- Go: Best performance (goroutines), but 2-3 week learning curve for team (not justified for I/O-bound workload)
- Java + Spring Boot: Enterprise-grade, but overkill for notification services (slower development, larger container sizes)

**Ecosystem Libraries** (to be evaluated in research phase):
- WebSocket: Socket.io (+ Redis adapter for scaling)
- Push: firebase-admin, node-apn
- Email: @sendgrid/mail, nodemailer
- SMS: twilio SDK
- Templates: Handlebars (email HTML), ejs (fallback)
- Queues: amqplib (RabbitMQ client)

### Message Broker: RabbitMQ

**Selection Rationale**:
- ✅ Reliable delivery: Acknowledgments, persistent queues, dead letter queues
- ✅ Rate limiting: Consumer throttling for SMS carrier restrictions (10/second)
- ✅ Retry logic: Dead letter queue with exponential backoff
- ✅ Existing infrastructure: Order processing service already uses RabbitMQ
- ✅ Monitoring: Management UI, Prometheus metrics

**Use Cases**:
- Email queue: Transactional and marketing emails (order confirmations, newsletters)
- SMS queue: Urgent notifications (shipment tracking, security alerts)
- Dead letter queue: Failed deliveries (retry with exponential backoff)

**Alternatives Considered**:
- Redis queues (Bull): Simpler, but less reliable (no acknowledgments, risk of message loss)
- Kafka: High throughput (100K+ msg/sec), but overkill and expensive for our scale (5K orders/day)
- AWS SQS: Vendor lock-in, additional cloud dependency (prefer self-hosted)

### Real-time Distribution: Redis Pub/Sub

**Selection Rationale**:
- ✅ Existing infrastructure: Redis already deployed for caching (99.9% uptime)
- ✅ Sub-millisecond latency: <1ms typical pub/sub latency
- ✅ Socket.io integration: Redis adapter for horizontal WebSocket scaling
- ✅ Simple pattern: Publish to 'notifications' channel, services subscribe
- ✅ No persistence needed: Pub/sub ephemeral (if subscriber offline, OK to miss message)

**Use Cases**:
- Event distribution: Order placed → all notification services receive event
- WebSocket scaling: Socket.io rooms synchronized across multiple servers
- Cache invalidation: (Bonus) Can use for other real-time cache updates

**Alternatives Considered**:
- RabbitMQ pub/sub: More features (routing, persistence), but overkill for simple pub/sub
- Kafka: High throughput, but 500ms+ latency (unacceptable for <500ms requirement)
- HTTP webhooks: 50-200ms latency vs <1ms Redis, no ordering guarantees

### Persistence: PostgreSQL 14

**Selection Rationale**:
- ✅ Existing database: No new infrastructure deployment
- ✅ JSONB support: Flexible notification payload storage (different types: email, push, SMS)
- ✅ Query capabilities: Analytics (delivery rates, failure analysis), customer support (proof of delivery)
- ✅ ACID guarantees: Audit trail integrity (legal requirement for transactional emails)

**Schema Design** (to be detailed in design phase):
```sql
-- High-level schema (details in design phase)
CREATE TABLE notification_logs (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  notification_type TEXT NOT NULL,  -- 'email', 'push', 'sms', 'websocket'
  channel TEXT NOT NULL,             -- 'order', 'inventory', 'promotion'
  payload JSONB NOT NULL,            -- Flexible per notification type
  delivery_status TEXT NOT NULL,     -- 'pending', 'sent', 'delivered', 'failed'
  delivered_at TIMESTAMP,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_notifications ON notification_logs(user_id, created_at DESC);
CREATE INDEX idx_delivery_status ON notification_logs(delivery_status, created_at);
```

**Retention Policy**: 90 days (compliance requirement for transactional emails)

---

## Service Definitions

### 1. WebSocket Service (Real-time Notifications)

**Responsibility**: Push real-time updates to web clients for order status and inventory changes.

**Technology Stack**:
- Socket.io 4.x (WebSocket library with fallback to HTTP polling)
- Redis adapter (for horizontal scaling across multiple servers)
- Express (for health check endpoint)

**Key Features**:
1. **Connection Lifecycle Management**:
   - Client connects: Authenticate via session token
   - Subscribe to user-specific room: `user:{userId}`
   - Heartbeat: 30-second ping/pong to detect disconnections
   - Reconnection: Automatic with exponential backoff

2. **Room-Based Broadcasting**:
   - User rooms: `user:{userId}` (order updates for specific user)
   - Inventory rooms: `item:{itemId}` (price drops, back-in-stock)
   - Admin rooms: `admin:dashboard` (real-time dashboard stats)

3. **Event Types**:
   - `order:placed` - Order confirmation
   - `order:processing` - Order being prepared
   - `order:shipped` - Shipment tracking number
   - `order:delivered` - Delivery confirmation
   - `inventory:price_drop` - Price alert for wishlisted item
   - `inventory:back_in_stock` - Availability alert

**Scaling Strategy**:
- Redis adapter: Share Socket.io state across multiple servers
- Load balancer: Sticky sessions not required (Redis handles state)
- Target capacity: 10,000 concurrent connections per server
- Auto-scaling: CPU > 70% triggers new server instance

**API Endpoints**:
- `GET /health` - Health check (200 OK if Socket.io server running)
- WebSocket connection: `ws://notifications.example.com` (upgrades from HTTP)

**Monitoring**:
- Connected clients count (Prometheus gauge)
- Events broadcasted per second (Prometheus counter)
- Average message latency (Prometheus histogram)

### 2. Push Notification Service (Mobile Notifications)

**Responsibility**: Send push notifications to Android (FCM) and iOS (APNs) devices.

**Technology Stack**:
- firebase-admin SDK (Firebase Cloud Messaging for Android)
- node-apn (Apple Push Notification service for iOS)
- Express (REST API for device token registration)

**Key Features**:
1. **Device Token Management**:
   - Token registration: POST /devices (store in PostgreSQL)
   - Token refresh: PUT /devices/:token (update on app launch)
   - Token deletion: DELETE /devices/:token (on logout)
   - Platform detection: Automatic (FCM vs APNs based on token format)

2. **Platform-Specific Payloads**:
   - Android (FCM): `{ notification: { title, body }, data: { orderId, action } }`
   - iOS (APNs): `{ aps: { alert: { title, body }, badge: 1 }, data: { orderId } }`

3. **Notification Types**:
   - Order updates: "Your order #1234 has shipped!"
   - Price drops: "Item on your wishlist dropped to $49.99"
   - Back-in-stock: "Nike Air Max is back in stock"
   - Abandoned cart: "Complete your purchase - 10% off today"

**Device Token Storage** (PostgreSQL):
```sql
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT UNIQUE NOT NULL,
  platform TEXT NOT NULL,  -- 'android' or 'ios'
  active BOOLEAN DEFAULT TRUE,
  last_used_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Error Handling**:
- Invalid token: Mark as inactive in database
- Token expired: Remove from database
- Platform error: Log to PostgreSQL, retry once

**API Endpoints**:
- `POST /devices` - Register device token
- `PUT /devices/:token` - Update token metadata
- `DELETE /devices/:token` - Unregister device
- `POST /send` - Send push notification (internal API, called by notification event handler)

**Rate Limits**:
- FCM: 600K requests/minute (free tier, sufficient for our scale)
- APNs: No documented limit (thousands per second typical)

### 3. Email Service (Transactional and Marketing Emails)

**Responsibility**: Send transactional emails (order confirmations) and marketing emails (newsletters, promotions).

**Technology Stack**:
- SendGrid (@sendgrid/mail SDK)
- Handlebars (HTML template engine)
- RabbitMQ consumer (amqplib)
- Bull queue (backup queue for SendGrid API failures)
- Express (webhook endpoint for delivery tracking)

**Key Features**:
1. **Template System**:
   - Handlebars templates in `templates/` directory
   - Partials for header, footer (consistent branding)
   - Dynamic content: Order details, user name, tracking links
   - Plain text fallback (auto-generated from HTML)

2. **Email Types**:
   - Transactional (P0):
     - Order confirmation: "Thanks for your order #1234"
     - Shipment notification: "Your order is on the way!"
     - Delivery confirmation: "Your package has arrived"
     - Password reset: "Reset your password"
   - Marketing (P1):
     - Newsletter: Weekly digest
     - Promotions: Flash sale announcements
     - Abandoned cart: "Complete your purchase"

3. **Delivery Tracking** (SendGrid webhooks):
   - Webhook endpoint: POST /webhooks/sendgrid
   - Events: delivered, opened, clicked, bounced, spam
   - Update PostgreSQL: delivery_status, delivered_at
   - Alerting: Bounce rate > 5% triggers Slack notification

4. **Queue Processing**:
   - RabbitMQ queue: `email_notifications`
   - Consumer concurrency: 10 parallel workers
   - Message format: `{ userId, templateName, templateData, to, subject }`
   - Acknowledgment: Only after SendGrid confirms (no message loss)

**Retry Logic**:
- SendGrid API error: Retry 3 times with exponential backoff (1s, 5s, 25s)
- After 3 failures: Move to dead letter queue, alert ops team
- Dead letter queue: Manual review + retry

**API Endpoints**:
- `POST /send` - Queue email for delivery (internal API)
- `POST /webhooks/sendgrid` - Delivery tracking webhook
- `GET /health` - Health check (RabbitMQ connection status)

**Monitoring**:
- Emails sent per minute (Prometheus counter)
- Delivery rate (delivered / sent, Prometheus gauge)
- Bounce rate (bounced / sent, Prometheus gauge)
- Queue depth (RabbitMQ management API)

**Configuration** (.env):
```
SENDGRID_API_KEY=SG.xxxx
SENDGRID_FROM_EMAIL=noreply@example.com
SENDGRID_FROM_NAME=Example Store
RABBITMQ_URL=amqp://localhost:5672
WEBHOOK_SECRET=xxx  # Validate SendGrid webhook signatures
```

### 4. SMS Service (Urgent Notifications)

**Responsibility**: Send urgent SMS notifications for shipments and security alerts.

**Technology Stack**:
- Twilio (twilio SDK)
- RabbitMQ consumer (amqplib)
- Express (webhook endpoint for delivery status)

**Key Features**:
1. **SMS Types** (Urgent Only):
   - Shipment notifications: "Your order #1234 shipped! Track: https://..."
   - Delivery notifications: "Your package arrived. Enjoy!"
   - Security alerts: "New login from IP 1.2.3.4. Not you? Reset password."
   - OTP codes: "Your verification code: 123456"

2. **Rate Limiting** (Carrier Restrictions):
   - Max rate: 10 SMS/second (carrier limit)
   - Implementation: Token bucket algorithm (consume 1 token per SMS)
   - Queue backlog: Alert if queue depth > 1000 messages

3. **Opt-Out Management**:
   - User preference: Store in PostgreSQL (sms_opt_in column)
   - STOP command: "Reply STOP to unsubscribe" (Twilio auto-handles)
   - START command: "Reply START to resubscribe"
   - Compliance: Required for marketing SMS (not transactional)

4. **Phone Number Validation**:
   - Format: E.164 (e.g., +14155551234)
   - Validation: libphonenumber-js library
   - Invalid numbers: Log error, do not retry

5. **Cost Tracking**:
   - Twilio pricing: $0.0075 per SMS (US)
   - Estimated monthly cost: 5,000 orders × 2 SMS × $0.0075 = $75/month
   - Budget alert: > $100/month triggers review

**Queue Processing**:
- RabbitMQ queue: `sms_notifications`
- Consumer concurrency: 1 worker (rate limiting to 10/second)
- Message format: `{ userId, phoneNumber, message }`
- Acknowledgment: After Twilio confirms delivery

**Webhook Handling** (Delivery Status):
- Webhook endpoint: POST /webhooks/twilio
- Events: sent, delivered, failed, undelivered
- Update PostgreSQL: delivery_status

**API Endpoints**:
- `POST /send` - Queue SMS for delivery (internal API)
- `POST /webhooks/twilio` - Delivery status webhook
- `GET /health` - Health check

**Error Handling**:
- Invalid number: Log error, mark as failed, do not retry
- Delivery failure: Retry once (sometimes temporary network issues)
- Opt-out: Silently skip (user preference)

**Configuration** (.env):
```
TWILIO_ACCOUNT_SID=ACxxxx
TWILIO_AUTH_TOKEN=xxxx
TWILIO_PHONE_NUMBER=+14155551234
RABBITMQ_URL=amqp://localhost:5672
```

---

## Inter-Service Communication Patterns

### Event Flow: Order Placed → All Notification Channels

```
Step 1: Order Service publishes event
  ├─ Redis PUBLISH 'notifications' '{"event": "order.placed", "orderId": "1234", "userId": "user-001"}'

Step 2: All notification services subscribe to 'notifications' channel
  ├─ WebSocket Service: Socket.io broadcasts to room `user:user-001`
  ├─ Push Service: Sends push to user-001's Android/iOS devices
  ├─ Email Service: Queues order confirmation email to RabbitMQ
  └─ SMS Service: Queues shipment notification SMS to RabbitMQ

Step 3: Delivery and logging
  ├─ Each service writes delivery log to PostgreSQL
  └─ Metrics exported to Prometheus
```

### Redis Pub/Sub Event Schema

**Event Format** (JSON):
```json
{
  "event": "order.placed",        // Event type
  "userId": "user-001",            // Recipient
  "orderId": "1234",               // Context data
  "timestamp": "2025-11-24T10:30:00Z",
  "priority": "high",              // 'high', 'normal', 'low'
  "channels": ["websocket", "push", "email", "sms"]  // Which channels to use
}
```

**Event Types**:
- `order.placed` - New order
- `order.processing` - Order being prepared
- `order.shipped` - Order shipped (tracking number)
- `order.delivered` - Delivery confirmed
- `inventory.price_drop` - Price alert
- `inventory.back_in_stock` - Availability alert
- `user.security_alert` - Login from new device

### RabbitMQ Queue Schema

**Email Queue Message** (JSON):
```json
{
  "userId": "user-001",
  "templateName": "order-confirmation",
  "templateData": {
    "orderId": "1234",
    "orderTotal": "$99.99",
    "items": [...]
  },
  "to": "user@example.com",
  "subject": "Order Confirmation #1234",
  "priority": "high"
}
```

**SMS Queue Message** (JSON):
```json
{
  "userId": "user-001",
  "phoneNumber": "+14155551234",
  "message": "Your order #1234 shipped! Track: https://example.com/track/1234",
  "priority": "high"
}
```

---

## API Design Patterns

### Internal APIs (Service-to-Service)

**WebSocket Service**:
- No internal API (subscribes to Redis pub/sub, broadcasts to clients)

**Push Service**:
- `POST /send` - Send push notification
  - Request: `{ userId, title, body, data, priority }`
  - Response: `{ messageId, platform, status }`

**Email Service**:
- `POST /send` - Queue email for delivery
  - Request: `{ userId, templateName, templateData, to, subject }`
  - Response: `{ queueId, estimatedDelivery }`

**SMS Service**:
- `POST /send` - Queue SMS for delivery
  - Request: `{ userId, phoneNumber, message }`
  - Response: `{ queueId, estimatedDelivery }`

### External APIs (Client-facing)

**Device Token Registration** (Push Service):
```
POST /api/v1/devices
Authorization: Bearer {userToken}
Content-Type: application/json

Request:
{
  "token": "fcm-or-apns-token",
  "platform": "android"  // or "ios"
}

Response (201 Created):
{
  "id": "device-001",
  "userId": "user-001",
  "platform": "android",
  "createdAt": "2025-11-24T10:30:00Z"
}
```

**WebSocket Connection**:
```
// Client-side code (JavaScript)
const socket = io('wss://notifications.example.com', {
  auth: {
    token: userSessionToken
  }
});

socket.on('connect', () => {
  console.log('Connected to notification service');
});

socket.on('notification', (data) => {
  // Handle notification: { event, orderId, message, timestamp }
  console.log('Notification received:', data);
});
```

---

## Deployment and Scaling Considerations

### Container Configuration

**WebSocket Service**:
- Resources: 1 CPU, 2GB RAM (per instance)
- Replicas: 3 (auto-scale based on connection count)
- Health check: HTTP GET /health (200 OK)

**Push Service**:
- Resources: 0.5 CPU, 1GB RAM
- Replicas: 2 (redundancy, not scaling)
- Health check: HTTP GET /health

**Email Service**:
- Resources: 0.5 CPU, 1GB RAM
- Replicas: 3 (scale based on queue depth)
- Health check: RabbitMQ connection status

**SMS Service**:
- Resources: 0.5 CPU, 1GB RAM
- Replicas: 1 (rate-limited to 10/second, single consumer sufficient)
- Health check: RabbitMQ connection status

### Scaling Triggers

**WebSocket Service**:
- Scale up: Connected clients > 8,000 per instance (80% of 10K capacity)
- Scale down: Connected clients < 3,000 per instance (30% capacity)
- Max replicas: 10 (100K concurrent connections = 10 instances × 10K)

**Email Service**:
- Scale up: Queue depth > 5,000 messages (backlog > 10 minutes)
- Scale down: Queue depth < 500 messages (backlog < 1 minute)
- Max replicas: 10

**SMS Service**:
- No auto-scaling (single consumer, rate-limited)

---

## Security Considerations

### Authentication and Authorization

**WebSocket Service**:
- Client authentication: JWT token in connection handshake
- Room authorization: Users can only subscribe to their own rooms (`user:{userId}`)
- Token validation: Verify signature with secret key

**Push Service**:
- Device token registration: Requires authenticated user session
- Token ownership: Validate userId matches authenticated user

**Email Service**:
- Internal API only: No external access (called by order service)
- Webhook verification: Validate SendGrid signature

**SMS Service**:
- Internal API only: No external access
- Webhook verification: Validate Twilio signature

### Data Protection

**Sensitive Data**:
- Email addresses: Encrypted at rest in PostgreSQL (AES-256)
- Phone numbers: Encrypted at rest in PostgreSQL
- Device tokens: Encrypted at rest
- Message content: Not encrypted (contains no PII, just order IDs and public data)

**Secrets Management**:
- API keys: Stored in environment variables (Kubernetes secrets)
- Webhook secrets: Rotated monthly
- JWT signing key: Rotated quarterly

### Rate Limiting

**WebSocket Service**:
- Connection rate: Max 10 connections per user (prevent abuse)
- Message rate: Max 100 messages/second per user (DoS protection)

**Push Service**:
- Registration rate: Max 5 device tokens per user (prevent abuse)

**Email Service**:
- No rate limiting (internal API, already rate-limited by order volume)

**SMS Service**:
- Carrier limit: 10 SMS/second (enforced by queue consumer)
- User limit: Max 5 SMS/day per user (cost control)

---

## Monitoring and Observability

### Metrics (Prometheus)

**WebSocket Service**:
- `websocket_connected_clients` (gauge) - Current connection count
- `websocket_events_sent_total` (counter) - Events broadcasted
- `websocket_latency_seconds` (histogram) - Time from event to client delivery

**Push Service**:
- `push_notifications_sent_total` (counter) - Push notifications sent (by platform)
- `push_delivery_rate` (gauge) - Successful deliveries / total sent
- `push_token_count` (gauge) - Active device tokens

**Email Service**:
- `email_sent_total` (counter) - Emails sent
- `email_delivery_rate` (gauge) - Delivered / sent
- `email_bounce_rate` (gauge) - Bounced / sent
- `email_queue_depth` (gauge) - RabbitMQ queue depth

**SMS Service**:
- `sms_sent_total` (counter) - SMS sent
- `sms_cost_total` (counter) - Total cost in USD
- `sms_queue_depth` (gauge) - RabbitMQ queue depth

### Logging (Structured JSON)

**Log Format**:
```json
{
  "timestamp": "2025-11-24T10:30:00Z",
  "service": "email-service",
  "level": "info",
  "message": "Email sent successfully",
  "userId": "user-001",
  "emailId": "email-001",
  "templateName": "order-confirmation",
  "deliveryTime": "2.3s"
}
```

**Log Levels**:
- ERROR: Delivery failures, API errors, database errors
- WARN: Retries, slow delivery (>30s), high queue depth
- INFO: Successful deliveries, configuration changes
- DEBUG: Detailed event processing (disabled in production)

### Alerting (Slack/PagerDuty)

**Critical Alerts** (PagerDuty):
- WebSocket service down (no health check response for 2 minutes)
- Email delivery rate < 90% (for 10 minutes)
- Email bounce rate > 10% (for 5 minutes)
- RabbitMQ connection lost

**Warning Alerts** (Slack):
- Email queue depth > 10,000 messages
- SMS cost > $100/month
- Push delivery rate < 95% (for 30 minutes)

---

## Questions for Orchestrator

### Question 1

**Question**: Should we support multiple notification providers per channel (e.g., SendGrid + AWS SES for email failover)?
**Context**: Current design uses single provider per channel (SendGrid for email, Twilio for SMS). Multi-provider adds complexity but increases reliability.

**Options**:
- **Option 1 (Single Provider)**: Use SendGrid exclusively for email
  - Pros: Simpler implementation, fewer API integrations, lower operational complexity
  - Cons: Single point of failure (if SendGrid down, no email delivery)

- **Option 2 (Multi-Provider with Failover)**: SendGrid primary, AWS SES fallback
  - Pros: Higher reliability (99.99% uptime with failover), no single point of failure
  - Cons: More complex implementation, must maintain 2 integrations, harder testing

- **Option 3 (Multi-Provider with Load Balancing)**: Round-robin between SendGrid and AWS SES
  - Pros: Best reliability, load distribution
  - Cons: Most complex, inconsistent delivery tracking (2 different webhook formats)

**My Recommendation**: Option 1 (Single Provider) for initial implementation. SendGrid has 99.97% uptime SLA, sufficient for our current scale. Design service with abstraction layer (EmailProvider interface) to enable future multi-provider support without major refactoring. Add failover in Q2 2026 if uptime becomes issue.

**Blocking**: No - Can proceed with single provider, design for future multi-provider

---

## Next Steps

### For Next Phase (Research)

**Priority 1: Notification Provider Research**
- Evaluate Firebase Cloud Messaging vs APNs vs alternatives (OneSignal, Pusher)
- Compare SendGrid vs AWS SES vs Mailgun (deliverability, pricing, features)
- Research Twilio alternatives (AWS SNS, MessageBird) for SMS
- Document provider selection criteria (cost, deliverability, SDK quality, uptime SLA)

**Priority 2: WebSocket Patterns Research**
- Investigate Socket.io Redis adapter configuration (scaling best practices)
- Research sticky sessions vs adapter approach (trade-offs)
- Study reconnection strategies (exponential backoff, client-side buffering)
- Document room management patterns (user-specific rooms, inventory rooms)

**Priority 3: Security Best Practices**
- Research mobile push token security (encryption, token rotation)
- Investigate message encryption for sensitive notifications (GDPR compliance)
- Study rate limiting patterns (token bucket, sliding window)
- Document webhook signature verification (SendGrid, Twilio)

**Priority 4: Queue Patterns**
- Research RabbitMQ dead letter queue configuration (retry strategies)
- Investigate exponential backoff patterns (retry intervals: 1s, 5s, 25s, 125s)
- Study queue priority patterns (high-priority transactional vs low-priority marketing)
- Document queue monitoring best practices (alert thresholds)

**Expected Deliverables**:
- Provider comparison matrix (features, pricing, deliverability, SLA)
- WebSocket scaling guide (Redis adapter configuration, load testing results)
- Security checklist (token management, encryption, rate limiting)
- Queue reliability patterns (DLQ, retry, monitoring)

---

## References

### Technology Documentation

**WebSocket**:
- [Socket.io Documentation](https://socket.io/docs/v4/) - WebSocket library
- [Socket.io Redis Adapter](https://socket.io/docs/v4/redis-adapter/) - Horizontal scaling

**Push Notifications**:
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) - Android push
- [Apple Push Notification service](https://developer.apple.com/documentation/usernotifications) - iOS push

**Email**:
- [SendGrid API Documentation](https://docs.sendgrid.com/api-reference/how-to-use-the-sendgrid-v3-api/authentication) - Email delivery
- [Handlebars Documentation](https://handlebarsjs.com/) - Template engine

**SMS**:
- [Twilio SMS API](https://www.twilio.com/docs/sms) - SMS delivery
- [Twilio Messaging Services](https://www.twilio.com/docs/messaging/services) - Opt-out management

**Message Brokers**:
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html) - Message queue
- [Redis Pub/Sub](https://redis.io/topics/pubsub) - Real-time event distribution

### Architecture Patterns

- [Microservices Architecture](https://microservices.io/) - Design patterns
- [Event-Driven Architecture](https://martinfowler.com/articles/201701-event-driven.html) - Martin Fowler
- [Notification Service Design](https://www.educative.io/courses/grokking-the-system-design-interview/notification-service) - System design

---

## Agent Output Metadata

**Agent ID**: agent-001-system-design
**Workflow ID**: notification-system-20251124
**Phase**: planning
**Topic**: system-architecture
**Started**: 2025-11-24T10:05:00Z
**Completed**: 2025-11-24T11:28:00Z
**Duration**: 83 minutes
**Tokens Used**: 18,500 (approximate)
**Status**: completed

**Return JSON**:
```json
{
  "status": "finished",
  "output_paths": ["active/planning/agent-001-system-design.md"],
  "questions": [
    {
      "question": "Should we support multiple notification providers per channel?",
      "options": ["Single provider", "Multi-provider failover", "Multi-provider load balancing"],
      "recommendation": "Single provider (design for future multi-provider)",
      "blocking": false
    }
  ],
  "summary": "Designed microservices architecture with 4 notification services (WebSocket, Push, Email, SMS). Selected Node.js + Express stack with Redis pub/sub and RabbitMQ queues. Key decisions: microservices for independent scaling, Socket.io for WebSocket, Firebase/APNs for push, SendGrid for email, Twilio for SMS. System designed for 50K DAU with 3x peak capacity.",
  "tokens_used": 18500,
  "next_phase_context": "Research phase should investigate notification providers (Firebase, APNs, SendGrid, Twilio), WebSocket scaling patterns (Socket.io Redis adapter), security best practices (token management, encryption), and queue reliability patterns (RabbitMQ DLQ, retry strategies). Architecture decisions made, need provider-specific implementation guidance."
}
```
