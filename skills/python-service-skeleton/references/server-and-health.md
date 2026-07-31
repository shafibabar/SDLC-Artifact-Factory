# uvicorn Server, SIGTERM Handling, and Health Endpoints — Standard

The ASGI server configuration and the two health endpoints that make a FastAPI
pod behave correctly under a Kubernetes rolling deploy. This is the Python
counterpart to `go-service-skeleton`'s shutdown-and-health standard: same
guarantees (no request accepted before readiness, no shutdown that outruns the
pod's grace period), different machinery (uvicorn owns signals; Go owns them
explicitly).

---

## uvicorn as the graceful-shutdown owner

uvicorn — the ASGI server FastAPI runs under — installs its own handlers for
`SIGTERM` and `SIGINT`. On either signal it:

1. stops accepting new connections (closes the listening socket),
2. waits a **bounded** interval for in-flight requests to complete,
3. runs the app's `lifespan` teardown (the code after `yield`),
4. exits.

You never write a `signal.signal(...)` or `loop.add_signal_handler(...)` call in
application code — doing so races uvicorn's handler and breaks the ordered drain.
This is the single biggest divergence from `go-service-skeleton`, which installs
`signal.NotifyContext` by hand precisely because Go's `net/http` server has no
equivalent built-in.

### The drain-deadline setting

The bounded wait in step 2 is uvicorn's `timeout_graceful_shutdown`, expressed in
**seconds**. It is the Python analog of Go's 25s `srv.Shutdown` budget. Set it
explicitly — the uvicorn default is `None` (wait indefinitely), which under
Kubernetes means the pod hangs until `terminationGracePeriodSeconds` expires and
the kernel sends `SIGKILL` mid-request. Set it to **25** so it fits under the
30s grace period with margin for the `preStop` hook and `lifespan` teardown:

```python
import uvicorn

def serve() -> None:
    config = uvicorn.Config(
        "app.main:create_app",
        factory=True,
        host="0.0.0.0",
        port=8000,
        timeout_graceful_shutdown=25,   # seconds; < terminationGracePeriodSeconds (30)
        timeout_keep_alive=5,           # idle keep-alive sockets closed after 5s
        access_log=False,               # structured logging is middleware's job
    )
    server = uvicorn.Server(config)
    server.run()                        # installs SIGTERM/SIGINT handlers itself


if __name__ == "__main__":
    serve()
```

`uvicorn.Server.run()` is what installs the signal handlers. The
`install_signal_handlers` flag exists for the rare case where uvicorn is embedded
in a parent process that owns signals itself — leave it at its default (`True`)
for a standalone pod; setting it `False` without providing your own handler means
`SIGTERM` falls straight through to a hard stop with no drain.

### The shutdown-timeout budget (must sum under the grace period)

| Step | Owner | Budget | Note |
|---|---|---|---|
| `preStop` sleep | Kubernetes manifest | 3s | Lets the endpoint controller pull the pod before uvicorn stops accepting. |
| HTTP request drain | uvicorn `timeout_graceful_shutdown` | 25s | In-flight requests finish or are cut. |
| `lifespan` teardown | app (consumer.stop + pool.close) | ~2s | Runs after the drain; consumer leaves the group, pool closes. |
| **Total** | | **~30s** | Must be **≤** `terminationGracePeriodSeconds`. Leave it at exactly 30 only if teardown is genuinely instant; prefer a grace period of 35s for headroom. |

The arithmetic mirrors `go-service-skeleton`'s exactly: every step is bounded,
the sum stays under the ceiling, and no single step uses an unbounded wait.

---

## `app/health.py` — the two endpoints and the readiness gate

```python
import asyncio
import asyncpg
from fastapi import APIRouter, Request, Response, status

health_router = APIRouter(tags=["health"])


class Readiness:
    """A flag flipped to not-ready the instant lifespan teardown begins, plus a
    bounded dependency check. Held on app.state, built in the lifespan."""

    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool
        self._ready = False

    def set_ready(self) -> None:
        self._ready = True

    def set_not_ready(self) -> None:
        self._ready = False

    @property
    def accepting(self) -> bool:
        return self._ready

    async def dependencies_ok(self) -> bool:
        if not self._ready:
            return False
        try:
            # Bounded reachability ping — SELECT 1, never a business query, so
            # probe frequency never becomes accidental load. asyncio.wait_for
            # caps it so a wedged Postgres cannot hang the probe.
            async with self._pool.acquire() as conn:
                await asyncio.wait_for(conn.fetchval("SELECT 1"), timeout=2.0)
            return True
        except (asyncpg.PostgresError, asyncio.TimeoutError, OSError):
            return False


@health_router.get("/healthz/live")
async def live() -> Response:
    # Liveness: is the process fundamentally stuck? Answer WITHOUT touching any
    # dependency. A liveness probe that pings Postgres turns one DB blip into a
    # fleet-wide restart storm — the kubelet kills every pod that fails it.
    return Response(status_code=status.HTTP_200_OK)


@health_router.get("/healthz/ready")
async def ready(request: Request) -> Response:
    # Readiness: can THIS instance serve traffic right now? Gated on the pool's
    # reachability AND the not-ready flag, so shutdown flips it to 503 before any
    # connection is refused.
    gate: Readiness = request.app.state.ready
    if await gate.dependencies_ok():
        return Response(status_code=status.HTTP_200_OK)
    return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
```

### Why readiness gates on dependencies but liveness never does

- **Liveness dependency-free.** The kubelet restarts a container that fails its
  liveness probe. If liveness checked Postgres, a transient database outage would
  make every pod fail liveness simultaneously → the kubelet restarts the entire
  fleet → the restart storm outlasts the outage. Liveness answers only "is the
  event loop alive," so it returns 200 unconditionally.
- **Readiness dependency-gated.** The endpoint controller removes a pod that
  fails its readiness probe from the Service's endpoint set — it stops receiving
  traffic but is **not** restarted. So a pod whose Postgres is briefly
  unreachable correctly stops taking requests and rejoins when the pool recovers,
  with no restart. And because teardown sets not-ready first, a draining pod
  fails readiness (503) and is pulled from the load balancer *before* uvicorn
  stops accepting — the client never sees a connection refused.

---

## Kubernetes probe mapping

```yaml
# in the pod spec — full manifest belongs to kubernetes-manifest
livenessProbe:
  httpGet:
    path: /healthz/live
    port: 8000
  periodSeconds: 10
  failureThreshold: 3          # ~30s of genuine stuck-ness before a restart
readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 8000
  periodSeconds: 5
  failureThreshold: 2          # pulled from the LB fast when a dependency drops
lifecycle:
  preStop:
    exec:
      command: ["sleep", "3"]  # endpoint controller drains before uvicorn stops accepting
terminationGracePeriodSeconds: 35   # > 3 (preStop) + 25 (uvicorn drain) + teardown
```

The `terminationGracePeriodSeconds` value must exceed the sum of the `preStop`
sleep, uvicorn's `timeout_graceful_shutdown`, and `lifespan` teardown — the same
"budget sums under the ceiling" rule Go enforces. Set it to 35 so the 3 + 25 +
~2 chain finishes with margin before the kernel escalates to `SIGKILL`.

---

## Divergences from the Go standard, stated plainly

- **Signals are uvicorn's, not the app's.** Go's standard is a `signal.NotifyContext`
  call the app owns; Python's is a server setting (`timeout_graceful_shutdown`)
  the app configures but does not implement. The correctness property is
  identical; the ownership boundary is not.
- **One event loop, not M:N goroutines.** The readiness `SELECT 1` runs on the
  same event loop as every request handler, so a probe that forgot its
  `asyncio.wait_for` bound could stall the whole process — hence the explicit
  2s cap. Go's probe runs on its own goroutine and cannot stall the server the
  same way. The bound is not optional in Python.
- **No separate liveness goroutine.** In Go the liveness handler is trivially
  isolated; in Python it shares the loop, which is exactly why it must do zero
  I/O — a truly stuck event loop won't answer `/healthz/live` at all, and that
  non-answer (probe timeout) is itself the correct "process is wedged" signal.
