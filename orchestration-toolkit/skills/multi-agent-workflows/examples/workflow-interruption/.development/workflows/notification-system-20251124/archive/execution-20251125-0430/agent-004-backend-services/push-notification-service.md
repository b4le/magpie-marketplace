# Push Notification Service

## Service Overview

**Purpose**: Send mobile push notifications to Android (via Firebase Cloud Messaging) and iOS (via Apple Push Notification service) devices

**Use Cases**:
- Order confirmations and status updates
- Promotional offers and announcements
- Inventory alerts (back in stock, price drops)
- Engagement reminders (abandoned cart, review requests)

**Technology Stack**:
- Node.js 20+
- Express.js 4.18+
- Firebase Admin SDK (for FCM/Android)
- node-apn 2.x (for APNs/iOS)
- PostgreSQL (device token storage)
- RabbitMQ (async notification queue)

**Port**: 3002

---

## Architecture

### Multi-Platform Notification Flow

```
Notification API                    Push Service
       │                                 │
       ├──1. Publish to queue────────────>│
       │   (user_id, message, data)       │
       │                                  │
       │                              ┌───▼────┐
       │                              │ Device │
       │                              │ Lookup │
       │                              │  (DB)  │
       │                              └───┬────┘
       │                                  │
       │                           ┌──────┴──────┐
       │                           │             │
       │                        ┌──▼──┐      ┌──▼───┐
       │                        │ FCM │      │ APNs │
       │                        │ SDK │      │ SDK  │
       │                        └──┬──┘      └──┬───┘
       │                           │            │
       ▼                           ▼            ▼
   ┌────────┐              ┌────────────┐  ┌────────────┐
   │ Queue  │              │   FCM      │  │   APNs     │
   │ (Next) │              │  (Google)  │  │  (Apple)   │
   └────────┘              └─────┬──────┘  └──────┬─────┘
                                 │                │
                                 ▼                ▼
                            ┌─────────┐      ┌─────────┐
                            │ Android │      │   iOS   │
                            │ Devices │      │ Devices │
                            └─────────┘      └─────────┘
```

### Device Token Registration Process

```
Mobile App                 Push Service              Database
    │                           │                        │
    ├──1. Register Token────────>│                        │
    │   {token, platform, userId} │                      │
    │                             ├──2. Validate Token───>│
    │                             │   (check duplicates)  │
    │                             │<──3. Existing?────────┤
    │                             │                       │
    │                             ├──4. Store Token───────>│
    │                             │   (upsert)            │
    │<──5. Registration Success───┤                       │
    │                             │                       │
```

### Platform Detection Strategy

**Automatic detection from token format**:
- FCM tokens: 152+ characters, alphanumeric with colons/underscores
- APNs tokens: 64 hex characters

```javascript
function detectPlatform(token) {
  if (/^[a-f0-9]{64}$/i.test(token)) {
    return 'ios';
  } else if (token.length > 140 && /[A-Za-z0-9_:-]+/.test(token)) {
    return 'android';
  }
  throw new Error('INVALID_TOKEN_FORMAT');
}
```

### Notification Priority Levels

| Priority | FCM | APNs | Behavior |
|----------|-----|------|----------|
| `high` | `high` | 10 | Immediate delivery, may wake device |
| `normal` | `normal` | 5 | Deferred delivery, batched |
| `low` | `low` | 5 | Low power, may be throttled |

---

## API Endpoints

### 1. Register Device

```http
POST /register-device HTTP/1.1
Host: localhost:3002
Content-Type: application/json
Authorization: Bearer <JWT>

{
  "deviceToken": "fT4gH...kL9p",
  "platform": "android",
  "userId": "user-12345",
  "appVersion": "2.1.0",
  "osVersion": "Android 13"
}

HTTP/1.1 201 Created
Content-Type: application/json

{
  "deviceId": "device-abc123",
  "userId": "user-12345",
  "platform": "android",
  "registeredAt": "2025-11-24T13:45:00Z"
}
```

**Validation**:
- Token format validation (platform-specific)
- User authentication (JWT)
- Platform must be `android` or `ios`

### 2. Send Notification

```http
POST /send-notification HTTP/1.1
Host: localhost:3002
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "userId": "user-12345",
  "title": "Order Confirmed",
  "body": "Your order #ORD-999 has been confirmed",
  "data": {
    "orderId": "ORD-999",
    "type": "order-confirmation"
  },
  "priority": "high",
  "badge": 1,
  "sound": "default"
}

HTTP/1.1 200 OK
Content-Type: application/json

{
  "notificationId": "notif-xyz789",
  "userId": "user-12345",
  "devicesNotified": 2,
  "results": [
    {
      "deviceId": "device-abc123",
      "platform": "android",
      "status": "sent",
      "messageId": "fcm-msg-123"
    },
    {
      "deviceId": "device-def456",
      "platform": "ios",
      "status": "sent",
      "messageId": "apns-msg-456"
    }
  ],
  "timestamp": "2025-11-24T13:45:00Z"
}
```

### 3. Send Batch Notification

```http
POST /send-batch HTTP/1.1
Host: localhost:3002
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "userIds": ["user-12345", "user-67890", "user-11111"],
  "title": "Flash Sale!",
  "body": "50% off all items for the next 2 hours",
  "data": {
    "type": "promotional",
    "saleId": "sale-black-friday"
  },
  "priority": "normal"
}

HTTP/1.1 202 Accepted
Content-Type: application/json

{
  "batchId": "batch-xyz789",
  "totalUsers": 3,
  "status": "processing",
  "estimatedCompletion": "2025-11-24T13:50:00Z"
}
```

### 4. Unregister Device

```http
DELETE /unregister-device HTTP/1.1
Host: localhost:3002
Content-Type: application/json
Authorization: Bearer <JWT>

{
  "deviceToken": "fT4gH...kL9p",
  "userId": "user-12345"
}

HTTP/1.1 204 No Content
```

---

## FCM Integration (Android)

### FCM Payload Format

```javascript
const fcmPayload = {
  notification: {
    title: 'Order Confirmed',
    body: 'Your order #ORD-999 has been confirmed'
  },
  data: {
    orderId: 'ORD-999',
    type: 'order-confirmation',
    clickAction: 'ORDER_DETAILS'
  },
  android: {
    priority: 'high', // 'high' or 'normal'
    notification: {
      channelId: 'order-updates', // Must match app's notification channel
      sound: 'default',
      tag: 'order-ORD-999', // Groups notifications
      color: '#FF5722', // Notification color
      icon: 'ic_notification' // Custom icon
    }
  },
  token: 'fT4gH...kL9p' // FCM device token
};
```

### FCM SDK Initialization

```javascript
const admin = require('firebase-admin');

// Initialize with service account
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FCM_PROJECT_ID,
    clientEmail: process.env.FCM_CLIENT_EMAIL,
    privateKey: process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n')
  })
});

const messaging = admin.messaging();
```

### Sending FCM Notifications

```javascript
async function sendFCMNotification(deviceToken, notification) {
  try {
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data || {},
      android: {
        priority: notification.priority || 'normal',
        notification: {
          channelId: notification.channelId || 'default',
          sound: notification.sound || 'default',
          color: notification.color || '#FF5722'
        }
      },
      token: deviceToken
    };

    const response = await messaging.send(message);

    logger.info('FCM notification sent', {
      messageId: response,
      deviceToken: maskToken(deviceToken),
      title: notification.title
    });

    return {
      status: 'sent',
      messageId: response,
      platform: 'android'
    };
  } catch (error) {
    logger.error('FCM send failed', {
      error: error.message,
      code: error.code,
      deviceToken: maskToken(deviceToken)
    });

    // Handle specific FCM errors
    if (error.code === 'messaging/invalid-registration-token') {
      await removeInvalidToken(deviceToken);
      return { status: 'invalid_token', error: 'Token removed' };
    }

    return { status: 'failed', error: error.message };
  }
}
```

### Android-Specific Notification Options

**Notification Channels** (Android 8.0+):
```javascript
const channelConfig = {
  'order-updates': {
    name: 'Order Updates',
    description: 'Notifications about order status',
    importance: 'high', // Shows as heads-up notification
    sound: 'default',
    vibration: true
  },
  'promotions': {
    name: 'Promotions',
    description: 'Deals and offers',
    importance: 'normal',
    sound: 'gentle',
    vibration: false
  }
};
```

**Priority and Delivery**:
- `high`: Immediate delivery, may wake device, shows heads-up
- `normal`: Standard delivery, batched with other notifications

---

## APNs Integration (iOS)

### APNs Payload Format

```javascript
const apnsPayload = {
  aps: {
    alert: {
      title: 'Order Confirmed',
      body: 'Your order #ORD-999 has been confirmed'
    },
    badge: 1, // App icon badge count
    sound: 'default', // or custom sound file
    'content-available': 1, // For background updates
    category: 'ORDER_CONFIRMATION', // For action buttons
    'thread-id': 'order-ORD-999' // Groups notifications
  },
  orderId: 'ORD-999', // Custom data
  type: 'order-confirmation'
};
```

### APNs Certificate/Key Configuration

**Using .p8 key (recommended)**:

```javascript
const apn = require('apn');

const apnProvider = new apn.Provider({
  token: {
    key: process.env.APNS_KEY_PATH, // Path to .p8 file
    keyId: process.env.APNS_KEY_ID,
    teamId: process.env.APNS_TEAM_ID
  },
  production: process.env.NODE_ENV === 'production' // true for prod, false for sandbox
});
```

**Using .p12 certificate** (legacy):

```javascript
const apnProvider = new apn.Provider({
  cert: process.env.APNS_CERT_PATH, // Path to .p12 file
  key: process.env.APNS_KEY_PATH,
  passphrase: process.env.APNS_CERT_PASSPHRASE,
  production: process.env.NODE_ENV === 'production'
});
```

### Sending APNs Notifications

```javascript
async function sendAPNsNotification(deviceToken, notification) {
  try {
    const apnNotification = new apn.Notification({
      alert: {
        title: notification.title,
        body: notification.body
      },
      badge: notification.badge || 0,
      sound: notification.sound || 'default',
      category: notification.category,
      threadId: notification.threadId,
      contentAvailable: notification.contentAvailable || false,
      mutableContent: notification.mutableContent || false,
      topic: process.env.APNS_BUNDLE_ID, // e.g., com.example.app
      priority: notification.priority === 'high' ? 10 : 5,
      expiry: Math.floor(Date.now() / 1000) + 3600, // Expire after 1 hour
      payload: notification.data || {}
    });

    const result = await apnProvider.send(apnNotification, deviceToken);

    if (result.sent.length > 0) {
      logger.info('APNs notification sent', {
        deviceToken: maskToken(deviceToken),
        title: notification.title
      });

      return {
        status: 'sent',
        messageId: result.sent[0].device,
        platform: 'ios'
      };
    } else if (result.failed.length > 0) {
      const failure = result.failed[0];
      logger.error('APNs send failed', {
        error: failure.response.reason,
        status: failure.status,
        deviceToken: maskToken(deviceToken)
      });

      // Handle specific APNs errors
      if (failure.response.reason === 'BadDeviceToken') {
        await removeInvalidToken(deviceToken);
        return { status: 'invalid_token', error: 'Token removed' };
      }

      return { status: 'failed', error: failure.response.reason };
    }
  } catch (error) {
    logger.error('APNs send exception', {
      error: error.message,
      deviceToken: maskToken(deviceToken)
    });

    return { status: 'failed', error: error.message };
  }
}
```

### iOS-Specific Notification Options

**Action Buttons** (Categories):

```javascript
// Define on iOS app side, triggered by category
const categoryConfig = {
  'ORDER_CONFIRMATION': {
    actions: [
      { id: 'VIEW', title: 'View Order' },
      { id: 'TRACK', title: 'Track Package' }
    ]
  }
};

// APNs payload
const notification = {
  aps: {
    category: 'ORDER_CONFIRMATION', // Triggers action buttons
    alert: { title: 'Order Shipped', body: 'Track your package' }
  }
};
```

**Rich Notifications** (Images, Videos):

```javascript
const notification = {
  aps: {
    alert: { title: 'New Product', body: 'Check out our latest item' },
    'mutable-content': 1 // Enables notification service extension
  },
  imageUrl: 'https://cdn.example.com/product.jpg' // Processed by app extension
};
```

---

## Device Token Management

### Database Schema

```sql
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  device_token TEXT NOT NULL UNIQUE,
  platform VARCHAR(10) NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version VARCHAR(20),
  os_version VARCHAR(50),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX idx_device_tokens_platform ON device_tokens(platform);
CREATE INDEX idx_device_tokens_active ON device_tokens(is_active) WHERE is_active = TRUE;
```

### Token Storage and Retrieval

```javascript
async function storeDeviceToken(userId, token, platform, metadata = {}) {
  const query = `
    INSERT INTO device_tokens (user_id, device_token, platform, app_version, os_version)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (device_token) DO UPDATE SET
      user_id = EXCLUDED.user_id,
      platform = EXCLUDED.platform,
      app_version = EXCLUDED.app_version,
      os_version = EXCLUDED.os_version,
      is_active = TRUE,
      updated_at = NOW(),
      last_used_at = NOW()
    RETURNING id
  `;

  const result = await db.query(query, [
    userId,
    token,
    platform,
    metadata.appVersion,
    metadata.osVersion
  ]);

  return result.rows[0].id;
}

async function getDeviceTokens(userId, platform = null) {
  let query = `
    SELECT device_token, platform
    FROM device_tokens
    WHERE user_id = $1 AND is_active = TRUE
  `;
  const params = [userId];

  if (platform) {
    query += ` AND platform = $2`;
    params.push(platform);
  }

  const result = await db.query(query, params);
  return result.rows;
}
```

### Token Expiration Handling

```javascript
async function removeInvalidToken(deviceToken) {
  const query = `
    UPDATE device_tokens
    SET is_active = FALSE, updated_at = NOW()
    WHERE device_token = $1
  `;

  await db.query(query, [deviceToken]);

  logger.info('Device token deactivated', {
    deviceToken: maskToken(deviceToken),
    reason: 'Invalid or expired'
  });
}

// Periodic cleanup of old inactive tokens
async function cleanupInactiveTokens(daysOld = 90) {
  const query = `
    DELETE FROM device_tokens
    WHERE is_active = FALSE
      AND updated_at < NOW() - INTERVAL '${daysOld} days'
  `;

  const result = await db.query(query);

  logger.info('Inactive tokens cleaned up', {
    tokensRemoved: result.rowCount,
    daysOld
  });
}
```

### Platform Detection Logic

```javascript
function detectAndValidatePlatform(token, declaredPlatform) {
  const detectedPlatform = detectPlatform(token);

  if (declaredPlatform && declaredPlatform !== detectedPlatform) {
    logger.warn('Platform mismatch', {
      declared: declaredPlatform,
      detected: detectedPlatform,
      token: maskToken(token)
    });
  }

  return detectedPlatform;
}

function detectPlatform(token) {
  // APNs tokens: 64 hex characters
  if (/^[a-f0-9]{64}$/i.test(token)) {
    return 'ios';
  }

  // FCM tokens: 152+ characters, alphanumeric with special chars
  if (token.length > 140 && /^[A-Za-z0-9_:-]+$/.test(token)) {
    return 'android';
  }

  throw new Error('INVALID_TOKEN_FORMAT');
}
```

### Duplicate Token Prevention

```javascript
// Database constraint ensures uniqueness
// ON CONFLICT in storeDeviceToken handles updates

// Optional: Check if token exists for different user (device shared/sold)
async function checkTokenOwnership(deviceToken, userId) {
  const query = `
    SELECT user_id FROM device_tokens
    WHERE device_token = $1 AND is_active = TRUE
  `;

  const result = await db.query(query, [deviceToken]);

  if (result.rows.length > 0 && result.rows[0].user_id !== userId) {
    logger.warn('Device token ownership change', {
      previousUser: result.rows[0].user_id,
      newUser: userId,
      token: maskToken(deviceToken)
    });

    // Update to new user (device changed hands)
    return false;
  }

  return true;
}
```

---

## Error Handling

### Invalid Device Tokens

```javascript
async function handleInvalidToken(deviceToken, platform, error) {
  logger.error('Invalid device token detected', {
    platform,
    error: error.message,
    token: maskToken(deviceToken)
  });

  // Remove from database
  await removeInvalidToken(deviceToken);

  // Track for analytics
  await trackMetric('push.invalid_token', {
    platform,
    errorCode: error.code
  });

  return {
    status: 'invalid_token',
    message: 'Device token has been removed',
    shouldRetry: false
  };
}
```

### Failed Delivery (Network Errors)

```javascript
async function handleDeliveryFailure(deviceToken, platform, error, attempt = 1) {
  const maxAttempts = 3;
  const retryableErrors = [
    'NETWORK_ERROR',
    'TIMEOUT',
    'SERVICE_UNAVAILABLE',
    'messaging/server-unavailable' // FCM
  ];

  if (retryableErrors.includes(error.code) && attempt < maxAttempts) {
    logger.warn('Retrying notification send', {
      platform,
      attempt,
      maxAttempts,
      error: error.message
    });

    // Exponential backoff: 1s, 2s, 4s
    await sleep(Math.pow(2, attempt - 1) * 1000);

    return { shouldRetry: true, nextAttempt: attempt + 1 };
  }

  logger.error('Notification send failed permanently', {
    platform,
    attempts: attempt,
    error: error.message,
    token: maskToken(deviceToken)
  });

  return { shouldRetry: false, status: 'failed' };
}
```

### Platform-Specific Error Codes

**FCM Error Codes**:

```javascript
const fcmErrorHandlers = {
  'messaging/invalid-registration-token': async (token) => {
    await removeInvalidToken(token);
    return { status: 'invalid_token', action: 'removed' };
  },
  'messaging/registration-token-not-registered': async (token) => {
    await removeInvalidToken(token);
    return { status: 'unregistered', action: 'removed' };
  },
  'messaging/invalid-argument': (token, error) => {
    logger.error('Invalid FCM payload', { error: error.message });
    return { status: 'invalid_payload', action: 'fix_payload' };
  },
  'messaging/server-unavailable': () => {
    return { status: 'service_down', action: 'retry' };
  }
};
```

**APNs Error Codes**:

```javascript
const apnsErrorHandlers = {
  'BadDeviceToken': async (token) => {
    await removeInvalidToken(token);
    return { status: 'invalid_token', action: 'removed' };
  },
  'DeviceTokenNotForTopic': (token) => {
    logger.error('APNs token/topic mismatch', { token: maskToken(token) });
    return { status: 'wrong_topic', action: 'check_bundle_id' };
  },
  'Unregistered': async (token) => {
    await removeInvalidToken(token);
    return { status: 'unregistered', action: 'removed' };
  },
  'TooManyProviderTokenUpdates': () => {
    logger.warn('APNs rate limit on token updates');
    return { status: 'rate_limited', action: 'slow_down' };
  }
};
```

### Retry Strategies

```javascript
const retryConfig = {
  maxAttempts: 3,
  backoffMultiplier: 2, // Exponential: 1s, 2s, 4s
  initialDelay: 1000, // 1 second
  retryableErrors: [
    'NETWORK_ERROR',
    'TIMEOUT',
    'messaging/server-unavailable',
    'ServiceUnavailable'
  ]
};

async function sendWithRetry(sendFn, deviceToken, notification, attempt = 1) {
  try {
    return await sendFn(deviceToken, notification);
  } catch (error) {
    if (
      retryConfig.retryableErrors.includes(error.code) &&
      attempt < retryConfig.maxAttempts
    ) {
      const delay = retryConfig.initialDelay * Math.pow(retryConfig.backoffMultiplier, attempt - 1);

      logger.info('Retrying notification send', { attempt, delay });

      await sleep(delay);
      return sendWithRetry(sendFn, deviceToken, notification, attempt + 1);
    }

    throw error; // Non-retryable or max attempts reached
  }
}
```

---

## Configuration

### Environment Variables

```bash
# Server
PUSH_SERVICE_PORT=3002
NODE_ENV=production

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/notifications

# Firebase Cloud Messaging (Android)
FCM_PROJECT_ID=your-firebase-project
FCM_CLIENT_EMAIL=firebase-adminsdk@your-project.iam.gserviceaccount.com
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# Apple Push Notification Service (iOS)
APNS_KEY_PATH=/path/to/AuthKey_ABC123.p8
APNS_KEY_ID=ABC123XYZ
APNS_TEAM_ID=TEAM123456
APNS_BUNDLE_ID=com.example.app
APNS_PRODUCTION=true  # true for prod, false for sandbox

# Batch Settings
BATCH_SIZE=500        # Max notifications per batch
BATCH_TIMEOUT=5000    # 5s max wait before sending batch

# Retry Settings
MAX_RETRY_ATTEMPTS=3
RETRY_BACKOFF_MS=1000

# Token Cleanup
TOKEN_CLEANUP_INTERVAL_HOURS=24
INACTIVE_TOKEN_RETENTION_DAYS=90
```

### Batch Size Limits

**FCM**: 500 tokens per batch request
**APNs**: No official limit, recommended 100-500 per connection

```javascript
const batchConfig = {
  fcm: {
    maxTokensPerBatch: 500,
    maxConcurrentBatches: 10
  },
  apns: {
    maxTokensPerBatch: 100,
    maxConcurrentConnections: 5
  }
};
```

### Retry Attempt Limits

```javascript
const retryLimits = {
  perNotification: 3, // Max retry attempts per notification
  globalRateLimit: 1000, // Max 1,000 retries/min across all notifications
  cooldownPeriod: 60000 // 1 minute cooldown if rate limit hit
};
```

---

## Testing & Monitoring

### Testing with FCM/APNs Sandbox Environments

**FCM Sandbox** (no separate sandbox, use test tokens):

```javascript
// Use Firebase Emulator Suite for local testing
process.env.FIREBASE_EMULATOR_HUB = 'localhost:4400';

// Or use test FCM tokens from Firebase Console
const testToken = 'fT4gH...kL9p'; // Token from test device
```

**APNs Sandbox**:

```javascript
const apnProvider = new apn.Provider({
  token: {
    key: process.env.APNS_KEY_PATH,
    keyId: process.env.APNS_KEY_ID,
    teamId: process.env.APNS_TEAM_ID
  },
  production: false // Use APNs sandbox (gateway.sandbox.push.apple.com)
});

// Test with sandbox tokens from development builds
const testToken = 'abc123...xyz789'; // 64-char hex token from dev device
```

### Delivery Rate Tracking

```javascript
async function trackDeliveryMetrics(results) {
  const metrics = {
    total: results.length,
    sent: results.filter(r => r.status === 'sent').length,
    failed: results.filter(r => r.status === 'failed').length,
    invalidToken: results.filter(r => r.status === 'invalid_token').length
  };

  metrics.deliveryRate = (metrics.sent / metrics.total) * 100;

  await publishMetrics('push_notification_delivery', metrics);

  logger.info('Delivery metrics', metrics);

  return metrics;
}
```

### Failed Delivery Logging

```javascript
async function logFailedDelivery(notificationId, deviceToken, platform, error) {
  const query = `
    INSERT INTO failed_notifications (notification_id, device_token, platform, error_code, error_message)
    VALUES ($1, $2, $3, $4, $5)
  `;

  await db.query(query, [
    notificationId,
    deviceToken,
    platform,
    error.code,
    error.message
  ]);

  // Alert if failure rate exceeds threshold
  const recentFailureRate = await calculateFailureRate('1 hour');
  if (recentFailureRate > 10) {
    await sendAlert('high_push_failure_rate', {
      rate: recentFailureRate,
      platform
    });
  }
}
```

### Monitoring Metrics

**Key Metrics**:
- `push_notifications_sent_total` - Total sent (by platform)
- `push_notification_delivery_rate` - Success rate %
- `push_notification_latency_seconds` - Time from request to send
- `push_invalid_tokens_total` - Invalid/expired tokens detected
- `push_platform_errors_total` - FCM/APNs errors (by error code)

**Sample Prometheus Metrics**:

```javascript
const { Counter, Histogram } = require('prom-client');

const notificationsSent = new Counter({
  name: 'push_notifications_sent_total',
  help: 'Total push notifications sent',
  labelNames: ['platform', 'status']
});

const notificationLatency = new Histogram({
  name: 'push_notification_latency_seconds',
  help: 'Push notification send latency',
  labelNames: ['platform'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

// Usage
notificationsSent.inc({ platform: 'android', status: 'sent' });
notificationLatency.observe({ platform: 'ios' }, 0.234);
```
