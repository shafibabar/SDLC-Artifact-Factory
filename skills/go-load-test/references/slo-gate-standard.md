# SLO-Based Pass/Fail Gate Standard

Full standard referenced from `SKILL.md`'s "SLO-Based Pass/Fail Gate" section. Self-contained —
reads without the parent body already in context. Covers how this skill's k6 thresholds are derived
from `slo-definition`'s actual, already-established SLO numbers rather than invented, and how this
closes the exact loop `go-performance-test`'s `references/performance-budgets.md` deliberately left
open: that file's 5ms in-process handler-logic ceiling is stated there as "a build-time proxy,
narrower in scope than the 800ms SLO, and complementary to, never a substitute for, `go-load-test`'s
real-traffic measurement of the actual system p99." This file is that measurement.

---

## The Numbers Are `slo-definition`'s, Never Reinvented

Every threshold below is copied from `slo-definition`'s SLI table, not derived independently —
this skill verifies the targets that skill already set, exactly as `slo-definition`'s own Purpose
section states its chain: "`nfr-specification` states requirements → `slo-definition` formalises
SLIs/SLOs → `prometheus-metrics-design` computes the SLIs as recorded series → `alerting-rules-design`
pages on budget burn → `go-load-test` verifies the targets hold under peak load before release." A
load test that gates on a different latency or error-rate number than the one `slo-definition`
declared is testing against a fabricated target no operator agreed to.

| SLI (from `slo-definition`) | Target | k6/verification mechanism |
|---|---|---|
| ClassifyDataAsset command API — Availability (non-5xx / all requests) | **99.5%** | `http_req_failed: ["rate<0.005"]` |
| ClassifyDataAsset command API — Latency (requests completing < 800ms) | **99.5%** | `http_req_duration: ["p(99.5)<800"]` |
| Classification pipeline — Freshness (classified within 15 min of discovery) | **99%** | PromQL check against the pipeline freshness histogram — see below, not a k6 threshold |
| entity-extractor consumer — Correctness (`outcome="ok"`, not DLQ/error) | **99.9%** | PromQL check against `pipeline_dlq_depth`/`pipeline_documents_processed_total` — see below |

The 800ms/99.5% pair is also the exact boundary `prometheus-metrics-design`'s histogram-bucket
table already brackets for this same route (`ClassifyDataAsset via PATCH …/classification`, bucket
list `…, 0.5, **0.8**, 1, …`) — the load test's threshold, the recorded metric's bucket boundary,
and the SLO document's target are three expressions of one number, not three separately chosen ones.

---

## Closing `go-performance-test`'s Deferred-p99 Promise

`go-performance-test`'s tracked benchmark measures `ClassifyDataAssetHandler.Handle()` called
directly, in-process, against a fixture double — **never crossing a real network boundary inside
the timed loop**, by that skill's own determinism rule. Its 5ms ceiling covers only command
validation, Domain Primitive construction, business-rule evaluation, and the repository call through
its interface — explicitly **not** network transit, the Linkerd mTLS handshake, the full middleware
chain, or a real Postgres round-trip, all of which the 800ms SLO must also cover. That file states
plainly: those remaining stages are "`go-load-test`'s call to make against real measured system
behavior."

**This is that measurement.** The Ramp and Soak profiles (`references/load-profile-standard.md`)
drive real HTTP requests through the real deployed binary in `staging` — real network hop, real
mTLS, real middleware, real `pgx`-backed Postgres write, real outbox insert — and k6's
`http_req_duration` **is** the system p99 `slo-definition` set the 800ms target against. When a
load-test run passes its `p(99.5)<800` threshold, the loop is closed: the in-process 5ms proxy
caught what a benchmark can catch (handler-logic regressions), and this system-level measurement
proves the number that proxy could never produce on its own — the actual end-to-end p99, with every
I/O-bound stage included.

---

## Sync API Gate: k6 Thresholds

The `thresholds` block in every Ramp/Soak scenario file is the enforceable gate — a threshold
breach fails the k6 process's exit code, which the CI job below treats as a release blocker:

```javascript
export const options = {
  // ...scenario config, references/load-profile-standard.md...
  thresholds: {
    http_req_duration: ["p(99.5)<800"],   // slo-definition's Latency SLO, exactly
    http_req_failed:   ["rate<0.005"],    // slo-definition's Availability SLO, exactly
  },
};
```

```yaml
# .github/workflows/load-gate.yml (excerpt — pre-release / on-demand trigger)
- name: Run k6 load gate against staging
  run: |
    k6 run load/scenarios/ramp.js \
      --env BASE=https://staging.internal/compliance-engine \
      --env TOKEN="${{ secrets.LOAD_TEST_TOKEN }}" \
      --env ASSET="${{ env.SEED_ASSET_ID }}"
    # k6 exits non-zero on any breached threshold — this step's own exit code is the gate.
```

No separate pass/fail logic is hand-rolled in the workflow: k6's own threshold evaluation *is* the
gate, the same "the tool's own exit code is the verdict" discipline `go-performance-test`'s
`benchstat`-against-baseline gate already practices for benchmarks.

---

## Async Pipeline Gate: PromQL, Not k6 Thresholds

Freshness and correctness are **not** synchronous request/response measurements — no HTTP call in
a k6 script waits 15 minutes for a classification to complete. These two SLIs are read from the
same Prometheus series `alerting-rules-design` and `slo-definition` already compute, queried
**after** the Spike/Soak profile's batch has had time to drain:

```promql
# Freshness: fraction of DataAssets classified within the 15-minute deadline, over the load-test window
sum(increase(pipeline_freshness_seconds_bucket{le="900"}[2h]))
/
sum(increase(pipeline_freshness_seconds_count[2h]))
# PASS: >= 0.99 (slo-definition's Freshness SLO)

# Correctness: fraction of documents NOT landing in the DLQ or failing validation, over the same window
1 - (
  sum(increase(pipeline_dlq_depth[2h]))
  /
  sum(increase(pipeline_documents_processed_total[2h]))
)
# PASS: >= 0.999 (slo-definition's Correctness SLO)
```

A load-test run script (`load/verify-async-slos.sh`) runs these two queries against the `staging`
Prometheus instance once the batch has drained (poll `pipeline_consumer_lag` back to its pre-burst
baseline, condition-based, never a fixed sleep — the identical wait discipline `go-e2e-test` already
mandates) and exits non-zero if either falls under target, so the async half of the gate is as
mechanical and CI-enforceable as the k6 threshold check for the sync half.

---

## Why the SLO Window Differs from a Single Load-Test Run

`slo-definition`'s targets are stated over a **rolling 28-day window** — a single 2-hour Soak run
cannot, by construction, prove a 28-day figure. The gate's actual claim is narrower and precise:
*at this offered load, over this run's window, the SLI met or exceeded the 28-day target rate.* A
single passing run is evidence the target is achievable under realistic load, not a substitute for
the live 28-day burn-rate tracking `alerting-rules-design` performs continuously in production. State
this distinction in every load-report output (`SKILL.md`'s Output Format) so a reader does not
mistake one passing pre-release run for a permanent guarantee.
