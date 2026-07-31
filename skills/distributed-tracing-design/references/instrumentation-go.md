# Go OpenTelemetry Tracing Instrumentation

Complete, copyable Go instrumentation for the repo stack: `go.opentelemetry.io/otel`
SDK, `chi` HTTP handlers, `pgx` repositories, and Redpanda (Kafka-protocol)
producers/consumers via `franz-go`, exporting over OTLP to Tempo. Provider *creation*
(the `TracerProvider`, resource, sampler wiring) is owned by `opentelemetry-instrumentation`;
this file shows the *tracing design applied* on top of it. Sampling and W3C propagation
theory live in `sampling-and-propagation.md`.

---

## 1. Tracer Provider and OTLP Export to Tempo

The provider is built once at startup and installed globally so `otel.Tracer(name)`
works from any package. The exporter ships spans over **OTLP gRPC to the collector on
port 4317** (the collector then forwards to Tempo); use `4318` for OTLP/HTTP if gRPC is
unavailable.

```go
package telemetry

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func InstallTracing(ctx context.Context, endpoint string, ratio float64) (func(context.Context) error, error) {
	exp, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint), // e.g. "otel-collector:4317"
		otlptracegrpc.WithInsecure(),         // Linkerd provides mTLS on the wire
	)
	if err != nil {
		return nil, err
	}

	res, _ := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName("classification-svc"),
		semconv.ServiceVersion(BuildVersion),
		semconv.DeploymentEnvironment(Env),
	))

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp), // batch spans; never SimpleSpanProcessor in prod
		sdktrace.WithResource(res),
		sdktrace.WithSampler(
			sdktrace.ParentBased(sdktrace.TraceIDRatioBased(ratio)),
		),
	)
	otel.SetTracerProvider(tp)

	// Composite propagator: W3C traceparent + baggage. MUST be set globally or
	// Inject/Extract silently do nothing.
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{},
	))
	return tp.Shutdown, nil // call on graceful shutdown to flush the batcher
}
```

`tp.Shutdown` flushes the batch processor — wire it into the same `errgroup`-supervised
shutdown path as the HTTP server (`go-service-skeleton`) so in-flight spans are not lost.

---

## 2. Span Kinds — Full Reference

The span kind tells the backend how to interpret the span in the trace topology and is
what lets it stitch a remote parent to its child.

| Kind | Constant | Use for |
|---|---|---|
| SERVER | `trace.SpanKindServer` | Inbound request handling (HTTP server span, set by middleware) |
| CLIENT | `trace.SpanKindClient` | Outbound calls: DB query, external HTTP, broker produce call |
| PRODUCER | `trace.SpanKindProducer` | Publishing a message to Redpanda |
| CONSUMER | `trace.SpanKindConsumer` | Receiving a message from Redpanda |
| INTERNAL | `trace.SpanKindInternal` | In-process work: command handlers, domain operations |

`SERVER`/`CLIENT` pair across a synchronous call; `PRODUCER`/`CONSUMER` pair across the
broker. Getting the kind wrong (e.g. an `INTERNAL` produce) leaves the topology view unable
to draw the service-to-service edge.

---

## 3. Command Handler Span (INTERNAL) with Attributes and Error Recording

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
	ctx, span := h.tracer.Start(ctx, "ClassifyDataAsset.Handle",
		trace.WithSpanKind(trace.SpanKindInternal),
		trace.WithAttributes(
			attribute.String("data_asset.id", cmd.DataAssetID.String()),
			attribute.String("tenant.id", cmd.TenantID.String()),
			attribute.String("sensitivity.level", string(cmd.Sensitivity)),
		),
	)
	defer span.End() // ALWAYS deferred immediately — ends on panic/return alike

	span.AddEvent("classification.started")

	if err := h.repo.Save(ctx, asset); err != nil { // pass ctx down — child inherits parent
		span.RecordError(err)
		span.SetStatus(codes.Error, "save failed") // RecordError alone does NOT mark failed
		return err
	}

	span.SetAttributes(attribute.Int("rules.matched", len(matches)))
	span.SetStatus(codes.Ok, "")
	return nil
}
```

### Attribute Conventions

- **Semantic conventions** come from the `semconv` package — `semconv.HTTPRoute(route)`,
  `semconv.DBSystemPostgreSQL`, `semconv.MessagingSystem("kafka")` — never hand-typed
  strings, which drift and break backend queries.
- **Domain attributes** use dotted, namespaced keys: `data_asset.id`, `tenant.id`,
  `sensitivity.level`, `batch.size`, `outbox.batch_size`.
- **Causal attributes** carry the choreography chain: `event.id`, `correlation.id`,
  `causation.id`.
- **Span events** (`span.AddEvent`) mark a point in time within a span — a retry attempt,
  a cache miss, a validation failure: `span.AddEvent("retry", trace.WithAttributes(attribute.Int("attempt", n)))`.

**Never** put secrets or PII (file paths, emails, document bytes) on a span — spans export
to Tempo, a separate store with its own retention. Ids and sizes only.

---

## 4. HTTP Server and Client Propagation (chi)

Inbound extraction and the SERVER span are handled by one middleware wrapping the chi
router (see `go-middleware`). `otelhttp` reads the `traceparent` header off the request and
makes the remote span the parent of everything downstream.

```go
// Inbound: wrap the whole chi mux once. otelhttp extracts traceparent + starts a SERVER span.
r := chi.NewRouter()
handler := otelhttp.NewHandler(r, "http.server",
	otelhttp.WithSpanNameFormatter(func(_ string, req *http.Request) string {
		return req.Method + " " + chi.RouteContext(req.Context()).RoutePattern() // low-cardinality
	}),
)

// Outbound: wrap the client transport so every request INJECTS the current context.
client := &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}
```

The `SpanNameFormatter` uses the chi *route pattern* (`/assets/{id}`), never the concrete
path (`/assets/6f9a…`) — otherwise every request id mints a new span name.

---

## 5. Broker Propagation — the Carrier Adapter (the crucial part)

An async boundary breaks a trace unless the W3C context rides in the **message headers**.
OTel propagators speak the `TextMapCarrier` interface (`Get`/`Set`/`Keys`); the adapter
below bridges that to `franz-go`'s `[]kgo.RecordHeader`.

```go
// kafkaHeaderCarrier adapts a Kafka record's headers to OTel's TextMapCarrier.
type kafkaHeaderCarrier struct{ rec *kgo.Record }

func (c kafkaHeaderCarrier) Get(key string) string {
	for _, h := range c.rec.Headers {
		if h.Key == key {
			return string(h.Value)
		}
	}
	return ""
}

func (c kafkaHeaderCarrier) Set(key, val string) {
	// overwrite if present, else append
	for i := range c.rec.Headers {
		if c.rec.Headers[i].Key == key {
			c.rec.Headers[i].Value = []byte(val)
			return
		}
	}
	c.rec.Headers = append(c.rec.Headers, kgo.RecordHeader{Key: key, Value: []byte(val)})
}

func (c kafkaHeaderCarrier) Keys() []string {
	keys := make([]string, len(c.rec.Headers))
	for i, h := range c.rec.Headers {
		keys[i] = h.Key
	}
	return keys
}
```

### Producer (outbox relay — see `go-event-publisher`)

```go
func publish(ctx context.Context, cl *kgo.Client, rec *kgo.Record) error {
	ctx, span := tracer.Start(ctx, "produce "+rec.Topic,
		trace.WithSpanKind(trace.SpanKindProducer),
		trace.WithAttributes(
			semconv.MessagingSystem("kafka"),
			semconv.MessagingDestinationName(rec.Topic),
		),
	)
	defer span.End()

	otel.GetTextMapPropagator().Inject(ctx, kafkaHeaderCarrier{rec}) // writes traceparent header
	if err := cl.ProduceSync(ctx, rec).FirstErr(); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "produce failed")
		return err
	}
	return nil
}
```

### Consumer (see `go-event-consumer`)

```go
func consume(ctx context.Context, rec *kgo.Record) {
	ctx = otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec}) // read traceparent -> SAME trace
	ctx, span := tracer.Start(ctx, "consume "+rec.Topic,
		trace.WithSpanKind(trace.SpanKindConsumer),
		trace.WithAttributes(
			semconv.MessagingSystem("kafka"),
			semconv.MessagingSourceName(rec.Topic),
		),
	)
	defer span.End()
	// ... handle; RecordError + SetStatus(Error) on failure, then route to DLQ.
}
```

With this, one trace spans the API request, the outbox relay, the broker hop, and every
downstream pipeline stage — one connected trace across the whole choreography.

---

## 6. pgx Repository Span (CLIENT)

Wrap queries so DB latency is a visible child of the handler span.

```go
func (r *DataAssetRepo) Save(ctx context.Context, a *DataAsset) error {
	ctx, span := r.tracer.Start(ctx, "repo.DataAsset.Save",
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(semconv.DBSystemPostgreSQL, semconv.DBOperationName("INSERT")),
	)
	defer span.End()

	_, err := r.pool.Exec(ctx, insertSQL, a.ID, a.TenantID, a.Sensitivity)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "insert failed")
	}
	return err
}
```

`otelpgx` (`github.com/exaring/otelpgx`) can auto-instrument the pool via a
`QueryTracer` if you prefer not to hand-wrap every method; either way the DB span must be a
child of the caller's context.

---

## 7. Testing Spans with `tracetest`

Assert spans and attributes deterministically with an in-memory exporter — no collector,
no Tempo.

```go
func TestHandle_RecordsSpan(t *testing.T) {
	exp := tracetest.NewInMemoryExporter()
	tp := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exp))
	h := &ClassifyDataAssetHandler{tracer: tp.Tracer("test"), repo: fakeRepo{}}

	_ = h.Handle(context.Background(), ClassifyDataAsset{DataAssetID: id})

	spans := exp.GetSpans()
	require.Len(t, spans, 1)
	assert.Equal(t, "ClassifyDataAsset.Handle", spans[0].Name)
	assert.Equal(t, codes.Ok, spans[0].Status.Code)
	assert.Contains(t, spans[0].Attributes, attribute.String("data_asset.id", id.String()))
}
```

Use `WithSyncer` (not the batcher) in tests so spans are exported synchronously and are
readable immediately after the call returns.

---

## 8. File Layout Produced

```
internal/infrastructure/telemetry/tracing.go   TracerProvider install, kafkaHeaderCarrier, tracer helpers
internal/handlers/.../*.go                       spans in command handlers and consumers
internal/repository/*.go                         CLIENT spans on pgx calls
internal/messaging/publisher.go                  PRODUCER span + Inject
internal/messaging/consumer.go                   CONSUMER span + Extract
*_test.go                                         tracetest assertions on span name/status/attributes
```
