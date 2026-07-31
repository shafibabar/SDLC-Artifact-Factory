# SLO-Tied Pass/Fail, Reading the Results, and Capacity Findings

Full standard referenced from `SKILL.md`'s "Closed vs. Open Workload Model", "SLO-Based Pass/Fail
Gate", and "Backpressure Under Organic Overload" sections. Self-contained — reads without the parent
body in context. Covers how the pass thresholds are derived from `slo-definition`'s actual numbers
(never invented), why the result must be read as percentiles rather than a mean, how the open-model
choice changes what a rate claim means, how the sync gate and the async gate are enforced
mechanically, what graceful degradation must look like under organic overload, and how a run's
capacity number is stated so it is not mistaken for a production guarantee.

---

## The Numbers Are `slo-definition`'s, Never Reinvented

Every threshold below is copied from `slo-definition`, which formalizes the requirements
`nfr-specification` states — this skill *verifies targets an operator already agreed to*, it does not
derive new ones. A load test that gates on a different latency or error-rate number than the SLO
document declared is testing against a fabricated target no one signed off on.

| SLI (from `slo-definition`) | Target | Verification mechanism |
|---|---|---|
| ClassifyDataAsset command API — Availability (non-5xx / all) | **99.5%** | Error rate < 0.005 over the run (locust `Failures` / `Requests`; k6 `http_req_failed: rate<0.005`) |
| ClassifyDataAsset command API — Latency (requests under 800ms) | **99.5%** | P99.5 < 800ms on the named `PATCH …/classification` statistic (locust CSV percentile column; k6 `http_req_duration: p(99.5)<800`) |
| Classification pipeline — Freshness (classified within 15 min of discovery) | **99%** | PromQL against the freshness histogram, post-drain — not a synchronous request measurement |
| entity-extractor consumer — Correctness (`outcome="ok"`, not DLQ/error) | **99.9%** | PromQL against `pipeline_dlq_depth` / `pipeline_documents_processed_total`, post-drain |

The 800ms/99.5% pair is the same boundary `prometheus-metrics-design`'s histogram-bucket table
already brackets for this route — the load-test threshold, the recorded metric's bucket boundary, and
the SLO document's target are three expressions of one number, not three separately chosen ones.

---

## Read Percentiles, Never the Mean

**The mean latency is worse than useless under load — it actively hides the failure the SLO exists to
catch.** Once a service begins shedding, its response population splits in two: fast `429`/fail-fast
rejections and slower successful responses. An average across that bimodal population lands in a
valley between the two humps, describing no real request, and it drowns the P99 tail — the exact
number the 800ms SLO is written against — under a mass of fast rejections. Always read and gate on
**percentiles**: P50 for the typical experience, **P95 and P99 for the tail the SLO governs**, and the
max for the worst case. locust reports these per named statistic (in the web UI and the `--csv`
output); k6 exposes them via `http_req_duration` percentile thresholds. If a report shows a mean
latency and calls the run green, the run was not analyzed — it was glanced at.

A concrete failure this catches: a run whose *mean* is a comfortable 120ms but whose P99 is 2.3s is a
**failing** run — one request in a hundred is missing the 800ms SLO by nearly 3×, and those are the
requests a real reviewer notices and complains about. The mean concealed it; the P99 exposed it.

---

## What the Open-Model Choice Changes About a Rate Claim

A **closed** model (locust's default `wait_time`, k6's `ramping-vus`) understates tail latency under
load because offered load drops when the service slows — real users don't wait. An **open** model
(locust's `constant_throughput`, k6's `constant-arrival-rate`) holds the arrival rate regardless of
response time. **Use the open model for any profile making a rate-based SLO claim** ("holds 30
req/s"); **use the closed model only for Ramp**, where letting offered load throttle naturally is the
point — it finds the break. State the model per profile in the report: a rate claim made under a
closed model is not wrong so much as *understated*, and a reviewer must know which they are reading.

---

## Sync Gate: Mechanical, Not Hand-Judged

The run's exit code is the gate, not a human reading a chart. With k6, the `thresholds` block fails
the process exit code the moment a threshold breaches. With locust, `--headless` plus a small
post-run check over the CSV gives the same enforceability:

```bash
# load/verify-sync-slos.sh — runs after a headless locust run, exits non-zero on any breach.
set -euo pipefail
STATS="load/results/ramp_stats.csv"    # locust --csv output

# Column: the aggregated row's 99% and failure count. Fail the gate if either SLO is missed.
python3 - "$STATS" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1])))
agg = next(r for r in rows if r["Name"] == "PATCH /v1/data-assets/{id}/classification")
p99 = float(agg["99%"])                                  # milliseconds
error_rate = int(agg["Failure Count"]) / max(int(agg["Request Count"]), 1)
ok = p99 < 800 and error_rate < 0.005                    # slo-definition's exact numbers
print(f"P99={p99}ms error_rate={error_rate:.4f} -> {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PY
```

No pass/fail logic is invented in the workflow — the tool's own numbers, checked against
`slo-definition`'s exact targets, are the verdict.

---

## Async Gate: PromQL, Post-Drain, Not a Load-Client Measurement

Freshness and correctness are **not** synchronous request/response measurements — no load request
waits 15 minutes for a classification to complete. These two SLIs are read from the same Prometheus
series `prometheus-metrics-design` already computes, queried **after** the Spike/Soak batch has
drained (poll `pipeline_consumer_lag` back to its pre-burst baseline — condition-based, never a fixed
sleep):

```promql
# Freshness: fraction of DataAssets classified within the 15-minute deadline, over the run window.
sum(increase(pipeline_freshness_seconds_bucket{le="900"}[2h]))
/
sum(increase(pipeline_freshness_seconds_count[2h]))
# PASS: >= 0.99  (slo-definition's Freshness SLO)

# Correctness: fraction of documents NOT landing in the DLQ or failing validation, same window.
1 - (
  sum(increase(pipeline_dlq_depth[2h]))
  /
  sum(increase(pipeline_documents_processed_total[2h]))
)
# PASS: >= 0.999  (slo-definition's Correctness SLO)
```

`load/verify-async-slos.sh` runs these against `staging`'s Prometheus once the batch has drained and
exits non-zero if either falls under target — so the async half of the gate is as mechanical and
CI-enforceable as the sync half. A green sync run with an undrained pipeline is a failing system on a
delay timer; the async gate is what catches it.

---

## Backpressure Under Organic Overload: The Pass Shape

The Ramp/Spike profiles push offered load past capacity on purpose. Three failure shapes are
possible; only one is a pass:

| Shape | What it looks like | Verdict |
|---|---|---|
| **Total collapse** | Every request 5xxs or times out at once; the `uvicorn` workers OOM or the event loop stalls | **Fail** — no request succeeds, including ones the service had capacity for moments earlier |
| **Silent unbounded queuing** | Requests accepted but coroutines pile up awaiting a saturated `asyncpg` pool; latency climbs without bound, no error signals the caller; memory grows monotonically | **Fail** — callers wait on a system that will never answer in time; OOM arrives later and less visibly |
| **Graceful degradation** | Excess sheds fast as `429` + `Retry-After` (`python-middleware`'s limiter) or a Circuit Breaker opens on the saturating pool; accepted requests keep meeting SLO; error rate and P99 return to baseline the instant load subsides | **Pass** — the caller gets an actionable signal and the service never approaches OOM |

This is organic-overload verification and is **distinct from `python-chaos-test`**, which proves the
same resilience patterns under a deliberately injected `toxiproxy` fault at normal volume. A service
could pass the injected-fault experiment yet still collapse under organic load if, say, the rate
limiter's burst is too generous for the actual replica count — a gap only a real volume ramp exposes.
Neither substitutes for the other. Assert, once offered load exceeds capacity:

- `rate(http_server_requests_total{http_response_status_code="429"}[1m])` **rises** as offered load
  climbs past the limiter's documented per-subject rate. Zero `429`s ever, despite far exceeding it,
  means the limiter is not engaging.
- `db_pool_in_use / db_pool_max` approaching 1 is **immediately** followed by a fail-fast error rate,
  not by `http` latency climbing into multi-second territory — the latter means coroutines are
  queuing on a saturated pool instead of failing fast.
- After the profile ends, error rate and P99 **return to baseline within minutes** — recovery, not
  just containment, is unproven if elevation persists.
- Pod memory (`container_memory_working_set_bytes`) **plateaus** across the 2-hour Soak rather than
  climbing monotonically — linear growth is a leak, or unbounded queuing dressed up as "still working."

---

## Capacity Findings: State the Sizing, Never Claim a Production Guarantee

`slo-definition`'s targets are stated over a **rolling 28-day window** — a single 2-hour Soak run
cannot prove a 28-day figure. The gate's actual claim is narrower and precise: *at this offered load,
over this run's window, against this `staging` sizing, the SLI met or exceeded the 28-day target
rate.* Because `staging` runs at **reduced sizing** relative to production (a legitimate, declared
`environment-config` difference), every capacity finding in `docs/quality/load-report.md` states the
replica counts, `asyncpg`-pool sizes, and resource requests the run used, so a reader can scale the
observed ceiling toward production sizing rather than mistake a staging number for a production
promise. A single passing run is evidence the target is *achievable* under realistic load — not a
substitute for the live burn-rate tracking `alerting-rules-design` performs continuously in
production.
