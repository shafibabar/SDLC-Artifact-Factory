# Example 3 — Enterprise: two trees for a multi-tenant freight platform, segments kept apart, assumption tests tracked (hardest case)

Self-contained. **Haulwise** is a multi-tenant SaaS platform where enterprise shippers tender loads to small and mid-size carriers. It runs in two regions, holds driver location data under data-protection law (the EU GDPR for EU drivers), and serves two segments with different buying motions: shipper tenants (sales-led, annual contracts) and carrier accounts (self-serve). At the **enterprise** profile the tree is **required**, there is one tree per product outcome, opportunities are tagged by segment and tenant role, and every assumption test is a dated, tracked file.

## Input

> **KR (strategy/okrs.md, KR-1.1):** "Net revenue retention of shipper tenants from 104% to 115% by FY-end."
>
> **Evidence:** fourteen snapshots (eight shipper-side: logistics managers and procurement; six carrier-side: dispatchers and owner-operators), two beta feedback logs, and the JTBD analysis's per-segment job maps.

## Working it

- **KR-1.1 is a business outcome.** Revenue retention lags by a year and depends on pricing, sales and account management. The agent presents candidate product outcomes with the evidence for each, and the user and the OKR owner choose two, because expansion depends on both sides of the marketplace:
  - **Shipper outcome:** share of a shipper tenant's loads tendered through the platform rather than by email, 38% → 65%.
  - **Carrier outcome:** share of tendered loads accepted within two hours, 51% → 75%.
  The belief linking each to KR-1.1 is a viability assumption in its tree.
- **Two trees, two files**: `ideate/opportunity-solution-trees/shipper-tender-share.md` and `ideate/opportunity-solution-trees/carrier-acceptance-speed.md`. One tree with two roots would invite comparing a shipper need with a carrier need on story counts, which means nothing.
- **Segment and tenant role on every row.** Within the shipper tree, a need heard only from procurement is not pooled with logistics managers' needs.
- **Tracked tests.** Each test is a dated file under `ideate/assumption-tests/`; each tree lists its tests with their verdicts, refreshed at each cycle's revision, so running a test never reopens an approved tree.
- **Ethical assumptions carry weight here**: carrier-side solutions touch driver location. They are listed and tested like any other type. Data-protection specifics belong to this example, not to the skill's rules.

## Output 1 — `ideate/opportunity-solution-trees/carrier-acceptance-speed.md` (abridged to the decision path)

````markdown
---
name: opportunity-solution-tree
product: haulwise
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-03
summary: Carrier tree for loads accepted within 2 h (51% → 75%); target is dispatchers not knowing which driver can take a load; ethical test on location sharing.
profile: enterprise
desired-outcome: share of tendered loads accepted within 2 h, 51% → 75% by 2027-06-30
outcome-type: product outcome
linked-kr: KR-1.1
evidence: ideate/interviews/snapshots/ (6 carrier-side files cited below); customer-validation/feedback/2026-10-28.md
target-opportunity: OPP-2.1
cycle: 2026-Q4 cycle 2
traces_to: strategy/okrs.md (KR-1.1); ideate/jtbd-analysis.md (J-3 dispatcher job map); ideate/opportunity-solution-trees/shipper-tender-share.md
---

# Opportunity Solution Tree — Haulwise: carriers accept tendered loads fast

## Desired Outcome

| Field | Value |
|---|---|
| Metric | Share of tendered loads accepted within 2 h of tender |
| Meter | Tender and acceptance timestamps, all carrier accounts, both regions, rolling 4 weeks |
| Baseline | 51% (October 2026) |
| Target | 75% |
| Deadline | 2027-06-30 |
| Constraint | Acceptance-then-cancel rate stays below 3% |
| Linked KR | KR-1.1: "Net revenue retention of shipper tenants from 104% to 115%" |
| Kind | **Product outcome.** KR-1.1 is a business outcome; this outcome is believed to drive it because shippers expand where loads are covered fast (A-9, viability). Chosen with the user and the OKR owner on 2026-10-30, alongside the shipper tree |

## Evidence

| ID | Kind | Date | Participant / source | Segment / role | Interviewer |
|---|---|---|---|---|---|
| [2026-10-09-k-1] | snapshot | 2026-10-09 | K-1 | carrier, 40 trucks, dispatcher | the user |
| [2026-10-12-k-2] | snapshot | 2026-10-12 | K-2 | owner-operator | design-partner lead |
| [2026-10-16-k-3] | snapshot | 2026-10-16 | K-3 | carrier, 12 trucks, dispatcher | the user |
| [2026-10-21-k-4] | snapshot | 2026-10-21 | K-4 | carrier, 85 trucks, dispatcher | the user |
| [2026-10-23-k-5] | snapshot | 2026-10-23 | K-5 | owner-operator | design-partner lead |
| [2026-10-27-k-6] | snapshot | 2026-10-27 | K-6 | carrier, 25 trucks, dispatcher | the user |
| [FB-031] | feedback item | 2026-10-28 | customer-validation/feedback/2026-10-28.md | carrier, dispatcher | — |

## Opportunity Space

| ID | Parent | Opportunity (customer's voice) | Experience step | Segment / tenant role | Evidence | Stories |
|---|---|---|---|---|---|---|
| OPP-1 | — | See a tender | See a tender | carrier | — | — |
| OPP-1.1 | OPP-1 | "Tenders arrive in five places and I miss the good ones" | See a tender | dispatcher | [2026-10-09-k-1], [2026-10-21-k-4] | 2 |
| OPP-2 | — | Decide | Decide | carrier | — | — |
| OPP-2.1 | OPP-2 | "I can't say yes until I know which driver can take it, and that takes phone calls" | Decide | dispatcher | [2026-10-09-k-1], [2026-10-16-k-3], [2026-10-21-k-4], [2026-10-27-k-6], [FB-031] | 5 |
| OPP-2.2 | OPP-2 | "I don't trust the rate until I've worked out the empty miles back" | Decide | dispatcher, owner-operator | [2026-10-12-k-2], [2026-10-23-k-5] | 2 |
| OPP-3 | — | Accept | Accept | carrier | — | — |
| OPP-3.1 | OPP-3 | "On the road I can't accept anything without pulling over" | Accept | owner-operator | [2026-10-12-k-2], [2026-10-23-k-5] | 2 |

<!-- Owner-operators and dispatchers are compared separately: OPP-3.1 is the owner-operators' top need and is the target of the next cycle for that role. -->

## Prioritisation

### Level 1 (dispatchers): See, Decide, Accept

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-1 See | 2 of 4 dispatchers | Table stakes | Fits | Medium | next |
| OPP-2 Decide | 4 of 4 dispatchers, every tender | Differentiator: rivals stop at the load board | Guiding policy: "coverage in hours, not days" | High: tenders lost while phoning | **chosen** |
| OPP-3 Accept | owner-operators only | — | Fits | High for that role | compared within owner-operators |

### Level 2: children of OPP-2

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-2.1 Driver availability | 4 snapshots + FB-031 | Differentiator | Fits | High | **target** |
| OPP-2.2 Rate vs empty miles | 2, both owner-operators | Rival tools exist | Pricing team owns rates | Medium | park |

**Target opportunity:** OPP-2.1. Every dispatcher described phone calls before they could accept, and each call is time the 2-hour window loses. Chosen by the user on 2026-11-03; reversible.

## Solutions for OPP-2.1

| ID | Solution | Kind | Pass | Carried forward? |
|---|---|---|---|---|
| SOL-1 | Drivers set "available from / where" in the driver app; dispatcher sees it beside each tender | software | 1 | yes |
| SOL-2 | Live location from the carrier's existing telematics, matched to tender pickup | software | 1 | yes |
| SOL-3 | Tender shows required equipment and window first, so dispatchers phone only drivers who fit | software | 2: "one week" | yes |
| SOL-4 | Weekly availability call with the dispatcher, entered by our support team | non-software | 2: "no new code" | parked; does not scale past pilot |

## Assumptions

| ID | Solution | Assumption | Type | Importance | Evidence today | Test first? |
|---|---|---|---|---|---|---|
| A-1 | SOL-1 | Drivers keep their availability current without being chased | desirability | high | none | yes |
| A-2 | SOL-2 | Carriers will connect telematics to a shipper-facing platform | desirability | high | [2026-10-21-k-4] reluctant | yes |
| A-3 | SOL-2 | Location shown to dispatchers only, only during duty hours, never to shippers | ethical | high | none | yes |
| A-4 | SOL-1 | Availability entries are not used to rank or penalise drivers | ethical | high | none | yes |
| A-5 | SOL-2 | Telematics APIs for the top 3 providers return position within 5 min | feasibility | medium | none | yes |
| A-6 | SOL-3 | Equipment and window are filled on 90%+ of tenders | feasibility | medium | shipper tender data | later |
| A-9 | all | Faster acceptance raises shippers' tender share and so their spend | viability | medium | shipper tree OPP-1.2 | later |

## Assumption Tests

| ID | Tests | Across | Test | Success criterion (set before running) | Runs it | Record | Verdict |
|---|---|---|---|---|---|---|---|
| T-4 | A-1 | SOL-1 | Concierge: 3 carriers' drivers text availability to a number for 2 weeks | At least 60% of drivers send an update on 8 of 10 working days | the user, with K-1, K-3, K-6 | ideate/assumption-tests/2026-11-04-driver-availability-concierge.md | not yet run |
| T-5 | A-2, A-3 | SOL-2 | Comparison test with 6 dispatchers on their last lost tender: SOL-1, SOL-2, SOL-3 | At least 4 of 6 choose an option; any dispatcher who says drivers would object to SOL-2 is followed up with 2 drivers | the user | ideate/assumption-tests/2026-11-05-dispatcher-comparison.md | not yet run |
| T-6 | A-5 | SOL-2 | Spike against 3 telematics sandboxes | Position within 5 min for all 3 | backend-engineer | ideate/assumption-tests/2026-11-05-telematics-spike.md | not yet run |
| T-2 | A-1 (cycle 1) | SOL-1 | One-question in-app survey to drivers | At least 30% of 200 drivers answer "yes, daily" | the user | ideate/assumption-tests/2026-10-14-driver-survey.md | not supported (11%) |

<!-- T-2's miss in cycle 1 is why A-1 is tested again by behaviour (T-4) rather than by stated intent. -->

## Re-plan Trigger

If 2-hour acceptance in pilot carriers stays below 60% after six weeks, or dispatchers' snapshots still describe phoning drivers, return to OPP-2 and compare OPP-2.2 for dispatchers.

## Hand-off

- `impact-mapping` (map for KR-1.1): actor "carrier dispatcher", impact "accepts a fitting tender within 2 h instead of after calls", explained by OPP-2.1; WHAT candidates SOL-1…3 with A-1…A-9 and T-4…T-6.
- Shipper tree: A-9 depends on its OPP-1.2.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-10-14 | First tree; target OPP-2.1 with SOL-1 only | Ideate, cycle 1 |
| 2.0.0 | 2026-11-03 | Three solutions carried forward after T-2; owner-operator branch split out | Cycle 2 revision |
````

## Output 2 — the shipper tree, in one line

`ideate/opportunity-solution-trees/shipper-tender-share.md`: root "share of loads tendered through the platform, 38% → 65%"; top level *Plan → Tender → Track → Settle*; opportunities tagged logistics manager vs procurement; target OPP-1.2 "I email my regular carriers because I know they'll answer, and the platform's carriers are strangers", with its own three solutions and tests. Its tests are listed in its own tracking table.

## Output 3 — one tracked test file (after it ran)

```markdown
---
name: assumption-test
product: haulwise
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-14
summary: Driver survey on keeping availability current; 11% said daily against a 30% bar, so not supported; retest by behaviour.
tree: ideate/opportunity-solution-trees/carrier-acceptance-speed.md
test-id: T-2
assumption: A-1 drivers keep their availability current without being chased
assumption-type: desirability
solutions: SOL-1
success-criterion: at least 30% of 200 drivers answer "yes, daily"
criterion-set-on: 2026-10-14
run-by: the user
run-on: 2026-10-20
verdict: not supported
---

# Assumption Test T-2 — would drivers keep availability current?

## Result

| Measure | Value |
|---|---|
| Participants | 200 drivers invited, 142 answered |
| Met the bar | 15 of 142 (11%) answered "yes, daily" |

**Verdict:** not supported, against the criterion as set.

## What changes on the tree

At the cycle-2 revision: SOL-1 is not dropped (stated intent under-predicts behaviour), but A-1 is retested by behaviour (T-4), and SOL-2 and SOL-3 are carried forward beside it.
```

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| Two trees from one business KR | Each product outcome needs its own opportunity space; one tree would mix shipper and carrier needs |
| Segment / tenant-role column; owner-operators compared separately | One role's need is never averaged into another's |
| Two ethical assumptions, tested | Location and availability data can harm drivers if misused; the data-protection law that applies is this product's, not a rule of the skill |
| Test results in dated files, listed with verdicts | A weekly result never reopens the approved tree; the tree catches up at each cycle's revision |
| T-2's miss reshaped cycle 2 | Results are read against the bar set before the run, and the tree changes because of them |
