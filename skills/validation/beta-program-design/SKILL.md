---
name: beta-program-design
description: >
  Teaches how to design a beta program for the Customer Validation phase —
  the closed alpha to closed beta to open beta to GA progression with
  entry/exit criteria per stage mapped to `canary-deployment` and
  `feature-flag-design` rollout mechanics, participant selection from the
  stakeholder register's design-partner cohort, a beta agreement setting
  mutual expectations under an unrelaxed SOC 2 security posture, structured
  feedback cadence feeding `feedback-template`, and graduation criteria to
  exit each stage. Used by the requirements-analyst during Customer
  Validation.
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, beta-program, design-partners, canary, feature-flags, rollout]
---

# Beta Program Design

## Purpose

A beta program is the structured, staged way real customers are exposed to a release before it reaches General Availability (GA). It is the human program that wraps the platform's technical progressive-delivery mechanics (`canary-deployment`, `feature-flag-design`) — the stages of the program and the stages of the rollout move together, but they are not the same thing: the rollout mechanism controls *how much traffic or how many tenants* run the new release; the beta program controls *which humans are watching, what they've agreed to, and what evidence graduates the release forward.*

This skill governs the program design once — its stage structure, participant selection, agreement terms, feedback cadence, and graduation bar. `uat-plan` governs the specific validation activity within it for a given release slice.

---

## Program Structure — Four Stages

| Stage | Who's in it | Rollout mechanic | Entry criteria | Exit criteria |
|---|---|---|---|---|
| **Closed alpha** | 1 design-partner tenant, highest trust/tolerance | `canary-deployment` stage 1 (5%) within that tenant only; release flag `true` for that tenant only (`feature-flag-design`) | Quality-phase gates passed; UAT scenarios drafted | No Critical/High defects open; core Must Have flow completes end-to-end for the alpha tenant |
| **Closed beta** | 3–5 design-partner tenants (`stakeholder-mapping`'s design-partner cohort) | Canary wave extends to the beta cohort's tenants; each runs its own in-cluster canary progression | Closed alpha exit criteria met; beta agreement signed by each participant | UAT exit criteria met (`uat-plan`) across the cohort; feedback triaged with no unaddressed blocking pattern (`feedback-template`) |
| **Open beta** | Any interested prospect/customer who opts in | Canary continues fleet-wide per tenant wave; flag defaults `true` for opted-in tenants | Closed beta exit criteria met; `acceptance-sign-off` at least conditional | Sustained SLO adherence at scale beyond the design-partner cohort; no new Critical/High pattern emerges |
| **GA** | Full fleet | Canary reaches 100% and terminates per `canary-deployment`; release flag deleted per its `removal_date` (`feature-flag-design`) | Open beta exit criteria met; full `acceptance-sign-off` | N/A — GA is the terminal state for this release |

The program never skips a stage under schedule pressure. Each stage's evidence is what the next stage's entry criteria consume — an open beta launched without a clean closed beta is a fleet-wide bet with no design-partner-scale evidence behind it.

---

## Participant Selection and Recruitment

Beta participants for closed alpha and closed beta are recruited from the **design-partner cohort** identified in the stakeholder register (`stakeholder-mapping` — "Design partners (3–5 companies)," Manage Closely quadrant). Selection criteria, all required:

| Criterion | Why it matters |
|---|---|
| **Representative of the ICP** | A participant who doesn't resemble the target customer produces feedback that doesn't generalize — validating for the wrong buyer wastes the program |
| **Willing to give structured feedback** | Beta only works if participants engage with the feedback cadence, not just use the product silently |
| **Tolerant of rough edges** | Beta software has defects by definition; a participant who churns at the first bug is the wrong fit for closed alpha/beta, even if otherwise a strong ICP match |
| **Named contact with decision authority or direct access to one** | Feedback and sign-off (`acceptance-sign-off`) need a real counterpart who can commit to the two-party sign-off, not an anonymous user base |

Recruitment happens through the engagement plan already defined in the stakeholder map — design partners are already in a "Manage Closely" relationship before the beta program starts; the program formalizes an existing relationship, it does not cold-recruit strangers into a Critical-defect-tolerant role.

---

## The Beta Agreement — Setting Expectations

Every closed alpha/beta participant receives a short, plain-language agreement before entry. This is not a legal contract (Legal/DPO owns the DPA separately) — it is an expectation-setting document the requirements-analyst maintains and the participant's named contact signs off on.

```markdown
## Beta Agreement — [Product] Closed Beta

### What we're asking of you
- Use [feature/slice] as part of your real workflow for [duration]
- Execute UAT scenarios when asked (typically < 2 hours per release slice)
- Attend [cadence] feedback check-ins
- Report issues via [feedback channel] rather than working around them silently

### What you can expect from us
- A named point of contact (the requirements-analyst) for the duration of the beta
- Response to Critical/High severity reports within [SLA, e.g. 1 business day]
- No change to your security posture: your data is handled under the same SOC 2
  posture (CC6 logical access, CC7 system operations, A1 availability) as GA —
  beta is not a reduced-security environment
- Transparency about known issues and their remediation timeline

### Data handling commitment
Beta does not relax any control from `access-control-model`, `compliance-design`,
or `data-classification`. The same encryption, tenant isolation, and audit logging
apply. Beta status changes *what* is being validated, never *how safely* it is handled.

### Exit
Either party may end participation at any time; feedback already given remains
part of the program record.
```

The data-handling commitment line is non-negotiable: nothing in this plugin's frugality or speed constraints ever trades away SOC 2 posture for a beta cohort. A design partner is a real tenant under the same `access-control-model` and `compliance-design` controls as any GA customer.

---

## Feedback Cadence

| Cadence type | Frequency | Purpose | Feeds |
|---|---|---|---|
| **Structured check-in** | Bi-weekly (matches the stakeholder engagement plan's design-partner frequency) | Facilitated session walking through recent usage, open questions, planned UAT scenarios | `feedback-template` records, aggregated |
| **Ad hoc report** | As issues arise | Participant-initiated report via the agreed feedback channel | `feedback-template`, triaged same-day for Critical/High |
| **Release-slice UAT session** | Once per release slice reaching this cohort | The formal `uat-plan` execution window | `uat-scenario` results, feeding `acceptance-sign-off` |

Structured check-ins are preferred over relying solely on ad hoc reports — participants under-report friction they've silently worked around unless asked directly, which is why `feedback-template` includes anti-leading-question guidance for these sessions.

---

## Graduation Criteria

A stage does not graduate on a calendar date alone — it graduates when its evidence bar is met. Two dimensions, both required:

| Dimension | Bar |
|---|---|
| **Quantitative** | UAT pass rate threshold met (`uat-plan`); zero open Critical/High defects (`feedback-template` severity); SLO adherence during the stage's canary window (`canary-deployment`) |
| **Qualitative** | The named participant contact affirms the release is usable for its intended purpose — a clean defect count with a participant who still finds the product frustrating to use is not a graduation-ready result |

If either dimension fails, the stage extends (more time in closed beta, a further remediation cycle) rather than proceeding on a fixed calendar regardless of evidence.

---

## Worked Example — Closed Beta for the Classification Pipeline (3 Design Partners)

```markdown
## Beta Program — Classification Pipeline Closed Beta

**Stage:** Closed beta
**Participants:** Northwind Compliance Co. (Maya Chen), Ridgeline Analytics
  (compliance lead TBD-named), Harborview Legal Group (compliance lead TBD-named)
**Selection rationale:** All three match the ICP (mid-market, regulated industry,
  active Google Drive estate); all three have a named IT/compliance contact with
  decision authority; all three accepted the beta agreement's rough-edges clause.

**Rollout mechanic:** Each tenant on its own canary wave (`canary-deployment`),
  release flag `classification.pipeline.enabled=true` scoped to these three
  tenant ids only (`feature-flag-design`).

**Feedback cadence:** Bi-weekly structured check-in (every other Tuesday);
  ad hoc reports via shared Slack channel, triaged same business day.

**Data handling:** Unchanged SOC 2 CC6/CC7/A1 posture; confirmed in the signed
  beta agreement with each participant's named contact.

**Graduation criteria for this stage:**
- UAT-001 through UAT-004 pass across all three tenants (`uat-plan`)
- Zero open Critical/High defects
- All three named contacts affirm usability in the closing check-in

**Exit decision:** Feeds `acceptance-sign-off`; if met, program advances to open beta.
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Staged progression | Alpha → closed beta → open beta → GA, each with entry/exit criteria | Stages skipped or collapsed under schedule pressure |
| Rollout mechanic mapped | Each stage names its `canary-deployment`/`feature-flag-design` mechanic | Program described with no link to the technical rollout controls |
| Participant selection criteria applied | ICP match, feedback willingness, rough-edge tolerance, named contact all confirmed | Participants recruited without checking fit |
| Security posture unrelaxed | Beta agreement states unchanged SOC 2 CC6/CC7/A1 posture | Any implication that beta data is handled less strictly |
| Feedback cadence structured | Bi-weekly check-ins scheduled, not solely reactive | Feedback collection is ad hoc only, under-reporting friction |
| Graduation is evidence-based | Quantitative + qualitative bar both met before advancing | Advancing a stage on calendar date alone regardless of open defects |

---

## Anti-Patterns

**Beta as a marketing label with no structure.** Calling an unstructured early-access program a "beta" without stage criteria, an agreement, or a feedback cadence produces unmanaged expectations on both sides and no usable evidence for `acceptance-sign-off`.

**Relaxing security "because it's just beta."** Beta tenants are real tenants handling real (or realistic) data; the SOC 2 posture, access control, and classification rules apply identically. A security exception for beta is a defect, not a convenience.

**Skipping closed alpha/beta straight to open beta.** Exposing an unvalidated release to a wide, less-engaged audience before a small trusted cohort has confirmed the core flow works wastes the open-beta stage's evidence-gathering value on defects that closed beta would have caught cheaper.

**Recruiting participants who don't match selection criteria.** A design partner chosen because they were available rather than because they represent the ICP produces feedback that misleads the roadmap.

**Calendar-only graduation.** "We said two weeks, so we're moving to open beta" regardless of open Critical defects or a participant's qualitative dissatisfaction inverts the purpose of staged validation.

---

## Output Format

```markdown
---
name: beta-program-[product]-[release-slice]
product: [product name]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# Beta Program — [product] [release-slice]

## Stage
[Closed alpha / Closed beta / Open beta / GA]

## Participants
[Names, companies, ICP-fit rationale, named contact]

## Rollout Mechanic
[canary-deployment stage + feature-flag-design key/scope]

## Beta Agreement Status
[Signed/pending per participant]

## Feedback Cadence
[Check-in schedule; ad hoc channel]

## Data Handling Statement
[Confirmation of unchanged SOC 2 CC6/CC7/A1 posture]

## Graduation Criteria
- Quantitative: [UAT pass rate, defect bar, SLO adherence]
- Qualitative: [named-contact affirmation]

## Exit Decision
[Advance to next stage / extend / escalate — feeds acceptance-sign-off]
```
