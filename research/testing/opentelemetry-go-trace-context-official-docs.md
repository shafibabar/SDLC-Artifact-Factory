# OpenTelemetry Go and W3C Trace Context: Official Documentation
**Authors:** OpenTelemetry Authors (opentelemetry.io, open-telemetry/opentelemetry-go, opentelemetry-go-contrib); W3C Distributed Tracing Working Group (w3.org)
**Domain:** Testing (end-to-end, trace correlation)

Accessed 2026-11-28. `go.opentelemetry.io/otel`, `otel/trace` and `otel/sdk` latest v1.47.0, 2026-10-02 (https://api.github.com/repos/open-telemetry/opentelemetry-go/releases/latest), Apache-2.0. `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` latest v0.72.0, released 2026-10-02 in the contrib release tagged v1.47.0 (https://api.github.com/repos/open-telemetry/opentelemetry-go-contrib/releases/latest; module version from `versions.yaml` and `otelhttp/version.go` at that tag), Apache-2.0. W3C Trace Context Level 1 is a W3C Recommendation dated 2021-11-23; Level 2 is a Candidate Recommendation Draft dated 2024-03-28.

Sources:
- [GI] https://opentelemetry.io/docs/languages/go/instrumentation/
- [GS] https://opentelemetry.io/docs/languages/go/sampling/
- [GL] https://opentelemetry.io/docs/languages/go/libraries/
- [CP] https://opentelemetry.io/docs/concepts/context-propagation/
- [otel] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/trace.go and `propagation.go` beside it
- [gt] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/internal/global/trace.go
- [gp] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/internal/global/propagator.go
- [noop] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/trace/noop.go
- [tr] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/trace/trace.go
- [tc] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/propagation/trace_context.go
- [prov] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/sdk/trace/provider.go
- [sdkt] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go/v1.47.0/sdk/trace/tracer.go
- [oh] https://raw.githubusercontent.com/open-telemetry/opentelemetry-go-contrib/v1.47.0/instrumentation/net/http/otelhttp/transport.go and `config.go` beside it
- [W1] https://www.w3.org/TR/trace-context/
- [W2] https://www.w3.org/TR/trace-context-2/

## Core Concepts

**Without an SDK, a span has no trace id**
- `otel.GetTracerProvider()`: "If none is registered then an instance of NoopTracerProvider is returned" [otel]. "all Span created prior to initialization are no-op Spans", and a span started before the SDK is registered "remains a no-op Span" afterwards [gt].
- The no-op span's `SpanContext()` "returns an empty span context" [noop]. An empty span context has an all-zero trace id, and "A valid trace ID does not consist of zeros only" [tr]. So `span.SpanContext().TraceID().String()` prints 32 zeros.
- The no-op tracer "carries forward a non-recording Span, if one is present in the context, otherwise it creates a no-op Span" [noop].

**Without a propagator, nothing is sent**
- The default global propagator is an empty composite: `propagation.NewCompositeTextMapPropagator()` with no members, until `otel.SetTextMapPropagator` is called [gp] [otel]. It injects no headers.
- "In order to propagate trace context over the wire, a propagator must be registered with the OpenTelemetry API": `otel.SetTextMapPropagator(propagation.TraceContext{})` [GI].
- The concepts page says "The default propagator uses the headers specified by the W3C TraceContext specification" [CP]; for the Go API that holds only once the propagator is registered [gp] [GI].
- `TraceContext.Inject` returns without writing when the span context is not valid [tc]. A no-op span therefore sends no `traceparent` even with the propagator set.

**SDK setup**
- `sdktrace.NewTracerProvider(opts...)`; register with `otel.SetTracerProvider(tp)`; get a tracer with `tp.Tracer("name")` or `otel.Tracer("name")`; `defer func() { _ = tp.Shutdown(ctx) }()` ("Handle shutdown properly so nothing leaks") [GI] [otel].
- Defaults: "a ParentBased(AlwaysSample) Sampler", a random id generator, `resource.Default()` [prov] [GS].
- An exporter is optional in code: span processors are added only by `WithBatcher`, `WithSyncer` or `WithSpanProcessor`, and `ForceFlush` returns nil when there are none [prov]. A provider with no processor still generates ids and samples.
- `Shutdown` shuts down the registered span processors; "After Shutdown is called, all methods are no-ops" [prov]. `ForceFlush` "immediately exports all spans that have not yet been exported" [prov].

**Spans, ids and sampling**
- `ctx, span := tracer.Start(ctx, "name")` then `defer span.End()`; the returned context carries the span [GI].
- The SDK tracer assigns ids before sampling: a new trace id and span id when the parent has no valid trace id, otherwise the parent's trace id and "Always generate a new span ID ... even if the Span is non-recording" [sdkt].
- A span that is sampled out is a non-recording span that still has a valid trace id and span id; its flags have the sampled bit cleared [sdkt]. It is still injected, as flags `00`, because injection checks only validity [tc].
- `FlagsSampled` is `0x01`; `FlagsRandom` is `0x02` (Level 2); `Inject` keeps only those two bits [tr] [tc].
- `ParentBased` "samples spans that have parents that were sampled" and does not sample those whose parents were not [GS]. A product service using a parent-based sampler follows the test's sampled flag.
- `SpanContext.IsValid()` is true when both ids are non-zero; `TraceID.String()` returns the hex form [tr].

**otelhttp client transport**
- `otelhttp.NewTransport(base, opts...)` "starts a span, injects the span context into the outbound request headers"; a nil base means `http.DefaultTransport` [oh].
- `WithPropagators`: "If this option isn't specified, then the global TextMapPropagator is used". The global is read when the transport is constructed [oh].
- The tracer comes from the provider of the span already in the request context, else `otel.GetTracerProvider()` [oh]. The request must carry the context: `http.NewRequestWithContext(ctx, ...)`.

**W3C `traceparent` and `tracestate`** [W1]
- `traceparent` = `version "-" trace-id "-" parent-id "-" trace-flags`, all lowercase hex: version 2 characters ("this document assumes version 00. Version ff is forbidden"), trace-id 32, parent-id 16, trace-flags 2. Total 55 characters.
- All-zero trace-id and all-zero parent-id are invalid. On an invalid trace-id "vendors MUST ignore the traceparent".
- Sampled is the least significant bit of trace-flags: "the caller may have recorded trace data". Level 2 adds the random-trace-id flag as the second bit [W2].
- `tracestate` is a comma-separated list of at most 32 `key=value` members; values are opaque, up to 256 printable ASCII characters; vendors "SHOULD propagate at least 512 characters". If `traceparent` fails to parse, `tracestate` must not be parsed.
- Header names are expected in any case and should be sent in lowercase.

## Actionable Techniques

- In `TestMain` or suite setup, before any tracer or transport is created: build the provider, `otel.SetTracerProvider`, `otel.SetTextMapPropagator(propagation.TraceContext{})`; defer `Shutdown` [GI] [gt] [oh].
- Give the journey's `http.Client` `Transport: otelhttp.NewTransport(nil)` and build every request with the journey context [oh].
- Start one span per journey, `defer span.End()`, and on failure print `span.SpanContext().TraceID().String()`; first assert `span.SpanContext().IsValid()` so an all-zero id fails loudly [tr] [noop].
- Keep the default sampler or `AlwaysSample` so the sampled flag is `01` and parent-based services record the trace [prov] [GS]. That the product then stores the trace is this note's inference, not a documented guarantee.
- With no exporter in the test, the test's own spans are not in the backend; the product's server spans carry the same trace id (inference from [sdkt] and [tc]).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-e2e-test | A failing journey must print a trace id that exists in the product's traces; today a span is started with no provider, no propagator and no `End()` | No-op span has an all-zero id and injects nothing; the three setup calls; the validity check |
| python-e2e-test | Same gap in the twin | The W3C header format and the validity rules are language-neutral; the Python API was not read |

## Candidate New Skills/Agents

None.

## Key Terminology

Tracer Provider, Text Map Propagator, Span Context, Non-Recording Span, Trace Flags, `traceparent`, `tracestate`.

## Caveats

- Nothing was run. No code was compiled; behaviour is read from documentation pages and from source at the tags above.
- Out of scope: how a tracing backend is queried by trace id (Tempo, Grafana or any other). Not researched here.
- Not stated in the official documentation: what happens to a span when `End()` is never called ([GI] shows `defer span.End()` and says only that a completed span is immutable). The no-provider and no-propagator behaviour is stated in source comments, not on an opentelemetry.io page.
- Not stated: a Go propagation page (https://opentelemetry.io/docs/languages/go/propagation/ returned 404); [GL] shows no `otelhttp.NewTransport` example.
- Not stated: whether a collector or backend keeps spans whose root span was never exported.
- OpenTelemetry Python was not read; the twin skill needs its own check of provider and propagator defaults.
