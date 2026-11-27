# API Behaviour Checks

Self-contained. Use when the API contract promises behaviour: a schema check proves a response's shape, not that the behaviour happens (Winteringham). Shape and compatibility belong to `go-contract-test`; middleware to `go-middleware`; whole user journeys to `go-e2e-test`.

## How to call

Build the **real router with its real middleware** and the real database, and call `router.ServeHTTP` with `httptest.NewRequest` in the test's goroutine, so a router built on the test's transaction stays in it (default isolation). Use a started server and real commits only when requests must run at the same time, or the promise depends on the server itself (timeouts, TLS); say which. Never replace the repository with a fake here.

## What to assert, only where the contract documents it

| Promise | Test | Assert |
|---|---|---|
| Repeat-request safety | Same `Idempotency-Key` and body twice | Same status and body; **one** stored effect and one event |
| Key reused for another request | Same key, different body | The documented refusal; nothing stored |
| Concurrent repeats | Several identical requests at once (real commit, scoped data) | One effect; every reply as documented |
| Rate limit | Exceed the burst | `429`, `Retry-After` and the documented error code; another caller unaffected |
| Deprecation | Call the old version | The `Deprecation` and sunset headers with the contract's values; absent on the current version |
| Error branches | One table row per documented status and code | Status, machine code, and no stored effect |
| Unexpected failure | A real database error (abort the test's transaction first) | The documented opaque `500`; no SQL or driver text |
| Workflow | Create, read, change, read | State consistent across the calls |
| Authentication, authorisation, security headers | As documented | `401`, `403`, headers present (`security-implementation` owns the controls) |
| Asynchronous reply (`202`) | Follow up | Poll with a deadline for the outcome |

## Rules

- Values come from the contract, the service's configuration or an NFR ID. If the contract promises a limit or a sunset without a value, that is an open question for the product owner; invent none.
- A rate-limit test builds the router with a limit whose refill cannot happen during the test (for example one token an hour, burst 2) through the same constructor production uses, and a separate check confirms the shipped values are wired. Tests about something else use an unlimited setting, so they do not trip it.
- A limiter or idempotency store kept in memory belongs to one router instance: build one per test. This does not prove behaviour across several instances; state that when the service runs more than one.
- Each promise test goes red once with the behaviour removed.
- Give high-risk endpoints more cases (`test-pyramid`).
