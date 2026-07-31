# STRIDE Catalogue — per-category depth and the per-element grid discipline

STRIDE is the taxonomy that answers Question 2 of the Four-Question Framework
("what can go wrong?"). Each of the six categories is the violation of one
specific security property, which is what makes the taxonomy also a
mitigation-property map: name the letter, and you have named the control lane.
This file gives each category its full definition, the property it violates, the
mitigation lane it maps to, and a concrete example on this repo's DataAsset
ingestion → classification → compliance flow. It closes with the STRIDE-per-element
grid discipline that turns STRIDE from a checklist ritual into an auditable
coverage argument.

Repo stack for grounding: Go + chi + pgx + Redpanda; per-tenant **physical**
isolation (separate namespace/deployment per tenant); Linkerd service mesh giving
automatic mTLS (transport identity only — the authorization decision is ABAC in
the application); OpenTelemetry/Prometheus/Tempo/Grafana; PII entity extraction
where raw file contents are **never** persisted (only entity types and counts).

---

## S — Spoofing → violates Authentication

**Definition.** An attacker presents a false identity — a user, a service, or a
process pretending to be a principal it is not. Spoofing is the failure to
correctly answer "who is this?"

**Mitigation lane: authentication.** Prove the identity of the caller before
trusting it.

- **Transport identity** — Linkerd's automatic mTLS gives every meshed pod a
  cryptographic peer identity, so one service cannot impersonate another on the
  wire. This is transport-layer identity only; it does **not** make an
  authorization decision.
- **User identity** — the JWT `sub` claim, validated (signature, expiry, issuer)
  at the API edge. A short expiry limits the window a stolen token is useful.
- **Domain Primitive reinforcement** — parse JWT claims into the same `Subject`
  type `access-control-model` uses, through one constructor, so a malformed or
  nil identity cannot circulate as a bare string.

**DataAsset example.** An attacker steals a browser-held JWT (via XSS) and calls
`PATCH /v1/data-assets/{id}/classification` as another user. Mitigation: RS256-signed
JWTs validated on every request, short (≈1h) expiry, server-side revocation.

---

## T — Tampering → violates Integrity

**Definition.** An attacker modifies data in transit or at rest — an event payload,
a database row, a config value — so the system acts on data that is not what its
author wrote.

**Mitigation lane: integrity.**

- **In transit** — Linkerd mTLS protects service-to-service flows; TLS on ingress
  protects the browser/API edge; signed events protect Redpanda messages a consumer
  reads.
- **At rest** — `pgx` **parameterized** writes (never string-concatenated SQL) so a
  payload cannot alter query structure; a Transactional Outbox so the DB write and
  the event publish cannot diverge.

**DataAsset example.** An attacker intercepts the classification PATCH and downgrades
a `Restricted` asset to `Public`. Mitigation: mTLS on every internal hop, TLS on
ingress, and an integrity check on the persisted classification event.

---

## R — Repudiation → violates Non-Repudiation

**Definition.** A principal performs an action and later credibly denies it because
there is no trustworthy record that ties the action to them. Repudiation is unique
in STRIDE for concerning *evidence* rather than the action itself.

**Mitigation lane: audit / non-repudiation.**

- An **immutable, append-only audit trail** recording actor identity, action,
  target, and timestamp for every state-changing operation.
- **OpenTelemetry spans** correlating the action across services via trace IDs, so
  the record survives a multi-service flow.
- The audit store itself must resist Tampering (it is a data store — apply STRIDE
  to it too), or the non-repudiation guarantee is only as strong as the log's own
  integrity.

**DataAsset example.** A user classifies a file as `Restricted`, triggering a
compliance obligation, then denies doing it. Mitigation: every classification
action written to an append-only audit log with the user's identity and timestamp,
correlated to an OpenTelemetry trace. This directly supplies SOC 2 audit-logging
evidence.

---

## I — Information disclosure → violates Confidentiality

**Definition.** Data is exposed to a principal not authorized to see it — a
cross-tenant leak, a secret in a log, an over-broad API response.

**Mitigation lane: confidentiality.**

- **Encryption** at rest and in transit.
- **ABAC filtering** — `AccessPolicy.Evaluate` scopes every read to the caller's
  tenant and clearance; physical tenant isolation is a second, independent layer
  (defense in depth), not a replacement for the ABAC check.
- **PII never persisted raw** — the classification process stores only entity types
  and counts, never the extracted text, so a compromised data store or a debug log
  cannot disclose raw PII. This is the recorded mitigation for the "raw PII in a
  debug log" Information-disclosure cell on the classification process element.

**DataAsset example.** A handler bug returns another tenant's asset. Mitigation:
physical isolation (the request never routes to another tenant's service) **plus**
the ABAC tenant-scope check in the command handler — two independent layers.

---

## D — Denial of service → violates Availability

**Definition.** An attacker exhausts a resource (CPU, connections, queue depth, a
rate limit) so legitimate users cannot use the system.

**Mitigation lane: availability.**

- **Rate limiting** at the API edge and per-user limits on write endpoints.
- **Redpanda backpressure** so a flood of ingestion events degrades gracefully
  rather than collapsing the consumer.
- **Circuit Breaker** on calls to external entities (Google Drive, S3) so a slow or
  failing dependency does not cascade.

**DataAsset example.** An attacker sends 10,000 classification PATCHes to exhaust the
service. Mitigation: per-user write rate limits at the gateway; queue backpressure
on the downstream classification worker.

---

## E — Elevation of privilege → violates Authorization

**Definition.** A principal performs an action beyond their granted rights — a
read-only user writing, a tenant user reaching an admin endpoint, a low-clearance
subject reading `Restricted` data.

**Mitigation lane: authorization.**

- The **ABAC `AccessPolicy.Evaluate`** check on every state-changing operation,
  enforced in the **Application layer** command handler (not only the API layer),
  so the check cannot be bypassed by reaching the handler another way.
- **Per-tenant scoping** as an attribute in the policy decision.
- Authorization is distinct from authentication (Spoofing): proving *who* you are
  does not establish *what you may do*.

**DataAsset example.** A read-only user sends a PATCH and it succeeds. Mitigation:
ABAC policy check in the command handler, evaluated on every write, failing closed.

---

## STRIDE-per-element: the grid discipline

Apply STRIDE to **each individual DFD element**, not to the system as a whole.
Element-type heuristics tell you which letters are even plausible per element type,
so the grid is finite and reviewable rather than open-ended:

| Element type | STRIDE letters that principally apply |
|---|---|
| **External entity** | Spoofing and Repudiation |
| **Process** | all six (S, T, R, I, D, E) |
| **Data store** | Tampering, Information disclosure, and (for logs) Repudiation |
| **Data flow** | Tampering, Information disclosure, and Denial of service |

Build a table with one row per **numbered** element and one column per applicable
STRIDE letter. Fill each cell that applies with the concrete threat; strike out
inapplicable cells (an external entity has no meaningful Tampering row — you cannot
tamper with a user, only with the flows to and from them). The completed grid *is*
the "what can go wrong?" deliverable, and its filled-vs-empty cells make coverage
auditable: a reviewer (including a PM) can see at a glance whether every element was
examined, without reading code.

**Why the heuristic matters.** Without it, "apply all six to everything" produces
noise (an external entity's fabricated Tampering cell) and hides gaps. With it,
every empty cell is either struck-out-as-inapplicable or filled — there is no third
"we forgot to look" state. That is the coverage argument STRIDE-per-element buys
that abstract brainstorming cannot.

**STRIDE-per-element vs STRIDE-per-interaction.** This skill mandates
per-*element*. STRIDE-per-interaction (analysing each element's participation in
each data flow separately) is a heavier variant; it finds more but costs more, and
per-element is the right default for a Design-phase model that must stay reviewable.

**Caveat.** A fully-filled grid is a strong floor, not a completeness proof. STRIDE
structures the search but cannot enumerate novel or business-logic threats (e.g., an
abuse of the classification workflow that violates no single STRIDE property
cleanly). Treat the grid as the minimum bar, and reserve the crown-jewel goal for an
attack tree (see `references/dfd-and-trust-boundaries.md` and
`references/worked-threat-model.md`).

## Feeding the Security Control Matrix

Each filled STRIDE cell becomes a row in the `security-architecture` Security
Control Matrix: the cell's threat is the matrix's threat column, and the letter's
mitigation lane (above) gives the control column a principled derivation rather than
an ad-hoc one. The trust-boundary the element sits on tells the matrix which layer
the control belongs in — mesh/mTLS (Spoofing, transport Tampering) versus
application/ABAC (Elevation of privilege, Information disclosure). This is what makes
the threat model reusable evidence for `compliance-design` rather than a parallel
document.
