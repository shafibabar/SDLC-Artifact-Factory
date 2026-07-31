# Classification-to-Controls Mapping and Downstream Handoff

Reference for `data-classification`. The full mapping from each sensitivity level to concrete,
mechanically-enforced controls — access, encryption, retention, masking/redaction, and audit — plus
the explicit handoff contract to `access-control-model` and `data-retention-policy`. A classification
scheme that no control consumes is documentation theatre; this file is what makes the scheme real.

Grounded in DAMA-DMBOK's Data Security KA, Secure-by-Design, and this repo's stack (chi + pgx +
Postgres, Linkerd mTLS, ABAC-over-JWT, physical per-tenant isolation).

---

## 1. The full control mapping

| Level | Access control | Encryption | Retention | Masking / redaction | Audit |
|---|---|---|---|---|---|
| **Public** | Authn optional | In transit (mTLS) | Standard | None | Standard |
| **Internal** | Authn required | In transit (mTLS) | Standard | None | Standard |
| **Confidential** | ABAC permission required (`data-assets:read`) | At rest + in transit | Defined per category | Masked on export/download | Writes audited |
| **Restricted** | ABAC permission **+ tenant check + Principle of Least Privilege** | At rest with **per-tenant encryption key** + in transit | Shortest justified window; erasure on request | **Dynamic field-level masking** on read for any Subject below Restricted clearance | **Every read and write audited** (Non-Repudiation) |

This table is the source of truth handed to the security-architect. Read each column as a contract the
downstream skill must satisfy.

---

## 2. Access control column → `access-control-model`

The Access column is the input to ABAC policy authoring. The sensitivity level becomes a `Resource`
attribute that `ABACPolicy.Evaluate(Subject, Resource, Action, Environment)` keys on:

```go
// A Resource carries its classification so the policy can gate on it.
type Resource struct {
    TenantID   TenantID   // Domain Primitive — never a bare uuid (Secure-by-Design)
    Kind       string     // "data_asset"
    Sensitivity Level      // Domain Primitive — the classification tag
}

// Policy rule shape (illustrative): Restricted requires clearance AND same tenant AND PoLP-scoped permission.
func (p ABACPolicy) Evaluate(s Subject, r Resource, a Action, e Environment) Decision {
    if r.Sensitivity == Restricted {
        if s.Clearance < Restricted || s.TenantID != r.TenantID {
            return Deny
        }
    }
    // … permission + PoLP checks …
}
```

Handoff rules:

- **Restricted always adds a tenant check** even though physical isolation already separates tenants —
  this is deliberate defense-in-depth (Secure-by-Design: never let one layer's isolation excuse the
  next layer's missing check). The ABAC tenant check is "partially redundant" *on purpose*.
- **Sensitivity and Clearance are Domain Primitives**, not bare strings/ints — a malformed level or a
  wrong-shape permission should be constructor-impossible, not a runtime hope (Secure-by-Design
  totality argument).
- Every permission (`data-assets:read`) and every sensitivity tier (`Restricted`) is a term the
  business recognizes — security lives in the Ubiquitous Language, not in an unnamed middleware.

---

## 3. Encryption column → `zero-trust-design`

| Level | At rest | In transit | Key strategy |
|---|---|---|---|
| Public / Internal | Not required | Linkerd mTLS | — |
| Confidential | Required | Linkerd mTLS | Shared at-rest key |
| Restricted | Required | Linkerd mTLS | **Per-tenant encryption key** — a key compromise is blast-radius-limited to one tenant, matching physical isolation |

In-transit encryption (Encryption in Transit) is automatic via Linkerd's mesh mTLS for everything;
at-rest encryption (Encryption at Rest) is level-gated. The per-tenant key for Restricted data is the
cryptographic complement to physical per-tenant isolation.

---

## 4. Retention column → `data-retention-policy`

The retention window is a function of level and special category, and the handoff is bidirectional:
`data-classification` supplies the level; `data-retention-policy` owns the concrete windows and
disposal mechanics.

| Level | Retention posture |
|---|---|
| Public / Internal | Standard organizational retention |
| Confidential | Per-category window; deletion on account closure |
| Restricted | Shortest justified window; **right-to-erasure honored on request** (GDPR); disposal audited |

A `DataAssetReclassified` event that *raises* a level can *shorten* an asset's retention window —
retention consumes the current effective level, so reclassification must propagate to the retention
engine.

---

## 5. Masking / redaction column

- **Confidential** — masked on export/download (e.g., a customer list exported to CSV has direct
  identifiers reduced), full value visible in-app to permitted subjects.
- **Restricted** — **dynamic field-level masking** applied at read time for any Subject whose
  clearance is below Restricted: the field is redacted (`•••`) rather than returned, even to an
  authenticated user, unless their ABAC decision grants Restricted clearance. The unmasked value never
  leaves the boundary for an under-cleared subject.

This complements the detection-side privacy constraint: the classifier already never stores a raw
sensitive *value* (only type + location); masking governs what a *permitted* pipeline consumer sees
of values that are legitimately stored.

---

## 6. Audit column → Non-Repudiation

- Confidential: every **write** is audited.
- Restricted: every **read and write** is audited — an append-only, tamper-evident trail supporting
  Non-Repudiation. De-escalation of any level is always audited regardless of the target level,
  because lowering protection is the highest-risk classification change.

---

## 7. The handoff contract (summary)

`data-classification` produces the level and special-category tags. It does **not** implement access,
encryption, retention, or masking — it declares, per level, what those controls must be. The contract:

| Consumer skill | Consumes | Owns |
|---|---|---|
| `access-control-model` | Sensitivity as a `Resource` attribute | ABAC policy rules, PoLP, tenant check |
| `zero-trust-design` | Encryption requirement per level | Key strategy, mesh mTLS config |
| `data-retention-policy` | Effective level + special category | Retention windows, erasure, disposal |
| `privacy-design` | Special-category tags, the no-raw-value constraint | DPIA, purpose limitation, personal-data inventory |
| `compliance-design` | Special-category tags | Regulation-to-control traceability |

If a level exists in the taxonomy but no control column changes when data moves into it, the scheme is
decoration — the mapping in §1 is the forcing function that keeps classification enforceable.
