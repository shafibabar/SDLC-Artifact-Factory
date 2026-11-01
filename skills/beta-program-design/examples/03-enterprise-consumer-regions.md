# Example 3 — Enterprise: a consumer open beta in waitlist waves across two regions; one region graduates to GA, the other is held on its own SLO and activation, with no second sign-off (hardest case)

Self-contained. **Hearthmeter** is a consumer app that reads a household's smart-meter data and shows energy use by appliance, at the **enterprise** profile. Release 2 adds Ireland to the UK. Irish meter data arrives through a different data provider. The release's one `acceptance-sign-off` was conditional, and its rollout path names the stages: UK open beta → UK GA, then Ireland open beta → Ireland GA.

## Input

> **User:** "The UK numbers are great, so let's take Hearthmeter to GA everywhere this week. Ireland's a bit behind, but it'll catch up. And since it's a new market, do we need a fresh sign-off for Ireland?"

Evidence, per region:
- **UK, open beta, waves 1–3** (2,000 / 6,000 / 6,000 users from a 38,000 waitlist): activation (meter linked within 7 days) 72%, 70%, 71% against a 60% target. Week-4 retention 51%, 47%, 46% against 40%. Meter-sync p95 18 minutes against a 30-minute SLO. Paid-tier conversion 3.1%. Support tickets per 1,000 users: 9 against a target of 25.
- **Ireland, open beta, wave 1** (3,000): activation 41% against 60%. Meter-sync p95 1 h 40 min against 30 minutes, from the provider's batch schedule. FB-112 (Medium): meter linking fails for one supplier's meter IDs; workaround: enter the MPRN by hand. No Critical or High.

## Working it

- **Graduation is per region.** The UK meets all four dimensions. Ireland misses traction (activation) and quality (its own SLO). The global average would hide that, so each region has its own row and its own decision.
- **Remediate Ireland, don't pivot it.** Both gaps are named and scoped (the provider's sync interval, FB-112), and the hypotheses hold: Irish users who do link a meter retain like UK users (wave 1, week 4: 45%). So it is **remediate**, not pivot, and not "it'll catch up", which is calendar graduation.
- **No new sign-off for Ireland.** There is one sign-off per release; its rollout path already names Ireland. Moving region by region is a graduation record. Only a new Critical or High, a failed graduation that re-opens Customer Validation, or a withdrawn acceptance would need a new UAT pass and a superseding sign-off (`acceptance-sign-off`). FB-112 is Medium, with a workaround, so it is within the defect rule.
- **GA is not the chasm.** These users came from a waitlist of enthusiasts. UK GA widens the audience; it does not show pragmatist households will buy. That stays a separate check in `gtm-strategy` (Moore).
- **Data handling** per region, in the product's own frameworks; telemetry beyond GA is opt-in.

## Output — the reply, and `customer-validation/beta-program/hearthmeter-release-2.md`

> UK to GA, yes: every target is met, wave after wave. Ireland, not yet. Activation is 41% against 60%, and meter data arrives in 1 h 40 min against a 30-minute target. Both causes are known: the provider's batch interval and the meter-ID bug FB-112, which has a manual workaround. So Ireland stays at wave 1 while they're fixed, then re-measures with a fresh wave. No new sign-off is needed: the release's sign-off already covers Ireland, and moving by region is a graduation step. One caution: UK GA comes from a waitlist of enthusiasts, so it doesn't show mainstream households will buy. Please approve UK GA and the Ireland hold.

````markdown
---
name: beta-program-hearthmeter-release-2
product: hearthmeter
release-slice: release-2
version: 1.4.0
phase: customer-validation
owner: requirements-analyst
created: 2027-01-11
summary: Hearthmeter Release 2 open beta by region: UK graduates to GA on activation, retention and SLO; Ireland held at wave 1 to remediate meter sync and FB-112.
profile: enterprise
traces_to: customer-validation/sign-off/release-2.md; customer-validation/uat-plan.md; strategy/business-model-canvas.md; slo/meter-sync.md
---

# Beta Program — hearthmeter release-2

## Shape
Consumer or high-volume open beta — stages run: closed beta → open beta (waitlist waves, per region) → GA; left out, and why: closed alpha — Release 1 ran it in the UK, and Release 2's code path is the same apart from the Irish data provider.

## Stage
Open beta

## Participants
Waitlist of 38,000, screened by "How do you track your energy use today?" (a named workaround) and "When did a bill last surprise you?" (recent pain). Closed beta: 600 UK households with a named workaround and a surprise in the last six months. Open beta: UK waves 1–3 (14,000); Ireland wave 1 (3,000).

| Candidate | ICP | Feedback | Rough edges | Named contact | Pain + prior effort (name the workaround) | Budget + reference | Result |
|---|---|---|---|---|---|---|---|
| Waitlist, screened | y — smart-meter households | y — in-app survey opt-in | y — beta label accepted | n/a consumer; 24 interviewees named per wave | Meter-reading spreadsheet or a supplier app, named in the answer | n/a consumer | invited by wave |

## Rollout Mechanic
canary-deployment: per region; UK at 100% of its open-beta cohort, Ireland at wave 1. feature-flag-design: `hearthmeter.appliance-view` targeted by region and wave through the targeting service (percentage below a region).

## Beta Agreement Status
In-app beta terms accepted by each user at invitation, with the date stored per account.

## Feedback Cadence
In-app survey at day 7 and day 28 per wave; 12 recorded interviews per wave per region, half with users who stopped; ad hoc reports in-app, Critical and High triaged the same day.

## Data Handling Statement
No control is relaxed for this beta: the same access control, data classification, encryption, tenant isolation and audit logging apply as at GA.
- Frameworks: UK GDPR and the Data Protection Act 2018 (UK users); EU GDPR (Irish users); Ofgem's consent rules for half-hourly smart-meter data (UK) — per compliance-design
- Telemetry: appliance-detection accuracy events, opt-in (64% opted in), switchable off in settings, kept 90 days

## Graduation Criteria
Targets set before the stage starts, per region.
- Quality: open defects within acceptance-sign-off's defect rule; meter-sync p95 ≤ 30 min per region (slo-definition), held for 14 days
- Traction: per wave cohort, activation (meter linked in 7 days) ≥ 60% and week-4 retention ≥ 40%
- Behaviour and commitment: interviewees describe a recent change made from the app, past tense; paid-tier conversion ≥ 2%
- Repeatability and operations: self-serve linking with ≤ 25 support tickets per 1,000 users; support covers each region's hours without engineering on call

## Graduation Record
Decision: Remediate
Suspect hypothesis: none — hypotheses hold; Ireland's gaps are named and scoped

| Region | Quality | Traction | Behaviour and commitment | Repeatability and operations | Decision |
|---|---|---|---|---|---|
| UK | Met: p95 18 min for 14 days; no open High | Met: activation 72/70/71%; week-4 retention 51/47/46% | Met: 31 of 36 interviewees changed a habit (tumble dryer, immersion timer); conversion 3.1% | Met: 9 tickets per 1,000 | **Advance to GA** |
| Ireland | Missed: p95 1 h 40 min (provider batch interval) | Missed: activation 41% (FB-112, Medium, MPRN workaround); week-4 retention 45% for linked users | Met: 10 of 12 interviewees changed a habit | Met: 14 tickets per 1,000 | **Remediate**: hold at wave 1 |

2027-01-11. UK: canary to 100% and terminate; flag on for all UK users; removed by its removal_date. Ireland: held at wave 1. platform-engineer moves the Irish sync to the provider's 15-minute feed (target 2027-02-01); backend-engineer fixes FB-112 (target 2027-01-25). Then Ireland wave 2 (5,000) is measured afresh. No further sign-off: the release's sign-off names this path. A new Critical or High would re-open Customer Validation instead. UK GA is not evidence the chasm is crossed (waitlist enthusiasts); gtm-strategy keeps that check.
````

## What the weak first draft looked like

"GA everywhere; Ireland will catch up." It graduated on the blended average, which hid an Irish SLO breach and an activation rate 19 points under target, and it asked for a fresh sign-off for a region the release's sign-off already covered. The opposite draft held the UK back for Ireland's problems, although the UK had met every target.
