# Backend Notification Services - Architecture Guide

## Overview

This directory contains implementation specifications for 4 backend notification services that work together to deliver multi-channel notifications to users.

**Services**:
1. **WebSocket Service** - Real-time push notifications via persistent connections
2. **Push Notification Service** - Mobile push notifications (FCM for Android, APNs for iOS)
3. **Email Service** - Transactional emails via SendGrid with template rendering
4. **SMS Service** - SMS notifications via Twilio with opt-out management

**Created**: 2025-11-24T13:30:00Z
**Last Updated**: 2025-11-25T04:30:00Z
**Agent**: agent-004-backend-services

---

## Shared Architecture Patterns

All 4 services follow consistent patterns for maintainability and operational excellence.

### Technology Stack

**Common Dependencies**:
- **Runtime**: Node.js 20+ (LTS)
- **Framework**: Express.js 4.18+
- **Database**: PostgreSQL 15+ (for persistent data)
- **Cache/Queue**: Redis 7+ (for session storage, queues, rate limiting)
- **Message Queue**: RabbitMQ 3.12+ (for asynchronous processing)
- **Monitoring**: Prometheus + Grafana (metrics and dashboards)
- **Logging**: Winston 3.x (structured JSON logging)

**Service-Specific**:
- **WebSocket**: Socket.io 4.6+, Redis adapter
- **Push**: FCM Admin SDK, node-apn
- **Email**: SendGrid API, Handlebars templates, Bull queue
- **SMS**: Twilio SDK, libphonenumber-js

### Configuration Management

All services use environment variables for configuration with sensible defaults.

**Common Variables**:
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/notifications
POSTGRES_POOL_SIZE=20

# Redis
REDIS_URL=redis://localhost:6379
REDIS_KEY_PREFIX=notifications:

# RabbitMQ
RABBITMQ_URL=amqp://user:pass@localhost:5672
RABBITMQ_EXCHANGE=notifications

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Monitoring
METRICS_PORT=9090
```

**Service-Specific** (see individual service files):
- WebSocket: `WEBSOCKET_PORT`, `JWT_SECRET`
- Push: `FCM_SERVER_KEY`, `APNS_KEY_PATH`, `APNS_KEY_ID`
- Email: `SENDGRID_API_KEY`, `EMAIL_TEMPLATE_DIR`
- SMS: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`

### Error Handling

**Consistent Error Response Format**:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid phone number format",
    "details": {
      "field": "phoneNumber",
      "value": "555-1234",
      "expected": "E.164 format (e.g., +12025551234)"
    },
    "requestId": "req-abc123",
    "timestamp": "2025-11-24T13:45:00Z"
  }
}
```

**Error Categories**:
- `VALIDATION_ERROR` - Invalid input (400)
- `AUTHENTICATION_ERROR` - Invalid or missing credentials (401)
- `AUTHORIZATION_ERROR` - Insufficient permissions (403)
- `NOT_FOUND` - Resource not found (404)
- `RATE_LIMIT_ERROR` - Too many requests (429)
- `EXTERNAL_SERVICE_ERROR` - Third-party service failure (502)
- `INTERNAL_ERROR` - Unexpected server error (500)

**Retry Strategy** (for external services):
```javascript
const retryConfig = {
  maxAttempts: 3,
  backoff: 'exponential', // 1s, 2s, 4s
  retryableErrors: ['NETWORK_ERROR', 'TIMEOUT', 'SERVICE_UNAVAILABLE'],
  nonRetryableErrors: ['VALIDATION_ERROR', 'AUTHENTICATION_ERROR']
};
```

### Logging

**Log Structure** (Winston format):
```json
{
  "level": "info",
  "message": "Notification sent successfully",
  "service": "push-notification-service",
  "requestId": "req-abc123",
  "userId": "user-12345",
  "notificationType": "order-confirmation",
  "platform": "android",
  "duration": 234,
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Log Levels**:
- `error` - Errors requiring immediate attention
- `warn` - Warnings that may need investigation
- `info` - General informational messages (requests, completions)
- `debug` - Detailed debugging information (disabled in production)

### Health Checks

All services expose `/health` endpoint:

```http
GET /health HTTP/1.1
Host: localhost:3001

HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "service": "websocket-service",
  "version": "1.0.0",
  "uptime": 3600,
  "dependencies": {
    "redis": "connected",
    "database": "connected",
    "rabbitmq": "connected"
  },
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Health Status Codes**:
- `200 OK` - All dependencies healthy
- `503 Service Unavailable` - One or more dependencies unhealthy

### Database Schema

**Shared Tables**:

```sql
-- Notification history (all channels)
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  channel VARCHAR(20) NOT NULL, -- 'websocket', 'push', 'email', 'sms'
  type VARCHAR(50) NOT NULL, -- 'order-confirmation', 'inventory-alert', etc.
  status VARCHAR(20) NOT NULL, -- 'pending', 'sent', 'delivered', 'failed'
  payload JSONB NOT NULL,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- User notification preferences
CREATE TABLE user_notification_preferences (
  user_id UUID PRIMARY KEY,
  email_enabled BOOLEAN DEFAULT TRUE,
  sms_enabled BOOLEAN DEFAULT TRUE,
  push_enabled BOOLEAN DEFAULT TRUE,
  websocket_enabled BOOLEAN DEFAULT TRUE,
  quiet_hours_start TIME, -- e.g., '22:00:00'
  quiet_hours_end TIME, -- e.g., '08:00:00'
  timezone VARCHAR(50) DEFAULT 'UTC',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Service Interaction

### Notification Flow

```
┌─────────────┐
│   API/App   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Notification API   │ (receives notification request)
│   (not in scope)    │
└──────┬──────────────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌─────────────┐  ┌─────────────┐
│  RabbitMQ   │  │  WebSocket  │ (for immediate delivery)
│   Exchange  │  │   Service   │
└──────┬──────┘  └─────────────┘
       │
       ├──────────┬─────────────┬─────────────┐
       │          │             │             │
       ▼          ▼             ▼             ▼
┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐
│   Push   │ │  Email  │ │   SMS    │ │  Other   │
│ Service  │ │ Service │ │ Service  │ │ Channels │
└──────────┘ └─────────┘ └──────────┘ └──────────┘
       │          │             │
       ▼          ▼             ▼
┌────────────────────────────────────┐
│    External Services               │
│  (FCM, APNs, SendGrid, Twilio)    │
└────────────────────────────────────┘
```

**Key Points**:
1. WebSocket service handles real-time delivery (bypasses queue)
2. Other services consume from RabbitMQ queues
3. Each service manages its own external service integration
4. All services write to shared `notifications` table for tracking

### Inter-Service Communication

Services are **loosely coupled** - they do not call each other directly.

**Communication Patterns**:
1. **Event-Driven** (via RabbitMQ):
   - Notification API publishes events to exchange
   - Services subscribe to relevant event types
   - Example: `notification.order-confirmation` → all 4 services receive

2. **Shared Database**:
   - Services write delivery status to `notifications` table
   - Services check `user_notification_preferences` before sending
   - No direct API calls between services

3. **Independent Deployments**:
   - Each service can scale independently
   - Service failures are isolated (SMS failure doesn't affect email)
   - Each service has its own health monitoring

---

## Deployment Considerations

### Service Ports

| Service | Port | Protocol |
|---------|------|----------|
| WebSocket Service | 3001 | HTTP + WS |
| Push Notification Service | 3002 | HTTP |
| Email Service | 3003 | HTTP |
| SMS Service | 3004 | HTTP |

### Scaling Strategy

**WebSocket Service**:
- Horizontal scaling with Redis adapter (shared connection state)
- Sticky sessions at load balancer (optional, Redis makes it unnecessary)
- Auto-scale based on active connection count

**Push/Email/SMS Services**:
- Horizontal scaling (stateless)
- Auto-scale based on queue depth (RabbitMQ metrics)
- Recommended: 2-5 instances per service for redundancy

### Resource Requirements (per instance)

| Service | CPU | Memory | Connections |
|---------|-----|--------|-------------|
| WebSocket | 1-2 cores | 512MB-1GB | 10,000+ concurrent |
| Push | 1 core | 256MB-512MB | N/A (queue-based) |
| Email | 1 core | 512MB | N/A (queue-based) |
| SMS | 1 core | 256MB | N/A (queue-based) |

### Monitoring Metrics

**Key Metrics to Track** (all services):
- Request rate (requests/sec)
- Error rate (errors/sec, %)
- Latency (p50, p95, p99)
- Queue depth (for async services)
- Dependency health (Redis, PostgreSQL, RabbitMQ)

**Service-Specific**:
- WebSocket: Active connections, connection churn rate
- Push: Delivery rate, platform breakdown (Android vs iOS)
- Email: Template render time, SendGrid API latency
- SMS: SMS cost ($ per message), opt-out rate

---

## Testing Strategy

### Unit Testing

All services should have:
- Input validation tests
- Error handling tests
- External service mocking (FCM, SendGrid, Twilio)
- Template rendering tests (for email)

### Integration Testing

Test interactions with:
- Redis (connection, pub/sub, rate limiting)
- PostgreSQL (queries, transactions)
- RabbitMQ (message consumption)
- External services (sandbox/test modes)

### Load Testing

Recommended tools:
- **WebSocket**: `k6` with WebSocket extension
- **Push/Email/SMS**: `k6` or `Artillery` (queue-based load)

Target metrics:
- WebSocket: 10,000 concurrent connections per instance
- Push: 1,000 notifications/sec
- Email: 500 emails/sec
- SMS: 100 SMS/sec (carrier rate limits apply)

---

## Security Considerations

### API Authentication

All services should authenticate requests:
- WebSocket: JWT validation on connection
- Push/Email/SMS: API key or OAuth token on REST endpoints

### Secrets Management

Use environment variables + secrets manager:
```bash
# Development (local .env)
SENDGRID_API_KEY=SG.xxxxx

# Production (AWS Secrets Manager, HashiCorp Vault, etc.)
SENDGRID_API_KEY=$(aws secretsmanager get-secret-value --secret-id prod/sendgrid-key --query SecretString --output text)
```

### Data Privacy

- **PII Protection**: Encrypt email addresses, phone numbers at rest
- **Log Redaction**: Mask sensitive data in logs (e.g., phone numbers → `+1202555****`)
- **Retention**: Delete old notifications after 90 days (GDPR compliance)

---

## Next Steps

For detailed implementation of each service, see:
1. [websocket-service.md](./websocket-service.md) - Real-time notifications
2. [push-notification-service.md](./push-notification-service.md) - Mobile push (FCM + APNs)
3. [email-service.md](./email-service.md) - Transactional emails
4. [sms-service.md](./sms-service.md) - SMS notifications

Each file contains:
- Service-specific architecture
- API endpoint specifications
- External service integration details
- Error handling patterns
- Configuration requirements
- Testing recommendations
