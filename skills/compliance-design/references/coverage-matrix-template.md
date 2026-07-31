# Control Coverage Matrix — Template, Worked Baseline, and FIPP Mapping

The Control Coverage Matrix is the completeness artifact of compliance design.
Its rule is simple and absolute: **every in-scope requirement gets a row** —
including one whose Status is "Not yet designed". A requirement with no row is an
orphan control, discovered missing at the audit. The matrix is what makes "did
we cover everything?" answerable instead of asserted.

This reference gives the column definitions, a worked SOC 2 baseline matrix for
this repo, and the FIPPs → GDPR/CCPA mapping table that fills the FIPP column.

---

## Column definitions

| Column | Holds | Source |
|---|---|---|
| **Control** | Short, human-readable control name | Design |
| **Requirement ref** | The real standard citation — SOC 2 CC6.1, GDPR Art 32, CCPA §1798.105, ISO A.9.4.1. Never an invented ID. | `control-catalogue.md` |
| **FIPP** | For privacy controls, the underlying Fair Information Practice Principle | FIPP table below |
| **Enforcement mode** | `gate` (blocks), `monitor` (alerts), or `record` (evidence only) | Materiality floor |
| **Materiality** | Critical / Moderate / Low — the risk weight and its rationale | Materiality rubric |
| **Test** | The automatable check `compliance-verification` implements | Design (must be nameable now) |
| **Evidence type** | What the pipeline emits — test output, IaC plan, Linkerd report, signed attestation | Design |
| **Status** | Designed / Not yet designed | Design |

The Enforcement-mode and Materiality columns are the two additions that turn a
flat control list into a risk-weighted design. The Test and Evidence-type
columns are the handoff contract to `compliance-verification`: if either is
blank, the control is not yet designed.

---

## Worked SOC 2 baseline matrix for this repo

The platform baseline — the controls every regulated feature inherits, designed
once for the whole product.

| Control | Requirement ref | FIPP | Mode | Materiality | Test | Evidence type | Status |
|---|---|---|---|---|---|---|---|
| Cross-tenant isolation | SOC 2 CC6.6 | Integrity/Security | gate | Critical | Tenant-A JWT vs tenant-B resource → 403/404 | Test output | Designed |
| Separation of Duties | SOC 2 CC8.1 | Enforcement/Accountability | gate | Critical | Author ≠ approver check in GitHub Actions | SoD attestation | Designed |
| Endpoint authentication | SOC 2 CC6.1 | Integrity/Security | gate | Critical | No-JWT request → 401 | Test output | Designed |
| ABAC on every request | SOC 2 CC6.1 / ISO A.9.4.1 | Integrity/Security | gate | Critical | Insufficient permission → 403 | Test output | Designed |
| Encryption at rest | GDPR Art 32 | Integrity/Security | gate | Critical | `storage_encrypted = true` in OpenTofu plan | IaC plan output | Designed |
| Encryption in transit / mTLS | SOC 2 CC6.7 | Integrity/Security | gate | Critical | Linkerd edge report: zero plaintext edges | Linkerd report | Designed |
| Structural minimisation (no raw PII) | GDPR Art 5(1)(c) | Collection limitation | gate | Critical | Findings type has no raw-text field/constructor | Test output | Designed |
| Token expiry ≤ 1h | SOC 2 CC6.1 | Integrity/Security | monitor | Moderate | `exp - iat ≤ 3600` on issued JWTs | Test output | Designed |
| Session revocation on termination | SOC 2 CC6.3 | Enforcement/Accountability | gate | Moderate | Reuse prior JWT after termination → 401 | Test output | Designed |
| Audit trail on state change | SOC 2 CC7.2 | Enforcement/Accountability | gate | Moderate | Action → audit entry (actor, event, hash) | Test output | Designed |
| Purpose limitation | GDPR Art 5(1)(b) | Purpose specification / Use limitation | monitor | Moderate | Foreign-purpose column read → denied | Test output | Designed |
| Retention TTL / partition drop | GDPR Art 5(1)(e) | Collection limitation | monitor | Moderate | Scheduled drop ran and was audited | Audit query | Designed |
| Continuous control monitoring | SOC 2 CC7.2 | Integrity/Security | monitor | Moderate | Prometheus rule over OTel signals alerts on drift | Prometheus alert | Not yet designed |
| Deletion right honored | CCPA §1798.105 / GDPR Art 17 | Access/Participation | gate | Critical | Verified deletion request drops subject data | Test output | Not yet designed |
| Processing register generated | GDPR Art 30 | Enforcement/Accountability | record | Low | Register produced by pipeline, not hand-kept | Register artifact | Not yet designed |
| Audit log retention window | SOC 2 CC7.2 / ISO A.12.4 | Integrity/Security | monitor | Moderate | Oldest audit entry ≥ required retention | Audit query | Designed |

The three "Not yet designed" rows are deliberately present — the matrix's value
is that a known-incomplete control is a visible row, not a silent omission.

---

## FIPPs → GDPR / CCPA mapping table

Map every privacy control to its **Fair Information Practice Principle before**
mapping it forward to a regulation. One FIPP row then unifies the GDPR article
and the CCPA section as two expressions of one principle — collapsing what would
otherwise look like two unrelated controls, and surfacing any FIPP served by
**zero** controls as a genuine gap.

| FIPP | GDPR article | CCPA / CPRA section | Example control here |
|---|---|---|---|
| Notice / awareness | Art 13–14 (information to be provided) | §1798.100(a) (notice at collection) | Privacy notice generated from processing metadata |
| Choice / consent | Art 6, Art 7 (lawful basis, consent) | §1798.120 (opt-out of sale) | Consent state gates disclosure |
| Access / participation | Art 15 (access), Art 16 (rectification), Art 17 (erasure) | §1798.100(d), §1798.105 (deletion), §1798.106 (correction) | Deletion right honored; access/export endpoint |
| Collection limitation | Art 5(1)(c) (minimisation) | §1798.100(c) (collection limited to purpose) | Structural minimisation — no raw PII; retention TTL |
| Purpose specification | Art 5(1)(b) (purpose limitation) | §1798.100(b) (disclosed business purpose) | Purpose-tagged columns |
| Use limitation | Art 5(1)(b), Art 6(4) | §1798.100(b) (no incompatible use) | Purpose-limitation access check |
| Data quality / integrity | Art 5(1)(d) (accuracy) | §1798.106 (correction right) | Correction workflow; input validation |
| Integrity / security | Art 5(1)(f), Art 32 (security of processing) | §1798.150 (reasonable security) | Encryption at rest/in transit; ABAC; mTLS |
| Enforcement / accountability | Art 5(2), Art 30 (records), Art 33–34 (breach) | §1798.130 (compliance mechanisms) | Audit trail; processing register; SoD attestation |

> Sourcing note. The FIPPs are the OECD/FTC lineage synthesised in *The Privacy
> Engineer's Manifesto* (Dennedy, Fox, Finneran); GDPR articles and CCPA/CPRA
> sections are cited by their real numbers from the regulations themselves (the
> Manifesto predates both, so article-level claims are grounded in the
> regulations, not the book). Use this table to fill the matrix's FIPP column,
> then read a "FIPP with no control" row as a design gap to close.

---

## Worked feature-specific extension — a new ingestion source

When a feature adds a **new external ingestion source** (say, a Box connector
alongside the existing Google Drive and S3 sources), it inherits the entire
baseline above and adds only the rows the new data flow introduces. The trust
boundary at the new external-entity edge (from `threat-modeling`'s DFD) is what
generates them:

| Control | Requirement ref | FIPP | Mode | Materiality | Test | Evidence type | Status |
|---|---|---|---|---|---|---|---|
| Ingestion source authenticated | SOC 2 CC6.1 | Integrity/Security | gate | Critical | Connector rejects an unauthenticated fetch → error | Test output | Designed |
| Source credentials in secrets store | SOC 2 CC6.1 / ISO A.10.1 | Integrity/Security | gate | Critical | No plaintext credential in config/env; only a secret ref | Test output | Designed |
| Ingested data tenant-scoped | SOC 2 CC6.6 | Integrity/Security | gate | Critical | Ingested asset lands only in its own tenant partition | Test output | Designed |
| New PII category minimised | GDPR Art 5(1)(c) | Collection limitation | gate | Critical | Extracted findings carry types+counts, never raw text | Test output | Not yet designed |

Only four rows are new. Everything else — encryption, ABAC, SoD, audit trail —
is already discharged by the baseline the feature inherits. This is why the
baseline is designed once: features extend it, they do not re-derive it.

---

## Reading the matrix at audit time

The matrix is not just a design artifact — it is the index into the evidence
store `compliance-verification` produces. At audit time each row resolves to a
concrete deliverable:

- A `gate` row → the CI test result and (for SoD, provenance) the signed
  attestation, retained in the append-only evidence store (S3 with object lock).
- A `monitor` row → the Prometheus alert history and recording-rule query
  showing the control stayed satisfied across the period.
- A `record` row → the emitted artifact (processing register, change log).

Because the store retains FAIL alongside PASS, a `gate` row whose history shows a
block, a remediation, and a passing re-run is the operating-effectiveness
narrative a SOC 2 Type II auditor wants — the matrix row is the query key, and
evidence assembly is a lookup rather than a pre-audit scramble.

---

## Using the matrix in the Design phase

1. Start from the platform baseline above; it is inherited by every regulated
   feature.
2. For a new feature, add only the *feature-specific* rows (a new data flow, a
   new external ingestion source, a new PII category), as shown above.
3. Fill Enforcement mode and Materiality from the rubric in
   `materiality-and-risk-selection.md` — never leave them blank.
4. Fill Test and Evidence type from `control-catalogue.md`; a blank in either
   means Status must be "Not yet designed", not "Designed".
5. Map every privacy control to its FIPP (table above) before its regulation, so
   duplicate rows collapse and FIPP-with-no-control gaps surface.
6. The completed matrix is the Design-phase compliance artifact and the handoff
   contract to `compliance-verification`.

---

## Traceability and versioning

The matrix is a traceable artifact under the repo's Artifact Standards: each row
traces backward to the requirement that caused it (the Requirement-ref column)
and forward to the test that proves it (the Test column). Store the matrix in
the repo, versioned, so a control change — a new row, a materiality re-score, an
enforcement-mode escalation — is a reviewed pull request rather than an
untracked spreadsheet edit. This is the "controls as code, co-authored with risk
and audit" posture from `materiality-and-risk-selection.md`: the matrix is the
shared, versioned contract, and its Git history is itself audit evidence that
the control set evolved through review.

A row is never silently deleted. A control that is retired moves to a
`Status: Retired` row with the commit that retired it, preserving the audit
trail — the same discipline that keeps FAIL attestations in the evidence store.
