# Materiality and Risk-Based Control Selection

Compliance design is not "decompose every clause the framework lists with equal
effort." That produces a flat pile of controls where a cross-tenant-isolation
gate and a cosmetic lint rule carry identical design weight — and where nobody
can say, per control, *what happens when it fails*. This reference gives the
selection method: how to weight controls by **materiality**, how materiality
drives **enforcement mode**, how to design each control to be automatable from
the start, and how risk and audit co-own that work (the three-lines-of-defense
model).

Grounded in the DevOps Automated Governance Reference Architecture (Beal,
Bensing, Willis et al., *Investments Unlimited*, 2022) and this repo's stack.

---

## Why materiality is a design-time decision

Traditional compliance treats every in-scope requirement uniformly: each gets a
control, each control is "tested," and a failing test is a failing test. That
hides the most important fact about a control — the **magnitude of harm if it
fails**. In this product:

- A failure of **cross-tenant isolation** exposes one customer's classified data
  to another. It is irreversible, it is the exact harm the product exists to
  prevent, and it is a reportable breach under GDPR/CCPA. Materiality: **critical**.
- A failure of a **cosmetic lint rule** produces a slightly inconsistent log
  format. Materiality: **low**.

Both might be "in scope." Treating them the same is the defect. Materiality is
the design-time judgment that ranks them, and that judgment then *chooses the
enforcement mode*.

---

## The materiality rubric

Score each candidate control on three axes; the highest axis dominates.

| Axis | Ask | Critical | Moderate | Low |
|---|---|---|---|---|
| **Harm reversibility** | If it fails, can the damage be undone? | Irreversible (data exposed, deleted, leaked) | Recoverable with effort | Fully recoverable |
| **Blast radius** | How many tenants / subjects are affected? | Cross-tenant or all subjects | Single tenant | Cosmetic / internal only |
| **Regulatory consequence** | Does failure trigger a reportable breach or a finding? | Reportable breach | Audit finding | None |

The score sets a *floor* on enforcement mode:

| Materiality | Minimum enforcement mode |
|---|---|
| Critical | **gate** — failure blocks the pipeline |
| Moderate | **monitor** — failure alerts, drift is watched in production |
| Low | **record** — evidence emitted, no active enforcement |

A control may be enforced *more* strictly than its floor, never less. The rubric
is the reviewable rationale that goes in the Coverage Matrix's Materiality column.

---

## Worked examples for this repo

| Control | Reversibility | Blast radius | Regulatory | Materiality | Mode |
|---|---|---|---|---|---|
| Cross-tenant isolation (CC6.6) | Irreversible | Cross-tenant | Reportable breach | Critical | gate |
| Separation of Duties (CC8.1) | Irreversible (unreviewed change shipped) | All tenants | Audit finding | Critical | gate |
| Encryption at rest (GDPR Art 32) | Irreversible if exfiltrated | All subjects | Reportable breach | Critical | gate |
| Structural minimisation — no raw PII (Art 5) | Irreversible | All subjects | Reportable breach | Critical | gate |
| Token expiry ≤ 1h (CC6.1) | Recoverable (rotate) | Single session | Finding | Moderate | monitor/gate |
| Audit retention window (CC7.2) | Recoverable | Internal | Finding | Moderate | monitor |
| Processing register generated (Art 30) | Recoverable | Internal | Finding | Low | record |
| Log-format consistency | Fully recoverable | Cosmetic | None | Low | record |

Threat severity feeds this table directly: a high-severity threat from
`threat-modeling` (e.g. an attacker crossing the physical tenant-isolation
boundary via an attack tree on the crown-jewel goal) forces the mitigating
control to **Critical / gate**. This is the concrete downstream consequence of
threat modeling — a modeled threat's severity determines its control's
enforcement mode, closing the loop between the two skills.

---

## Design for automatability — a co-owned criterion

A control is only useful if `compliance-verification` can implement its test. At
design time, each control must pass the **automatability check** before it is
accepted:

1. **Is the behaviour observable?** Can a test observe a concrete
   input→output ("no-JWT request → 401"), or is it a subjective state
   ("access is appropriately managed")? Reword until observable.
2. **Is the evidence machine-emittable?** Does the check produce a test result,
   an IaC plan assertion, a Linkerd report, or a signed attestation — something
   the pipeline stores — rather than a screenshot someone takes?
3. **Can it run every pipeline execution?** SOC 2 Type II assesses operating
   effectiveness over a period. A control that can only be checked manually once
   a quarter fails this criterion.
4. **Does it name its evidence type?** The Coverage Matrix Evidence-type column
   must be fillable now, not deferred.

A control that fails any of these is **not yet designed** — it is a wish with a
citation. Automatability is not verification's problem to discover later; it is
a design constraint owned jointly with risk and audit.

---

## The three-lines-of-defense collaboration

Automated governance works only when the codified controls are **co-authored**,
not inspected after the fact:

- **First line — engineering (security-architect + the domain agents).** Builds
  the system and writes the controls as code.
- **Second line — risk / compliance.** Owns which requirements are in scope and
  validates the materiality weighting and enforcement modes.
- **Third line — audit.** Consumes the evidence store as the audit deliverable
  and validates that controls operated over the period.

The control definitions (IDs, decomposition, enforcement mode, evidence spec)
live **in the repo, versioned**. A control change is then a reviewed, traceable
pull request — not a spreadsheet edited the week before an assessment. This
reframes the auditor from adversary to collaborator and makes the control set a
shared contract.

> Caveat for this repo's scale. *Investments Unlimited* assumes a large bank
> with dedicated risk and audit functions. This product has a solo operator, so
> the "three lines" are aspirational role-hats, not three teams — but the
> discipline (controls versioned in-repo, materiality justified, modes explicit)
> transfers directly and is the target posture even with one person wearing all
> three hats.

---

## Common mis-scorings to avoid

- **Scoring by framework prominence, not harm.** A control is not Critical
  because the framework lists it first or names it prominently; it is Critical
  because its failure is irreversible, wide, or reportable. Score the *harm*.
- **Averaging the three axes.** The axes do not average — the *highest* axis
  dominates. A control that is fully recoverable and cosmetic but triggers a
  reportable breach is Critical, not Moderate.
- **Letting infrastructure downgrade materiality.** Physical per-tenant
  isolation already discharges some isolation risk, but the ABAC cross-tenant
  check is still Critical / gate: it is the independent second layer, and
  defence in depth means neither layer's existence lowers the other's weight.
- **Confusing "low effort to test" with "low materiality."** Ease of automating
  a check has nothing to do with the harm the control addresses. A trivially
  testable control can be Critical; a hard-to-test one can be Low.

## Materiality as the bridge from threat model to pipeline

The materiality lens is the concrete link between `threat-modeling` and the
pipeline. A modeled threat carries a severity; materiality translates that
severity into an enforcement mode, and the enforcement mode determines whether
the mitigating control blocks a release. The chain is:

```
modeled threat (STRIDE cell / attack-tree goal)
   → threat severity
   → control materiality (this rubric)
   → enforcement mode (gate / monitor / record)
   → pipeline consequence (block / alert / evidence-only)
```

Without materiality, a threat model produces a list of mitigations with no
statement of which ones a failing build must stop for. Materiality is what gives
the threat model a downstream consequence in CI rather than leaving it a
parallel document.

## Selection procedure (the design step)

1. **Enumerate** in-scope requirements per framework (SOC 2 CC-series, GDPR/CCPA
   articles, ISO 27001 Annex A) — see `control-catalogue.md`.
2. **Score** each candidate control with the materiality rubric above.
3. **Assign** an enforcement mode at or above the materiality floor.
4. **Automatability-check** each control; reword until it passes all four tests.
5. **Record** every control as a Coverage Matrix row, including the ones scored
   Low — a `record`-mode row is still a row (no orphan controls).
6. **Review** materiality and modes with the second/third-line hats before the
   design is accepted.
