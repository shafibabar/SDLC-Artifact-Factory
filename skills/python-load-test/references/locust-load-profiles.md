# locust Load Profiles — User Classes, Shapes, Distributed Runs, and the DataAsset Worked Test

Full standard referenced from `SKILL.md`'s "Tool Standard", "Load-Profile Standard", and "Closed vs.
Open Workload Model" sections. Self-contained — reads without the parent body in context. Covers what
a locust `User`/task class is and how the journey mix is expressed as ordinary Python, the four load
profiles with concrete parameters for the data-estate-mapping platform's bursty traffic, why a single
locust process is capped by one CPU core (the GIL) and how the distributed master/worker run lifts
that cap, how to make locust behave as an open-arrival-rate model when a rate-based SLO demands it,
and a complete worked load test against the DataAsset command/query API.

---

## Why locust, and What a `User` Class Is

locust (MIT, open-source, self-hosted — no paid tier, per CLAUDE.md's frugality constraint) models
load as a population of simulated **users**, each an instance of an `HttpUser` subclass whose
`@task`-decorated methods are the requests that user makes. Task **weights** set the journey mix;
`wait_time` sets the think-time between a user's successive tasks. This reads as ordinary Python and
lives beside the FastAPI service it exercises — the reason to pick locust over k6 when the same team
maintains both. It is still a **black-box external client**: locust drives HTTP at the `uvicorn`-
served binary over the network (through Linkerd's mesh, exactly as a real caller would), never
imported in-process with the app under test.

```python
# load/locustfile.py
import os
import random
from locust import HttpUser, task, between, events

BASE_TENANT = os.environ["LOAD_TEST_TENANT"]   # synthetic staging tenant — never a real customer stamp
TOKEN = os.environ["LOAD_TEST_TOKEN"]
SEED_ASSETS = os.environ["SEED_ASSET_IDS"].split(",")

DOCUMENT_TYPES = ["pdf", "docx", "xlsx"]        # matches prometheus-metrics-design's label allowlist
SOURCE_TYPES = ["gdrive", "s3"]


class DataAssetReviewer(HttpUser):
    """A human reviewer journey: browsing and reading dominate; classifying is the
    minority, SLO-gated action. Weights encode that ratio (user-journey-mapping)."""

    wait_time = between(1, 3)   # think-time — makes this a CLOSED model (see "Open Model" below)

    def on_start(self):
        # Common headers for every request this simulated user issues.
        self.client.headers.update({
            "Authorization": f"Bearer {TOKEN}",
            "X-Tenant-Id": BASE_TENANT,
            "Content-Type": "application/json",
        })

    @task(6)
    def list_data_assets(self):
        # Browsing — the dominant interactive action.
        self.client.get("/v1/data-assets?limit=25", name="GET /v1/data-assets")

    @task(3)
    def read_data_asset(self):
        asset_id = random.choice(SEED_ASSETS)
        self.client.get(f"/v1/data-assets/{asset_id}", name="GET /v1/data-assets/{id}")

    @task(1)
    def classify_data_asset(self):
        # The SLO-gated command: PATCH …/classification. Named so its own P95/P99 is isolated.
        asset_id = random.choice(SEED_ASSETS)
        with self.client.patch(
            f"/v1/data-assets/{asset_id}/classification",
            json={"sensitivityLevel": "Confidential"},
            name="PATCH /v1/data-assets/{id}/classification",
            catch_response=True,
        ) as resp:
            # Backpressure check: a 429 is a SUCCESS shape (graceful shedding) only if it
            # carries Retry-After. A 5xx is a failure. See references/criteria-and-analysis.md.
            if resp.status_code == 429 and "Retry-After" in resp.headers:
                resp.success()
            elif resp.status_code >= 500:
                resp.failure(f"5xx under load: {resp.status_code}")
```

Never hammer one endpoint with one payload — a journey mix (list/read/classify above) and payload
variety (document/source types below) is what makes a saturation finding attributable to a real
document class rather than an artifact of testing only the cheapest path.

---

## Load Profiles — Concrete Parameters for This Platform's Traffic Shape

The platform's traffic is bursty, not a smooth ramp: interactive `ClassifyDataAsset` calls are low,
steady volume, while `estate-scanner`'s discovery sweeps enqueue **batches** of thousands of
documents in seconds, absorbed by the `aiokafka` pipeline as a burst. Every profile models this.

| Profile | Shape | Concrete parameters (this platform) | Answers |
|---|---|---|---|
| **Smoke** | 1 user, ~1 min | `-u 1 -r 1 -t 60s` against the reviewer journey | Does it work under any load at all? (fast CI pre-check) |
| **Ramp** | Steady climb past peak until SLO breach | 0→50 users over 2 min, hold 50 for 5 min (daytime reviewer concurrency), 50→500 over 5 min | Where is the breaking point, and how does it fail? |
| **Soak** | Sustained moderate load, hours | 30 req/s at the command API + a steady 500-document/min pipeline feed, held **2 hours** | Memory leaks, `asyncpg`-pool exhaustion, outbox growth, consumer-lag drift that only appear over time |
| **Spike** | Sudden batch burst | Baseline 30 req/s + a **10,000-document burst** enqueued in under 60s (a large source's sweep completing) | Does backpressure engage and recover, or does the burst cascade into the sync API's degradation? |

A locust `LoadTestShape` expresses Ramp and Spike as code, so the profile is version-controlled, not
a set of CLI flags a runner has to remember:

```python
# load/shapes.py
from locust import LoadTestShape


class RampToBreak(LoadTestShape):
    """Closed-model ramp: climb past capacity so offered load naturally throttles
    to what the system can absorb — the mechanism that reveals where saturation begins."""

    stages = [
        {"duration": 120,  "users": 50,  "spawn_rate": 1},    # 0→50 over 2 min
        {"duration": 420,  "users": 50,  "spawn_rate": 1},    # hold 50 for 5 min
        {"duration": 720,  "users": 500, "spawn_rate": 5},    # 50→500 over 5 min, until thresholds breach
    ]

    def tick(self):
        run_time = self.get_run_time()
        for stage in self.stages:
            if run_time < stage["duration"]:
                return (stage["users"], stage["spawn_rate"])
        return None   # end the test


class SpikeBurst(LoadTestShape):
    """Baseline reviewer load with a sudden batch-scan spike layered on."""

    def tick(self):
        run_time = self.get_run_time()
        if 300 <= run_time < 360:      # 60-second spike window at t=5min
            return (600, 50)
        if run_time < 900:
            return (30, 5)             # steady baseline
        return None
```

Run **smoke** in CI on every change (seconds, cheap). Run **ramp/soak/spike** on a
nightly/pre-release/on-demand cadence against `staging` — each takes minutes to hours — never per-PR.

---

## The Open-Model Case: locust Is Closed by Default

A locust `User` sleeps `wait_time` between tasks and waits for each response before issuing the next
request — that is a **closed** model, correct for Ramp (where letting offered load throttle naturally
finds the break) but **wrong for a rate-based SLO claim** ("does it hold 30 req/s"), because when the
service slows, offered load quietly drops and tail latency is understated (coordinated omission).

To make locust issue requests at a fixed **arrival rate** regardless of response time — an open model
— pace tasks with `constant_throughput` (tasks/second per user) instead of `between`, sizing the user
count so `users × throughput` equals the target rate:

```python
from locust import HttpUser, task, constant_throughput

class SoakLoad(HttpUser):
    # 30 users × 1 task/s = 30 req/s offered, held regardless of how slow responses get.
    wait_time = constant_throughput(1)

    @task
    def classify(self):
        ...   # same request body as above
```

This is the sharpest honest divergence from k6, whose `constant-arrival-rate`/`ramping-arrival-rate`
executors are open-model out of the box: with locust the open model is a deliberate configuration,
never a default. State which model each profile uses in the load report so a reviewer knows whether a
rate claim was made under an open model (trustworthy) or a closed one (understated).

---

## Distributed Runs: One Process Is Capped by One Core (the GIL)

**A single locust process runs all its simulated users on one CPU core, because CPython's Global
Interpreter Lock (GIL) lets only one thread execute Python bytecode at a time.** For a smoke test or
a few dozen users this is fine; to generate serious offered load (hundreds of req/s) a single process
becomes the bottleneck — you would be measuring the load generator's own saturation, not the
service's. This is a real Python-specific constraint with no k6 equivalent (k6 is Go-based and uses
all cores in one process).

The fix is locust's built-in **distributed mode**: one coordinating master and N worker processes,
each worker its own OS process on its own core (spread across cores on one host, or across several
load-generator hosts):

```bash
# One coordinator (aggregates stats, serves the web UI, owns the LoadTestShape):
locust -f load/locustfile.py --master --shape RampToBreak

# N workers, one per core, each a separate OS process generating traffic:
locust -f load/locustfile.py --worker --master-host 127.0.0.1   # repeat per core

# Headless, CI-friendly, with a hard pass/fail exit code:
locust -f load/locustfile.py --master --headless \
  --users 500 --spawn-rate 5 --run-time 12m \
  --host https://staging.internal/compliance-engine \
  --expect-workers 4 --csv load/results/ramp
```

Size the worker count to actual generator-host cores, leaving headroom so the generator never becomes
the bottleneck. `--expect-workers` makes the master wait until every worker connects before starting,
so the run always applies the intended parallelism. `--headless` plus `--csv` gives a scriptable,
non-interactive run whose exit code and CSV percentiles the CI gate reads — the enforcement
discipline covered in `references/criteria-and-analysis.md`.

---

## The Worked DataAsset Load Test, End to End

1. **Seed** a synthetic load-test tenant's physically-isolated `staging` stamp with a known set of
   DataAssets (`SEED_ASSET_IDS`), the same tenant-override discipline `python-integration-test` uses —
   never a real customer's stamp.
2. **Ramp** with `RampToBreak` distributed across workers, watching the named
   `PATCH …/classification` statistic's P95/P99 and the `429` rate climb as offered load passes the
   rate limiter's per-subject bucket. The break point is where P99 crosses 800ms or the error rate
   crosses 0.5%.
3. **Soak** with the open-model `constant_throughput` config at 30 req/s for 2 hours, concurrently
   feeding 500 documents/min into the `aiokafka` pipeline, watching for `asyncpg`-pool exhaustion,
   monotonic memory growth, and consumer-lag drift.
4. **Spike** with `SpikeBurst`, enqueuing a 10,000-document burst in under 60s, then verifying the
   pipeline drains and freshness/correctness SLOs still hold post-drain (PromQL — see
   `references/criteria-and-analysis.md`).
5. **Verify** the two async SLOs post-drain and record the run in `docs/quality/load-report.md` with
   the model used per profile, the `staging` sizing, and P95/P99 per gate.
