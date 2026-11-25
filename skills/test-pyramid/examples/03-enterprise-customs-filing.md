# Example 3 (enterprise): Multi-tenant Customs Filing

Self-contained input and output. The points: tenant isolation and region failover get depth, a failed branch-coverage trial goes back to the product owner, timeouts are checked one by one.

## Input

- Request: "gobco panics on our platform-specific files, so keep statements only; the mutation timeouts can count as kills."
- Profile enterprise. Go services `filing`, `tariff` and `gateway`, events between them; a Python document classifier; React shell and remotes; many broker firms as tenants; two regions.
- NFR-SEC-01: no tenant reads another's filing. NFR-AVL-01: recover in the second region within 15 minutes. NFR-PERF-02: submit within 3 s at p99 at 80 filings per second. NFR-USE-02: WCAG 2.2 AA. SOC 2 in scope.

## What is declined, and why

- Statements only: a failed trial returns to the product owner with options; the branch gate shows as not met until decided.
- Timeouts as kills: each is checked and recorded with a one-line reason first.

## Output

````markdown
---
name: test-strategy
product: tariffgate
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-11-25
summary: Eight layers across three Go services, a classifier and a web app; isolation and failover first; Go branch gate unmet after a failed trial.
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md, design/event-schemas.md]
---

# Test Strategy for Tariffgate

- **Profile:** enterprise
- **Languages:** go, python, typescript
- **Accessibility target:** WCAG 2.2 AA (NFR-USE-02)

## Risk

| ID | Capability or boundary | Traces to | Impact | Likelihood | Extra depth |
|---|---|---|---|---|---|
| RK-1 | Tenant isolation in every query and event | NFR-SEC-01 | H | M | cross-tenant negative test per endpoint and consumer, through product code; exploratory charter |
| RK-2 | Duty calculation | AC-US-4.1 | H | H | decision tables, boundaries, path coverage |
| RK-3 | Region failover | NFR-AVL-01 | H | M | chaos experiment and restore drill |
| RK-4 | Event versions across services | design/event-schemas.md | H | M | compatibility check for old and new versions |

## Layers

| Layer | What it proves here | Skill | Author | When it runs | Selected by |
|---|---|---|---|---|---|
| Unit | Duty and filing rules, classifier rules, screens | go-unit-test, python-unit-test, react-component-testing | backend-engineer, frontend-engineer | pull request | default |
| Integration | Storage, broker, isolation, repeat submission, rate limit per tenant | go-integration-test, python-integration-test | backend-engineer | pull request | default |
| Contract | HTTP specs, event versions, shell to remotes | go-contract-test, python-contract-test, react-component-testing | test-strategist, frontend-engineer | pull request | tag and marker contract |
| End-to-end | File, amend, release, for two tenants | go-e2e-test, react-e2e-testing | test-strategist, frontend-engineer | mocked journeys per pull request; full nightly and before release | tag e2e |
| Performance | Duty calculation and submit path not slower | go-performance-test, python-performance-test | test-strategist | when that code changes and before release | tag perf |
| Load | Submit target, with many tenant identities | go-load-test, python-load-test | test-strategist | before release | separate job |
| Chaos | Region loss, broker partition, tariff timeout | go-chaos-test, python-chaos-test | test-strategist | before release and the owning skill's cadence | tag chaos |
| Mutation | All product code | go-mutation-test, python-mutation-test; no owning skill (StrykerJS) | test-strategist, frontend-engineer | monthly and before release | separate job |

## Acceptance and Journeys

| Journey or scenario group | Criteria | Layer | Smoke |
|---|---|---|---|
| File and release a declaration | AC-US-1.1, AC-US-2.1 | End-to-end | no |
| Amend a filing | AC-US-3.1, AC-US-3.2 | End-to-end | no |
| Duty rules | AC-US-4.1, AC-US-4.2 | Unit | no |
| Sign in and list filings of the smoke tenant | AC-US-5.1 | End-to-end | yes (read-only) |

## Targets

| Check | Target | Source |
|---|---|---|
| Submit latency under demand | 3 s at p99 at 80 filings per second | NFR-PERF-02 |
| Regional recovery | within 15 minutes | NFR-AVL-01 |
| Cross-tenant reads | none | NFR-SEC-01 |

## Chaos Experiments

| Experiment | Steady-state hypothesis | Resilience pattern proven |
|---|---|---|
| Primary region lost in the test environment | Filings resume in the second region within 15 minutes with none lost | failover and Transactional Outbox |
| Broker partition | No filing event is lost; unprocessable ones reach the Dead Letter Queue | Idempotency and Dead Letter Queue |
| Tariff service slow | Submit fails fast and the breaker opens | Circuit Breaker |

## Coverage Gate

**Rule:** 100% of lines and branches. Only machine-generated code is excluded automatically.

| Language | Line gate | Branch gate | Not measured (stated in each report) |
|---|---|---|---|
| go | 100% of statement blocks, no zero-count block | gobco after a trial: trial failed on platform-specific files, gate not met | select, range and zero-iteration loops; boolean expressions outside conditions |
| python | missing lines zero on the full run | branch measurement on, fail under 100 | alternatives inside one line |
| typescript | coverage.include covers all source; lines 100% per file | branches 100% per file | browser journey runs |

**If a gate cannot be measured:** it returns to the product owner; statements alone are not accepted.

## Coverage Exclusions

| Path or pattern | Kind | Reason | Approval |
|---|---|---|---|
| gen/**/*.pb.go | generated | protocol compiler output with the marker | automatic (generated) |
| coverage.py built-in default exclusions | other | type-checking blocks hold no runtime behaviour | approved 2026-11-20 |

## Mutation Rule

**Rule:** every planted mutant is caught by a test, or recorded with the reason it cannot be (it does not alter behaviour).

**Timeouts and type-checker rejections:** each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically.

| Language | Tool | Gate reads | Never planted (stated limit) |
|---|---|---|---|
| go | Gremlins, all operators, per module | each mutation status, including timed out and not viable | statement removal |
| python | mutmut 3 | every line of results --all, including type-check rejections | module-level code, most decorated functions |
| typescript | StrykerJS | each mutant status, including timeout and compile error | anything the register excludes |

## Flaky Tests

| Layer | Automatic retries |
|---|---|
| Unit | 0 |
| Integration | 0 |
| Contract | 0 |
| End-to-end | 1 |
| Performance, Load, Chaos, Mutation | 0 |

- **Quarantine:** tagged, non-blocking, tracked issue, deadline of two weeks, owner named; a growing list triggers an environment review.
- **Deletion:** only with a record of why and what proves the behaviour instead.
- **Regression:** every production defect gets a failing test before the fix.

## Delegated Testing

| Check | Owner | Skill | Gate |
|---|---|---|---|
| Security controls | security-engineer | security-implementation | pull request |
| Compliance verification (SOC 2) | security-engineer | compliance-verification | before release |
| Vulnerability and dependency scanning | security-engineer, platform-engineer | ci-pipeline | pull request |
| Health checks | platform-engineer | health-check-design | after deploy |
| Exploratory sessions and user acceptance | requirements-analyst | uat-plan | customer validation |

## Open Questions

- Go branch coverage: the trial failed. Options to decide: another tool, restructuring the platform-specific files, or another measure. Owner: product owner.
- Web mutation, performance, load and chaos have no owning skill.
````
