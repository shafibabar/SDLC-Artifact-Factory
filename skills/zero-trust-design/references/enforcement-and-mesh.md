# Enforcement Substrate — mTLS, Workload Identity, and Micro-Segmentation

This reference holds the concrete enforcement configuration for
`zero-trust-design`. mTLS is the practical mechanism that makes zero trust real
on the wire: every connection is mutually authenticated with certificates,
giving both ends a verified cryptographic identity and encrypting the transport.
Crucially, the certificate *is* the workload's identity — trust is bound to a
short-lived, rotatable credential, not to an IP or DNS name that can be spoofed.

**The load-bearing boundary:** mTLS answers *"who is this?"* at the transport
layer; it does **not** answer *"is this actor allowed to do this?"*. That
authorization question lives above the transport, in the application's ABAC
policy engine. A meshed connection succeeding proves *who* connected, never
*what they may do*.

---

## mTLS Implementation (Linkerd)

Linkerd provides automatic mTLS between all services in the mesh — no
application code changes required. Every service-to-service connection is
mutually authenticated and encrypted.

**How it works:**

1. Linkerd injects a sidecar proxy into every pod.
2. All traffic between pods is intercepted by the sidecar proxies.
3. The proxies establish mTLS connections using short-lived certificates issued
   by Linkerd's control plane.
4. Application code communicates over localhost (unencrypted) to its own
   sidecar; the sidecar handles encryption.

**What this provides:**

- Encryption in transit for all service-to-service communication.
- Mutual authentication — both sides of every connection verify each other's
  identity.
- Certificate rotation without application downtime (Linkerd manages the
  lifecycle).

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

All user-facing APIs authenticate via JWT Bearer tokens. The JWT carries the
user's identity and claims — it is the credential for every API request.

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

- Algorithm: RS256 (asymmetric) — never HS256 (symmetric shared secret).
- Expiry: 1 hour maximum.
- Audience claim: scoped to the specific API — prevents token reuse across
  services.
- Issuer claim: tenant-scoped identity provider — validated on every request,
  alongside the audience; a token from another tenant's issuer must fail even if
  its signature verifies against a shared key set.
- Key rotation: signing keys rotated every 90 days; `kid` header enables
  graceful rotation.
- Revocation: short expiry is the primary revocation mechanism; a revocation
  list for emergency invalidation.

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

## Workload Identity (Service-to-Service)

Services authenticate to each other using workload identity — not
username/password credentials.

In Kubernetes with Linkerd:

- Each service runs as a named Kubernetes ServiceAccount.
- Linkerd issues short-lived mTLS certificates tied to the ServiceAccount
  identity, in SPIFFE format:
  `spiffe://cluster.local/ns/[namespace]/sa/[serviceaccount]`.
- Authorisation policies check the ServiceAccount identity, not a shared secret.

For external system authentication (Google Drive, AWS S3):

- OAuth 2.0 with short-lived access tokens.
- Tokens stored in a secrets manager; refreshed automatically before expiry.
- Never stored in environment variables or application configuration. Treat a
  customer's Drive/S3 OAuth grant as a standing privilege that must be scoped,
  time-boxed, and revocable.

---

## NetworkPolicy Micro-Segmentation

Default-deny all service-to-service traffic and open only the specific
identity-to-identity paths a service actually needs (e.g. `pii-extraction` may
receive from `data-classification` and nothing else). This bounds the blast
radius so a single compromised workload identity cannot reach the whole estate.

Express the segmentation against *logical identity* (ServiceAccount, workload
labels), never source IP or port, and store it as versioned code reviewed like
any other source (GitOps) — so policy is auditable and diffable rather than
living in mutable NetworkPolicy state that drifts. NetworkPolicy is the
Kubernetes-layer deny-all baseline; Linkerd `Server`/`ServerAuthorization`
(above) is the identity-aware layer on top. Both are deny-by-default.

---

## Per-Tenant Isolation as a Trust Boundary

Physical per-tenant namespace isolation is an independent **failure domain**: a
compromise of one tenant's service cannot reach another tenant's data even if an
in-tenant control (e.g. an ABAC check) fails. This is defence in depth by design
— two independent containment layers, neither trusting the other:

- **Physical isolation** contains cross-tenant blast radius at the deployment
  layer.
- **Per-workload zero-trust identity + micro-segmentation** contains blast
  radius *within* a tenant's deployment.

Read these as complementary, not redundant: micro-segmentation contains a breach
inside a tenant; physical isolation contains it across tenants.

---

## Encryption at Rest

All data at rest is encrypted. Encryption is the last line of defence if
physical media or backup storage is compromised.

| Data type | Encryption mechanism |
|---|---|
| PostgreSQL data files | Filesystem-level encryption (LUKS or cloud-provider managed) OR PostgreSQL Transparent Data Encryption |
| Backup files | AES-256 encrypted before upload to backup storage |
| Secrets (in secrets manager) | Secrets manager encrypts at rest using customer-managed keys (BYOK where required) |
| File contents (never stored) | File contents are never stored — only extracted metadata and entities are stored |

**Key management:**

- Encryption keys are never stored in application code, environment variables, or
  configuration files.
- Keys are stored in a secrets manager (HashiCorp Vault or cloud-provider KMS).
- Per-tenant encryption keys — one tenant's key cannot decrypt another tenant's
  data.
- Key rotation policy: annually, or immediately on suspected compromise.
