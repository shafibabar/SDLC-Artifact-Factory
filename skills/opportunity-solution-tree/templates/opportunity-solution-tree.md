---
name: opportunity-solution-tree
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: the product outcome, the target opportunity and the solutions being tested>
profile: <standard | enterprise>
desired-outcome: <metric, baseline → target, deadline>
outcome-type: <product outcome | product outcome (learning goal)>
linked-kr: <KR ID from strategy/okrs.md>
evidence: <snapshot and feedback files cited, e.g. ideate/interviews/snapshots/2026-10-05-dp-1.md … | none: every opportunity is an assumption>
target-opportunity: <OPP-n.m>
cycle: <discovery cycle, e.g. 2026-11 or cycle 2>
traces_to: strategy/okrs.md; ideate/jtbd-analysis.md; <customer-validation/feedback/<date>.md>
---

<!-- Copy into ideate/opportunity-solution-tree.md (standard) or
     ideate/opportunity-solution-trees/<outcome-slug>.md (enterprise: one file per product outcome) and fill.
     Lean uses ranked-opportunity-list.md instead. Delete these comments.
     Every opportunity without a snapshot or feedback item behind it is tagged [assumption]. -->

# Opportunity Solution Tree — <Product>: <outcome in a few words>

## Desired Outcome

| Field | Value |
|---|---|
| Metric | <what is measured> |
| Meter | <how it is measured> |
| Baseline | <value, date> <!-- or "not set in KR" --> |
| Target | <value> |
| Deadline | <date> |
| Constraint | <a level that must not fall, or —> |
| Linked KR | <KR ID>: "<KR as written>" |
| Kind | **Product outcome**: <the customer behaviour, and why the team can move it directly> |

<!-- If the KR is a business outcome: "KR is a business outcome (<metric>); this product outcome is believed to drive it: <belief>" and list that belief under Assumptions as viability.
     If the KR is a traction metric: name the feature as a candidate solution and root the tree at what the feature was for. -->

## Evidence

| ID | Kind | Date | Participant / source | Segment / role | Interviewer |
|---|---|---|---|---|---|
| [<yyyy-mm-dd>-<participant>] | snapshot | <date> | <pseudonymous ID> | <segment, role> | <the user / design-partner lead> |
| [FB-<nnn>] | feedback item | <date> | <customer-validation/feedback/<date>.md> | <segment> | — |

## Tree at a Glance

```text
OUTCOME: <metric baseline → target>
├─ OPP-1 <experience step>
│  ├─ OPP-1.1 "<customer's voice>"
│  └─ OPP-1.2 "<customer's voice>"
└─ OPP-2 <experience step>
   └─ OPP-2.1 "<customer's voice>"  ◄ TARGET
      ├─ SOL-1 <solution>
      ├─ SOL-2 <solution>
      └─ SOL-3 <solution>
```

## Opportunity Space

<!-- Top level = steps of the customer's experience (experience map). Children nest under exactly one parent.
     Stories = independent conversations or feedback items that mention it (two mentions in one conversation = one).
     Enterprise: add a Segment / tenant role column and never pool story counts across segments. -->

| ID | Parent | Opportunity (customer's voice) | Experience step | Evidence | Stories |
|---|---|---|---|---|---|
| OPP-1 | — | <experience step as a branch> | <step> | — | — |
| OPP-1.1 | OPP-1 | "<I … when …>" | <step> | [<snapshot>], [FB-<nnn>] | <k> |
| OPP-1.2 | OPP-1 | "<…>" | <step> | [assumption] | 0 |

## Prioritisation

<!-- Compare siblings under one parent, one level at a time. Qualitative; any rating labelled "directional (n = k)". -->

### Level 1: <compare OPP-1 … OPP-n>

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-1 | <how many, how often> | <table stakes / differentiator> | <fit with strategy kernel> | <importance; how badly served> | <chosen / next / park> |

### Level 2: <compare the children of the chosen branch>

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|

**Target opportunity:** OPP-<n.m>. <One or two sentences: why, from the comparison. Chosen by the user on <date>; reversible, revisited next cycle.>

## Solutions for OPP-<n.m>

<!-- Generated in two passes (the second under a constraint); at least one non-software option; about three carried forward together. -->

| ID | Solution | Kind | Pass | Carried forward? |
|---|---|---|---|---|
| SOL-1 | <solution> | <software / non-software / policy> | <1 / 2: constraint> | yes |
| SOL-2 | | | | yes |
| SOL-3 | | | | yes |
| SOL-4 | | | | parked |

## Assumptions

<!-- Surfaced by walking the tree's lines, story-mapping each solution, and a pre-mortem.
     Type: desirability | viability | feasibility | usability | ethical. At least one ethical assumption per carried-forward solution. -->

| ID | Solution | Assumption | Type | Importance | Evidence today | Test first? |
|---|---|---|---|---|---|---|
| A-1 | SOL-1 | <what must be true> | desirability | high | <none / snapshot ref> | yes |
| A-2 | SOL-1 | <…> | ethical | high | none | yes |

## Assumption Tests

<!-- Success criterion written before the test runs, with a number and a population. The user runs anything involving a customer.
     Results go in ideate/assumption-tests/<yyyy-mm-dd>-<slug>.md, never into this file between cycles. -->

| ID | Tests | Across | Test | Success criterion (set before running) | Runs it | Record |
|---|---|---|---|---|---|---|
| T-1 | A-1 | SOL-1, SOL-2, SOL-3 | <comparison test, concierge, data look…> | <at least N of M … do X> | <the user> | <ideate/assumption-tests/<file>.md, or "not yet run"> |

## Re-plan Trigger

<What would send the team back to this tree after the chosen solution ships: the opportunity's pain persisting in new snapshots, or the outcome not moving although the opportunity is served.>

## Hand-off

- `impact-mapping`: the outcome and its fields as the WHY; OPP-<n.m> as the reason behind the HOW for <actor>; SOL-1…3 as WHAT candidates with assumptions A-… and tests T-….
- Next discovery cycle: open opportunities OPP-… and parked solutions SOL-….

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | <date> | First tree | Ideate, cycle <n> |
