# Load-Profile and Tool Standard

Full standard referenced from `SKILL.md`'s "Tool Standard" and "Load-Profile Standard" sections.
Self-contained — reads without the parent body already in context. Covers why k6 is the default
tool and what it is (and is not) in this plugin's Go-centric context, why load tests run against a
production-shaped `staging` environment rather than an ephemeral `kind` cluster, and the four load
profiles with concrete parameters derived from the data-estate-mapping platform's actual traffic
shape — not generic web-traffic defaults.

---

## Tool Standard: k6 as a Black-Box External Load Generator

**k6 is scripted in JavaScript. This is not a departure from the plugin's Go-first tech-stack
default — k6 is a black-box HTTP/gRPC traffic generator that runs *outside* the target service
entirely, the same way `curl` or `ab` would, and its own implementation language is irrelevant to
what it tests.** The "Go" in this skill's context is the *target system under test* (a `chi`
handler, a `pgx`-backed repository, an outbox relay) — never the tool driving traffic at it. Do not
port k6 scripts to Go; k6's scenario/threshold DSL is purpose-built for this job and reimplementing
it in Go would duplicate a mature open-source tool for no benefit.

| Tool | Style | Use | Frugality |
|---|---|---|---|
| **k6** (Grafana Labs, Apache-2.0) | Scriptable scenarios, built-in percentile metrics, thresholds evaluated as pass/fail | **Default** — every profile in this standard | Self-hosted binary or container; k6 Cloud (the paid SaaS tier) is explicitly **not used** — CLAUDE.md's frugality constraint forbids it and every capability this skill needs (scenarios, thresholds, Prometheus output) ships in the open-source binary |
| **vegeta** (Go-native) | Simple constant-rate HTTP attack, library-embeddable | Ad hoc throughput/latency spot-checks during development; not the CI-gated standard | Open-source, self-hosted |

k6 is the default because it turns a load test into a **pass/fail gate**, not a report someone has
to interpret: `thresholds` in the `options` block fail the process's exit code the moment an SLO
breaches, which is what lets the CI-Placement standard (below) block a release on a real SLO
regression rather than relying on a human reading a chart. Install as a static binary in CI (no
package-manager dependency chain) or the official `grafana/k6` container image for a Kubernetes
`Job` — both are self-hosted, no external service call, no license cost.

---

## Environment Standard: `staging`, Not an Ephemeral `kind` Cluster

`go-e2e-test`'s environment standard (`references/environment-provisioning-standard.md`) uses an
ephemeral `kind` cluster created and destroyed per CI run. **Load testing needs a different
environment for a reason specific to what each test proves**, not because one standard is more
rigorous than the other:

| | `go-e2e-test`'s `kind` cluster | `go-load-test`'s environment (this skill) |
|---|---|---|
| Proves | The deployment *shape* is correct — Helm charts render right, NetworkPolicy doesn't silently block a call, Linkerd mTLS handshakes complete, ingress routes resolve | The system's *capacity* — how many requests/sec it serves, what its real p99 is, where it saturates |
| A single-node, shared-machine cluster | **Sufficient** — correctness of a route or a policy doesn't depend on how much spare CPU the host has | **Meaningless** — CPU/scheduler contention from every other process on the CI runner's host directly corrupts the one thing being measured: latency and throughput under load |
| Sizing that matters | None — one Pod answering one request proves the policy works | Everything — replica counts, resource requests/limits, connection-pool sizes must resemble production or the numbers describe the test rig, not the system |

`environment-config` (this repo's Environment Parity authority) names exactly the environment this
skill needs: **`staging`** — "Full-stack soak: nightly e2e/load suites, SLO soak, rollback and DR
drills," "Long-lived; mirrors production topology at reduced sizing." Load tests run here, not
against `kind-local` and never against a `tenant-<id>` production stamp:

- **Same chart, same digest** as the release candidate — Environment Parity — so throughput and
  latency numbers describe the artifact that will actually ship, not a rebuild of it.
- **Reduced sizing relative to production** is a legitimate, declared difference (`environment-config`'s
  Sizing/Replicas difference classes) — state the replica counts and resource requests the load run
  used in the result report (below) so a reader can scale the observed ceiling toward production
  sizing rather than mistake a staging number for a production guarantee.
- **One `staging`, not one per tenant** — the same one-staging-suffices reasoning `environment-config`
  already establishes; a synthetic load-test tenant identity is used (the same `tenant.id` override
  class `go-e2e-test` uses), never a real customer's isolated production stamp.
- **Never production** — real customer tenants are the blast radius; `staging`'s whole purpose is
  absorbing exactly this kind of destructive, resource-intensive rehearsal before a release earns
  production traffic.

---

## Load Profiles — Concrete Parameters for This Platform's Traffic Shape

The data-estate-mapping platform's real traffic is not a smooth Poisson arrival process: interactive
`ClassifyDataAsset` command-API calls from human reviewers are relatively low, steady volume, while
`estate-scanner`'s discovery sweeps enqueue **batches** of documents that `entity-extractor` and
`compliance-engine` then process as a burst through the async pipeline — a scheduled scan of a large
Google Drive/S3 source can enqueue thousands of documents in seconds. Every profile below models
this bursty, batch-driven shape rather than a generic smooth-ramp web-traffic default.

| Profile | Shape | Concrete parameters (this platform) | Answers |
|---|---|---|---|
| **Smoke** | Minimal load, ~1 min | 1 VU, 20 iterations against `ClassifyDataAsset` | Does it work under any load at all? (fast CI pre-check) |
| **Ramp** | Steady climb past expected peak until it breaks | `ramping-vus`: 0→50 over 2 min, hold 50 for 5 min (expected daytime reviewer concurrency), then 50→500 over 5 min until thresholds breach | Where is the breaking point, and how does it fail? |
| **Soak** | Sustained moderate load, hours | `constant-arrival-rate`: 30 requests/sec sustained for **2 hours** at the command API, concurrently with a steady 500-document/min feed into the async pipeline | Memory leaks, connection-pool exhaustion, outbox-table growth, consumer-lag drift that only appear over time |
| **Spike** | Sudden, sharp burst mirroring a real batch scan | Baseline 30 req/s on the command API, then a **10,000-document burst** enqueued to the pipeline in under 60 seconds (simulating a large source's discovery sweep completing), sustained baseline continues throughout | Does autoscaling/backpressure engage and recover, or does the burst cascade into the sync API's own degradation? |

Run **smoke** in CI on every change (seconds, cheap). Run **ramp/soak/spike** on a schedule and
before every release (each takes minutes to hours and needs the `staging` environment above) — see
`SKILL.md`'s CI-placement note, which follows the identical nightly/pre-release/on-demand cadence
`go-e2e-test`'s CI-Placement standard already establishes for the same cost-and-flakiness reasons.

---

## k6 Scenario Structure and the Workload-Model Choice

```javascript
// load/scenarios/ramp.js
import http from "k6/http";
import { check } from "k6";

export const options = {
  scenarios: {
    ramp: {
      executor: "ramping-arrival-rate",   // OPEN model — see below
      startRate: 5,
      timeUnit: "1s",
      preAllocatedVUs: 100,
      maxVUs: 600,
      stages: [
        { duration: "2m", target: 50 },
        { duration: "5m", target: 50 },
        { duration: "5m", target: 500 },
      ],
    },
  },
  thresholds: {                                          // pass/fail gate — real values: references/slo-gate-standard.md
    http_req_duration: ["p(99.5)<800"],
    http_req_failed: ["rate<0.005"],
  },
};

export default function () {
  const res = http.patch(
    `${__ENV.BASE}/v1/data-assets/${__ENV.ASSET}/classification`,
    JSON.stringify({ sensitivityLevel: "Confidential" }),
    { headers: { Authorization: `Bearer ${__ENV.TOKEN}`, "Content-Type": "application/json" } },
  );
  check(res, { "not a 5xx": (r) => r.status < 500 });
}
```

**Workload model is a deliberate choice, not a default left alone.** k6's `ramping-vus` executor is
a **closed** model: each virtual user waits for its response before sending the next request, so
when the service slows down, offered load quietly drops and tail latency is understated
(coordinated omission) — real users do not wait politely for a slow server before trying again.
`ramping-arrival-rate`/`constant-arrival-rate` are **open** models: they keep issuing requests at
the declared rate regardless of response time, exactly like independent real users would. **Use
open-model executors (`constant-arrival-rate`, `ramping-arrival-rate`) for every profile whose
question is "does it hold an SLO at N req/s"** — Soak and the sustained baseline in Spike. **Use the
closed `ramping-vus` model only for Ramp**, where the actual goal is finding the breaking point by
letting offered load naturally throttle to what the system can absorb — the closed model's
"understatement" there is not a flaw, it is the mechanism that reveals where saturation begins.

---

## Traffic Mix — Never a Single Endpoint, Single Payload

A load test that hammers one endpoint with one payload shape measures a cache or a hot code path,
not the system a reviewer actually uses. Model the journey mix: interactive load blends
`GET /v1/data-assets` (list/browse), `GET /v1/data-assets/{id}` (detail), and
`PATCH /v1/data-assets/{id}/classification` (the command under SLO) at a ratio matching the real
reviewer journey (`user-journey-mapping`) — browsing and reading dominate; classifying is the
minority, SLO-gated action. Pipeline load varies `document_type` (pdf/docx/xlsx) and `source_type`
(gdrive/s3) across the batch, matching `prometheus-metrics-design`'s own label allowlist for
`pipeline_documents_processed_total`, so saturation findings are attributable to a real document
class rather than an artifact of testing only the cheapest payload shape.
