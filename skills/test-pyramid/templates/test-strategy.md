---
name: test-strategy
product: [product slug]
version: 1.0.0
phase: implement
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: what is proven at which layer, the gates, and what is still open]
traces-to: [ideate/acceptance-criteria/, ideate/nfr-specification.md, [design artifacts]]
---

# Test Strategy for [Product]

<!-- Path: artifacts/<product>/implement/test-strategy.md. The product owner approves it.
     Every profile plans every layer; size changes the number of rows, never the layers.
     No layer ratios. No invented targets. Delete these comments' advice only after following it. -->

- **Profile:** [lean | standard | enterprise]
- **Languages:** [any of: go, python, typescript]
- **Accessibility target:** [WCAG 2.2, level from the NFR, or "no user interface"]

## Risk

| ID | Capability or boundary | Traces to | Impact | Likelihood | Extra depth |
|---|---|---|---|---|---|
| RK-1 | [capability] | [AC, NFR, event or ADR id] | [H/M/L] | [H/M/L] | [checks added, or "standing gates only"] |

## Layers

| Layer | What it proves here | Skill | Author | When it runs | Selected by |
|---|---|---|---|---|---|
| Unit | [rules and components] | [skill] | [agent] | [trigger] | [selector] |
| Integration | [dependencies and API behaviour] | [skill] | [agent] | [trigger] | [selector] |
| Contract | [each boundary] | [skill] | [agent] | [trigger] | [selector] |
| End-to-end | [journeys] | [skill] | [agent] | [trigger] | [selector] |
| Performance | [changed code compared] | [skill] | [agent] | [trigger] | [selector] |
| Load | [targets held] | [skill] | [agent] | [trigger] | [selector] |
| Chaos | [patterns proven] | [skill] | [agent] | [trigger] | [selector] |
| Mutation | [code mutated] | [skill or "no owning skill (tool)"] | [agent] | [trigger] | [selector] |

## Acceptance and Journeys

Every Must Have criterion has at least one executable scenario. Smoke is read-only and separately selected; destructive tests refuse any address that is not throwaway.

| Journey or scenario group | Criteria | Layer | Smoke |
|---|---|---|---|
| [journey] | [AC-US-n.m ids] | [layer] | [yes (read-only) / no] |

## Targets

| Check | Target | Source |
|---|---|---|
| [performance, load or recovery check] | [the measure as written in its source, or "not set"] | [NFR id, SLO id, or OQ-n open question] |

## Chaos Experiments

| Experiment | Steady-state hypothesis | Resilience pattern proven |
|---|---|---|
| [fault injected] | [what stays true] | [pattern] |

## Coverage Gate

**Rule:** 100% of lines and branches. Only machine-generated code is excluded automatically, plus Go test support under `internal/test/` (approved class, listed in every report, never shipped).

<!-- Keep one row per language. Go: 100% of statement blocks (hard gate) plus gobco branch coverage after a trial;
     Not measured names select, range and zero-iteration loops; a failed trial returns to the product owner.
     Python: branch measurement on. TypeScript: coverage.include set. -->

| Language | Line gate | Branch gate | Not measured (stated in each report) |
|---|---|---|---|
| [language] | [how] | [how] | [cases] |

**If a gate cannot be measured:** [what happens; it returns to the product owner]

## Coverage Exclusions

| Path or pattern | Kind | Reason | Approval |
|---|---|---|---|
| [path, setting or "none"] | [generated / other] | [reason] | [automatic (generated) / pending / approved YYYY-MM-DD] |

## Mutation Rule

**Rule:** every planted mutant is caught by a test, or recorded with the reason it cannot be (it does not alter behaviour).

**Timeouts and type-checker rejections:** each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically.

| Language | Tool | Gate reads | Never planted (stated limit) |
|---|---|---|---|
| [language] | [tool] | [per-mutant report] | [limits] |

## Waivers

**Waiver rule:** line coverage, branch coverage and the mutation result are each judged separately; more than 90% and under 100% fails unless the product owner reviews the gap and waives it with recorded comments; 90% or below cannot be waived; testing layers can never be waived.

<!-- Before any run, keep the single "none" row. Add a row only after the product owner has reviewed a measured result.
     Measured is exact counts, covered/total. Mutation counts caught plus individually recorded over all planted. -->

| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| none | [none, or the language] | [none, or the run's report] | [none, or covered/total] | [none, or the comments as given] | [none, or YYYY-MM-DD] |

## Flaky Tests

| Layer | Automatic retries |
|---|---|
| Unit | 0 |
| Integration | 0 |
| Contract | 0 |
| End-to-end | 1 |
| Performance, Load, Chaos, Mutation | 0 |

- **Quarantine:** tagged, non-blocking, tracked issue, deadline of [period]; a quarantined test proves nothing.
- **Deletion:** only with a record of why and what proves the behaviour instead.
- **Regression:** every production defect gets a failing test before the fix.

## Delegated Testing

| Check | Owner | Skill | Gate |
|---|---|---|---|
| Security controls | security-engineer | security-implementation | [gate] |
| Compliance verification | security-engineer | compliance-verification | [gate] |
| Vulnerability and dependency scanning | security-engineer, platform-engineer | ci-pipeline | [gate] |
| Health checks | platform-engineer | health-check-design | [gate] |
| Exploratory sessions and user acceptance | requirements-analyst | uat-plan | [gate] |

## Open Questions

- [Question, owner; or "none"]
