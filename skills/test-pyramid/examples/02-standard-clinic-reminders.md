# Example 2 (standard): Clinic Appointment Reminders

Self-contained input and output. The points: a flaky integration test, an uncovered line the team wants excluded, an invented target refused.

## Input

- Request: "Retry the flaky consumer test three times, drop the settings module from coverage, and set p99 at 200 ms."
- Profile standard. Python services `booking-api` and `reminder-worker` joined by events; React shell and remotes; an outside SMS provider.
- Criteria US-1 (book), US-2 (remind), US-3 (opt out). NFR-REL-02: no reminder sent twice. NFR-PERF-01: booking page answers within 1.5 s at the 95th percentile. NFR-USE-01: WCAG 2.2 AA.

## What is declined, and why

- Retries: only end-to-end retries once. The consumer test is quarantined with a deadline, and AC-US-2.2 is unproven (gate red) until a stable test exists.
- The exclusion: listed as pending, so it is not yet excluded.
- p99 200 ms: nobody agreed it. The cited measure is p95 1.5 s.

## Output

````markdown
---
name: test-strategy
product: clinicping
version: 1.0.0
phase: implement
owner: test-strategist
created: 2026-11-25
summary: Eight layers for two Python services and a web app; duplicate-send rule gets extra depth; one exclusion pending.
traces-to: [ideate/acceptance-criteria/, ideate/nfr-specification.md, design/event-schemas.md]
---

# Test Strategy for Clinicping

- **Profile:** standard
- **Languages:** python, typescript
- **Accessibility target:** WCAG 2.2 AA (NFR-USE-01)

## Risk

| ID | Capability or boundary | Traces to | Impact | Likelihood | Extra depth |
|---|---|---|---|---|---|
| RK-1 | Reminder sent once | NFR-REL-02 | H | H | redelivery test that waits for the second delivery; path coverage of the send decision; exploratory charter |
| RK-2 | Opt-out respected | AC-US-3.1 | H | M | decision table over channel, consent and time |
| RK-3 | Booking page | AC-US-1.1 | M | M | boundary and error branches |

## Layers

| Layer | What it proves here | Skill | Author | When it runs | Selected by |
|---|---|---|---|---|---|
| Unit | Send decision, consent rules, screens | python-unit-test, react-component-testing | backend-engineer, frontend-engineer | pull request | default |
| Integration | Real database and broker, redelivery, rate limit, error replies | python-integration-test | backend-engineer | pull request | default |
| Contract | HTTP spec, event schemas, shell to remotes | python-contract-test, react-component-testing | test-strategist, frontend-engineer | pull request | marker contract |
| End-to-end | Book, be reminded, opt out | python-e2e-test, react-e2e-testing | test-strategist, frontend-engineer | mocked journeys per pull request; full nightly and before release | marker e2e |
| Performance | Send decision and booking query not slower | python-performance-test | test-strategist | when that code changes and before release | marker performance |
| Load | Booking target at expected demand | python-load-test | test-strategist | before release | separate job |
| Chaos | Broker and SMS provider failures | python-chaos-test | test-strategist | before release | marker chaos |
| Mutation | All product code | python-mutation-test; no owning skill (StrykerJS) | test-strategist, frontend-engineer | monthly and before release | separate job |

## Acceptance and Journeys

| Journey or scenario group | Criteria | Layer | Smoke |
|---|---|---|---|
| Book an appointment | AC-US-1.1, AC-US-1.2 | End-to-end | no |
| Reminder reaches the provider once | AC-US-2.1, AC-US-2.2 | Integration | no |
| Opt out stops reminders | AC-US-3.1 | End-to-end | no |
| Opening hours page loads | AC-US-1.3 | End-to-end | yes (read-only) |

## Targets

| Check | Target | Source |
|---|---|---|
| Booking page | within 1.5 s at the 95th percentile | NFR-PERF-01 |
| Duplicate reminders | none | NFR-REL-02 |
| Booking demand | not set | OQ-1 |

## Chaos Experiments

| Experiment | Steady-state hypothesis | Resilience pattern proven |
|---|---|---|
| Broker restarts while reminders queue | Every due reminder is sent exactly once after recovery | Transactional Outbox and Idempotency |
| SMS provider times out | Failures stop being retried at once and reach the Dead Letter Queue | Circuit Breaker, Retry and Backoff |

## Coverage Gate

**Rule:** 100% of lines and branches. Only machine-generated code is excluded automatically.

| Language | Line gate | Branch gate | Not measured (stated in each report) |
|---|---|---|---|
| python | missing lines zero on the full run | branch measurement on, fail under 100 | alternatives inside one line |
| typescript | coverage.include covers all source; lines 100% per file | branches 100% per file | browser journey runs |

**If a gate cannot be measured:** it returns to the product owner.

## Coverage Exclusions

| Path or pattern | Kind | Reason | Approval |
|---|---|---|---|
| clinicping/clients/sms_gen.py | generated | generator header | automatic (generated) |
| clinicping/settings.py | other | requested by the team: reads environment variables only | pending |
| coverage.py built-in default exclusions | other | type-checking blocks and ellipsis bodies hold no runtime behaviour | pending |

## Mutation Rule

**Rule:** every planted mutant is caught by a test, or recorded with the reason it cannot be (it does not alter behaviour).

**Timeouts and type-checker rejections:** each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically.

| Language | Tool | Gate reads | Never planted (stated limit) |
|---|---|---|---|
| python | mutmut 3 | every line of results --all | module-level code, most decorated functions |
| typescript | StrykerJS | each mutant status in the JSON report | anything the register excludes |

## Flaky Tests

| Layer | Automatic retries |
|---|---|
| Unit | 0 |
| Integration | 0 |
| Contract | 0 |
| End-to-end | 1 |
| Performance, Load, Chaos, Mutation | 0 |

- **Quarantine:** tagged, non-blocking, tracked issue, deadline of two weeks; the redelivery test enters today, leaving AC-US-2.2 unproven and the gate red.
- **Deletion:** only with a record of why and what proves the behaviour instead.
- **Regression:** every production defect gets a failing test before the fix.

## Delegated Testing

| Check | Owner | Skill | Gate |
|---|---|---|---|
| Security controls | security-engineer | security-implementation | pull request |
| Compliance verification | security-engineer | compliance-verification | before release |
| Vulnerability and dependency scanning | security-engineer, platform-engineer | ci-pipeline | pull request |
| Health checks | platform-engineer | health-check-design | after deploy |
| Exploratory sessions and user acceptance | requirements-analyst | uat-plan | customer validation |

## Open Questions

- OQ-1: peak bookings per minute? Owner: product owner, via nfr-specification.
- Exclusions pending: settings module and the tool's default exclusions. Owner: product owner.
- Web mutation, performance, load and chaos have no owning skill.
````
