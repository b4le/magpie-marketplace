# SMS Notification Service

## Service Overview

**Purpose**: Send SMS notifications via Twilio API with rate limiting, opt-out management, and compliance features

**Use Cases**:
- Order status updates (shipped, delivered)
- Two-factor authentication (2FA) codes
- Appointment reminders
- Time-sensitive alerts (flash sales, limited inventory)
- Delivery notifications

**Technology Stack**:
- Node.js 20+
- Express.js 4.18+
- Twilio API (SMS provider)
- Redis (rate limiting, deduplication)
- PostgreSQL (opt-out database, message history)
- libphonenumber-js (phone validation)

**Port**: 3004

---

## Architecture

### SMS Sending Flow

```
API Request            SMS Service              Twilio               Recipient
    │                       │                      │                     │
    ├──1. POST /send-sms───>│                      │                     │
    │   (phoneNumber, msg)  │                      │                     │
    │                       ├──2. Validate Phone───>│                     │
    │                       │   (E.164 format)     │                     │
    │                       ├──3. Check Opt-Out    │                     │
    │                       │   (database)         │                     │
    │                       ├──4. Rate Limit Check │                     │
    │                       │   (Redis)            │                     │
    │                       ├──5. Send via API─────>│                     │
    │                       │                      ├──6. Deliver────────>│
    │<──7. 202 Accepted─────┤                      │                     │
    │   (message_id)        │<──8. Delivery Status─┤                     │
    │                       │   (webhook)          │                     │
    │                       ├──9. Update DB        │                     │
    │                       │   (delivered_at)     │                     │
    │                       │                      │<──10. STOP command──┤
    │                       │<──11. Webhook────────┤   (opt-out)         │
    │                       ├──12. Add to Opt-Out  │                     │
    │                       │   (database)         │                     │
```

### Rate Limiting Architecture

**Why Rate Limiting?**
- Carrier restrictions (max 1 msg/sec per phone number for US carriers)
- Cost control (prevent runaway spending)
- Spam prevention (avoid being flagged as spammer)

**Redis-Based Rate Limiting**:

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   Request   │──────>│    Redis    │       │   Twilio    │
│  (send SMS) │       │ Rate Limiter│──yes─>│     API     │
└─────────────┘       └──────┬──────┘       └─────────────┘
                             │
                             │ no (rate exceeded)
                             ▼
                      ┌─────────────┐
                      │   429 Error │
                      │ (Too Many   │
                      │  Requests)  │
                      └─────────────┘
```

**Rate Limit Tiers**:

| Tier | Limit | Window | Use Case |
|------|-------|--------|----------|
| Per phone number | 1 msg/sec | 1 second | Carrier restriction |
| Per user | 10 msg/min | 1 minute | Prevent abuse |
| Global | 100 msg/sec | 1 second | Service capacity |

### Opt-Out Management System

**Compliance Requirements** (TCPA, CTIA):
- Must honor opt-out requests immediately
- Must respond to "STOP" keyword with confirmation
- Must support "START" to re-enable

**Opt-Out Flow**:

```
Recipient              Twilio                SMS Service           Database
    │                      │                      │                    │
    ├──1. Reply "STOP"────>│                      │                    │
    │                      ├──2. Webhook─────────>│                    │
    │                      │   (inbound message)  │                    │
    │                      │                      ├──3. Add to Opt-Out>│
    │                      │                      │   (phone number)   │
    │                      │<──4. Confirmation────┤                    │
    │<──5. "You're opted──┤   ("You've been      │                    │
    │    out" message      │    removed...")      │                    │
```

### Webhook Handling for Delivery Tracking

**Twilio Status Callbacks**:

```
Twilio                                SMS Service
   │                                        │
   ├──1. Message Queued──────────────────────>│
   │   POST /webhooks/twilio                 │
   │   {status: "queued"}                    │
   │                                         ├──2. Update DB
   │                                         │   (status = 'queued')
   ├──3. Message Sent────────────────────────>│
   │   {status: "sent"}                      │
   │                                         ├──4. Update DB
   │                                         │   (status = 'sent')
   ├──5. Message Delivered───────────────────>│
   │   {status: "delivered"}                 │
   │                                         ├──6. Update DB
   │                                         │   (delivered_at = NOW())
   ├──7. Message Failed──────────────────────>│
   │   {status: "failed", error: "..."}      │
   │                                         ├──8. Update DB + Alert
   │                                         │   (status = 'failed')
```

---

## API Endpoints

### 1. Send SMS

```http
POST /send-sms HTTP/1.1
Host: localhost:3004
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "phoneNumber": "+12025551234",
  "message": "Your order #ORD-999 has shipped! Track: https://track.example.com/ORD-999",
  "userId": "user-12345"
}

HTTP/1.1 202 Accepted
Content-Type: application/json

{
  "messageId": "sms-abc123",
  "status": "queued",
  "phoneNumber": "+12025551234",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Rate Limit Response** (429):

```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many messages to this number. Try again in 1 second.",
  "retryAfter": 1
}
```

### 2. Send Batch SMS

```http
POST /send-batch HTTP/1.1
Host: localhost:3004
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "messages": [
    {
      "phoneNumber": "+12025551234",
      "message": "Flash sale! 50% off for 2 hours.",
      "userId": "user-12345"
    },
    {
      "phoneNumber": "+14155551234",
      "message": "Flash sale! 50% off for 2 hours.",
      "userId": "user-67890"
    }
  ]
}

HTTP/1.1 202 Accepted
Content-Type: application/json

{
  "batchId": "batch-xyz789",
  "totalMessages": 2,
  "status": "processing",
  "estimatedCompletion": "2025-11-24T13:46:00Z"
}
```

### 3. Twilio Delivery Webhook

```http
POST /webhooks/twilio HTTP/1.1
Host: localhost:3004
Content-Type: application/x-www-form-urlencoded
X-Twilio-Signature: <HMAC-SHA1-signature>

MessageSid=SM1234567890abcdef&
MessageStatus=delivered&
To=%2B12025551234&
From=%2B14155551234&
Body=Your+order+has+shipped&
AccountSid=AC1234567890abcdef

HTTP/1.1 200 OK
```

**Status Values**:
- `queued` - Message accepted by Twilio
- `sent` - Sent to carrier
- `delivered` - Delivered to recipient
- `failed` - Delivery failed (invalid number, carrier issue)
- `undelivered` - Could not deliver (out of service, etc.)

### 4. Opt-Out Status Check

```http
GET /opt-out-status/+12025551234 HTTP/1.1
Host: localhost:3004
Authorization: Bearer <API_KEY>

HTTP/1.1 200 OK
Content-Type: application/json

{
  "phoneNumber": "+12025551234",
  "isOptedOut": false,
  "optedOutAt": null
}
```

**If opted out**:

```json
{
  "phoneNumber": "+12025551234",
  "isOptedOut": true,
  "optedOutAt": "2025-11-20T10:30:00Z",
  "reason": "User replied STOP"
}
```

---

## Twilio Integration

### Twilio API Setup

```javascript
const twilio = require('twilio');

// Initialize Twilio client
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;
```

### SMS Payload Format

```javascript
const smsPayload = {
  body: 'Your order #ORD-999 has shipped! Track: https://track.example.com/ORD-999',
  from: twilioPhoneNumber, // Your Twilio number (e.g., +14155551234)
  to: '+12025551234', // Recipient number (E.164 format)
  statusCallback: `${process.env.BASE_URL}/webhooks/twilio`, // Delivery tracking
  maxPrice: 0.05 // Max price in USD (prevent expensive routes)
};
```

### Sending SMS via Twilio

```javascript
async function sendSMSViaTwilio(phoneNumber, message, metadata = {}) {
  try {
    // 1. Validate phone number
    const validatedPhone = validateAndFormatPhone(phoneNumber);

    // 2. Check opt-out status
    const isOptedOut = await checkOptOutStatus(validatedPhone);
    if (isOptedOut) {
      logger.warn('Phone number opted out', { phoneNumber: maskPhone(validatedPhone) });
      return {
        status: 'opted_out',
        message: 'Recipient has opted out of SMS notifications'
      };
    }

    // 3. Check rate limit
    const rateLimitOk = await checkRateLimit(validatedPhone);
    if (!rateLimitOk) {
      throw new Error('RATE_LIMIT_EXCEEDED');
    }

    // 4. Send via Twilio
    const twilioMessage = await twilioClient.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: validatedPhone,
      statusCallback: `${process.env.BASE_URL}/webhooks/twilio`,
      maxPrice: parseFloat(process.env.TWILIO_MAX_PRICE) || 0.05
    });

    logger.info('SMS sent via Twilio', {
      messageSid: twilioMessage.sid,
      to: maskPhone(validatedPhone),
      status: twilioMessage.status
    });

    // 5. Record in database
    await recordSMS({
      messageId: twilioMessage.sid,
      phoneNumber: validatedPhone,
      message: message,
      status: twilioMessage.status,
      userId: metadata.userId
    });

    return {
      status: 'sent',
      messageId: twilioMessage.sid,
      twilioStatus: twilioMessage.status
    };
  } catch (error) {
    logger.error('Twilio SMS send failed', {
      error: error.message,
      code: error.code,
      phoneNumber: maskPhone(phoneNumber)
    });

    throw error;
  }
}
```

### Twilio Error Handling

**Common Twilio Error Codes**:

```javascript
const twilioErrorHandlers = {
  21211: (error) => {
    // Invalid phone number
    logger.error('Invalid phone number', { error: error.message });
    return { status: 'invalid_phone', shouldRetry: false };
  },
  21408: (error) => {
    // Permission denied (Twilio account issue)
    logger.error('Twilio permission denied', { error: error.message });
    sendAlert('twilio_permission_error', { message: error.message });
    return { status: 'permission_denied', shouldRetry: false };
  },
  21606: (error) => {
    // Phone number is not verified (sandbox mode)
    logger.warn('Phone number not verified', { error: error.message });
    return { status: 'unverified_number', shouldRetry: false };
  },
  21610: (error) => {
    // Phone number opted out
    logger.info('Phone number opted out', { error: error.message });
    return { status: 'opted_out', shouldRetry: false };
  },
  20003: (error) => {
    // Authentication error
    logger.error('Twilio auth failed', { error: error.message });
    sendAlert('twilio_auth_failure', { message: 'Check credentials' });
    return { status: 'auth_failed', shouldRetry: false };
  },
  default: (error) => {
    logger.error('Twilio unknown error', { error: error.message, code: error.code });
    return { status: 'failed', shouldRetry: true };
  }
};

async function handleTwilioError(error, phoneNumber) {
  const handler = twilioErrorHandlers[error.code] || twilioErrorHandlers.default;
  const result = handler(error);

  if (!result.shouldRetry) {
    await recordSMSFailure(phoneNumber, error.code, error.message);
  }

  return result;
}
```

---

## Phone Number Validation

### E.164 Format Validation

**E.164 Format**: `+[country code][subscriber number]`
- Example: `+12025551234` (US), `+447911123456` (UK)

```javascript
const { parsePhoneNumber, isValidPhoneNumber } = require('libphonenumber-js');

function validateAndFormatPhone(phoneNumber, defaultCountry = 'US') {
  try {
    // Parse phone number
    const parsed = parsePhoneNumber(phoneNumber, defaultCountry);

    if (!parsed) {
      throw new Error('INVALID_PHONE_NUMBER');
    }

    // Check if valid
    if (!parsed.isValid()) {
      throw new Error('INVALID_PHONE_NUMBER');
    }

    // Format to E.164
    const e164 = parsed.format('E.164');

    logger.debug('Phone number validated', {
      input: phoneNumber,
      formatted: e164,
      country: parsed.country,
      type: parsed.getType() // 'MOBILE', 'FIXED_LINE', etc.
    });

    return e164;
  } catch (error) {
    logger.error('Phone validation failed', {
      phoneNumber,
      error: error.message
    });

    throw new Error('INVALID_PHONE_NUMBER');
  }
}
```

### Country Code Detection

```javascript
function detectCountryCode(phoneNumber) {
  try {
    const parsed = parsePhoneNumber(phoneNumber);
    return parsed ? parsed.country : null;
  } catch {
    return null;
  }
}

// Example usage
const country = detectCountryCode('+12025551234'); // 'US'
const country2 = detectCountryCode('+447911123456'); // 'GB'
```

### Invalid Number Handling

```javascript
async function validatePhoneOrReject(phoneNumber) {
  try {
    return validateAndFormatPhone(phoneNumber);
  } catch (error) {
    // Log invalid attempt
    await logInvalidPhoneAttempt(phoneNumber);

    // Track metric
    await incrementMetric('sms_invalid_phone_total');

    throw {
      code: 'INVALID_PHONE_NUMBER',
      message: 'Phone number must be in E.164 format (e.g., +12025551234)',
      example: '+12025551234'
    };
  }
}

// Use in API endpoint
app.post('/send-sms', async (req, res) => {
  try {
    const validatedPhone = await validatePhoneOrReject(req.body.phoneNumber);

    // Continue with sending...
  } catch (error) {
    if (error.code === 'INVALID_PHONE_NUMBER') {
      return res.status(400).json({ error });
    }
    throw error;
  }
});
```

### Phone Number Normalization

```javascript
function normalizePhoneNumber(phoneNumber, defaultCountry = 'US') {
  // Handle various input formats
  const formats = [
    phoneNumber, // As-is
    phoneNumber.replace(/\D/g, ''), // Remove non-digits
    `+1${phoneNumber.replace(/\D/g, '')}`, // Assume US if no country code
    phoneNumber.replace(/^00/, '+') // Replace 00 prefix with +
  ];

  for (const format of formats) {
    try {
      const validated = validateAndFormatPhone(format, defaultCountry);
      return validated;
    } catch {
      continue;
    }
  }

  throw new Error('INVALID_PHONE_NUMBER');
}

// Examples
normalizePhoneNumber('2025551234'); // '+12025551234'
normalizePhoneNumber('(202) 555-1234'); // '+12025551234'
normalizePhoneNumber('001442071838750'); // '+442071838750'
```

---

## Rate Limiting

### Carrier Restrictions

**US Carrier Limits**:
- Max 1 message per second per recipient number
- Exceeding may result in filtering or blocking

**Implementation**:

```javascript
const Redis = require('ioredis');
const redis = new Redis(process.env.REDIS_URL);

async function checkRateLimit(phoneNumber) {
  const key = `sms:ratelimit:phone:${phoneNumber}`;

  // Check if key exists (message sent recently)
  const exists = await redis.exists(key);

  if (exists) {
    logger.warn('Rate limit exceeded for phone number', {
      phoneNumber: maskPhone(phoneNumber)
    });

    return false;
  }

  // Set key with 1-second expiration
  await redis.setex(key, 1, '1');

  return true;
}
```

### Queue Throttling

**Bull Queue with Rate Limiting**:

```javascript
const Queue = require('bull');

const smsQueue = new Queue('sms-notifications', {
  redis: process.env.REDIS_URL,
  limiter: {
    max: 100, // Max 100 SMS per duration
    duration: 1000 // Per second (global limit)
  },
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000
    }
  }
});

// Process with concurrency limit
smsQueue.process(10, async (job) => {
  const { phoneNumber, message, userId } = job.data;

  // Per-phone rate limiting
  const rateLimitOk = await checkRateLimit(phoneNumber);
  if (!rateLimitOk) {
    // Retry after 1 second
    throw new Error('RATE_LIMIT_EXCEEDED');
  }

  return await sendSMSViaTwilio(phoneNumber, message, { userId });
});
```

### Redis-Based Rate Limit Tracking

**Multi-Tier Rate Limiting**:

```javascript
async function checkAllRateLimits(phoneNumber, userId) {
  const checks = [
    { key: `sms:ratelimit:phone:${phoneNumber}`, limit: 1, window: 1, name: 'per-phone' },
    { key: `sms:ratelimit:user:${userId}`, limit: 10, window: 60, name: 'per-user' },
    { key: `sms:ratelimit:global`, limit: 100, window: 1, name: 'global' }
  ];

  for (const check of checks) {
    const count = await redis.incr(check.key);

    if (count === 1) {
      // First increment, set expiration
      await redis.expire(check.key, check.window);
    }

    if (count > check.limit) {
      logger.warn('Rate limit exceeded', {
        type: check.name,
        limit: check.limit,
        window: check.window,
        phoneNumber: maskPhone(phoneNumber),
        userId
      });

      const ttl = await redis.ttl(check.key);

      throw {
        code: 'RATE_LIMIT_EXCEEDED',
        message: `Rate limit exceeded (${check.name})`,
        retryAfter: ttl
      };
    }
  }

  return true;
}
```

### Burst Handling Strategies

**Smooth Burst Handling**:

```javascript
const { RateLimiterRedis } = require('rate-limiter-flexible');

const rateLimiter = new RateLimiterRedis({
  storeClient: redis,
  points: 10, // Allow 10 messages
  duration: 60, // Per 60 seconds
  blockDuration: 60, // Block for 60s if exceeded
  keyPrefix: 'sms:ratelimit:user'
});

async function checkRateLimitWithBurst(userId) {
  try {
    await rateLimiter.consume(userId, 1); // Consume 1 point
    return true;
  } catch (rejRes) {
    logger.warn('Rate limit exceeded with burst', {
      userId,
      remainingPoints: rejRes.remainingPoints,
      retryAfter: Math.ceil(rejRes.msBeforeNext / 1000)
    });

    throw {
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: Math.ceil(rejRes.msBeforeNext / 1000)
    };
  }
}
```

---

## Opt-Out Management

### STOP/START Command Handling

**Inbound Webhook Handler**:

```javascript
app.post('/webhooks/twilio', async (req, res) => {
  // Verify Twilio signature
  const twilioSignature = req.headers['x-twilio-signature'];
  const isValid = twilio.validateRequest(
    process.env.TWILIO_AUTH_TOKEN,
    twilioSignature,
    `${process.env.BASE_URL}/webhooks/twilio`,
    req.body
  );

  if (!isValid) {
    logger.error('Invalid Twilio webhook signature');
    return res.status(403).send('Forbidden');
  }

  const { From, Body, MessageSid, MessageStatus } = req.body;

  // Handle delivery status updates
  if (MessageStatus) {
    await updateSMSStatus(MessageSid, MessageStatus);
    return res.status(200).send();
  }

  // Handle inbound messages (opt-out commands)
  if (Body) {
    const command = Body.trim().toUpperCase();

    if (command === 'STOP' || command === 'UNSUBSCRIBE') {
      await handleOptOut(From, 'STOP command');

      // Send confirmation (required by TCPA)
      await twilioClient.messages.create({
        body: 'You have been unsubscribed from SMS notifications. Reply START to re-subscribe.',
        from: twilioPhoneNumber,
        to: From
      });

      logger.info('Opt-out processed', { phoneNumber: maskPhone(From) });
    } else if (command === 'START' || command === 'SUBSCRIBE') {
      await handleOptIn(From);

      // Send confirmation
      await twilioClient.messages.create({
        body: 'You have been re-subscribed to SMS notifications. Reply STOP to unsubscribe.',
        from: twilioPhoneNumber,
        to: From
      });

      logger.info('Opt-in processed', { phoneNumber: maskPhone(From) });
    }
  }

  res.status(200).send();
});
```

### Opt-Out Database Schema

```sql
CREATE TABLE sms_opt_outs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(20) NOT NULL UNIQUE,
  opted_out_at TIMESTAMPTZ DEFAULT NOW(),
  reason VARCHAR(100), -- 'STOP command', 'Manual request', etc.
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sms_opt_outs_phone ON sms_opt_outs(phone_number);

-- Track opt-in history (for auditing)
CREATE TABLE sms_opt_out_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(20) NOT NULL,
  action VARCHAR(20) NOT NULL, -- 'opt_out' or 'opt_in'
  reason VARCHAR(100),
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

### Opt-Out Database Operations

```javascript
async function handleOptOut(phoneNumber, reason = 'STOP command') {
  const query = `
    INSERT INTO sms_opt_outs (phone_number, reason)
    VALUES ($1, $2)
    ON CONFLICT (phone_number) DO UPDATE SET
      opted_out_at = NOW(),
      reason = EXCLUDED.reason
  `;

  await db.query(query, [phoneNumber, reason]);

  // Record in history
  await db.query(
    `INSERT INTO sms_opt_out_history (phone_number, action, reason) VALUES ($1, $2, $3)`,
    [phoneNumber, 'opt_out', reason]
  );

  logger.info('Phone number opted out', {
    phoneNumber: maskPhone(phoneNumber),
    reason
  });
}

async function handleOptIn(phoneNumber) {
  const query = `DELETE FROM sms_opt_outs WHERE phone_number = $1`;

  await db.query(query, [phoneNumber]);

  // Record in history
  await db.query(
    `INSERT INTO sms_opt_out_history (phone_number, action) VALUES ($1, $2)`,
    [phoneNumber, 'opt_in']
  );

  logger.info('Phone number opted in', {
    phoneNumber: maskPhone(phoneNumber)
  });
}

async function checkOptOutStatus(phoneNumber) {
  const query = `SELECT 1 FROM sms_opt_outs WHERE phone_number = $1`;
  const result = await db.query(query, [phoneNumber]);

  return result.rows.length > 0;
}
```

### Webhook Processing

**Delivery Status Webhook**:

```javascript
async function updateSMSStatus(messageSid, status) {
  const statusMap = {
    queued: 'queued',
    sent: 'sent',
    delivered: 'delivered',
    failed: 'failed',
    undelivered: 'failed'
  };

  const mappedStatus = statusMap[status] || status;

  const query = `
    UPDATE notifications
    SET status = $1, updated_at = NOW()
    WHERE id = (SELECT id FROM notifications WHERE id = $2 AND channel = 'sms')
  `;

  await db.query(query, [mappedStatus, messageSid]);

  // If delivered, record timestamp
  if (status === 'delivered') {
    await db.query(
      `UPDATE notifications SET delivered_at = NOW() WHERE id = $1`,
      [messageSid]
    );
  }

  logger.info('SMS status updated', {
    messageSid,
    status: mappedStatus
  });
}
```

### Compliance Requirements (TCPA, CTIA)

**TCPA (Telephone Consumer Protection Act)**:
- Must obtain prior express consent before sending marketing SMS
- Must honor opt-out requests immediately
- Must identify sender in message

**CTIA (Cellular Telecommunications Industry Association)**:
- Support STOP, UNSTOP, HELP keywords
- Respond to STOP within 24 hours (ideally immediately)
- Keep opt-out records for at least 5 years

**Implementation**:

```javascript
// Include sender identification in messages
function formatMessage(message) {
  const senderName = process.env.SMS_SENDER_NAME || 'Example Store';
  return `${senderName}: ${message}`;
}

// Auto-respond to HELP keyword
if (command === 'HELP') {
  await twilioClient.messages.create({
    body: `Example Store SMS help: Reply STOP to unsubscribe. Msg&data rates may apply. Contact support@example.com for help.`,
    from: twilioPhoneNumber,
    to: From
  });
}

// Keep audit trail (opt-out history table serves this purpose)
```

---

## Error Handling

### Invalid Phone Numbers

```javascript
app.post('/send-sms', async (req, res) => {
  try {
    const validatedPhone = validateAndFormatPhone(req.body.phoneNumber);

    // Continue with sending...
  } catch (error) {
    return res.status(400).json({
      error: 'INVALID_PHONE_NUMBER',
      message: 'Phone number must be in E.164 format',
      example: '+12025551234',
      provided: req.body.phoneNumber
    });
  }
});
```

### Delivery Failures

```javascript
async function handleDeliveryFailure(messageSid, errorCode, errorMessage) {
  logger.error('SMS delivery failed', {
    messageSid,
    errorCode,
    errorMessage
  });

  // Update status in database
  await db.query(
    `UPDATE notifications SET status = $1, error_message = $2 WHERE id = $3`,
    ['failed', errorMessage, messageSid]
  );

  // Track failure metric
  await incrementMetric('sms_delivery_failed_total', {
    errorCode
  });

  // Alert if failure rate exceeds threshold
  const failureRate = await calculateSMSFailureRate('1 hour');
  if (failureRate > 5) {
    await sendAlert('high_sms_failure_rate', {
      rate: failureRate,
      recentError: errorMessage
    });
  }
}
```

### Twilio API Errors

**See Twilio Error Handling section above for comprehensive error handling**

### Retry Strategies

```javascript
const smsRetryConfig = {
  maxAttempts: 3,
  backoff: 'exponential', // 2s, 4s, 8s
  retryableErrors: [
    'ETIMEDOUT',
    'ECONNRESET',
    '503', // Service unavailable
    '429' // Rate limit (should be handled separately)
  ],
  nonRetryableErrors: [
    '21211', // Invalid phone number
    '21610', // Phone number opted out
    '400' // Bad request
  ]
};

async function sendSMSWithRetry(phoneNumber, message, attempt = 1) {
  try {
    return await sendSMSViaTwilio(phoneNumber, message);
  } catch (error) {
    const isRetryable = smsRetryConfig.retryableErrors.includes(error.code);
    const maxAttempts = smsRetryConfig.maxAttempts;

    if (isRetryable && attempt < maxAttempts) {
      const delay = Math.pow(2, attempt) * 1000; // Exponential backoff

      logger.info('Retrying SMS send', {
        attempt,
        maxAttempts,
        delay,
        error: error.message
      });

      await sleep(delay);
      return sendSMSWithRetry(phoneNumber, message, attempt + 1);
    }

    throw error;
  }
}
```

---

## Configuration

### Environment Variables

```bash
# Server
SMS_SERVICE_PORT=3004
NODE_ENV=production

# Twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+14155551234
TWILIO_MAX_PRICE=0.05  # Max price per SMS (USD)

# Sender Identification
SMS_SENDER_NAME="Example Store"

# Webhooks
BASE_URL=https://api.example.com
TWILIO_WEBHOOK_URL=https://api.example.com/webhooks/twilio

# Rate Limiting
SMS_RATE_LIMIT_PER_PHONE=1  # Per second
SMS_RATE_LIMIT_PER_USER=10  # Per minute
SMS_RATE_LIMIT_GLOBAL=100   # Per second

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/notifications

# Redis
REDIS_URL=redis://localhost:6379

# Compliance
SMS_OPT_OUT_RETENTION_YEARS=5
```

### Rate Limit Settings

```javascript
const rateLimitConfig = {
  perPhone: {
    limit: parseInt(process.env.SMS_RATE_LIMIT_PER_PHONE) || 1,
    window: 1 // seconds
  },
  perUser: {
    limit: parseInt(process.env.SMS_RATE_LIMIT_PER_USER) || 10,
    window: 60 // seconds
  },
  global: {
    limit: parseInt(process.env.SMS_RATE_LIMIT_GLOBAL) || 100,
    window: 1 // seconds
  }
};
```

### Opt-Out Webhook URL

**Configure in Twilio Console**:
1. Go to Phone Numbers → Manage → Active Numbers
2. Select your number
3. Under "Messaging", set:
   - **A message comes in**: Webhook → `https://api.example.com/webhooks/twilio`
   - **HTTP Method**: POST

---

## Testing & Monitoring

### Twilio Sandbox Testing

**Use Twilio Test Credentials** (for development):

```bash
# Test credentials (from Twilio Console)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Test account
TWILIO_AUTH_TOKEN=test_auth_token
TWILIO_PHONE_NUMBER=+15005550006  # Magic test number
```

**Twilio Magic Numbers** (for testing):
- `+15005550006` - Valid test number (always succeeds)
- `+15005550001` - Invalid number (error 21211)
- `+15005550007` - Number without SMS capability (error 21606)

### Delivery Rate Tracking

```javascript
async function calculateSMSMetrics(timeRange = '24 hours') {
  const query = `
    SELECT
      COUNT(*) FILTER (WHERE status = 'sent') as sent,
      COUNT(*) FILTER (WHERE status = 'delivered') as delivered,
      COUNT(*) FILTER (WHERE status = 'failed') as failed,
      COUNT(*) as total
    FROM notifications
    WHERE channel = 'sms' AND created_at > NOW() - INTERVAL '${timeRange}'
  `;

  const result = await db.query(query);
  const metrics = result.rows[0];

  metrics.deliveryRate = (metrics.delivered / metrics.sent) * 100;
  metrics.failureRate = (metrics.failed / metrics.total) * 100;

  return metrics;
}

// Expose metrics endpoint
app.get('/metrics/sms', async (req, res) => {
  const metrics = await calculateSMSMetrics();
  res.json(metrics);
});
```

### Cost Tracking

```javascript
async function calculateSMSCosts(timeRange = '24 hours') {
  // Twilio pricing (varies by country)
  const pricing = {
    US: 0.0079, // $0.0079 per SMS
    CA: 0.0075,
    GB: 0.04,
    default: 0.01
  };

  const query = `
    SELECT
      SUBSTRING(phone_number FROM 1 FOR 3) as country_code,
      COUNT(*) as count
    FROM notifications
    WHERE channel = 'sms' AND status = 'sent' AND created_at > NOW() - INTERVAL '${timeRange}'
    GROUP BY country_code
  `;

  const result = await db.query(query);

  let totalCost = 0;

  for (const row of result.rows) {
    const country = detectCountryFromCode(row.country_code);
    const pricePerSMS = pricing[country] || pricing.default;
    totalCost += row.count * pricePerSMS;
  }

  return {
    totalSMS: result.rows.reduce((sum, r) => sum + parseInt(r.count), 0),
    estimatedCost: totalCost.toFixed(4),
    currency: 'USD'
  };
}
```

### Opt-Out Compliance Monitoring

```javascript
async function monitorOptOutCompliance() {
  // Check opt-out response time (should be < 24 hours, ideally immediate)
  const query = `
    SELECT
      phone_number,
      opted_out_at,
      (SELECT MAX(timestamp) FROM sms_opt_out_history
       WHERE phone_number = sms_opt_outs.phone_number AND action = 'opt_out') as request_time
    FROM sms_opt_outs
    WHERE opted_out_at > NOW() - INTERVAL '7 days'
  `;

  const result = await db.query(query);

  const violations = result.rows.filter(row => {
    const responseTime = row.opted_out_at - row.request_time;
    return responseTime > 24 * 60 * 60 * 1000; // 24 hours
  });

  if (violations.length > 0) {
    await sendAlert('opt_out_compliance_violation', {
      count: violations.length,
      phoneNumbers: violations.map(v => maskPhone(v.phone_number))
    });
  }

  return {
    totalOptOuts: result.rows.length,
    complianceViolations: violations.length
  };
}
```

**Key Metrics**:
- `sms_sent_total` - Total SMS sent
- `sms_delivered_total` - Total SMS delivered
- `sms_delivery_rate` - Delivery success rate %
- `sms_failed_total` - Total failed SMS
- `sms_opted_out_total` - Total opt-outs
- `sms_cost_usd` - Estimated cost
