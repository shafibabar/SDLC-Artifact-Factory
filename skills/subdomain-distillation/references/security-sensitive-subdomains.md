# Security-Sensitive Subdomains

Per *Secure by Design* (Bergh Johnsson, Deogun, Sawano). Self-contained —
loadable without reading `SKILL.md` first, though it assumes the
Core/Supporting/Generic classification from there.

---

## The Counterpoint

Core/Supporting/Generic classification answers a build-vs-buy and
general-modeling-depth question. It does not answer a separate question:
**would a modeling mistake here cause unauthorized data exposure, financial
loss, or a safety failure?** These are independent axes. A subdomain can be
Generic by every buy-vs-build measure and still deserve Core-level modeling
rigor for its security-relevant slice.

The MVP version of this skill's worked example called Authentication/
Authorization flatly "Generic — modeling this from scratch would be wasted
effort." That's half right and half wrong. **Correction:**

- Buying the identity provider/library (Auth0, Okta, Keycloak, or an
  equivalent) — still Generic. No org gains competitive advantage by
  hand-rolling password hashing or OAuth flows.
- Modeling **how access decisions interact with this product's specific
  invariants** — which role can see which PII field, under what condition,
  across which tenant boundary — is not something to skip because "auth
  sounds generic." That mapping is domain-specific work, and getting it
  wrong is exactly the kind of mistake that causes real breaches.

## Why Layered Defense Isn't an Excuse

A common mistake Secure by Design names directly: teams reason "we have a
firewall / API gateway / authentication middleware, so the domain model
doesn't need to encode security invariants." This is backward for
business-logic-level security questions. "Can a data steward from Org A see
PII belonging to Org B's data estate, even indirectly through a shared graph
relationship?" is a **domain** question — no infrastructure layer can answer
it, because the answer depends on this product's specific Aggregate
boundaries and relationships. Domain-level invariants are often the last,
and most reliable, line of defense for exactly this class of failure.

## Domain Primitives and Assertions

Secure by Design's core tactical technique, applied wherever a subdomain is
flagged security-sensitive:

- **Domain Primitives** — richer Value Objects that make illegal states
  unrepresentable, including security-relevant illegal states. Not just
  "an `Email` type that validates format" but e.g. an `AccessScope` type
  that cannot be constructed except with a valid tenant + role combination,
  or a `RedactedField` type that a raw PII value can never bypass on its
  way to a projection.
- **Assertions** — explicit, fail-fast checks embedded in constructors, not
  scattered validation logic sprinkled through call sites. If an invariant
  can be violated, the type that should have prevented it wasn't designed
  strictly enough.
- **Security in the Ubiquitous Language** — access/authorization concepts
  become first-class domain terms (`AccessScope`, `RedactionPolicy`,
  `TenantBoundary`), reviewed in `glossary-management` like any other term —
  not left as unnamed infrastructure/framework concepts bolted on outside
  the model.
- **Aggregates as trust boundaries** — decide explicitly which Aggregates
  are trust boundaries (crossing them requires an authorization check) vs.
  which operate entirely within an already-trusted context. This is a
  modeling decision, not a middleware configuration.

## Security-Sensitivity Checklist

Run this alongside — not instead of — the Core/Supporting/Generic
classification, for every subdomain:

1. Does this subdomain handle PII, secrets, credentials, or financial data
   directly?
2. Is this subdomain a trust boundary — does it cross tenant isolation,
   privilege levels, or organizational boundaries?
3. Would a modeling mistake here (not an infrastructure misconfiguration —
   a genuine domain-model error) plausibly cause unauthorized data exposure
   or a safety/financial failure?

**Any "yes" flags the subdomain's security-relevant slice for Core-level
modeling rigor** — Domain Primitives, Assertions, explicit trust-boundary
Aggregates — regardless of what its Core/Supporting/Generic classification
says about general investment. The rest of the subdomain (the non-security
slice) still follows its original classification.

## Worked Examples

Applied to this product's subdomains (see `SKILL.md`'s classification of
each):

- **Authentication/Authorization** — classified **Generic** for build-vs-buy
  (use Auth0/Okta/Keycloak). Security-sensitivity checklist: yes to all
  three questions. **Its access-decision-mapping slice gets Core-level
  rigor** — Domain Primitives for `AccessScope`/`TenantBoundary`, explicit
  Assertions at every Aggregate that reads cross-tenant data, security terms
  in `glossary-management`. The library choice stays a Generic, bought
  decision; the domain modeling of what the library's tokens are allowed to
  *do* in this product's specific graph does not.
- **Storage Connectors (Google Drive, S3)** — classified **Supporting**
  overall (per `SKILL.md`'s worked example). Security-sensitivity checklist:
  yes to question 1 (handles OAuth tokens/credentials for customer storage
  access) and partially question 3. **The credential-handling slice** (never
  holding raw OAuth tokens outside a narrowly scoped Aggregate, always
  redacted in logs and error traces) **gets Core-level rigor** even though
  the connector's general CRUD/sync logic remains ordinary Supporting-level
  modeling.
