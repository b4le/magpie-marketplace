# WebSocket Notification Service

## Service Overview

**Purpose**: Deliver real-time notifications to web clients via persistent WebSocket connections

**Use Cases**:
- Order status updates (placed, shipped, delivered)
- Inventory alerts (low stock, back in stock)
- System notifications (maintenance, new features)
- Live activity feeds

**Technology Stack**:
- Node.js 20+
- Express.js 4.18+ (HTTP server)
- Socket.io 4.6+ (WebSocket library)
- Redis 7+ (connection state sharing across instances)
- JWT for authentication

**Port**: 3001

---

## Architecture

### Connection Lifecycle

```
Client                          WebSocket Service              Redis
  │                                    │                         │
  ├──1. HTTP Handshake───────────────>│                         │
  │   (JWT in query string)           │                         │
  │                                    ├──2. Validate JWT────────>│
  │                                    │<─────(user_id)──────────┤
  │<──3. WebSocket Upgrade─────────────┤                         │
  │                                    │                         │
  ├──4. 'authenticate' event──────────>│                         │
  │<──5. 'connection-status' OK────────┤                         │
  │                                    │                         │
  ├──6. 'join-room' event─────────────>│                         │
  │   {room: "user-12345"}             ├──7. Subscribe to room───>│
  │<──8. 'room-joined' confirmation────┤                         │
  │                                    │                         │
  │                                    │<─9. Notification event──┤
  │<──10. 'notification' event─────────┤   (from other instance) │
  │                                    │                         │
  ├──11. 'heartbeat' ping────────────>│                         │
  │<──12. 'heartbeat' pong─────────────┤                         │
  │                                    │                         │
  ├──13. Disconnect───────────────────>│                         │
  │                                    ├──14. Cleanup room───────>│
  │                                    │                         │
```

### Room/Channel Structure

**Room Types**:
1. **User-Specific Rooms**: `user-{userId}` - Personal notifications
2. **Order-Specific Rooms**: `order-{orderId}` - Order status updates
3. **Broadcast Rooms**: `all-users` - System-wide announcements

**Example**: User 12345 watching order ORD-999 joins:
- `user-12345` (personal notifications)
- `order-ORD-999` (order updates)

### Redis Adapter for Scaling

**Problem**: Multiple WebSocket service instances need to share connection state

**Solution**: Socket.io Redis adapter broadcasts events across all instances

```javascript
// Redis adapter configuration
const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const { createClient } = require('redis');

const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

await Promise.all([pubClient.connect(), subClient.connect()]);

const io = new Server(server, {
  adapter: createAdapter(pubClient, subClient)
});
```

**How it works**:
1. User connects to instance A
2. Notification published to instance B
3. Instance B publishes to Redis
4. Instance A receives from Redis and emits to user

---

## API Endpoints

### HTTP Health Check

```http
GET /health HTTP/1.1
Host: localhost:3001

HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "service": "websocket-service",
  "version": "1.0.0",
  "connections": 1247,
  "uptime": 3600,
  "dependencies": {
    "redis": "connected"
  },
  "timestamp": "2025-11-24T13:45:00Z"
}
```

### WebSocket Connection

```javascript
// Client-side connection
const socket = io('http://localhost:3001', {
  query: {
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' // JWT token
  },
  transports: ['websocket'], // Force WebSocket (no long-polling fallback)
  reconnection: true,
  reconnectionAttempts: 5,
  reconnectionDelay: 1000
});
```

---

## WebSocket Events

### Client → Server Events

#### 1. `authenticate`

**Purpose**: Verify JWT and establish user identity

**Payload**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response** (via `connection-status` event):
```json
{
  "status": "authenticated",
  "userId": "user-12345"
}
```

**Errors**:
- `INVALID_TOKEN` - Malformed or expired JWT
- `AUTHENTICATION_FAILED` - Invalid signature

#### 2. `join-room`

**Purpose**: Subscribe to a notification room/channel

**Payload**:
```json
{
  "room": "user-12345"
}
```

**Response** (via `room-joined` event):
```json
{
  "room": "user-12345",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Errors**:
- `UNAUTHORIZED` - User not allowed to join room
- `ROOM_NOT_FOUND` - Invalid room name

#### 3. `leave-room`

**Purpose**: Unsubscribe from a notification room

**Payload**:
```json
{
  "room": "order-ORD-999"
}
```

**Response** (via `room-left` event):
```json
{
  "room": "order-ORD-999",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

#### 4. `heartbeat`

**Purpose**: Keep connection alive (ping/pong)

**Payload**: `{ "timestamp": 1700846700000 }`

**Response** (via `heartbeat` event):
```json
{
  "timestamp": 1700846700000,
  "serverTime": 1700846700123
}
```

### Server → Client Events

#### 1. `notification`

**Purpose**: Deliver a notification to the client

**Payload**:
```json
{
  "id": "notif-abc123",
  "type": "order-confirmation",
  "title": "Order Confirmed",
  "message": "Your order #ORD-999 has been confirmed",
  "data": {
    "orderId": "ORD-999",
    "total": 149.99
  },
  "priority": "high",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Client handling**:
```javascript
socket.on('notification', (notification) => {
  console.log('Received notification:', notification);
  displayNotification(notification);

  // Acknowledge receipt (optional)
  socket.emit('notification-ack', { id: notification.id });
});
```

#### 2. `connection-status`

**Purpose**: Inform client of connection state changes

**Payload**:
```json
{
  "status": "authenticated",
  "userId": "user-12345",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Statuses**:
- `connected` - WebSocket connection established
- `authenticated` - JWT validated, user identified
- `disconnected` - Connection closed

#### 3. `error`

**Purpose**: Notify client of errors

**Payload**:
```json
{
  "code": "AUTHENTICATION_FAILED",
  "message": "Invalid or expired JWT token",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

---

## Implementation Details

### Connection Management

**Server-side connection handling**:

```javascript
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS.split(','),
    credentials: true
  },
  pingTimeout: 10000, // 10s
  pingInterval: 25000, // 25s (heartbeat)
  maxHttpBufferSize: 1e6 // 1MB max message size
});

io.use(async (socket, next) => {
  // JWT authentication middleware
  const token = socket.handshake.query.token;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.userId;
    next();
  } catch (err) {
    next(new Error('AUTHENTICATION_FAILED'));
  }
});

io.on('connection', async (socket) => {
  console.log(`User ${socket.userId} connected (socket ${socket.id})`);

  // Auto-join user-specific room
  socket.join(`user-${socket.userId}`);

  // Send connection confirmation
  socket.emit('connection-status', {
    status: 'authenticated',
    userId: socket.userId,
    timestamp: new Date().toISOString()
  });

  // Handle events
  socket.on('join-room', handleJoinRoom(socket));
  socket.on('leave-room', handleLeaveRoom(socket));
  socket.on('heartbeat', handleHeartbeat(socket));

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log(`User ${socket.userId} disconnected (socket ${socket.id})`);
  });
});
```

### Room Broadcasting

**Publishing notifications to rooms**:

```javascript
// Broadcast to specific user
function sendNotificationToUser(userId, notification) {
  io.to(`user-${userId}`).emit('notification', notification);
}

// Broadcast to all users in a room
function sendNotificationToRoom(room, notification) {
  io.to(room).emit('notification', notification);
}

// Broadcast to multiple rooms
function sendNotificationToRooms(rooms, notification) {
  rooms.forEach(room => {
    io.to(room).emit('notification', notification);
  });
}

// Example: Order update notification
sendNotificationToRooms(
  [`user-12345`, `order-ORD-999`],
  {
    id: 'notif-abc123',
    type: 'order-shipped',
    title: 'Order Shipped',
    message: 'Your order is on the way!',
    data: { orderId: 'ORD-999', trackingNumber: 'TRK-xyz' },
    timestamp: new Date().toISOString()
  }
);
```

### Heartbeat/Keepalive

**Client-side heartbeat**:

```javascript
// Send heartbeat every 20 seconds
setInterval(() => {
  socket.emit('heartbeat', { timestamp: Date.now() });
}, 20000);

socket.on('heartbeat', (data) => {
  const latency = Date.now() - data.timestamp;
  console.log(`Heartbeat latency: ${latency}ms`);
});
```

**Server-side handling**:

```javascript
function handleHeartbeat(socket) {
  return (data) => {
    socket.emit('heartbeat', {
      timestamp: data.timestamp,
      serverTime: Date.now()
    });
  };
}
```

### Graceful Disconnect Handling

**Server-side cleanup**:

```javascript
socket.on('disconnect', async (reason) => {
  console.log(`Socket ${socket.id} disconnected: ${reason}`);

  // Cleanup: Remove from all rooms
  const rooms = Array.from(socket.rooms).filter(room => room !== socket.id);
  rooms.forEach(room => socket.leave(room));

  // Log to database
  await logDisconnection(socket.userId, reason);

  // Notify other services (optional)
  await publishEvent('user-disconnected', {
    userId: socket.userId,
    socketId: socket.id,
    reason
  });
});
```

**Client-side reconnection**:

```javascript
socket.on('disconnect', () => {
  console.log('Disconnected from server. Reconnecting...');
});

socket.on('reconnect', (attemptNumber) => {
  console.log(`Reconnected after ${attemptNumber} attempts`);

  // Re-join rooms
  socket.emit('join-room', { room: `user-${userId}` });
  socket.emit('join-room', { room: `order-${orderId}` });
});

socket.on('reconnect_failed', () => {
  console.error('Reconnection failed. Please refresh the page.');
});
```

---

## Configuration

### Environment Variables

```bash
# Server
WEBSOCKET_PORT=3001
NODE_ENV=production

# Redis
REDIS_URL=redis://localhost:6379
REDIS_KEY_PREFIX=websocket:

# Authentication
JWT_SECRET=your-secret-key-min-32-chars
JWT_ALGORITHM=HS256

# CORS
ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com

# Connection Limits
MAX_CONNECTIONS_PER_INSTANCE=10000
MAX_MESSAGE_SIZE=1048576  # 1MB

# Heartbeat
PING_TIMEOUT=10000        # 10s
PING_INTERVAL=25000       # 25s

# Logging
LOG_LEVEL=info
```

### Connection Timeout Settings

```javascript
const ioConfig = {
  pingTimeout: parseInt(process.env.PING_TIMEOUT) || 10000,
  pingInterval: parseInt(process.env.PING_INTERVAL) || 25000,
  maxHttpBufferSize: parseInt(process.env.MAX_MESSAGE_SIZE) || 1e6,
  transports: ['websocket'], // Disable long-polling in production
  allowUpgrades: false // Prevent transport upgrades
};
```

### Max Connections Per Instance

**Monitoring and limiting**:

```javascript
io.on('connection', (socket) => {
  const currentConnections = io.engine.clientsCount;
  const maxConnections = parseInt(process.env.MAX_CONNECTIONS_PER_INSTANCE) || 10000;

  if (currentConnections > maxConnections) {
    socket.emit('error', {
      code: 'MAX_CONNECTIONS_REACHED',
      message: 'Server at capacity. Please try again later.'
    });
    socket.disconnect(true);
    return;
  }

  // Continue with normal connection handling...
});
```

---

## Error Handling

### Connection Errors

**Network failures**:

```javascript
// Client-side handling
socket.on('connect_error', (error) => {
  console.error('Connection error:', error.message);

  // Show user-friendly message
  if (error.message === 'AUTHENTICATION_FAILED') {
    showError('Session expired. Please log in again.');
    redirectToLogin();
  } else {
    showError('Connection failed. Retrying...');
  }
});
```

**Server-side handling**:

```javascript
io.engine.on('connection_error', (err) => {
  console.error('Connection error:', err);

  // Log for monitoring
  logger.error('WebSocket connection error', {
    error: err.message,
    code: err.code,
    context: err.context
  });
});
```

### Authentication Failures

**Invalid JWT**:

```javascript
io.use(async (socket, next) => {
  const token = socket.handshake.query.token;

  if (!token) {
    return next(new Error('MISSING_TOKEN'));
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check token expiration
    if (decoded.exp < Date.now() / 1000) {
      return next(new Error('TOKEN_EXPIRED'));
    }

    socket.userId = decoded.userId;
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError') {
      return next(new Error('INVALID_TOKEN'));
    }
    return next(new Error('AUTHENTICATION_FAILED'));
  }
});
```

### Room Join/Leave Errors

**Unauthorized room access**:

```javascript
function handleJoinRoom(socket) {
  return async (data) => {
    const { room } = data;

    // Validate room access
    if (room.startsWith('user-')) {
      const requestedUserId = room.replace('user-', '');
      if (requestedUserId !== socket.userId) {
        socket.emit('error', {
          code: 'UNAUTHORIZED',
          message: 'Cannot join another user\'s room'
        });
        return;
      }
    }

    if (room.startsWith('order-')) {
      const orderId = room.replace('order-', '');
      const hasAccess = await checkOrderAccess(socket.userId, orderId);
      if (!hasAccess) {
        socket.emit('error', {
          code: 'UNAUTHORIZED',
          message: 'You do not have access to this order'
        });
        return;
      }
    }

    // Join room
    socket.join(room);
    socket.emit('room-joined', { room, timestamp: new Date().toISOString() });
  };
}
```

### Redis Connection Failures

**Handling Redis outages**:

```javascript
const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

pubClient.on('error', (err) => {
  logger.error('Redis pub client error', { error: err.message });

  // Alert monitoring system
  sendAlert('redis-connection-error', {
    client: 'pub',
    error: err.message
  });
});

subClient.on('error', (err) => {
  logger.error('Redis sub client error', { error: err.message });
});

// Fallback: If Redis fails, Socket.io reverts to in-memory adapter
// (connections limited to single instance, no cross-instance broadcasting)
```

---

## Testing

### Unit Tests

**Example: JWT authentication test**

```javascript
const { describe, it, expect, beforeEach } = require('@jest/globals');
const jwt = require('jsonwebtoken');
const { authenticateSocket } = require('../middleware/auth');

describe('WebSocket Authentication', () => {
  let socket, next;

  beforeEach(() => {
    socket = {
      handshake: { query: {} }
    };
    next = jest.fn();
  });

  it('should authenticate valid JWT', async () => {
    const token = jwt.sign({ userId: 'user-123' }, process.env.JWT_SECRET);
    socket.handshake.query.token = token;

    await authenticateSocket(socket, next);

    expect(socket.userId).toBe('user-123');
    expect(next).toHaveBeenCalledWith();
  });

  it('should reject expired JWT', async () => {
    const token = jwt.sign(
      { userId: 'user-123', exp: Math.floor(Date.now() / 1000) - 3600 },
      process.env.JWT_SECRET
    );
    socket.handshake.query.token = token;

    await authenticateSocket(socket, next);

    expect(next).toHaveBeenCalledWith(new Error('TOKEN_EXPIRED'));
  });
});
```

### Integration Tests

**Example: Connection lifecycle test**

```javascript
const io = require('socket.io-client');

describe('WebSocket Connection Lifecycle', () => {
  let clientSocket;

  beforeEach((done) => {
    const token = jwt.sign({ userId: 'user-123' }, process.env.JWT_SECRET);
    clientSocket = io('http://localhost:3001', {
      query: { token },
      transports: ['websocket']
    });
    clientSocket.on('connect', done);
  });

  afterEach(() => {
    clientSocket.close();
  });

  it('should receive connection-status event', (done) => {
    clientSocket.on('connection-status', (data) => {
      expect(data.status).toBe('authenticated');
      expect(data.userId).toBe('user-123');
      done();
    });
  });

  it('should join and receive notification in room', (done) => {
    clientSocket.emit('join-room', { room: 'user-123' });

    clientSocket.on('room-joined', (data) => {
      expect(data.room).toBe('user-123');

      // Simulate notification from server
      io.to('user-123').emit('notification', {
        id: 'test-notif',
        type: 'test',
        message: 'Test notification'
      });
    });

    clientSocket.on('notification', (notif) => {
      expect(notif.message).toBe('Test notification');
      done();
    });
  });
});
```

### Load Testing

**k6 WebSocket load test**:

```javascript
import ws from 'k6/ws';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 1000 },  // Ramp up to 1,000 connections
    { duration: '1m', target: 5000 },   // Ramp up to 5,000 connections
    { duration: '2m', target: 5000 },   // Hold at 5,000 connections
    { duration: '30s', target: 0 },     // Ramp down
  ],
};

export default function () {
  const url = 'ws://localhost:3001/socket.io/?transport=websocket&token=<JWT>';

  const res = ws.connect(url, (socket) => {
    socket.on('open', () => {
      console.log('Connected');
      socket.send('42["join-room",{"room":"user-123"}]'); // Socket.io format
    });

    socket.on('message', (data) => {
      console.log('Received:', data);
    });

    socket.on('close', () => {
      console.log('Disconnected');
    });

    socket.setTimeout(() => {
      socket.close();
    }, 60000); // Hold connection for 1 minute
  });

  check(res, { 'connected successfully': (r) => r && r.status === 101 });
}
```

**Target Metrics**:
- 10,000 concurrent connections per instance
- <100ms latency for notification delivery
- >99.9% message delivery success rate

---

## Monitoring & Logging

### Metrics to Track

**Connection Metrics**:
- `websocket_connections_total` - Total active connections
- `websocket_connections_created` - Connection creation rate
- `websocket_connections_closed` - Connection close rate
- `websocket_connection_duration_seconds` - Average connection lifetime

**Message Metrics**:
- `websocket_messages_sent_total` - Total messages sent
- `websocket_messages_received_total` - Total messages received
- `websocket_message_latency_seconds` - Message delivery latency

**Error Metrics**:
- `websocket_authentication_failures_total` - Failed authentication attempts
- `websocket_room_join_errors_total` - Failed room joins
- `websocket_redis_errors_total` - Redis connection errors

### Log Format Examples

**Connection log**:
```json
{
  "level": "info",
  "message": "User connected",
  "service": "websocket-service",
  "userId": "user-12345",
  "socketId": "abc123xyz",
  "ipAddress": "192.168.1.100",
  "timestamp": "2025-11-24T13:45:00Z"
}
```

**Notification log**:
```json
{
  "level": "info",
  "message": "Notification sent",
  "service": "websocket-service",
  "notificationId": "notif-abc123",
  "userId": "user-12345",
  "room": "user-12345",
  "type": "order-confirmation",
  "latency": 23,
  "timestamp": "2025-11-24T13:45:00Z"
}
```

### Recommended Monitoring Tools

- **Prometheus** - Metrics collection
- **Grafana** - Dashboards and alerting
- **Socket.io Admin UI** - Real-time connection monitoring
- **Redis Insights** - Redis performance monitoring

**Sample Grafana Alert**:
```yaml
alerts:
  - name: High WebSocket Error Rate
    condition: rate(websocket_authentication_failures_total[5m]) > 10
    severity: warning
    message: "WebSocket authentication failures exceeding 10/min"
```
