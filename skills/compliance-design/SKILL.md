---
name: compliance-design
description: >
  Teaches the security-architect to design compliance controls that are
  automatable from the start — decomposing SOC 2 Trust Service Criteria
  (CC-series), GDPR/CCPA, and ISO 27001 requirements into concrete, testable
  controls, including the Separation of Duties control (author does not equal
  approver) enforced in CI, risk-based control selection with a materiality /
  enforcement-mode dimension (gate / monitor / record), the FIPPs to regulation
  control mapping, and the Control Coverage Matrix artifact. Each control is
  designed to be verified automatically (handoff to compliance-verification).
  Used during Design for any regulated feature or the platform baseline.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
related: [compliance-verification, privacy-design, threat-modeling, security-architecture, access-control-model, glossary-management]
tags: [design, compliance, soc2, gdpr, separation-of-duties, control-design, materiality, risk-based, fipps]
---

# Compliance Design

## Purpose

Compliance design translates a regulatory or framework requirement — a SOC 2
Trust Service Criterion, a GDPR obligation, an ISO 27001 clause — into a
concrete control that a test can exercise automatically. The goal is not "a
policy document exists"; it is that every in-scope requirement becomes a control
whose satisfaction is machine-verifiable, whose evidence is produced by the
pipeline as a byproduct of delivery, and whose failure has a defined consequence.

Design ends with a **Control Coverage Matrix** and control decompositions that
hand off cleanly to `compliance-verification`, which implements the automated
checks and the evidence pipeline. Design decides *what* the controls are, their
materiality, and their enforcement mode; verification proves they operate.

---

## The Control-Design Method

Every control follows the same three-step decomposition. This is the core
loop — apply it to each in-scope requirement.

1. **Requirement** — cite the real, standard requirement by name (SOC 2 CC6.1,
   GDPR Article 32, ISO 27001 A.9.4.1). Never invent a control ID.
2. **Control** — the specific, observable behaviour that satisfies it ("every
   API endpoint rejects an unauthenticated request with 401").
3. **Automatable test** — the check that proves the behaviour holds, expressed
   so `compliance-verification` can implement it as a CI test or an IaC/plan
   assertion, emitting evidence. If you cannot name the test at design time, the
   control is not yet designed — it is a wish.

**Design for automatability from the start.** A control worded "access is
appropriately restricted" cannot be tested; "an actor without the
`data-assets:write` permission receives 403" can. Author each control so its
verification is obvious — a criterion co-owned with risk and audit (see
`references/materiality-and-risk-selection.md`).

---

## Enforcement Mode — a First-Class Matrix Column

Not every control blocks a release. Before decomposing a requirement, decide
what happens **when the control fails**. Every control carries one of three
enforcement modes:

| Mode | On failure | Use for |
|---|---|---|
| **gate** | Blocks the pipeline / promotion | Material controls: cross-tenant isolation, encryption at rest, Separation of Duties, mTLS coverage |
| **monitor** | Raises an alert, does not block | Controls best watched continuously in production for drift (retention windows, mTLS edge completeness) |
| **record** | Emits evidence only | Controls that must be evidenced for the audit but need no active enforcement (change logs, provenance records) |

Enforcement mode is not cosmetic metadata — it states, per control, the design
decision about consequence. A `gate` control that fails must stop a `main`
promotion; a `monitor` control rides this repo's Prometheus / OpenTelemetry
stack and alerts on drift. It is a required column on the Coverage Matrix.

---

## Risk-Based Selection and Materiality

Do not decompose every in-scope requirement with equal weight. Select and
weight controls by the **materiality** of the risk they address — the degree of
harm if the control fails. In this product a cross-tenant data-exposure control
is material enough to be a hard `gate`; a cosmetic lint rule is not. Materiality
drives enforcement mode: the most material risks earn `gate`, the rest `monitor`
or `record`.

This is a design-time judgment made with the second line (risk/compliance) and
third line (audit) rather than after the fact — the three-lines-of-defense
collaboration. Threat severity feeds it directly: a high-severity modeled threat
from `threat-modeling` (crossing the physical tenant-isolation boundary) forces
a `gate`-mode control. Full method, the materiality rubric, and the three-lines
model: `references/materiality-and-risk-selection.md`.

---

## Separation of Duties — a Required Baseline Control

Separation of Duties (**the change author does not equal the change approver**)
is a core SOC 2 CC-series change-management control and a **required baseline
control** for this platform — not optional, not feature-specific. It becomes
real only when the pipeline enforces it mechanically, not when a policy document
asserts it. In this repo's `feature/<n>-…` → PR → `main` flow, SoD is a
`gate`-mode control enforced in GitHub Actions that emits an attestation to the
evidence store. Full decomposition — what the gate compares, how it emits
evidence, how it grounds in the branch flow — is in
`references/control-catalogue.md`.

---

## FIPPs — Map to the Principle Before the Regulation

A control that satisfies GDPR Article 5 and CCPA §1798.100 is not two unrelated
controls — it is one **Fair Information Practice Principle** (purpose
limitation) expressed under two regimes. Map each privacy control back to its
FIPP *before* mapping it forward to a regulation. This collapses duplicate rows,
and — more valuably — a FIPP with zero controls is a visible gap the matrix
surfaces. The FIPPs (notice, choice/consent, access/participation,
integrity/security, enforcement/accountability, plus collection limitation,
purpose specification, use limitation) are the common ancestor of GDPR, CCPA,
and SOC 2's Privacy criteria. The FIPP → GDPR-article → CCPA-section table is in
`references/coverage-matrix-template.md`. Privacy *lifecycle* controls are owned
by `privacy-design`; compliance-design maps and evidences them.

---

## The Control Coverage Matrix

The Coverage Matrix is the completeness artifact — every in-scope requirement
gets a row, even one whose status is "Not yet designed". Its columns:

| Column | Holds |
|---|---|
| Control | Short control name |
| Requirement ref | The real standard citation (SOC 2 CC6.1, GDPR Art 32, ISO A.9.4.1) |
| FIPP | The underlying principle (privacy controls) |
| Enforcement mode | gate / monitor / record |
| Materiality | The risk weight driving the mode |
| Test | The automatable check (handoff to compliance-verification) |
| Evidence type | What the pipeline emits (test output, IaC plan, attestation) |
| Status | Designed / Not yet designed |

Full column definitions, a worked SOC 2 baseline matrix, and the FIPP mapping
table: `references/coverage-matrix-template.md`.

---

## Reference Material

- `references/control-catalogue.md` — SOC 2 CC-series, GDPR/CCPA, and ISO 27001
  decomposed into concrete controls, each with enforcement mode and its
  automatable test; the Separation-of-Duties control decomposed in full.
- `references/materiality-and-risk-selection.md` — risk-based selection, the
  materiality rubric, design-for-automatability, three-lines-of-defense.
- `references/coverage-matrix-template.md` — the Coverage Matrix template, a
  worked SOC 2 baseline matrix, and the FIPPs → GDPR/CCPA mapping table.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Requirement citation | Every control cites a real standard clause by name | Invented control IDs or vague references |
| Automatable by design | Every control names the test that proves it | "Appropriately restricted" wording with no testable behaviour |
| Enforcement mode set | Every control declares gate / monitor / record | Failure consequence undefined |
| Materiality-weighted | Controls selected and weighted by risk, not uniformly | Every control decomposed with equal weight |
| SoD present | Separation of Duties is a baseline gate control | SoD absent or left to policy |
| FIPP-mapped | Privacy controls map to a FIPP before a regulation | Duplicate rows for one principle; FIPP gaps invisible |
| Matrix complete | Every in-scope requirement has a row | Orphan controls discovered at audit |

---

## Anti-Patterns

- **Checkbox compliance.** Declaring a control "met" because a policy document
  exists, with no system behaviour a test can exercise.
- **Uniform decomposition.** Treating a cross-tenant-isolation control and a
  cosmetic check with equal design weight — no materiality, no enforcement mode.
- **SoD by policy.** Relying on a Slack-honored "someone else approves" norm
  instead of a mechanically enforced author ≠ approver gate.
- **Regulation-first mapping.** Mapping controls straight to article numbers
  with no FIPP layer, so one principle appears as unrelated rows.
- **Untestable controls.** Wording a control so vaguely ("access is
  appropriately restricted") that no automated check can be written.
- **Orphan controls.** In-scope requirements that never appear in the matrix,
  discovered missing during the audit.
- **Conflating compliance with security.** A passing compliance suite verifies
  the controls in scope — not that the system is secure; compliance is the floor.

---

## Output Format

```markdown
---
name: compliance-design
product: [product name]
frameworks: [SOC 2, GDPR, CCPA, ISO 27001]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Compliance Design

## In-Scope Requirements   [per framework, with materiality noted]
## Control Decomposition   [per control: requirement ref, behaviour, test, mode]
## Separation of Duties Control   [the author != approver gate decomposition]

## Control Coverage Matrix
| Control | Requirement ref | FIPP | Enforcement mode | Materiality | Test | Evidence type | Status |
|---|---|---|---|---|---|---|---|

## FIPP Mapping   [FIPP -> GDPR article -> CCPA section, for privacy controls]
## Handoff to compliance-verification   [`tests/compliance/` tests + evidence types]
```
