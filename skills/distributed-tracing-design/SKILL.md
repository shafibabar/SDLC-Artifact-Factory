---
name: distributed-tracing-design
description: >
  Design distributed tracing for a Go + chi + Redpanda system: decide what work
  becomes a span, name spans by operation not data, choose span kind
  (SERVER/CLIENT/PRODUCER/CONSUMER/INTERNAL), attach high-cardinality domain
  attributes, record errors with RecordError and SetStatus, propagate W3C trace
  context across HTTP and across the async broker so one trace follows an event
  through the outbox → Redpanda → consumer pipeline, and choose head-vs-tail
  sampling and a sample rate. Answers "why is my trace severed at the broker?",
  "should I span this function?", "what sample rate?", "how do errors show on a
  span?", "head or tail sampling?". Used by backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
related:
  - opentelemetry-instrumentation
  - structured-logging-design
  - go-middleware
  - go-event-publisher
  - go-event-consumer
tags: [implement, observability, distributed-tracing, opentelemetry, span, context-propagation, sampling]
---

# Distributed Tracing Design

## Purpose

A distributed trace is the end-to-end story of one logical operation as it moves across services and async boundaries. When a classification request flows API → command handler → repository → outbox → broker → consumer → graph update, a single trace ties all of it together, so a latency spike or an error can be located to the exact span where it happened.

This skill covers the **design decisions**: what to make a span, how to name and attribute it, how to record errors, and — the part that breaks most often — how to keep one trace unbroken across the Redpanda hop. SDK/provider setup lives in `opentelemetry-instrumentation`. Full Go instrumentation code is in `references/instrumentation-go.md`; sampling and W3C propagation in depth are in `references/sampling-and-propagation.md`.

---

## What Deserves a Span

Span the **units of work that can fail or be slow** — not every function.

| Span it | Do not span it |
|---|---|
| Inbound HTTP request (middleware SERVER span) | Trivial getters/setters, pure formatting |
| Command/query handler (INTERNAL) | In-memory struct mapping |
| Repository call / DB query (CLIENT) | A loop body iterating a slice |
| Broker produce (PRODUCER) and consume (CONSUMER) | Logging or metric emission itself |
| Outbound HTTP / external API call (CLIENT) | Anything that never blocks or fails |

A span per trivial function produces thousand-span traces where the story drowns in noise. Span the boundaries and the fallible work.

---

## Span Naming and Kind

- **Name by operation, low-cardinality**: `ClassifyDataAsset.Handle`, `repo.DataAsset.Save`, `consume orders.classification` — never `classify asset 6f9a…`. The asset id is an *attribute*, not part of the name.
- **Set the span kind** so the backend can stitch the topology: `SERVER`/`CLIENT` pair across a sync call, `PRODUCER`/`CONSUMER` pair across the broker. Handlers and domain work are `INTERNAL`. Full kind table and worked code: `references/instrumentation-go.md`.

Two rules that keep the tree intact:
- **`defer span.End()` immediately** after `Start` — a span that never ends corrupts the trace.
- **Pass the returned `ctx` downward** — children derive their parent from it. Dropping it severs the tree into disconnected roots.

---

## Attributes: High-Cardinality Detail Belongs Here

Detail that must **not** go on metrics (UUIDs, ids, sizes) belongs on spans — a trace is one execution, so high cardinality is fine and valuable.

| Attribute type | Examples |
|---|---|
| Semantic conventions | `http.route`, `http.response.status_code`, `db.system`, `messaging.system` — use `semconv` constants, not hand-typed strings |
| Domain attributes | `data_asset.id`, `tenant.id`, `sensitivity.level`, `batch.size` |
| Causal attributes | `event.id`, `correlation.id`, `causation.id` |

Enrich spans with the quantitative detail that explains behaviour (batch counts, byte sizes). **Never** put secrets or PII — a file path, an email, document content — on a span; spans are exported to a third system with its own retention (security `privacy-design`). Ids and sizes only. Attribute conventions and code: `references/instrumentation-go.md`.

---

## The Error/Status Rule

A failing span must be **visibly** failing. On any error path:

```
span.RecordError(err)                    // attaches the error as a span event
span.SetStatus(codes.Error, "save failed")
```

`RecordError` alone does **not** mark the span failed — you need `SetStatus(codes.Error, …)` too. Omitting it renders the failing span green in every trace view. On success, leave status unset (or `codes.Ok` only where you deliberately override sampling of an otherwise-error-looking result). This mirrors the SRE golden-signals discipline of separating successful from failed latency: a trace's error status is what lets tail sampling keep exactly the failed executions.

---

## Context Propagation (the part that breaks)

A trace survives a boundary only if the **W3C `traceparent`** context crosses it.

- **HTTP** — inbound: the SERVER middleware extracts the parent from request headers; outbound: wrap the client transport with `otelhttp` so every request injects the current context automatically.
- **Redpanda (async)** — the async boundary is where traces usually break, because producer and consumer are different processes at different times. The trace survives only if the context is carried **in the message headers**: the publisher `Inject`s into Kafka headers, the consumer `Extract`s to continue the *same* trace. A `PRODUCER` span and a `CONSUMER` span then pair across the hop.

Getting this right stitches the API request, the outbox relay, the broker hop, and every downstream pipeline stage into one connected trace across the whole choreography. Both carriers, the `kafkaHeaderCarrier` adapter, and end-to-end code are in `references/instrumentation-go.md`; the W3C header format and why event-header propagation (not span links) is the primary mechanism are in `references/sampling-and-propagation.md`.

---

## Sampling: Head vs Tail, and the Rate

Tracing every request at full volume is expensive and rarely necessary.

| Decision | Default choice | Why |
|---|---|---|
| Where to decide | **Head** for the common case: `ParentBased(TraceIDRatioBased(r))` in the SDK | Cheap, and `ParentBased` guarantees whole traces — the entry service's decision is followed downstream, no half-traces |
| Keep all errors | **Tail** sampling in the collector | You cannot know at head time whether a trace will error; tail sampling inspects the finished trace and keeps every one containing an error |
| Rate `r` | 100% non-prod; a small fraction in prod (see reference for how to pick) | Cost and backend cardinality scale with retained spans |

**`ParentBased` is essential** — per-service independent sampling produces traces with missing middles, worse than no trace. Rate selection, tail-sampling collector policy config, and the cost/cardinality tradeoff are in `references/sampling-and-propagation.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Spans well-formed | `defer End()`; returned ctx propagated | Unended spans; dropped ctx severing the tree |
| Operation-named | Low-cardinality operation names | Names containing ids/data |
| Errors recorded | `RecordError` + `SetStatus(Error)` on failure | Failures invisible / green on the span |
| HTTP propagation | Context extracted inbound, injected outbound | New disconnected trace per service |
| **Broker propagation** | Trace context in message headers; consumer continues it | Trace severed at every async hop |
| Rich attributes | Quantitative domain attributes on spans | Bare spans with no explanatory detail |
| No PII on spans | Ids/sizes only | Secrets/PII in span attributes |
| Whole-trace sampling | `ParentBased`; errors kept via tail | Independent per-span sampling → half-traces |

---

## Anti-Patterns

- **Dropping the returned context** — `_, span := tracer.Start(ctx, …)` then passing the *old* `ctx` down. Every child becomes a root; the tree flattens.
- **Span names carrying data** — `"classify asset 6f9a…"` mints one span name per asset. Names are operations; the id is an attribute.
- **A span per trivial function** — the story drowns in thousand-span traces. Span boundaries and fallible work only.
- **Severed async traces** — publishing without `Inject` or consuming without `Extract` breaks the trace exactly where debugging needs it most.
- **Errors swallowed by the span** — returning an error without `RecordError`/`SetStatus(Error)` leaves the failing span green.
- **Non-`ParentBased` sampling** — independent per-service decisions produce traces with missing middles.
- **PII in attributes** — ids and sizes only; never paths, emails, or content.

---

## Output Format

Produces Go source plus tracing assertions in tests:

```
internal/infrastructure/telemetry/tracing.go   (tracer helpers, kafkaHeaderCarrier)
internal/handlers/.../*.go                       (spans in handlers/consumers)
*_test.go                                         (assert spans/attributes via tracetest)
```

Detailed instrumentation, exporter wiring, and sampling configuration: see the two `references/` files.
