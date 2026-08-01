---
name: threat-modeling
description: >
  Teaches the security-architect and backend-engineer to threat-model a system
  using a concrete, repeatable method — the Four-Question Framework (what are we
  building, what can go wrong, what are we going to do about it, did we do a good
  job), STRIDE-per-element threat enumeration (Spoofing/Tampering/Repudiation/
  Information-disclosure/Denial-of-service/Elevation-of-privilege mapped to
  authentication/integrity/non-repudiation/confidentiality/availability/
  authorization), the Data Flow Diagram with trust boundaries as the mandatory
  modeling artifact, attack trees, and the validation loop. Used during Design
  for every new service or significant data flow, producing a reviewable threat
  model that feeds the Security Control Matrix.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, threat-modeling, stride, data-flow-diagram, trust-boundary, attack-tree, risk]
produces: threat-model
domain: security
status: stable
related: [security-architecture, access-control-model, zero-trust-design, privacy-design, security-implementation, compliance-design, compliance-verification, methodology-review, glossary-management]
---

# Threat Modeling

Threat modeling is a **software-centric**, structured method for finding security
threats at design time — before a weakness is built into the system, when fixing
it costs the time to write a mitigation rather than the cost of a breach. It does
not require a security specialist: an ordinary engineer with a structured model
and a taxonomy can enumerate what can go wrong. This skill is the source that
feeds the `security-architecture` Security Control Matrix — every threat it finds
becomes a control row.

## The Four-Question Framework (the backbone)

Every threat model answers four questions, in order:

| # | Question | What you produce | Skips-to-avoid |
|---|---|---|---|
| 1 | **What are we building?** | A Data Flow Diagram (DFD) of the flow, with trust boundaries drawn on it | Listing "assets" in the abstract instead of drawing the system |
| 2 | **What can go wrong?** | A STRIDE-per-element grid — every element × its applicable STRIDE letters | Attacker-brainstorm ("what would a hacker do?") with no coverage guarantee |
| 3 | **What are we going to do about it?** | A mitigation or a signed accepted-risk note for every filled cell | Restating the threat as its own mitigation |
| 4 | **Did we do a good job?** | The validation loop below | Treating the diagram as the finished model — the most-skipped step |

Question 1 for this repo is a diagram of the **DataAsset ingestion → classification
→ compliance** flow. Question 4 is the loop most lightweight efforts skip.

**Why software-centric.** Of the three entry points — asset-centric (start from the
data), attacker-centric (start from threat personas), software-centric (start from
the DFD) — this skill mandates software-centric because the DFD is something the
team already understands and can draw accurately. Asset lists drift; attacker
personas invite speculation. Use asset and attacker thinking only to *prioritize*.

## STRIDE — the "what can go wrong?" taxonomy

STRIDE gives Question 2 six categories. Each is the violation of one security
property, so the taxonomy doubles as a mitigation-property map:

| Letter | Threat | Violates property | Mitigation lane |
|---|---|---|---|
| **S** | Spoofing | Authentication | mTLS peer identity (Linkerd), JWT `sub` |
| **T** | Tampering | Integrity | Signed events, `pgx` parameterized writes, Transactional Outbox |
| **R** | Repudiation | Non-Repudiation | Immutable audit trail, OpenTelemetry spans |
| **I** | Information disclosure | Confidentiality | Encryption at rest/in transit, ABAC filtering, PII never persisted raw |
| **D** | Denial of service | Availability | Rate limits, Redpanda backpressure, Circuit Breaker |
| **E** | Elevation of privilege | Authorization | ABAC `AccessPolicy.Evaluate`, per-tenant scoping |

Apply STRIDE **per element**, not to the system as a whole. Walk each process,
data store, data flow, and external entity and ask which of the six apply *to that
element*. This is far less hand-wavy than brainstorming against the system in the
abstract, and the filled-vs-empty grid makes "did we look everywhere?" answerable.
Full per-category depth, element-type heuristics, and DataAsset examples:
`references/stride-catalogue.md`.

## The DFD and trust boundaries (the mandatory artifact)

Question 1's artifact is a Data Flow Diagram with exactly four element types:

- **External entity** — users, third-party services (Google Drive, S3, the browser)
- **Process** — the ingestion worker, the classification service
- **Data store** — PostgreSQL, and the Redpanda topic acting as a store-in-transit
- **Data flow** — the arrows between the above

Overlaid are **trust boundaries** — dashed lines wherever the level of trust
changes. Threats cluster on the data flows that *cross* a boundary, so the boundary
lines are where STRIDE pays off most. Draw the DFD first, boundaries second, then
number every element so findings link back to the model. The boundary set for this
repo (per-tenant namespace edge, each Linkerd mTLS hop, the Google Drive/S3
external-ingestion edges, the browser/API edge), DFD notation, and drawing
anti-patterns: `references/dfd-and-trust-boundaries.md`.

## Attack trees — depth for the crown jewel

STRIDE is breadth-first discovery across the whole model; an **attack tree** is
depth-first analysis of one goal. Author **one** tree, for the highest-value goal
only — for this domain, crossing the physical tenant-isolation boundary to read
another tenant's classified DataAssets. Do not scope a threat model around building
comprehensive attack trees; good trees are high-effort and easy to do badly. Use
STRIDE for breadth and one tree for the depth case. Worked tree:
`references/worked-threat-model.md`.

## When to threat-model

- At **Design**, before architecture decisions are locked — for every new service
  or significant data flow. The threat model is an *input* to Zero Trust design
  (`zero-trust-design`), not a review of it.
- **Again** whenever the DFD changes: a new ingestion connector, a new data store,
  a moved boundary. A threat model dated before the current architecture is stale
  evidence — treat any DFD change as the trigger to re-open it.

## The validation loop (Question 4)

The single most-skipped technique, and the one that separates a real threat model
from a diagram. Check three things explicitly:

1. **Does the DFD still match the built system?**
2. **Was STRIDE applied to *every* element**, not just the interesting ones?
3. **Does every filled cell have a mitigation or a signed accepted-risk note?**

A complete worked example — the DataAsset DFD, the filled STRIDE grid per element,
each cell's mitigation or accepted-risk note, and the Question-4 checklist — is in
`references/worked-threat-model.md`.

## Prioritization

STRIDE structures the search but does not prioritize. Rank findings with an
explicit, reviewable risk judgment (likelihood × impact). Avoid DREAD and
false-precision numeric scores — the scores exist only to *sequence* work: crown-
jewel paths get the attack tree and mitigations first; low-value threats may be
accepted. For every threat you defer, record the accepted-risk rationale so the
deferral is a visible decision, not a silent omission.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| DFD exists | Question 1 is a numbered DFD with trust boundaries | Threat list with no model |
| STRIDE-per-element | Every element carries its applicable STRIDE letters as a grid | STRIDE applied to the system in the abstract |
| Boundaries covered | Internal boundaries (service↔service, tenant↔tenant) get STRIDE too | Only the internet-facing edge analysed |
| Mitigations specific | Each cell names a mechanism and its verifying test | Mitigation restates the threat |
| Residual risk honest | Deferred threats carry a signed accepted-risk note | Risks silently dropped |
| Validated | Question 4 loop run; DFD matches the built system | Diagram treated as finished model |
| Versioned | Re-opened when the DFD changes | One-time exercise never revisited |

## Anti-Patterns

- **Threat modeling the finished system** — turns every finding into a rework
  ticket. The model precedes architecture decisions.
- **Attacker-centric brainstorming without structure** — produces whatever the room
  imagines. STRIDE-per-element is exhaustive by construction.
- **Only the external boundary** — Assume Breach means service↔service,
  service↔database, and tenant↔tenant boundaries get the same STRIDE treatment.
- **Risk scores as decoration** — assigning likelihood × impact then mitigating in
  discovery order anyway. Scores sequence work.
- **Mitigation by restatement** — "prevent cross-tenant access" is not a mitigation;
  a named mechanism plus its test is.
- **A register that only ever says "Mitigated"** — if nothing is Accepted or Open,
  the model describes aspiration, not reality.
- **Frozen threat model** — a DFD dated before the current architecture is stale.

## Output Format

```markdown
---
name: threat-model
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Threat Model: [Product Name / Flow]

## 1. What are we building? (DFD + trust boundaries)
[Numbered DFD — four element types — with trust boundaries drawn on it]

## 2. What can go wrong? (STRIDE-per-element grid)
| Element # | Element | S | T | R | I | D | E |
|---|---|---|---|---|---|---|---|

## 3. What are we going to do about it?
| Cell (element#/letter) | Threat | Mitigation / Accepted-risk note | Verifying test |
|---|---|---|---|---|

## Attack Tree (crown-jewel goal only)
[One goal-rooted AND/OR tree]

## 4. Did we do a good job? (validation loop)
- [ ] DFD matches the built system
- [ ] STRIDE applied to every element
- [ ] Every filled cell has a mitigation or a signed accepted-risk note
```
