---
name: go-e2e-test
description: >
  This plugin's end-to-end-test authority for Go — the top of the pyramid
  above go-integration-test, for journeys that must cross a real service
  boundary via a real network call (the deployed binary actually running,
  not a test binary's package import). Covers: the precise e2e-vs-integration
  scope boundary; the environment-provisioning standard (an ephemeral `kind`
  cluster per run, the same Helm charts and digest production uses, never
  docker-compose — references/environment-provisioning-standard.md); the
  test-data seeding and teardown standard (idempotent seed scripts,
  guaranteed cleanup on failure or CI timeout via a three-layer trap/
  always()/janitor defense, never happy-path-only — references/test-data-
  seeding-and-teardown-standard.md); the flakiness-budget standard (one
  automatic retry, build-tag quarantine with a tracked issue and deadline —
  references/flakiness-budget-and-quarantine-standard.md); the CI-placement
  standard (nightly/pre-release/on-demand triggers for the full suite, the
  tagged smoke subset cd-pipeline and blue-green-deployment already assume
  exists, never per-PR — references/ci-placement-and-trigger-standard.md);
  and the worked API-level journey test with trace correlation
  (references/journey-test-and-trace-correlation.md). Authored and run by
  the test-strategist. Used during Quality.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, e2e, kind, ephemeral-environment, flakiness, quarantine, ci, shift-right]
produces: go-e2e-test-suite
domain: testing
status: stable
related: [go-integration-test, go-unit-test, multi-tenancy-design, environment-config, ci-pipeline, cd-pipeline, helm-chart, react-e2e-testing, test-pyramid, user-journey-mapping, distributed-tracing-design, disaster-recovery-plan]
---

# Go End-to-End Test

## Purpose

E2E tests prove the fully-deployed system delivers a user journey — real Pods, real Services, real network calls — not the test binary calling into its own packages. This is the top of the pyramid above `go-integration-test`: highest confidence, highest cost, most prone to flakiness, reserved for critical journeys only. Authored and run by the test-strategist.

---

## Scope Boundary — E2E vs. Integration

The boundary is which process boundary a test crosses, not which dependency it touches:

| | `go-integration-test` | `go-e2e-test` (this skill) |
|---|---|---|
| Runs inside | The test binary's own process | No test-binary process at all |
| Exercises | This service's Go code, `go test`-invoked, against a real dependency (Testcontainers Postgres/Redpanda) | The fully-deployed system: this service's actual compiled image, actually running as a Pod, actually receiving traffic |
| Crosses | A dependency boundary (real SQL, real broker) | A real service boundary — real network hop, real DNS, real Linkerd mTLS handshake, real ingress |
| Reached via | Direct Go function/struct calls inside the test | HTTP/gRPC over the network, or a browser (`react-e2e-testing`) |
| Multi-service? | Never — one service's package under test | Often — a journey spans several Bounded Contexts' deployed services |

A test that imports another service's package to simulate calling it is not e2e regardless of how many real dependencies sit underneath it — no network hop was crossed, so it is at most an elaborate integration test. A test that drives the real API endpoint from outside the process is e2e even for a single service: the deployed binary's HTTP transport, middleware chain, and TLS termination are all genuinely exercised, none of which a package import ever touches.

---

## Coverage Boundary — Few, High-Value, Two Surfaces

Cover the journeys that matter; push permutations to lower layers:

| Cover with e2e | Push down |
|---|---|
| P1 user journeys (audit prep, classify, generate report) | Validation rules → unit (`go-unit-test`) |
| Cross-service happy paths + critical failure paths | Repository/broker wiring → integration (`go-integration-test`) |
| Auth → action → persistence → event → projection round-trips | Component states → component tests |
| A release smoke suite (the tagged `smoke` subset, below) | Edge-case permutations → unit/integration |

Two surfaces drive the same journey: **UI e2e** (Playwright, through the browser — `react-e2e-testing`) for genuinely user-facing flows, and **API e2e** (a Go HTTP client against the deployed API) for backend-centric journeys — cheaper, less flaky. The same Gherkin scenario (`bdd-feature-file`) can bind to either. Worked API-level journey test, condition-based waits, and trace correlation: `references/journey-test-and-trace-correlation.md`.

---

## Environment-Provisioning Standard

E2E needs the real, deployed system, not a simplified stand-in. **The full journey suite runs in an ephemeral `kind` cluster, created fresh per run and destroyed after** — the same tool and the same "created and destroyed per run" lifecycle `environment-config` already assigns to `kind-local`, extended from `helm-chart`'s single-chart install-test to every service a journey touches, installed via the identical `kind create cluster` / `helm install --wait` idiom, same chart, same digest, a CI values file. Never docker-compose: `environment-config`'s Environment Parity law — every environment runs the same chart at the same digest, differing only in values — forbids the one full-stack layer that most needs to catch real deploy drift from running on a second, divergently-decaying deployment description. Seeded data carries a synthetic `tenant.id: e2e-<run-id>` values-file identity (the identity difference class `environment-config` already permits), not a full OpenTofu-provisioned production tenant stamp. Full provisioning/teardown commands and the rejected-alternatives table: `references/environment-provisioning-standard.md`.

This is distinct from the **tagged `smoke` subset** — a small, non-destructive slice of the same journey test files (`-tags smoke`, the exact convention `cd-pipeline`'s post-deploy verification, `blue-green-deployment`'s pre-cutover gate, and `disaster-recovery-plan`'s restore verification already assume this skill produces) that runs directly against the real, persistent dev/staging/tenant environments on every promotion — a different trigger, covered under CI-Placement below.

---

## Test-Data Seeding and Teardown Standard

Every seed script is idempotent — IDs derived deterministically from the run id, `ON CONFLICT DO UPDATE` never a blind `INSERT` — safe to rerun if only the seed step retries within a run. Cleanup is guaranteed, never happy-path-only: the failure branch calls the identical teardown the success branch calls, backed by three independent layers — an in-runner `trap EXIT` handler, a workflow-level `if: always()` step (the real backstop, since a hard job timeout bypasses a bash trap), and a scheduled orphan-cluster janitor as the final safety net. Full scripts and the failure-path proof: `references/test-data-seeding-and-teardown-standard.md`.

---

## Flakiness-Budget Standard

E2E is inherently flakier than unit/integration — real network hops, real DNS, real mesh handshakes, real async pipeline lag — a cost to budget, not a defect to chase to zero. **Retry:** one automatic retry on failure before a test is marked genuinely failed; failing both the original run and the retry is a real failure. **Quarantine:** a test that fails intermittently across multiple runs moves to a `//go:build quarantine` suite that still runs in CI (`continue-on-error: true`, non-blocking) with a tracked GitHub issue and a two-week deadline — never silently deleted, never permanently skipped with no issue. The quarantine list's steady state is empty; a growing list means the waits, seeding, or environment are wrong, not that the tests are unlucky. Detection mechanics, the build tag, and the issue template: `references/flakiness-budget-and-quarantine-standard.md`.

---

## CI-Placement Standard

The full suite runs less often than unit/integration for two compounding reasons: **cost** (an ephemeral `kind` cluster running every service a journey touches costs real minutes to stand up, unlike a Testcontainers pair's seconds) and **flakiness** (a false-failure rate from real network/timing dependencies that would erode trust in a required PR gate). Three triggers, never `pull_request`:

| Trigger | Cadence | Purpose |
|---|---|---|
| **Nightly** | `schedule: cron` | The steady-state cadence `ci-pipeline`'s trigger table and `cd-pipeline`'s dev→staging promotion gate already assume exists |
| **Pre-release** | `release: types: [published]` | A release must not ship on a nightly run from days ago |
| **On-demand** | `workflow_dispatch` | A developer verifying one journey fix without waiting for the nightly window |

The **tagged `smoke` subset runs separately and more often** — on every promotion, directly against the real environment, as `cd-pipeline`'s post-deploy verification and `blue-green-deployment`'s pre-cutover gate already describe (`go test ./tests/e2e/... -tags smoke -tenant=<id>`, the exact form `disaster-recovery-plan` also uses to verify a restored stamp). `e2e_test_cadence` (`sdlc-config-management`) overrides the nightly schedule for a product that needs it tightened. Full trigger YAML and the cost-model arithmetic: `references/ci-placement-and-trigger-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Scope boundary honored | Test crosses a real network hop against the deployed binary | "E2E" that imports another service's package |
| Few, high-value | Critical journeys only; permutations pushed down | E2E duplicating lower-layer coverage |
| Real full stack | Deployed services + real DB + real broker (+ UI) | Mocked backends called "e2e" |
| Ephemeral, representative env | `kind` cluster, same charts/digest as production | Docker-compose stand-in; hand-built manifests |
| Guaranteed teardown | Trap + `if: always()` + janitor, three-layered | Happy-path-only cleanup; orphaned clusters accumulate |
| Idempotent seeding | Deterministic IDs, upsert semantics | Blind `INSERT`; reruns fail or duplicate |
| No arbitrary sleeps | Condition-based waits with deadlines | `time.Sleep` guesses |
| Eventual-consistency aware | Polls for the projected state | Asserting immediately after an async action |
| Trace-correlated | Test id → one trace across the stack | Failures with no trace to follow |
| Retry policy explicit | One automatic retry, then genuine failure | Ad-hoc reruns; retry-until-green |
| Flaky tests governed | Quarantine with issue + deadline; list trends to empty | Ignored, deleted, or permanently skipped |
| Full-suite CI-placed correctly | Nightly + pre-release + on-demand; never `pull_request` | Full e2e suite blocking every PR |
| Smoke subset present | `-tags smoke` slice runs against real envs on every promotion | No smoke coverage; promotion trusts the nightly run alone |

---

## Anti-Patterns

- **E2E as the default layer** — a journey test for what unit/integration already proves inverts the pyramid into an ice-cream cone.
- **Package-import "e2e"** — importing another service's code to simulate calling it never crosses a network boundary; at most it is integration.
- **Docker-compose environment** — a second, divergent deployment description breaks Environment Parity for the layer that most needs to catch deploy drift.
- **Happy-path-only teardown** — a script whose failure path never runs cleanup leaves orphaned clusters that silently burn budget.
- **`time.Sleep` as synchronization** — the canonical flake generator; every wait is a condition with a deadline.
- **Retry-until-green** — masks real intermittent production bugs (races, ordering) e2e exists to catch; one retry is a diagnostic, not a pass criterion.
- **Full suite on every PR** — the cost and flakiness math never closes; nightly plus pre-release plus on-demand, with the smoke subset covering promotions, is the affordable, sufficient placement.

---

## Output Format

Produces e2e journey tests, the ephemeral-environment scripts, and the CI triggers:

```
tests/e2e/journeys/*_test.go              (API-level journey tests; smoke-tagged subset via -tags smoke)
tests/e2e/*.spec.ts                        (UI journeys — Playwright, see react-e2e-testing)
tests/e2e/provision-kind.sh                (kind create, helm install, trap-based teardown)
tests/e2e/trace.go                         (test-id → trace correlation helpers)
.github/workflows/e2e-nightly.yml          (nightly/pre-release/on-demand triggers, always() teardown)
```
