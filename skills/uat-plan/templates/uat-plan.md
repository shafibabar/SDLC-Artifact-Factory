# UAT Plan Template (standard and enterprise)

Copy the block below into `artifacts/<product>/customer-validation/uat-plan.md` and fill every bracket. At lean, use `./uat-plan-lean.md` instead. Delete the Exception section if the executor and the accepting authority are different people. The Completion Summary is filled after execution, before the sign-off.

````markdown
---
name: uat-plan
product: [product]
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars: the release, the acceptance types in scope, who executes and accepts, and the decision date]
profile: [standard | enterprise]
release: [release name — the walking skeleton it delivers]
traces_to: [ideate/moscow.md; ideate/story-map.md; ideate/acceptance-criteria/*.md; quality feature files]
---

# UAT Plan — [product], [release]

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | Must stories below | [intended users, by role] | uat-scenario results, exploratory debriefs | [accepting authority] |
| Operational acceptance (OAT) | [yes / no, because …] | [restore, rollback, alerting, …] | platform-engineer | [restore drill, runbook run, test alert] | [who accepts] |
| Contractual | [yes / no, because …] | [the clause, quoted] | [who] | [scenario + result] | [contract signatory] |
| Regulatory | [yes / no, because …] | [requirements from compliance-design] | [who] | compliance-verification attestations | [compliance signatory] |
| Alpha / beta | [yes / no, because …] | [cohort] | [cohort] | see beta-program-design | — |

## Scope Traceability
Must stories = the walking skeleton. Test basis = each story's acceptance criteria and feature file.
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk (where extra depth goes) |
|---|---|---|---|---|
| [US-n …] | [AC-US-n] | [path] | [UAT-na, UAT-nb] | [high / normal] |

## Out of Scope
[Should, Could and Won't stories; anything a user exercises outside these is logged as feedback, not as a UAT result.]

## Roles and Independence
- **Executor:** [name and role, organisation]
- **UAT lead:** requirements-analyst
- **Accepting authority:** [product owner] + [customer representative, role, organisation] [+ compliance signatory]
- **Independence level (ISTQB):** [none | within team | within organisation | business or user community | external] [per type at enterprise]

## Exception: solo operator
- Executor and accepting authority: [the product owner]
- Independence level (ISTQB): none
- Why no second party: [reason]
- Independence in time: scenarios frozen from Ideate acceptance criteria on [date]
- Evidence per scenario: screenshot or recording, date, environment, digest, flag state
- Borrowed session: [who, which scenarios, date] or "none available, because …"

## Environment
- **Environment:** [canary tenant id | staging label | production, flag on for the executor only]
- **Version / digest:** [chart version, image digest]
- **Feature flags:** [flag = value, scope]
- **Test data:** [seeded fixtures, accounts]

## Entry Criteria
- [ ] Quality-phase gates passed ([evidence])
- [ ] Deployed to the UAT environment at the digest that will ship
- [ ] Release flags on for the UAT cohort only
- [ ] Every Must story has its uat-scenario(s), traced to its acceptance criteria
- [ ] Acceptance criteria, pass threshold and defect bar agreed by the accepting authority on [date]
- [ ] Exploratory charters drafted ([n])
- [ ] Executors briefed and scheduled; OAT / regulatory evidence owners booked

## Exit Criteria
- Every scenario has a result: Pass, Fail, Blocked or Not run; Blocked and Not run fail this criterion until run
- Pass threshold: [100% of Must scenarios] [any lower threshold: agreed by …, on … (before execution), because …]
- Open defects: per the defect rule in acceptance-sign-off
- All feedback triaged (feedback-template)
- Exploratory charters run and debriefed: [n of n]
- Every acceptance type in scope has a result
- Residual risk evaluated and written in the Completion Summary

## Schedule
| Day | Date | Activity |
|---|---|---|
| 0 | [date] | Entry criteria verified; executors briefed; charters handed over |
| 1–3 | [dates] | Scripted scenarios and exploratory sessions [+ OAT window at enterprise] |
| 4 | [date] | Compile results; triage feedback |
| 4–5 | [dates] | Re-test fixes and regression-check neighbouring scenarios |
| 5 | [date] | Acceptance decision (acceptance-sign-off) |

## Exploratory Charters
| # | Charter | Time-box | Explorer | Heuristics |
|---|---|---|---|---|
| EX-1 | Explore [target], with [resources], to discover [information] | [45–90 min] | [human executor] | [interruptions, boundaries, …] |

## Repeatability
[Were all executors or design partners set up the same documented way? Note any who needed bespoke help.]

## Completion Summary
- **Planned vs run:** [n scenarios planned; n Pass, n Fail, n Blocked, n Not run]; charters [n of n]; acceptance types [results]
- **Open defects:** [ID, severity, workaround, owner] or "none"
- **Residual risk:** [what is knowingly accepted, by whom]
- **Recommendation:** [full / conditional / no-go, for acceptance-sign-off to decide]
````
