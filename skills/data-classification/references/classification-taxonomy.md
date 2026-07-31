# Classification Taxonomy — Levels, Criteria, Detection, and Authority

Reference for `data-classification`. The full sensitivity-level definitions, the criteria that decide
a level, the automated-detection entity-type map, the special-category tags, and the Data Steward
authority that governs the scheme. Grounded in DAMA-DMBOK's Data Governance and Reference Data
disciplines and Secure-by-Design's sensitivity axis.

---

## 1. The four sensitivity levels (full definitions)

The taxonomy is a fixed, ordered set of exactly four levels. It is **Reference Data** in DAMA-DMBOK's
sense (a controlled vocabulary that classifies other data), and the four terms are Ubiquitous
Language — they appear verbatim in `data_assets.sensitivity_level`, in event payloads, in ABAC
policy rules, and in the UI. Adding a fifth level or a synonym is a governed change, not an ad-hoc
edit (see §5).

| Level | Ordinal | Definition | Harm if disclosed |
|---|---|---|---|
| **Public** | 0 | Cleared for public release; no harm on disclosure | None |
| **Internal** | 1 | Internal-only; limited harm on disclosure | Limited / reputational |
| **Confidential** | 2 | Material harm on disclosure to the business or a third party | Material — legal/commercial |
| **Restricted** | 3 | Severe harm; legal or regulatory exposure on disclosure | Severe — regulatory/statutory |

The ordinal is what `max()` runs over during propagation (see `tagging-and-propagation.md`).

### Worked repo-data examples

These are the calls a data-architect actually makes on this product's data:

| Data | Level | Why |
|---|---|---|
| Published marketing PDF crawled from a public S3 bucket | Public | Cleared for release |
| **Aggregate entity counts** ("this asset contains 3 email addresses") | Internal | The *count* is derived metadata; it reveals no individual's data. This is the key insight behind `privacy-design` — counts are Internal even when the underlying entities are Restricted |
| A crawled contract, customer list, or internal financial spreadsheet | Confidential | Material business harm |
| An `EMAIL` or `PERSON_NAME` entity extracted from a document | Confidential | Personal data, ordinary identifier strength |
| **A `SSN`, `PASSPORT`, or `NATIONAL_ID` entity type** | **Restricted** | Strong identifier; statutory exposure — a single one makes its containing asset Restricted |
| A `HEALTH_TERM` / `DIAGNOSIS` entity | Restricted | GDPR Art. 9 special category |
| A database credential or API key discovered during a crawl | Restricted | Secret |

> Note the orthogonal axis: *aggregate counts of Restricted entities are themselves Internal*. The
> sensitivity of a fact about the data (how many SSNs) is not the sensitivity of the data (the SSNs).

---

## 2. Classification criteria — how you decide a level

A level is chosen by asking, in order:

1. **Does the data contain a regulated special category?** (PII strong identifier, Art. 9, PHI, PCI) →
   Restricted. This dominates everything below.
2. **Does the data contain ordinary personal data or material business secrets?** → Confidential.
3. **Is the data internal-only but non-sensitive?** → Internal.
4. **Is the data cleared for public release?** → Public.

The **highest-sensitivity rule**: a composite asset's level is the maximum over everything it
contains — never an average, never "mostly Internal so call it Internal". One Restricted entity
dominates. This is the same inherit-max rule that governs derived datasets
(`tagging-and-propagation.md`).

---

## 3. Special categories (regulated data) — tagged *in addition to* the level

Some data carries legal obligations beyond its sensitivity level. Tag the category **separately** —
a field can be `Restricted` + `PII` + `special-category` at once. These tags drive `privacy-design`
and `compliance-design`.

| Category | Regulation driver | Notes |
|---|---|---|
| `PII` | GDPR, general privacy | Personal data identifying a natural person |
| `special-category` | GDPR Art. 9 | Health, biometric, racial/ethnic, political, sexual — elevated protection |
| `PHI` | HIPAA (if in scope) | Health information |
| `payment` | PCI DSS (if in scope) | Card data — typically out of MVP scope |

The category is orthogonal to the level, but a strong-identifier PII category *forces* Restricted;
an ordinary PII category *forces at least* Confidential.

---

## 4. Automated detection — the entity-type map and confidence threshold

During the Entity Extraction pipeline stage, detected entity types map to a **provisional** level and
special category. This map is Reference Data too — governed, versioned, keyed on by the pipeline.

| Detected entity type | Implies special category | Provisional level |
|---|---|---|
| `EMAIL`, `PHONE`, `PERSON_NAME` | `PII` | Confidential |
| `SSN`, `NATIONAL_ID`, `PASSPORT` | `PII` (strong identifier) | **Restricted** |
| `HEALTH_TERM`, `DIAGNOSIS` | `special-category` | **Restricted** |
| `ACCOUNT_NUMBER`, `IBAN` | `PII` (financial) | **Restricted** |
| `CREDIT_CARD` | `payment` (PCI) | **Restricted** |

### Confidence threshold

Detection produces a **confidence score** in `[0, 1]`. A configured threshold (the MVP default is
**0.60**) gates auto-classification:

- **At or above threshold** → the provisional level is applied automatically (escalation only).
- **Below threshold** → the asset is **flagged for Data Steward review**, *not* auto-classified. A
  low-confidence guess must neither silently set a level nor be dropped on the floor.

Automated detection **only ever escalates** a level. It never de-escalates — lowering protection is a
human decision (§5), always audited.

**Privacy constraint:** detection records the entity's *type and location* (`"SSN on page 3"`), never
the raw value. The raw value is itself the Restricted data being protected. See `privacy-design`.

---

## 5. Who classifies — Data Steward authority (DAMA-DMBOK Governance KA)

DAMA-DMBOK places Data Governance at the hub of its wheel: governance grants *authority and
accountability*, it doesn't produce data itself. Classification decisions therefore need an owner.

- **Data Steward** — the accountable authority for a data domain, with standing power to set or
  override a classification. In this solo-operator context the steward is **Shafi**, or an agent he
  has explicitly delegated review to, with escalation back to Shafi on dispute (mirroring the
  escalation-rule pattern in `agents/data-architect.md`).
- **Authority order:** manual steward classification **wins over** automated detection and over
  propagation, and the win is **audited** (who, when, and a recorded reason).
- **De-escalation is steward-only and always audited.** Automated signals can raise a level; only a
  steward can lower it, and lowering emits an audited `DataAssetReclassified` event because it reduces
  protection.

### The taxonomy and entity map are governed Reference Data

Neither the four-level taxonomy nor the entity-type map is edited casually. A change (adding a fifth
level, or a new regulated type like `CRYPTO_WALLET_ADDRESS`) is a Reference Data change that must
propagate to **every** ABAC policy, event schema, and UI control keyed on the old fixed set — the
kind of change control DAMA-DMBOK's Reference Data discipline (Ch. 10) prescribes. Treat it as a
versioned, reviewed change, not a code edit. (A dedicated `reference-data-management` skill is the
eventual home for that procedure; until it exists, the steward owns the change.)

---

## 6. DAMA-DMBOK grounding summary

| DMBOK concept | How it lands here |
|---|---|
| Data Governance as the coordinating hub (Ch. 3) | The Data Steward role and decision rights over classification |
| Reference Data vs Master Data (Ch. 10) | The taxonomy and entity map are Reference Data (controlled vocabularies), not Master Data |
| Data Security KA | Consumes the classification to drive controls (see `classification-to-controls.md`) |
| Secure-by-Design sensitivity axis | Sensitivity is orthogonal to Core/Supporting/Generic subdomain rating |
