---
name: beta-program-[product]-[release-slice]
product: [product name]
release-slice: [release-slice]
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: [date]
summary: [one sentence, ≤ 200 chars — what this artifact establishes; indexed as its memory-engine abstract]
profile: [lean / standard / enterprise]
traces_to: [stakeholder-map path; uat-plan path; business-model-canvas path]
---

# Beta Program — [product] [release-slice]

## Shape
[B2B design partners / Internal rollout / Consumer or high-volume open beta] — stages run: [e.g. closed alpha → closed beta → open beta → GA]; left out, and why: [stage — reason, or "none"]

## Stage
[Closed alpha / Closed beta / Open beta / GA]

## Participants
[Names, companies, ICP-fit rationale, named contact]

| Candidate | ICP | Feedback | Rough edges | Named contact | Pain + prior effort (name the workaround) | Budget + reference | Result |
|---|---|---|---|---|---|---|---|
| [name, company] | [y/n — why] | [y/n] | [y/n] | [name, role] | [e.g. "shared spreadsheet since 2024"] | [y/n] | [in / downgraded / declined] |

## Rollout Mechanic
[canary-deployment wave or region + feature-flag-design key and scope; whether the platform splits traffic within a tenant]

## Beta Agreement Status
[Accepted / pending per participant, with date]

## Feedback Cadence
[Check-in schedule; ad hoc channel; UAT window]

## Data Handling Statement
No control is relaxed for this beta: the same access control, data classification, encryption, tenant isolation and audit logging apply as at GA.
- Frameworks: [the product's own, from compliance-design — or "the product's own policy" when none applies]
- Telemetry: [what is collected beyond GA, and the consent recorded — or "none beyond GA"]

## Graduation Criteria
Targets set before the stage starts.
- Quality: [UAT threshold (uat-plan); defects within acceptance-sign-off's defect rule; SLOs held through the canary window]
- Traction: [activation and retention per cohort, with targets and the window — from the canvas's Key Metrics]
- Behaviour and commitment: [observed use described past tense by each named contact; the commitment asked for]
- Repeatability and operations: [same documented onboarding for each participant; the backstage runs without hand-holding]

## Graduation Record
Decision: [Pending / Advance / Extend / Remediate / Pivot]
Suspect hypothesis: [segment / problem / solution / process — and its canvas block; "none" on Advance or Pending]
[Date; evidence for each of the four dimensions; the rollout change handed to platform-engineer]
