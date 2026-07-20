---
name: data-classification
description: >
  Teaches how to design a data classification scheme — the sensitivity taxonomy,
  how data is classified (manually and automatically), how PII and special
  categories are detected, how a classification propagates through the pipeline
  and graph, and how classification drives downstream access control, encryption,
  and retention. Data classification is the input that makes privacy-design and
  the access-control-model enforceable. Produced by the data-architect during the
  Design phase, in concert with the security-architect.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, classification, pii, sensitivity, privacy, abac]
---

# Data Classification

## Purpose

Data classification assigns every piece of data a sensitivity level that determines how it must be protected. Without classification, every protection control is a guess — you cannot apply the Principle of Least Privilege, encryption, or retention rules to data whose sensitivity you have not declared.

Classification is where data architecture and security meet. The data-architect designs the scheme and how classification is computed and propagated; the security-architect consumes it to drive access control (`access-control-model`), encryption (`zero-trust-design`), and privacy (`privacy-design`). This skill produces the scheme they share.

---

## The Sensitivity Taxonomy

The first product uses a four-level taxonomy. These exact terms are part of the Ubiquitous Language and appear in the data model, events, UI, and policies — never substituted.

| Level | Definition | Examples | Default handling |
|---|---|---|---|
| **Public** | No harm if disclosed | Published marketing content, public docs | Standard controls |
| **Internal** | Internal-only; limited harm if disclosed | Internal process docs, non-sensitive metadata | Authn required |
| **Confidential** | Material harm if disclosed | Business financials, contracts, customer lists | Authn + ABAC + encryption at rest |
| **Restricted** | Severe harm; legal/regulatory exposure | PII, PHI, payment data, secrets | All Confidential controls + strictest access + audit on every read |

A data asset's level is the **highest** sensitivity of any data it contains. One Restricted entity in an otherwise Internal document makes the document Restricted.

---

## Special Categories (Regulated Data)

Some data carries specific legal obligations beyond the sensitivity level. Tag these explicitly, in addition to the level — they drive `privacy-design` and `compliance-design`.

| Category | Regulation driver | Notes |
|---|---|---|
| PII | GDPR, general privacy | Personal data identifying a natural person |
| Special-category personal data | GDPR Art 9 | Health, biometric, racial/ethnic, political, etc. — elevated protection |
| PHI | HIPAA (if in scope) | Health information |
| Payment data | PCI DSS (if in scope) | Card data — typically out of MVP scope |

A field can be both a sensitivity level and one or more special categories: e.g., `Restricted` + `PII` + `special-category`.

---

## How Classification Happens

Classification is applied at three points, in increasing authority:

| Method | When | Authority |
|---|---|---|
| **Automated detection** | During the Entity Extraction pipeline stage | Initial, provisional |
| **Rule-based propagation** | When an asset's contained entities imply a level | Derived |
| **Manual classification** | A Data Steward reviews and sets/overrides | Authoritative — wins over automated |

### Automated PII detection

During extraction, detected entity types map to provisional sensitivity:

| Detected entity type | Implies special category | Provisional level |
|---|---|---|
| `EMAIL`, `PHONE`, `PERSON_NAME` | PII | Confidential |
| `SSN`, `NATIONAL_ID`, `PASSPORT` | PII (strong identifier) | Restricted |
| `HEALTH_TERM`, `DIAGNOSIS` | Special-category | Restricted |
| `ACCOUNT_NUMBER`, `IBAN` | Financial PII | Restricted |

Detection produces a **confidence score**. Below a configured threshold, the asset is flagged for manual review rather than auto-classified — a low-confidence guess must not silently downgrade protection.

**Privacy constraint:** detection records the entity *type and location*, never the raw value of a sensitive entity. The classifier knows "there is an SSN on page 3" — it does not store the SSN. (See `privacy-design`.)

### Rule-based propagation

```
effective_level(asset) =
    manual_override_level                     if a manual override is set
    else max( sensitivity of each contained entity,
              source_default_level )
```

`max` over the ordered taxonomy (Public < Internal < Confidential < Restricted). The manual override sits **outside** the `max`, not inside it — a Data Steward's decision is authoritative even when it de-escalates. Automated classification only ever escalates; de-escalation happens only through an audited manual decision.

Two rules make this safe:

- **Store the override separately from the computed level.** If only the effective level is stored, recomputation cannot distinguish "a human decided Internal" from "the max rule produced Internal" — and will either clobber the human decision or bake it in forever. Keep `manual_override_level` (nullable, with an override reason and who/when) as its own column; the effective level is always derivable.
- **Escalation past an override triggers re-review, not silence.** If recomputation over new evidence yields a level *higher* than the standing override (a new SSN entity appears in an asset a steward marked Internal), do not silently keep the low override and do not silently discard the human judgment — flag the asset for steward re-review and alert. Both silent outcomes are defects.

---

## Propagation Through Pipeline and Graph

A classification is not a one-time stamp — it flows:

- **Through the pipeline:** the `sensitivity_level` travels in event envelopes/payloads so every downstream stage (graph update, compliance engine, alerting) sees the current level.
- **Into the graph:** the `DataAsset` and `Entity` vertices in Apache AGE carry `sensitivity_level`, so graph queries can reason about exposure ("which Restricted assets are reachable by this person").
- **On change:** a `DataAssetReclassified` Domain Event is emitted when the level changes, so projections and access decisions update. Re-classification to a *lower* level is always audited (it reduces protection).

---

## Classification Drives Downstream Controls

The classification scheme is only valuable if it mechanically drives protection. Document the mapping that downstream agents implement:

| Sensitivity | Access control (security) | Encryption (security) | Retention (data-retention-policy) | Audit |
|---|---|---|---|---|
| Public | Authn optional | In transit | Standard | Standard |
| Internal | Authn required | In transit | Standard | Standard |
| Confidential | ABAC permission required | At rest + in transit | Defined per category | Write audited |
| Restricted | ABAC + tenant check; Principle of Least Privilege | At rest (per-tenant key) + in transit | Shortest justified; erasure on request | **Every read and write audited** |

This table is the contract handed to the security-architect: it is the source for ABAC policy rules and encryption requirements.

---

## Example — Classifying a Crawled DOCX

A worked pass over one `DataAsset` (a DOCX crawled from a Google Drive StorageSource whose `source_default_level` is Internal, confidence threshold 0.60):

```
Extraction run finds:
  3 × EMAIL        (confidence 0.97–0.99)  → PII, provisional Confidential
  1 × PERSON_NAME  (confidence 0.94)        → PII, provisional Confidential
  1 × SSN          (confidence 0.41)        → below threshold → NOT auto-applied;
                                              asset flagged for steward review

Propagation:
  no manual override set
  effective = max(Confidential, Confidential, Internal) = Confidential
  special categories: [PII]

Steward review:
  steward confirms the low-confidence SSN is real
  → manual_override_level = Restricted (reason recorded, decision audited)
  → DataAssetReclassified emitted { old: "Confidential", new: "Restricted" }
  → graph vertex updated, ABAC decisions now require Restricted access,
    retention category tightens per the control mapping
```

Note what did *not* happen: the 0.41-confidence SSN never silently set a level (below threshold → review, not auto-classification), and the escalation to Restricted came from an audited human decision, with the automated evidence as input.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Taxonomy uses canonical terms | Public/Internal/Confidential/Restricted, exactly | Synonyms or an undefined extra level |
| Highest-sensitivity rule | Asset level = max of contained data | An asset classified below its most sensitive content |
| Special categories tagged | PII / special-category tagged in addition to level | Regulated data with only a sensitivity level |
| Manual overrides authoritative | Manual classification wins and is audited | Automated detection overwriting a human decision |
| No raw sensitive values stored | Detection stores type + location only | Raw PII persisted by the classifier |
| Drives downstream controls | Mapping to access/encryption/retention exists | Classification with no enforced consequence |
| De-escalation audited | Lowering a level emits an audited event | Silent downgrade of protection |
| Override stored separately | `manual_override_level` kept apart from the computed level | Only the effective level stored, so recomputation clobbers or fossilises human decisions |
| Escalation past override re-reviewed | New higher-sensitivity evidence flags the asset for steward review | Standing override silently suppresses (or is silently discarded by) new evidence |

---

## Anti-Patterns

- **Classification as decoration.** A sensitivity taxonomy that no access, encryption, or retention control mechanically consumes. If nothing changes when a level changes, the scheme is documentation theatre — the control mapping table is what makes it real.
- **Manual override inside the max.** Computing `max(manual_override, detected, default)` so a steward's de-escalation is silently out-voted by an automated signal. The override sits outside the formula; escalation past it goes to re-review.
- **Storing only the effective level.** Persisting the result of propagation without the inputs (override, per-entity levels, source default). The level can never be recomputed, audited, or explained.
- **Silent low-confidence classification.** Auto-applying a level from a detection below the confidence threshold. Below threshold means human review — a 0.41 SSN guess must neither set Restricted unaudited nor be dropped on the floor.
- **The classifier that keeps the evidence.** Persisting raw detected values ("the SSN was 078-05-1120") to justify the classification. Type + location only; the raw value is itself the Restricted data you are trying to protect.
- **Taxonomy drift.** Introducing "Secret", "Sensitive", "High" or per-team synonym levels. The four terms are Ubiquitous Language — every extra synonym breaks the ABAC policies, event schemas, and UI that key on the canonical four.
- **One-time stamping.** Classifying at ingestion and never re-evaluating. Classification is recomputed whenever contained entities change, and every change emits `DataAssetReclassified` so downstream projections and access decisions stay current.

---

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
|---|---|---|---|

## Special Categories
| Category | Regulation | In scope? |
|---|---|---|

## Detection Rules
| Entity type | Special category | Provisional level | Confidence threshold |
|---|---|---|---|

## Propagation Rules
[max-rule with manual override outside the max; reclassification event; audit on de-escalation; re-review on escalation past an override]

## Control Mapping (handoff to security-architect)
| Sensitivity | Access | Encryption | Retention | Audit |
|---|---|---|---|---|
```
