---
name: beta-program-design
description: >
  Teaches how to design and run a staged beta program in Customer
  Validation: closed alpha, closed beta, open beta and GA, each with entry
  and exit criteria tied to canary-deployment and feature-flag-design
  rollout. Covers choosing the program shape (B2B design partners, an
  internal staff rollout, or a consumer or high-volume open beta with
  waitlist cohorts and opt-in telemetry); screening participants, including
  Steve Blank's earlyvangelist conditions; the beta agreement and a
  data-handling statement in the product's own compliance frameworks; the
  feedback cadence; and graduation on quality, activation and retention,
  observed behaviour and commitment, repeatability and operational
  readiness. Each stage move is a graduation record (advance, extend,
  remediate or pivot, naming the suspect hypothesis), not another sign-off.
  Use when planning a beta or design-partner program, choosing who to let
  in, deciding whether a stage can graduate, or deciding between extending
  and pivoting. Used by the requirements-analyst agent in Customer
  Validation; written to customer-validation/beta-program/<slug>.md.
version: 3.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, beta-program, design-partners, earlyvangelist, graduation, pivot, retention, canary, feature-flags, rollout]
produces: beta-program
domain: validation
status: stable
related: [acceptance-sign-off, uat-plan, uat-scenario, feedback-template, stakeholder-mapping, gtm-strategy, business-model-canvas, jtbd-analysis, opportunity-solution-tree, pricing-and-packaging, canary-deployment, feature-flag-design, slo-definition, compliance-design, access-control-model, data-classification, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/service-design/this-is-service-design-doing-stickdorn.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/running-lean-maurya.md
---

# Beta Program Design

## Purpose

A beta program is the staged, human side of exposing a release to real users before General Availability. The rollout mechanism (`canary-deployment`, `feature-flag-design`) controls **how much** traffic or how many tenants run the release. The beta program controls **who** is watching, what they have agreed to, and **what evidence** lets each stage graduate.

The phase name is Steve Blank's (*The Four Steps to the Epiphany*): Customer Discovery → **Customer Validation** → Customer Creation. Every stage here sits inside Blank's single Customer Validation stage. Problem/solution fit is assumed from Ideate (`jtbd-analysis` is the Discovery equivalent), and no stage turns on demand-generation spend. Blank's test for this stage is **repeatability**: a documented process that works for a *new* participant without the founder's hand-holding, not just design partners who like the product.

| Owned here | Owned elsewhere |
|---|---|
| Program shape and stages; participant screening; the beta agreement; feedback cadence; graduation criteria and **graduation records** | The launch plan's Stage 1: `gtm-strategy` (the plan; this is its execution) · the design-partner cohort: `stakeholder-mapping` · UAT scope and exit criteria: `uat-plan` · capture and severity: `feedback-template` · **the defect rule and the one sign-off per release**: `acceptance-sign-off` · operating the canary and flags: `platform-engineer` |

## 1. Choose the Program Shape

| Shape | When | Stages usually run | Recruited from |
|---|---|---|---|
| **B2B design partners** | A few named customer organisations, each a tenant | Closed alpha → closed beta → open beta → GA | `stakeholder-mapping`'s design-partner cohort |
| **Internal rollout** | The users are the customer's own staff (an internal tool) | Closed alpha (one team) → GA (all staff) | The team that feels the pain first |
| **Consumer or high-volume open beta** | Many individual users; no named relationships | Closed beta (invited cohort) → open beta (waitlist waves, by region if needed) → GA | A waitlist with a screening question |

Choose the stages at design time and record why any is left out (an internal tool has no open beta). Once chosen, a stage is never skipped under schedule pressure. Waitlist screening, cohort sizes, opt-in telemetry and regional waves: `./references/program-shapes.md`.

## 2. Stages and the Rollout They Ride On

| Stage | Who | Rollout mechanic | Entry | Exit |
|---|---|---|---|---|
| **Closed alpha** | One highest-trust participant or team | Release flag on for that participant only; a canary inside that tenant if the platform splits traffic per tenant | Quality-phase gates passed; UAT scenarios drafted | Core Must flow completes end to end; graduation record |
| **Closed beta** | 3–5 screened design partners, or an invited cohort | Canary wave widens to the cohort; flag scoped to their tenant ids (or a percentage via the targeting service) | Alpha graduated; agreement accepted by each participant | `uat-plan` exit criteria met across the cohort; graduation record |
| **Open beta** | Anyone who opts in, or waitlist waves | Canary continues per tenant wave or region; flag on for opted-in users | Closed beta graduated; the release's one `acceptance-sign-off` names this stage in its rollout path | Graduation bar (§ 6) sustained at scale; graduation record |
| **GA** | Everyone | Canary reaches 100% and terminates; release flag removed by its `removal_date` | Open beta graduated; sign-off conditions closed or carried per its rollout action | Terminal for this release |

Whether a canary can split traffic **within** one tenant depends on the platform's tenancy model (`canary-deployment`'s per-tenant waves). Where it cannot, the release flag scoped to tenant ids does that job. State which in the record.

**One sign-off, many graduation records.** There is one `acceptance-sign-off` per release (D046). Moving from one stage to the next is a **graduation record** in this program, not a further sign-off. When asked for a sign-off per stage or per tenant, answer with the whole rule:
- one sign-off for the release; its rollout path names every stage, and at enterprise each tenant's representative accepts for their own cohort inside it;
- each stage move is a graduation record;
- three things **re-open Customer Validation**, meaning a new UAT pass and a sign-off that supersedes the old one: **a failed graduation**, a new Critical or High while widening, or a representative withdrawing. Before the sign-off exists, a failed graduation simply keeps Customer Validation open.

This skill never restates the defect rule.

**Stage is not the chasm.** Moore (*Crossing the Chasm*): a product can pass every stage and still sell only to visionaries. Audience size over time (this skill) and buyer psychology across the adoption curve (`gtm-strategy`'s beachhead) are separate checks; never treat GA as proof the chasm is crossed.

## 3. Screen the Participants

For a design-partner or invited stage, screen each **named** candidate against every row and record the facts, not impressions:

| Criterion | Why |
|---|---|
| **Represents the ICP** | Feedback from the wrong buyer misleads the roadmap |
| **Willing to give structured feedback** | Silent use produces no evidence |
| **Tolerates rough edges** | A participant who churns at the first defect is wrong for a closed stage |
| **Named contact with decision authority, or direct access to it** | The sign-off needs a real counterpart |
| **Already recognises the pain and has tried to solve it** (earlyvangelist 1–2) | A spreadsheet, workaround, consultant or rival tool is evidence the pain is real; "loves the idea" with no prior effort is goodwill, not pain |
| **Has budget or access to it, and is credible as a reference** (earlyvangelist 3–4) | Closed-beta evidence must transfer to a wider, colder audience |

A candidate who misses an earlyvangelist row is downgraded (a later open-beta participant, or an interview) or declined, however enthusiastic. Record the self-funded workaround by name in the participant row. During the beta, also note `stakeholder-mapping`'s **Mobilizer test**: does the contact carry what they learn to colleagues? The full four-condition checklist and Blank's reasoning: `./references/customer-development-discipline.md`.

Design partners come from an existing "Manage Closely" relationship; the program formalises it rather than cold-recruiting strangers into a defect-tolerant role.

## 4. The Beta Agreement and the Data-Handling Statement

Every closed-stage participant accepts a short, plain-language agreement before entry: what we ask, what they can expect, data handling, and exit. It sets expectations and is not the legal contract or DPA. Copy `./templates/beta-agreement.md`.

**Beta relaxes no control.** The data-handling statement names **the product's own frameworks**, from its `compliance-design` (UK GDPR, HIPAA, SOC 2, PCI DSS, or "the product's own policy" when nothing external applies), and states that the same `access-control-model`, `data-classification`, encryption, tenant isolation and audit logging apply as at GA. Never import another product's frameworks. Beta changes *what* is validated, never *how safely* data is handled. A consumer beta also records consent for any telemetry beyond what GA collects.

## 5. Feedback Cadence

| Type | Frequency | Feeds |
|---|---|---|
| **Structured check-in** | Bi-weekly for design partners (the stakeholder plan's cadence); a short in-app survey per wave for a consumer beta | `feedback-template` items |
| **Ad hoc report** | As issues arise; Critical and High triaged the same day | `feedback-template` |
| **Release-slice UAT window** | Once per slice reaching the cohort | `uat-scenario` results → `acceptance-sign-off` |

Ask about past behaviour, not opinions of the future. Fitzpatrick (*The Mom Test*): compliments and "I would use it" are not evidence; a **commitment** is (time on the calendar, an introduction, real data, a paid pilot, a renewal). End each check-in by asking for the next one. Question design: `feedback-template`.

## 6. Graduation: the Evidence Bar

A stage graduates on evidence, never on a calendar date. All four dimensions are recorded:

| Dimension | Bar |
|---|---|
| **Quality** | `uat-plan` threshold met; open defects within `acceptance-sign-off`'s defect rule; SLOs held through the stage's canary window (`slo-definition`) |
| **Traction** | Activation and retention **per cohort**, against targets set before the stage (Maurya, *Running Lean*: Product/Market Fit shows in retention, not sign-ups). Take the measures from the canvas's Key Metrics (`business-model-canvas`); rates, never running totals |
| **Behaviour and commitment** | The named contact describes observed use and friction, past tense, and has made a commitment. The **outside-the-building check** (Blank): an internal demo the team liked, or a leading question politely agreed with, does not count |
| **Repeatability and operations** | Each participant was onboarded by the same documented steps, without bespoke help; the backstage (support, review queues, manual steps) ran without the designer in the room. Stickdorn (*This Is Service Design Doing*) calls this the Minimum Viable Service: operational readiness is its own risk |

Closed stages lean on behaviour and commitment (Maurya's "validate qualitatively"); open beta to GA leans on traction (Maurya's "verify quantitatively"). Neither replaces the other.

**When the bar is not met**, name the **suspect hypothesis first**: segment, problem, solution or process. Then decide:

| Decision | When |
|---|---|
| **Advance** | All four dimensions met |
| **Extend** | The hypothesis holds; the stage needs more time or coverage |
| **Remediate** | A named defect or gap blocks graduation; the fix is scoped |
| **Pivot** | The evidence says a hypothesis is wrong (wrong segment, no real pain, the release doesn't solve it, or onboarding doesn't repeat). Name the canvas block it lives in so `business-model-canvas` is updated, not only this record |

Extending against evidence that already points at a wrong hypothesis buys time you cannot use. Diagnostic table and worked reasoning: `./references/customer-development-discipline.md`.

## Scale

`phase-requirements.json`: `beta-program-design` is **skipped at lean**, optional at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | None unless the user asks; if asked, one page with two stages. `./examples/01-lean-internal-staff.md` |
| **standard** | Design-partner closed beta with screening, agreement, four-dimension graduation. `./examples/02-standard-design-partners-pivot.md` |
| **enterprise** | Waitlist or tenant waves, regional rollout, SLO-gated graduation per region, per-cohort traction. `./examples/03-enterprise-consumer-regions.md` |

## Producing the Record

1. **Scaffold**: `bash ./scripts/scaffold-beta-program-design.sh <product> <release-slice>` copies `./templates/beta-program.md` to `artifacts/<product>/customer-validation/beta-program/<slug>.md`.
2. **Choose the shape and stages** (§ 1–2) and state the rollout mechanic each stage rides on.
3. **Screen participants** (§ 3); send `./templates/beta-agreement.md` with the product's own frameworks (§ 4).
4. **Set the graduation targets** for all four dimensions **before** the stage starts (§ 6).
5. **Present it to the user**: participants, targets and dates need their approval; a participant's agreement is theirs to give.
6. **Validate**: `bash ./scripts/validate-beta-program-design.sh <path>` checks structure only (a real stage, participants, a filled data-handling statement with no relaxation, all four graduation dimensions, a valid decision, and a suspect hypothesis on a pivot). Cross-check `./resources/beta-program-checklist.md` by hand.
7. **At each stage move**, append a graduation record; hand the rollout change to `platform-engineer`.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **"Beta" as a label** | No stages, agreement or cadence: no evidence for the sign-off |
| **Relaxing controls "because it's beta"** | Beta tenants are real tenants; a security exception is a defect |
| **Another product's frameworks in the statement** | Claims controls the product never designed for |
| **Recruiting enthusiasm** | "Loves the idea" with no prior effort predicts goodwill, not pain |
| **Calendar or defect-count graduation** | A clean defect count with no retention or commitment is not Product/Market Fit evidence |
| **Compliments as validation** | No commitment, no observed behaviour: nothing was tested outside the building |
| **Extending a wrong hypothesis** | Repeats the test instead of learning from it |
| **A sign-off per stage** | Duplicates the release's one decision; stage moves are graduation records |
| **Skipping a closed stage under pressure** | Spends the open beta on defects a small cohort would have caught cheaper |

Use canonical terms from `glossary-management`: **Canary Deployment**, **Acceptance Testing**, **Residual Risk**. Run `methodology-review` before hand-off.
