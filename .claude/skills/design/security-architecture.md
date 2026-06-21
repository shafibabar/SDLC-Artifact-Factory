# Skill: design/security-architecture

## Purpose
Produce the Security Architecture document — the top-level design of all security controls: Zero Trust network model, authentication, authorisation, encryption, secrets management, and security monitoring. This document is the security baseline that all implementation must conform to.

## Inputs
- `sdlc-config.json` (compliance_frameworks, tenancy_model, deployment_target)
- `artifacts/design/architecture/c4-container.md`
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/data/data-classification.md`

## Output
**File:** `artifacts/design/security/security-architecture.md`
**Registers in manifest:** yes

## Security Architecture Rules (enforced)
- Zero Trust: no implicit trust based on network location. Every request is authenticated and authorised.
- mTLS via Linkerd on all pod-to-pod communication within product infrastructure.
- JWT tokens are short-lived (max 1 hour). Refresh tokens are rotated on use.
- Secrets are never in environment variables, config files, or code. Only secrets manager references.
- All C4 data is encrypted at rest (AES-256-GCM) and in transit (TLS 1.3).
- Principle of least privilege applies to all service accounts, IAM roles, and user roles.
- Security controls are automated — not a checklist that humans run manually.

## Artifact Template

```markdown
# Security Architecture

**Product:** {product_name}
**Phase:** Design
**Artifact:** Security Architecture
**Version:** 1.0
**Date:** {date}
**Compliance frameworks:** {from sdlc-config}
**Status:** Draft

---

## Security Model: Zero Trust

The product assumes no implicit trust. Every request — regardless of source network — is:
1. **Authenticated** — identity is verified via JWT (external) or mTLS (internal)
2. **Authorised** — permissions are checked against the ABAC policy for the specific resource and action
3. **Logged** — every access is recorded in the immutable audit trail

**Perimeter security is NOT relied upon.** A compromised pod on the same Kubernetes node has no implicit access to other pods.

---

## Authentication Design

### External (User-facing)
- **Protocol:** OIDC / OAuth 2.0
- **Token type:** JWT (signed RS256)
- **Token lifetime:** Access token 1 hour; Refresh token 24 hours
- **Refresh token rotation:** Yes — each refresh invalidates the previous refresh token
- **Identity provider:** Customer's existing IdP (Okta, Azure AD, Google Workspace) — the product does not store passwords
- **Claims required in JWT:** `tenant_id`, `user_id`, `email`, `roles[]`, `iat`, `exp`
- **Token validation:** Every API Gateway request validates JWT signature, expiry, and `tenant_id` claim

### Internal (Service-to-Service)
- **Protocol:** mTLS (mutual TLS) via Linkerd service mesh
- **Certificate management:** Linkerd issues and rotates workload certificates automatically (every 24 hours)
- **No bearer tokens between internal services** — identity is the workload certificate

### Worker Node (Customer Infrastructure → Product Control Plane)
- **Protocol:** mTLS with client certificate issued at provisioning time
- **Certificate rotation:** Automated; certificate lifetime 90 days; rotation workflow documented
- **Outbound only:** Worker Node initiates all connections to the product control plane. No inbound connections from the product to the customer network.

---

## Authorisation Design (ABAC)

### Model: Attribute-Based Access Control (ABAC)

Every authorisation decision evaluates:
- **Subject attributes:** `user_id`, `roles[]`, `tenant_id`
- **Resource attributes:** `resource_type`, `resource_id`, `tenant_id`, `classification`
- **Action:** `read`, `write`, `delete`, `admin`
- **Environment:** `time_of_day`, `request_ip_risk_score`

### Role Definitions

| Role | Permissions |
|------|------------|
| `tenant_admin` | All actions on all resources within the tenant |
| `compliance_officer` | Read all findings; write exception acknowledgements; read audit trail |
| `viewer` | Read findings and dashboards; no write access |
| `auditor` | Read audit trail and compliance posture only; no operational access |
| `api_service_account` | Programmatic API access; scope defined per service account |

### Tenant Isolation Enforcement
- Every API request includes `tenant_id` from the validated JWT
- The ABAC policy engine rejects any request where the resource's `tenant_id` ≠ the JWT's `tenant_id`
- This is enforced at the API Gateway and again at the service layer (defence in depth)

---

## Encryption Design

### At Rest
| Data | Tier | Mechanism |
|------|------|-----------|
| PostgreSQL data | All | PostgreSQL `pg_tde` (Transparent Data Encryption) or filesystem-level encryption (LUKS on host) |
| C4 fields (PII) | C4 | Application-level field encryption (AES-256-GCM) before database write |
| Elasticsearch indices | C2-C3 | Index-level encryption (Elasticsearch Security) |
| Object storage (backups) | C2-C4 | SSE with customer-managed keys (CMK) |
| Secrets Manager | C4 | Customer-operated (AWS KMS, HashiCorp Vault — encryption at rest by default) |

### In Transit
| Channel | Mechanism |
|---------|-----------|
| External (user browser → product) | TLS 1.3; HSTS enforced |
| Internal (pod-to-pod) | mTLS via Linkerd (automatic) |
| Product → Customer storage APIs | TLS 1.3 (platform-enforced) |
| Worker Node → Product control plane | mTLS (mutual) |
| Product → Customer secrets manager | TLS 1.3 + IAM/SDK auth |

---

## Secrets Management

**Rule: No secrets in environment variables, config files, or source code.**

| Secret type | Storage | Access mechanism |
|-------------|---------|-----------------|
| Storage platform credentials | Customer-operated Secrets Manager | Read at scan time via SDK with read-only IAM role |
| Database connection strings | Kubernetes Secret (sealed with Sealed Secrets / ESO) | Mounted as env var by Kubernetes; rotated via operator |
| Redpanda credentials | Kubernetes Secret | Mounted at startup; rotated via operator |
| JWT signing key (RS256 private) | Kubernetes Secret | Loaded at Identity Service startup; never exposed via API |
| Worker Node mTLS certificate | Customer Secrets Manager (reference) | Loaded at Worker Node startup |
| Internal service TLS certs | Linkerd (auto-managed) | Injected by Linkerd proxy; not application-managed |

---

## Security Monitoring

| Control | Mechanism | Alert threshold |
|---------|-----------|----------------|
| Failed authentication attempts | Audit trail + Elasticsearch alert | >5 failures in 1 minute for same user |
| Privilege escalation attempts | ABAC decision log (DENY) + alert | Any DENY on admin action |
| Cross-tenant access attempt | ABAC tenant_id mismatch → DENY + alert | Any occurrence |
| Anomalous API access pattern | Elasticsearch ML anomaly detection | Baseline deviation >3σ |
| DLQ depth | Prometheus alert | >0 messages in DLQ for >5 minutes |
| Certificate expiry | Linkerd metrics → Prometheus | <7 days before expiry |

---

## Security Non-Negotiables (Architectural Constraints)

1. File content NEVER transits product infrastructure — WorkerNodes execute in customer environment
2. Credentials are NEVER stored inline — only references to customer-operated Secrets Manager
3. mTLS is ALWAYS active on internal communications — no plaintext internal HTTP
4. Tenant isolation is enforced at EVERY layer — network, database, application, API
5. All C4 data access is audited — no read of PII without an audit entry
```

## Quality Checks
- [ ] Zero Trust model is stated and all three properties (authenticate, authorise, log) are implemented
- [ ] mTLS is specified for all internal pod-to-pod communication
- [ ] No secrets in environment variables or config — only secrets manager references
- [ ] ABAC roles are defined with specific permissions
- [ ] Cross-tenant access prevention is documented at multiple layers
- [ ] Encryption at rest and in transit covers all data tiers
- [ ] Security monitoring alerts are defined with threshold values
