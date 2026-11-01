---
name: nfr-specification
description: >
  Teaches how to write the non-functional requirements (NFR) specification in
  Ideate: consume the functional requirements document's quality-attribute
  hand-off (QA-n) and business-rule catalogue (BR-n), walk the ISO/IEC 25010
  quality characteristics plus deployability, write each NFR as a
  quality-attribute scenario (Bass: source, stimulus, environment, artifact,
  response, response measure) with Planguage Must / Plan / Stretch targets
  scaled to the profile, rank the scenarios (a utility tree at enterprise),
  cross-check them for conflicts as candidate trade-off points, and hand the
  architecturally significant ones to enterprise-architect. Use when writing,
  reviewing or ranking non-functional requirements or quality attributes
  (performance, latency, availability, RTO/RPO, scalability, security,
  usability, accessibility, maintainability, deployability), turning "fast",
  "instantly" or "99.9%" into a testable requirement, citing data residency or
  retention rules in an NFR, or deciding whether DORA delivery metrics belong
  in an NFR (they are process targets owned by dora-metrics). Used by the
  requirements-analyst agent in Ideate (/sdlc-ideate) after the functional
  requirements and before epics; required at lean, standard and enterprise.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, nfr, quality-attributes, quality-attribute-scenario, iso-25010, utility-tree, trade-off, architecture-input, deployability]
produces: nfr-specification
domain: discovery
status: stable
related: [requirements-analysis, okr-authoring, gtm-strategy, competitive-analysis, dora-metrics, slo-definition, go-load-test, platform-engineering-design, adr-authoring, glossary-management, methodology-review]
sources:
  - research/software-architecture/software-architecture-in-practice-bass.md
  - research/requirements-and-user-stories/software-requirements-wiegers-beatty.md
  - research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/devops-and-delivery/accelerate-forsgren-humble-kim.md
  - research/devops-and-delivery/platform-engineering-fournier-nowland.md
---

# NFR Specification

## Purpose

The NFR specification answers: **how well must the product do what the functional requirements say, under which conditions, and how will each target be checked?** Wiegers and Beatty (*Software Requirements*) call these **quality attributes**; the Hathaways (*Getting and Writing IT Requirements in a Lean and Agile World*) place them in the Solution tier as its non-functional half. Bass, Clements and Kazman (*Software Architecture in Practice*, 4th ed.) give the reason they matter: almost any structure can deliver the features, but only some deliver them with the required availability or latency. **Quality attributes, not features, drive the architecture**, so this artifact is `enterprise-architect`'s first input.

An NFR that cannot fail a test is a wish. "Fast" and "highly available" become NFRs only when they say under what conditions, by how much, and how it will be measured.

## Where It Sits

```
Ideate: … impact map ─► functional requirements (FRD) ─► NFR SPECIFICATION ─► epics ─► stories … ─► MoSCoW
                                                              └─► Design: enterprise-architect (handoff) · Deploy: slo-definition
```

| Reads | What it takes |
|---|---|
| `requirements-analysis` (FRD) | The **Quality-Attribute Hand-off** (QA-n, each with the FRs it constrains), the **Business Rules** catalogue (BR-n), constraints (CON-n) and data requirements (DR-n). At lean there is no FRD: read the quality concerns and business rules in the requirements header of `ideate/user-stories.md`, or ask the user |
| `okr-authoring`, `gtm-strategy`, `competitive-analysis` | Business value behind a target: an SLA buyers expect, table-stakes quality, the KR a slow path would hurt |
| `sdlc-config.json` | Scale profile; `compliance_frameworks` (control families the product must satisfy) |

| Feeds | What it gives |
|---|---|
| `enterprise-architect` | The **Architecture Handoff**: architecturally significant scenarios, their ratings and the candidate trade-off points |
| `security-architect`, `domain-modeler` | Security scenarios; residency and isolation obligations (citing BR-n) |
| `slo-definition` (Deploy) | Availability and latency scenarios, which it formalises as SLIs and SLOs. The NFR states the requirement; the SLO is how it is monitored |
| Quality phase (`go-load-test`, test plan) | Each response measure is a test's pass condition; the NFR ID is the traceability key |

## Step One: Consume the Hand-offs, Never Restate Them

`requirements-analysis` refused to put "instantly" or "99.9%" inside a functional requirement and handed them here as QA-n. It catalogued regulations such as data residency once, as BR-n. This skill picks both up; **one fact, one home**:

| From the FRD | Becomes here | Never |
|---|---|---|
| QA-n quality concern | One or more scenarios tracing to QA-n and the FRs it constrains, or a one-line decline with its reason | Silently dropped; a QA-n with no line in **Inputs Consumed** is a defect |
| BR-n regulation or policy (residency, retention, a control) | An **obligation** row (NFR-OBL-n): the measurable thing *this system* must do or prove, and its check, citing BR-n | Restating the rule, or a second residency or retention rule written here |
| CON-n constraint | Read as a fixed condition on scenarios (an environment or a limit) | Turned into an NFR target |
| A number the user gave ("99.9%") | A **candidate** Plan value, kept only if a business driver justifies it | Copied as the target without asking why |

If an obligation has no BR-n yet, do not create the rule here: add it to the FRD's Business Rules (the backlog header at lean), as a change request if the FRD is approved, then cite it. Likewise, when an NFR implies functional behaviour ("lock the account after 5 failed sign-ins"), send it back to the FRD as a **derived requirement** (Wiegers) rather than leaving it only here.

## What Is, and Is Not, an NFR

| Item | Where it lives |
|---|---|
| How well the product behaves under stated conditions (latency, recovery, isolation, learnability, deployability) | **Here**, as a quality-attribute scenario |
| A regulation, policy or contract term (residency, retention, a SOC 2 or GDPR control) | FRD business rule (BR-n); here only the measurable obligation that cites it |
| How the *team* delivers: deployment frequency, lead time for changes, change failure rate, test coverage, CI duration | **Process targets** (PT-n), a separate, optional section. Values come from `dora-metrics`, never set here |
| SLI definitions, error budgets, burn-rate alerts | `slo-definition` (Deploy), formalising this artifact's availability and latency scenarios |
| What the software does, with its fit criterion | The FRD |

**Why DORA figures are not NFRs.** Forsgren, Humble and Kim (*Accelerate*) validate the four key metrics as measures of a team's **delivery performance** across many changes, and warn that the clusters are directional, not hard thresholds. No ISO/IEC 25010 characteristic is "how often the team deploys". What the architecture must support is **deployability** (Bass, 4th ed.): one service can be deployed and rolled back on its own, with no manual step. That is a product scenario here; the rates are process targets, calibrated in `dora-metrics`, and never defaulted to the high-performer cluster.

## The Quality-Attribute Scenario

Every NFR is a **quality-attribute scenario** (Bass): six parts, so the conditions are part of the shape and a missing one is visible.

| Part | Says | Example |
|---|---|---|
| **Source** | Who or what causes the event | 200 parents at once; an attacker with a stolen password; the on-call developer |
| **Stimulus** | The event | Opens the timetable; a zone fails; a fix is ready to release |
| **Environment** | Conditions at the time | Monday 07:00 peak; normal operation; one node lost |
| **Artifact** (affected part) | The part of the system affected | The booking API; the tenant database; the whole system |
| **Response** | What the system does | Returns the page; fails over and keeps accepting writes; blocks and logs |
| **Response measure** | The number that makes it testable | P95 ≤ 800 ms (Must), ≤ 400 ms (Plan); RTO 15 min, RPO 0 |

Call it a *quality-attribute scenario*, never just "scenario" (that word means a Gherkin `Scenario`), and read "artifact" as *the part of the system affected*, not a document. Put the target inside the response measure in **Planguage** (Tom Gilb, as taught by Wiegers and Beatty): **Must** is the minimum acceptable, **Plan** the target, **Stretch** the ambition. Planguage *Must* is not MoSCoW *Must*. Latency is always a percentile with its load, never an average. Availability is written as **failure scenarios** (what fails, what the system does, time to detect and recover, data lost); an uptime percentage is one response measure among them, which `slo-definition` later turns into an SLO.

The six parts, the general-scenario library per characteristic, Planguage and the Platform DX scenarios for internal platforms: `./references/quality-attribute-scenarios.md`. Read it before drafting the first scenario and whenever a characteristic's stimuli or measures are unclear.

## Coverage: Walk ISO/IEC 25010, Then Keep Only What Matters

ISO/IEC 25010 (2023) names nine product-quality characteristics: functional suitability, performance efficiency, compatibility, interaction capability (2011: usability), reliability, security, maintainability, flexibility (2011: portability, now including scalability) and safety. Bass adds **deployability**, which the standard lacks. Walk all ten: each gets at least one candidate scenario or a one-line decline with its reason ("flexibility: one cloud region, no portability need"). Functional suitability is declined by default: the FRD's fit criteria own it. The standard is a checklist, not a quota, and it gives names, not targets.

Then **rank**. Wiegers advises specifying the few attributes that matter. Bass's utility tree rates each scenario on **business value** and **architectural impact**, High / Medium / Low. A scenario rated H on architectural impact is an **architecturally significant requirement** (ASR) and goes into the handoff. (L, L) scenarios get one line or are dropped. The lean rule in `phase-requirements.json` ("only the NFRs that change a design decision") is this test.

The characteristics with sub-characteristics and typical stimuli, the utility tree, the conflict check and the handoff format: `./references/ranking-and-trade-offs.md`. Read it when ranking, and before the handoff.

## The Conflict Check

Richards and Ford (*Fundamentals of Software Architecture*) call architecture characteristics competing forces: everything is a trade-off. Before the handoff, take each pair of highly rated scenarios and ask whether meeting one makes the other harder. Typical pairs: cross-region failover vs data that must stay in one country; low latency vs encryption and audit on every call; tenant isolation vs cost per tenant; fast deployability vs a manual approval gate. Record each clash as a **candidate trade-off point** (TP-n, Bass's ATAM term) naming the scenarios, why they pull apart and the options open. **Do not choose**: resolving it is an architecture decision for `enterprise-architect`, recorded in an ADR (`adr-authoring`), or a product decision for the user.

## Producing the Artifact

1. **Check the profile** (Scale, below) and read the inputs. If the FRD (standard, enterprise) is missing or not approved, stop and say so.
2. **List Inputs Consumed**: every QA-n, BR-n and CON-n the NFRs draw on, and what each became.
3. **Walk the characteristics**; draft candidate scenarios from the general-scenario library; decline the rest with a reason.
4. **Rank** (lean: an ordered list; standard: rated value and impact; enterprise: a utility tree).
5. **Write the kept scenarios** in the profile's form, each tracing to QA-n, the FRs and, for an obligation, BR-n. Ask "why this number?" of every Plan value: a business driver, or it is a copy-paste target.
6. **Name the verification** for each response measure: the Quality-phase test or measurement that passes or fails it.
7. **Run the conflict check**; record candidate trade-off points.
8. **Send derived requirements** back to the FRD and record them.
9. **Process targets** only as the profile allows, values chosen by the user from `dora-metrics`.
10. **Write the Architecture Handoff**: every ASR, its rating, the trade-off points it is in, and (as pointers only) the tactic families that usually serve it. Tactics are chosen at Design.
11. **Validate** against `./resources/nfr-checklist.md`, run `python3 ./scripts/check-nfr.py <artifact>`, and write from `./templates/nfr-specification.md` to `ideate/nfr-specification.md`.

## Scale

`phase-requirements.json`: **required** at every profile; lean is "short — only the NFRs that change a design decision". Targets scale with the profile: **minimum** at lean, **target** at standard, **stretch** at enterprise.

| Profile | Shape |
|---|---|
| **lean** | Inputs from the backlog header and the user. The ten characteristics at top level, one line each to keep or decline. **3–8 scenarios** in short form: stimulus, environment, response measure with **Must** only. An ordered list, each kept scenario because it changes a design decision. One deployability scenario. No process targets unless the user asks. Conflict check on the kept few: `./examples/01-lean-toolshed.md` |
| **standard** | The FRD hand-off in full. Characteristics plus the relevant sub-characteristics. Each scenario rated business value / architectural impact; all six parts for any scenario rated H, short form for the rest. **Must and Plan**. Candidate trade-off points. Process targets optional: `./examples/02-standard-rebound.md` |
| **enterprise** | A full **utility tree** (utility → characteristic → refinement → rated scenarios). All six parts on every kept scenario. **Must, Plan and Stretch**, per service tier and per tenant tier or region where they differ. Trade-off and sensitivity points flagged for a lightweight architecture evaluation at Design. Process targets per service tier, set by the user from `dora-metrics`: `./examples/03-enterprise-permitry.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Wish NFR** ("fast", "secure", "highly available") | No falsifying condition; it passes every demo |
| **Target without environment** | "P95 < 200 ms" at what load, on what data? A missing environment part shows it |
| **Average as target** | The mean hides the tail where users suffer; use percentiles |
| **Copy-paste nines** | Each nine multiplies cost; a 99.99% rated M on business value is caught by its own rating |
| **Restated rule** | Residency written here as well as BR-n: two homes drift apart |
| **DORA as an NFR** | Team process rates, mandated per service, contradict *Accelerate*'s caution; deployability is the product property |
| **Every characteristic in full** | A lean product drowns; rank, keep few, decline the rest with a reason |
| **Conflict left implicit** | The architect discovers the clash mid-design; record it as a candidate trade-off point |
| **Tactic chosen in the NFR** | "Use a service mesh" is a design decision; the NFR stops at the response measure |
| **Orphaned NFR** | An NFR ID no Quality-phase test references was never verified |
| **Product rule as skill rule** | A SOC 2 control or a region belongs in that product's BR-n, not in every product's NFRs |

Each anti-pattern with its fix: `./references/anti-patterns.md`. Read it when reviewing an NFR document or when a draft target feels arbitrary.

Use canonical terms from `glossary-management`: **Quality Attribute**, **Quality-Attribute Scenario**, **Utility Tree**, **Architecturally Significant Requirement**, **Trade-off Point**, **Planguage**, **Deployability**, **Process Target**, **Business Rule**, **Encryption at Rest**, **Encryption in Transit**, **Zero Trust Architecture**. Run `methodology-review` before hand-off.
