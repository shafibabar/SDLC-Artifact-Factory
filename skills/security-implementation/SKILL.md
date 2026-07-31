---
name: security-implementation
description: >
  Teaches the security-engineer and backend-engineer to implement application-security controls in Go —
  input validation (allowlist, validate at every trust boundary), output/contextual encoding,
  authentication and session management, server-side authorization with ABAC (deny by default, IDOR
  prevention), the OWASP Top 10 mapped to concrete Go+chi+pgx controls, secrets handling, security
  logging and audit/attestation emission, secure defaults and least-privilege API design. Every control
  traces back to the STRIDE threat it discharges. Used during Implement for every service handling
  untrusted input or sensitive data.
version: 2.0.0
phase: implement
owner: security-engineer
created: 2026-06-25
related:
  - access-control-model
  - security-architecture
  - zero-trust-design
  - threat-modeling
  - secrets-management
  - compliance-verification
  - privacy-design
  - glossary-management
tags: [implement, security, owasp, input-validation, authentication, authorization, abac, secure-coding, audit-log, go]
---

# Security Implementation

Translate the security architecture into working, auditable Go code. Controls are built correctly the
first time and tested — never bolted on after a review. This is a *push-left* discipline: validated
input, encoded output, server-side authorization, no secrets in code or logs, and a security-event log
are as much a merge gate as passing tests (Janca, *Alice and Bob Learn Application Security*).

This body holds the decision-shaping rules — the one non-negotiable rule per control category, the
STRIDE traceability principle, and pointers into `references/` for the full Go patterns, the OWASP map,
and the audit/attestation deliverables.

---

## The Seven Control Categories — One Rule Each

Every service handling untrusted input or sensitive data must satisfy all seven. The rule is the thing
you cannot get wrong; the reference file holds the code.

| # | Category | The one rule | Full pattern |
|---|---|---|---|
| 1 | **Input validation** | **Allowlist** at **every** trust boundary — accept the known-good shape (type, length, range, format, set membership), reject everything else. A denylist always loses to an encoding it missed. | `references/secure-coding-go.md` |
| 2 | **Output encoding** | Encode **contextually, at the sink** — HTML, JS, URL, SQL, log line, and HTTP header each need a *different* encoding. This is a **separate** control from validation and does not substitute for it. | `references/secure-coding-go.md` |
| 3 | **Authentication & sessions** | Validate the JWT against the server's JWKS (algorithm pinned server-side, `aud`/`iss`/`exp` mandatory); harden any browser-held cookie (`HttpOnly; Secure; SameSite`), regenerate session IDs on auth, enforce idle + absolute timeouts. | `references/authn-authz.md` |
| 4 | **Authorization** | **Server-side, deny by default, per request, per object.** Absence of an explicit grant is a denial. Every resource-by-ID access checks ownership of *that* object (IDOR/BOLA). UI hiding is never a control. | `references/authn-authz.md` |
| 5 | **Secrets** | Never in source, committed config, or logs — injected from a secrets manager, wrapped in a redacting type at the point of read, and rotatable/revocable. | `references/secure-coding-go.md` + `secrets-management` |
| 6 | **Security logging** | Log security **events** (authN outcome, authZ denial, validation rejection, privilege change); **never** log secrets, session tokens, or PII; encode user-controlled values so a newline can't forge a log line. | `references/audit-and-evidence.md` |
| 7 | **Secure defaults** | The out-of-the-box configuration is the safe one — an operator opts *into* risk. Least functionality, least-privilege API surface, security headers on, errors that leak nothing. | `references/secure-coding-go.md` |

---

## Every Control Names the Threat It Discharges (STRIDE traceability)

A control with no named threat is decoration; a threat with no control is an unmet requirement. Trace
each implemented control back to the STRIDE letter it mitigates (Shostack, *Threat Modeling*), so a
reviewer can see what breaks if the control is removed:

| STRIDE letter | Violated property | Concrete control in this stack |
|---|---|---|
| **S**poofing | Authentication | JWT validation against JWKS; Linkerd mTLS peer identity |
| **T**ampering | Integrity | pgx parameterized writes; Transactional Outbox; signed events |
| **R**epudiation | Non-repudiation | Append-only, hash-chained audit log; OpenTelemetry spans |
| **I**nformation disclosure | Confidentiality | ABAC filtering; contextual output encoding; PII never persisted as raw text |
| **D**enial of service | Availability | Rate limiting; Redpanda backpressure; Circuit Breaker |
| **E**levation of privilege | Authorization | `AccessPolicy.Evaluate` deny-by-default check; per-tenant scoping |

The OWASP Top 10 → concrete Go control → STRIDE letter map (the audit-friendly control list) lives in
`references/owasp-controls.md`. Use it as the coherence check: the skill's scattered controls should
read as one answer to a recognized threat set, not a bag of independent patterns.

---

## The Authorization Boundary: mTLS Answers *Who*, ABAC Answers *What*

The network is always assumed hostile — a compromised pod on the same namespace is a hostile
participant (Gilman & Barth, *Zero Trust Networks*). Do not conflate the two planes:

- **Data plane (Linkerd mTLS):** transport-layer *identity* + encryption. A meshed connection
  succeeding proves *who* connected. It is an identity fact, **never** a permission grant.
- **Control plane (the application's ABAC engine):** the authorization *decision*. Every `allow/deny`
  stays here, re-evaluated per request against `Subject`/`Resource`/`Action`/`Environment`.

For any server-to-server call, require *both* a verified workload identity (Linkerd cert) *and* a
re-validated propagated user `Subject` (the JWT) — a receiving service re-derives the `Subject` from
the token; it never trusts an upstream service's assertion of it. Trust-engine signals (token
freshness, device posture, IP reputation) feed ABAC as `Environment` attributes so a structurally-valid
request from a low-trust context can still be denied. Full middleware, claims→`Subject` parsing, and
the two-identity-plane pattern: `references/authn-authz.md`.

---

## One Constructor for the Subject, Not Two

The JWT validation middleware and `access-control-model`'s `SubjectFromContext` must agree on a
**single** claims→`Subject` construction path built from Domain Primitives (`TenantID`, `Permission`),
not two independent parses of the same claims (Johnsson/Deogun/Sawano, *Secure by Design*). Validity is
a *type* guarantee established once at the boundary — downstream code receives only well-formed data and
never re-checks. This is the "parse, don't validate" discipline. Where the constructor lives and how it
aligns across the two skills: `references/authn-authz.md`.

---

## Least Privilege in Depth, Breakglass, and Revocation

From Adkins & Beyer, *Building Secure and Reliable Systems* (see `references/authn-authz.md` and
`references/secure-coding-go.md`):

- **Small functional APIs.** Expose intent-named operations (`ClassifyDataAsset`), not a general
  `RunQuery` — the authority a compromised caller holds is bounded by the surface it can reach.
- **Breakglass, not a standing backdoor.** Emergency elevated access is an explicit, time-boxed,
  justification-gated path that emits a high-priority audit event — never a permanent admin credential.
- **Revocation is a tested capability.** "The token will expire" is an incomplete answer; document and
  test the emergency path that invalidates a leaked JWT, cert, or customer Drive/S3 OAuth grant, with a
  stated propagation bound.
- **Fail secure, decided per subsystem.** When a security dependency is unavailable (JWKS unreachable,
  policy store times out), the default is **never** allow. Resolve the availability-vs-confidentiality
  tension explicitly in the error path, not by whatever the code happens to do.

---

## Secure Defaults Are Inherited, Not Re-Checked

Capture the hardened posture — deny-by-default ABAC middleware order, security headers, append-only
audit role, non-root SecurityContext, default-deny NetworkPolicy — as a template a new service
*inherits*, so a service is secure by omission and relaxation is the logged exception. Middleware order
is explicit and load-bearing: **security headers → auth → rate limit → handler** (rate limiting keyed
on user ID before auth reads an empty subject and collapses all anonymous traffic into one bucket).

---

## Audit and Attestation as Implementation Deliverables

The append-only, hash-chained audit log (structured fields, never PII/secrets, INSERT-only DB role,
per-tenant serialized appends) and the signed CI pipeline attestations (SLSA/in-toto-style provenance
feeding the evidence ledger) are code this skill produces, not design notes. Both tie to
`compliance-verification` as verifiable SOC 2 evidence. Full schema, hash-chain concurrency handling,
and attestation emission: `references/audit-and-evidence.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Input validated as allowlist at every boundary | Handler, Redpanda consumer, ingestion worker each parse-and-validate | Validation only at the HTTP handler, or a denylist |
| Output encoded contextually at the sink | Per-sink encoding; no `dangerouslySetInnerHTML` on ingested data | Injection treated as an input-only problem |
| JWT validated server-side | `jwt.WithKeySet` RSA; `aud`/`iss`/`exp` required | HS256, `alg` from token, or missing claim checks |
| Authorization server-side, deny-by-default, IDOR-safe | Policy in application layer; per-object ownership check | Policy at API layer only, or authentication mistaken for authorization |
| Single `Subject` constructor | Middleware and `SubjectFromContext` share one path | Two independent claim parses that can diverge |
| No panics on malformed input | Claim extraction returns errors; no `MustParse` | Attacker-controlled data can panic a handler |
| Secrets never in code/logs | Injected + redacting type at point of read | Secret as bare `string`, or logged |
| Audit append-only + hash-chained | INSERT-only role; serialized per-tenant appends | Audit table mutable by the app role, or forked chain |
| Every control names a STRIDE threat | Control → STRIDE letter traced | Control with no threat rationale |

---

## Anti-Patterns

- **Treating a meshed (mTLS) connection as authorization.** It proves *who*, never *what they may do*.
- **Trusting an upstream service's asserted `Subject`.** Re-derive it from the JWT at every hop.
- **Two claim parsers.** The middleware and `SubjectFromContext` diverging on how a token becomes a
  `Subject` is a latent authorization bug — one constructor.
- **Input validation standing in for output encoding** (or the reverse). They are distinct controls.
- **`fmt.Sprintf` SQL "just this once."** pgx `$N` for values; a fixed allowlist map for identifiers.
- **Distinguishing denial reasons to the caller.** One `ErrForbidden` outward; the specific reason to
  the server log only.
- **Logging the token, claims, or any PII.** A leaked log becomes a replayable credential/disclosure sink.
- **Breakglass as a standing admin credential** instead of a designed, audited, expiring path.
- **"The network already isolates this"** used to skip a domain-level check — every layer enforces its
  own boundary (defense in depth is not an excuse for a shallow model).

---

## Output Format

This skill produces real Go files, not a design document:

```
internal/handlers/middleware/auth.go
internal/handlers/middleware/security_headers.go
internal/handlers/middleware/rate_limiter.go
internal/domain/policy.go
internal/infrastructure/audit/log.go
internal/infrastructure/secrets/secret.go
.github/workflows/attest.yml
tests/security/auth_test.go
tests/security/abac_test.go
tests/security/idor_test.go
tests/security/sql_injection_test.go
```
