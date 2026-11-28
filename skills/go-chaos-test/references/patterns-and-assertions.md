# Each Pattern, Its Defined Behaviour and the Assertion That Proves It

Self-contained. Read when writing or reviewing an experiment for a resilience pattern, when the product lacks a pattern, when a test "proves" a pattern with one call, or for the DLQ, idempotency, 429, broker, shutdown and deadlock rows. Definitions and numbers come from `integration-design` (resilience patterns, "internal, hot path" row: trip at 5 consecutive failures, a 10 s window, a 5 s reset, one half-open probe; 3 attempts, 100 ms doubling to 5 s, full jitter; the remaining deadline passed down; one pool per downstream). Library facts come from `research/testing/go-resilience-fault-injection-official-docs.md` (Go 1.27.4, gobreaker v2.4.0, backoff v7.0.3, x/sync v0.25.0). Each assertion below was run on 2026-11-28 against the lab product of `../examples/02-standard-harbour-pilots.md`, passing on the correct code and failing on a deliberately broken copy; the failure messages are quoted.

## First: what does the product implement?

Read the product's client code for each downstream and list, per pattern, **present** (with its settings: threshold, window, reset, attempts, backoff, timeout, pool size, fallback, in-flight limit) or **missing**. The experiments test what is present, against the product's own settings read from its config (`tides.DefaultConfig`), never numbers chosen by the test. A setting that differs from `integration-design`'s row is a finding for the report, not something the test quietly accepts.

A pattern that is **missing is named as missing** in the answer and the report ("the product has no circuit breaker on its call to the payments partner; `integration-design` requires one for an external call at this size"). Do not build one inside the test, and do not "prove" it with a stand-in: the lab uses `sony/gobreaker` only to show what a correct experiment looks like. Building the breaker, bulkhead and retry is a gap the product owner has assigned to the Go build skills (no Go build skill implements them today); the report lists it as a corrective action.

## Circuit breaker

**Defined:** closed, failures counted; open once the threshold is crossed, every call failing at once for the reset time; half-open after it, one probe let through; a good probe closes it, a failed one reopens it. One breaker per downstream; its state is exported as a metric.

**Assert, in order** (`TestChaos_BreakerTransitions`):
1. A healthy call; state closed. (If not, INVALID.)
2. Fault the dependency (503). After each of the first threshold−1 failed calls, state is still closed; after the threshold-th, open. Calls are counted at the call level: retries sit inside the breaker, so one failed call is one breaker failure.
3. While open: 20 calls each return the product's "unavailable" error in under 20 ms, and the dependency counts **zero** new requests.
4. Half-open no sooner than the reset (polled, no fixed sleep); with five concurrent callers, four are refused at once (one probe).
5. The probe fails: open again. After the next reset, clear the fault: the probe succeeds and the state is closed.

**Seen failing:** a breaker whose `ReadyToTrip` never fires: `after 5 consecutive failures: breaker is closed, want open`. The 2.1.0 test (one call with a 5 s latency toxic, asserting a fast "unavailable" error) **passed** on that same broken breaker: the 300 ms attempt timeout and three attempts returned the error in 1.2 s. One fast failure is not a breaker.

**Library traps:** gobreaker's default `ReadyToTrip` is `ConsecutiveFailures > 5`, one more than `integration-design`'s 5; `MaxRequests` 0 means 1; `Timeout` 0 means 60 s; `Interval` 0 never clears the closed-state counts. Exclude the caller's own cancellation (`IsExcluded`); treat a permanent 4xx as success (`IsSuccessful`), or a burst of bad requests opens the breaker on a healthy dependency.

## Retry with backoff and jitter

**Defined:** transient failures only (5xx, 429, connection errors), capped attempts, exponential backoff with full jitter, never past the caller's deadline; a write retried only with an idempotency key.

**Assert** (`TestChaos_RetryIsBoundedJitteredAndStopsAtTheDeadline`), every call bounded by its own 5 s deadline so an unbounded retry fails instead of hanging:
- One call against a dependency that keeps failing: the dependency receives **exactly** the attempt cap (3).
- The wait before attempt *k* is within its cap (100 ms, then 200 ms, plus 30 ms of scheduling slack), and across 10 calls the first wait varies by at least 5 ms (jitter).
- A 404 reaches the dependency once.
- With the caller's deadline shorter than two attempts, the call returns `context.DeadlineExceeded` by the deadline (+50 ms).
- 50 calls against a dependency that stays down send at most threshold × attempts (15): the open breaker caps the load. That is the "no retry storm" check.

**Seen failing:** with the attempt cap removed, `run 0: the dependency received 9 attempts for one call, want exactly 3`. backoff v7 has no `WithMaxRetries` or `WithContext`; `WithMaxTries(n)` counts attempts, not retries; its default `MaxElapsedTime` is 15 minutes; its `ExponentialBackOff` is ±50 % around the interval, not full jitter, and not safe to share between calls.

## Timeout and deadline propagation

**Defined:** every remote call has a deadline; the remaining deadline is passed down, so no dependency works longer than its caller waits.

**Assert** (`TestChaos_DeadlinePropagatesToTheDependency`): the dependency holds every request; the caller's deadline is half the attempt timeout; the call returns `context.DeadlineExceeded` by the deadline (+50 ms), and the dependency sees its request's context end by the deadline (+100 ms).

**Seen failing:** an attempt built on `context.Background()` with its own 2 s timeout: `the call returned after 2.002448292s, past the caller's 150ms deadline`. The fault-injecting `RoundTripper` honours `req.Context()` during an injected delay for the same reason (Go's `RoundTripper` contract).

## Bulkhead

**Defined:** one pool or concurrency limit per downstream; when full, fail fast; never queue without bound.

**Assert** (`TestChaos_SaturatedPoolDoesNotExhaustAnother`): hold every slot of downstream A with slow requests; one more call to A returns "unavailable" in under 20 ms; a call to downstream B succeeds in under 100 ms.

**Seen failing:** a pool shared by both clients: `another downstream's pool was exhausted too: tides: unavailable: bulkhead full`.

## Graceful degradation and load shedding

**Defined:** a defined, observable degraded answer when a dependency fails (`integration-design` §6); an overloaded service rejects early and cheaply (SRE: "fail early and cheaply", 503 once in-flight passes a threshold).

**Assert on the answer the SLI counts** (`handler_chaos_test.go`): under a dependency fault every answer for a berth seen before is **200 in under 800 ms**, marked `X-Degraded: stale`; a berth never seen gets 503 with `Retry-After`, which the SLI counts as bad and the report states. With the in-flight limit reached, one more request gets 503 with `Retry-After` in under 20 ms, and the admitted ones finish 200.

**Seen failing:** no fallback: `request 0 under the fault: 503 in 144ms, which the SLI counts as bad`; no limit: `over the limit: 200 in 201ms, want 503 with Retry-After at once`. Deployed (Toxiproxy, 2 s latency): the same no-fallback product made the runner abort at an SLI of 0.000.

## Lock order (partial deadlock and livelock)

**Why here:** Go's runtime deadlock detector fires only when every goroutine is blocked; `go test -race` finds data races, not deadlocks. A partial deadlock and a livelock are silent to both (*Concurrency in Go*, Cox-Buday). Only a deliberate experiment turns "we believe the lock order is safe" into a check.

**Assert** (`TestChaos_LockOrderHoldsUnderContention`): eight workers move pilots between two rosters in opposite directions at once, 200 rounds each, through the **shipped** `Move` (the 2.1.0 experiment injected its own reversed locks and asserted that they deadlocked, which tests nothing the product ships). A build-tagged hook widens the window between the two lock acquisitions. Pass: every move completes and the pilot count is unchanged. A stall detector samples progress every 100 ms; no progress for 2 s fails with the goroutine count and a full goroutine dump for `go-concurrency-patterns`' runbook.

**Signatures:** partial deadlock: progress stopped, goroutine count **flat and elevated**, CPU **idle**. Livelock: progress stopped, goroutines flat, CPU **pegged**. Starvation: one worker never progresses while others do. A climbing count is a leak, not this.

**Seen failing:** the lock order inverted (always `from` first): `partial deadlock: no move completed for 2s (0 of 1600 done); 9 goroutines flat above the 2 before`. It deadlocked with and without the hook on this machine; the hook makes it certain on any. No livelock experiment was run: the livelock signature above is from the book and the runbook, **unverified** here.

**Build tag:** the hook (`hook_chaos.go`) and every test that calls it carry `//go:build chaos`. Seen: an untagged test calling the tagged hook broke `go vet ./...` for everyone (`undefined: roster.SetBetweenLocks`).

## DLQ, idempotency and 429: confirm, do not re-prove

`go-integration-test` proves that a poison record is parked on the DLQ, that a redelivered event has one effect and that the rate limiter answers 429 with `Retry-After` (W3-D23). Chaos does not repeat those tests. It confirms they **still hold while a fault is active**: for example, with the broker's pod killed mid-batch, the integration test's duplicate-delivery assertion run against the deployed consumer after recovery shows one effect per event. Write such an experiment as a `go-test` experiment whose test runs while a Chaos Mesh fault is active (`../templates/experiment-definition.md`).

## Event-driven rows (shapes, not run)

These were rows without templates in 2.1.0. Each is an experiment shape for a product that has the pattern; **none was run in this rebuild** (unverified), because the lab product has no broker.

| Row | Fault | Steady state and assertion |
|---|---|---|
| Broker outage | Chaos Mesh `PodChaos` pod-kill on one broker pod of the throwaway cluster's broker release (never the last broker) | Outbox rows unpublished during the outage, drained to zero after; consumer lag returns to its baseline within the stated window; no event lost (count in = count out) |
| Poison message under a fault | A poison record published while the consumer's database is slowed (Toxiproxy latency) | The record lands on `<topic>.dlq` once; the next record is handled; partition keeps flowing |
| Duplicate delivery under a fault | Consumer pod killed after processing, before commit | Redelivered; one effect per event (the integration test's assertion, run after recovery) |
| Graceful shutdown | Chaos Mesh `PodChaos` pod-kill during steady requests, two replicas | The SLI holds; in-flight requests finish (no 502/EOF counted beyond the SLO's budget) |

## Boundary with load testing

This skill injects one isolated fault. `go-load-test`'s overload check makes the product's own traffic the stressor. A product can pass one and fail the other; neither replaces the other.
