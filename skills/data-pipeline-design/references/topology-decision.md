# Topology Decision — Batch vs Streaming vs Micro-Batch, ELT vs ETL, Data-Flow Patterns

Reference material for `data-pipeline-design`. The body carries the decision summary;
this file carries the full framework, the criteria thresholds, the ELT/ETL tradeoff, and
the three canonical data-flow patterns with worked examples grounded in the first product
(Google Drive / S3 ingestion → entity extraction → classification → compliance → audit).

---

## 1. Frame the flow on the Data Engineering Lifecycle first

Before choosing a processing mode, name which lifecycle stage the new flow touches
(Reis & Housley — *Fundamentals of Data Engineering*). The five stages are:

| Stage | Question it answers | In this product |
|---|---|---|
| Generation | What does the *source system* emit, how often, in what order? | Google Drive / S3 — third-party, uncontrolled; no CDC, no schema authority |
| Storage | What substrate underlies every stage? | PostgreSQL + `pgx`; Apache AGE graph; Elasticsearch index — all treated as derived/rebuildable |
| Ingestion | How does data enter the platform? | Bespoke crawler workers at customer storage emit `FileDiscovered` |
| Transformation | Where does business logic turn raw into usable? | Entity extraction, classification, compliance evaluation — in-flight, per stage |
| Serving | Where does data produce value? | PostgreSQL Read Models feeding dashboards / reports; the audit log |

**Generation is a design input, not a given.** The source system's guarantees about change
notification, ordering, and rate bound what `FileDiscovered` can promise. Google Drive and S3
are third-party stores this product has zero influence over: there is no reliable push-based
change feed you can treat as CDC, ordering across a bulk scan is not guaranteed, and the rate
is bursty (a first-time estate scan floods; steady-state trickles). Name these constraints
before choosing a topology — they are the reason the bulk scan and the steady-state change
flow are two different regimes that may warrant two different processing modes.

---

## 2. Batch vs Streaming vs Micro-Batch — the decision

The reflex "just make it streaming" is a trade-off to justify, not a default. True low-latency
streaming (sub-second) carries real cost: stateful stream processing, exactly-once machinery,
and continuous operational burden. The right question is always **what latency does the
business decision this data supports actually require** — not "what is the most impressive
architecture."

### Decision criteria

| Criterion | Pushes toward batch | Pushes toward micro-batch | Pushes toward true streaming |
|---|---|---|---|
| Business-decision latency | Hours to days is fine | Seconds to minutes | Sub-second required |
| Source emission | Bounded set, known in advance | Frequent small arrivals | Continuous unbounded event flow |
| Volume shape | Large, periodic | Steady moderate | High-rate continuous |
| Per-event value | Low (value is in the aggregate) | Medium | High (each event drives an action) |
| Ordering need | Whole-set, order irrelevant | Per-key order within a window | Strict per-key order, always |
| Operational cost tolerance | Lowest | Low–moderate | Highest |

### Latency bands (the threshold rule)

Pick the mode from the *tightest* decision the data feeds, using these bands:

- **Decision tolerates hours or more → scheduled batch.** Cheapest; run on a cron/DAG trigger.
- **Decision tolerates seconds to a few minutes → micro-batch.** Small, frequent batches
  (e.g. drain the topic every 10–60 s, or every N=500 events, whichever comes first). This is
  the pragmatic middle ground and gets most of the perceived benefit of "real-time" at a
  fraction of the engineering cost.
- **Decision needs sub-second, per-event → true streaming.** Only justified when a single late
  event materially changes an action a human or system takes immediately.

**Default bias: micro-batch.** For the vast majority of flows in a compliance product, no
human acts on a single file's classification within one second of it landing. A file
classified 30 seconds after discovery is indistinguishable, to the reviewer, from one
classified instantly. Reserve true streaming for the narrow case where sub-second latency is a
real business requirement, not an aesthetic preference.

### Worked example A — the bulk estate scan

A first-time customer connects a Google Drive estate of 400,000 files. This is a **bounded,
known-in-advance set** with **no per-file latency requirement** — the customer expects a first
compliance picture in hours, not that file #7 is classified sub-second. Criteria point at
batch or micro-batch, not streaming. The chosen design runs the scan as a throttled producer
feeding the *same* choreographed stages the steady-state flow uses, drained in **micro-batches**
so the extraction and classification stages amortise per-event overhead across hundreds of
files. True streaming here would pay exactly-once and stateful-processing cost for a workload
whose business latency budget is measured in hours — the wrong trade.

### Worked example B — steady-state change flow

After the initial scan, new and modified files trickle in. A newly-added file containing PII
should surface on the compliance dashboard within a **minute or two**, not sub-second. This is
a micro-batch flow: the crawler emits `FileDiscovered` as changes are detected, and downstream
stages drain their topics in small frequent batches. The steady-state and bulk-scan flows share
the same stage topology and differ only in the *producer's* rate and the *backpressure regime* —
naming them as one micro-batch pipeline with two load profiles avoids building two codebases.

### Worked example C — a genuine streaming case (counter-example)

If a future capability must **block** an action in real time — e.g. prevent a file from being
shared externally the instant it is classified as containing a Special Category — that decision
has a sub-second latency budget and each event drives an immediate action. *That* flow justifies
true streaming (or a synchronous check), because micro-batch's seconds-of-lag would let the
unsafe action through. Name the specific decision that forces streaming; do not inherit
streaming for the whole pipeline because one edge needs it.

---

## 3. ELT vs ETL vs Streaming-Transform

A second, orthogonal choice: **where** transformation happens relative to storage. Three shapes:

| Pattern | Order | Raw form retained? | Re-derive new facts without re-ingesting? | Typical home |
|---|---|---|---|---|
| **ETL** | Transform → Load | No (transform discards raw) | No | Legacy warehouses; scarce storage/compute |
| **ELT** | Load raw → Transform in place | Yes (raw landing zone) | Yes — re-run SQL transform against the same raw load | Modern analytics stack (Jewell) |
| **Streaming-transform** | Transform in-flight at each stage, then land derived | Only if you deliberately keep an intermediate artifact | Not without replaying the whole pipeline | This product |

**This product's pipeline is streaming-transform, and that is a deliberate choice — record it
as one.** The topology `FileDiscovered → FileProcessed → EntityExtracted → {Graph, Classification,
Compliance}` transforms incrementally, in-flight, at each stage, before anything lands in a
queryable form. It is neither classic ETL nor MDS-style ELT.

Why streaming-transform was chosen over ELT here:

- **Privacy / residency.** ELT's premise is a raw landing zone you re-query later. Raw file
  content and raw extracted PII must not be retained in a replicated log or landing table (see
  `data-retention-policy`). There is deliberately no raw-content landing zone to re-transform.
- **Independent scaling, no orchestrator bottleneck.** Each stage scales on its own topic lag;
  no central transform job is a single point of contention.

Cost of the choice (name it honestly): there is **no ELT-style "just re-run the transform with
new logic against the same raw load."** When an extraction or classification rule changes, you
cannot re-derive from a retained raw form — you reprocess from the event log instead (see
`references/fault-tolerance-design.md` §backfill). Preserving a minimal *parsed-content*
intermediate artifact (metadata, not raw PII) is the design lever that makes reprocessing
cheaper without reintroducing a privacy-liable raw landing zone.

---

## 4. The three canonical data-flow patterns

Most flows this product designs are one of three shapes. Name the pattern explicitly; each has
a different ingestion contract and fault-tolerance profile.

### Pattern 1 — Scheduled batch

A bounded set pulled on a trigger (cron, or an orchestration DAG node). Use when the source has
no change feed and the decision latency is hours+. Example: a nightly reconciliation that
re-scans an estate to detect files deleted at the source since the last crawl.

- Ingestion contract: pull the full (or delta) set at trigger time; idempotent per run.
- Fault tolerance: re-run the whole batch; the run is the unit of retry.

### Pattern 2 — Change Data Capture (CDC) ingest

Consume a source's change feed as an ordered stream. Use when the source *emits* changes you can
subscribe to. **Caveat for this product:** Google Drive / S3 are third-party stores with no
first-class CDC feed — the crawler *approximates* CDC by polling and diffing, then emitting
`FileDiscovered` / `FileModified` domain events onto Redpanda. Downstream of that boundary the
flow behaves like true CDC (an ordered, replayable log of changes); upstream, the "capture" is
poll-and-diff, not a native change stream. Name that boundary so no one assumes source-native
ordering guarantees the crawler cannot provide.

- Ingestion contract: emit one domain event per detected change, keyed by asset id for order.
- Fault tolerance: the Redpanda topic is the replayable change log; a consumer group can reset
  its offset to reprocess history.

### Pattern 3 — Event stream processing

Consume a domain-event stream and produce a derived stream or Read Model, incrementally. This is
the interior of this product's pipeline: each stage consumes the previous stage's event and
emits its own. Use when transformation is naturally per-event and downstream needs low latency.

- Ingestion contract: consume topic `X` / event `E`, emit topic `Y` / event `F`.
- Fault tolerance: checkpoint + idempotent consumer; see `references/fault-tolerance-design.md`.

---

## 5. Putting it together — the topology-selection procedure

1. Name the lifecycle stage(s) the flow touches and the source's generation guarantees.
2. Write down the *business-decision latency* the tightest downstream decision needs.
3. Map that latency to a band (hours → batch, seconds/minutes → micro-batch, sub-second → streaming).
4. Choose the transform placement (ETL / ELT / streaming-transform) and record *why*, naming the
   alternative you rejected — never inherit it by accident.
5. Classify the flow as one of the three data-flow patterns and write its ingestion contract.
6. Hand the fault-tolerance design to `references/fault-tolerance-design.md` and the orchestration
   / observability design to `references/orchestration-and-observability.md`.
