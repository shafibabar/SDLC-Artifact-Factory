---
name: privacy-design
description: >
  Teaches the security-architect and domain-modeler to design privacy into a system —
  Privacy by Design's 7 foundational principles (Cavoukian), the PII data lifecycle
  (collect, use, retain, disclose, destroy) with a control at each stage, data
  minimisation and purpose limitation enforced structurally (a Domain Primitive that
  makes storing raw PII a type error, not a code-review catch), the FIPPs, consent and
  notice, the security-vs-privacy distinction, and Continuous Control Monitoring for
  retention windows. Grounded in the repo constraint that raw extracted file contents are
  never persisted — only entity types and counts. Used during Design for any feature
  touching personal data.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, privacy, privacy-by-design, pii, data-minimization, gdpr, consent, data-lifecycle, domain-primitive]
produces: privacy-design
domain: security
status: stable
related: [threat-modeling, access-control-model, secrets-management, compliance-design, compliance-verification, security-architecture, glossary-management]
---

# Privacy Design

## Purpose

Privacy by Design (Ann Cavoukian) means privacy protections are built into the
architecture from the start — not bolted on as a compliance checkbox at the end. Privacy is
an **engineering discipline**: obligations like minimisation, purpose limitation, and
erasure are requirements with acceptance criteria a test can exercise, not controls asserted
on faith in a Word document. This skill shapes those decisions during the Design phase for
any feature that touches personal data (user identity, file metadata, extracted PII
entities, access logs).

---

## Security is not privacy — the distinction that governs everything else

**Security protects data that exists; privacy governs whether the data should exist, why it
may be used, and for how long.** A perfectly encrypted, ABAC-gated, mTLS-protected store of
data you had no basis to collect is a security success and a privacy failure.

| Concern | Controls | Answers |
|---|---|---|
| **Security** | Encryption at Rest / in Transit (Linkerd mTLS), ABAC, audit trail | "Is the data that exists protected?" |
| **Privacy** | Data minimisation, purpose limitation, retention limits, consent | "Should this data exist, for what purpose, for how long?" |

One never substitutes for the other. "We encrypted it" does **not** discharge a privacy
obligation. Never accept a security control as evidence a privacy control was met.

---

## The Seven Privacy by Design Principles

| Principle | Applied meaning in this product |
|---|---|
| **1. Proactive not reactive** | Privacy risks designed out before code — DPIA and privacy misuse cases in the Design phase |
| **2. Privacy as the default** | Strictest posture with zero config; a weaker posture is a recorded opt-in, never an opt-out |
| **3. Privacy embedded in design** | Controls live in the domain model and infra (retention on `DataAsset`, purpose tags at the pgx layer) — no bolt-on `privacy-service` |
| **4. Full functionality** | Privacy *and* utility both, never traded — types+counts loses no compliance capability |
| **5. End-to-end security** | Protection across the full lifecycle — collect through destroy |
| **6. Visibility and transparency** | Processing documented, auditable, disclosable — transparency is a system output |
| **7. Respect for user privacy** | Individuals can access, correct, delete — routed through the controller/processor split |

Each principle in depth, plus the FIPPs and their GDPR/CCPA mapping:
`references/privacy-by-design-principles.md`.

---

## The PII data lifecycle — a control at every stage

PII is the atomic unit, and every item moves through five stages. Place an explicit control
at *each* — an inventory lists categories; a lifecycle map lists the gate each category
passes through. A blank stage is an unguarded transition, and a defect.

| Stage | Key control |
|---|---|
| **Collect** | Lawful basis + data minimisation (extract types+counts, never raw text) |
| **Use** | Purpose-binding — purpose tag on the column, checked at the pgx access layer; ABAC gate |
| **Retain** | Retention TTL + **Continuous Control Monitoring** that alarms on any row past its window |
| **Disclose** | ABAC decision (in the application, not the mesh) + immutable audit entry |
| **Destroy** | Verifiable deletion (scheduled partition drop) whose *execution is itself audited* |

Full per-category control map, the retention CCM mechanism, erasure (GDPR Art 17), the
Article 30 record of processing activities, and the DPIA risk model:
`references/pii-lifecycle-controls.md`.

---

## Data minimisation and purpose limitation — structural, not procedural

The strongest privacy control is *not collecting or not retaining the data in the first
place*. Minimisation designed into the schema makes a violation structurally impossible
rather than a discipline someone must remember. Two forms:

- **Structural minimisation** — make the safe representation the *only* representable one.
  Model an extracted finding as a type constructible only from `(EntityType, Count)`, with
  no field and no constructor path that accepts raw text. "Log the raw PII" then has no data
  source — it is a compile error, not a code-review catch. This turns the "never store file
  contents" rule into a type-level guarantee. Full Go pattern, its relationship to
  `secure-by-design`'s Domain Primitive and `access-control-model`, and the STRIDE
  Information-disclosure cell it discharges: `references/pii-domain-primitive.md`.
- **Purpose limitation as code** — a purpose written in a table is documentation; a purpose
  *tag* attached to the column and checked at the data-access layer is a control. A query
  issued under purpose `security-audit` cannot read a column tagged `compliance-detection`.
  Enforce it at the pgx layer, not by trusting callers.

**The repo constraint that anchors all of this:** raw extracted file contents are **never
persisted** — only entity **types and counts**. This is the primary privacy architecture
decision; it is the archetype of structural minimisation (a disclosure with no data source
cannot happen) and it loses no compliance-detection utility ("this file contains 3
national-ID numbers" is exactly what the use case needs).

---

## Consent, notice, and the controller/processor split

Consent is an engineered artifact with lifecycle state (granted, scoped, withdrawn,
expired) — not a checkbox. Notice/transparency is a system output the individual can *see*
and *act on*, not a static policy PDF. For this B2B product the participation right routes
through a split: the **customer is the controller** of in-document PII and holds the
relationship with those data subjects; **we are the processor** acting on documented
instruction. Route an individual's erasure request for in-document PII to the *controller* —
sending it to the processor short-circuits the legal chain. (Full split table:
`references/privacy-by-design-principles.md`.)

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Security vs privacy kept distinct | Privacy controls named separately from security controls | "We encrypted it" offered as a privacy control |
| Lifecycle control map complete | Every PII category has a control at all five stages | A category with a blank lifecycle stage |
| Minimisation is structural | Safe representation is the only representable one (type-enforced) | Minimisation as a rule the access layer is trusted to honour |
| Purpose defined and enforced | Every element has a specific purpose, enforced at the access layer | Generic "operational purposes"; purpose in a table nobody checks |
| Retention is enforced + monitored | Scheduled deletion job + CCM alarm on over-retention | Documented window with no deletion job |
| Correct legal basis | Each basis matches an Art 6(1) ground precisely | Bases conflated or listed as "GDPR" |

---

## Anti-Patterns

- **Treating security as privacy.** Offering encryption / mTLS / ABAC as evidence a privacy
  obligation was met. They protect data that exists; they say nothing about whether it
  should exist.
- **Minimisation as discipline, not structure.** A rule that says "never log raw PII" while
  the extraction result type still carries the raw text. Make raw text unrepresentable
  downstream — see `references/pii-domain-primitive.md`.
- **Privacy as a module.** A `privacy-service` bolted beside the domain instead of retention
  on the `DataAsset` Aggregate and purpose tags at the data-access layer. Principle 3 is
  architectural, not organisational.
- **"Operational purposes."** A purpose so generic it permits anything. A purpose that cannot
  generate a prohibited-uses list is not a purpose.
- **Retention as a config nobody enforces.** A documented 90-day window with no scheduled
  deletion job and no monitor. Retention is real only when a mechanism provably deletes on
  schedule, the deletion is audited, and CCM alarms on any row that outlives its window.
- **Conflating legal bases.** Citing legitimate interest for processing actually necessary
  for contract performance, or claiming consent from users who cannot meaningfully refuse.
  Each basis carries distinct obligations.
- **DPIA after go-live.** A DPIA run once the system is built can only document risk, not
  design it out. DPIA triggers are evaluated in the Design phase.

---

## Output Format

```markdown
---
name: privacy-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
gdpr-applicable: [yes / no]
dpia-required: [yes / no]
---

# Privacy Design

## Security vs Privacy Controls
[Which controls protect existing data (security) vs. govern its existence (privacy)]

## Personal Data Inventory + Lifecycle Control Map
| Category | Collect | Use | Retain | Disclose | Destroy |
|---|---|---|---|---|---|

## Structural Minimisation Decisions
[Per element: is it collected? which representation is the only representable one?]

## Purpose Limitation Controls
[Per element: purpose tag, permitted and prohibited uses, enforcement point]

## Data Subject Rights + Controller/Processor Split
| Right | Scope | Controller/processor | Implementation | Limitations |
|---|---|---|---|---|

## Article 30 Processing Register
[Processing activity entries]

## DPIA Summary
[Risk model scores and mitigations if DPIA was required]
```
