---
name: python-load-test
description: >
  Teaches the backend-engineer to write Python load tests — locust
  (Python-native, user-behavior classes) or k6 as a black-box generator
  running OUTSIDE the target, closed-vs-open workload models, ramp/soak/spike
  profiles, and pass criteria tied to SLOs (P95 latency, error rate under
  load). The Python analog of go-load-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, load-test, locust, k6, slo, throughput, latency, backpressure, shift-right]
produces: load-test-suite
domain: testing
status: stable
related: [go-load-test, python-performance-test, slo-definition, nfr-specification]
tools: [Bash]
---

# Python Load Test

## Purpose

Unit, integration, and even `python-performance-test`'s in-process `pytest-benchmark` gate say
nothing about the deployed FastAPI service under real, sustained traffic. Load testing answers what
those layers structurally cannot: real requests/sec, real P95/P99 under network/Linkerd-mTLS/
`asyncpg`-pool overhead, when the async service starts shedding, and whether it holds the Service
Level Objectives `slo-definition` set — the **shift-right** proof closing the gap between "the
coroutine's own logic is fast" and "the system holds up in production-like conditions." Authored and
run by the backend-engineer during Quality.

---

## Tool Standard: locust (Python-native) or k6 (black-box) — Both Run OUTSIDE the Target

Two sanctioned open-source generators, chosen per the job — **never a paid SaaS tier**, per
CLAUDE.md's frugality constraint:

| Tool | Style | Use when |
|---|---|---|
| **locust** (MIT) | Python `User`/`@task` behavior classes, `HttpUser`, weighted tasks | The journey mix is complex or maintained by the same team that writes the FastAPI service — user behavior reads as ordinary Python and lives beside the app it exercises |
| **k6** (Grafana Labs, Apache-2.0) | JS scenarios, `thresholds` DSL as a hard pass/fail exit code | A pure black-box rate gate is wanted, or one load tool is shared across a polyglot (Go/Node/Python) estate |

**Whichever tool, it runs entirely OUTSIDE the target — a separate process driving HTTP at the
`uvicorn`-served binary it never imports, exactly like `curl`.** locust being written in Python is
*not* a departure from the black-box rule: it is still an external client, never in-process with the
service under test. Do not reach for a third tool — `locust` and `k6` between them cover Python-
native ergonomics and cross-stack uniformity; adding one more duplicates mature tooling for no gain.
Full comparison, locust class structure, and the distributed-run mechanic:
`references/locust-load-profiles.md`.

---

## Environment Standard: `staging`, Not an Ephemeral Testcontainer

`python-integration-test` runs against a throwaway `testcontainers-python` Postgres/Redpanda started
per test session — correct there, since it proves the code's *behavior* against a real dependency,
which a single shared container does fine. **Load testing proves *capacity*, and a shared-machine
container on a CI runner cannot produce a meaningful capacity number** — host scheduler contention
corrupts the exact latency/throughput being measured. This skill runs against **`staging`** instead
(`environment-config`'s purpose-built "full-stack soak" environment): same chart, same image digest
(Environment Parity), reduced sizing declared in every report and never mistaken for a production
guarantee, one synthetic load-test tenant identity, never a real customer's physically-isolated
production stamp, and never production itself. Because tenants are **physically isolated**, a load
run's synthetic tenant exercises one dedicated stamp end to end — its saturation cannot bleed into
another tenant's, and the capacity number is per-stamp, exactly the unit that matters for sizing.

---

## Load-Profile Standard: Ramp, Soak, Spike — Sized to This Platform's Traffic Shape

Real traffic is bursty, not a smooth ramp: `estate-scanner`'s discovery sweeps enqueue thousands of
documents in seconds, absorbed as a burst by the `aiokafka` pipeline, while `ClassifyDataAsset` sees
low, steady interactive volume. Every profile is parameterized against that shape:

| Profile | Shape | This platform's parameters |
|---|---|---|
| **Smoke** | 1 user, ~1 min | Fast CI pre-check; every change |
| **Ramp** | Closed-model climb past capacity | 0→50 users over 2 min, hold 5 min, 50→500 over 5 min until SLO breach |
| **Soak** | Open-model sustained, hours | 30 req/s sync + 500 docs/min pipeline feed, held 2 hours |
| **Spike** | Sudden batch burst | 30 req/s baseline + a 10,000-document burst in under 60s |

Traffic is always a journey mix (`GET /v1/data-assets` list, `GET …/{id}` detail,
`PATCH …/{id}/classification` the SLO-gated command), never one endpoint hammered with one payload —
that measures a cache, not the system. Full locust profile code, the workload-model reasoning, and
the worked DataAsset-API load test: `references/locust-load-profiles.md`.

---

## Closed vs. Open Workload Model — A Deliberate Choice, Not a Default

A **closed** model (a fixed pool of users, each waiting for its response before sending the next
request) lets offered load quietly drop when the service slows — tail latency is understated
(*coordinated omission*), because real users don't wait politely for a slow server. An **open** model
issues requests at a declared arrival rate regardless of response time, like independent real users.
**Use the open model for every profile whose question is "does it hold an SLO at N req/s"** (Soak,
Spike's baseline); **use the closed model only for Ramp**, where letting offered load throttle
naturally is the mechanism that finds the break.

This is where locust and k6 diverge sharply, and it must not be glossed. **locust is closed-model by
construction** — a `User` sleeps `wait_time` between tasks, so it is naturally a Ramp/closed tool; to
approximate an open arrival-rate model it needs a custom `LoadTestShape` or `constant_throughput`
pacing, covered in `references/locust-load-profiles.md`. **k6's `constant-arrival-rate`/
`ramping-arrival-rate` executors are open-model out of the box.** Pick the tool that matches the
profile's model, or configure locust explicitly for the open case — never let the default stand
unexamined on a rate-based SLO claim. Full reasoning: `references/criteria-and-analysis.md`.

---

## SLO-Based Pass/Fail Gate: `slo-definition`'s Real Numbers, Not Invented Ones

Every pass threshold is copied from `slo-definition` (which formalizes `nfr-specification`'s stated
requirements), never independently derived: **availability 99.5%** (error rate < 0.005), **latency
99.5% of ClassifyDataAsset requests under 800ms**, **pipeline freshness 99% within 15 min**,
**consumer correctness 99.9%**. Report **percentiles (P95/P99), never the mean** — an average across
a shedding population hides the exact tail the SLO is written against. The two async SLOs (freshness,
correctness) are verified post-drain via PromQL against series `prometheus-metrics-design` already
computes — no synchronous load request waits 15 minutes for a classification. A passing P99 against
the real deployed system in `staging` **is** that system's end-to-end P99 — the loop
`python-performance-test`'s in-process benchmark deliberately leaves open closes here. Full gate,
result-reading discipline, backpressure assertions, and capacity findings:
`references/criteria-and-analysis.md`.

---

## Backpressure Under Organic Overload — Prove Graceful Degradation

A load test must prove the service **degrades gracefully** under its own request *volume* — sheds
fast (`python-middleware`'s rate limiter, `429` with `Retry-After`) or a Circuit Breaker opens on a
saturating dependency (the `asyncpg` pool) — rather than collapsing or silently queuing coroutines
until the event loop stalls and memory grows unbounded. This is organic-overload verification,
**distinct from `python-chaos-test`**, which proves the same patterns under a deliberately injected
`toxiproxy` fault at normal volume — complementary, neither a substitute. The Ramp/Spike profiles
assert `429`s rise as offered load exceeds the limiter's rate, the saturated path fails fast rather
than queuing into climbing latency, and error rate/P99 return to baseline once load subsides. Full
assertions: `references/criteria-and-analysis.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| SLOs gated on real numbers | Thresholds copied from `slo-definition`; breach fails the run | Invented targets, or numbers drifting from the SLO document |
| Percentiles, not the mean | P95/P99 reported and gated | Averages reported; the shedding tail hidden |
| Generator runs outside the target | locust/k6 as an external client process | Load logic imported in-process with the FastAPI app |
| Workload model chosen deliberately | Open model for rate SLOs; closed only to find the break; locust configured explicitly for the open case | Closed-model default left unexamined on a rate claim (coordinated omission) |
| Environment correct | `staging`, production-shaped, sized and declared, per-stamp | A testcontainer or a laptop; non-representative capacity claim |
| Async SLOs verified | Freshness/correctness via PromQL post-drain | Only sync endpoints tested; `aiokafka` pipeline lag ignored |
| Backpressure proven, distinct from chaos | `429`/breaker engages under organic volume with recovery | Total collapse or silent queuing; conflated with chaos testing |
| Realistic traffic mix | Journey-mix endpoints and payload variety | One endpoint, one payload |
| Frugal tooling | Self-hosted locust/k6 | A paid SaaS load platform |

---

## Anti-Patterns

- **Reporting the mean** — hides the P99 tail the SLO is written against.
- **A closed-model generator on a rate-based SLO claim** — coordinated omission understates real tail latency; locust needs explicit open-model configuration to make this claim honestly.
- **Load-testing a testcontainer or a laptop** — numbers describe host contention, not capacity.
- **Load-testing production** — physically-isolated real tenants become the blast radius; `staging` exists to absorb this.
- **Inventing SLO numbers instead of copying `slo-definition`'s** — proves nothing an operator agreed to.
- **Conflating this with `python-chaos-test`** — organic-overload and injected-fault are complementary, not interchangeable.
- **Ignoring the async half** — a green sync run with an undrained `aiokafka` burst is a failing system on a delay timer.
- **One locust process for serious load** — one process is capped by a single core under the GIL; see `references/locust-load-profiles.md`.

---

## Output Format

- **`load/locustfile.py`** (or `load/scenarios/{smoke,ramp,soak,spike}.js` for k6) — the generator
  definitions, journey-mix traffic, SLO-derived pass criteria, `429` + `Retry-After` backpressure
  checks. Executor/shape model chosen per the rule above, never defaulted without stating why.
- **`load/verify-async-slos.sh`** — PromQL freshness/correctness check, run post-drain against
  `staging`'s Prometheus, polling `pipeline_consumer_lag` to baseline (condition-based, never a fixed
  sleep). Exits non-zero on either SLO miss.
- **CI wiring** — Smoke in the fast PR loop; Ramp/Soak/Spike on a nightly/pre-release/on-demand
  cadence, never per-PR. Runs `verify-async-slos.sh` after the load step; either failure blocks release.
- **`docs/quality/load-report.md`** — one entry per run: run id, profile, `staging` sizing, P95/P99
  and error rate per gate, backpressure outcome. Reviewable-by-Shafi, a pointer into the observability
  stack, never a duplicate data dump.
