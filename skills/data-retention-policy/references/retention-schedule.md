# Retention Schedule — The Artifact

The retention schedule is the primary deliverable of `data-retention-policy`: a
table mapping every **data class** (from `data-classification`) to a **retention
window**, its **basis**, and a **disposition**. It is the single source of truth
the platform's purge jobs read and that `compliance-design` cites as evidence.

This reference gives the full worked schedule for this product's data classes,
the regulatory drivers behind each window, and the method for setting a window
for a class that does not yet have one.

---

## Vocabulary

| Term | Meaning |
|---|---|
| **Data class** | A category assigned by `data-classification` — e.g. `PUBLIC`, `INTERNAL`, `CONFIDENTIAL`, `RESTRICTED`, or a functional class like "audit log" |
| **Retention window** | The duration data of that class is kept before it becomes *eligible* for disposal. The clock starts at a named event (creation, last access, source disconnect) |
| **Basis** | The legal or operational reason the window is what it is. Every window has one; "we might need it" is not a basis |
| **Disposition** | What happens when the window elapses: hard delete, cascade delete, verifiable deletion, or (rarely, justified) continued retention |
| **Retention clock start** | The event the window is measured from — critical to state, because "7 years" means nothing without "from when" |

DAMA-DMBOK frames a retention schedule as a **Data Management** deliverable — a
specific, concrete standard implementing a governance policy decision made
upstream ("we retain audit evidence for the SOC 2 audit cycle"). The schedule is
the standard; the decision to be SOC 2-compliant is the policy.

---

## The Worked Schedule for This Product

The first product is a data-estate / compliance platform: it scans Google Drive
and S3, extracts PII entities, classifies data, and builds an Apache AGE graph.
Its own data classes and their windows:

| Data class | Window | Clock starts at | Basis | Disposition |
|---|---|---|---|---|
| **Audit log** | 7 years | Event write | SOC 2 evidence; must cover the full audit look-back cycle | Cold-tier after 90 days; hard delete at 7 years |
| **Compliance report** | 7 years | Report generation | Audit evidence; a customer's regulator may request historical reports | Hard delete at 7 years |
| **Lineage record** | = longest-retained derived artifact it describes | Artifact creation | Evidence integrity — lineage must outlive nothing and predecease nothing it explains | Purged *with* the artifact it describes |
| **Data-asset record** | Source disconnect + 30-day grace | Source connector removed | Operational; the grace window lets a re-connect recover state | Soft delete at disconnect → hard delete after grace |
| **Extracted entity metadata** | Life of the parent data asset | Parent asset created | Operational; entities have no independent reason to exist | Cascade-deleted with the asset (`ON DELETE CASCADE`) |
| **Personal data (PII)** | Minimum for the processing purpose; erasable on request | Collection | GDPR Art. 5(1)(e) storage limitation + Art. 17 erasure | Verifiable deletion — see `deletion-mechanics.md` |
| **Raw file content** | **Not retained** | — | Privacy by design — the platform extracts metadata, never stores the source bytes | Never stored; nothing to dispose |
| **Operational telemetry** | 30–90 days | Emission | Operations / debugging; no evidentiary value past the incident window | Rolling deletion (partition drop) |
| **Event payload (Redpanda)** | Topic retention (time/size) | Publish | Operational replay window; payloads carry IDs/metadata, not raw sensitive values | Topic retention expiry; verifiable deletion for anything sensitive — see `deletion-mechanics.md` |

**Note the two longest windows are evidentiary, not operational.** The 7-year
audit-log and compliance-report windows exist to survive an audit look-back, not
because the platform needs them to function. That is the correct shape: the
*shortest defensible* window per class, lengthened only where a named regulation
demands it.

---

## Regulatory Drivers

### GDPR — storage limitation and erasure

- **Art. 5(1)(e), storage limitation.** Personal data is kept "no longer than is
  necessary for the purposes." This is the source of the *minimisation-in-time*
  principle: the PII window is the shortest duration that still serves the
  processing purpose, not a fixed number.
- **Art. 17, right to erasure ("right to be forgotten").** A data subject can
  demand deletion. This is what makes PII disposition *verifiable* rather than
  best-effort — see `deletion-mechanics.md`.
- **Art. 17(3), exceptions.** Erasure does not apply where processing is
  necessary for compliance with a legal obligation or the establishment/exercise/
  defence of legal claims. This is the door through which **legal hold** and the
  retained audit-of-erasure record enter — see `legal-hold-and-archival.md`.

### SOC 2 — evidence retention

SOC 2 is an attestation over a period (typically 12 months look-back for a Type
II report). The audit log and compliance reports must cover the full period an
auditor may examine. Seven years is the conventional evidentiary retention that
comfortably spans multiple audit cycles and aligns with common financial-record
retention expectations. The basis is *evidence availability*, and the disposition
is **hard delete only after the window** — never before, because premature
deletion of audit evidence is itself a control failure.

### Sector regulations (out of MVP scope, but the schedule must accommodate them)

HIPAA (6-year retention for certain records), PCI DSS, and financial-services
rules impose their own windows. The schedule's shape must let a new class be
added with its own window without disturbing existing rows — see the method
below. Do not bake sector windows in until the product claims that scope.

---

## Method: Setting a Window for a New Class

When `data-classification` introduces a class with no retention rule, derive its
window from this decision procedure — do not default to "keep forever":

1. **Name the processing purpose.** Why does this data exist? The window can
   never be shorter than the purpose requires nor (for PII) longer than it needs.
2. **Check for a mandatory floor.** Is there a regulation, contract, or audit
   obligation that sets a *minimum* window (e.g. SOC 2 evidence, HIPAA 6-year)?
   That floor wins over minimisation.
3. **Check for a mandatory ceiling.** Is it personal data? Then GDPR storage
   limitation sets a *ceiling* — keep it no longer than the purpose needs.
4. **Resolve floor vs ceiling.** If a legal floor exceeds the purpose ceiling
   (e.g. you must keep an invoice with PII for tax law longer than the marketing
   purpose needs), retain the minimum required by the floor and record the lawful
   basis — this is a documented exception, not a free pass.
5. **Choose the clock-start event.** Creation, last access, or a lifecycle event
   (source disconnect). State it explicitly; a window without a start is unenforceable.
6. **Choose the disposition** from `deletion-mechanics.md`: cascade, hard delete,
   or verifiable deletion. PII and anything reachable in immutable backups
   require verifiable deletion.
7. **Set the archival trigger** (optional) from `legal-hold-and-archival.md`: if
   the data is retained long but accessed rarely, name a cold-tier trigger
   distinct from the disposal date.

The output of this procedure is one new row in the schedule table.

---

## Artifact Template

```markdown
---
name: data-retention-policy
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Retention & Disposal Policy

## Retention Schedule

| Data class | Window | Clock starts at | Basis | Disposition |
|---|---|---|---|---|
| [class] | [duration or rule] | [event] | [legal/operational reason] | [method] |

## Mandatory Floors and Ceilings

| Class | Floor (min) | Source | Ceiling (max) | Source | Resolution |
|---|---|---|---|---|---|

## Documented Exceptions to Minimisation

| Class | Retained beyond purpose because | Lawful basis | Minimum retained |
|---|---|---|---|
```

---

## Cross-References

- Disposition methods, verifiable deletion, cross-store cascade, audit evidence:
  `deletion-mechanics.md`
- Legal-hold override of any window, archival cold-tiering, retrieval SLAs:
  `legal-hold-and-archival.md`
- The classes this schedule assigns windows to: `data-classification`
- The PII lifecycle stages this schedule's PII row implements: `privacy-design`
