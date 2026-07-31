# Call-Type Handlers, Status/Error Details, Deadlines, Health, and the Linkerd HTTP/2 Caveat

Worked `grpc.aio` server-side bodies for each of the four gRPC call types, the single domain-error → gRPC status writer with structured details, deadline/cancellation handling, the health service, and the operational config for running gRPC through Linkerd. Continues `server-and-interceptors.md`; same `DataAssetServicer` example, same `current_tenant` ContextVar set by the auth interceptor.

---

## 1. Unary — request/response

Already shown in `server-and-interceptors.md` (`GetDataAsset`). Shape: validate → `current_tenant.get()` → `await` the application handler → encode, or funnel the error through `write_domain_error`.

---

## 2. Server streaming — one request, a stream of responses

The canonical data-estate case: a scan emits `DataAsset`s as it discovers them. In `grpc.aio` the server-streaming method is a natural **async generator** — `yield` each result; there is no explicit `stream.Send`. **Check `context.cancelled()` between yields** so a cancelled or timed-out client stops server work immediately.

```python
import grpc
from dataasset.v1 import dataasset_pb2 as pb


class DataAssetServicer(...):  # continued
    async def ScanDataAssets(self, request: pb.ScanRequest,
                             context: grpc.aio.ServicerContext):
        tenant = current_tenant.get()
        if not request.source:
            await context.abort(grpc.StatusCode.INVALID_ARGUMENT, "source is required")

        try:
            async for asset in self._scanner.stream(tenant, request.source):
                if context.cancelled():          # client hung up or deadline blown -> hard stop
                    return
                yield to_proto_data_asset(asset)
        except Exception as exc:                 # noqa: BLE001
            await write_domain_error(context, exc)
```

When the async generator returns (the `async for` over `self._scanner.stream` completes), the stream closes cleanly — the analog of Go's returning `nil` after the channel closes.

---

## 3. Client streaming — a stream of requests, one response

Chunked document ingest: the client streams chunks, the server assembles and returns a single result. Iterate the incoming `request_iterator` with `async for`; when it is exhausted, `return` the single response.

```python
class DataAssetServicer(...):  # continued
    async def IngestDocument(self, request_iterator,
                             context: grpc.aio.ServicerContext) -> pb.IngestResponse:
        tenant = current_tenant.get()
        buf = bytearray()
        async for chunk in request_iterator:
            if context.cancelled():
                return pb.IngestResponse()       # abandoned; nothing committed
            buf += chunk.data
        try:
            asset = await self._ingest.handle(tenant, bytes(buf))
        except Exception as exc:                 # noqa: BLE001
            await write_domain_error(context, exc)
        return pb.IngestResponse(id=asset.id)    # one response closes the stream
```

---

## 4. Bidirectional streaming — independent read and write streams

A live progress/control channel: the server reads commands and emits progress over one connection. In `grpc.aio` the simplest correct shape is an async generator that reads the request iterator and yields updates as it goes.

```python
class DataAssetServicer(...):  # continued
    async def Progress(self, request_iterator,
                       context: grpc.aio.ServicerContext):
        tenant = current_tenant.get()
        async for msg in request_iterator:
            if context.cancelled():
                return
            try:
                update = await self._progress.apply(tenant, msg.command)
            except Exception as exc:             # noqa: BLE001
                await write_domain_error(context, exc)
            yield pb.ProgressUpdate(percent=update.percent)
```

For fully independent read/write cadence (writes not driven one-per-read), spawn the send side as an `asyncio.Task` keyed off the same context and cancel it when the request iterator ends — but default to the coupled read→yield shape above unless the decoupling earns its complexity.

---

## 5. One status writer: domain error → gRPC code

Every method funnels errors through `write_domain_error`, exactly as the REST edge funnels through one `@app.exception_handler(DomainError)`. Never let a bare `Exception` escape (it becomes an opaque `UNKNOWN`), never leak an internal string.

### Domain error → `StatusCode` mapping

| Domain condition | gRPC `StatusCode` | Why (vs the REST collapse to 4xx) |
|---|---|---|
| Missing/blank required field, malformed input | `INVALID_ARGUMENT` | the request itself is wrong regardless of state |
| Entity not found | `NOT_FOUND` | — |
| Unique/duplicate conflict | `ALREADY_EXISTS` | distinct from a generic conflict |
| Precondition on current state fails (e.g. asset already classified) | `FAILED_PRECONDITION` | request valid but state forbids it — REST collapses this and INVALID_ARGUMENT both to 400 |
| Value out of the valid range | `OUT_OF_RANGE` | a third case REST also collapses to 400 |
| No/invalid credentials | `UNAUTHENTICATED` | — |
| Authenticated but not allowed (wrong tenant) | `PERMISSION_DENIED` | — |
| Quota/rate limit hit | `RESOURCE_EXHAUSTED` | — |
| Deadline passed / client cancelled | `DEADLINE_EXCEEDED` / `CANCELLED` | surfaces as `asyncio.CancelledError` / `context.cancelled()` |
| Downstream dependency down | `UNAVAILABLE` | retryable by the client |
| Genuine bug / unexpected | `INTERNAL` | reserved — the only code meaning "our fault, not yours" |

```python
import grpc
from app import domain  # domain exception types


async def write_domain_error(context: grpc.aio.ServicerContext, exc: Exception) -> None:
    if isinstance(exc, domain.NotFoundError):
        await context.abort(grpc.StatusCode.NOT_FOUND, "data asset not found")
    elif isinstance(exc, domain.AlreadyClassifiedError):
        await context.abort(grpc.StatusCode.FAILED_PRECONDITION, "asset already classified")
    elif isinstance(exc, domain.ValidationError):
        await _abort_with_validation_details(context, exc)   # structured details, below
    elif isinstance(exc, domain.ForbiddenError):
        await context.abort(grpc.StatusCode.PERMISSION_DENIED, "not permitted for this tenant")
    else:
        # Reserve INTERNAL for genuine bugs; the caller logged the real exc
        # server-side. Return an opaque message — never the internal string.
        await context.abort(grpc.StatusCode.INTERNAL, "internal error")
```

### Structured, machine-readable details with `grpcio-status`

Attach a `google.rpc.BadRequest` rather than stuffing field errors into the message string. This needs the `grpcio-status` package (`grpc_status.rpc_status`) plus the generated `google.rpc` messages (`status_pb2`, `error_details_pb2`, `code_pb2`). The client reads them back with `rpc_status.from_call(...)`.

```python
import grpc
from grpc_status import rpc_status
from google.rpc import status_pb2, error_details_pb2, code_pb2


async def _abort_with_validation_details(context: grpc.aio.ServicerContext,
                                         exc: "domain.ValidationError") -> None:
    detail = error_details_pb2.BadRequest(
        field_violations=[
            error_details_pb2.BadRequest.FieldViolation(
                field="classification",
                description="must be one of PUBLIC, INTERNAL, RESTRICTED",
            )
        ]
    )
    status_proto = status_pb2.Status(
        code=code_pb2.INVALID_ARGUMENT,
        message="validation failed",
    )
    status_proto.details.add().Pack(detail)
    # abort_with_status carries the full rich status (code + message + packed details).
    await context.abort_with_status(rpc_status.to_status(status_proto))
```

---

## 6. Deadlines and cancellation

The deadline is an absolute time the client sets and the server honours — distinct from an ad-hoc client-local timeout. Server-side, `context.time_remaining()` returns the seconds left (`None` if the client set no deadline) and `context.cancelled()` reports a cancelled/expired call. An expired deadline while you are `await`ing surfaces as `asyncio.CancelledError`. Treat a done call as a **hard stop**.

```python
class DataAssetServicer(...):  # continued
    async def Classify(self, request: pb.ClassifyRequest,
                       context: grpc.aio.ServicerContext) -> pb.ClassifyResponse:
        # Fast-fail if the caller's deadline is already effectively gone.
        remaining = context.time_remaining()
        if remaining is not None and remaining <= 0:
            await context.abort(grpc.StatusCode.DEADLINE_EXCEEDED, "deadline exceeded")

        tenant = current_tenant.get()
        try:
            # Do NOT wrap downstream awaits in a fresh asyncio task that outlives
            # this call — let CancelledError propagate so asyncpg/aiokafka calls abort.
            await self._classify.handle(tenant, request.id, pb.Level.Name(request.level))
        except asyncio.CancelledError:
            raise                                 # propagate; the RPC ends CANCELLED/DEADLINE_EXCEEDED
        except Exception as exc:                  # noqa: BLE001
            await write_domain_error(context, exc)
        return pb.ClassifyResponse()
```

The honest divergence from Go: there is no single `context.Context` object carrying *both* cancellation and request-scoped values. Cancellation rides `asyncio` (`CancelledError`, `context.time_remaining()`); values (tenant, trace span) ride the `contextvars.ContextVar` set in the auth interceptor. A naive port that expects one object to carry both silently loses tenant scoping. Never re-`await` downstream work under a fresh `asyncio.timeout()` that ignores the incoming deadline — derive from what the call already gives you.

---

## 7. Health service

Registered in `server-and-interceptors.md` §8 via `grpc_health.v1.health.aio.HealthServicer`. It is the gRPC analog of an HTTP `/healthz`; Kubernetes probes it with a native gRPC liveness/readiness probe (or `grpc_health_probe`), and Linkerd uses it for readiness. Toggle per-service status as dependencies come and go — the async servicer's `set` is a coroutine:

```python
# e.g. asyncpg pool unreachable during a dependency check
await health_servicer.set(
    "dataasset.v1.DataAssetService",
    health_pb2.HealthCheckResponse.NOT_SERVING,
)
```

---

## 8. The Linkerd + gRPC HTTP/2 balancing caveat (operational gotcha, not a formality)

This caveat is language-agnostic — identical to the Go sibling — because it is a property of HTTP/2 and Kubernetes, not of the server's language.

gRPC multiplexes **many requests over one long-lived HTTP/2 connection**. A plain Kubernetes `Service` (kube-proxy / iptables) and any L4/connection-level balancer make their decision *once, at connect time*, then every subsequent request rides that same connection — so all of a client's traffic pins to the single backend pod it first hit. Load does not spread; scaling the Deployment up does nothing.

Linkerd's data-plane proxy does **per-request L7 balancing over HTTP/2** — it looks inside the connection and distributes individual requests across the available endpoints. This is precisely why the mesh matters for gRPC, and why bypassing it (or exposing gRPC through a plain Service without an L7-aware balancer) silently loses load distribution.

A Python-specific reinforcement: a `grpc.aio` server runs on **one asyncio event loop per process**, and the GIL means one process does not scale across cores for CPU-bound work. Real deployments therefore run **multiple pods/processes** (mirroring `python-middleware`'s multiple-uvicorn-worker caveat), which makes correct per-request balancing across those replicas matter even more than it would for a single fat multi-core process.

Practical rules:

- Ensure both client and server pods are **meshed** (`linkerd.io/inject: enabled` on the namespace or Deployment) so the proxy sits in the path and does the per-request balancing.
- Point the client at the **Kubernetes Service DNS name** (`dataasset.svc.cluster.local:PORT`); Linkerd resolves it to the endpoint set and balances per request. Do **not** pre-resolve to a single pod IP.
- **Verify, don't assume**: send sustained gRPC load and confirm traffic actually spreads across pods (`linkerd viz stat deploy` / per-pod request counts), rather than trusting the Service distributes it — a plain Service will not.
- Name the container port `grpc` so Linkerd's protocol detection classifies it correctly.

Example Deployment annotation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dataasset-service
  annotations:
    linkerd.io/inject: enabled   # proxy injected -> per-request HTTP/2 L7 balancing
spec:
  replicas: 3                     # multiple processes: GIL means one loop per pod
  template:
    spec:
      containers:
        - name: dataasset
          ports:
            - name: grpc            # named port aids protocol detection
              containerPort: 50051
```
