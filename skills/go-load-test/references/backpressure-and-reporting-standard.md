# Backpressure/Circuit-Breaker Verification and Result-Reporting Standard

Full standard referenced from `SKILL.md`'s "Backpressure and Circuit-Breaker Verification" and
"Result-Reporting Standard" sections. Self-contained — reads without the parent body already in
context. Covers what a load test must prove about graceful degradation under organic overload
(distinct from `go-chaos-test`'s injected-fault verification of the same resilience patterns), and
how a load-test run's results are plumbed into the same OpenTelemetry/Prometheus/Grafana stack that
observes the running product — never a one-off HTML report nobody opens again.

---

## What "Graceful Degradation" Means and Why the Ramp Profile Proves It

Every service in this plugin ships two mechanisms specifically to survive more load than it can
fully serve: `go-middleware`'s per-subject `RateLimit` stage (a token bucket, default 10 req/s
sustained / burst 20, returning `429` with an exact `Retry-After` computed from
`rate.Reservation.Delay()`) at the ingress, and the **Circuit Breaker** (`integration-design`'s
Closed → Open → Half-Open pattern) guarding outbound calls to a saturating dependency such as the
Postgres connection pool. Both exist so the system **sheds or fails fast** under overload instead of
one of the two failure shapes a load test exists to catch:

| Failure shape | What it looks like | Why it's worse than shedding |
|---|---|---|
| **Total collapse** | Every request times out or 5xxs simultaneously; the process may OOM or crash | No request succeeds, including ones the system had capacity for moments earlier |
| **Silent unbounded queuing** | Requests accepted but queued indefinitely; latency climbs without bound, no error signals the caller | Callers wait on a system that will never answer in time; memory grows until OOM anyway, just later and less visibly |
| **Graceful degradation (the pass condition)** | Excess requests rejected fast (`429`) or a circuit opens and fails fast; accepted requests keep meeting SLO; the system recovers the instant load subsides | Callers get an immediate, actionable signal (back off, retry later) and the system never approaches OOM |

**The Ramp profile (`references/load-profile-standard.md`) is the experiment that proves which
shape occurs.** Its closed-model `ramping-vus` executor climbs offered load past the point the
system can serve everything — the deliberate design, not a flaw — and the assertions below run
against that same run's data.

---

## The Distinction from `go-chaos-test`: Organic Overload vs. Injected Fault

`go-chaos-test` proves a resilience pattern engages when a **specific, isolated dependency fault**
is deliberately injected via toxiproxy — e.g., 5 seconds of added Postgres latency, at otherwise
normal request volume, proving the Circuit Breaker's Closed→Open→Half-Open cycle in isolation. That
is a controlled, single-variable experiment. **This skill proves the same patterns engage when the
system's own request *volume* is the stressor** — no injected fault, no toxiproxy, just more real
traffic than the deployed replica count and connection-pool sizing can absorb. The two are
complementary, not overlapping: a system could pass `go-chaos-test`'s isolated-fault experiment
(the breaker opens correctly when Postgres is artificially slow) yet still collapse under organic
load if, say, the rate limiter's burst setting is too generous for the actual replica count — a gap
only a real volume ramp exposes. Neither skill substitutes for the other.

---

## Assertions the Ramp/Spike Profile Must Prove

```javascript
// load/scenarios/ramp.js — assertions appended to the scenario in references/load-profile-standard.md
export const options = {
  // ...scenario + SLO thresholds from references/slo-gate-standard.md...
  thresholds: {
    http_req_duration: ["p(99.5)<800"],
    http_req_failed:   ["rate<0.005"],
    // Backpressure assertions — evaluated only once offered load exceeds capacity (late-stage checks):
    "http_reqs{expected_response:true}": ["count>0"],      // accepted requests kept succeeding even at peak
  },
};

export default function () {
  const res = http.patch(/* ...classification call, references/load-profile-standard.md... */);
  check(res, {
    "not a 5xx (no total collapse)": (r) => r.status < 500,
    "429 carries Retry-After (shed, not silently queued)": (r) =>
      r.status !== 429 || r.headers["Retry-After"] !== undefined,
  });
}
```

Beyond k6's own request-level checks, the run is judged against telemetry gathered concurrently
(`opentelemetry-instrumentation`, queried via `prometheus-metrics-design`'s PromQL patterns):

| What must be true, once offered load exceeds capacity | PromQL / signal | Fail condition |
|---|---|---|
| Excess load sheds as `429`, not accepted and queued | `rate(http_server_requests_total{http_response_status_code="429"}[1m])` rises as offered load climbs past the limiter's rate | Zero `429`s ever observed despite offered load far exceeding the documented 10 req/s-per-subject bucket — the limiter isn't engaging |
| The Circuit Breaker opens if the Postgres pool saturates under real volume | `db_pool_in_use / db_pool_max` approaching 1 immediately followed by a fail-fast error rate rather than climbing latency | `http_req_duration` climbs into multi-second territory with no corresponding error spike — requests are queuing on a saturated pool instead of failing fast |
| The system recovers once load returns to baseline | `service:http_request_errors:ratio_rate5m` and `p99` both return to pre-Ramp baseline within minutes of the Ramp/Spike profile ending | Elevated error rate or latency persists after offered load has dropped — recovery, not just containment, is unproven |
| No unbounded memory growth under Soak | Pod memory (`container_memory_working_set_bytes`) plateaus rather than climbing monotonically across the 2-hour Soak window | Linear or accelerating memory growth — a leak, or unbounded queuing dressed up as "still working" |

A run that shows accepted requests holding their SLO *and* excess requests shedding fast *and*
memory/latency returning to baseline after the run ends is a pass. A run where either the accepted
traffic's SLO degrades silently, or nothing sheds and everything queues until timeouts cascade, is a
fail — regardless of what the raw `http_req_duration` average reports, since an average across a
shedding population hides exactly the two-population shape (fast-fail vs. slow-succeed) this section
exists to distinguish.

---

## Result-Reporting Standard: Into the Observability Stack, Not a One-Off Report

A load-test run's results live in the **same** OpenTelemetry/Prometheus/Grafana stack
(`opentelemetry-instrumentation`, `prometheus-metrics-design`) that observes the product in
production — not a static HTML file generated once and never opened again after the release it
gated.

**1. k6 metrics stream to Prometheus via the native remote-write output**, no separate collector:

```bash
k6 run --out experimental-prometheus-rw load/scenarios/soak.js \
  --env K6_PROMETHEUS_RW_SERVER_URL=http://staging-prometheus:9090/api/v1/write \
  --env BASE=https://staging.internal/compliance-engine
```

This writes k6's own metrics (`k6_http_req_duration`, `k6_http_reqs`, `k6_vus`, `k6_http_req_failed`)
into `staging`'s Prometheus as ordinary time series, queryable with the exact `histogram_quantile`
and `rate()` idioms `prometheus-metrics-design`'s PromQL Patterns table already teaches — a load
test's own client-side view sits next to the service's server-side RED metrics, so a p99 gap between
what k6 observed and what the service reported is itself a diagnostic signal (network/proxy latency
not visible server-side).

**2. A Grafana dashboard panel set, not a bespoke chart tool** — the same Grafana instance
`prometheus-metrics-design`'s scrape topology already deploys per tenant/environment gets a
`load-test` dashboard folder with: k6 `http_req_duration` percentiles overlaid on the service's own
`service:http_request_duration_seconds:p99_5m` recording rule (proving client- and server-side views
agree), `429` rate and `db_pool_in_use` ratio during the run (the backpressure assertions above,
visually), and `pipeline_consumer_lag` across the Spike burst and its drain. One dashboard, reused
run after run — never rebuilt per release.

**3. A Grafana annotation marks the run's start/end** on every dashboard the run's window
overlaps, via the Grafana HTTP Annotations API, so a reviewer looking at production dashboards weeks
later can see "a load-test run happened here" rather than mistaking a staging soak's traffic shape
for an unexplained anomaly:

```bash
curl -s -X POST "$GRAFANA_URL/api/annotations" \
  -H "Authorization: Bearer $GRAFANA_TOKEN" -H "Content-Type: application/json" \
  -d '{"text":"load-test: soak profile, staging","tags":["load-test","soak"],
       "time":'"$(date -d "$RUN_START" +%s000)"',"timeEnd":'"$(date +%s000)"'}'
```

**4. `docs/quality/load-report.md` stays, but as a pointer, not a data dump** — the run id, the
profile run, the Grafana dashboard link (with the time range pre-set to the run's window), the
pass/fail verdict per SLO gate (`references/slo-gate-standard.md`), and the backpressure assertions'
outcome. The durable record is the time series in Prometheus and the dashboard that reads it; the
Markdown file is the reviewable-by-Shafi summary CLAUDE.md's Artifact Standards require, not a
second copy of the data.
