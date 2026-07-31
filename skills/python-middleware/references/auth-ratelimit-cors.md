# Authenticate, Rate Limit, CORS

The identity-and-load half of the chain: the `Authenticate` middleware (bearer
credential → `Subject`), the per-subject token-bucket `RateLimit` middleware with its
honest multi-worker caveat, and Starlette's built-in `CORSMiddleware` configuration.
Correlation/observability/safety stages and the reverse-registration block live in the
sibling `references/middleware-chain.md`. Self-contained — read it without assuming
`SKILL.md`'s body is also loaded.

---

## Authenticate — Claims → Subject

Validates the bearer credential (RS256 JWT verified against a JWKS, or an opaque
session token — `security-implementation` owns the verification mechanics, including
signature, `aud`, `iss`, and `exp` checks) and stores the resolved `Subject` — which
already carries `tenant_id` as a field — in the `ContextVar`, never a second,
independently-set tenant variable. Health/readiness routes are mounted on a separate,
unauthenticated router and are excluded here:

```python
# app/middleware/auth.py
from uuid import UUID
import jwt                         # PyJWT
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.context import Subject, set_subject, reset, _subject
from app.security import verify_bearer   # security-implementation owns this

_ANON_PATHS = frozenset({"/healthz", "/readyz"})


class AuthenticateMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if request.url.path in _ANON_PATHS or request.method == "OPTIONS":
            # OPTIONS never carries Authorization; CORSMiddleware (outside us) handles it,
            # but this guard keeps a stray preflight from 401-ing if ordering regresses.
            return await call_next(request)

        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return _unauthorized()

        try:
            claims = verify_bearer(header.removeprefix("Bearer "))   # raises on bad sig/aud/exp
        except jwt.InvalidTokenError:
            return _unauthorized()

        subject = Subject(
            id=UUID(claims["sub"]),
            tenant_id=UUID(claims["tid"]),        # one Subject, tenant_id as a field
            scopes=frozenset(claims.get("scope", "").split()),
        )
        token = set_subject(subject)
        try:
            return await call_next(request)
        finally:
            reset(_subject, token)                # pair every .set() with a reset


def _unauthorized() -> JSONResponse:
    return JSONResponse(
        status_code=401,
        content={"error": {"code": "AUTHENTICATION_REQUIRED",
                           "message": "authentication required"}},
    )
```

Storing one `Subject` value (not a subject variable *plus* a separate tenant variable
set from the same claims) removes a class of drift bug: two independently-set
context values can be updated inconsistently by a later edit; one value with
`tenant_id` as a field cannot. This matters doubly under this product's **physical
per-tenant isolation** — the `tenant_id` on the `Subject` is what a downstream
repository asserts against the connection's bound tenant, and it must have exactly one
source of truth.

---

## RateLimit — Per-Subject Token Bucket

Mounted *inside* `Authenticate`, so the limiter key is the authenticated subject id
(not a shared, spoofable client IP). A pure-Python token bucket per subject, with an
idle-eviction sweep so the map never grows unbounded:

```python
# app/middleware/ratelimit.py
import asyncio
import time
from dataclasses import dataclass, field

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.context import get_subject


@dataclass
class _Bucket:
    tokens: float
    last_refill: float
    last_seen: float = field(default_factory=time.monotonic)


class _TokenBucketStore:
    """Per-subject token buckets with idle eviction. rate = sustained tokens/sec."""

    def __init__(self, rate: float, burst: int, idle_ttl: float = 300.0) -> None:
        self._rate = rate
        self._burst = burst
        self._idle_ttl = idle_ttl
        self._buckets: dict[str, _Bucket] = {}
        self._lock = asyncio.Lock()

    async def allow(self, key: str) -> tuple[bool, float]:
        now = time.monotonic()
        async with self._lock:
            b = self._buckets.get(key)
            if b is None:
                b = _Bucket(tokens=float(self._burst), last_refill=now)
                self._buckets[key] = b
            # refill proportionally to elapsed time, capped at burst
            b.tokens = min(self._burst, b.tokens + (now - b.last_refill) * self._rate)
            b.last_refill = now
            b.last_seen = now
            if b.tokens >= 1.0:
                b.tokens -= 1.0
                return True, 0.0
            # exact wait until the next whole token is available
            retry_after = (1.0 - b.tokens) / self._rate
            return False, retry_after

    async def sweep(self) -> None:
        """Background task: evict buckets idle past idle_ttl. Without it the map grows
        one entry per distinct subject ever seen, for the life of the process."""
        while True:
            await asyncio.sleep(self._idle_ttl)
            now = time.monotonic()
            async with self._lock:
                stale = [k for k, b in self._buckets.items()
                         if now - b.last_seen > self._idle_ttl]
                for k in stale:
                    del self._buckets[k]


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, rate: float = 10.0, burst: int = 20) -> None:
        super().__init__(app)
        self._store = _TokenBucketStore(rate=rate, burst=burst)

    async def dispatch(self, request: Request, call_next) -> Response:
        subject = get_subject()
        if subject is None:               # invariant: Authenticate ran first
            return await call_next(request)   # anon routes (healthz) — not limited
        allowed, retry_after = await self._store.allow(str(subject.id))
        if not allowed:
            resp = JSONResponse(
                status_code=429,
                content={"error": {"code": "RATE_LIMIT_EXCEEDED",
                                   "message": "too many requests"}},
            )
            resp.headers["Retry-After"] = str(int(retry_after) + 1)
            return resp
        return await call_next(request)
```

**Default parameters:** `rate=10.0` (10 requests/second sustained) with `burst=20` —
the sustained rate bounds steady-state load per subject; the burst headroom absorbs a
legitimate short spike (a page load firing several requests at once) without rejecting
it. The sweep task is started from the FastAPI `lifespan` (owned by
`python-service-skeleton`): `asyncio.create_task(store.sweep())` on startup, cancelled
on shutdown.

### The honest multi-worker caveat

This in-memory bucket is **per Python process**. `uvicorn --workers N` (or
`gunicorn -k uvicorn.workers.UvicornWorker -w N`) runs N separate OS processes, each
with its own `_TokenBucketStore` and its own bucket map — there is no shared memory
between them (the GIL is irrelevant here; these are distinct interpreters, not threads).
A subject's requests are load-balanced across all N workers, so the effective limit is
**multiplied by the worker count**: 4 workers at `rate=10` lets a single subject through
at roughly 40 req/s, not 10. The in-memory limiter is therefore correct only for a
single-worker deployment (or a deployment where per-tenant physical isolation already
pins one tenant to one process). For a multi-worker service that must enforce a global
per-subject limit, move the bucket state to a shared store (a Redis `INCR`-with-expiry
or a Lua token-bucket script) so all workers debit the same counter — accept the added
network hop and the extra dependency only when a genuinely global limit is required.
This is the same in-memory-vs-shared trade-off Go's single-process limiter faces the
moment it is horizontally scaled; Python surfaces it earlier because multi-worker is
the *default* way to use all cores under the GIL.

---

## CORS — Starlette's Built-In `CORSMiddleware`

Starlette ships `CORSMiddleware`; no third-party plugin is needed (unlike chi's
hand-rolled CORS or Node's `@fastify/cors`). It answers the browser's preflight
`OPTIONS` — which carries no `Authorization` header or cookie by design, because the
browser sends it *before* deciding whether to attach credentials — itself, short-
circuiting the chain with a `200`/`204` and the CORS headers. It is registered
**outside** `Authenticate` (see the registration block in
`references/middleware-chain.md`) for exactly that reason: a preflight that reached
`Authenticate` first would fail with a confusing 401 instead of getting the real CORS
decision.

```python
from starlette.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,   # dev: ["http://localhost:5173"] (Vite); prod: ["https://app.example.com"]
    allow_credentials=True,                   # requires an explicit origin list — see below
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
    expose_headers=["Retry-After", "X-Request-ID"],
    max_age=300,                              # seconds a browser may cache the preflight result
)
```

`allow_origins` is **never** `["*"]` when `allow_credentials=True` — the CORS spec
forbids the combination and browsers reject a wildcard-with-credentials response
outright. Starlette's `CORSMiddleware` enforces this too: with `allow_credentials=True`
it reflects the specific request `Origin` back rather than emitting `*`, but the origin
list must still be an explicit allow-list, never a catch-all. Set
`allow_origins` from configuration (`sdlc-config.json` → settings), never hard-coded.
