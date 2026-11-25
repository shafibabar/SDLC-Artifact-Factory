# Example 1 (lean): Allotment Waiting List

Self-contained input and output. The point: a very small product still plans all eight layers, with few rows.

## Input

- Request: "It's tiny, one volunteer-run list. Just give me unit tests and a couple of browser tests, 80% coverage is fine."
- Profile lean. One Go service (modular monolith), a web shell with two remotes (apply, committee), PostgreSQL, no events.
- Criteria US-1 (apply for a plot), US-2 (committee offers a plot). NFR-REL-01: no application lost; restore within one day. No speed or load target.

## What is declined, and why

Dropping layers and an 80% gate: full testing applies at every size and the target is 100% line and branch coverage, whoever asks. Nothing is waived in advance. The strategy is short instead.

## Output

````markdown
---
name: test-strategy
product: plotqueue
version: 1.0.0
phase: implement
owner: test-strategist
created: 2026-11-25
summary: Eight layers for a one-service waiting list; 100% gates; no load or speed target set yet (two open questions).
traces-to: [ideate/acceptance-criteria/US-1.md, ideate/acceptance-criteria/US-2.md, ideate/nfr-specification.md]
---

# Test Strategy for Plotqueue

- **Profile:** lean
- **Languages:** go, typescript
- **Accessibility target:** WCAG 2.2, level not set (OQ-3)

## Risk

| ID | Capability or boundary | Traces to | Impact | Likelihood | Extra depth |
|---|---|---|---|---|---|
| RK-1 | Queue order when offering a plot | AC-US-2.1 | H | M | decision table over date, residency and refusals; workflow test |
| RK-2 | Applying | AC-US-1.1 | M | L | boundary and invalid classes |

## Layers

| Layer | What it proves here | Skill | Author | When it runs | Selected by |
|---|---|---|---|---|---|
| Unit | Queue order, application rules, remote screens | go-unit-test, react-component-testing | backend-engineer, frontend-engineer | pull request | default |
| Integration | Queries, migrations, repeat submission, error replies | go-integration-test | backend-engineer | pull request | default |
| Contract | HTTP spec both sides use; shell loads both remotes | go-contract-test, react-component-testing | test-strategist, frontend-engineer | pull request | default |
| End-to-end | Apply, then committee offers | go-e2e-test, react-e2e-testing | test-strategist, frontend-engineer | mocked journeys per pull request; full nightly and before release | tag e2e |
| Performance | Offer calculation not slower than before | go-performance-test | test-strategist | when that code changes and before release | tag perf |
| Load | The list under an opening-day burst | go-load-test | test-strategist | before release | tag load |
| Chaos | Database unavailable during an application | go-chaos-test | test-strategist | before release | tag chaos |
| Mutation | All product code | go-mutation-test; no owning skill (StrykerJS) | test-strategist, frontend-engineer | monthly and before release | separate job |

## Acceptance and Journeys

| Journey or scenario group | Criteria | Layer | Smoke |
|---|---|---|---|
| Apply and see position | AC-US-1.1, AC-US-1.2 | End-to-end | no |
| Offer to the next person | AC-US-2.1 | End-to-end | no |
| Application rules | AC-US-1.3 | Unit | no |
| Public page loads | AC-US-1.2 | End-to-end | yes (read-only) |

## Targets

| Check | Target | Source |
|---|---|---|
| Restore after loss | restore within one day, no application lost | NFR-REL-01 |
| Opening-day load | not set | OQ-1 |
| Speed change | old against new in the same job; allowed slowdown from go-performance-test or the config override | OQ-2 |

## Chaos Experiments

| Experiment | Steady-state hypothesis | Resilience pattern proven |
|---|---|---|
| Database connection cut mid-application | The applicant sees an error and nothing is half saved | transaction rollback and retry |

## Coverage Gate

**Rule:** 100% of lines and branches. Only machine-generated code is excluded automatically.

| Language | Line gate | Branch gate | Not measured (stated in each report) |
|---|---|---|---|
| go | 100% of statement blocks, no zero-count block | gobco after a trial (not yet run) | select, range and zero-iteration loops; boolean expressions outside conditions |
| typescript | coverage.include covers all source; lines 100% per file | branches 100% per file | browser journey runs |

**If a gate cannot be measured:** it returns to the product owner; the statement gate alone is not accepted.

## Coverage Exclusions

| Path or pattern | Kind | Reason | Approval |
|---|---|---|---|
| internal/api/spec_gen.go | generated | carries the generator marker | automatic (generated) |

## Mutation Rule

**Rule:** every planted mutant is caught by a test, or recorded with the reason it cannot be (it does not alter behaviour).

**Timeouts and type-checker rejections:** each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically.

| Language | Tool | Gate reads | Never planted (stated limit) |
|---|---|---|---|
| go | Gremlins, all operators | each mutation status in the JSON output | statement removal |
| typescript | StrykerJS | each mutant status in the JSON report | anything the register excludes |

## Waivers

**Waiver rule:** line coverage, branch coverage and the mutation result are each judged separately; more than 90% and under 100% fails unless the product owner reviews the gap and waives it with recorded comments; 90% or below cannot be waived; testing layers can never be waived.

| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| none | none | none | none | none | none |

## Flaky Tests

| Layer | Automatic retries |
|---|---|
| Unit | 0 |
| Integration | 0 |
| Contract | 0 |
| End-to-end | 1 |
| Performance, Load, Chaos, Mutation | 0 |

- **Quarantine:** tagged, non-blocking, tracked issue, deadline of two weeks; a quarantined test proves nothing.
- **Deletion:** only with a record of why and what proves the behaviour instead.
- **Regression:** every production defect gets a failing test before the fix.

## Delegated Testing

| Check | Owner | Skill | Gate |
|---|---|---|---|
| Security controls | security-engineer | security-implementation | pull request |
| Compliance verification | security-engineer | compliance-verification | before release, for personal data held |
| Vulnerability and dependency scanning | security-engineer, platform-engineer | ci-pipeline | pull request |
| Health checks | platform-engineer | health-check-design | after deploy |
| Exploratory sessions and user acceptance | requirements-analyst | uat-plan | customer validation |

## Open Questions

- OQ-1: how many applications must the opening day absorb, and how fast? Owner: product owner, via nfr-specification.
- OQ-2: is the default slowdown threshold acceptable? Owner: product owner.
- OQ-3: which WCAG 2.2 level? Owner: product owner, via nfr-specification.
- Performance, load and chaos have no front-end owning skill; mutation for the web code has none either.
````
