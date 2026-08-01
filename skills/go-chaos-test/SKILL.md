---
name: go-chaos-test
description: >
  This plugin's chaos-engineering standard for Go — deliberately injecting an
  artificial, isolated fault (independent of load) to prove the resilience
  patterns already built actually work: Circuit Breaker, Retry with backoff,
  the Dead Letter Queue, idempotency, and graceful degradation. Covers the
  hypothesis-driven experiment-design standard (steady-state definition,
  blast-radius scoping, an exact automatic rollback trigger — references/
  experiment-design-standard.md); the fault-injection catalogue for this
  repo's actual stack — pod kill, Linkerd-layer network partition/latency via
  Chaos Mesh, Postgres connection-pool exhaustion, Redpanda broker
  unavailability, each with an exact experiment template
  (references/fault-injection-catalogue.md); a full worked partial-deadlock/
  livelock experiment that deliberately induces the one failure shape neither
  `go test -race` nor the runtime deadlock detector catches, deferring to
  go-concurrency-patterns' runbook for diagnosis rather than restating it
  (references/deadlock-livelock-worked-experiment.md); and the safety-rail
  standard — non-production/canary-scoped environments only, automatic abort
  conditions wired to the same alerting stack, never a human watching a
  dashboard (references/safety-rails-standard.md). Used by the
  test-strategist during Quality.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, chaos, resilience, toxiproxy, chaos-mesh, circuit-breaker, retry, dlq, fault-injection, blast-radius, deadlock, livelock]
produces: go-chaos-test
domain: testing
status: stable
related: [go-load-test, go-concurrency-patterns, go-event-consumer, go-event-publisher, integration-design, canary-deployment, kubernetes-manifest, multi-tenancy-design, alerting-rules-design, glossary-management]
---

# Go Chaos Test

## Purpose

The system was built with resilience patterns — Circuit Breaker, Retry and Backoff, the Dead Letter Queue, idempotent consumers, graceful shutdown (`event-driven-patterns`, `integration-design`, `go-event-consumer`). Chaos testing proves those patterns **actually work** by deliberately injecting the failures they were designed to survive. An untested resilience pattern is a hope; a chaos-tested one is a guarantee. Authored and run by the test-strategist during Quality.

**Boundary against `go-load-test`:** this skill injects a **specific, isolated fault** — a killed pod, a severed network link, an exhausted pool — independent of request volume; `go-load-test`'s `references/backpressure-and-reporting-standard.md` proves the same patterns engage when the system's own **traffic volume** is the stressor instead, no injected fault. A system can pass one and fail the other; neither substitutes for the other, and the boundary statement in that file is authoritative — read it before assuming overlap.

---

## Hypothesis-Driven Experiment Design

Every experiment states four things, in order, **before** the fault is injected: a measurable **steady state** pulled from real telemetry; a falsifiable **hypothesis** naming the exact pattern and expected behavior; an explicit **blast-radius scope** (one canary pod, one tenant — never the whole fleet on a first run); and an exact, automatic **rollback trigger** (e.g. `abort if error_rate > 5% OR steady-state breach sustained > 60s`). Full standard, the four-part test-header convention, and the blast-radius scoping table: `references/experiment-design-standard.md`.

---

## Fault-Injection Catalogue

Two tool tiers, chosen for the narrowest thing that produces the fault: **toxiproxy + app-level fault decorators** for a dependency call itself misbehaving from inside the test process (already this skill's frugal default — see the worked Circuit Breaker example below); **Chaos Mesh** (CNCF, open-source, one Helm chart) for infrastructure-level faults no in-process tool can produce — a pod dying, a network link severing beneath Linkerd. Four fault types, one exact experiment template each:

| Fault | Tool | Proves |
|---|---|---|
| **Pod kill** | Chaos Mesh `PodChaos` | PDB + readiness probe + Linkerd retry mask a single pod's death from callers |
| **Linkerd-layer network partition/latency** | Chaos Mesh `NetworkChaos` (below the mesh proxy, doesn't fight Linkerd) | Circuit Breaker opens on an unreachable/slow downstream instead of hanging on an mTLS handshake |
| **Postgres connection-pool exhaustion** | App-level (hold every `pgxpool.Pool` connection deliberately) | Pool exhaustion fails fast via the breaker, never queues unbounded or deadlocks |
| **Redpanda broker unavailability** | Chaos Mesh `PodChaos` on the broker | Outbox relay backs off without loss (`go-event-publisher`); consumer retries and resumes from its committed offset (`go-event-consumer`) — cross-referenced, not restated |

Full YAML/Go templates, exact assertions, and why Chaos Mesh over Litmus: `references/fault-injection-catalogue.md`.

---

## Toxiproxy — Network Fault Injection (In-Process)

Toxiproxy (Shopify, open-source) sits between the service and a dependency it dials, injecting latency, drops, or timeouts the app-level fault decorators below can't reach because the fault is genuinely on the wire, not in application code:

```go
func TestCircuitBreaker_OpensOnDatabaseLatency(t *testing.T) {
    stack := startStack(t)
    requireSteadyState(t, stack)
    _ = stack.dbProxy.AddToxic("latency", "latency", "downstream", 1.0, toxiproxy.Attributes{"latency": 5000})
    t.Cleanup(func() { _ = stack.dbProxy.RemoveToxic("latency") })

    start := time.Now()
    err := classify(t, stack, sampleCmd)
    require.ErrorIs(t, err, ErrServiceUnavailable)          // fails fast, not after 5s
    require.Less(t, time.Since(start), 1*time.Second)

    stack.dbProxy.RemoveToxic("latency")
    requireEventualSteadyState(t, stack, 30*time.Second)    // recovers after the fault clears
}
```

The assertion that matters is **fail-fast + recover**. Every `AddToxic` pairs with a `t.Cleanup` removal — a leaked toxic poisons every later test in the run.

---

## The Patterns to Validate

| Pattern | Fault injected | Expected behaviour |
|---|---|---|
| **Circuit Breaker** | Dependency latency/errors, pool exhaustion | Opens → fails fast → half-opens → closes on recovery |
| **Retry + Backoff** | Transient dependency error | Retries with backoff; succeeds on a later attempt |
| **Dead Letter Queue** | Poison message / persistent failure | Exhausts retries → routes to DLQ → partition keeps flowing |
| **Idempotent consumer** | Duplicate / redelivered event | Processed exactly once (dedup holds under redelivery) |
| **Graceful shutdown** | SIGTERM mid-request / mid-batch | In-flight work drains; no dropped requests/events |
| **Broker outage** | Redpanda broker killed | Outbox retains events; consumer resumes from offset; both recover |
| **Pod / network resilience** | Pod kill, Linkerd-layer partition | PDB + retry mask it; breaker opens on unreachable downstream |
| **Partial deadlock / livelock** | Artificial opposite-order lock contention (build-tag-gated, never production code) | Flat elevated goroutine count + idle CPU (deadlock) or pegged CPU (livelock) detected automatically within a timeout — the only place in the toolchain that notices either, since neither `-race` nor the runtime deadlock detector catches a partial deadlock or livelock (`go-concurrency-patterns`' Deadlock/Livelock/Starvation section) |

Full worked deadlock/livelock experiment — steady state, fault-injection mechanism, detection loop, and the explicit handoff to `go-concurrency-patterns`' incident-response runbook for diagnosis rather than a restatement of it: `references/deadlock-livelock-worked-experiment.md`.

---

## Safety Rails

Two mandatory, independent rails on every experiment above: **environment restriction** — first run always against an isolated/ephemeral stack or a canary-scoped slice (`canary-deployment`'s existing weighted-traffic + SLO-burn-gate mechanism, aimed at an injected fault instead of a new release), never unscoped production; and **automatic abort** — the rollback trigger fires from a Prometheus alert + watcher loop (Chaos Mesh experiments) or in-process polling (toxiproxy/app-level experiments), never a human who happens to be watching a dashboard. Full staged-environment table and the abort-wiring YAML: `references/safety-rails-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Four-part experiment header | Steady state + hypothesis + blast radius + rollback trigger, stated before injection | Any of the four missing or decided mid-experiment |
| Hypothesis falsifiable | Names the exact pattern and expected state transition | "The system will struggle" — unfalsifiable |
| Fail-fast + recover | Asserts containment AND recovery to steady state | Only checks it fails, not that it heals |
| Blast radius bounded and escalated | One canary pod/tenant first; wider scope only after a clean pass | Whole fleet or all tenants on a first run |
| Rollback trigger automatic | Wired to fire without a human watching (alert+watcher or in-process poll) | A person watching a dashboard is the only abort mechanism |
| Right tool for the fault | Toxiproxy/app-level for in-process faults; Chaos Mesh only for infra-level faults it alone can produce | Chaos platform reached for where toxiproxy would do; or infra faults faked in-process |
| Catalogue faults covered | Pod kill, Linkerd network partition/latency, pool exhaustion, broker unavailability each have a template | A stack-specific fault type with no experiment |
| Deadlock/livelock covered | Build-tag-gated fault; automated goroutine-count/CPU detection; defers to the runbook for diagnosis | No concurrency-correctness experiment; or diagnosis steps restated instead of cross-referenced |
| Tenant isolation tested | Fault in one tenant's stack verified not to reach another | Cross-tenant impact unverified |
| Environment-scoped | Non-production or canary-scoped only, staged escalation | First run against unscoped production |
| Leaked toxics/CRs cleaned up | Every `AddToxic`/Chaos Mesh CR paired with guaranteed removal | Poisoned later tests or an orphaned chaos CR left running |
| Boundary against `go-load-test` respected | Injected, isolated fault only — no organic-overload testing duplicated here | Volume-ramp testing reinvented in this skill instead of cited |

---

## Anti-Patterns

- **Random breakage without a hypothesis** — pulling cables to "see what happens" produces anecdotes; only a stated steady state and expected behaviour produce a pass/fail verdict.
- **Asserting failure but not recovery** — half an experiment; the system must return to steady state once the fault clears.
- **Unbounded blast radius** — running any experiment's first attempt against a shared or full-production environment converts a test into an incident.
- **A rollback trigger decided while watching the experiment degrade** — not a safety rail; a post-hoc rationalization of however bad it was allowed to get.
- **Reaching for Chaos Mesh where toxiproxy suffices** (or the reverse) — each tool tier exists because the other structurally cannot produce that fault; using the wrong one is either overkill or a fault that was never really injected.
- **Restating the deadlock/livelock runbook's diagnostic steps here** — this skill proves detection works before an incident; the runbook diagnoses one. Cross-reference, never duplicate.
- **Fixed sleeps around fault windows** — recovery is eventually consistent; poll for steady state with a deadline, exactly as in `go-e2e-test`.
- **Leaving toxics or Chaos Mesh CRs behind** — a leaked fault poisons every later test or keeps degrading a canary after the experiment "ended."

---

## Output Format

Every artifact below is reviewable by Shafi without IDE tooling and carries the four-part experiment header (`references/experiment-design-standard.md`) where applicable — this is a checkable engineering standard per file, not a folder listing:

- **`tests/chaos/*_test.go`** — one hypothesis-driven experiment per pattern under test, each with the `EXPERIMENT`/`STEADY STATE`/`HYPOTHESIS`/`BLAST RADIUS`/`ROLLBACK` comment header immediately above its test function. Uses `requireSteadyState`/`requireEventualSteadyState` polling helpers, never a fixed `time.Sleep`. Every `t.Cleanup` guarantees toxic/fault removal on both pass and failure paths.
- **`tests/chaos/toxiproxy.go`** — proxy setup and toxic helpers for in-process dependency faults; every `AddToxic` call site has a matching `t.Cleanup(RemoveToxic)` in the same function.
- **`internal/test/faults/*.go`** — app-level fault-injecting decorators (the `faultyPublisher` shape) and the build-tag-gated (`//go:build chaos_deadlock`) contention-injection helpers for the deadlock/livelock experiment — never compiled into a production build.
- **`chaos/*.yaml`** — Chaos Mesh `PodChaos`/`NetworkChaos` manifests, one per infrastructure-level experiment, each scoped by an explicit `labelSelectors`/`namespaces` block matching the experiment's stated blast radius — never a selector broader than the experiment's own header declares.
- **`chaos/abort-rule-*.yaml`** — the `PrometheusRule` encoding each infrastructure experiment's exact rollback trigger, paired with the watcher script that deletes the Chaos Mesh CR on fire.
- **`docs/quality/resilience-report.md`** — a pointer, not a data dump: which patterns were validated, which experiments ran at which blast-radius stage, and any gaps found — the durable record is the experiment code and the telemetry it ran against, this file is the reviewable summary.
