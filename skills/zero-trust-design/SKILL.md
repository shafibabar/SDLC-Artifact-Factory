---
name: zero-trust-design
description: >
  Design a Zero Trust Architecture for a microservices system: the zero-trust
  model (never trust, always verify; the network is always hostile), the
  control-plane vs data-plane split, establishing trust independently in
  devices, users, and workloads, and dynamic context-aware policy. Covers the
  enforcement substrate — mTLS and workload identity via Linkerd (transport-layer
  identity only; the ABAC authorization decision stays in the application),
  JWT/OIDC user identity, deny-by-default NetworkPolicy micro-segmentation,
  per-tenant isolation as a trust boundary, and encryption at rest and in
  transit. Zero Trust Architecture is mandatory for every service. Used by the
  security-architect agent during the Design phase.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, zero-trust, mtls, jwt, linkerd, encryption, mandatory]
produces: zero-trust-design
domain: security
status: stable
related: [security-architecture, security-implementation, access-control-model, threat-modeling, secrets-management]
---

# Zero Trust Design

## Purpose

Zero Trust Architecture (NIST SP 800-207) is built on one axiom: **never trust, always verify**. No actor — user, service, or network location — is implicitly trusted. Every request is authenticated, authorised, and encrypted, regardless of whether it originates inside or outside the perimeter. The network is always assumed hostile: a packet from inside the Kubernetes cluster or the Linkerd mesh is exactly as untrusted as one from the public internet — a compromised pod in the same namespace is a hostile network participant.

Zero Trust Architecture is mandatory in this plugin. Its absence in any service is a security defect, not a future enhancement.

The conceptual model behind this design — the control-plane vs data-plane split, the policy engine and trust engine, independent trust in devices/users/workloads, and dynamic context-aware policy — lives in `references/zero-trust-principles.md`. The concrete enforcement substrate (Linkerd mTLS with worked policy, JWT specification and validation middleware, workload identity/SPIFFE, deny-by-default NetworkPolicy micro-segmentation, per-tenant isolation, encryption at rest) lives in `references/enforcement-and-mesh.md`.

## The Three Pillars

Zero Trust design in this plugin rests on three pillars. The full per-identity mapping tables for each are in `references/zero-trust-principles.md`.

- **Verify Explicitly.** Every request is authenticated and authorised, every time; location grants no implicit trust. User→service uses JWT; service→service uses mTLS certificate identity; service→database uses rotated service-account credentials; service→external uses short-lived OAuth tokens.
- **Least Privilege.** Every identity holds only the permissions its function requires — never "just in case." Scoped JWT claims enforced by ABAC, per-service database access only, scoped IaC credentials, time-limited audited admin access.
- **Assume Breach.** Design as if the attacker is already inside. Contain the blast radius: mTLS prevents service impersonation, tenant namespace isolation contains cross-tenant reach, short-lived credentials shrink the exploitation window, read-only accounts and audit logging bound and expose a compromise.

## The Authorization Boundary — the Decision That Governs Everything

The single most important design decision: **mTLS answers "who is calling?"; ABAC answers "may they do this?"** These are different planes and must never be conflated (see the control-plane/data-plane split in `references/zero-trust-principles.md`).

- **Data plane (transport enforcement).** Linkerd's sidecar proxies establish mTLS on every connection, giving each end a verified cryptographic *workload* identity. This proves *which service* connected — nothing about tenants, resources, or permissions.
- **Control plane (authorization decision).** The application's ABAC engine decides whether the request is permitted, consuming Subject/Resource/Action plus dynamic trust signals (token freshness, device posture, source-IP reputation) as Environment attributes. **The mesh never authorises.** A meshed connection succeeding is an identity fact, never a permission grant.

A request arriving over mTLS still carries an *unverified user identity* until its JWT is validated at the receiving service. The two identity planes — workload (Linkerd cert) and user (JWT) — are validated independently, per hop; never let a trusted workload identity launder an unvalidated user claim. See `references/enforcement-and-mesh.md`.

## Enforcement Layers (at a glance)

Every layer is deny-by-default. Worked configuration for each is in `references/enforcement-and-mesh.md`.

| Layer | Mechanism |
|---|---|
| Service → service transport | Automatic mTLS via Linkerd; deny-by-default `Server`/`ServerAuthorization` |
| User → service | JWT Bearer, RS256, ≤1h expiry, `iss`+`aud` validated every request |
| Workload identity | Kubernetes ServiceAccount + Linkerd-issued SPIFFE certificate |
| Network segmentation | Deny-by-default NetworkPolicy; only identity-to-identity paths a service needs |
| Tenant isolation | Physical per-tenant namespace as an independent failure domain |
| Data at rest / in transit | Per-tenant encryption keys in a secrets manager; mTLS/TLS on the wire |

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
| Authorization stays in the app | ABAC decision made in the application on every request | Mesh/mTLS success treated as authorization |

## Anti-Patterns

- **Perimeter trust in disguise.** "It's inside the mesh, so we skip the JWT check." mTLS authenticates the *service*, not the *user* — a request arriving over mTLS still carries an unverified user identity until its JWT is validated. Each layer verifies its own concern.
- **HS256 "because it's simpler".** A symmetric signing secret must be shared with every service that validates tokens — any one of them can then mint tokens. RS256 keeps minting capability in the identity provider alone.
- **Signature-only JWT validation.** Verifying the signature but not `iss`, `aud`, and `exp`. A validly-signed token for a different audience or from a different issuer is still an attack token.
- **One ServiceAccount for everything.** A shared ServiceAccount collapses all workload identities into one — Linkerd ServerAuthorization can no longer distinguish callers, and the Principle of Least Privilege becomes unenforceable.
- **Long-lived credentials as convenience.** Multi-day JWTs, static database passwords, non-expiring API keys. Assume Breach prices every credential by its lifetime: a leaked one-hour token is an incident; a leaked one-year key is a catastrophe.
- **Allow-by-default with deny rules.** Writing policies that block known-bad callers instead of admitting known-good ones. Zero Trust Architecture is deny-by-default at every layer — network, mesh, and application.
- **Trusting the sidecar to do authorisation.** Linkerd authorises which *workload* may connect; it knows nothing about tenants, resources, or permissions. ABAC decisions stay in the application — the mesh is transport-layer identity only.
- **Policy expressed against network topology.** Writing authorization against source IP, namespace, or port instead of logical identities and attributes. Topology drifts; identity-and-attribute policy is evaluated fresh per request and stored as reviewable code (GitOps).

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
