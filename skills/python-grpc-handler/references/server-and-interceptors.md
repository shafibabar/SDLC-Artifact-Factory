# gRPC Server and Interceptors — Full Python (grpc.aio) Implementation

Complete, copyable server setup for an internal gRPC service in this repo's stack (Python asyncio, per-tenant physical isolation, OpenTelemetry, Linkerd mesh). Assumes a `.proto` compiled with `grpc_tools.protoc` (see `grpc-contract-design`). The service is a `DataAssetService` for the data-estate product. Everything runs on `grpc.aio` — the asyncio server — to match FastAPI + asyncpg + aiokafka.

---

## 1. Regeneration (build step, run via the Bash tool)

```bash
# From the module root; requires the grpcio-tools package.
python -m grpc_tools.protoc \
  -I proto \
  --python_out=. \
  --grpc_python_out=. \
  --pyi_out=. \
  proto/dataasset/v1/dataasset.proto
```

`--python_out` emits `dataasset_pb2.py` (message classes); `--grpc_python_out` emits `dataasset_pb2_grpc.py` containing the `DataAssetServiceServicer` base class, the `add_DataAssetServiceServicer_to_server` registration function, and a client stub. **`--pyi_out` is not optional in this repo**: it emits `dataasset_pb2.pyi` type stubs so `mypy` can check message field access — without it the generated `_pb2.py` is untyped and a whole class of field-name bugs goes unchecked (the honest static-safety gap `python-fastapi-handler` also flags). `mypy-protobuf`'s `protoc-gen-mypy` is a richer alternative; `--pyi_out` is the frugal built-in. Generated code is checked in (or built in CI) — a proto change that breaks compatibility then surfaces as a mypy/import break, not a production error.

---

## 2. The servicer implementation (the Humble Object)

The class subclasses the generated `DataAssetServiceServicer` and holds only application-layer dependencies — never an asyncpg pool directly (that is injected one layer in, in `python-service-layer`). Every RPC is `async def`.

```python
import grpc
from dataasset.v1 import dataasset_pb2 as pb
from dataasset.v1 import dataasset_pb2_grpc as pb_grpc
from app.errors import write_domain_error  # single status writer, see call-types-errors-mesh.md
from app.context import current_tenant      # contextvars.ContextVar, set by the auth interceptor


class DataAssetServicer(pb_grpc.DataAssetServiceServicer):
    """Thin adapter: validate -> await application layer -> encode / map error."""

    def __init__(self, classify, get_by_id, scanner, ingest, progress):
        self._classify = classify   # command handler from python-service-layer
        self._get_by_id = get_by_id # query handler
        self._scanner = scanner
        self._ingest = ingest
        self._progress = progress

    async def GetDataAsset(self, request: pb.GetDataAssetRequest,
                           context: grpc.aio.ServicerContext) -> pb.DataAsset:
        if not request.id:
            await context.abort(grpc.StatusCode.INVALID_ARGUMENT, "id is required")
        tenant = current_tenant.get()  # placed on the ContextVar by the auth interceptor
        try:
            asset = await self._get_by_id.handle(tenant, request.id)
        except Exception as exc:                # noqa: BLE001 - funnelled through the one writer
            await write_domain_error(context, exc)
        return to_proto_data_asset(asset)
```

`context.abort(...)` raises immediately and terminates the RPC with that status — it never returns, so no `return` is needed after it.

---

## 3. The re-wrapping helper (the key grpc.aio divergence from Go)

Go gives two clean interceptor signatures (`UnaryServerInterceptor`, `StreamServerInterceptor`). `grpc.aio` gives **one** hook — `ServerInterceptor.intercept_service(continuation, handler_call_details)` — that returns an `RpcMethodHandler`. To actually observe/modify the call you fetch the handler, then rebuild it around a wrapped behaviour, dispatching on its `request_streaming`/`response_streaming` flags to pick the matching factory. Write this once; every interceptor reuses it.

```python
import grpc


def _wrap_rpc_behavior(handler, wrapper):
    """Rebuild an RpcMethodHandler with `wrapper` applied to its behavior.
    Dispatch on the four (request_streaming, response_streaming) combinations."""
    if handler is None:
        return None

    if handler.request_streaming and handler.response_streaming:
        behavior, factory = handler.stream_stream, grpc.stream_stream_rpc_method_handler
    elif handler.request_streaming and not handler.response_streaming:
        behavior, factory = handler.stream_unary, grpc.stream_unary_rpc_method_handler
    elif not handler.request_streaming and handler.response_streaming:
        behavior, factory = handler.unary_stream, grpc.unary_stream_rpc_method_handler
    else:
        behavior, factory = handler.unary_unary, grpc.unary_unary_rpc_method_handler

    return factory(
        wrapper(behavior, handler.request_streaming, handler.response_streaming),
        request_deserializer=handler.request_deserializer,
        response_serializer=handler.response_serializer,
    )
```

A community package, `grpc-interceptor`, offers an `AsyncServerInterceptor` with a Go-like `intercept(method, request_or_iterator, context, method_name)` ergonomic wrapper — adopt it if the boilerplate below grows. The native mechanism shown here is the frugal default and makes the divergence explicit.

---

## 4. Panic-recovery interceptor (registered OUTERMOST)

An unhandled exception must never leak a traceback to the client or kill the HTTP/2 connection. Recovery is outermost so it wraps every other interceptor and the behaviour. `context.abort` is already-terminal, so let its raise pass through; catch only genuinely unexpected exceptions.

```python
import grpc


class RecoveryInterceptor(grpc.aio.ServerInterceptor):
    def __init__(self, logger):
        self._log = logger

    async def intercept_service(self, continuation, handler_call_details):
        handler = await continuation(handler_call_details)
        method = handler_call_details.method

        def wrap(behavior, request_streaming, response_streaming):
            if response_streaming:
                async def stream_wrapper(request_or_iter, context):
                    try:
                        async for response in behavior(request_or_iter, context):
                            yield response
                    except grpc.aio.AbortError:
                        raise                        # already a deliberate status
                    except Exception as exc:         # noqa: BLE001
                        self._log.error("panic recovered", method=method, error=repr(exc))
                        await context.abort(grpc.StatusCode.INTERNAL, "internal error")
                return stream_wrapper

            async def unary_wrapper(request_or_iter, context):
                try:
                    return await behavior(request_or_iter, context)
                except grpc.aio.AbortError:
                    raise
                except Exception as exc:             # noqa: BLE001
                    self._log.error("panic recovered", method=method, error=repr(exc))
                    await context.abort(grpc.StatusCode.INTERNAL, "internal error")
            return unary_wrapper

        return _wrap_rpc_behavior(handler, wrap)
```

---

## 5. Auth + tenant-extraction interceptor

Reads the bearer token and tenant ID from **metadata**, never from the request body — a tenancy-isolation requirement under per-tenant physical isolation. Because `grpc.aio` has no `context.WithValue`, the tenant is placed on a `contextvars.ContextVar` that handlers read via `current_tenant.get()`.

```python
# app/context.py
import contextvars
current_tenant: contextvars.ContextVar[str] = contextvars.ContextVar("current_tenant")
```

```python
import grpc


class AuthInterceptor(grpc.aio.ServerInterceptor):
    def __init__(self, token_parser):
        self._parser = token_parser

    async def intercept_service(self, continuation, handler_call_details):
        md = dict(handler_call_details.invocation_metadata or ())
        token = md.get("authorization")
        tenant = None
        if token:
            try:
                claims = self._parser.parse(token)
                tenant = claims.tenant_id
            except Exception:                        # noqa: BLE001
                tenant = None

        handler = await continuation(handler_call_details)

        def wrap(behavior, request_streaming, response_streaming):
            if response_streaming:
                async def stream_wrapper(request_or_iter, context):
                    if not tenant:
                        await context.abort(grpc.StatusCode.UNAUTHENTICATED, "invalid token")
                    current_tenant.set(tenant)       # ContextVar carries it across awaits
                    async for response in behavior(request_or_iter, context):
                        yield response
                return stream_wrapper

            async def unary_wrapper(request_or_iter, context):
                if not tenant:
                    await context.abort(grpc.StatusCode.UNAUTHENTICATED, "invalid token")
                current_tenant.set(tenant)
                return await behavior(request_or_iter, context)
            return unary_wrapper

        return _wrap_rpc_behavior(handler, wrap)
```

Weak-encapsulation honesty (same as `python-middleware`): a `ContextVar` is a module-global read by convention — nothing stops a handler ignoring it and trusting the request body instead. The discipline (read tenant only from `current_tenant`) is enforced by review and by this skill's anti-patterns, not by the type system, exactly as Go's typed private context key would.

---

## 6. Logging interceptor (records method, code, latency)

```python
import time
import grpc


class LoggingInterceptor(grpc.aio.ServerInterceptor):
    def __init__(self, logger):
        self._log = logger

    async def intercept_service(self, continuation, handler_call_details):
        handler = await continuation(handler_call_details)
        method = handler_call_details.method

        def wrap(behavior, request_streaming, response_streaming):
            if response_streaming:
                async def stream_wrapper(request_or_iter, context):
                    start = time.monotonic()
                    async for response in behavior(request_or_iter, context):
                        yield response
                    self._log.info("stream call", method=method,
                                   code=context.code(),
                                   duration_ms=int((time.monotonic() - start) * 1000))
                return stream_wrapper

            async def unary_wrapper(request_or_iter, context):
                start = time.monotonic()
                response = await behavior(request_or_iter, context)
                self._log.info("unary call", method=method,
                               code=context.code(),
                               duration_ms=int((time.monotonic() - start) * 1000))
                return response
            return unary_wrapper

        return _wrap_rpc_behavior(handler, wrap)
```

`context.code()` is the gRPC `StatusCode`, not an HTTP status — record it as-is.

---

## 7. OpenTelemetry tracing — prefer the community async interceptor

Do **not** hand-roll trace-context extraction from metadata. The `opentelemetry-instrumentation-grpc` package ships a ready async server interceptor, `aio_server_interceptor()`, which extracts the propagated trace context from metadata, starts a server span named for the method, and closes it on return — the Python analog of Go's preferring `otelgrpc`'s `StatsHandler` over a hand-rolled tracing interceptor. Add it to the interceptor list; it is one line and correct.

```python
from opentelemetry.instrumentation.grpc import aio_server_interceptor

tracing = aio_server_interceptor()   # extracts trace context from metadata, starts the server span
```

---

## 8. Server construction and graceful shutdown

The composition root (`python-service-skeleton`'s `lifespan`) calls this, having already built the handlers and the `TokenParser`. Interceptor order in the list is outermost-first — recovery wraps everything, then tracing, then auth, then logging closest to the behaviour.

```python
import grpc
from grpc_health.v1 import health, health_pb2, health_pb2_grpc
from dataasset.v1 import dataasset_pb2_grpc as pb_grpc


async def build_server(servicer, token_parser, logger) -> tuple[grpc.aio.Server, "health.aio.HealthServicer"]:
    server = grpc.aio.server(
        interceptors=[
            RecoveryInterceptor(logger),      # OUTERMOST
            aio_server_interceptor(),          # OpenTelemetry
            AuthInterceptor(token_parser),
            LoggingInterceptor(logger),        # closest to the behaviour
        ]
    )
    pb_grpc.add_DataAssetServiceServicer_to_server(servicer, server)

    # Standard gRPC health service — unauthenticated, probed by K8s and the mesh.
    health_servicer = health.aio.HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)
    await health_servicer.set("", health_pb2.HealthCheckResponse.SERVING)

    server.add_insecure_port("[::]:50051")   # TLS terminates at the Linkerd proxy
    return server, health_servicer


async def serve(server: grpc.aio.Server) -> None:
    await server.start()
    try:
        await server.wait_for_termination()
    finally:
        # Drains in-flight RPCs up to the grace period, then stops accepting.
        await server.stop(grace=5.0)
```

`uvicorn`-style signal handling does not apply here — `grpc.aio` has its own `server.stop(grace)`. The composition root wires `SIGTERM`/`SIGINT` to trigger that stop, and closes the asyncpg pool and aiokafka clients in reverse construction order, exactly as `python-service-skeleton` specifies for the FastAPI side.

---

The four call-type handler bodies, the domain-error → `StatusCode` mapping table, `grpcio-status` structured details, deadline handling, and the Linkerd HTTP/2 balancing config live in `call-types-errors-mesh.md`.
