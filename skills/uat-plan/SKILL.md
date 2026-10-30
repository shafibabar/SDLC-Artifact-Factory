---
name: uat-plan
description: >
  Teaches how to plan acceptance testing for a deployed release in Customer
  Validation: choosing the acceptance types in scope (user acceptance testing,
  operational acceptance testing, contractual, regulatory, alpha / beta),
  scoping UAT to the release's Must stories (the walking skeleton) with the
  acceptance criteria and feature files as the test basis, naming the executor,
  UAT lead and accepting authority, the solo-operator exception when the
  product owner is the only person who can test and accept, the environment,
  entry and exit criteria (Pass / Fail / Blocked / Not run, residual risk), a
  time-boxed schedule with re-test time, and exploratory sessions with charters
  a human runs. Use when planning UAT or acceptance testing, deciding who
  tests and who accepts, writing UAT entry or exit criteria, planning
  operational acceptance (restore, rollback, alerting) or regulatory
  acceptance, asking whether an agent can do the exploratory testing, keeping
  Should stories out of UAT, or deciding what UAT looks like at the lean,
  standard or enterprise profile. Used by the requirements-analyst agent first
  in Customer Validation (/sdlc-validate), before uat-scenario and
  acceptance-sign-off; written to customer-validation/uat-plan.md.
version: 3.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, uat, acceptance-testing, operational-acceptance, regulatory-acceptance, exploratory-testing, test-independence, walking-skeleton, entry-exit-criteria]
produces: uat-plan
domain: validation
status: stable
related: [uat-scenario, acceptance-sign-off, beta-program-design, feedback-template, moscow-prioritization, story-mapping, acceptance-criteria, bdd-feature-file, canary-deployment, environment-config, feature-flag-design, disaster-recovery-plan, runbook-authoring, slo-definition, compliance-verification, compliance-design, stakeholder-mapping, test-pyramid, glossary-management, methodology-review]
sources:
  - research/testing/user-acceptance-testing-hambling.md
  - research/testing/explore-it-hendrickson.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/testing/testing-web-apis-winteringham.md
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
---

# UAT Plan

## Purpose

A UAT plan answers: **which acceptance tests does this deployed release need, against what, run by whom, and by what bar is it ready for the acceptance decision?** Hambling and van Goethem (*User Acceptance Testing: A Step-by-Step Guide*) put the point plainly: acceptance testing exists to give the accepting party enough confidence to **decide**. Finding defects is a side effect. The output that matters is the decision, which `acceptance-sign-off` records.

UAT here runs **after** Deploy, against the release that will reach everyone. It is not the pre-code agreement: `acceptance-criteria` and `bdd-feature-file` together are this plugin's ATDD (Pugh, *Lean-Agile Acceptance Test-Driven Development*), agreed before coding and automated in Quality. UAT is the later, human proof in the business-facing, product-critiquing quadrant (Q3 of the Agile Testing Quadrants, Crispin and Gregory, *Agile Testing*). Automation **checks** what was specified; UAT and exploration **test** what nobody specified. Neither replaces the other.

| Asking | Owner |
|---|---|
| Does the code meet the agreed rule, before merge? | Quality: `test-strategist`, `bdd-feature-file` |
| Does the deployed release do the job for its users, before we widen it? | Customer Validation: `requirements-analyst`, this skill |

## What the Plan Owns, and What It Does Not

The plan owns **scope, approach (acceptance types, scripted plus exploratory), roles, environment, entry and exit criteria, and schedule**. It does not own:
- the individual test scripts: each is a `uat-scenario`, one or more per Must story;
- the defect severity scale and triage: `feedback-template`;
- the go / no-go, the defect rule and the sign-off record: `acceptance-sign-off`;
- the staged rollout to wider cohorts: `beta-program-design`.

## 1. Choose the Acceptance Types First

Before scoping, decide which acceptance forms this release needs. The five forms are ISTQB's (Certified Tester Foundation Level), which Hambling's process sits inside. Each type in scope gets its own scope line, executor and evidence, and later its own line on the sign-off.

| Type | In scope when | Checked against | Executed by | Evidence comes from |
|---|---|---|---|---|
| **User acceptance (UAT)** | Always | The Must stories' acceptance criteria, as business scenarios | Intended users (or the product owner under the solo exception) | `uat-scenario` results, exploratory debriefs |
| **Operational acceptance (OAT)** | The product is run and supported by someone, or holds user data | Can it be operated: restore, rollback, alerting, upgrade, user management | `platform-engineer` | `disaster-recovery-plan` restore drill, `runbook-authoring` runbooks exercised, `slo-definition` alert fired |
| **Contractual** | Only when a signed contract states acceptance criteria | The contract's own clauses | Users or independent testers | The clause, the scenario that proves it, the result |
| **Regulatory** | The product is in a compliance scope (`compliance-design` says which laws or frameworks) | Regulation-derived requirements, with retained evidence | Users or independent testers; a named compliance signatory accepts | `compliance-verification` attestations |
| **Alpha / beta** | A cohort will use the release in its own context before general release | Feedback from real use | Real users at their own site | **Hand off to `beta-program-design`**; this plan only names the cohort's UAT |

Never hard-code a framework: which regulation applies comes from the product's own `compliance-design`. When to pick each type, what OAT covers at each profile, and the three-line lean OAT smoke: `./references/acceptance-types.md`. Read it whenever any type other than UAT might apply.

## 2. Scope: the Musts, Tested as Business Scenarios

UAT scope is the release's **Must stories, which are the walking skeleton** (`moscow-prioritization`, `story-mapping`; at lean, the Must / Won't-this-time block closing `ideate/user-stories.md`). The **test basis** is each Must's `acceptance-criteria` and its `bdd-feature-file` scenarios: UAT tests against what was agreed, never against the executor's memory of what was meant.

- Every Must story has **at least one** UAT scenario. A Must with none is an ungated promise. IDs are 1:N: `AC-US-5` → `UAT-5a`, `UAT-5b` (the same root, a letter per scenario).
- Design from **business scenarios** (Hambling): a realistic piece of work across several functions ("a steward closes Friday's overdue list"), then confirm every Must is touched. Re-running system tests with a person at the keyboard adds nothing.
- **Should, Could and Won't stories are out of scope.** A request to "add every Should too" is declined: it dilutes the time the Musts need and delays the decision. A Should a user happens to exercise is logged as feedback, never as a UAT result.
- **Risk decides depth** (Hambling): put extra scenarios and charters where failure would hurt the business most, not evenly.

## 3. Roles, Independence and the Solo-Operator Exception

Hambling's three-way split: an **executor** (an intended user) runs the scenarios and sessions; the **UAT lead** (the requirements-analyst) plans, briefs, observes without leading and compiles results; the **accepting authority** (the product owner plus a customer representative) decides. **By default the executor and the accepting authority are different people.** Every plan states the **test independence level** reached (ISTQB's scale, from "none" up to external independent testers).

**Solo-operator exception (D045).** When the product owner is the only person available, they may run UAT **and** sign off. The plan records it as an exception, not a hidden weakness:
- `Exception: solo operator`, with **independence level "none"** (ISTQB) and why no second party was available;
- scenarios **frozen before the build is seen**: they come from Ideate's acceptance criteria, which gives independence in time;
- **per-scenario evidence** (screenshot or recording, date, environment, digest, flag state), so anyone can re-judge later;
- at least one **borrowed session** with a real intended user, a colleague or a friend wherever one exists;
- **the agent is never the independent party**: it wrote the scenarios and facilitates.

A **full sign-off is allowed** under the exception; the exception record carries the risk. Do not cap the outcome at conditional because of it. The sign-off's own Exception block is `acceptance-sign-off`'s. Levels, the independence-without-headcount techniques, and a design partner who cannot attend: `./references/roles-and-independence.md`.

## 4. Environment

UAT runs where the release that will ship runs: the same image digest and configuration class, never a developer's local instance. At **standard and enterprise** that is a canary tenant (`canary-deployment`) or a production-like staging environment (`environment-config`); at **lean**, with no canary, it is production with the release flag on for the executor only (`feature-flag-design`), or the one staging environment. Record the environment, version or digest, and flag state, so a failed scenario can be reproduced exactly. Exploratory sessions use the same environment.

## 5. Entry Criteria

UAT does not start until all hold:
- Quality-phase gates passed for this release; the release is deployed to the UAT environment at the digest that will ship; release flags set for the UAT cohort only.
- Every Must story has its `uat-scenario`(s), traced to its acceptance criteria.
- **The acceptance criteria, pass threshold and defect bar are agreed by the accepting authority before execution** (Hambling: agree the yardstick first). They are never lowered once results arrive: a release that falls short goes to the acceptance decision as it is, and anything the authority then accepts is recorded there, in `acceptance-sign-off`.
- At least one exploratory charter per area of real risk; executors briefed and scheduled; each other acceptance type's evidence owner booked.

## 6. Exit Criteria

UAT closes, and the evidence moves to `acceptance-sign-off`, when:
- **Every scenario has a result: Pass, Fail, Blocked or Not run.** Blocked (an environment problem or an earlier defect stopped it) and Not run both **fail** this criterion until the scenario is run. Hiding them overstates readiness.
- **Pass threshold: 100% of Must scenarios by default**, because the Musts are the release's promise: one failing Must means the release is not usable. A lower threshold is allowed only if agreed and signed before execution, with its reason. Lowering it after the results ("we got 90%, so make it 90%") is refused.
- Open defects are handled by the **single defect rule in `acceptance-sign-off`**, which says what an open Critical or High allows. The plan never sets a defect bar of its own.
- All feedback triaged (`feedback-template`); every planned charter run and debriefed (a separate criterion: a charter has no pass/fail); every acceptance type in scope has a result.
- **Residual risk evaluated and written down** (ISTQB): what is knowingly accepted, by whom.
- A short **completion summary** (planned vs run, results, open defects, residual risk, recommendation) closes the plan. It is a section, not a new artifact.

Meeting the exit criteria readies the decision; it does not make it.

## 7. Schedule

Time-boxed, with the decision date fixed before execution:

| Day | Activity |
|---|---|
| 0 | Entry criteria verified; executors briefed; charters handed over |
| 1–3 | Scripted scenarios and exploratory sessions, same executors, same environment |
| 4 | Compile results; triage all feedback |
| 4–5 | **Re-test and regression**: a fix counts only when its failing scenario re-runs green and its neighbours are re-checked |
| 5 | Acceptance decision (`acceptance-sign-off`) |

Lean compresses to one or two days. Enterprise runs this per tenant wave, with a separate OAT window. Execution may stretch for executor availability; the compile-and-decide tail does not.

Where there are several executors or design partners, note whether each was set up the **same documented way**. Blank (*The Four Steps to the Epiphany*) defines Customer Validation by repeatability: three passes that each needed bespoke, founder-led hand-holding are weaker evidence than they look.

## 8. Exploratory Sessions

Scripted scenarios prove the known; they cannot find what nobody wrote down. The plan therefore includes time-boxed **exploratory sessions** (Hendrickson, *Explore It!*): each has a charter, *"Explore [target], with [resources], to discover [information]"*, a 45–90 minute time-box, notes taken during the session, and a debrief that may produce new charters. The requirements-analyst **drafts** charters; **a human explores**. An agent reasoning over screenshots or a UI description is scripted testing with an exploratory label: say so plainly if asked to "do the exploratory testing". API-level probing of raw HTTP is a different practice that belongs earlier, with `test-strategist` (Winteringham, *Testing Web APIs*). It is not a UAT session.

Charter writing, the heuristics (CRUD, boundaries, Goldilocks, interruptions, configuration, saboteur) and charter-generates-charter: `./references/exploratory-testing.md`. Record each session in `./templates/exploratory-session.md`.

## Scale

`phase-requirements.json`: `uat-plan` and `acceptance-sign-off` are **required at every profile**; `beta-program-design` is skipped at lean and optional above; `feedback-log` is optional.

| Profile | Shape of `customer-validation/uat-plan.md` |
|---|---|
| **lean** | **One page** from `./templates/uat-plan-lean.md`: UAT plus, if the product holds user data, a three-line OAT smoke (restore works, rollback works, someone gets alerted); scope = the Must block; roles usually the solo-operator exception; production behind a flag or one staging environment; one or two days; at least one charter; exit criteria and residual risk in a few lines. `./examples/01-lean-toolshed.md` |
| **standard** | Full template `./templates/uat-plan.md`: UAT and OAT; design-partner executors on a canary tenant or staging; a five-day window with re-test; charters per risky area; repeatability note. `./examples/02-standard-rebound.md` |
| **enterprise** | Every type that applies, each with its own executor and sign-off line (OAT by platform-engineer, regulatory against attestations, contractual per tenant contract); UAT per tenant wave on the canary; independence level per type. `./examples/03-enterprise-permitry.md` |

## Producing the Plan

1. **Read** the product manifest, the Must stories (story map skeleton and MoSCoW, or the lean Must block), their acceptance criteria and feature files, `compliance-design` and any customer contract.
2. **Select the acceptance types** (§ 1).
3. **Write the traceability table**: Must story → AC → UAT scenario IDs (§ 2).
4. **Name the roles and independence level**; record the exception if solo (§ 3).
5. **Fix environment, entry and exit criteria, and schedule** (§ 4–7); draft charters (§ 8).
6. **Validate** against `./resources/uat-plan-checklist.md` and run `python3 ./scripts/check-uat-plan.py customer-validation/uat-plan.md`. If you cannot run it, walk the checklist by hand.
7. **Hand off**: scenarios to `uat-scenario`; OAT and regulatory evidence requests to their owners; after execution, the completion summary to `acceptance-sign-off`.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **UAT as a second QA pass** | Same scope as automation, with a person clicking: no new signal |
| **Every Should in scope** | Dilutes the Must signal and delays the decision |
| **UAT on local dev** | Not what ships; proves nothing about the rollout |
| **Yardstick set after the results** | An acceptance decided without agreed criteria is a negotiation |
| **Blocked counted as passed** | Overstates readiness; Blocked and Not run fail the exit |
| **A defect bar of the plan's own** | Two rules drift; the one rule is `acceptance-sign-off`'s |
| **Hidden solo testing** | Same person executes and accepts with no recorded exception |
| **"The agent explored it"** | No human judgement in the loop; it is scripted testing |
| **UAT only, for a hosted or regulated product** | Nobody checked it can be operated, or that the regulation is met |
| **No re-test time** | "Fixed" means deployed, not proven |
| **Product rules as skill rules** | A persona, framework or tenant rule belongs in that product's plan |

Use canonical terms from `glossary-management`: **Acceptance Testing**, **User Acceptance Testing**, **Operational Acceptance Testing**, **Test Independence**, **Exploratory Testing**, **Test Charter**, **Entry Criteria**, **Exit Criteria**, **Residual Risk**, **Walking Skeleton**. Run `methodology-review` before hand-off.
