---
name: python-chaos-test
description: >
  Teaches the backend-engineer to write Python chaos tests — fault injection
  via toxiproxy (latency, timeout, partition) or testcontainers dependency
  kills, hypothesis-driven experiments with a bounded blast radius, and
  pass/fail against a stated resilience assumption (circuit breaker engages,
  consumer recovers, no data loss). The Python analog of go-chaos-test; frugal
  (toxiproxy, not a chaos platform).
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, chaos, resilience, toxiproxy, testcontainers, circuit-breaker, consumer-recovery, fault-injection, blast-radius, asyncio, tenant]
related: [go-chaos-test, disaster-recovery-plan, python-integration-test]
tools: [Bash]
---

# Python Chaos Test

## Purpose

The service was built with resilience patterns — a Circuit Breaker on outbound
downstream calls, an idempotent consumer with a Dead Letter Queue and
retry+backoff (`python-event-consumer`), the outbox-as-backpressure relay
(`python-event-publisher`). Chaos testing proves those patterns **actually
work** by deliberately injecting the failure each was designed to survive. An
untested resilience pattern is a hope; a chaos-tested one is a guarantee. The
discipline is identical to `go-chaos-test`; only the runner (`pytest` +
`pytest-asyncio`), the fault mechanism (`toxiproxy-python` + testcontainers
container-kill instead of a Go toxiproxy client + Chaos Mesh CRDs), and the
async recovery-polling mechanics differ.

**Boundary against load testing.** This skill injects a **specific, isolated
fault** — a severed link, a killed broker, an exhausted pool — independent of
request volume. Proving the same patterns engage when the system's own
**traffic volume** is the stressor (no injected fault) is a load test's job.
A system can pass one and fail the other; neither substitutes for the other.

---

## Hypothesis-Driven Experiment Shape

Every experiment states four things, in order, **before** the fault is
injected — **assume → inject → observe → conclude** made concrete:

1. **Steady state** — a number from real telemetry, over a stated window
   (e.g. `p99(classify_duration_seconds) < 0.8` over the 60s pre-fault window),
   never an assertion invented for the test.
2. **Hypothesis** — one falsifiable sentence naming the exact pattern
   (`glossary-management`'s canonical **Circuit Breaker** / **Dead Letter
   Queue** / **Idempotency**, never a paraphrase) and the state transition
   expected: "if the Postgres link is severed, the Circuit Breaker opens within
   5s and calls fail fast with `ServiceUnavailableError`, not hang."
3. **Blast radius** — explicit and narrow: one tenant's stack, one dependency,
   one fault type, inside an ephemeral testcontainers stack — never two
   simultaneous faults, never a shared environment on a first run.
4. **Rollback trigger** — an exact automatic condition written down first
   (`ABORT IF error_rate > 5% OR steady-state breach sustained > 60s`), fired
   by an in-test async poll loop, never a human watching output scroll by.

A hypothesis that only predicts failure ("the system will struggle") is
unfalsifiable and proves nothing. The full four-part test-header convention,
the async abort-loop wiring, and the blast-radius scoping table:
`references/experiment-design.md`.

---

## The Four Elements as a Test Header

Every experiment carries this comment block immediately above its test
function — reviewable by Shafi before reading a line of Python:

```python
# EXPERIMENT:   Circuit Breaker opens when the Postgres link is severed
# STEADY STATE: p99 classify latency < 0.8s, error rate < 0.1% (60s pre-fault)
# HYPOTHESIS:   a severed DB link trips the breaker within 5s; calls fail fast
#               with ServiceUnavailableError, never hang on a dead socket
# BLAST RADIUS: one tenant's ephemeral stack, Postgres link only
# ROLLBACK:     abort if error_rate > 5% OR steady-state breach sustained > 60s
async def test_breaker_opens_on_severed_db_link(chaos_stack): ...
```

An experiment whose header is missing any of the four lines fails review
regardless of what the body does.

---

## Fault Mechanisms — Two Frugal Tiers

Chosen for the narrowest thing that produces the fault:

| Fault shape | Tool | Why |
|---|---|---|
| A dependency call misbehaves on the wire (latency, timeout, a severed/reset link) while the process stays up | **toxiproxy** (`toxiproxy-python` client), the app dialing the dependency **through** the proxy port | The fault is genuinely on the TCP path, not in app code; deterministic, fast, in-process to drive |
| The dependency itself goes away (a broker or DB dies and comes back) | **testcontainers** `container.stop()` / `container.get_wrapped_container().kill()` then restart | A real process death and recovery at the Docker layer — no cluster tooling |

**The frugal-toxiproxy default.** Toxiproxy is a single open-source proxy
container, not a chaos platform. This is a **real divergence from
`go-chaos-test`**, which reaches for Chaos Mesh (a Kubernetes chaos platform)
to produce pod-scheduling and mesh-namespace faults that toxiproxy structurally
cannot. This skill deliberately does **not** — an in-test chaos suite scopes
itself to what toxiproxy (wire faults) and testcontainers (dependency death)
can produce inside an ephemeral Docker stack. Pod-kill and Linkerd-layer
partition are a cluster-level concern deferred to Deploy, not reinvented here;
that keeps the Python chaos suite frugal and runnable in CI without a cluster.

Toxic types this repo uses — `latency` (added delay), `timeout` (stop data,
close after N ms), and a hard link sever for a partition — with the exact
`toxiproxy-python` calls, the fixture that wires the app DSN through the proxy,
guaranteed toxic cleanup, and two full worked experiments (sever Postgres →
breaker opens; kill a Redpanda broker → consumer resumes from its committed
offset with no data loss): `references/toxiproxy-fault-injection.md`.

---

## The Patterns to Validate

| Pattern | Fault injected | Expected behaviour |
|---|---|---|
| **Circuit Breaker** | Downstream latency / a severed link | Opens → fails fast → half-opens → closes on recovery |
| **Retry + Backoff** | Transient dependency error | Retries with backoff; a later attempt succeeds |
| **Dead Letter Queue** | Poison / persistently-failing message | Exhausts retries → routes to `<topic>.dlq` → partition head keeps flowing |
| **Idempotent consumer** | Redelivered event after a broker blip | Effect happens exactly once (dedup holds under redelivery) |
| **Graceful drain** | `SIGTERM` mid-batch | In-flight work finishes, final offsets commit, no lost events |
| **Broker outage** | Redpanda container killed | Outbox retains rows (no loss); consumer resumes from committed offset; both recover |

The assertion that always matters is **contain the fault AND recover to steady
state** — an experiment that only proves the system breaks is half an
experiment. Recovery is eventually consistent: **poll with a deadline**, never
`await asyncio.sleep(n)` as a "give it a second" guess (same rule as
`python-integration-test`).

---

## Safety Rails

Two independent, mandatory rails on every experiment. **Environment
restriction** — a chaos test's first run targets an **ephemeral testcontainers
stack** (or a `chaos`-marked, Docker-only suite), never a shared or production
environment; `@pytest.mark.chaos` gates it so `pytest -m "not chaos"` skips it
where Docker is unavailable. **Automatic abort** — because the whole experiment
runs in one async process, the abort *is* Python: an `asyncio` poll task
watches the steady-state signal and calls the fault's own removal
(`toxic.destroy()`, restart the container) the instant the rollback trigger is
crossed. Full staged-environment reasoning and the abort-task wiring:
`references/experiment-design.md`.

---

## Corrective-Action Output

A failed experiment is a finding, not a defeat: it names a resilience assumption
that does not hold. Each failing experiment produces a corrective action —
a config fix (breaker threshold, retry budget), a code fix, or a documented
operational procedure that feeds `disaster-recovery-plan`'s runbook. The
mapping from "which experiment failed" to "which recovery procedure or fix it
demands": `references/experiment-design.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Four-part header | Steady state + hypothesis + blast radius + rollback, stated before injection | Any of the four missing or decided mid-run |
| Hypothesis falsifiable | Names the exact pattern and state transition | "The system will struggle" — unfalsifiable |
| Contain AND recover | Asserts fail-fast/containment AND recovery to steady state | Only proves it breaks, not that it heals |
| Blast radius bounded | One tenant/dependency/fault, ephemeral stack, escalated only after a clean pass | Two faults at once, or a shared env on a first run |
| Rollback automatic | An async poll task removes the fault on the numeric trigger | A human watching output is the only abort |
| Right tool | toxiproxy for wire faults, testcontainers kill for dependency death | A chaos platform reached for where toxiproxy suffices |
| No sleeps | Recovery polled with a deadline | `asyncio.sleep` waiting for the breaker/consumer |
| Toxics cleaned up | Every `add_toxic` paired with a guaranteed `destroy` in teardown | A leaked toxic poisons every later test |
| Tenant isolation | A fault in one tenant's stack verified not to reach another | Cross-tenant impact unverified |
| Chaos-marked & Docker-only | `@pytest.mark.chaos`; `-m "not chaos"` skips | Runs against a shared/real dependency |
| No-data-loss proven | Broker-outage test asserts the outbox row survives and republishes | Only checks the consumer reconnects |

---

## Anti-Patterns

- **Random breakage without a hypothesis** — pulling the plug to "see what
  happens" yields anecdotes; only a stated steady state and expected transition
  yield a pass/fail verdict.
- **Asserting failure but not recovery** — the system must return to steady
  state once the fault clears; half an experiment proves nothing durable.
- **Reaching for a chaos platform** — this suite is frugal by design;
  toxiproxy + testcontainers cover every fault it needs inside CI's Docker.
- **`asyncio.sleep` around the fault window** — recovery is eventually
  consistent; poll for steady state with a deadline instead.
- **A leaked toxic** — an `add_toxic` with no matching `destroy` in teardown
  silently degrades every later test in the run.
- **Unbounded blast radius** — a first run against a shared environment turns a
  test into an incident.
- **A rollback trigger decided while watching it degrade** — that is a post-hoc
  rationalization of however bad it was allowed to get, not a safety rail.

---

## Output Format

Produces chaos experiment files and the fault-injection harness:

```
tests/chaos/conftest.py                    (toxiproxy + testcontainers chaos_stack fixture, toxic cleanup)
tests/chaos/test_breaker_severed_db.py     (sever Postgres link → Circuit Breaker opens, recovers)
tests/chaos/test_consumer_broker_kill.py   (kill Redpanda broker → consumer resumes, no data loss)
docs/quality/resilience-report.md          (pointer: patterns validated, blast-radius stages, gaps → disaster-recovery-plan)
```

Full standards: `references/toxiproxy-fault-injection.md` (toxiproxy container +
`toxiproxy-python` client, toxic types, DSN wiring, guaranteed cleanup, both
worked experiments) and `references/experiment-design.md` (four-part header,
hypothesis template, blast-radius controls, async abort task, corrective-action
mapping to `disaster-recovery-plan`).
