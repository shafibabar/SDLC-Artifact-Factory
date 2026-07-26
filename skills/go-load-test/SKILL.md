---
name: go-load-test
description: >
  Teaches this plugin's system-level load-testing standard for Go services —
  the shift-right proof that the deployed system holds up under real,
  sustained pressure, distinct from go-performance-test's in-process
  benchmark proxy. Covers the k6 tool standard (open-source, frugal, a
  black-box external traffic generator — never ported to Go code); the
  staging-environment standard, deliberately different from go-e2e-test's
  ephemeral kind cluster (references/load-profile-standard.md, which also
  covers ramp/soak/spike profiles with concrete parameters for the
  data-estate platform's bursty, batch-driven traffic shape and the
  open-vs-closed workload-model choice); the SLO-based pass/fail gate using
  slo-definition's actual 800ms/99.5% latency-availability numbers and 99%
  freshness/99.9% correctness targets, closing the real end-to-end p99 loop
  go-performance-test's 5ms in-process budget deliberately deferred here
  (references/slo-gate-standard.md); and the backpressure/Circuit-Breaker
  verification standard proving graceful degradation (429 shedding, breaker
  opening) under organic overload, distinct from go-chaos-test's injected-
  fault verification of the same patterns, plus the result-reporting
  standard wiring k6 output into the OpenTelemetry/Prometheus/Grafana stack
  (references/backpressure-and-reporting-standard.md). Used by the
  test-strategist during Quality.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, load-test, k6, slo, throughput, latency, backpressure, circuit-breaker, shift-right]
related: [go-performance-test, go-chaos-test, slo-definition, prometheus-metrics-design, integration-design, go-middleware, environment-config, go-e2e-test]
---

# Go Load Test

## Purpose

Unit, integration, and even `go-performance-test`'s gated in-process benchmark say nothing about
behaviour under real, sustained traffic against the fully deployed system. Load testing answers what
those layers structurally cannot: real requests/sec, real p99 under network/mTLS/pool overhead, when
the system starts shedding, and whether it holds the Service Level Objectives `slo-definition` set —
the **shift-right** proof that closes the gap between "the handler's own logic is fast" and "the
system holds up in production-like conditions." Authored and run by the test-strategist during Quality.

---

## Tool Standard: k6, Open-Source, a Black-Box External Generator

**k6** (Grafana Labs, Apache-2.0) is the default: its `thresholds` DSL turns a run into a pass/fail
gate, not a report to interpret, and it is self-hosted — no k6 Cloud SaaS, per CLAUDE.md's frugality
constraint. **k6 is scripted in JavaScript and that is not a departure from this plugin's Go-first
stack** — it runs entirely outside the target service, like `curl`, driving traffic at a Go binary it
never imports; the "Go" in this skill's scope names the *system under test*, never the generator's
language. `vegeta` (Go-native, constant-rate) is a fine dev-time spot-check, not the CI-gated
standard. Full comparison and frugality reasoning: `references/load-profile-standard.md`.

---

## Environment Standard: `staging`, Deliberately Not `go-e2e-test`'s `kind` Cluster

`go-e2e-test` runs its journeys against an ephemeral `kind` cluster — correct there, since it proves
deployment *shape*, which a single-node, shared-machine cluster does fine. **Load testing proves
*capacity*, and a shared-machine `kind` cluster cannot produce a meaningful capacity number** — host
scheduler contention corrupts the exact thing being measured. This skill runs against **`staging`**
instead — `environment-config`'s own environment, purpose-built for "full-stack soak: nightly
e2e/load suites, SLO soak," "mirrors production topology at reduced sizing." Same chart, same digest
(Environment Parity); reduced sizing declared in every report, never mistaken for a production
guarantee; one `staging`, never production. Full comparison table: `references/load-profile-standard.md`.

---

## Load-Profile Standard: Ramp, Soak, Spike — Sized to This Platform's Traffic Shape

Real traffic here is bursty, not a smooth ramp: `estate-scanner`'s discovery sweeps enqueue
thousands of documents in seconds, which the async pipeline absorbs as a burst, while
`ClassifyDataAsset` sees low, steady interactive volume. Every profile is parameterized against that
shape:

| Profile | Shape | This platform's parameters |
|---|---|---|
| **Smoke** | 1 VU, ~1 min | Fast CI pre-check; every change |
| **Ramp** | Closed-model climb past capacity | 0→50 VUs/2min, hold 5min, 50→500/5min until breach |
| **Soak** | Open-model sustained, hours | 30 req/s sync + 500 docs/min pipeline feed, held 2 hours |
| **Spike** | Sudden batch burst | 30 req/s baseline + a 10,000-document burst in under 60s |

Open-model executors (`constant-arrival-rate`/`ramping-arrival-rate`) answer "does it hold N req/s"
(Soak, Spike's baseline); closed `ramping-vus` is used only for Ramp, where letting offered load
throttle naturally finds the break. Traffic is always a journey mix, never one endpoint hammered with
one payload. Full k6 structure and the workload-model reasoning: `references/load-profile-standard.md`.

---

## SLO-Based Pass/Fail Gate: `slo-definition`'s Real Numbers, Not Invented Ones

Every threshold is copied from `slo-definition`, never independently derived: **availability 99.5%**
(`http_req_failed: rate<0.005`), **latency 99.5% under 800ms** (`http_req_duration: p(99.5)<800`),
**pipeline freshness 99% within 15 min**, **consumer correctness 99.9%** — the latter two verified
via PromQL against series `slo-definition`/`prometheus-metrics-design` already compute, post-drain,
not as k6 thresholds. **This is the measurement `go-performance-test`'s `performance-budgets.md`
deliberately deferred**: its 5ms handler-logic ceiling excludes network transit, the mTLS handshake,
middleware, and the real Postgres round-trip by design, naming those "`go-load-test`'s call to make
against real measured system behavior." A passing `p(99.5)<800` against the real deployed system in
`staging` **is** that system p99 — the loop closes here. Full gate, CI job, async PromQL, and why one
run's window differs from the rolling-28-day SLO claim: `references/slo-gate-standard.md`.

---

## Backpressure and Circuit-Breaker Verification

A load test must prove the system **degrades gracefully** under organic overload — sheds load fast
(`go-middleware`'s token-bucket `RateLimit`, `429` with `Retry-After`) or opens a Circuit Breaker
(`integration-design`) on a saturating dependency — rather than collapsing or silently queuing until
OOM. **This is distinct from `go-chaos-test`**, which proves the same patterns under a deliberately
injected, isolated fault at normal volume; this skill proves they engage when the stressor is the
system's own request *volume* — complementary, neither a substitute. Ramp/Spike assert: `429`s rise
as offered load exceeds the limiter's rate, the saturated path fails fast rather than queuing into
climbing latency, error rate and p99 return to baseline once load subsides, and memory does not grow
unbounded across Soak. Full assertions and the two disqualifying failure shapes (total collapse,
silent unbounded queuing): `references/backpressure-and-reporting-standard.md`.

---

## Result-Reporting Standard: Into the Observability Stack, Not a One-Off Report

Results are plumbed into the **same** OpenTelemetry/Prometheus/Grafana stack that observes the
product in production: k6's metrics stream to `staging`'s Prometheus via the native remote-write
output, a reused Grafana dashboard overlays the client-side k6 view against the service's own RED
recording rules and backpressure signals, and a Grafana annotation marks the run's window so a later
reviewer sees "a load test happened here," not an anomaly. `docs/quality/load-report.md` is a
reviewable-by-Shafi pointer (run id, dashboard link, verdict per gate) — never a second data copy.
Full plumbing and dashboard contents: `references/backpressure-and-reporting-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| SLOs gated on real numbers | Thresholds copied from `slo-definition`; breach fails the run | Invented targets, or numbers drifting from the SLO document |
| Percentile latency, real system p99 | p99.5 thresholded against the real deployed system; closes `go-performance-test`'s deferred proxy | Averages reported; only the in-process 5ms proxy ever checked |
| Async SLOs verified | Freshness/correctness checked via PromQL post-drain | Only sync endpoints load-tested; pipeline lag ignored |
| Environment correct | `staging`, production-shaped, sized and declared | `kind` cluster or a laptop; non-representative capacity claims |
| Profile coverage, workload model | Smoke in CI; Ramp/Soak/Spike scheduled with real parameters; open-model for rate SLOs, closed only to find the break | Ad-hoc run; generic parameters; coordinated omission on a rate claim |
| Backpressure proven, distinct from chaos | `429`/breaker engages under organic volume with recovery; not duplicating `go-chaos-test`'s injected-fault experiments | Total collapse or silent queuing; conflated with chaos testing |
| Realistic traffic mix | Journey-mix endpoints and payload variety | One endpoint, one payload — measures a cache |
| Results in the observability stack | k6 → Prometheus remote-write → Grafana + annotation | A static report nobody opens again |
| Frugal tooling | Self-hosted k6/vegeta | A paid SaaS load platform |

---

## Anti-Patterns

- **Reporting averages** — hides the p99 tail the SLO is written against.
- **Closed-model executors for a rate-based SLO claim** — coordinated omission understates real tail latency.
- **Load-testing a shared-machine `kind` cluster, or a laptop** — numbers describe host contention, not system capacity.
- **Load-testing production** — real tenants become the blast radius; `staging` exists to absorb this.
- **Inventing SLO numbers instead of copying `slo-definition`'s** — proves nothing an operator agreed to.
- **Treating this skill's job as `go-chaos-test`'s** — organic-overload and injected-fault are complementary, not interchangeable.
- **A single heroic pre-launch run** — capacity regresses gradually; smoke in CI plus scheduled profiles catch drift.
- **Ignoring the async half** — a green sync run with an undrained pipeline burst is a failing system on a delay timer.
- **A one-off HTML report** — results that never reach Prometheus/Grafana are invisible next time.

---

## Output Format

- **`load/scenarios/{smoke,ramp,soak,spike}.js`** — k6 files, one per profile, each carrying the
  `slo-definition`-derived `thresholds` and backpressure `check()`s (`429` + `Retry-After`, never a
  bare status check). Journey-mix traffic. Executor model chosen per the rule in
  `references/load-profile-standard.md`, never defaulted without stating why.
- **`load/verify-async-slos.sh`** — PromQL freshness/correctness check, run post-drain against
  `staging`'s Prometheus, polling `pipeline_consumer_lag` to baseline (condition-based, never a fixed
  sleep). Exits non-zero on either SLO miss — same enforceability as k6's threshold exit code.
- **`.github/workflows/load-smoke.yml`** — Smoke in the fast PR loop.
- **`.github/workflows/load-gate.yml`** — Ramp/Soak/Spike on the nightly/pre-release/on-demand
  cadence `go-e2e-test`'s CI-Placement standard establishes; never per-PR. Runs
  `verify-async-slos.sh` after the k6 step; either failure blocks the release.
- **Grafana `load-test` dashboard folder** (provisioned once, reused) — k6 percentiles over the
  service's RED recording rules, `429` rate, `db_pool_in_use`, `pipeline_consumer_lag`, annotated
  per run via the Annotations API.
- **`docs/quality/load-report.md`** — one entry per run: run id, profile, `staging` sizing, dashboard
  link, pass/fail per gate, backpressure outcome. A pointer into the stack, never a duplicate dump.
