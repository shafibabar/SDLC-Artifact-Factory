---
name: distributed-tracing-design
description: >
  Teaches how to design distributed tracing across a Go microservices system —
  span creation and naming, parent/child relationships, semantic and custom
  attributes, recording errors and status, context propagation across HTTP and
  the Redpanda broker (so a trace follows an event through the pipeline), span
  events, and sampling strategy. Tracing is how a request is followed end-to-end
  across service and async boundaries. Used by the backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
tags: [implement, observability, tracing, opentelemetry, spans, context-propagation, sampling]
---

# Distributed Tracing Design

## Purpose

A distributed trace is the end-to-end story of one logical operation as it moves across services and async boundaries. When a classification request flows API → command handler → repository → outbox → broker → consumer → graph update, a single trace ties all of it together, so a latency spike or an error can be located to the exact span where it happened.

This skill covers how to create well-formed spans, attach the right detail, and — critically — **propagate trace context across HTTP and the Redpanda broker** so the trace is not severed at every boundary. Provider setup is in `opentelemetry-instrumentation`; this is the tracing design on top of it.

---

## Span Anatomy

A span represents one unit of work with a start, end, status, attributes, and a parent. Spans nest to form the trace tree.

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    ctx, span := h.tracer.Start(ctx, "ClassifyDataAsset.Handle",
        trace.WithSpanKind(trace.SpanKindInternal),
        trace.WithAttributes(
            attribute.String("data_asset.id", cmd.DataAssetID.String()),
            attribute.String("sensitivity.level", string(cmd.Sensitivity)),
        ),
    )
    defer span.End()                       // span always ends, even on panic/return

    if err := h.repo.Save(ctx, asset); err != nil {
        span.RecordError(err)              // attach the error to the span
        span.SetStatus(codes.Error, "save failed")
        return err
    }
    span.SetStatus(codes.Ok, "")
    return nil
}
```

Rules:
- **`defer span.End()` immediately** after `Start` — a span that never ends corrupts the trace.
- **Pass the returned `ctx` downward** — children derive their parent from it. Dropping the returned ctx severs the tree.
- **Name spans by operation, not data**: `ClassifyDataAsset.Handle`, `repo.DataAsset.Save` — low-cardinality, not `Classify asset a1b2…`.

---

## Span Kinds

The span kind tells the backend how to interpret the span in the trace topology:

| Kind | Use for |
|---|---|
| `SERVER` | Inbound request handling (HTTP server span — set by middleware) |
| `CLIENT` | Outbound calls (DB query, external API, broker produce) |
| `PRODUCER` | Publishing a message to the broker |
| `CONSUMER` | Receiving a message from the broker |
| `INTERNAL` | In-process work (command handlers, domain operations) |

`SERVER`/`CLIENT` and `PRODUCER`/`CONSUMER` pair across boundaries — this is what lets the backend stitch a remote parent to its child.

---

## Attributes: High-Cardinality Detail Lives Here

The detail that must **not** go on metrics (UUIDs, ids) belongs on spans — a trace is one execution, so high cardinality is fine and valuable.

| Attribute type | Examples |
|---|---|
| Semantic conventions | `http.route`, `http.status_code`, `db.system`, `messaging.system` |
| Domain attributes | `data_asset.id`, `tenant.id`, `sensitivity.level`, `batch.size` |
| Causal attributes | `event.id`, `correlation.id`, `causation.id` |

The blueprint's directive — "commit custom attributes (data sizes, batch counts) to the span context" — is exactly this: enrich spans with the quantitative detail that explains behaviour.

```go
span.SetAttributes(
    attribute.Int("outbox.batch_size", len(records)),
    attribute.String("tenant.id", tenantID.String()),
)
```

**Never** put secrets or PII in attributes — spans are exported and stored (security `privacy-design`).

---

## Propagation Across HTTP

Inbound: the server extracts the parent context from request headers (done by instrumentation middleware). Outbound: the client injects the current context into request headers. Use `otelhttp` so this is automatic for standard clients/servers.

```go
client := http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)} // injects on every request
// inbound extraction handled by the Telemetry middleware (see go-middleware)
```

---

## Propagation Across the Broker (the crucial part)

An async boundary is where traces usually break — the producer and consumer are different processes, different times. The trace survives only if the context is carried **in the message headers**. The publisher injects; the consumer extracts.

```go
// Publisher (outbox relay — see go-event-publisher): inject trace context into Kafka headers
otel.GetTextMapPropagator().Inject(ctx, kafkaHeaderCarrier{rec})

// Consumer (see go-event-consumer): extract it to continue the SAME trace
ctx = otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec})
ctx, span := tracer.Start(ctx, "consume "+rec.Topic, trace.WithSpanKind(trace.SpanKindConsumer))
```

The `kafkaHeaderCarrier` adapts the broker's headers to OTel's `TextMapCarrier` interface (get/set/keys). With this, a classification event's trace spans the API request, the outbox relay, the broker hop, and every downstream pipeline stage — one connected trace across the whole choreography.

---

## Span Events and Links

- **Span events** mark a point in time within a span (a retry attempt, a cache miss): `span.AddEvent("retry", trace.WithAttributes(attribute.Int("attempt", n)))`.
- **Span links** connect spans that are related but not parent/child — e.g., a batch consumer processing many messages links to each message's producing trace, since it has many "parents."

---

## Sampling Strategy

Tracing every request at full volume is expensive and rarely necessary. Sample intelligently (configured in `opentelemetry-instrumentation`):

| Strategy | Use |
|---|---|
| `ParentBased(TraceIDRatioBased(r))` | **Default** — sample a fraction `r`, but always follow the parent's decision so traces are whole |
| Always sample errors | Tail-sampling in the collector keeps all traces that contain an error |
| Higher ratio in non-prod | Sample 100% in staging; a small ratio in production |

**ParentBased is essential**: it guarantees that if a trace is sampled at the entry service, every downstream span is kept too — no half-traces.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Spans well-formed | `defer End()`; returned ctx propagated | Unended spans; dropped ctx severing the tree |
| Operation-named | Span names are low-cardinality operations | Names containing ids/data |
| Errors recorded | `RecordError` + `SetStatus(Error)` on failure | Failures invisible on the span |
| HTTP propagation | Context extracted inbound, injected outbound | New disconnected trace per service |
| **Broker propagation** | Trace context in message headers; consumer continues the trace | Trace severed at every async hop |
| Rich attributes | Quantitative domain attributes on spans | Bare spans with no explanatory detail |
| No PII on spans | Attributes carry ids/sizes, not secrets/PII | PII/secrets in span attributes |
| Whole-trace sampling | ParentBased sampling | Independent per-span sampling → half-traces |

---

## Output Format

Produces Go source plus tracing assertions in tests:

```
internal/infrastructure/telemetry/tracing.go      (tracer helpers, kafkaHeaderCarrier)
internal/handlers/.../*.go                          (spans in handlers/consumers)
*_test.go                                           (assert spans/attributes via tracetest)
```
