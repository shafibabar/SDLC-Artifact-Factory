---
name: go-load-test
description: >
  Teaches system-level load and stress testing — using k6 (or vegeta) to drive
  realistic traffic against the running service, measuring latency percentiles,
  throughput, and error rate, verifying Service Level Objectives under sustained
  and peak load, observing resource saturation (CPU, memory, pool, consumer lag)
  via the existing telemetry, and the load-test profiles (smoke/load/stress/soak/
  spike). The shift-right validation that the system holds up under real pressure.
  Used by the test-strategist during Quality.
version: 1.1.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, load-test, k6, slo, throughput, latency, saturation, shift-right]
---

# Go Load Test

## Purpose

Unit and integration tests prove correctness; they say nothing about behaviour under a thousand concurrent users. Load testing answers the operational questions: How many requests per second can it serve? What's the p99 latency at peak? When does it start shedding errors? Does it stay within its SLOs? Where does it saturate first? These only emerge under real, sustained traffic — load testing is the **shift-right** validation that the system holds up in production-like conditions.

This validates the Service Level Objectives the NFR specification sets and the `slo-definition` skill formalises, using the RED/USE telemetry the services already emit (`opentelemetry-instrumentation`).

---

## Tooling — Frugal and Open Source

| Tool | Style | Use |
|---|---|---|
| **k6** | Scriptable (JS), rich metrics, thresholds-as-pass/fail | **Default** — realistic scenarios, SLO assertions built in |
| **vegeta** | Simple constant-rate HTTP, Go-native | Quick throughput/latency checks; library-embeddable in Go |

Default to **k6**: it expresses load profiles and SLO thresholds declaratively and fails the run when an SLO is breached — turning a load test into a pass/fail gate, not just a report. Both are open-source and self-hosted (no SaaS load service — frugal).

---

## Load Profiles

Different questions need different traffic shapes:

| Profile | Shape | Answers |
|---|---|---|
| **Smoke** | Minimal load, short | Does it work under any load at all? (cheap pre-check) |
| **Load** | Expected peak, sustained | Does it meet SLOs at the expected busy-hour traffic? |
| **Stress** | Ramp beyond peak until it breaks | Where is the breaking point? How does it fail? |
| **Soak** | Moderate load, hours | Memory leaks, resource exhaustion, slow degradation over time |
| **Spike** | Sudden sharp surge | Does it survive and recover from a traffic spike? |

Run **smoke** in CI on every change (fast); run **load/stress/soak/spike** on a schedule and before a release (they take minutes to hours).

---

## A k6 Scenario with SLO Thresholds

The SLOs are encoded as k6 `thresholds` — if latency or error rate breaches them, the run **fails**.

```javascript
// load/classify.js
import http from "k6/http";
import { check } from "k6";

export const options = {
  scenarios: {
    load: { executor: "ramping-vus", stages: [
      { duration: "1m", target: 200 },   // ramp to 200 virtual users
      { duration: "5m", target: 200 },   // hold at peak
      { duration: "1m", target: 0 },     // ramp down
    ]},
  },
  thresholds: {                          // SLOs as pass/fail gates
    http_req_duration: ["p(95)<300", "p(99)<800"],  // p95 < 300ms, p99 < 800ms
    http_req_failed:   ["rate<0.01"],                // error rate < 1%
  },
};

export default function () {
  const res = http.patch(`${__ENV.BASE}/v1/data-assets/${__ENV.ASSET}/classification`,
    JSON.stringify({ sensitivityLevel: "Confidential" }),
    { headers: { Authorization: `Bearer ${__ENV.TOKEN}`, "Content-Type": "application/json" } });
  check(res, { "is 2xx/4xx (not 5xx)": (r) => r.status < 500 });
}
```

---

## Measure the Four Golden Signals

A load run reports — and gates on — the signals that define user-perceived health:

| Signal | Source | SLO example |
|---|---|---|
| **Latency** | k6 `http_req_duration` percentiles | p95 < 300ms, p99 < 800ms |
| **Traffic** | Achieved requests/sec | sustain N rps |
| **Errors** | `http_req_failed` rate | < 1% |
| **Saturation** | The service's USE telemetry during the run | pool/CPU/lag below limits |

**Latency is read as percentiles, never averages** — an average hides the tail, and the tail is what users feel. p95/p99 are the SLO targets.

One modelling caveat: `ramping-vus` is a **closed** workload model — each virtual user waits for its response before sending the next request, so when the service slows down, the offered load quietly drops and tail latency is understated (coordinated omission). For SLO verification at a target rate, prefer k6's **open-model** executors (`constant-arrival-rate` / `ramping-arrival-rate`), which keep sending at the intended rate regardless of response times — like real users do. Use closed VU ramps for stress profiles where finding the breaking point is the goal.

---

## Observe Saturation via Existing Telemetry

A load test is also an observability test: while k6 drives traffic, watch the service's **USE metrics** (`opentelemetry-instrumentation`) — DB pool utilisation, CPU/memory, consumer lag — to find what saturates first. The bottleneck the stress profile reveals (e.g., pool exhaustion at 250 VUs) is the next scaling or tuning target, and confirms the alerts (`alerting-rules-design`) actually fire under real pressure.

For the async pipeline, load is applied at ingestion and **consumer lag** is the key saturation signal — the pipeline must drain at the rate it's filled, or backpressure must engage gracefully (`data-pipeline-design`).

---

## Environment and Safety

- Run against a **production-like environment** (the platform-engineer's ephemeral/staging stack) — never production, never a laptop (laptop numbers are meaningless for capacity).
- Size the environment like production so results extrapolate.
- Load tests generate real data — run against an **isolated tenant/environment** that is torn down after.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| SLOs gated | Thresholds encode SLOs; breach fails the run | Load test that only prints numbers |
| Percentile latency | p95/p99 measured and targeted | Averages reported; tail ignored |
| Profile coverage | Smoke in CI; load/stress/soak/spike scheduled | Only a single ad-hoc run |
| Saturation observed | USE metrics watched; first bottleneck identified | Throughput measured with no resource insight |
| Pipeline lag | Async load checks consumer lag/backpressure | Only sync endpoints load-tested |
| Realistic env | Production-like, isolated, torn down | Laptop/uneven env; or against production |
| Frugal tooling | Self-hosted k6/vegeta | A paid SaaS load platform |

---

## Anti-Patterns

- **Reporting averages** — mean latency at p50-ish traffic hides the p99 tail where SLOs are actually breached.
- **Closed-model VU ramps for rate-based SLOs** — coordinated omission flatters the numbers; use arrival-rate executors when the question is "does it meet SLOs at N rps".
- **Load-testing on a laptop** — the numbers describe the laptop, not the system; capacity claims from non-production-like hardware are noise.
- **Load-testing production** — real users become the blast radius; use the isolated production-like stack.
- **A single heroic run before launch** — performance regresses gradually; smoke in CI plus scheduled full profiles catch the drift.
- **Ignoring the async half** — a green HTTP load test with a growing consumer lag is a failing system on a delay timer.
- **Unrealistic traffic mix** — hammering one endpoint with one payload measures the cache, not the service; model the journey mix.

---

## Output Format

Produces load scripts, profiles, and the SLO report:

```
load/*.js                          (k6 scenarios with SLO thresholds)
load/profiles/{smoke,load,stress,soak,spike}.js
.github/workflows/load-smoke.yml    (smoke in CI; full profiles scheduled)
docs/quality/load-report.md         (percentiles, throughput, saturation findings vs SLOs)
```
