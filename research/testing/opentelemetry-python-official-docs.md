# OpenTelemetry Python: Official Documentation
**Authors:** OpenTelemetry Authors (opentelemetry.io, open-telemetry/opentelemetry-python, opentelemetry-python-contrib)
**Domain:** Testing (end-to-end, trace correlation, Python)

Accessed 2026-11-28. `opentelemetry-api` and `opentelemetry-sdk` latest 1.45.2, 2026-10-29, Apache-2.0, Python >=3.10, "Production/Stable" (https://pypi.org/pypi/opentelemetry-api/1.45.2/json, https://pypi.org/pypi/opentelemetry-sdk/1.45.2/json); source read at tag `v1.45.2`. `opentelemetry-instrumentation-httpx` latest 0.66b2, 2026-10-29, Apache-2.0, Python >=3.10, classifier "Development Status :: 4 - Beta", requires `opentelemetry-api~=1.12` and `httpx>=0.18.0` (https://pypi.org/pypi/opentelemetry-instrumentation-httpx/0.66b2/json); source read at tag `v0.66b2`. The `traceparent` format and W3C validity rules are in `opentelemetry-go-trace-context-official-docs.md` and are not repeated here.

Sources:
- [PI] https://opentelemetry.io/docs/languages/python/instrumentation/
- [PP] https://opentelemetry.io/docs/languages/python/propagation/
- [tr] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-api/src/opentelemetry/trace/__init__.py
- [sp] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-api/src/opentelemetry/trace/span.py
- [pr] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-api/src/opentelemetry/propagate/__init__.py
- [tc] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-api/src/opentelemetry/trace/propagation/tracecontext.py
- [cv] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-api/src/opentelemetry/context/contextvars_context.py
- [sdk] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-sdk/src/opentelemetry/sdk/trace/__init__.py
- [sam] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python/v1.45.2/opentelemetry-sdk/src/opentelemetry/sdk/trace/sampling.py
- [hx] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python-contrib/v0.66b2/instrumentation/opentelemetry-instrumentation-httpx/src/opentelemetry/instrumentation/httpx/__init__.py
- [hp] https://pypi.org/pypi/opentelemetry-instrumentation-httpx/0.66b2/json (package description)

## Core Concepts

**Without an SDK, a span has no trace id**
- `trace.get_tracer(...)` uses the global provider; when none has been set in code or through `OTEL_PYTHON_TRACER_PROVIDER` it returns "a proxy tracer provider" [tr].
- A `ProxyTracer` uses a no-op tracer until a real provider is set, then delegates to it; it re-checks on each use [tr]. Unlike Go, a tracer obtained before setup starts working after setup; a span already started stays as it was.
- The no-op tracer's `start_span` returns the current span if it is non-recording, otherwise a `NonRecordingSpan` over the parent span context; with no parent that is the invalid context [tr].
- `INVALID_SPAN_CONTEXT` has trace id `0x0…0` and span id `0x0…0`; `INVALID_SPAN = NonRecordingSpan(INVALID_SPAN_CONTEXT)`; `SpanContext.is_valid` is false for it [sp].
- `format_trace_id(trace_id)` is `format(trace_id, "032x")`, "a 32-character hexadecimal string"; `format_span_id` gives 16 [sp]. On the invalid context it prints 32 zeros.
- The instrumentation page does not use the word no-op; it says only that an API-only library "will not emit telemetry on its own" [PI].

**The propagator is set by default (differs from Go)**
- The global propagator is built at import of `opentelemetry.propagate` from `OTEL_PROPAGATORS`; the default value is `tracecontext,baggage`, giving a `CompositePropagator([TraceContextTextMapPropagator(), W3CBaggagePropagator()])`. The value `none` removes all propagators [pr].
- `opentelemetry.propagate.inject(carrier, context=None, setter=default_setter)`: "Uses the configured propagator to inject a Context into the carrier"; context "Defaults to current context if not set" [pr].
- The trace-context `inject` returns without writing when the span context equals `INVALID_SPAN_CONTEXT`; it checks validity only, not `is_recording` [tc]. So with no SDK nothing is sent, and a sampled-out span with a valid context is still sent.
- The propagation page names no default; its examples build `TraceContextTextMapPropagator()` explicitly and inject into a plain dict [PP].

**SDK setup**
- Documented form: `provider = TracerProvider()`, `provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))`, `trace.set_tracer_provider(provider)`, `tracer = trace.get_tracer("my.tracer.name")` [PI].
- `set_tracer_provider`: "This can only be done once, a warning will be logged if any further attempt is made" ("Overriding of current TracerProvider is not allowed") [tr].
- A span processor is optional: with none the provider holds an empty multi-processor and still generates ids [sdk]. Defaults: `RandomIdGenerator()`, `Resource.create({})`, sampler from the environment [sdk].
- Default sampler: `OTEL_TRACES_SAMPLER` defaults to `parentbased_always_on`, "respects its parent span's sampling decision, but otherwise always samples" [sam].
- `shutdown()` shuts down "the span processors added to the tracer provider"; `shutdown_on_exit=True` by default registers it with `atexit`; `force_flush(timeout_millis=30000)` is also available [sdk]. The opentelemetry.io page does not cover shutdown [PI].
- `OTEL_SDK_DISABLED=true` makes the SDK provider return a no-op tracer [sdk].

**Spans and ids**
- `with tracer.start_as_current_span("name") as span:` makes the span current; "When the 'with' block goes out of scope, 'span' is closed for you" [PI]. `end_on_exit` defaults to true, as do `record_exception` and `set_status_on_exception` [tr].
- A root span gets `id_generator.generate_trace_id()`; a child reuses the parent's trace id. A sampled-out span is a `NonRecordingSpan` over a valid context without the sampled flag [sdk].
- Read the id with `span.get_span_context().trace_id` and print it with `format_trace_id` [sp].
- The current context is stored in a `ContextVar` named `current_context` [cv]. How the current span behaves across asyncio tasks is not stated on the opentelemetry.io page; it says only that `start_span` (not current) "is usually done to track concurrent or asynchronous operations" [PI].

**httpx instrumentation (0.66b2, beta)**
- Three forms, exact names: `HTTPXClientInstrumentor().instrument()` ("all clients will automatically trace requests"); `HTTPXClientInstrumentor.instrument_client(client)` for one existing client; and `SyncOpenTelemetryTransport(transport)` / `AsyncOpenTelemetryTransport(transport)` passed as `transport=` [hp] [hx].
- `instrument()` wraps `HTTPTransport.handle_request` and `AsyncHTTPTransport.handle_async_request` on the httpx classes, not individual clients [hx]. The documentation states no ordering rule; its example instruments before creating clients [hp].
- Because only those two classes are wrapped, a client built on another transport (a mock, ASGI or custom transport) is not covered by `instrument()`; `instrument_client` wraps that client's own `_transport` and each mount [hx].
- Each request runs inside a `SpanKind.CLIENT` span and `inject(headers)` is called on the request headers with the global propagator; the description page itself makes no statement about header injection [hx] [hp].
- The tracer provider is the `tracer_provider` argument, else the global one [hx].
- The package also ships `httpx2` variants (`HTTPX2ClientInstrumentor`, `SyncOpenTelemetryTransportHttpx2`) [hp].

## Actionable Techniques (design is this note's)

- In a session fixture: `provider = TracerProvider()`, `trace.set_tracer_provider(provider)`, yield, then `provider.shutdown()`. No exporter is needed to obtain real ids.
- Wrap the journey client explicitly (`instrument_client(client)` or the transport classes) rather than relying on global patching, so custom transports are covered.
- Keep every request inside `with tracer.start_as_current_span("journey") as span:`; the span must still be current when the request is sent.
- On failure print `format_trace_id(span.get_span_context().trace_id)`; first assert `span.get_span_context().is_valid` so 32 zeros fail loudly.
- Leave `OTEL_PROPAGATORS` and `OTEL_TRACES_SAMPLER` unset in the test process, or assert their values, since `none` or an off sampler silently changes what is sent.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-e2e-test | A failing journey must print a trace id the product actually received | Provider setup, default propagator already W3C, injection needs a valid current span, `format_trace_id`, validity check |
| python-e2e-test | The current skill has no tracer provider and ends the span before any request | No-op span is all zeros and injects nothing; `start_as_current_span` ends the span on exit of the `with` block, so requests go inside it |
| python-e2e-test | Which client calls carry `traceparent` | The three httpx forms and what `instrument()` does and does not wrap |

## Candidate New Skills/Agents

None.

## Key Terminology

Tracer Provider, Proxy Tracer, Non-Recording Span, Span Context, Composite Propagator, Parent-Based Sampler.

## Caveats

- Nothing was run. No package was installed; behaviour is read from documentation pages and from source at the tags above.
- Most answers here come from source and docstrings, not opentelemetry.io pages: the Python pages do not state the default propagator, the no-SDK behaviour, shutdown, or async context handling.
- Not stated in the official documentation: whether `instrument()` must precede client creation. Source suggests order does not matter for standard transports; confirm by a run.
- Not stated: whether the httpx instrumentation is tested against httpx 0.29.0 (released 2026-11-26, after 0.66b2); the requirement is only `httpx>=0.18.0`.
- Not stated: whether a backend keeps the product's spans when the test's root span is never exported (same open point as the Go note).
- The instrumentation is beta (`0.66b2`); names may change, so pin the version.
