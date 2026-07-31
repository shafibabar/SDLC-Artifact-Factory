# Worked Example: Two Integrations, End to End

Reference for `integration-design`. Self-contained: a complete integration design
for the Data Estate Mapping & Compliance Intelligence platform, showing the full
decision trail for two contrasting integrations — one synchronous to an external
system, one asynchronous across two Bounded Contexts. Follow the reasoning, not
just the result: the value is in *why* each choice was made.

Bounded Contexts in play:
- **DataAsset Management** — registers, classifies, and tracks data assets.
- **Compliance** — evaluates data assets against compliance rules, tracks gaps.
- **Source Catalog** — an *external* third-party system holding origin metadata
  about where data assets physically live.

---

## Integration 1 — DataAsset Management → Source Catalog (external, synchronous)

### The requirement

When registering a new data asset, DataAsset Management must enrich it with origin
metadata (source system, physical locator) that lives only in the external Source
Catalog. The registration cannot complete without it.

### Step 1 — communication style (`sync-vs-async-decision.md`)

| Criterion | Reading | Verdict |
|---|---|---|
| Need for immediate response | Registration genuinely blocks on the origin data | → sync |
| Temporal coupling tolerance | Registration is user-initiated and short; brief co-availability acceptable | → sync tolerable |
| Failure blast radius | One caller, one external callee; contained with a fallback | → sync acceptable |
| Data volume / fan-out | One lookup per registration; small payload | → sync fine |

**Decision: Request/Response (synchronous).** Consistency need: **eventual** — a
slightly stale origin record is acceptable, so no atomic guarantee is required
across the boundary. No multi-step flow, so no coordination axis.

### Step 2 — it is a foreign model, so it needs an ACL (`integration-patterns.md`)

Source Catalog is a third-party system with its own vocabulary (`obj_id`,
`src_system`, `locator`). That model must not leak into DataAsset Management's
domain. Build `adapters/sourcecatalog/` with `client.go`, `translator.go`,
`dto.go`, and a domain-side `SourceCatalogPort`:

```go
// domain — the port, in our language
type SourceCatalogPort interface {
    LookupOrigin(ctx context.Context, id AssetID) (Origin, error)
}
```

The translator maps `catalogEntryDTO` → domain `Origin`, ignoring vendor fields
the domain doesn't use (no stamp coupling).

### Step 3 — it is synchronous, so it needs the full resilience stack (`resilience-patterns.md`)

Composed innermost-to-outermost inside the ACL's `client.go`:

- **Timeout** — 500ms per attempt; deadline propagated from the registration
  request's `context.Context`.
- **Retry** — 3 attempts, 100ms initial backoff, ×2, ±20% jitter; safe because
  `LookupOrigin` is a read (idempotent).
- **Circuit Breaker** (`sony/gobreaker`, name `source-catalog`) — trips at 50%
  failures over ≥20 requests in a 30s window; 30s reset timeout; single half-open
  probe. State exported to Prometheus.
- **Bulkhead** — a dedicated `http.Client` with its own `MaxConnsPerHost`, so a
  slow Source Catalog cannot starve calls to internal services.
- **Fallback** — on open breaker or failure, return the last-known-good origin
  from the local cache with a `stale: true` marker, or mark origin "pending
  enrichment" and enqueue a retry — registration still succeeds in degraded form.

### Step 4 — contract

Loose JSON, tolerant-reader parsing (ignore unknown fields). A Consumer-Driven
Contract test (`go-contract-test`) pins the handful of fields the translator
reads (`obj_id`, `src_system`, `locator`); the provider's CI fails if any is
removed.

### Inventory row

| From | To | Style | Consistency | Protocol | Contract | Resilience |
|---|---|---|---|---|---|---|
| DataAsset Mgmt | Source Catalog (ext) | Sync req/resp | Eventual | HTTP/JSON | ACL + CDC test | Timeout+Retry+Breaker+Bulkhead+Fallback |

---

## Integration 2 — DataAsset Management → Compliance (cross-BC, asynchronous)

### The requirement

When a data asset is classified (e.g. sensitivity set to `Restricted`), the
Compliance context must re-evaluate whether that asset creates a compliance gap.
DataAsset Management should not know or care that Compliance exists.

### Step 1 — communication style (`sync-vs-async-decision.md`)

| Criterion | Reading | Verdict |
|---|---|---|
| Need for immediate response | The classifying caller needs no answer from Compliance | → async |
| Temporal coupling tolerance | Compliance may be down/slow without blocking classification | → async required |
| Failure blast radius | A Compliance outage must never fail classification | → async required |
| Data volume / fan-out | Reporting and the Graph projection also react to the same fact | → event, one-to-many |

**Decision: Event-Driven (asynchronous).** Consistency: **eventual** —
gap re-evaluation lags classification by the consumer's processing time.
Coordination: **choreographed** — Compliance simply reacts to the event, no
central orchestrator. In Ford's taxonomy this is an **Anthology Saga step** (async
+ eventual + choreographed) — the most decoupled shape, correct here because the
reaction is genuinely independent.

Explicitly rejected: **request/reply over the broker** (publishing an event and
waiting for a "gap re-evaluated" event) — that would recreate temporal coupling
with worse latency. The event is a fire-and-forget *fact*: "this asset was
classified."

### Step 2 — reliable publication: Transactional Outbox

DataAsset Management writes the `dataasset.classified` event to an `outbox_events`
row **in the same PostgreSQL transaction** as the classification state change, so
the event cannot be lost if the process crashes after committing the state. An
Outbox Relay reads `outbox_events` and publishes to the Redpanda topic
`dataasset.classified`. (Mechanics owned by `event-driven-patterns`.)

### Step 3 — event schema (contract)

The event payload is a **purpose-built projection**, not the whole DataAsset
Aggregate — avoiding stamp coupling. Compliance declares the fields it reads
(`assetId`, `tenantId`, `sensitivityLevel`, `classifiedAt`); the schema registry
(`event-schema-design`) enforces backward compatibility so the publisher can add
fields without breaking Compliance, and CI fails if a consumed field is removed.

### Step 4 — resilient consumption

Compliance runs its own consumer group (`compliance.gap-evaluator`) — never
shared with another service, so offsets and replay are independent:

- **Idempotency** — each event carries an `eventId`; the consumer records
  processed IDs and skips duplicates (at-least-once delivery means duplicates *will*
  happen).
- **Retry policy** — immediate, then 1s, 5s, 30s, 2m.
- **Dead Letter Queue** — after 5 failures the event moves to
  `compliance.gap-evaluator.dlq` rather than being silently dropped or blocking
  the partition.
- **No synchronous external call on the critical path** — if gap evaluation needs
  an external lookup, it goes behind its own resilience stack, or is split into a
  separate step with its own topic, so broker lag doesn't balloon behind a slow
  third party.

### Inventory row

| From | To | Style | Consistency | Protocol | Contract | Resilience |
|---|---|---|---|---|---|---|
| DataAsset Mgmt | `dataasset.classified` | Async event | Eventual | Kafka protocol | Event schema | Transactional Outbox |
| Compliance | `dataasset.classified` | Async consume | Eventual | Kafka protocol | Event schema | Idempotent + retry + DLQ |

---

## The two decisions side by side

| Dimension | Integration 1 (Source Catalog) | Integration 2 (Compliance) |
|---|---|---|
| Shape | Request/Response | Event-Driven |
| Why | Registration blocks on the result | Caller needs no answer; many consumers; must not cascade |
| Consistency | Eventual | Eventual |
| Coordination | none (single call) | Choreographed (Anthology Saga) |
| Foreign model? | Yes → ACL | No (our own event) |
| Resilience | Timeout+Retry+Breaker+Bulkhead+Fallback | Outbox + idempotent consumer + DLQ |
| Contract | ACL + CDC test, loose JSON | Event schema, backward-compatible |

The pattern to internalize: **synchronous** integrations spend their design effort
on the *resilience stack and the ACL*; **asynchronous** integrations spend it on
*reliable publication (Outbox), idempotent consumption, and schema compatibility*.
Both start from the same first question — the four-criteria sync-vs-async
decision — and both declare consistency as a separate axis from communication.

---

## Observability for both (OpenTelemetry / Prometheus / Tempo / Grafana)

- **Traces (Tempo)** — the trace context propagates through the synchronous call
  to Source Catalog *and* is injected into the `dataasset.classified` event
  headers, so the async hop into Compliance stays on the same distributed trace.
- **Metrics (Prometheus)** — circuit-breaker state gauge per downstream; retry
  counts; consumer lag on `dataasset.classified`; DLQ depth on
  `compliance.gap-evaluator.dlq`.
- **Dashboards (Grafana)** — an open breaker, rising consumer lag, or a
  non-empty DLQ are the three integration-health signals that page an operator.
