# HTTPX and RESPX Official Documentation
**Authors:** The HTTPX project (encode/httpx); Jonas Lundberg (lundberg/respx)
**Domain:** Testing (consumer-side HTTP doubles)

Accessed 2026-11-28. httpx latest 0.29.0, 2026-11-26, BSD-3-Clause, Python >=3.10 (https://pypi.org/pypi/httpx/json); docs read at tag `0.29.0`: H = https://raw.githubusercontent.com/encode/httpx/0.29.0. respx latest 0.23.1, 2026-04-08, BSD-3-Clause, Python >=3.8, requires `httpx>=0.25.0` (https://pypi.org/pypi/respx/json); docs read at tag `0.23.1`: R = https://raw.githubusercontent.com/lundberg/respx/0.23.1.

## Core Concepts

**HTTPX**

- `Client` and `AsyncClient` accept a `transport` argument that performs the actual sending. (H/docs/advanced/transports.md)
- `httpx.MockTransport(handler)` takes a function from request to `httpx.Response` and returns pre-determined responses without the network. (H/docs/advanced/transports.md)
- Transports can be mounted per scheme or domain: `httpx.Client(mounts={"all://example.org": httpx.MockTransport(handler)})`. (H/docs/advanced/transports.md)
- In-process app call: `transport = httpx.ASGITransport(app=app)` then `httpx.AsyncClient(transport=transport, base_url="http://testserver")`. Options: `raise_app_exceptions=False` (inspect 500 responses instead of raising), `root_path`, `client=(host, port)`. (H/docs/advanced/transports.md)
- "It is not in the scope of HTTPX to trigger ASGI lifespan events of your app"; the docs suggest `LifespanManager` from asgi-lifespan. (H/docs/advanced/transports.md)
- The `app=` shortcut on the client was removed in 0.28.0; `transport=` is the only form. (H/CHANGELOG.md)
- Timeouts are on by default: `TimeoutException` after 5 seconds of network inactivity. `httpx.Timeout(10.0, connect=60.0)` sets connect, read, write and pool separately; `timeout=None` disables. Exceptions: `ConnectTimeout`, `ReadTimeout`, `WriteTimeout`, `PoolTimeout`. (H/docs/advanced/timeouts.md)
- 0.29.0 raises the minimum Python to 3.10 and exposes `FunctionAuth`; no other change is listed. (H/CHANGELOG.md)
- The transports page points to RESPX and pytest-httpx for more advanced mocking. (H/docs/advanced/transports.md)

**RESPX**

- RESPX is a mock router: it captures requests sent by HTTPX and returns mocked responses or triggers side effects. (R/docs/guide.md)
- Activation: the `@respx.mock` decorator, the `with respx.mock:` context manager, or the `respx_mock` pytest fixture. These patch HTTPX, so an unmodified client is intercepted. (R/docs/guide.md)
- Without patching: `router = respx.Router()`, then `httpx.MockTransport(router.handler)` for `Client` or `router.async_handler` for `AsyncClient`. (R/docs/guide.md)
- Settings: `respx.mock(assert_all_mocked=True, assert_all_called=True, base_url=None)`. Passing settings creates an isolated router. (R/docs/api.md)
- `assert_all_mocked` (default `True`): a request that matches no route raises; when disabled the request is auto-mocked with status 200. The exception in source is `AllMockedAssertionError`, a subclass of `AssertionError`. (R/docs/guide.md, R/respx/models.py, R/respx/router.py)
- `assert_all_called` (default `True` on a configured router): on exit, any route that was not called fails the test. (R/docs/guide.md)
- The default router `respx.mock` used without settings has `assert_all_called` disabled. (R/docs/api.md)
- The `respx_mock` fixture without a marker uses that default router, so uncalled routes are not asserted. The guide's sentence that the fixture asserts all routes by default does not match this source. (R/respx/plugin.py, R/respx/api.py, R/docs/guide.md)
- Fixture settings come from the marker `@pytest.mark.respx(assert_all_called=..., assert_all_mocked=..., base_url=...)`. (R/docs/guide.md, R/respx/plugin.py)
- With `MockTransport(router.handler)` there is no automatic exit check; call `router.assert_all_called()` yourself. (R/docs/guide.md)
- Routes: method helpers `get`, `options`, `head`, `post`, `put`, `patch`, `delete`, or `route(...)` with patterns `method`, `scheme`, `host`, `port`, `path`, `params`, `url`, `content`, `data`, `files`, `json`, `headers`, `cookies`. (R/docs/guide.md, R/docs/api.md)
- Lookups by suffix: `__eq`, `__contains`, `__in`, `__regex`, `__startswith`. `M(...)` objects combine with `&`, `|`, `~`. (R/docs/api.md)
- `json` matches with `eq` by default and supports path traversal (`json__foobar__0__ham="spam"`). `headers` matches with `contains` by default. (R/docs/api.md)
- Routes are matched in the order added; more specific routes go first. (R/docs/guide.md)
- Responses: `route.mock(return_value=httpx.Response(...))`, `route.respond(status, json=...)`, `route.return_value = ...`, or the `%` shortcut. (R/docs/guide.md)
- Side effects: a function receiving `request` (and optionally `route` and named regex groups), an exception class such as `httpx.ConnectError`, or an iterable of responses and exceptions returned in order (`StopIteration` when exhausted). A function returning `None` means no match; returning the request passes it through. (R/docs/guide.md)
- `route.pass_through()` sends the request to the real server. (R/docs/guide.md)
- Call inspection: `route.called`, `route.call_count`, `route.calls`, `route.calls.last.request`, `route.calls.last.response`; router-wide `respx.calls`; named routes through `respx.routes["name"]` or `router["name"]`. (R/docs/guide.md)
- Routes and call history roll back when the mocked scope exits. (R/docs/guide.md)
- An app can back a route: `respx_mock.route().mock(side_effect=ASGIHandler(app))` or `WSGIHandler(app)`. (R/docs/guide.md)

**What neither tool checks**

- Neither set of documentation mentions OpenAPI or any validation of a canned response against an API description. A statement that the tools do or do not validate doubles is therefore not stated in the official documentation; the absence was confirmed by searching the pages listed above for "openapi" and "schema". (H/docs/advanced/transports.md, R/docs/guide.md, R/docs/api.md)
- Compatibility of respx 0.23.1 with httpx 0.29.0 is not stated; respx predates that release and declares only `httpx>=0.25.0`. (https://pypi.org/pypi/respx/json, H/CHANGELOG.md)

## Actionable Techniques (design is this note's)

- Give the real client an injectable transport or `httpx.AsyncClient`; in tests pass `httpx.MockTransport(router.async_handler)` built from a `respx.Router()`. This avoids global patching and keeps the client code path real.
- Use a configured router (`respx.mock(assert_all_called=True, ...)` or the marker) rather than the bare fixture, or call `router.assert_all_called()` explicitly.
- Keep `assert_all_mocked=True` so an unexpected call fails instead of returning an empty 200.
- Assert on the request the client sent (`route.calls.last.request`) and on the values the client read from the response.
- Add an extra unknown field to the canned body to show the client tolerates it.
- Validate each canned response against the provider's description with a separate tool (see `openapi-conformance-python-official-docs.md`); these two libraries do not do it.
- A consumer test uses a canned double. `ASGITransport(app=provider_app)` or `ASGIHandler(provider_app)` imports the provider and is a different kind of test.
- Exercise timeouts with `side_effect=httpx.ReadTimeout` or `httpx.ConnectError`.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-contract-test | Consumer tests its real client against a double | `MockTransport(router.async_handler)`, route patterns, strictness defaults |
| python-contract-test | Double checked against the provider's description | Not provided by httpx or respx; needs a separate validator |
| python-contract-test | Assert the values read; tolerate unknown fields | Call inspection API; nothing in either tool rejects extra fields |
| python-contract-test | A consumer test must not import the provider app | `ASGITransport` and `ASGIHandler` are the in-process routes to avoid here; lifespan is not run by `ASGITransport` |

## Candidate New Skills/Agents

None.

## Key Terminology

Transport, Mock Transport, Route, Side Effect, Pass Through.

## Caveats

- Nothing was run. No package was installed.
- [unverified] respx 0.23.1 working with httpx 0.29.0, which was two days old on the access date.
- [unverified] Whether `ASGIHandler` in respx runs lifespan events.
- The fixture default for `assert_all_called` is taken from source, against the guide's wording; confirm by a run in the rebuild.
