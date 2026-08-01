---
name: data-classification
description: >
  Design a data-classification scheme for a dataset — the classification taxonomy and
  sensitivity levels (Public / Internal / Confidential / Restricted), the tagging schema and
  how a classification tag propagates through pipelines, joins, and derived datasets, and the
  mapping from each sensitivity level to concrete controls (encryption, ABAC access, retention,
  masking/redaction). Covers who classifies (Data Steward authority), automated PII/special-category
  detection with a confidence threshold, the inherit-max propagation rule, manual-override handling,
  and reclassification. Grounded in DAMA-DMBOK and the Secure-by-Design security-sensitivity axis.
  Used during Design for any dataset; feeds access-control-model, data-retention-policy, and
  privacy-design.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-governance, classification, sensitivity, tagging, pii, access-control]
produces: data-classification-scheme
domain: data
status: stable
related: [access-control-model, data-retention-policy, privacy-design, zero-trust-design, compliance-design, glossary-management]
---

# Data Classification

## What this skill decides

A classification scheme assigns every dataset, column, and asset a **sensitivity level** that
mechanically determines how it must be protected. Without it, every protection control is a guess —
you cannot apply the Principle of Least Privilege, Encryption at Rest, or a retention window to data
whose sensitivity was never declared.

This skill produces the scheme the data-architect and security-architect share. The data-architect
designs the taxonomy, the tagging schema, and how a tag is computed and propagated. The
security-architect consumes it to drive access (`access-control-model`), encryption
(`zero-trust-design`), retention (`data-retention-policy`), and privacy (`privacy-design`). Reach for
this skill whenever a new dataset, table, pipeline output, or graph projection enters the design.

**Sensitivity is orthogonal to strategic subdomain classification.** Secure-by-Design's key framing:
a Subdomain's Core/Supporting/Generic rating answers "how much competitive value?"; sensitivity
answers "how much harm if disclosed?" — two independent axes. A Generic subdomain (e.g., an auth
token issuer) can be maximally sensitive; a Core subdomain can be low-sensitivity. Never let a
"boring" Generic component escape sensitivity review because it isn't where differentiation lives.

## The sensitivity taxonomy (Ubiquitous Language — do not substitute)

The first product uses exactly four levels, ordered. These terms appear in the data model, events,
UI, and ABAC policies — synonyms ("Secret", "Sensitive", "High") are taxonomy drift and a defect.

| Level | Harm if disclosed | Repo-data example |
|---|---|---|
| **Public** | None | Published marketing content |
| **Internal** | Limited | Aggregate entity counts ("3 emails on page 2"), non-sensitive metadata |
| **Confidential** | Material | Contracts, customer lists, `EMAIL` / `PERSON_NAME` entities |
| **Restricted** | Severe; legal/regulatory exposure | A `SSN` / `PASSPORT` PII entity type, secrets |

Full level definitions, classification criteria, the automated-detection entity-type map, confidence
thresholds, special-category tags (PII / GDPR Art. 9 / PHI / PCI), and the Data Steward authority
that DAMA-DMBOK's Governance KA grants: **`references/classification-taxonomy.md`**.

## Tagging and the inherit-max propagation rule

A classification is a **tag**, not a one-time stamp — it lives as metadata on the classified thing
(column, table, dataset, `DataAsset` vertex) and it *flows*. The core rule:

> **Inherit-max.** A derived dataset inherits the **maximum** sensitivity of every input that fed it.
> A join of an Internal table with a Restricted table yields a Restricted result. One Restricted
> entity in an otherwise Internal document makes the document Restricted.

`max` runs over the ordered taxonomy (Public < Internal < Confidential < Restricted). A **manual
override** by a Data Steward sits *outside* the max — it is authoritative even when it de-escalates —
and is stored separately from the computed level so the level is always re-derivable and the human
decision is never clobbered by recomputation. Escalation past a standing override (new
higher-sensitivity evidence appears) triggers steward **re-review**, never silent suppression.

Where the tag physically lives in this stack (Postgres column/table comment metadata, Redpanda event
envelopes, Apache AGE graph vertices), the propagation across pipeline stages and joins with SQL/Go,
and the `DataAssetReclassified` reclassification event: **`references/tagging-and-propagation.md`**.

## Classification drives controls (the whole point)

A scheme nothing enforces is documentation theatre. Each level maps to concrete, mechanical controls
that downstream agents implement — this mapping table is the contract handed to the security-architect:

| Level | Access | Encryption | Retention | Masking |
|---|---|---|---|---|
| Public / Internal | Authn (Internal) | In transit | Standard | None |
| Confidential | ABAC permission | At rest + in transit | Per category | On export |
| Restricted | ABAC + tenant check + PoLP; every read audited | At rest (per-tenant key) + in transit | Shortest justified | Field-level on read below clearance |

The full mapping — exact ABAC policy shape, key strategy, retention windows, and the redaction/masking
rules — plus the explicit handoff to `access-control-model` and `data-retention-policy`:
**`references/classification-to-controls.md`**.

## How classification happens

Three methods, in increasing authority — detail in `references/classification-taxonomy.md`:

| Method | When | Authority |
|---|---|---|
| Automated detection | Entity Extraction pipeline stage | Provisional |
| Inherit-max propagation | When contained entities / inputs imply a level | Derived |
| Manual (Data Steward) | Steward reviews, sets, or overrides | Authoritative, audited |

**Privacy constraint (see `privacy-design`):** detection records an entity's *type and location*,
never its raw value. The classifier knows "there is an SSN on page 3"; it never stores the SSN — the
raw value is itself the Restricted data being protected.

## Quality criteria

| Criterion | Pass |
|---|---|
| Canonical terms | Exactly Public / Internal / Confidential / Restricted |
| Inherit-max | Asset/derived level = max of contained data and inputs |
| Special categories tagged | PII / special-category tagged *in addition to* level |
| Override authoritative | Manual classification wins, stored separately, audited |
| No raw sensitive values | Detection stores type + location only |
| Drives controls | Every level maps to enforced access/encryption/retention/masking |
| De-escalation audited | Lowering a level emits an audited event |
| Escalation past override re-reviewed | New higher evidence flags steward re-review |

## Anti-patterns

- **Classification as decoration** — a taxonomy no control consumes. The control mapping is what makes it real.
- **Manual override inside the max** — `max(override, detected, default)` lets an automated signal out-vote a steward's de-escalation. The override is outside the formula.
- **Storing only the effective level** — discards the inputs (override, per-entity levels, source default); the level can never be recomputed, audited, or explained.
- **Silent low-confidence classification** — auto-applying a level from a detection below threshold. Below threshold means human review, not a silent guess and not a dropped signal.
- **The classifier that keeps the evidence** — persisting raw detected values to "justify" a level. Type + location only.
- **Taxonomy drift** — introducing per-team synonym levels breaks every ABAC policy, event schema, and UI keyed on the canonical four.
- **One-time stamping** — classifying at ingestion and never re-evaluating. Recompute on change; every change emits `DataAssetReclassified`.

## Output Format

```markdown
---
name: data-classification-scheme
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Classification Scheme

## Sensitivity Taxonomy
| Level | Definition | Examples | Default handling |

## Special Categories
| Category | Regulation | In scope? |

## Detection & Classification Authority
| Entity type | Special category | Provisional level | Confidence threshold |
[who classifies: Data Steward authority and escalation]

## Tagging & Propagation
[where the tag lives; inherit-max rule; override outside the max;
reclassification event; audit on de-escalation; re-review on escalation past an override]

## Control Mapping (handoff to security-architect / data-retention-policy)
| Sensitivity | Access | Encryption | Retention | Masking | Audit |
```
```
