# Orchestration and Observability Design

Reference material for `data-pipeline-design`. The body carries the choreography-vs-orchestration
decision; this file carries the DAG model, dependency/trigger design, backpressure and flow
control, SLA/freshness targets, and the pipeline-level observability design (which hands the
metric definitions to `metrics-instrumentation-plan`).

Orchestration is one of the six **undercurrents** (Reis & Housley) that run through every
lifecycle stage — scheduling and dependency management across the whole flow, not just within one
stage.

---

## 1. Choreography vs orchestration — the topology decision

Two ways to coordinate multi-stage work:

| | Event Choreography | Orchestration (a central coordinator) |
|---|---|---|
| Control | Each stage reacts to the prior stage's event | A coordinator invokes each stage in turn |
| Coupling | Loose — stages know only their topics | Tight — coordinator knows every stage |
| Scaling | Each stage scales on its own topic lag | Coordinator can become a bottleneck |
| Failure | A slow stage builds backlog, does not block upstream | Coordinator is a single point of failure |
| Best for | Independent, incrementally-derived stages | Flows needing coordinated rollback (a Saga) |

**This product's interior pipeline is choreography.** Stages communicate only through Redpanda
topics — never direct calls. A slow extraction stage does not block file processing; it builds
backlog on its topic. No central coordinator becomes a bottleneck or single point of failure.

**When orchestration (a Saga) is the right call:** a multi-step process that needs *coordinated
compensation* — if step 3 fails, steps 1 and 2 must be rolled back in a defined order. That is
not the happy-path topology; it is a targeted tool. Do not put an orchestrator on the happy path
"for visibility" — it reintroduces exactly the coupling and single-point-of-failure choreography
removes. Saga detail: `event-driven-patterns`.

**Scheduled/batch flows are the exception where a DAG orchestrator does fit** (see §2) — a nightly
reconciliation or a bounded backfill is a batch job with explicit dependencies, and a DAG
scheduler is the natural home for *that*, even though the streaming interior stays choreographed.

---

## 2. The DAG model — dependency and trigger design

For any scheduled/batch flow, model it as a Directed Acyclic Graph of tasks:

- **Nodes** are tasks (extract-delta, transform, reconcile, emit-report).
- **Edges** are dependencies — a task runs only after its upstream tasks succeed.
- **Triggers** start the DAG: time-based (cron: "02:00 daily"), or event-based (an upstream
  dataset landing). State the trigger explicitly.
- **Retry/backoff per node** — a failed node retries with backoff before failing the run; a
  failed run alerts and does not silently skip.
- **Idempotent nodes** — a re-run of the DAG (after a fix) must not double-apply; the whole run is
  the unit of retry, so each node is designed to be safely re-runnable.

Keep the DAG's *concrete tool* choice (Airflow/Dagster-style) a late decision; the design here is
the dependency graph and trigger contract, tool-agnostic and open-source-first per frugality.

---

## 3. Backpressure and flow control

When a downstream stage is slower than its upstream, the design must degrade gracefully, not
collapse.

| Mechanism | Effect |
|---|---|
| Topic as buffer | Redpanda retains the backlog; a slow consumer builds lag without losing data or blocking the producer |
| Consumer lag metric | Lag per consumer group is monitored; sustained growth triggers scaling or alerting |
| Partitioning for parallelism | Topics partitioned by key so consumers scale horizontally via Competing Consumers |
| Bounded concurrency | Each consumer caps in-flight work to protect downstream stores from overload |
| Rate limiting at ingress | The worker tier throttles discovery so a huge estate cannot flood the pipeline faster than it drains |

**Partitioning rule — ordering first, parallelism second.** All events for one Aggregate must land
on one partition — key by `aggregateId` — or a consumer can apply `DataAssetClassified` before the
`FileDiscovered` that created the asset. In the first product's physical multi-tenancy, topics are
already tenant-scoped, so `aggregateId` keying gives per-Aggregate order *and* horizontal
parallelism. In a shared-topic deployment, keying by `tenant_id` instead buys starvation isolation
and per-tenant ordering — at the cost of capping each tenant's throughput at one partition. Name
the trade-off you chose; do not inherit it by accident.

**The two load regimes.** The bulk estate scan and the steady-state change flow share the same
stage topology but differ in producer rate. The scan is rate-limited at ingress so it drains at
the pipeline's sustainable rate rather than flooding; the steady-state flow is naturally paced by
change frequency. Design the ingress throttle for the scan regime — it is the one that can
overwhelm downstream stores.

---

## 4. SLA and freshness targets

Every flow states, in its contract, the freshness and latency targets it is designed to meet.
These are design commitments, not aspirations — they drive the alerting thresholds.

| Target | Definition | Example |
|---|---|---|
| Processing latency SLO | p95 time from consume to state-commit, per stage | p95 < 5 s per stage |
| End-to-end freshness | Time from `FileDiscovered` to `ComplianceEvaluated` | p95 < 2 min steady-state |
| Max consumer lag | Sustained lag ceiling before alerting | lag < 10 000 messages |
| Backlog drain time | For the bulk scan, expected time to fully process an estate | 400k files < 6 h |

Freshness is a first-class contract term because a compliance dashboard showing a number that is
silently 3 hours stale is *wrong*, not just slow. State what "stale" means and who is notified.

---

## 5. Pipeline observability design

Data observability (Reis & Housley) is a distinct discipline from per-record quality gating: it
continuously monitors the *pipeline's* health in production, not individual records at ingestion.
The five pillars, and how each maps to a designed signal here:

| Pillar | Signal the pipeline must expose | Alerts when |
|---|---|---|
| **Freshness** | Time since last event processed per stage; end-to-end lag | Freshness exceeds the SLO |
| **Volume** | Files-processed-per-hour; events-per-topic | Sudden drop (source outage) or spike (runaway scan) |
| **Distribution** | Value distributions of derived fields (e.g. classification-level mix) | Distribution shifts sharply from baseline |
| **Schema** | Shape of source documents / event envelopes | A new/unexpected file-type or envelope shape appears |
| **Lineage** | Input→output provenance per stage | A stage produces output with no recorded input |

**Where the numbers live.** This skill *designs* which signals must exist and their thresholds; it
does **not** define the metric formulas or wire the collectors — that is `metrics-instrumentation-plan`.
The handoff: for each pillar above, name the signal and its SLO/threshold in the stage contract,
then reference `metrics-instrumentation-plan` for the metric definition (name, type, labels,
source event) and `alerting-rules-design` for the alert rule.

**Operational metadata is a designed output, not exhaust.** Job run statistics — execution time,
records processed, success/failure rate per run — are one of the three metadata categories
(technical / business / operational) and feed the observability signals above. Design the stage to
*emit* operational metadata, do not hope to reconstruct it from logs later.

---

## 6. The pipeline contract — orchestration/observability fields

Each stage's contract (the full contract template is in the skill body's Output Format) carries
these orchestration/observability fields:

- **Trigger** — event (topic/event consumed) or schedule (for batch nodes).
- **Retry / DLQ** — attempts, backoff curve, DLQ topic.
- **Partition key** — and the ordering/parallelism trade-off it encodes.
- **SLO** — processing-latency p95, max consumer lag, end-to-end freshness.
- **Observability signals** — the freshness/volume/distribution/schema/lineage signals this stage
  exposes, each with a threshold, cross-referenced to `metrics-instrumentation-plan`.
