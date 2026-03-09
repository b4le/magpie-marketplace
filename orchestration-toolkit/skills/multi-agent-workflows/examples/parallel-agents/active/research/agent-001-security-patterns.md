---
agent_id: agent-001
topic: security-patterns
phase: research
started_at: 2025-11-24T14:32:00Z
completed_at: 2025-11-24T14:47:00Z
duration_minutes: 15
status: complete
---

# Microservices API Security Patterns Research

## Executive Summary

Comprehensive analysis of security patterns for microservices APIs, focusing on authentication, authorization, transport security, and API key management. Findings emphasize zero-trust architecture and defense-in-depth strategies.

---

## 1. OAuth 2.1 for User Authentication

### Pattern Overview
OAuth 2.1 (RFC draft) consolidates OAuth 2.0 best practices and removes insecure legacy flows. Recommended for user-facing APIs requiring delegated authorization.

### Implementation Strategy
```
Flow: Authorization Code + PKCE
1. Client requests authorization from user
2. User authenticates with authorization server
3. Authorization server issues code to client
4. Client exchanges code + PKCE verifier for access token
5. Client uses access token for API requests
```

### Key Security Controls
- **PKCE (Proof Key for Code Exchange)**: Mandatory for all clients, prevents authorization code interception
- **Short-lived access tokens**: 15-60 minute TTL reduces compromise window
- **Refresh token rotation**: One-time use refresh tokens with detection of reuse
- **State parameter**: CSRF protection during authorization flow

### Pros
- Industry standard with extensive library support
- Enables fine-grained delegated permissions (scopes)
- Supports third-party integrations securely
- Separates authentication from resource servers

### Cons
- Complex implementation and debugging
- Requires maintaining authorization server infrastructure
- Token management overhead on client side

### Real-World Example
**Spotify API**: Uses OAuth 2.0 with PKCE for user authorization, enabling third-party apps to access user data with explicit consent.

---

## 2. Mutual TLS (mTLS) for Service-to-Service Authentication

### Pattern Overview
mTLS authenticates both client and server using X.509 certificates, establishing cryptographically verified identity for service mesh communication.

### Implementation Strategy
```
Certificate Management:
1. Issue short-lived certificates (24-72 hours) via internal CA
2. Automatic rotation using sidecar proxies (Envoy, Linkerd)
3. Certificate pinning for critical services
4. Revocation checking via OCSP or CRL
```

### Key Security Controls
- **Certificate-based identity**: Cryptographically strong, no shared secrets
- **Automated rotation**: Reduces risk from compromised credentials
- **Transport encryption**: TLS 1.3 with strong cipher suites only
- **Service mesh integration**: Transparent to application code

### Pros
- Strongest authentication mechanism for service-to-service
- No credential storage in environment variables
- Automatic encryption and authentication
- Works at network layer, language-agnostic

### Cons
- Complex certificate lifecycle management
- Performance overhead (negligible with modern hardware)
- Requires service mesh or manual certificate handling
- Debugging encrypted traffic is harder

### Real-World Example
**Google Internal Infrastructure**: All inter-service RPC requires mTLS via ALTS (Application Layer Transport Security).

---

## 3. API Key Management for External Consumers

### Pattern Overview
API keys provide simple authentication for server-to-server integrations where OAuth complexity isn't justified. Suitable for B2B APIs and internal tools.

### Implementation Strategy
```
Key Lifecycle:
1. Generate cryptographically random keys (min 256-bit entropy)
2. Store only hashed versions (bcrypt, Argon2)
3. Associate keys with identity, permissions, rate limits
4. Enable key rotation without service interruption
5. Automatic expiration and audit logging
```

### Key Security Controls
- **Prefix-based key identification**: Enables key detection in code repos (e.g., `sk_live_...`)
- **Scope-limited keys**: Read-only vs read-write, resource-specific permissions
- **Rate limiting per key**: Prevents abuse and identifies compromised keys
- **Key rotation**: Support multiple active keys during rotation periods

### Pros
- Simple to implement and use
- No user interaction required
- Easy to revoke and rotate
- Low latency (no token introspection)

### Cons
- Risk of accidental exposure in logs/repos
- Difficult to track which team member used a key
- No automatic expiration (must be enforced manually)
- Less granular than OAuth scopes

### Best Practices
- **Never log full keys**: Log only prefix (first 8 chars) for debugging
- **Rotation policy**: Force rotation every 90 days for production keys
- **Environment separation**: Different keys for dev/staging/production
- **Secret scanning**: Use GitHub secret scanning, GitGuardian, or similar

### Real-World Example
**Stripe API**: Uses prefixed API keys (`sk_live_`, `sk_test_`) with fine-grained permissions and automatic detection in GitHub repos.

---

## 4. JWT (JSON Web Tokens) for Stateless Authorization

### Pattern Overview
Self-contained tokens carrying identity and claims, verified cryptographically without database lookup. Ideal for distributed microservices.

### Implementation Strategy
```
Token Structure:
Header: { "alg": "RS256", "typ": "JWT" }
Payload: { "sub": "user-id", "scope": ["read", "write"], "exp": 1700000000 }
Signature: RSASSA-PKCS1-v1_5(header.payload, private_key)
```

### Key Security Controls
- **Asymmetric signing (RS256/ES256)**: Public key verification, private key never leaves auth server
- **Short expiration**: 15-60 minutes forces regular token refresh
- **Claims validation**: Verify `iss`, `aud`, `exp`, `nbf` on every request
- **Deny list for revocation**: Cache revoked token IDs until expiration

### Pros
- Stateless validation (no DB lookup per request)
- Works across distributed services
- Contains authorization claims (scopes, roles)
- Cryptographically tamper-proof

### Cons
- Cannot revoke before expiration (without deny list)
- Token size overhead (300-1000 bytes)
- Clock skew issues require careful validation
- Exposed claims (don't put sensitive data in JWT)

### Common Pitfalls
- Using HS256 with shared secrets (key distribution problem)
- Not validating `aud` claim (token reuse across services)
- Long expiration times (defeats stateless benefit)
- Storing sensitive data in payload (it's base64, not encrypted)

---

## 5. Defense-in-Depth Recommendations

### Layered Security Controls
1. **Gateway layer**: API key validation, rate limiting, IP allowlisting
2. **Service layer**: JWT validation, scope enforcement, input validation
3. **Data layer**: Encryption at rest, row-level security, audit logging

### Security Headers
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'none'
X-API-Version: v1  # Enable version-based security policies
```

### Monitoring and Alerting
- Failed authentication attempts (threshold: 10/minute/IP)
- Token reuse after revocation (potential compromise)
- Unusual API usage patterns (ML-based anomaly detection)
- Certificate expiration warnings (30 days before expiry)

---

## Synthesis and Recommendations

### Primary Recommendation by Use Case

| Use Case | Recommended Pattern | Rationale |
|----------|-------------------|-----------|
| User-facing mobile/web apps | OAuth 2.1 + PKCE | Delegated authorization, scope management |
| Service-to-service (internal) | mTLS | Strongest authentication, automatic encryption |
| B2B API integrations | API Keys + Scopes | Simplicity, easy rotation, scope control |
| Distributed microservices | JWT (RS256) | Stateless validation, low latency |

### Implementation Checklist
- [ ] Use TLS 1.3 for all transport encryption
- [ ] Implement rate limiting per authentication identity
- [ ] Log authentication events with correlation IDs
- [ ] Regular security audits and penetration testing
- [ ] Automate credential rotation (keys, certificates, tokens)
- [ ] Monitor for leaked credentials in public repos

---

**Research completed by agent-001 | Duration: 15 minutes | Token count: 847**
