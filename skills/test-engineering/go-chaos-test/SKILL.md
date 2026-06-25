---
name: go-chaos-test
description: >
  Teaches frugal chaos / resilience testing — injecting realistic failures
  (network latency, partitions, dependency outages, broker unavailability) to
  verify the resilience patterns already built actually work: Circuit Breaker,
  Retry with backoff, the Dead Letter Queue, idempotency, and graceful degradation.
  Uses toxiproxy and application-level fault injection rather than a chaos platform.
  Covers the hypothesis-driven experiment method and steady-state validation. The
  shift-right proof that the system survives the real world. Used by the test-strategist during Quality.
version: 1.0.0
phase: quality
owner: test-strategist
tags: [quality, chaos, resilience, toxiproxy, circuit-breaker, retry, dlq, fault-injection]
---

# Go Chaos Test

## Purpose

The system was built with resilience patterns — Circuit Breaker, Retry and Backoff, the Dead Letter Queue, idempotent consumers, graceful shutdown (`event-driven-patterns`, `integration-design`, `go-event-consumer`). Chaos testing proves those patterns **actually work** by deliberately injecting the failures they were designed to survive. An untested resilience pattern is a hope; a chaos-tested one is a guarantee.

This is **shift-right** validation of real-world resilience. The frugal stance: inject faults with lightweight tools (toxiproxy, app-level hooks) against an ephemeral stack — no chaos platform, no production blast radius.

---

## Hypothesis-Driven Experiments

Chaos testing is not random breakage — it is a controlled experiment with a hypothesis, the way a scientist tests a claim:

1. **Define steady state** — a measurable "healthy" signal (e.g., classify requests succeed within SLO; the pipeline drains).
2. **Hypothesise** — "if PostgreSQL latency spikes, the circuit breaker opens and requests fail fast with a clear error, instead of hanging."
3. **Inject the fault** — add the latency.
4. **Observe** — did the system behave as hypothesised, and did steady state recover after the fault was removed?
5. **Learn** — if it didn't, you found a resilience gap before production did.

Each experiment targets a **specific pattern** the system claims to have. The experiment passes when the pattern engages and the blast radius is contained.

---

## Toxiproxy — Network Fault Injection

Toxiproxy (Shopify, open-source) sits between the service and its dependency (Postgres, Redpanda, an external API) and injects controllable network faults — latency, bandwidth limits, connection drops, timeouts. The service connects through the proxy in the test environment; the test toggles "toxics."

```go
func TestCircuitBreaker_OpensOnDatabaseLatency(t *testing.T) {
    stack := startStack(t)                                 // app connects to Postgres via toxiproxy
    proxy := stack.dbProxy

    requireSteadyState(t, stack)                            // 1. healthy: classify succeeds

    // 3. inject: 5s of added latency on every DB call
    _ = proxy.AddToxic("latency", "latency", "downstream", 1.0, toxiproxy.Attributes{"latency": 5000})
    t.Cleanup(func() { _ = proxy.RemoveToxic("latency") })

    // 2/4. hypothesis: the breaker opens and requests fail FAST, not hang for 5s
    start := time.Now()
    err := classify(t, stack, sampleCmd)
    require.ErrorIs(t, err, ErrServiceUnavailable)          // fails fast with a clear error
    require.Less(t, time.Since(start), 1*time.Second)       // did NOT wait on the slow dependency

    proxy.RemoveToxic("latency")
    requireEventualSteadyState(t, stack, 30*time.Second)    // 5. recovers after the fault clears
}
```

The assertion that matters is **fail-fast + recover**: the breaker turns a slow dependency into a fast, contained failure, and the system heals once the dependency does.

---

## Application-Level Fault Injection

Some faults are cleaner to inject in-process than over the network — a dependency returning an error, a forced panic in a consumer, a simulated partial failure. A tiny, test-only fault hook (behind a build tag or interface seam) makes the resilience path reachable without breaking real infrastructure.

```go
// A fault-injecting decorator over a port, enabled only in chaos tests.
type faultyPublisher struct {
    domain.EventPublisher
    failNext atomic.Bool
}
func (f *faultyPublisher) Publish(ctx context.Context, e domain.DomainEvent) error {
    if f.failNext.Swap(false) { return errors.New("injected publish failure") }
    return f.EventPublisher.Publish(ctx, e)
}
```

This is the frugal alternative to killing pods: exercise the exact failure the pattern handles, deterministically, in a unit/integration-style test.

---

## The Patterns to Validate

Each built-in resilience pattern gets at least one experiment proving it works:

| Pattern | Fault injected | Expected behaviour |
|---|---|---|
| **Circuit Breaker** | Dependency latency/errors | Opens → fails fast → half-opens → closes on recovery |
| **Retry + Backoff** | Transient dependency error | Retries with backoff; succeeds on a later attempt |
| **Dead Letter Queue** | Poison message / persistent failure | Exhausts retries → routes to DLQ → partition keeps flowing |
| **Idempotent consumer** | Duplicate / redelivered event | Processed exactly once (dedup holds under redelivery) |
| **Graceful shutdown** | SIGTERM mid-request / mid-batch | In-flight work drains; no dropped requests/events |
| **Broker outage** | Redpanda unavailable | Outbox retains events; publishes on recovery (no loss) |
| **Backpressure** | Ingestion faster than processing | Lag grows bounded; system degrades, doesn't collapse |

These map one-to-one to patterns already implemented — chaos testing closes the loop from "we built a circuit breaker" to "we proved the circuit breaker works."

---

## Steady State and Blast Radius

- **Steady state** is measured from the existing telemetry (RED/USE — `opentelemetry-instrumentation`): success rate, latency, consumer lag. The experiment asserts steady state before, controlled deviation during, and recovery after.
- **Blast radius is bounded**: experiments run against an **ephemeral, isolated stack** (or an isolated tenant), never production. Start small (one dependency, one fault), expand only as confidence grows.
- **Tenant isolation is itself a chaos hypothesis**: injecting a fault in one tenant's stack must not affect another — validating the physical multi-tenancy guarantee (`multi-tenancy-design`).

---

## Frugality Note

Full chaos platforms (Chaos Mesh, Litmus, Gremlin) orchestrate cluster-wide failure and are valuable at scale — but for a solo operator they are operational overhead. **toxiproxy + app-level injection** exercises the same resilience patterns with a fraction of the setup. Adopt a platform only when running many services at a scale where coordinated cluster chaos earns its keep — and record that decision as an ADR.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Hypothesis-driven | Each experiment states steady state + expected behaviour | Random breakage with no hypothesis |
| Validates real patterns | Every built resilience pattern has an experiment | "We have a circuit breaker" — untested |
| Fail-fast + recover | Asserts containment AND recovery to steady state | Only checks it fails, not that it heals |
| Bounded blast radius | Ephemeral/isolated stack; start small | Chaos against production |
| Tenant isolation tested | Fault in one tenant doesn't reach another | Cross-tenant impact unverified |
| Steady state measured | Uses existing RED/USE telemetry | No measurable health signal |
| Frugal tooling | toxiproxy + app-level injection | A chaos platform for a solo system |

---

## Output Format

Produces chaos experiments and the fault-injection harness:

```
tests/chaos/*_test.go                  (hypothesis-driven experiments per pattern)
tests/chaos/toxiproxy.go                (proxy setup + toxic helpers)
internal/test/faults/*.go               (app-level fault-injecting decorators)
docs/quality/resilience-report.md       (patterns validated, gaps found)
```
