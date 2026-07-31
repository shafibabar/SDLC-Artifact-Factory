---
name: security-architecture
description: >
  Teaches the security-architect to design a system's security architecture — applying the four
  design principles (least privilege, understandability, defense in depth, design for recovery),
  the zero-trust model (the network is always hostile; trust is never derived from network location),
  blast-radius reduction via distinct failure domains, and producing the Security Control Matrix that
  maps STRIDE threats to controls to enforcement layers. Covers where each control sits (Linkerd mTLS
  = transport identity only; ABAC = the authorization decision), the security-sensitivity axis
  orthogonal to Core/Supporting/Generic subdomain classification, and the automated-governance
  component triad. Used during Design after threat-modeling.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, zero-trust, defense-in-depth, least-privilege, blast-radius, security-control-matrix, mtls, abac]
related: [threat-modeling, zero-trust-design, access-control-model, security-implementation, compliance-design, compliance-verification, privacy-design]
---

# Security Architecture

## Purpose

The Security Architecture is the Design-phase synthesis of every security decision into one coherent, reviewable view. It sits downstream of `threat-modeling` (which produces the STRIDE-per-element grid of *what can go wrong*) and it produces the **Security Control Matrix** — the artifact that maps each threat to the controls that mitigate it, the layer each control lives in, and what happens when that control fails.

This skill is decision-shaping guidance. The exhaustive per-layer control tables, the worked matrix, the zero-trust decomposition, and each design principle in depth live in `references/` — pulled in only when the security-architect needs them.

---

## The Four Design Principles

The document is organized around four principles (Adkins & Beyer). One line each — full depth, mechanisms, and Go grounding in `references/design-principles.md`.

1. **Least privilege** — every component holds the *minimum authority to do its job*, designed in depth (small intent-named APIs, scoped service accounts, scoped and revocable third-party grants), not only at the outer gate. The authority a compromised caller can wield is bounded by the surface it can reach.
2. **Understandability** — a design whose security you cannot reason about is not secure. State the small set of **invariants** that must hold *regardless of any action an attacker takes* (e.g. "no request is processed under a tenant other than its validated JWT's `tenant_id`"); security review is confirming each change preserves every invariant.
3. **Defense in depth** — partition into distinct, independent **failure domains** so one breach does not cascade. Every control assumes the layers around it will fail.
4. **Design for recovery** — assume compromise is inevitable; design detection, rate-limiting, emergency revocation, and containment as first-class capabilities, and prefer root-causing over rollback (rollback can reintroduce the breached condition).

Understandability and recovery are the two principles most often missing from a control-only architecture — they are *design-time* concerns, not runtime knobs.

---

## Zero Trust: The Core Rule

**The network is always hostile. Trust is never derived from network location.** A packet arriving from inside the Kubernetes cluster or inside the Linkerd mesh is exactly as untrusted as one from the public internet. Every request is authenticated and authorized on its own merits, every time — being `ClusterIP`-local is an identity fact, never a permission grant.

**Where the authorization decision lives — the placement rule:** Linkerd mTLS answers *"who is connecting?"* (transport-layer workload identity + encryption). It **never** answers *"is this actor allowed to do this?"*. The authorization decision — ABAC — stays in the application. A meshed connection succeeding proves identity, not permission. This separation of *who enforces transport* from *what decides authorization* is the architectural invariant a reviewer must be able to assert; the vocabulary and decomposition behind it (and the device/user/workload identity planes, dynamic policy, micro-segmentation, per-tenant isolation as a failure-domain boundary) are in `references/zero-trust-and-mesh.md`.

---

## Blast Radius and Failure Domains

Defense in depth means more than layered controls — it means bounded, *known-in-advance* blast radius. For every control in the matrix, state two things the layer model alone does not:

- **Blast radius** — what becomes reachable, corrupted, or exposed if *this control alone* fails.
- **Containing failure domain** — which independent domain still contains that blast radius.

Each **physical per-tenant namespace is a failure domain**. The honest statement for a cross-tenant leak is: *if the ABAC tenant check fails, physical namespace isolation is the independent domain that still contains it.* That is a designed, stated property — not an implicit hope. Decide **fail-safe vs. fail-secure per subsystem**: what a chi handler does when its JWKS endpoint is unreachable or its policy store times out must be decided and recorded — the default must never be "allow".

---

## The Security Control Matrix (the artifact)

The matrix is this skill's deliverable. Columns: **Threat · Control · Layer · Enforcement mode**.

- **Threat column** is *generated*, not recalled. Its disciplined source is `threat-modeling`'s **STRIDE-per-element** grid: each filled STRIDE cell becomes one matrix row. STRIDE's property-to-mitigation map gives the Control column a principled derivation, not an ad-hoc one:

  | STRIDE letter | Violated property | Control lane |
  |---|---|---|
  | Spoofing | Authentication | Linkerd mTLS peer identity, JWT `sub` |
  | Tampering | Integrity | `pgx` parameterized writes, signed events, Transactional Outbox |
  | Repudiation | Non-Repudiation | append-only audit log, OpenTelemetry spans |
  | Information disclosure | Confidentiality | Encryption at rest/in transit, ABAC filtering, PII never persisted raw |
  | Denial of service | Availability | rate limits, Redpanda backpressure, Circuit Breaker |
  | Elevation of privilege | Authorization | `AccessPolicy.Evaluate` (ABAC), per-tenant scoping |

- **Enforcement mode** (from Investments Unlimited's materiality lens) states *what happens on failure*: `gate` (blocks promotion — cross-tenant isolation, encryption-at-rest, Separation of Duties), `monitor` (alerts on drift), or `record` (emits evidence only). A control mitigating no listed threat is decoration; a filled STRIDE cell with no control is an unmet requirement.

Full column definitions, a worked matrix for the DataAsset ingestion→classification flow, the six-layer control tables, and the governance component triad: `references/control-matrix-template.md`.

---

## Where Each Control Sits

Defense-in-depth layers — the decision surface for *which layer owns which concern*:

| Layer | Owns | Key controls |
|---|---|---|
| 1 Infrastructure | tenant + account boundary | physical namespace-per-tenant isolation, IaC-only changes, account segmentation, immutable nodes |
| 2 Network | reachability | default-deny NetworkPolicy, ingress TLS, namespace isolation |
| 3 Service-to-service | transport identity | Linkerd mTLS, deny-by-default authorization policy, short-lived rotated certs |
| 4 Workload | container posture | non-root, read-only FS, no privilege escalation, image scan + signing |
| 5 Application | authN + **authZ decision** | JWT validation, **ABAC** `Evaluate`, input validation, parameterized queries |
| 6 Data | data at rest | encryption at rest, per-tenant keys, append-only audit, residency enforcement |

The authorization *decision* is a Layer-5 concern by design (zero-trust placement rule above) — never delegated down to the mesh (Layer 3) or the network (Layer 2).

---

## Security Sensitivity — Orthogonal to Subdomain Classification

Security-sensitivity is a **separate axis** from a Subdomain's strategic Core/Supporting/Generic classification (Secure by Design). A *Generic* Subdomain (authentication, an internal admin-token issuer) can be maximally security-sensitive; a *Core* Subdomain can be low-sensitivity. Conflating the two axes causes teams to under-review "boring" Generic/Supporting subdomains precisely because they are not where competitive value lives. Tag each Bounded Context with a security-sensitivity rating independently, and flag every subdomain where the two ratings **diverge** — those are the forcing-function candidates for proportionate review.

---

## Automated Governance Components

Governance is itself an architecture concern with named, deployable components (Investments Unlimited's Automated Governance Reference Architecture): an **attestation-producer** (pipeline stages emitting signed, digest-pinned attestations), an **immutable evidence-store** (append-only ledger, the audit deliverable), and a **control-gate** (a pipeline stage that consumes the required attestation set, verifies signatures, and permits or blocks promotion). Design these alongside the service architecture, not as a reporting afterthought. The triad, the attestation shape, Separation of Duties in code, and Continuous Control Monitoring are in `references/control-matrix-template.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Principles named as a set | All four design principles organize the document | Only defense-in-depth present; recovery/understandability absent |
| Invariants stated | Each control maps to a stated invariant it preserves | Controls listed with no invariant they exist to protect |
| Blast radius per control | Every control states blast radius + containing failure domain | Blast radius left implicit |
| Threats derived, not recalled | Every matrix threat traces to a filled STRIDE cell | Threat column authored from memory |
| authZ placement explicit | Matrix asserts ABAC decision stays in the application, mesh = transport only | Authorization delegated to mesh/network |
| Enforcement mode set | Every control classified gate/monitor/record | Matrix records existence but not failure behavior |
| Sensitivity axis applied | Subdomains tagged for security-sensitivity independent of Core/Supporting/Generic | Sensitivity conflated with strategic classification |
| Residual risk explicit | Accepted/deferred threats listed with owner + rationale | Undocumented gaps |

---

## Anti-Patterns

- **Single-layer trust.** "The network is isolated, so the application check is redundant." Every control assumes the layers around it fail. Physical isolation does not remove the ABAC tenant check; mTLS does not remove JWT validation.
- **Mesh-as-authorizer.** Treating a successful mTLS connection as carrying authorization weight. mTLS answers *who*; ABAC answers *what*. Conflating them puts the authorization decision in the wrong plane.
- **Controls without invariants.** A control that names no invariant it preserves cannot be reviewed for removal — nobody can tell what breaks if it goes.
- **Blast radius left implicit.** Listing layers without stating, per control, what is reachable if it alone fails and which domain contains that.
- **Copy-paste control catalogue.** Importing a generic control list without deriving it from this system's STRIDE grid. A control mitigating no listed threat is decoration.
- **Perimeter thinking.** Concentrating controls at Layers 1–2 and trusting the interior — the direct contradiction of Zero Trust Architecture.
- **Hiding residual risk.** Presenting the architecture as fully mitigated when threats are accepted or deferred. An auditor finding an undocumented gap is far worse than one finding an owned, accepted risk.

---

## Output Format

```markdown
---
name: security-architecture
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Security Architecture

## Design Principles Applied
[Least privilege / understandability / defense in depth / recovery — how each shapes this system]

## Security Invariants
[The small set of properties that must hold regardless of attacker action]

## Zero-Trust Placement
[Mesh = transport identity; ABAC = authorization decision; per-hop identity planes]

## Security Control Matrix
| Threat (STRIDE cell) | Control | Layer | Enforcement (gate/monitor/record) | Blast radius | Containing failure domain |
|---|---|---|---|---|---|

## Security-Sensitivity Map
| Subdomain | Core/Supporting/Generic | Security-sensitivity | Divergence? |
|---|---|---|---|

## Automated Governance Components
[attestation-producer / evidence-store / control-gate]

## Residual Risks
[Accepted or deferred threats — owner + rationale]
```
