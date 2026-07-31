# Flakiness-Budget and Quarantine Standard

E2E tests cross real network hops, real DNS resolution, real Linkerd mTLS handshakes, and real asynchronous pipeline lag — dependencies a unit test never touches and an integration test only partially touches (Testcontainers is real, but still in-process and single-host). Some non-zero flake rate is the honest cost of that realism, not evidence of a badly written test. The discipline is not eliminating flakiness to zero — it is budgeting for it mechanically, so a flaky test is a tracked, time-boxed liability instead of a build everyone learns to re-run and ignore.

---

## Retry Policy — One Automatic Retry, Then a Verdict

A failing journey test is retried **exactly once**, automatically, before it is recorded as a genuine failure:

```yaml
# tests/e2e/journeys — retry wrapper invoked by the CI job
- name: Run journey suite (one retry on failure)
  run: |
    go test ./tests/e2e/journeys/... -v -json > run1.json || \
    go test ./tests/e2e/journeys/... -v -json -run "$(jq -r 'select(.Action=="fail" and .Test) | .Test' run1.json | paste -sd '|')" > run2.json
```

A test that fails on both the first attempt and the retry is a genuine failure — it blocks the build, exactly as any other CI failure would. A test that fails once and passes on the retry is, by definition, **flaky**: this is the mechanical detection rule, not a judgment call left to whoever is looking at the build.

**This is not "retry until green."** The policy is bounded at exactly one retry; there is no third attempt, and the automatic retry is never used to paper over a test that has already been flagged flaky. Retry-until-green as a standing practice would hide the real intermittent bugs (races, ordering assumptions, resource exhaustion under load) that e2e testing exists to catch — the whole point of running against the real deployed system is to surface exactly this class of bug, and unlimited retries erase the signal.

---

## Detection — Recorded, Not Assumed

Every fail-then-pass-on-retry pair is logged with enough context to act on later, not just silently absorbed by the green build:

```json
{"test": "TestJourney_ClassifyThenAppearsInReport", "run_id": "...", "attempt_1": "FAIL", "attempt_2": "PASS", "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736", "timestamp": "..."}
```

The `trace_id` ties directly into the OpenTelemetry span the failing attempt produced (`journey-test-and-trace-correlation.md`) — a flake investigation starts from a concrete trace, not a re-run under a debugger hoping to reproduce it.

A dashboard or a simple append-only log of these records is enough to answer the question that decides quarantine: has this specific test flaked more than once across recent runs?

---

## Quarantine — Move, Don't Delete, Don't Silently Skip

A test that has flaked (fail-then-pass-on-retry) more than once across recent runs graduates to quarantine:

```go
//go:build quarantine

package journeys

// TestJourney_BulkClassifyUnderLoad has flaked 3× in the last 10 nightly runs —
// intermittent projection lag beyond the current wait deadline.
// Tracking: https://github.com/org/repo/issues/1234 — opened 2026-07-20, deadline 2026-08-03.
func TestJourney_BulkClassifyUnderLoad(t *testing.T) {
    // unchanged test body — quarantine is a build-tag move, not a rewrite
}
```

```yaml
# quarantine runs, but cannot fail the required gate
- name: Quarantined journeys (non-blocking)
  continue-on-error: true
  run: go test ./tests/e2e/journeys/... -tags quarantine -v
```

Every quarantined test carries, in the same commit that quarantines it: a **tracked issue** (opened the day of quarantine) and a **two-week deadline**. Before the deadline, exactly one of two things happens:

1. **Fix the root cause**, using the trace id(s) collected during detection to find the actual span that broke (a wait deadline too tight for real pipeline lag, an unhandled connection-pool exhaustion under the `kind` cluster's smaller resource footprint, etc.), then move the test back out of quarantine in the same PR that fixes it.
2. **Delete it deliberately**, with the issue documenting the decision that this journey's coverage is better provided at a lower layer (its logic decomposed into something `go-unit-test` or `go-integration-test` can prove more cheaply and more reliably) — a conscious removal with a paper trail, never a silent `t.Skip()` with no issue and no reasoning.

**Never permanently skip.** `t.Skip("flaky, investigate later")` with no linked issue and no deadline is functionally identical to deleting the test, except it still shows up in test output pretending to provide coverage. The build tag plus the issue plus the deadline is the mechanism that keeps quarantine an active queue instead of a graveyard.

---

## The Quarantine List's Steady State Is Empty

A quarantine list at zero means the environment, waits, and seeding are sound. A **growing** list is a signal about the suite's infrastructure, not about the individual tests in it — check the environment-provisioning and test-data standards first (is the `kind` cluster's resource footprint smaller than what the wait deadlines assume? is a shared seed conflicting across parallel journeys?) before assuming each new quarantine entry is an isolated, unrelated flake.
