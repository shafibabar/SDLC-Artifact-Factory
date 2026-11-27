# API Behaviour Checks

Self-contained. Use when the API contract promises behaviour: a schema check proves a response's shape, not that the behaviour happens (Winteringham). Shape and compatibility belong to `python-contract-test`; middleware to `python-middleware`; whole user journeys to `python-e2e-test`.

## How to call

Build the **real application with its real routes and middleware** and the real database, injected through the app factory. Call it with `httpx.AsyncClient(transport=httpx.ASGITransport(app=app, raise_app_exceptions=False), base_url="http://test")`.

- It runs on the test's event loop, so an app built on `one_pool` stays inside the test's transaction (default isolation). Seen: `fastapi.testclient.TestClient` on the test's connection fails with a `RuntimeError` about another event loop.
- `raise_app_exceptions=False` lets the test read the documented `500`. Seen with the default: the exception is raised into the test.
- `ASGITransport` does not run the app's lifespan (seen), so set what lifespan would set (pool, settings) through the factory.
- Do not override the repository or unit of work with a fake here. Override only a third party's port (and say so).
- Use `pool` and real commits only when requests must run at the same time; a started `uvicorn` server only when the promise depends on the server (timeouts, TLS; not run here). Say which.

## What to assert, only where the contract documents it

| Promise | Test | Assert |
|---|---|---|
| Repeat-request safety | Same `Idempotency-Key` and body twice | Same status and body; **one** stored effect and one event |
| Key reused for another request | Same key, different body | The documented refusal; nothing stored |
| Concurrent repeats | `asyncio.gather` of several identical requests (real commit, scoped keys) | One effect; every reply as documented |
| Rate limit | Exceed the burst | `429`, `Retry-After`, the documented error code; another caller unaffected |
| Deprecation | Call the old version | `Deprecation` and sunset headers with the contract's values; absent on the current version |
| Error branches | One parametrized row per documented status and code, including request validation | Status, machine code, and no stored effect |
| Unexpected failure | A real database error (abort the test's transaction first) | The documented opaque `500`; no SQL or driver text |
| Workflow | Create, change, read | State consistent across the calls |
| Authentication, authorisation, security headers | As documented | `401`, `403`, headers present (`security-implementation` owns the controls) |
| Asynchronous reply (`202`) | Follow up | Poll with a deadline for the outcome |

## Rules

- Values come from the contract, the service's configuration or an NFR ID. If the contract promises a limit or a sunset without a value, that is an open question for the product owner; invent none.
- A rate-limit test builds the app with a limit whose refill cannot happen during the test (for example one token an hour, burst 2) through the same factory production uses, and a separate check confirms the shipped values are wired. Tests about something else use an unlimited setting.
- A limiter or idempotency store kept in memory belongs to one process: build one app per test, and state that the test proves nothing across several workers or instances.
- Each promise test goes red once with the behaviour removed. Seen: idempotency claim ignored gave `409` for the repeat; limiter removed gave `404` where `429` was expected.
- Give high-risk endpoints more cases (`test-pyramid`).
