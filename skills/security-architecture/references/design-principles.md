# The Four Security Design Principles — In Depth

Reference for `security-architecture`. The body names the four principles (Adkins & Beyer,
*Building Secure and Reliable Systems*) in one line each; this file is the depth: concrete
mechanisms, the invariants each principle protects, and how each grounds onto this repo's stack
(Go + chi + pgx + Redpanda, Linkerd mesh, physical per-tenant isolation, PII entity-extraction
where raw file contents are never persisted).

The organizing thesis of the source: **security and reliability are the same discipline viewed
under adversity** — both are emergent properties of a whole system, not features bolted on.
Reliability is behavior under random failure; security is behavior under an intelligent adversary
who *chooses* the worst failure. The same failure-domain analysis feeds both. A design that fails
open under load (reliability instinct) and one that fails closed under attack (security instinct)
are in direct tension, and that tension must be resolved *explicitly per subsystem* — not left to
whichever middleware runs last.

---

## Principle 1 — Least Privilege (in depth)

Least privilege is not "set RBAC roles narrowly." It is a design discipline applied at **every**
layer, so the authority a compromised caller can wield is bounded by the surface it can reach.

### Small functional APIs

Expose narrow, intent-named operations, not general-purpose ones. A service should offer
`ClassifyDataAsset` or `ExtractEntities`, never a general `RunQuery` or `ExecuteJob`. The privilege
a compromised caller holds is bounded by the *surface it can call*. Audit each service's public API
for any operation broad enough that holding it grants more authority than the caller's role needs.

```go
// GOOD — intent-named, authority bounded by the operation itself.
type Classifier interface {
    ClassifyDataAsset(ctx context.Context, id DataAssetID) (Classification, error)
    ExtractEntities(ctx context.Context, id DataAssetID) (EntitySummary, error)
}

// ANTI-PATTERN — a general surface that laundries arbitrary authority.
type Backend interface {
    RunQuery(ctx context.Context, sql string) (Rows, error) // any table, any tenant
}
```

### Breakglass — emergency access as a designed, audited path

Tight least privilege creates an incentive to leave a permanent backdoor "just in case." The
answer is **breakglass**: an explicit, time-boxed, second-party- or justification-gated emergency
escalation that emits a high-priority audit event on use and auto-expires. This turns "we left an
admin credential around" into a reviewable, logged, revocable capability. Wire its audit event into
the **same non-repudiation hash chain** the audit log already uses, so an emergency escalation is
never off-ledger.

```go
// Breakglass grant: time-boxed, justified, second-party approved, auto-expiring.
type BreakglassGrant struct {
    Subject     SubjectID
    Justification string       // required, recorded verbatim
    ApprovedBy   SubjectID     // must differ from Subject (second party)
    IssuedAt     time.Time
    ExpiresAt    time.Time     // short — minutes to a single incident window
}

func GrantBreakglass(req BreakglassRequest, audit AuditChain) (BreakglassGrant, error) {
    if req.ApprovedBy == req.Subject {
        return BreakglassGrant{}, errors.New("breakglass requires a second-party approver")
    }
    if req.Justification == "" {
        return BreakglassGrant{}, errors.New("breakglass requires a recorded justification")
    }
    g := BreakglassGrant{
        Subject: req.Subject, Justification: req.Justification,
        ApprovedBy: req.ApprovedBy, IssuedAt: time.Now(),
        ExpiresAt: time.Now().Add(15 * time.Minute),
    }
    // High-priority audit event into the existing hash-chained audit log.
    audit.AppendPriority("breakglass.granted", g)
    return g, nil
}
```

### Third-party trust as an explicit privilege grant

For this product, "third-party trust" is load-bearing: an OAuth token for a customer's Google Drive
or an S3 access grant is a **standing privilege**, not an ambient assumption. Every such grant must
be scoped (only the resources ingestion actually needs), time-boxed, and **revocable**. Treat a
long-lived, broad third-party grant as a defect.

### The invariant least-privilege protects

> No caller ever holds authority beyond the minimum its role requires; no standing credential or
> third-party grant is broader or longer-lived than the task that needs it.

---

## Principle 2 — Understandability (in depth)

A system whose security you cannot reason about is not secure — because you cannot tell whether a
change breaks it. Understandability is what makes security review *possible*.

### Invariants that hold regardless of attacker action

Security rests on a small set of **invariants** — properties that must hold no matter what an
attacker does. Security review is then the concrete act of confirming each change preserves every
invariant. State them explicitly; annotate each control in the Security Control Matrix with *which
invariant it preserves*. A control preserving no stated invariant is decoration; an invariant with
no control is an unmet requirement.

Worked invariants for this repo:

| # | Invariant | Preserving controls |
|---|---|---|
| INV-1 | A request is never processed under a tenant other than its validated JWT's `tenant_id`. | JWT validation, ABAC tenant check, physical namespace isolation |
| INV-2 | A secret value never crosses the process boundary as plaintext. | `Secret` redaction type, TLS in transit, no env-var secrets |
| INV-3 | An audit entry is never mutated or deleted once written. | append-only table, INSERT-only DB role, hash chain |
| INV-4 | Raw extracted file contents are never persisted — only entity *types* and *counts*. | `ExtractedEntitySummary` type with no raw-text constructor path |
| INV-5 | An authorization decision is made in the application, never inferred from network position. | ABAC `Evaluate` at Layer 5; deny-by-default policy |

### Minimize complexity; keep the trusted computing base small

Prefer a design a reviewer can hold in their head. Secure-by-default is the corollary: the safe
configuration must be the one you get by *doing nothing* — hardening must not depend on every
operator remembering every flag. Capture the hardened posture (deny-by-default NetworkPolicy,
non-root SecurityContext, ABAC-on middleware order, security headers, append-only audit role) as a
**secure-default service template a new service inherits**, so a service is secure by omission and
relaxation is the explicit, logged exception.

### The invariant understandability protects

> Every change to the system can be reviewed against a small, written set of invariants, and a
> reviewer can determine — without running it — whether the change preserves them.

---

## Principle 3 — Defense in Depth (in depth)

Sharpen "defense in depth" past the layered-controls cliché into **failure-domain** design.

### Distinct, independent failure domains

Partition the system so a compromise is *contained* to a domain, and the **blast radius** of any
single failure (a leaked credential, a compromised pod, a poisoned dependency) is bounded and known
in advance. Each physical per-tenant namespace *is* a failure domain — the security architecture
should state, per threat: "what is the blast radius if this control fails, and which independent
domain contains it?"

Worked blast-radius statements:

| Threat | Blast radius if primary control fails | Independent containing domain |
|---|---|---|
| Cross-tenant data leak | one tenant's classified DataAssets become readable | physical namespace isolation still contains it |
| Compromised `pii-extraction` pod | that workload's least-privilege grants only | micro-segmentation (NetworkPolicy) + per-workload identity |
| Leaked Drive OAuth token | one customer's source documents at the third party | token scope + time-box + revocation path |

### Fail safe vs. fail secure

A failure domain must have a **defined, tested behavior under failure that never defaults to
granting access**. Decide per subsystem what happens when a security dependency is unavailable —
JWKS endpoint unreachable, ABAC policy store times out. Where availability and confidentiality
conflict (failing open keeps the service up but drops the check), resolve the tension explicitly in
the design and record the reasoning — do not leave it to whatever the code happens to do on error.

```go
// Fail-secure: an unreachable policy store denies, it never allows.
dec, err := policy.Evaluate(ctx, subject, resource, action)
if err != nil {
    // record the fail-secure decision; never default to allow
    return Deny, fmt.Errorf("policy store unavailable, failing secure: %w", err)
}
```

### The invariant defense-in-depth protects

> No single control failure yields a complete breach; every critical asset is contained by at least
> one independent failure domain whose blast radius is stated in advance.

---

## Principle 4 — Design for Recovery (in depth)

Assume compromise is inevitable and ask how fast and cleanly you can return to a known-good state.

### Rate-limiting

Rate-limit to *slow an in-progress attack* and buy detection time. This is a security lever, not
only a capacity one — a suddenly high rate of authorization *denials* or classification requests
from one identity is both an attack signal and a throttle point.

### Revocation as a first-class, tested capability

For every standing credential and third-party grant — JWTs, Linkerd certificates, dynamic DB
secrets, customer Drive/S3 OAuth tokens — document *and test* the emergency revocation path: how it
is triggered and the **maximum propagation time** between "revoke" and the credential being
universally rejected. Short-lived credentials bound the worst case; an actual revocation path
shortens it further. "We rely on the token expiring" is an incomplete answer.

| Credential | Revocation trigger | Stated propagation bound |
|---|---|---|
| User JWT | IdP revocation list / short `exp` + denylist | ≤ token TTL, or immediate via denylist |
| Linkerd workload cert | rotate issuer / evict pod | ≤ cert rotation interval |
| Drive/S3 OAuth grant | revoke at provider + purge stored token | immediate at provider; ≤ next ingestion cycle locally |

### Root-cause over rollback

Distinguish **rolling back** (returning to a prior state — which may *reintroduce* the
vulnerability) from **root-causing** (understanding and fixing why the compromise was possible).
Rollback is a reliability reflex; for a security incident it can restore the exploitable condition.
Record the immediate containment and the root-cause fix as separate, tracked actions.

### The invariant recovery protects

> Every standing credential and grant has a tested revocation path with a known propagation bound,
> and incident recovery never silently reintroduces the breached condition.

---

## How the principles feed the Security Control Matrix

- **Least privilege** → the Control column's authority-scoping controls and the small-API design of
  each service in scope.
- **Understandability** → the **Invariants** section; every matrix row cites the invariant it
  preserves.
- **Defense in depth** → the **blast-radius** and **containing-failure-domain** columns.
- **Recovery** → `monitor`-mode controls, revocation runbooks, and the rate-limit controls that buy
  detection time.

A security design review (the `methodology-review` criteria) asks three questions this framework
answers: does each change preserve every stated invariant? is the blast radius bounded and stated?
is there a tested recovery/revocation path?
