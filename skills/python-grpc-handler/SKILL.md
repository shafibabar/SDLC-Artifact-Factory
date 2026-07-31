---
name: python-grpc-handler
description: >
  Teaches the backend-engineer to implement a gRPC server in Python — grpcio
  async server from generated stubs, unary and streaming interceptors (the
  python-middleware analog: auth/logging/OTel/recovery), the four call types,
  the status/error code model, deadlines/cancellation/metadata, health checks,
  and Linkerd+gRPC per-request L7 balancing for long-lived HTTP/2. The Python
  analog of go-grpc-handler.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, grpc, python, grpcio, asyncio, interceptor, streaming, server]
related: [go-grpc-handler, grpc-contract-design, python-fastapi-handler, python-middleware]
tools: [Bash]
---

# Python gRPC Handler

## Purpose

A gRPC server method is the transport edge for internal service-to-service traffic, exactly as a FastAPI route is the edge for the public REST surface. Its only job is to translate between the RPC and the application layer: it receives an already-typed, generated request message (no JSON decode — `grpc_tools.protoc` produced the type), validates its structure, `await`s the relevant command/query handler, and returns the generated response message or maps the error to a gRPC status. It contains no business logic and no persistence — the same thin **Humble Object** discipline `python-fastapi-handler` teaches at the HTTP boundary, translated to gRPC.

This skill owns the Python server-side implementation on `grpc.aio` (the asyncio server, matching this repo's async stack: FastAPI + asyncpg + aiokafka). The `.proto` contract itself — `service`/`message` authoring, field numbering, method shape — is `grpc-contract-design`'s. The composition root that constructs the server is `python-service-skeleton`'s. gRPC is for **internal** transport only; the public/browser-facing data-estate API stays REST + OpenAPI (`python-fastapi-handler`), because browsers cannot speak native gRPC without a gRPC-Web proxy.

---

## Server Setup From Generated Stubs

`python -m grpc_tools.protoc` (from the `grpcio-tools` package) compiles the `.proto` into `dataasset_pb2.py` (messages) and `dataasset_pb2_grpc.py` (the `DataAssetServiceServicer` base class plus `add_DataAssetServiceServicer_to_server`). The server is a class subclassing that generated servicer, with every RPC an `async def`. Build the transport with `grpc.aio.server(interceptors=[...])`, register with `add_..._to_server`, `add_insecure_port` (TLS terminates at the Linkerd proxy), `await server.start()`, `await server.wait_for_termination()`. Regeneration is a build step, run via the Bash tool — always pass `--pyi_out` so mypy can check message field usage (the generated `_pb2.py` is otherwise untyped; see the honest divergence in "Errors"). Full server, registration, and graceful `server.stop(grace)`: `references/server-and-interceptors.md`.

---

## Interceptors: the python-middleware Analog

Cross-cutting concerns do **not** go in the method body — they go in interceptors, the role the Starlette middleware chain plays at the REST edge. Here is the first honest divergence from Go: `grpc.aio` gives you **one** hook, `ServerInterceptor.intercept_service(continuation, handler_call_details)`, not Go's two clean `UnaryServerInterceptor`/`StreamServerInterceptor` signatures. To observe the actual call you `await continuation(...)` for the `RpcMethodHandler`, then re-wrap its behaviour by dispatching on its `request_streaming`/`response_streaming` flags. That re-wrapping helper is written once and shared by every interceptor.

| Concern | Notes |
|---|---|
| Auth-token validation, tenant extraction | first in chain; read `handler_call_details.invocation_metadata`; `context.abort(UNAUTHENTICATED/PERMISSION_DENIED)` before the method runs |
| Request/response logging, metrics | record method, code, latency after the behaviour returns |
| OpenTelemetry trace propagation | prefer the community OpenTelemetry gRPC async instrumentation over hand-rolling (named in the reference) |
| Panic recovery | **outermost** so it wraps all others; catch `Exception` → `context.abort(INTERNAL, ...)`; never let it leak a traceback |

Because there is no `context.WithValue` equivalent, the authenticated tenant is carried across `await` boundaries in a `contextvars.ContextVar` set inside the interceptor — the same mechanism (and the same weak-encapsulation honesty) `python-middleware` uses for request-scoped state. Register interceptors in a list on `grpc.aio.server`; order is outermost-first — recovery, tracing, auth, logging. Full `_wrap_rpc_behavior` helper and all four interceptors: `references/server-and-interceptors.md`.

---

## The Four Call Types

Choose the method shape from the data flow, not habit — default to unary unless streaming earns its keep (it complicates retries and load balancing). In `grpc.aio` the streaming shapes are natural async generators/iterators, which is genuinely cleaner than Go's `stream.Send`/`stream.Recv` loop.

| Shape | proto | Python server side | Fits |
|---|---|---|---|
| **Unary** | `rpc Get(Req) returns (Resp)` | `async def`, `return resp` | request/response commands and point reads — the default |
| **Server streaming** | `rpc Scan(Req) returns (stream Resp)` | `async def` **generator**, `yield resp` | large/open-ended result sets — a scan emitting `DataAsset`s as discovered |
| **Client streaming** | `rpc Ingest(stream Req) returns (Resp)` | `async for chunk in request_iterator`, `return resp` | large uploads assembled server-side — chunked document ingest |
| **Bidirectional** | `rpc Progress(stream Req) returns (stream Resp)` | `async for` + `yield` | independent concurrent read/write — a live progress channel |

Check `context.cancelled()` / honour `CancelledError` between yields so a cancelled client stops server work. Worked handler for each of the four shapes: `references/call-types-errors-mesh.md`.

---

## Errors: One Status Writer

Map domain errors to gRPC status codes through a single writer, exactly as `python-fastapi-handler` maps domain errors to HTTP status through one `@app.exception_handler`. Never let a bare `Exception` escape (it becomes an opaque `UNKNOWN`), never leak an internal string. The gRPC status model is its own enum (`grpc.StatusCode.OK`, `INVALID_ARGUMENT`, `NOT_FOUND`, `ALREADY_EXISTS`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `FAILED_PRECONDITION`, `OUT_OF_RANGE`, `RESOURCE_EXHAUSTED`, `DEADLINE_EXCEEDED`, `UNAVAILABLE`, `INTERNAL`, …), richer than HTTP — `INVALID_ARGUMENT` vs `FAILED_PRECONDITION` vs `OUT_OF_RANGE` distinguish failures that all collapse to `400` in REST. Reserve `INTERNAL` for genuine bugs. Raise a status with `await context.abort(code, details)`. Attach machine-readable structured detail (a `google.rpc.BadRequest`) via the `grpcio-status` package rather than stuffing context into the string.

**Honest divergence — static safety:** the generated `_pb2.py` stubs are untyped Python; mypy cannot check message field access without `--pyi_out` stubs (or `mypy-protobuf`). Just as `python-fastapi-handler` makes mypy a CI-breaking gate, a `python-grpc-*` service must generate `.pyi` stubs and keep mypy green, or it has a materially weaker static-safety story than the compiler-checked Go baseline. Full domain-error → `StatusCode` table and the `grpcio-status` detail example: `references/call-types-errors-mesh.md`.

---

## Deadlines, Cancellation, Metadata

Every gRPC call carries a **deadline** — an absolute time propagated from the client, distinct from an ad-hoc client-local timeout. Server-side, `context.time_remaining()` returns the seconds left and `context.cancelled()` reports a cancelled/expired call; an expired deadline surfaces as `asyncio.CancelledError` in the awaited handler. Treat a cancelled call as a **hard stop** — check it in long loops and streaming yields. Here Python diverges from Go honestly: there is no single `context.Context` carrying cancellation *and* values together — cancellation rides `asyncio` while request-scoped values (tenant ID, trace span) ride a `contextvars.ContextVar` set in the auth interceptor. **Metadata** is the gRPC header channel — read incoming with `context.invocation_metadata()` (or `handler_call_details.invocation_metadata` in an interceptor); it carries the auth token, the tenant ID (per-tenant physical isolation), and the OpenTelemetry trace context. Never trust a tenant ID from the request message body; read it from validated metadata in the auth interceptor. Worked deadline-honouring handler: `references/call-types-errors-mesh.md`.

---

## Health Checks and the Linkerd HTTP/2 Caveat

Expose the standard gRPC health service from the `grpcio-health-checking` package (`grpc_health.v1.health.aio.HealthServicer`, `add_HealthServicer_to_server`, `await servicer.set(service, SERVING)`) so Kubernetes and the mesh can probe readiness — the gRPC analog of `health-check-design`'s HTTP `/healthz`. Register it unauthenticated on the same server.

The **Linkerd + gRPC caveat is a real operational gotcha, not a formality** — and it is language-agnostic, identical to the Go sibling. gRPC multiplexes many requests over one long-lived HTTP/2 connection, so a plain Kubernetes `Service` (or any L4/connection-level balancer) pins *all* of a client's traffic to the single backend pod it first connected to — load does not spread, and scaling the Deployment does nothing. Linkerd's proxy does per-**request** L7 balancing over HTTP/2, which is precisely why the mesh matters for gRPC; bypassing it silently loses load distribution. A Python-specific note: one `grpc.aio` server runs on one asyncio event loop per process, so multi-core scaling means multiple pods/processes — which makes correct per-request mesh balancing across those replicas matter even more. Verify traffic actually spreads across pods rather than assuming the Service does it. Config note and details: `references/call-types-errors-mesh.md`.

---

## Quality Criteria

- The method body is thin — validate → `await` application layer → return generated message or abort with a mapped status. No business logic, no persistence, no direct DB access.
- All cross-cutting concerns are in interceptors registered once; the panic-recovery interceptor is outermost.
- Every error leaves through the one status writer as a deliberate `grpc.StatusCode`; `INTERNAL` only for genuine bugs; no leaked internal strings.
- Tenant ID and trace context are read from validated metadata into a `contextvars.ContextVar`, never from the request body.
- Streaming methods check `context.cancelled()` and honour deadlines/cancellation as a hard stop.
- Generated stubs are regenerated with `--pyi_out` and mypy is a CI-breaking gate.
- The gRPC health service is registered; the service runs inside the Linkerd mesh for per-request L7 balancing.

---

## Anti-Patterns

- **Business logic in the method body** — move it to `python-service-layer`; the method is a Humble Object.
- **Cross-cutting concern repeated per method** instead of an interceptor — that is what interceptors are for.
- **Letting a bare `Exception` escape** a method — it becomes an opaque `UNKNOWN`; always abort through the status writer.
- **Reading the tenant ID from the request message** instead of validated metadata — a tenancy-isolation hole.
- **Reading tenant/trace state from a module-level global** instead of a `contextvars.ContextVar` — leaks state across concurrently-scheduled coroutines.
- **Skipping `--pyi_out`/mypy** — the generated stubs go unchecked and the static-safety story collapses.
- **Running gRPC through a plain K8s Service without L7-aware balancing** — pins all traffic to one pod (the Linkerd caveat).
- **Ad-hoc client timeouts instead of a call deadline** — the deadline is the propagated, server-honoured contract.
