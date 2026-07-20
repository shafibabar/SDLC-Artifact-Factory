---
name: go-e2e-test
description: >
  Teaches end-to-end testing of the full stack — orchestrating critical user
  journeys from frontend through API to the real storage and event engines,
  deterministic state seeding, flakiness mitigation (dynamic waits, never arbitrary
  sleeps), test-trace correlation through OpenTelemetry, the environment strategy
  (ephemeral stack via Testcontainers/compose), and keeping e2e few and high-value
  at the top of the pyramid. The shift-right validation of whole-system behaviour.
  Used by the test-strategist during Quality.
version: 1.1.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, e2e, user-journey, playwright, trace-correlation, flakiness, shift-right]
---

# Go End-to-End Test

## Purpose

End-to-end tests prove the assembled system delivers a user journey — the compliance officer logs in, connects a source, watches assets get classified, reviews the gap report, and exports it — across the frontend, the API, the database, and the event pipeline working together. This is the highest-confidence, highest-cost test layer: it catches integration failures nothing below it can see, but it is slow and the most prone to flakiness, so it is used sparingly for the **critical journeys only**.

E2E sits at the top of the pyramid (`test-pyramid`) — few, high-value, comprehensive. It is the primary **shift-right** verification that the real, whole system behaves as the journeys promised (`user-journey-mapping`).

---

## Few and High-Value

Cover the journeys that matter; let the layers below cover the permutations.

| Cover with e2e | Push down to lower layers |
|---|---|
| P1 user journeys (audit prep, classify, generate report) | Validation rules → unit |
| Cross-stack happy paths + critical failure paths | Repository SQL → integration |
| Auth → action → persistence → event → projection round-trips | Component states → component tests |
| A release smoke suite | Edge-case permutations → unit/integration |

A handful of well-chosen journeys gives most of the confidence. Resist growing e2e into a slow second copy of the lower suites.

---

## Two Surfaces, One Journey

A journey can be driven at two levels; choose per test:

| Surface | Tool | Use for |
|---|---|---|
| **UI e2e** | Playwright (the frontend's `react-e2e-testing`) | True full-stack journeys through the browser |
| **API e2e** | Go HTTP client against the running stack | Backend-centric journeys, faster, no browser |

The same Gherkin journey scenario (`bdd-feature-file`) can bind to either. UI e2e for the genuinely user-facing flows; API e2e for backend journey coverage that doesn't need a browser (cheaper, less flaky).

```go
// API-level e2e: drive the real running stack through its public API.
func TestJourney_ClassifyThenAppearsInReport(t *testing.T) {
    stack := startStack(t)                                  // ephemeral full stack (below)
    token := signInAsSteward(t, stack)

    assetID := connectSourceAndWaitForAsset(t, stack, token) // through the real pipeline
    classify(t, stack, token, assetID, "Restricted")

    // Eventually-consistent: the projection updates after the event is processed.
    report := awaitGapReportReflects(t, stack, token, assetID, 10*time.Second)
    require.Contains(t, report.RestrictedAssets, assetID)
}
```

---

## Deterministic State Seeding

E2E flakiness most often comes from data assumptions. Each journey **seeds its own world** and asserts only on what it created (the hermetic rule from `test-fixture-design`, applied to the whole stack): a fresh tenant, known users, known sources. No reliance on ambient or shared data; teardown removes the tenant.

```go
tenant := provisionTestTenant(t, stack)   // isolated; t.Cleanup deprovisions it
```

---

## Flakiness Mitigation — Never Sleep

Arbitrary `time.Sleep` is the cardinal sin of e2e: too short and it's flaky, too long and the suite crawls. **Wait for a condition, not a duration.**

| Instead of | Do |
|---|---|
| `time.Sleep(3*time.Second)` | Poll for the expected state with a timeout (`await…`) |
| Sleeping for the pipeline | Wait until the projection reflects the event (eventual consistency) |
| Sleeping for the UI | Playwright auto-waiting on the element/network-idle |

```go
// Condition-based wait with a deadline — deterministic, as fast as the system allows.
func awaitGapReportReflects(t *testing.T, s *stack, tok string, id uuid.UUID, d time.Duration) Report {
    deadline := time.Now().Add(d)
    for time.Now().Before(deadline) {
        r := getGapReport(t, s, tok)
        if contains(r.RestrictedAssets, id) { return r }
        time.Sleep(100 * time.Millisecond)   // a poll interval, not a fixed guess at completion
    }
    t.Fatalf("gap report did not reflect %s within %s", id, d)
    return Report{}
}
```

This respects the system's **Eventual Consistency** (the event pipeline is async by design — `data-pipeline-design`) instead of fighting it with fixed sleeps.

---

## Flaky-Test Quarantine

A flaky e2e test is worse than no test: it trains you to re-run red builds, which hides real failures. The policy is mechanical, not judgemental:

1. **Detect** — a test that fails then passes on retry with no code change is flaky by definition; CI records it (test name, failure output, trace id).
2. **Quarantine, don't delete** — move it to a quarantined set (build tag `//go:build quarantine` or a skip list) that still runs in CI but cannot fail the build. The journey's coverage gap is now explicit.
3. **Time-box** — a quarantined test carries an issue and a deadline (e.g. two weeks). Fix the root cause via its failure trace, or decide the journey belongs at a lower layer and delete it deliberately.
4. **Never retry-to-green as policy** — automatic retries are a diagnostic aid (retry once, report both outcomes), not a pass criterion.

The quarantine list's steady state is **empty**; a growing list is a suite telling you its waits, seeding, or environment are wrong.

---

## Test-Trace Correlation

Inject a unique **test id** that propagates as `traceparent`/a header through the whole stack, so a failing journey's activity is one connected OpenTelemetry trace, browser → API → pipeline (the trace the frontend and backend already wired — `react-observability`, `distributed-tracing-design`). When an e2e test fails, its trace id leads straight to the exact span that broke — root-cause without re-running under a debugger.

```go
ctx = withTestTrace(ctx, t.Name())   // test id → trace headers on every request the test makes
```

---

## Environment Strategy

E2E needs a real, running stack. Two frugal options:

| Strategy | How | Use |
|---|---|---|
| **Ephemeral stack** | Testcontainers / docker-compose spins up API + Postgres + Redpanda (+ UI) per run | CI and local — self-contained, no shared environment to pollute |
| **Seeded staging** | Run against a deployed staging environment | A small post-deploy smoke suite (CD) |

Default to an **ephemeral stack** for the journey suite (hermetic, portable, parallelisable per tenant), with a tiny real-environment smoke suite in CD to catch deploy/infra drift. The platform-engineer provisions the CD environment; the test-strategist owns the journeys.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Few, high-value | Critical journeys only; permutations pushed down | E2E duplicating lower-layer coverage |
| Real full stack | API + DB + broker (+ UI) running together | "E2E" with mocked backends |
| Deterministic seeding | Each journey seeds + tears down its own tenant | Reliance on shared/ambient data |
| No arbitrary sleeps | Condition-based waits with deadlines | `time.Sleep` guesses; flaky timing |
| Eventual-consistency aware | Polls for the projected state | Asserting immediately after an async action |
| Trace-correlated | Test id → one trace across the stack | Failures with no trace to follow |
| Portable env | Ephemeral stack in CI; small staging smoke | Depends on a hand-maintained shared env |
| Flakiness governed | Quarantine with issue + deadline; list trends to empty | Retry-until-green; flaky tests ignored |

---

## Anti-Patterns

- **E2E as the default layer** — writing a journey test for what a unit or integration test proves inverts the Test Pyramid into an ice-cream cone: slow, flaky, expensive.
- **`time.Sleep` as synchronization** — the canonical flake generator; every wait must be a condition with a deadline.
- **Asserting immediately after an async action** — the projection lags the Domain Event by design; a test that ignores Eventual Consistency fails intermittently and teaches nothing.
- **Shared long-lived test environment as the only target** — ambient data drift makes every failure ambiguous; the ephemeral stack is the source of truth, staging gets only the smoke suite.
- **Retry-until-green** — masks real intermittent production bugs (races, ordering) that e2e exists to catch.
- **UI e2e for backend-only behaviour** — driving a browser to test an API path pays the flakiest tax for no extra confidence; use API-level e2e.

---

## Output Format

Produces e2e journey tests and the stack harness:

```
tests/e2e/journeys/*_test.go           (API-level journey tests)
tests/e2e/*.spec.ts                     (UI journeys — Playwright, see react-e2e-testing)
tests/e2e/stack.go                      (ephemeral full-stack harness)
tests/e2e/trace.go                      (test-id → trace correlation helpers)
```
