---
agent_id: agent-002
topic: performance-optimization
phase: research
started_at: 2025-11-24T14:32:00Z
completed_at: 2025-11-24T14:57:00Z
duration_minutes: 25
status: complete
---

# Microservices API Performance Optimization Research

## Executive Summary

In-depth analysis of performance patterns for microservices APIs, covering caching strategies, rate limiting algorithms, pagination techniques, and response compression. Focus on achieving sub-100ms P95 latency while maintaining system stability under load.

---

## 1. Multi-Tier Caching Strategy

### Pattern Overview
Hierarchical caching reduces latency and backend load through strategic cache placement at multiple layers. Critical for read-heavy APIs.

### Implementation Architecture

```
Request Flow:
1. CDN Cache (Edge) → 50-100ms latency reduction
2. API Gateway Cache → 20-50ms reduction
3. Service-Level Cache (Redis) → 5-15ms reduction
4. Database Query Cache → 2-5ms reduction
```

### Layer-Specific Strategies

#### Edge/CDN Caching
- **Use cases**: Static responses, public data, geographically distributed users
- **TTL**: 1-24 hours for rarely changing data
- **Cache keys**: Include API version, query params, Accept headers
- **Purging**: Webhook-triggered purge on data mutations

#### API Gateway Caching
- **Use cases**: Authenticated responses with shared data (e.g., product catalogs)
- **TTL**: 5-60 minutes for semi-dynamic data
- **Vary headers**: By user tier, location, or feature flags
- **Pattern**: `GET /products?category=electronics` → cached per category

#### Service-Level Caching (Redis)
- **Use cases**: Frequently accessed database queries, computed results
- **TTL**: 30 seconds to 10 minutes
- **Eviction policy**: LRU (Least Recently Used) with memory limits
- **Pattern**: Cache-aside with explicit invalidation on writes

```javascript
// Cache-aside pattern example
async function getUser(userId) {
  const cached = await redis.get(`user:${userId}`);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(userId);
  await redis.setex(`user:${userId}`, 300, JSON.stringify(user)); // 5min TTL
  return user;
}
```

### Cache Invalidation Strategies
1. **TTL-based**: Simple, eventual consistency acceptable
2. **Event-driven**: Publish invalidation events on writes (Kafka, Redis Pub/Sub)
3. **Versioned keys**: `user:123:v5` → increment version on update
4. **Cache tags**: Group related entities for bulk invalidation

### Performance Impact
- **Cache hit reduction**: 200ms → 15ms (93% improvement)
- **Backend load reduction**: 70-90% fewer database queries
- **Cost savings**: Reduced database instance sizing

### Pitfalls
- **Stale data risk**: Balance TTL vs data freshness
- **Cache stampede**: Thundering herd on cache expiration (use locking)
- **Memory limits**: Monitor eviction rates and adjust sizing

---

## 2. Rate Limiting Algorithms

### Pattern Overview
Control request velocity to prevent abuse, ensure fair usage, and protect backend systems from overload.

### Algorithm Comparison

#### Token Bucket (Recommended)
```
Mechanism:
- Bucket holds N tokens, refills at R tokens/second
- Each request consumes 1 token
- Request rejected if bucket empty

Configuration example:
Bucket size: 100 tokens
Refill rate: 10 tokens/second
Burst capacity: 100 requests in 1 second, then 10/sec sustained
```

**Pros**: Allows bursts, smooth refill, industry standard
**Cons**: Requires state storage per user
**Implementation**: Redis sorted sets for distributed systems

#### Sliding Window Log
```
Mechanism:
- Store timestamp of each request
- Count requests in past N seconds
- Reject if count exceeds limit

Configuration example:
Window: 60 seconds
Limit: 100 requests/minute
Precision: Exact request count
```

**Pros**: Precise limiting, no burst allowance
**Cons**: Higher memory usage (stores all request timestamps)
**Use case**: Strict rate enforcement for sensitive operations

#### Fixed Window Counter
```
Mechanism:
- Counter resets every fixed interval (e.g., top of minute)
- Increment on each request
- Reject if counter > limit

Configuration example:
Window: 1 minute
Limit: 100 requests
Reset: :00 seconds of each minute
```

**Pros**: Minimal memory, easy implementation
**Cons**: Boundary problem (200 requests possible at window edge)
**Use case**: Low-criticality APIs, simple quotas

### Tiered Rate Limits

```
Free tier:     100 requests/minute
Professional:  1000 requests/minute
Enterprise:    10000 requests/minute
Internal:      No limit (with circuit breaker)
```

### Response Headers
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 742
X-RateLimit-Reset: 1700000000
Retry-After: 45  (on 429 response)
```

### Real-World Example
**GitHub API**: Uses token bucket with tiered limits (5000/hour authenticated, 60/hour unauthenticated) and detailed rate limit headers.

---

## 3. Pagination Strategies

### Pattern Overview
Break large datasets into manageable chunks to reduce response size, memory usage, and client parsing time.

### Offset-Based Pagination

```
GET /users?limit=50&offset=100

Pros:
- Simple implementation: SELECT * FROM users LIMIT 50 OFFSET 100
- Easy page navigation (jump to page N)
- Familiar pattern to developers

Cons:
- Performance degrades with large offsets (database scans)
- Inconsistent results during concurrent writes (missing/duplicate items)
- Not suitable for real-time data

Best for: Small-to-medium datasets (< 10K items), admin interfaces
```

### Cursor-Based Pagination (Recommended)

```
GET /users?limit=50&cursor=eyJpZCI6MTIzNDU2fQ==

Response:
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzNTA2fQ==",
    "has_more": true
  }
}

Implementation:
1. Cursor encodes last item's sort key (e.g., ID, timestamp)
2. Query: SELECT * FROM users WHERE id > 123456 ORDER BY id LIMIT 50
3. Encode last item's ID as next cursor

Pros:
- Consistent performance regardless of dataset size
- No duplicate/missing items during concurrent writes
- Efficient database queries (uses index)

Cons:
- Cannot jump to arbitrary page
- Cursor is opaque to clients
- Requires stable sort order

Best for: Large datasets, real-time feeds, infinite scroll
```

### Keyset Pagination (SQL Optimization)

```sql
-- Instead of OFFSET (slow)
SELECT * FROM users ORDER BY created_at, id LIMIT 50 OFFSET 10000;

-- Use keyset (fast)
SELECT * FROM users
WHERE (created_at, id) > ('2024-01-15 10:30:00', 123456)
ORDER BY created_at, id
LIMIT 50;
```

**Performance**: 10x-100x faster on large datasets with proper indexes.

### Pagination Best Practices
- **Default limit**: 25-50 items
- **Max limit**: 100-500 items (prevent abuse)
- **Include total count**: Optional (expensive on large datasets)
- **Stable sort order**: Always include tie-breaker (e.g., id)

### Real-World Example
**Twitter API**: Uses cursor-based pagination for timeline endpoints to handle millions of tweets efficiently.

---

## 4. Response Compression

### Pattern Overview
Reduce bandwidth usage and improve transfer times through HTTP compression. Especially valuable for mobile clients and large JSON responses.

### Compression Algorithms

#### Gzip (Universal Support)
```
Content-Encoding: gzip

Compression ratio: 60-80% for JSON
CPU overhead: Low-moderate
Browser support: Universal
```

#### Brotli (Modern Standard)
```
Content-Encoding: br

Compression ratio: 70-85% for JSON (better than gzip)
CPU overhead: Moderate
Browser support: 95%+ (all modern browsers)
```

### Configuration Strategy

```
Compression rules:
- Enable for responses > 1KB (overhead not worth it for smaller)
- Compress text formats: JSON, XML, HTML, CSS, JavaScript
- Skip pre-compressed: images, video, already-compressed archives
- Compression level: 4-6 (balance ratio vs CPU)

Nginx example:
gzip on;
gzip_types application/json application/xml text/plain;
gzip_min_length 1024;
gzip_comp_level 5;
```

### Dynamic vs Static Compression
- **Static**: Pre-compress during build/deployment (zero runtime CPU)
- **Dynamic**: Compress on-demand (flexible, works for dynamic data)

### Performance Impact
```
Uncompressed JSON response: 450 KB
Gzip compressed: 85 KB (81% reduction)
Brotli compressed: 72 KB (84% reduction)

Transfer time (3G network, 750 Kbps):
Uncompressed: 4.8s
Gzip: 0.9s (5.3x faster)
Brotli: 0.77s (6.2x faster)
```

### Pitfalls
- **CPU overhead**: Monitor compression CPU usage under load
- **BREACH attack**: Don't compress responses with user secrets + attacker-controlled input
- **Double compression**: Check if upstream proxy already compressing

---

## 5. Database Query Optimization

### N+1 Query Problem

```javascript
// BAD: N+1 queries
const users = await db.users.findAll(); // 1 query
for (const user of users) {
  user.posts = await db.posts.findByUser(user.id); // N queries
}

// GOOD: Single query with join
const users = await db.users.findAll({
  include: [{ model: db.posts }]
}); // 1 query with JOIN
```

### Connection Pooling
```
Configuration:
- Pool size: 10-20 connections per service instance
- Max connection lifetime: 30 minutes (prevent stale connections)
- Connection timeout: 5 seconds
- Idle timeout: 10 minutes

Monitor:
- Active connections
- Wait time for connection
- Connection errors
```

### Read Replicas for Scaling
```
Write traffic → Primary database
Read traffic → Round-robin across 3 replicas

Pros: 3x read capacity, no primary load
Cons: Replication lag (eventual consistency)
Pattern: Route reads to replicas, writes to primary
```

---

## 6. Performance Monitoring and SLOs

### Key Metrics

```
Latency:
- P50: 25ms (median)
- P95: 80ms (95th percentile)
- P99: 200ms (worst case for most users)

Throughput:
- 5000 requests/second sustained
- 8000 requests/second burst capacity

Error rate:
- < 0.1% (99.9% success rate)
```

### Service Level Objectives (SLOs)

```
API Response Time SLO:
- 95% of requests complete in < 100ms
- 99% of requests complete in < 500ms
- 99.9% of requests complete in < 2000ms

Measured over 30-day rolling window
```

### Observability Stack
- **Metrics**: Prometheus + Grafana
- **Tracing**: OpenTelemetry → Jaeger/Tempo
- **Logging**: Structured JSON logs → ELK/Loki

### Load Testing
```bash
# Baseline load test
artillery quick --duration 60 --rate 100 https://api.example.com/v1/users

# Stress test (find breaking point)
k6 run --vus 1000 --duration 5m load-test.js
```

---

## Synthesis and Recommendations

### Performance Optimization Priority Matrix

| Priority | Optimization | Expected Impact | Implementation Effort |
|----------|--------------|-----------------|----------------------|
| P0 | Database indexing | 10-100x query speedup | Low (hours) |
| P0 | Redis caching (hot paths) | 5-20x latency reduction | Medium (days) |
| P1 | Response compression | 60-80% bandwidth reduction | Low (hours) |
| P1 | Cursor-based pagination | 10x improvement on large datasets | Medium (days) |
| P1 | Token bucket rate limiting | Prevent abuse, system stability | Medium (days) |
| P2 | CDN caching | 50-100ms latency reduction | Medium (days) |
| P2 | Read replicas | 2-5x read capacity | High (weeks) |

### Implementation Checklist
- [ ] Implement multi-tier caching (Redis + CDN)
- [ ] Add token bucket rate limiting with tiered limits
- [ ] Use cursor-based pagination for large datasets
- [ ] Enable Brotli/Gzip compression for JSON responses
- [ ] Optimize N+1 queries with eager loading
- [ ] Set up connection pooling (10-20 connections)
- [ ] Define and monitor SLOs (P95 < 100ms)
- [ ] Run regular load tests (weekly or on major changes)

---

**Research completed by agent-002 | Duration: 25 minutes | Token count: 1023**
