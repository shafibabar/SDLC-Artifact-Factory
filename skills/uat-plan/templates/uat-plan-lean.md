# UAT Plan Template — Lean (one page)

Copy the block below into `artifacts/<product>/customer-validation/uat-plan.md` at the **lean** profile. Same sections as the full template, a line or two each. Keep the Exception section when the product owner executes and accepts; delete it otherwise.

````markdown
---
name: uat-plan
product: [product]
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars]
profile: lean
release: [release — the Must block from ideate/user-stories.md]
traces_to: [ideate/user-stories.md (Must / Won't-this-time block); acceptance criteria; feature files]
---

# UAT Plan — [product], [release]

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | Must block | [who] | scenario results, one debrief | [who accepts] |
| Operational acceptance (OAT) | [yes: three-line smoke / no, because it holds no user data] | restore works; rollback works; someone gets alerted | [who] | one dated observation each | [who accepts] |
| Contractual | no, because [no contract] | — | — | — | — |
| Regulatory | no, because [not in a compliance scope] | — | — | — | — |
| Alpha / beta | no: skipped at lean | — | — | — | — |

## Scope Traceability
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk |
|---|---|---|---|---|
| [US-n …] | [AC-US-n] | [path] | [UAT-na] | [high / normal] |

## Out of Scope
[Contingency and Won't-this-time stories.]

## Roles and Independence
- **Executor:** [who]  · **UAT lead:** requirements-analyst  · **Accepting authority:** [who]
- **Independence level (ISTQB):** [none | …]

## Exception: solo operator
- Executor and accepting authority: the product owner · Independence level (ISTQB): none
- Why no second party: [reason]
- Independence in time: scenarios frozen from acceptance criteria on [date]
- Evidence per scenario: screenshot, date, environment, version, flag state
- Borrowed session: [who, which scenarios] or "none available, because …"

## Environment
[production with the release flag on for the executor only | the one staging environment] · version [x] · flags [x]

## Entry Criteria
- [ ] Quality gates passed · [ ] deployed at the version that will ship · [ ] scenarios traced to every Must
- [ ] Pass threshold and defect bar agreed on [date], before execution · [ ] one charter drafted

## Exit Criteria
- Every scenario Pass, Fail, Blocked or Not run; Blocked and Not run fail this criterion until run
- Pass threshold: 100% of Must scenarios
- Open defects: per the defect rule in acceptance-sign-off
- Charter run and debriefed; OAT smoke lines recorded; residual risk written below

## Schedule
[Day 1: scenarios and the charter · Day 2: re-test fixes, completion summary, acceptance decision]

## Exploratory Charters
- EX-1: Explore [target], with [resources], to discover [information] ([60] min, [human explorer])

## Completion Summary
- Planned vs run: [ … ] · Open defects: [ … ] · Residual risk: [ … ] · Recommendation: [ … ]
````
