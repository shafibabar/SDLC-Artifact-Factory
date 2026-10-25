---
name: nfr-specification
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: the few quality attributes that shape this product's design, with their headline targets and conflicts>
profile: <lean | standard | enterprise>
status: <draft | approved>
linked-frd: <ideate/requirements.md | ideate/user-stories.md (lean: the requirements header)>
traces_to: <linked-frd> (QA-…, BR-…); strategy/okrs.md (<KR>)
architecture-handoff: [<NFR IDs rated H on architectural impact>]
---

<!-- Copy into ideate/nfr-specification.md and fill. Delete these comments.
     lean: short-form scenario table, Must only, an ordered ranking list, 3–8 scenarios.
     standard: six-part table for every scenario rated H on either scale; Must and Plan.
     enterprise: utility tree; six parts on every kept scenario; Must, Plan and Stretch,
     per service tier and tenant tier or region where they differ. -->

# Non-Functional Requirements — <Product>

**Translation.** <Which hand-offs (QA-n, BR-n) and drivers (KRs, SLAs) become which scenarios, for which consumers (enterprise-architect, security-architect, slo-definition, the Quality phase).>

Targets use Planguage: **Must** is the minimum acceptable, **Plan** the target, **Stretch** the ambition. Planguage *Must* is not a MoSCoW priority. Ratings were drafted by the requirements-analyst and are confirmed by the user at the gate.

## Inputs Consumed

<!-- Every QA-n from the FRD's hand-off, and every BR-n / CON-n an NFR draws on. -->

| Input | Says (cited, not restated) | Became |
|---|---|---|
| QA-1 | <quality concern, as worded in the FRD> | <NFR-…, or "declined: <reason>"> |
| BR-1 | <rule name only; the rule lives in the FRD> | <NFR-OBL-…> |
| CON-1 | <constraint name> | <environment of NFR-…> |

## Characteristics Considered

| Characteristic | Decision |
|---|---|
| Functional suitability | Declined: the FRD's fit criteria own it |
| Performance efficiency | <kept: NFR-PERF-… / declined: reason> |
| Compatibility | <…> |
| Interaction capability (usability) | <…> |
| Reliability | <…> |
| Security | <…> |
| Maintainability | <…> |
| Flexibility (portability, scalability) | <…> |
| Safety | <…> |
| Deployability | <kept: NFR-DEPLOY-…> |

## Ranking

<!-- lean: an ordered list, each line saying which design decision the scenario changes.
     standard: the table below.
     enterprise: rename to "## Utility Tree", draw the tree (utility → characteristic →
     refinement → leaf, each leaf "(value, impact)"), and keep the table below it. -->

| Rank | NFR | Business value | Architectural impact | Why |
|---|---|---|---|---|
| 1 | NFR-… | H | H | <the driver; the structure it changes> |

## Quality-Attribute Scenarios

<!-- lean (short form): | ID | Characteristic | Stimulus | Environment | Response measure | Traces to | Verification |
     standard / enterprise (full form, below). Latency as percentiles with their load.
     Availability as failure scenarios: detect, recover, RTO, RPO. -->

| ID | Characteristic (sub) | Source | Stimulus | Environment | Affected part | Response | Response measure | Traces to | Verification |
|---|---|---|---|---|---|---|---|---|---|
| NFR-PERF-01 | Performance efficiency (time behaviour) | <who, how many> | <event> | <peak, data size, where> | <part> | <what the system does> | <P95 ≤ … (Must), ≤ … (Plan), ≤ … (Stretch)> | <QA-n; FR-…; KR-…> | <load test on …> |
| NFR-REL-01 | Reliability (recoverability) | <zone / dependency> | <fails> | <when> | <part> | <detect, fail over, recover> | <RTO … (Must), … (Plan); RPO …> | <QA-n> | <failover drill, …> |
| NFR-DEPLOY-01 | Deployability | <developer / pipeline> | <a fix is ready> | <normal operation> | <one service> | <deployed, no manual step; rolled back if it fails> | <ready → running ≤ … (Must); rollback ≤ … (Must)> | <QA-n or "product property"> | <timed release rehearsal> |

## Obligations from Business Rules

<!-- One row per BR-n that requires this system to do or prove something measurable.
     Cite the rule; never restate or extend it. "None" if no rule applies. -->

| ID | Business rule | Measurable obligation on this system | Verification |
|---|---|---|---|
| NFR-OBL-01 | BR-n | <what is stored, processed, kept or logged where, measurably> | <policy-as-code test, retention test, audit query> |

## Candidate Trade-off Points

<!-- Each pair of highly rated scenarios where meeting one makes the other harder.
     Do not choose; "None found" is allowed when the check was run. -->

| ID | Scenarios | Why they pull apart | Options open (not chosen) | Decided by |
|---|---|---|---|---|
| TP-1 | NFR-… × NFR-… | <…> | <…> | <enterprise-architect (ADR) / the user> |

## Derived Requirements

| From | Functional requirement sent to the FRD | Status |
|---|---|---|
| NFR-… | <behaviour the NFR implies> | <FR-… added / change request raised / none> |

## Process Targets

<!-- Not product quality attributes. lean: "None set" unless the user asks. standard:
     optional. enterprise: per service tier. Values are the user's choice, calibrated
     against dora-metrics' clusters (never copied from them as a default). Test coverage
     and CI duration belong here too. -->

| ID | Target | Scope | Value (chosen by the user) | Calibration | Measured by |
|---|---|---|---|---|---|
| PT-1 | <deployment frequency / lead time for changes / change failure rate / coverage> | <service tier> | <…> | `dora-metrics` | <pipeline event> |

## Architecture Handoff

<!-- Every scenario rated H on architectural impact, and every trade-off point.
     Tactic families are pointers; choosing one is a Design decision. -->

| NFR | Rating (value, impact) | Trade-off points | Tactic families (pointers only) |
|---|---|---|---|
| NFR-… | (H, H) | TP-… | <redundancy and failover / concurrency and caching / …> |

## Open Questions

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | <…> | <NFR-…> | <the product owner> | <before the Design phase gate> |
