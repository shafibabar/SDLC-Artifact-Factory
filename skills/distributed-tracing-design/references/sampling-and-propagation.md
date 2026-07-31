# Sampling and W3C Context Propagation in Depth

Head vs tail sampling, how to pick the rate, the W3C `traceparent` wire format, propagating
context across synchronous (HTTP) and asynchronous (Redpanda) boundaries, carrying trace
context on domain events, and the cost/cardinality tradeoffs that make sampling necessary.
Grounded in the repo stack (Go OTel SDK, OpenTelemetry Collector, Tempo) and the SRE
golden-signals discipline. Instrumentation code is in `instrumentation-go.md`.

---

## 1. Why Sample at All — the Cost/Cardinality Tradeoff

A trace is not free. Every retained span is bytes on the wire (OTLP export), CPU in the
collector, and storage plus index cardinality in Tempo. At even modest traffic, tracing
100% of production is both expensive and low-value: the thousandth identical successful
`GET /assets/{id}` trace tells you nothing the first did not. The SRE golden-signals
framing (Beyer/Jones/Petoff/Murphy, Ch. 6 — latency, traffic, errors, saturation) is the
guide to what *is* worth keeping: the slow ones, the failing ones, and a representative
baseline of the normal ones. Sampling is how you keep that signal while dropping the
redundant bulk.

Two independent decisions follow from this:

1. **How much of normal traffic to keep** — a *head* decision, made cheaply up front.
2. **Whether to always keep the interesting traces** (errors, high latency) — a *tail*
   decision, which can only be made once the trace is finished.

---

## 2. Head Sampling — `ParentBased(TraceIDRatioBased(r))`

Head sampling decides at span creation, before the outcome is known. In the Go SDK:

```go
sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.05))) // keep 5%
```

- **`TraceIDRatioBased(r)`** keeps a deterministic fraction `r` of traces by hashing the
  trace id — deterministic so the *same* trace id yields the *same* decision everywhere.
- **`ParentBased(...)`** is the essential wrapper: if a parent span already made a sampling
  decision (arrived via `traceparent`), **follow it**; only apply the ratio when *this*
  service is the root. Without `ParentBased`, each service samples independently and you get
  traces with **missing middles** — service A kept its spans, service B dropped its, and the
  trace has a hole exactly where you need to look. A trace with a missing middle is worse
  than no trace.

`ParentBased` has sub-samplers for each relationship (`WithRemoteParentSampled`,
`WithRemoteParentNotSampled`, `WithLocalParentSampled`, …); the defaults — honor the parent
in every case — are correct and rarely need overriding.

### Picking the Rate `r`

| Environment | Rate | Rationale |
|---|---|---|
| Local / dev | 1.0 (100%) | You are debugging a specific flow; keep everything |
| Staging / CI | 1.0 (100%) | Low traffic; full traces make integration failures diagnosable |
| Production, low QPS (< ~50/s) | 0.1–0.5 | Volume is affordable; keep a rich sample |
| Production, high QPS | 0.01–0.05 | Cost dominates; a small representative baseline is enough — errors are caught separately by tail sampling |

Start conservative and adjust from the collector's own metrics (exported span rate, refusal
rate) and Tempo's ingest cost. The rate is a *dial*, tuned against observed cost, not a
constant to guess once.

---

## 3. Tail Sampling — Keep Every Interesting Trace

Head sampling has one fatal blind spot: at span-creation time you do **not** know whether
the trace will error or run slow. If you head-sample at 5%, you drop 95% of your errors too.
**Tail sampling** solves this by buffering complete traces in the OpenTelemetry Collector
and deciding *after* the whole trace is assembled.

Collector `tail_sampling` processor (grounded in the repo's collector deployment):

```yaml
processors:
  tail_sampling:
    decision_wait: 10s          # how long to buffer a trace before deciding
    num_traces: 100000          # in-memory trace buffer size
    policies:
      - name: keep-errors
        type: status_code
        status_code: { status_codes: [ERROR] }   # every trace with an ERROR-status span
      - name: keep-slow
        type: latency
        latency: { threshold_ms: 800 }            # every trace slower than the latency SLO
      - name: baseline
        type: probabilistic
        probabilistic: { sampling_percentage: 5 } # a 5% representative sample of the rest
```

The `keep-errors` policy is what makes the **error/status rule** in the skill body pay off:
because handlers call `span.SetStatus(codes.Error, …)` on failure, the collector can select
exactly the failed executions and retain 100% of them regardless of the head rate. The
`keep-slow` threshold is deliberately aligned to the latency SLO (`slo-definition`) so every
SLO-violating request is inspectable.

**Head + tail together** is the production recipe: head sampling caps the raw volume cheaply;
tail sampling rescues the errors and slow traces the head stage would otherwise have thrown
away. Tail sampling requires all spans of a trace to reach the *same* collector instance —
use a trace-id-aware load-balancing exporter in front of a collector pool.

---

## 4. The W3C `traceparent` Wire Format

Context crosses a boundary as the W3C Trace Context standard's `traceparent` HTTP/message
header. It is a single ASCII string of four hyphen-delimited fields:

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                │
             │  │                                │                └─ trace-flags (2 hex)
             │  │                                └─ parent-id / span-id (16 hex, 8 bytes)
             │  └─ trace-id (32 hex, 16 bytes) — globally unique per trace
             └─ version (2 hex, currently 00)
```

| Field | Size | Meaning |
|---|---|---|
| version | 1 byte (2 hex) | Format version, `00` today |
| trace-id | 16 bytes (32 hex) | Identifies the whole trace; constant across every span |
| parent-id | 8 bytes (16 hex) | The calling span's id; becomes the new span's parent |
| trace-flags | 1 byte (2 hex) | Bit 0 is the **sampled** flag: `01` = sampled, `00` = not |

The **sampled bit** in `trace-flags` is exactly what `ParentBased` reads to honor the
upstream decision — this is the wire-level mechanism behind whole-trace sampling. An
optional companion `tracestate` header carries vendor-specific key/values; OTel manages both
via the `propagation.TraceContext{}` propagator, so application code never parses these
strings by hand — it calls `Inject`/`Extract`.

---

## 5. Propagation Across Synchronous Boundaries (HTTP)

On a synchronous call the header rides on the request:

1. **Client** — `otelhttp.NewTransport` calls `propagator.Inject(ctx, headerCarrier)` which
   serializes the active span into the outgoing `traceparent` request header.
2. **Server** — `otelhttp.NewHandler` calls `propagator.Extract(ctx, headerCarrier)` which
   parses `traceparent` back into a remote span context, then starts a SERVER span whose
   parent is that remote span.

The chain is unbroken as long as **both** ends share the same globally-set propagator
(`otel.SetTextMapPropagator`). The single most common cause of "a new disconnected trace per
service" is forgetting to set the global propagator — `Inject`/`Extract` then no-op silently.

---

## 6. Propagation Across Asynchronous Boundaries (Redpanda)

The async boundary is where traces break by default: producer and consumer are different
processes at different times, with no shared call stack. The context survives **only** if it
is written into the message and read back out:

- **Producer** injects the current context into the record's Kafka headers before publishing
  (`Inject(ctx, kafkaHeaderCarrier{rec})`), inside a `PRODUCER` span.
- **Consumer** extracts it from the record's headers before handling
  (`Extract(ctx, kafkaHeaderCarrier{rec})`), then starts a `CONSUMER` span that continues the
  **same** trace.

Because the outbox relay (`go-event-publisher`) is what actually produces to Redpanda, the
`traceparent` written into the message headers is the context of the relay's produce span,
which itself descends from the original API request — so the trace is continuous from HTTP
request → outbox → broker → consumer.

### Trace Context on Domain Events — Headers, Not Payload

Carry trace context in **message/transport headers**, never inside the domain event's JSON
payload. Two reasons:

1. The event schema (`event-schema-design`) is a consumer-facing contract; trace ids are
   transport concerns and must not pollute it or force a schema version bump.
2. Header propagation is what OTel's `TextMapCarrier` targets, so it works with zero custom
   parsing.

The event body still carries **`correlation_id` / `causation_id`** as first-class domain
fields — those are business-meaningful lineage, distinct from and complementary to the
transport `traceparent`. A consumer sets `causation_id` on any event it emits to the id of
the event it is reacting to, giving a business-level causal chain that survives even when a
trace is not sampled.

### Span Links for Fan-In

Parent/child is one-to-one, but a **batch consumer** pulling many messages has many logical
parents. Model this with **span links**, not a single parent: the batch-processing span
`links` to each message's producing span context, so the trace backend can still navigate
from any source trace to the batch that consumed it.

```go
links := make([]trace.Link, 0, len(recs))
for _, rec := range recs {
	rctx := otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec})
	links = append(links, trace.Link{SpanContext: trace.SpanContextFromContext(rctx)})
}
ctx, span := tracer.Start(ctx, "consume.batch",
	trace.WithSpanKind(trace.SpanKindConsumer), trace.WithLinks(links...))
```

Use a real parent when one message clearly causes the work; use links when the relationship
is many-to-one or merely associative.

---

## 7. Decision Summary

| Question | Answer |
|---|---|
| Head or tail? | Both: head to cap volume cheaply, tail to rescue errors + slow traces |
| Which head sampler? | `ParentBased(TraceIDRatioBased(r))` — always `ParentBased` |
| Prod rate `r`? | 0.01–0.05 high-QPS, 0.1–0.5 low-QPS; 1.0 non-prod; tune against cost |
| Tail policies? | `status_code=ERROR` (all errors), `latency>=SLO` (all slow), small probabilistic baseline |
| Wire format? | W3C `traceparent`: version-traceid-parentid-**trace-flags**, sampled bit in flags |
| Where does context ride on events? | Kafka message **headers** via `kafkaHeaderCarrier`, never the payload |
| Fan-in from many messages? | **Span links**, one per source, not a single parent |
