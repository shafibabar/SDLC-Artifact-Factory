---
name: zero-trust-design
description: >
  Teaches how to design a Zero Trust Architecture for a microservices system —
  covering the core Zero Trust principles (never trust, always verify), how Zero
  Trust is implemented at the network layer (mTLS via Linkerd), the identity layer
  (JWT + OIDC), the workload layer (service accounts, SPIFFE/SPIRE), and the data
  layer (encryption at rest and in transit). Zero Trust Architecture is mandatory
  for all services in this plugin. Used by the security-architect agent during the
  Design phase.
version: 1.1.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, zero-trust, mtls, jwt, linkerd, encryption, mandatory]
---

# Zero Trust Design

## Purpose

Zero Trust Architecture (NIST SP 800-207) is built on the principle: **never trust, always verify**. No actor — user, service, or network — is implicitly trusted because of its location. Every request must be authenticated, authorised, and encrypted, regardless of whether it originates from inside or outside the network perimeter.

Zero Trust Architecture is mandatory in this plugin. The absence of Zero Trust principles in any service is a security defect, not a future enhancement.

---

## Zero Trust Pillars

### Pillar 1: Verify Explicitly

Every request is authenticated and authorised, every time. Location (internal network, same Kubernetes namespace) does not grant implicit trust.

| Layer | Mechanism |
|---|---|
| User → Service | JWT Bearer token; validated on every request at the API Gateway and at the service handler |
| Service → Service | mTLS; certificate identity (SPIFFE/SPIRE or Linkerd-issued); verified on every connection |
| Service → Database | Service account credentials; rotated automatically; never static passwords in environment variables |
| Service → External API | Short-lived OAuth 2.0 access tokens; never long-lived API keys stored in code |

### Pillar 2: Apply the Principle of Least Privilege

Every identity (user or service) has only the permissions required for its specific function. No identity has permissions "just in case."

| Identity | Principle application |
|---|---|
| User JWT claims | Claims scoped to the user's role; ABAC policy enforced at every resource access |
| Service account | Read/write only to its own database; no cross-service database access |
| Infrastructure credentials | Terraform/Tofu state access scoped to specific environment; no wildcard IAM policies |
| Admin access | Time-limited; requires approval; logged; no standing admin access to production |

### Pillar 3: Assume Breach

Design as if an attacker is already inside the perimeter. Contain the blast radius of a compromise.

| Mechanism | Purpose |
|---|---|
| mTLS between all services | A compromised service cannot impersonate another service |
| Tenant namespace isolation | A compromise of one tenant's service cannot reach another tenant's data |
| Short-lived credentials | Compromised credentials expire quickly; reduces the window of exploitation |
| Read-only service accounts where possible | A compromised read-only service account cannot modify data |
| Audit logging of all privileged actions | Compromise can be detected and its scope bounded post-incident |

---

## mTLS Implementation (Linkerd)

Linkerd provides automatic mTLS between all services in the mesh — no application code changes required. Every service-to-service connection is mutually authenticated and encrypted.

**How it works:**
1. Linkerd injects a sidecar proxy into every pod
2. All traffic between pods is intercepted by the sidecar proxies
3. The proxies establish mTLS connections using short-lived certificates issued by Linkerd's control plane
4. Application code communicates over localhost (unencrypted) to its own sidecar; the sidecar handles encryption

**What this provides:**
- Encryption in transit for all service-to-service communication
- Mutual authentication — both sides of every connection verify each other's identity
- Certificate rotation without application downtime (Linkerd manages the lifecycle)

**Verification:**
```bash
# Confirm mTLS is active between two services
linkerd viz edges deployment -n tenant-[id]
# Shows: all connections are mTLS (not plain text)
```

**Linkerd policy (deny by default):**
```yaml
# Default policy: deny all inbound traffic not explicitly permitted
apiVersion: policy.linkerd.io/v1beta2
kind: Server
metadata:
  name: classification-api
  namespace: tenant-[id]
spec:
  podSelector:
    matchLabels:
      app: classification-service
  port: 8080
  proxyProtocol: HTTP/2
---
apiVersion: policy.linkerd.io/v1beta2
kind: ServerAuthorization
metadata:
  name: allow-api-gateway
  namespace: tenant-[id]
spec:
  server:
    name: classification-api
  client:
    meshTLS:
      serviceAccounts:
        - name: api-gateway
          namespace: tenant-[id]
```

---

## JWT Authentication Design

All user-facing APIs authenticate via JWT Bearer tokens. The JWT carries the user's identity and claims — it is the credential for every API request.

**JWT structure:**

```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id-for-rotation"
  },
  "payload": {
    "sub": "user-uuid",
    "iss": "https://auth.[tenant-id].example.com",
    "aud": "https://api.[tenant-id].example.com",
    "exp": 1719316800,
    "iat": 1719313200,
    "tenant_id": "tenant-uuid",
    "email": "user@example.com",
    "roles": ["compliance-officer"],
    "permissions": ["data-assets:read", "compliance-gaps:read", "reports:generate"]
  }
}
```

**Rules:**
- Algorithm: RS256 (asymmetric) — never HS256 (symmetric shared secret)
- Expiry: 1 hour maximum
- Audience claim: scoped to the specific API — prevents token reuse across services
- Issuer claim: tenant-scoped identity provider — validated on every request, alongside the audience; a token from another tenant's issuer must fail even if its signature verifies against a shared key set
- Key rotation: signing keys rotated every 90 days; `kid` header enables graceful rotation
- Revocation: short expiry is the primary revocation mechanism; a revocation list for emergency invalidation

**Validation (Go middleware):**
```go
func JWTMiddleware(keySet jwk.Set) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token, err := jwt.ParseRequest(r,
                jwt.WithKeySet(keySet),
                jwt.WithValidate(true),
                jwt.WithIssuer("https://auth."+tenantID+".example.com"),
                jwt.WithAudience("https://api."+tenantID+".example.com"),
            )
            if err != nil {
                http.Error(w, "Unauthorized", http.StatusUnauthorized)
                return
            }
            ctx := context.WithValue(r.Context(), contextKeyToken, token)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

---

## Encryption at Rest

All data at rest is encrypted. Encryption is the last line of defence if physical media or backup storage is compromised.

| Data type | Encryption mechanism |
|---|---|
| PostgreSQL data files | Filesystem-level encryption (LUKS or cloud-provider managed) OR PostgreSQL Transparent Data Encryption |
| Backup files | AES-256 encrypted before upload to backup storage |
| Secrets (in secrets manager) | Secrets manager encrypts at rest using customer-managed keys (BYOK where required) |
| File contents (never stored) | File contents are never stored — only extracted metadata and entities are stored |

**Key management:**
- Encryption keys are never stored in application code, environment variables, or configuration files
- Keys are stored in a secrets manager (HashiCorp Vault or cloud-provider KMS)
- Per-tenant encryption keys — one tenant's key cannot decrypt another tenant's data
- Key rotation policy: annually, or immediately on suspected compromise

---

## Workload Identity (Service-to-Service)

Services authenticate to each other using workload identity — not username/password credentials.

In Kubernetes with Linkerd:
- Each service runs as a named Kubernetes ServiceAccount
- Linkerd issues short-lived mTLS certificates tied to the ServiceAccount identity (SPIFFE format: `spiffe://cluster.local/ns/[namespace]/sa/[serviceaccount]`)
- Authorisation policies check the ServiceAccount identity, not a shared secret

For external system authentication (Google Drive, AWS S3):
- OAuth 2.0 with short-lived access tokens
- Tokens stored in secrets manager; refreshed automatically before expiry
- Never stored in environment variables or application configuration

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| mTLS on all internal traffic | Linkerd policy configured; all inter-service traffic is mTLS | Any service-to-service HTTP without mTLS |
| JWT RS256 | All JWTs signed with RS256; HS256 not used | Any JWT using symmetric algorithms |
| Short JWT expiry | JWT expiry ≤ 1 hour | JWTs with multi-day or no expiry |
| Encryption at rest | All databases and backups encrypted | Any data store without encryption at rest |
| No secrets in code or env vars | All secrets injected at runtime from secrets manager | Secrets in Dockerfiles, env vars, or source code |
| Least-privilege service accounts | Each service has a dedicated ServiceAccount following the Principle of Least Privilege | Services sharing a ServiceAccount or using cluster-admin |
| Issuer and audience validated | JWT middleware validates `iss` and `aud` on every request | Signature-only validation |

---

## Anti-Patterns

- **Perimeter trust in disguise.** "It's inside the mesh, so we skip the JWT check." mTLS authenticates the *service*, not the *user* — a request arriving over mTLS still carries an unverified user identity until its JWT is validated. Each layer verifies its own concern.
- **HS256 "because it's simpler".** A symmetric signing secret must be shared with every service that validates tokens — any one of them can then mint tokens. RS256 keeps minting capability in the identity provider alone.
- **Signature-only JWT validation.** Verifying the signature but not `iss`, `aud`, and `exp`. A validly-signed token for a different audience or from a different issuer is still an attack token.
- **One ServiceAccount for everything.** A shared ServiceAccount collapses all workload identities into one — Linkerd ServerAuthorization can no longer distinguish callers, and the Principle of Least Privilege becomes unenforceable.
- **Long-lived credentials as convenience.** Multi-day JWTs, static database passwords, non-expiring API keys. Assume Breach prices every credential by its lifetime: a leaked one-hour token is an incident; a leaked one-year key is a catastrophe.
- **Allow-by-default with deny rules.** Writing policies that block known-bad callers instead of admitting known-good ones. Zero Trust Architecture is deny-by-default at every layer — network, mesh, and application.
- **Trusting the sidecar to do authorisation.** Linkerd authorises which *workload* may connect; it knows nothing about tenants, resources, or permissions. ABAC decisions stay in the application — the mesh is transport-layer identity only.

---

## Output Format

```markdown
---
name: zero-trust-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Zero Trust Design

## Identity Verification Matrix
| Identity type | Authentication mechanism | Token lifetime | Rotation policy |
|---|---|---|---|

## mTLS Policy
[Linkerd Server and ServerAuthorization resources per service]

## JWT Specification
[Algorithm, claims, expiry, audience, rotation policy]

## Encryption at Rest
| Data type | Mechanism | Key management | Rotation |
|---|---|---|---|

## Workload Identity
| Service | ServiceAccount | SPIFFE ID | External auth mechanism |
|---|---|---|---|

## Deny-by-Default Network Policy
[Linkerd or Kubernetes NetworkPolicy resources establishing deny-all baseline]
```
