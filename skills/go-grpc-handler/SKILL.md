---
name: go-grpc-handler
description: >
  Teaches the backend-engineer to implement a gRPC server in Go — server setup
  from protoc-generated stubs (grpc.NewServer, RegisterXServiceServer,
  implementing the generated ServiceServer interface), unary and stream
  interceptors as the go-middleware analog for auth/tenant-extraction/logging/
  OpenTelemetry-tracing/panic-recovery, the four call types (unary,
  server-streaming, client-streaming, bidirectional-streaming) and which fits
  which data flow, mapping domain errors to gRPC status codes through one
  status writer (status.Error, codes.InvalidArgument/NotFound/FailedPrecondition,
  status.WithDetails for machine-readable error details), reading the tenant
  claim and trace context from metadata via metadata.FromIncomingContext,
  honoring deadlines/cancellation/context propagation (ctx.Err,
  DEADLINE_EXCEEDED), the grpc_health_v1 health service, and the Linkerd +
  gRPC HTTP/2 per-request L7 balancing caveat (long-lived HTTP/2 connections
  defeat connection-level load balancing). The gRPC analog of go-chi-handler,
  the same thin Humble Object handler discipline translated to gRPC. Full
  server + interceptor code is in references/server-and-interceptors.md;
  worked per-call-type handlers, status/details, deadlines, health, and the
  Linkerd note are in references/streaming-errors-mesh.md. Used by the
  backend-engineer during Implement for internal gRPC services.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, grpc, go, interceptor, streaming, server]
produces: go-grpc-handler
domain: backend
status: stable
related: [go-chi-handler, go-middleware, grpc-contract-design, go-service-skeleton]
tools: [Bash]
---

# Go gRPC Handler

## Purpose

A gRPC server method is the transport edge for internal service-to-service traffic, exactly as a chi handler is the edge for public REST. Its only job is to translate between the RPC and the application layer: it receives a generated, already-typed request message (no JSON decode step — `protoc` produced the type), validates its structure, calls the relevant command/query handler with the incoming `context.Context`, and returns the generated response message or maps the error to a gRPC status. It contains no business logic and no persistence — it is the same thin, boring **Humble Object** `go-chi-handler` teaches, translated to gRPC. The generated method body stays validate → domain → encode; every cross-cutting concern lives in an interceptor.

This skill owns the Go server-side implementation. The `.proto` contract itself — `service`/`message` authoring, field-numbering discipline, choosing the method shape — is `grpc-contract-design`'s. The composition root that constructs the server and its dependencies is `go-service-skeleton`'s. gRPC is for **internal** transport only; the public/browser-facing data-estate API stays REST + OpenAPI (`go-chi-handler`), because browsers cannot speak native gRPC without a gRPC-Web proxy.

---

## Server Setup From Generated Stubs

`protoc` with `protoc-gen-go` and `protoc-gen-go-grpc` compiles the `.proto` into Go message types plus a `XServiceServer` interface and a `RegisterXServiceServer` function. The server is a plain struct that implements that interface (embedding `UnimplementedXServiceServer` for forward compatibility so a newly added RPC does not break the build). Construct the transport with `grpc.NewServer(...)` passing the interceptor chains as options, register the implementation, then `Serve` on a `net.Listener`. Regeneration is a build step, not runtime — run it via the Bash tool (`protoc --go_out --go-grpc_out`, or `buf generate`), check the generated code into the repo or CI. Full server, registration, and graceful shutdown (`GracefulStop`): `references/server-and-interceptors.md`.

---

## Interceptors: the go-middleware Analog

Cross-cutting concerns do **not** go in the method body — they go in interceptors, exactly the role chi middleware plays at the REST edge. gRPC has two flavors matching the method shapes, each registered once on `grpc.NewServer`:

| Concern | Where | Notes |
|---|---|---|
| Auth-token validation, tenant extraction | interceptor (first in chain) | read from `metadata.FromIncomingContext`; reject with `codes.Unauthenticated`/`PermissionDenied` before the method runs |
| Request/response logging, metrics | interceptor | record method, code, latency after `handler` returns |
| OpenTelemetry trace propagation | interceptor | extract trace context from metadata, start a span, inject into `ctx` |
| Panic recovery | interceptor (must be **outermost** so it wraps all others) | `recover()` → `status.Error(codes.Internal, ...)`; never let a panic kill the connection |

A **unary interceptor** has signature `func(ctx, req, info, handler) (resp, err)` and wraps one request/response. A **stream interceptor** has signature `func(srv, ss ServerStream, info, handler) error` and wraps a streaming call — to observe individual messages it must wrap `ss` in a type overriding `SendMsg`/`RecvMsg`. Every concern that needs both must be implemented as both a unary and a stream interceptor. Chain them with `grpc.ChainUnaryInterceptor(...)` / `grpc.ChainStreamInterceptor(...)`; order matters — recovery outermost, then tracing, then auth, then logging. Full implementations of all four (auth, logging, OTel, recovery) in both flavors, plus the `wrappedServerStream`: `references/server-and-interceptors.md`.

---

## The Four Call Types

Choose the method shape from the data flow, not habit — default to unary unless streaming earns its keep (it complicates retries and load balancing).

| Shape | proto | Fits |
|---|---|---|
| **Unary** | `rpc Get(Req) returns (Resp)` | request/response commands and point reads — the REST-like default |
| **Server streaming** | `rpc Scan(Req) returns (stream Resp)` | large or open-ended result sets — a data-estate scan emitting `DataAsset`s as it discovers them |
| **Client streaming** | `rpc Ingest(stream Req) returns (Resp)` | large uploads assembled server-side — chunked document ingest |
| **Bidirectional** | `rpc Progress(stream Req) returns (stream Resp)` | independent concurrent read/write — a live progress or control channel |

A streaming method's server side reads with `stream.Recv()` (returns `io.EOF` when the client is done) and writes with `stream.Send(msg)`; always check `stream.Context().Err()` between sends so a cancelled client stops server work. Worked handler for each of the four shapes: `references/streaming-errors-mesh.md`.

---

## Errors: One Status Writer

Map domain errors to gRPC status codes through a single writer, exactly as the REST edge maps to HTTP status through one error writer — never leak internal error strings, never return a bare Go `error`. The gRPC status model is its own enum (`codes.OK`, `InvalidArgument`, `NotFound`, `AlreadyExists`, `PermissionDenied`, `Unauthenticated`, `FailedPrecondition`, `ResourceExhausted`, `DeadlineExceeded`, `Unavailable`, `Internal`, …), richer than HTTP status — `InvalidArgument` vs `FailedPrecondition` vs `OutOfRange` distinguish failures that all collapse to `400` in REST. Reserve `codes.Internal` for genuine bugs; prefer `InvalidArgument`/`FailedPrecondition`/`NotFound` for domain conditions. Attach machine-readable structured detail with `status.WithDetails` (typically a `google.rpc.BadRequest` / `ErrorInfo` protobuf message) rather than stuffing context into the string. The full domain-error → `codes` mapping table and the `status.WithDetails` worked example: `references/streaming-errors-mesh.md`.

---

## Deadlines, Cancellation, Metadata

Every gRPC call carries a **deadline** — an absolute time propagated from the client to the server, distinct from an ad-hoc client-local timeout. The server sees it as its `context.Context`: when the deadline passes or the client cancels, `ctx.Done()` fires and `ctx.Err()` returns `context.DeadlineExceeded`/`Canceled`, which map to `codes.DeadlineExceeded`/`codes.Canceled`. Treat a done context as a **hard stop**, not advisory — check it in long loops and streaming sends, and derive every downstream call's context from the incoming one so cancellation propagates through the whole chain. **Metadata** is the gRPC header/trailer key/value channel (the analog of HTTP headers) — read incoming with `metadata.FromIncomingContext(ctx)`, and it is where the auth token, the tenant ID (per-tenant physical isolation), and the OpenTelemetry trace context ride. Never trust a tenant ID from the request message body; read it from validated metadata in the auth interceptor. Worked deadline-honoring handler: `references/streaming-errors-mesh.md`.

---

## Health Checks and the Linkerd HTTP/2 Caveat

Expose the standard gRPC health service (`grpc_health_v1`) via `google.golang.org/grpc/health` + `healthpb.RegisterHealthServer` so Kubernetes and the mesh can probe readiness — this is the gRPC analog of `health-check-design`'s HTTP `/healthz`. Register it on the same server, unauthenticated.

The **Linkerd + gRPC caveat is a real operational gotcha, not a formality**: gRPC multiplexes many requests over one long-lived HTTP/2 connection, so a plain Kubernetes `Service` (or any L4/connection-level balancer) pins *all* of a client's traffic to the single backend pod it first connected to — load does not spread. Linkerd's proxy does per-**request** L7 balancing over HTTP/2, which is precisely why the mesh matters for gRPC; bypassing it silently loses load distribution. Verify traffic actually spreads across pods rather than assuming the Service does it. Config note and details: `references/streaming-errors-mesh.md`.

---

## Quality Criteria

- The method body is thin — validate → call application layer with incoming `ctx` → return generated message or mapped status. No business logic, no persistence, no direct DB access.
- All cross-cutting concerns are in interceptors, registered once; the panic-recovery interceptor is outermost.
- Every error leaves through the one status writer as a `status.Error` with a deliberate `codes` value; `codes.Internal` only for genuine bugs; no leaked internal strings.
- Tenant ID and trace context are read from validated metadata, never from the request body.
- Streaming methods check `stream.Context().Err()` and honor deadlines/cancellation as a hard stop.
- The `grpc_health_v1` health service is registered; the service runs inside the Linkerd mesh for per-request L7 balancing.

---

## Anti-Patterns

- **Business logic in the method body** — move it to `go-service-layer`; the method is a Humble Object.
- **Cross-cutting concern repeated per method** instead of an interceptor — that is what interceptors are for.
- **Returning a bare Go `error`** from a method — it becomes an opaque `codes.Unknown`; always wrap through the status writer.
- **Reading the tenant ID from the request message** instead of validated metadata — a tenancy-isolation hole.
- **Running gRPC through a plain K8s Service without L7-aware balancing** — pins all traffic to one pod (the Linkerd caveat).
- **Ad-hoc client timeouts instead of a call deadline** — the deadline is the propagated, server-honored contract.
