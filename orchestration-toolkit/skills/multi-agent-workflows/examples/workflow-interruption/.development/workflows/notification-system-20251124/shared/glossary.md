# Real-Time Notification System Glossary

**Workflow**: notification-system-20251124
**Created**: 2025-11-24T10:00:00Z
**Last Updated**: 2025-11-25T05:45:00Z

This glossary captures domain terminology discovered and refined during the notification system workflow, including interruption-resilience concepts.

---

## Notification Delivery Mechanisms

### WebSocket
**Definition**: Bi-directional, persistent communication protocol enabling real-time data push from server to client.
**Context**: Used for order status updates and inventory changes requiring <500ms latency.
**Protocol**: Upgrades from HTTP to WebSocket (ws:// or wss://)
**Added In**: Planning phase
**Related Terms**: Socket.io, Real-Time Notifications

### Push Notification
**Definition**: Mobile device notification delivered via platform-specific service (FCM for Android, APNs for iOS).
**Context**: Used for critical alerts when user not actively using app (order shipped, price drop).
**Delivery**: Through OS-level notification center, survives app closure
**Added In**: Planning phase
**Related Terms**: FCM, APNs, Device Token

### Transactional Email
**Definition**: Automated email triggered by user action or system event (order confirmation, password reset).
**Context**: Legal/compliance-critical notifications requiring audit trail.
**Distinction**: Not marketing email (CAN-SPAM exemption)
**Added In**: Planning phase
**Related Terms**: SendGrid, Email Template

### SMS (Short Message Service)
**Definition**: Text message notification sent to mobile phone via carrier network.
**Context**: High-urgency notifications (2FA codes, order delays) with 98% open rate.
**Limitations**: 160 characters (GSM-7), carrier rate limits, cost per message
**Added In**: Planning phase
**Related Terms**: Twilio, E.164, Opt-Out

---

## Third-Party Services (Research Phase)

### FCM (Firebase Cloud Messaging)
**Definition**: Google's platform for sending push notifications to Android devices and web.
**Pronunciation**: "F-C-M" (letters, not acronym)
**Features**:
- Topic-based messaging for broadcast
- Device group messaging
- Upstream messaging (device to server)
- Analytics and delivery reports
**Free Tier**: Unlimited messages
**Added In**: Research phase
**Related Terms**: Push Notification, Device Token, APNs

### APNs (Apple Push Notification service)
**Definition**: Apple's platform for sending push notifications to iOS, macOS, watchOS, tvOS devices.
**Pronunciation**: "A-P-N-S" (letters) or "Apple Push"
**Authentication**:
- Token-based (.p8 key file) - recommended
- Certificate-based (.p12 file) - legacy
**Environment**: Sandbox (development) vs Production
**Added In**: Research phase
**Related Terms**: Push Notification, Device Token, FCM

### SendGrid
**Definition**: Cloud-based email delivery service (ESP - Email Service Provider) by Twilio.
**Capabilities**:
- Transactional and marketing email
- Template management with dynamic content
- Webhook events (delivered, opened, bounced)
- Email validation API
**Deliverability**: 99.97% (industry-leading)
**Added In**: Research phase
**Related Terms**: Transactional Email, Email Template, Webhook

### Twilio
**Definition**: Cloud communications platform for SMS, voice, and video.
**Context**: Using Programmable Messaging API for SMS notifications.
**Features**:
- Global SMS delivery (190+ countries)
- Short codes and long codes
- Two-way messaging (send and receive)
- Delivery status webhooks
**Pricing**: Pay-per-message (varies by country)
**Added In**: Research phase
**Related Terms**: SMS, E.164, Webhook

### Socket.io
**Definition**: JavaScript library for real-time, bi-directional communication between web clients and servers.
**Architecture**:
- Built on top of WebSocket protocol
- Automatic fallback to HTTP long polling
- Event-based communication
**Features**:
- Automatic reconnection with exponential backoff
- Room management for broadcasting
- Redis adapter for horizontal scaling
**Added In**: Research phase
**Related Terms**: WebSocket, Redis Adapter, Room

---

## Infrastructure & Architecture (Planning/Execution Phase)

### Microservices Architecture
**Definition**: Application design pattern where system is composed of small, independent services communicating via APIs.
**Our Implementation**: 4 services (WebSocket, Push, Email, SMS)
**Benefits**: Independent scaling, fault isolation, technology flexibility
**Trade-offs**: Increased operational complexity, distributed system challenges
**Added In**: Planning phase
**Related Terms**: Service Orchestration, Message Queue

### Message Queue
**Definition**: Asynchronous communication pattern where messages are stored in queue until consumed.
**Our Choice**: RabbitMQ
**Purpose**: Decouple notification services from core platform, enable retry logic
**Pattern**: Producer → Queue → Consumer
**Added In**: Planning phase
**Related Terms**: RabbitMQ, Bull Queue, Asynchronous Processing

### RabbitMQ
**Definition**: Open-source message broker implementing AMQP (Advanced Message Queuing Protocol).
**Usage**: Service-to-service messaging for notification events
**Features**: Routing, persistence, delivery acknowledgments, clustering
**Exchanges**: Direct, topic, fanout, headers
**Added In**: Planning phase, implemented in Execution phase
**Related Terms**: Message Queue, AMQP

### Bull Queue
**Definition**: Redis-backed job queue for Node.js with advanced features.
**Usage**: Email and SMS job processing (retry, rate limiting, scheduling)
**Features**:
- Retry logic with exponential backoff
- Job prioritization (urgent vs normal)
- Rate limiting (respect API limits)
- Cron jobs (scheduled sends)
- UI dashboard (bull-board)
**Storage**: Redis lists and sorted sets
**Added In**: Research phase, implemented in Execution phase
**Related Terms**: Job Queue, Redis, Rate Limiting

### Redis Adapter
**Definition**: Socket.io component enabling message broadcasting across multiple server instances.
**Purpose**: Horizontal scaling - WebSocket connections distributed across servers
**Mechanism**: Redis Pub/Sub for inter-server communication
**Configuration**: `io.adapter(redisAdapter({ host: 'redis.internal', port: 6379 }))`
**Added In**: Research phase, implemented in Execution phase
**Related Terms**: Socket.io, Horizontal Scaling, Redis

---

## Data Formats & Standards (Execution Phase)

### E.164
**Definition**: International standard for telephone number formatting (ITU-T recommendation).
**Format**: `+[country code][subscriber number]` (no spaces, hyphens, parentheses)
**Example**:
- US: `+14155552671` (not `(415) 555-2671`)
- UK: `+447700900123` (not `07700 900123`)
**Max Length**: 15 digits (including country code)
**Requirement**: Twilio requires E.164 format for all phone numbers
**Added In**: Execution phase (SMS service implementation)
**Related Terms**: Phone Number Validation, Twilio

### Device Token
**Definition**: Unique identifier for mobile device used to route push notifications.
**Platform-Specific**:
- FCM: 152-character string (e.g., `eGpSd3F4...`)
- APNs: 64-character hex string (e.g., `740f4707...`)
**Lifecycle**: Can change (app reinstall, user opts out), must refresh periodically
**Storage**: Database table `device_tokens` with user_id, platform, token, updated_at
**Added In**: Research phase, detailed in Execution phase
**Related Terms**: Push Notification, FCM, APNs

### Email Template
**Definition**: Reusable HTML/text structure with placeholders for dynamic content.
**Our Choice**: Handlebars templates
**Structure**:
- Base layout (header, footer)
- Partials (reusable components)
- Helpers (date formatting, currency)
**Example**: `order-confirmation.hbs` with `{{customer.name}}`, `{{order.total}}`
**Storage**: Filesystem (`/templates/email/`) or SendGrid Template Editor
**Added In**: Execution phase (Email service implementation)
**Related Terms**: Handlebars, SendGrid, Dynamic Content

### Handlebars
**Definition**: Logic-less template engine for JavaScript, extends Mustache syntax.
**Philosophy**: Templates contain presentation logic only, not business logic
**Features**:
- Variables: `{{name}}`
- Conditionals: `{{#if premium}}...{{/if}}`
- Loops: `{{#each items}}...{{/each}}`
- Partials: `{{> header}}`
- Helpers: `{{formatDate date "MMMM DD, YYYY"}}`
**Precompilation**: Templates compiled to JavaScript functions for performance
**Added In**: Execution phase (Email service implementation)
**Related Terms**: Email Template, Template Engine

---

## Security & Compliance (Execution Phase)

### Opt-Out Management
**Definition**: System for managing user preferences to stop receiving notifications.
**Legal Requirement**: TCPA (US), GDPR (EU) require clear opt-out mechanisms
**SMS Keywords**:
- STOP, UNSUBSCRIBE, CANCEL, END, QUIT → Opt-out
- START, YES, UNSTOP → Opt-in
- HELP, INFO → Information message
**Implementation**:
- Database table `user_notification_preferences`
- Automatic keyword detection in incoming SMS
- Confirmation message sent on opt-out/opt-in
**Added In**: Execution phase (SMS service implementation)
**Related Terms**: TCPA Compliance, SMS, User Preferences

### TCPA (Telephone Consumer Protection Act)
**Definition**: US federal law regulating telemarketing calls, auto-dialed calls, and SMS messages.
**Key Requirements**:
- Prior express consent before sending marketing SMS
- Clear opt-out mechanism (STOP keyword)
- Identification of sender
- Time restrictions (8am-9pm local time)
**Penalties**: Up to $1,500 per violation
**Relevance**: SMS service must comply to avoid fines
**Added In**: Execution phase (SMS service implementation)
**Related Terms**: Opt-Out Management, Compliance, SMS

### Rate Limiting
**Definition**: Restricting number of operations within time window to prevent abuse and comply with limits.
**Context**: Multiple use cases in notification system
**Use Cases**:
1. **API Protection**: Prevent abuse of notification endpoints (10 req/min per user)
2. **Carrier Limits**: SMS throughput limits (1 msg/sec per long code)
3. **Provider Limits**: SendGrid (100 emails/sec), Twilio (varies by country)
**Implementation**: Bull queue with limiter config, Redis-based counters
**Added In**: Research phase (Bull queue decision), detailed in Execution phase
**Related Terms**: Bull Queue, Throttling, API Limits

### Webhook
**Definition**: HTTP callback - server makes POST request to configured URL when event occurs.
**Context**: Delivery status tracking from SendGrid and Twilio
**SendGrid Events**:
- `delivered`: Email successfully delivered
- `open`: Recipient opened email (tracking pixel)
- `click`: Recipient clicked link
- `bounce`: Email bounced (hard or soft)
- `spam_report`: Marked as spam
**Twilio Events**:
- `queued`, `sent`, `delivered`, `failed`, `undelivered`
**Security**: Validate webhook signatures to prevent spoofing
**Added In**: Research phase, implemented in Execution phase
**Related Terms**: SendGrid, Twilio, Event Tracking

---

## WebSocket Concepts (Execution Phase)

### Room
**Definition**: Socket.io concept - logical channel for broadcasting messages to subset of connected clients.
**Usage Examples**:
- User-specific room: `user:${userId}` (only that user's devices)
- Order-specific room: `order:${orderId}` (all users watching that order)
- Inventory room: `inventory:${productId}` (all users viewing product page)
**Join/Leave**: `socket.join('room-name')`, `socket.leave('room-name')`
**Broadcasting**: `io.to('room-name').emit('event', data)`
**Added In**: Execution phase (WebSocket service implementation)
**Related Terms**: Socket.io, Broadcasting, Namespace

### Connection Lifecycle
**Definition**: States a WebSocket connection transitions through from establishment to termination.
**States**:
1. **Connecting**: Client initiates WebSocket handshake
2. **Connected**: Handshake complete, bi-directional communication established
3. **Authenticated**: Client provides JWT token, server validates
4. **Subscribed**: Client joined rooms, receiving targeted broadcasts
5. **Disconnected**: Connection closed (network issue, client exit, server restart)
**Events**: `connection`, `authenticated`, `disconnect`, `reconnect`
**Added In**: Execution phase (WebSocket service implementation)
**Related Terms**: WebSocket, Socket.io, Authentication

### Reconnection
**Definition**: Automatic re-establishment of WebSocket connection after disconnection.
**Socket.io Strategy**:
- Exponential backoff: 1s, 2s, 4s, 8s, 16s (max)
- Randomization: Add jitter to prevent thundering herd
- Max attempts: Configurable (default unlimited)
**Client-Side**: `socket.io-client` handles automatically
**Server-Side**: Must re-authenticate and re-join rooms on reconnect
**Added In**: Research phase (Socket.io decision), detailed in Execution phase
**Related Terms**: Socket.io, Connection Lifecycle, Exponential Backoff

---

## Workflow Interruption Concepts (Interruption Event)

### Checkpoint
**Definition**: Point in agent execution where progress is saved, enabling resumption from that state.
**Our Implementation**: File-based checkpoints
- STATUS.yaml: Section-level progress tracking
- Agent output files: Completed deliverables
- Progress markers: -INCOMPLETE, -TODO file suffixes
**Purpose**: Enable interruption-resilience without database/external state
**Added In**: Interruption event (2025-11-24T15:45:00Z)
**Related Terms**: Resumption, File-Based State, Progress Markers

### Continuation Context
**Definition**: Information provided to resumed agent about prior work, current state, and remaining tasks.
**Components**:
1. **What happened**: Description of interruption event
2. **What's complete**: List of finished deliverables with file paths
3. **What's in progress**: Partially complete work with specific stopping point
4. **What remains**: Explicit list of pending tasks
5. **Patterns to follow**: Reference to completed work for consistency
**Format**: Structured prompt to Task tool when resuming agent
**Added In**: Resumption event (2025-11-25T02:00:00Z)
**Related Terms**: Agent Resumption, Checkpoint, Interruption Recovery

### File-Based State
**Definition**: Workflow state persistence using filesystem files instead of database or external storage.
**Files Used**:
- `workflow-state.yaml`: Overall workflow progress, phases, agents
- `STATUS.yaml`: Current phase progress, detailed task tracking
- Agent output files: Deliverables (markdown, code)
- Progress markers: File suffixes indicating completion status
**Benefits**:
- No external dependencies (database, API)
- Version control friendly (git diff shows progress)
- Human-readable (easy to inspect, debug)
- Survives system restarts, crashes, interruptions
**Added In**: Framework design (present from workflow start)
**Related Terms**: Checkpoint, Persistence, Interruption-Resilience

### Progress Markers
**Definition**: File naming conventions indicating completion status of deliverables.
**Conventions**:
- `{filename}.md`: Complete, ready for use
- `{filename}-INCOMPLETE.md`: Started but not finished
- `{filename}-TODO.md`: Planned but not started
**Purpose**: Visual indication of what's done vs pending (filesystem listing shows status)
**Usage**: During interruption, orchestrator scans for progress markers to determine checkpoint
**Added In**: Framework design, critical during interruption recovery
**Related Terms**: File-Based State, Checkpoint, Status Tracking

### Agent Resumption
**Definition**: Continuing an interrupted agent's work with awareness of prior progress.
**Alternatives**:
1. **Restart from scratch**: Agent begins with original prompt, no memory of prior work
2. **New agent for remaining work**: Different agent handles pending tasks
3. **Resume with continuation context**: Same agent continues with prior work awareness (selected)
**Resumption Process**:
1. Analyze checkpoint files (STATUS.yaml, agent outputs)
2. Construct continuation context (what's done, what remains)
3. Resume agent with continuation context
4. Agent reviews completed work to understand patterns
5. Agent completes remaining tasks
**Added In**: Resumption decision (2025-11-25T02:00:00Z)
**Related Terms**: Continuation Context, Checkpoint, Interruption Recovery

---

## Performance & Optimization

### Exponential Backoff
**Definition**: Retry strategy where wait time between attempts increases exponentially.
**Formula**: `delay = initial_delay * (2 ^ attempt_number)`
**Example**: 1s, 2s, 4s, 8s, 16s, 32s (capped at max_delay)
**Jitter**: Add randomness to prevent synchronized retries (thundering herd)
**Usage**: Socket.io reconnection, Bull queue retries, API error handling
**Added In**: Research phase (Socket.io, Bull queue decisions)
**Related Terms**: Retry Logic, Reconnection, Error Handling

### Horizontal Scaling
**Definition**: Adding more server instances to handle increased load (scale out vs scale up).
**WebSocket Challenge**: Connection state is local to server instance
**Solution**: Redis adapter for Socket.io
- Client connects to any server instance (load balancer)
- Server publishes messages to Redis Pub/Sub
- All servers subscribe to Redis channel
- Message broadcast reaches all connected clients
**Added In**: Research phase (Socket.io decision)
**Related Terms**: Redis Adapter, Load Balancing, Scalability

### Job Queue
**Definition**: Queue data structure for managing background tasks (jobs) to be processed asynchronously.
**Our Implementation**: Bull queue (Redis-backed)
**Job Lifecycle**:
1. Enqueue: Add job to queue with payload
2. Wait: Job sits in queue until worker available
3. Process: Worker picks up job, executes task
4. Complete: Job marked complete, removed from queue
5. (Optional) Retry: On failure, re-queue with backoff
**Use Cases**: Email sending, SMS sending, webhook deliveries
**Added In**: Research phase, implemented in Execution phase
**Related Terms**: Bull Queue, Asynchronous Processing, Background Jobs

---

## Acronyms & Abbreviations

- **AMQP**: Advanced Message Queuing Protocol
- **APNs**: Apple Push Notification service
- **CAN-SPAM**: Controlling the Assault of Non-Solicited Pornography And Marketing (US email law)
- **ESP**: Email Service Provider (e.g., SendGrid, Mailgun)
- **FCM**: Firebase Cloud Messaging
- **GDPR**: General Data Protection Regulation (EU)
- **GSM-7**: 7-bit character encoding for SMS (160 chars max)
- **ITU-T**: International Telecommunication Union - Telecommunication Standardization Sector
- **JWT**: JSON Web Token (authentication)
- **Pub/Sub**: Publish/Subscribe (messaging pattern)
- **SMS**: Short Message Service
- **TCPA**: Telephone Consumer Protection Act (US)
- **TTL**: Time to Live (expiration)
- **WebSocket**: Full-duplex communication protocol (RFC 6455)

---

## Phase-by-Phase Term Discovery

### Planning Phase
- Notification delivery mechanisms (WebSocket, Push, Email, SMS)
- Microservices architecture
- Message queue pattern
- Real-time requirements

### Research Phase
- Third-party services (FCM, APNs, SendGrid, Twilio)
- Socket.io features and architecture
- Bull queue for job processing
- Rate limiting strategies

### Design Phase
- (Skipped - no unique terms added)

### Execution Phase (Pre-Interruption)
- WebSocket concepts (Room, Connection Lifecycle)
- Push notification specifics (Device Token)
- Email templating (Handlebars)

### Execution Phase (Post-Resumption)
- SMS specifics (E.164, Opt-Out Management)
- Compliance (TCPA)
- Webhook implementation details

### Interruption Event
- Checkpoint and resumption concepts
- File-based state management
- Progress markers
- Continuation context

### Review Phase
- Integration testing terminology
- Production readiness criteria
- Deployment patterns

---

## External References

- **Socket.io Documentation**: https://socket.io/docs/v4/
- **Firebase Cloud Messaging (FCM)**: https://firebase.google.com/docs/cloud-messaging
- **Apple Push Notification service (APNs)**: https://developer.apple.com/documentation/usernotifications
- **SendGrid API**: https://docs.sendgrid.com/api-reference
- **Twilio Programmable Messaging**: https://www.twilio.com/docs/messaging
- **Bull Queue**: https://github.com/OptimalBits/bull
- **Handlebars Template Engine**: https://handlebarsjs.com/
- **E.164 Standard**: https://www.itu.int/rec/T-REC-E.164/en
- **TCPA Compliance**: https://www.fcc.gov/general/telemarketing-and-robocalls
- **RabbitMQ**: https://www.rabbitmq.com/documentation.html

---

## Context-Specific Term Usage

### Real-Time vs Asynchronous
**Real-Time**: WebSocket service (<500ms latency requirement)
**Asynchronous**: Email, SMS services (acceptable delay, queue-based)

### Transactional vs Marketing
**Transactional**: Order confirmations, shipping updates (TCPA-exempt, high priority)
**Marketing**: Promotional emails, sale announcements (requires opt-in, lower priority)

### Platform-Specific
**Android**: FCM, device tokens (152-char), Google Play Services dependency
**iOS**: APNs, device tokens (64-char hex), certificate/token auth

### Interruption-Specific
**Checkpoint**: Point where progress saved (every service completion, every section)
**Resumption**: Act of continuing work (agent-004 resumed at T+14:00)
**Continuation Context**: Information provided to resumed agent

---

**Glossary Status**: Complete
**Total Terms**: 45+ terms across all phases
**Interruption Terms**: 5 new concepts added during recovery
**Last Updated**: 2025-11-25T05:45:00Z (Workflow completion)
