# Journeys, Waiting and Trace Correlation

Self-contained. Read when choosing which journeys to automate in a Python product, writing one, or working out why one failed. Code named here is in `../templates/python-suite.md`; it was run on Python 3.15.2 with pytest 9.2.0, pytest-asyncio 1.5.0, httpx 0.29.0, OpenTelemetry Python 1.45.2 and `opentelemetry-instrumentation-httpx` 0.66b2.

## What an end-to-end test is

A test that drives the **deployed** product from outside, over the network, through at least one real hop: the built image running as a Pod, reached through its Service. It imports no package of the product.

| | Integration (`python-integration-test`) | End-to-end (this skill) |
|---|---|---|
| Code under test runs | Inside the test process | In Pods, from the image that would ship |
| Proves | Our code against the real database and broker | The deployed parts work together: charts, configuration, service-to-service calls, the asynchronous path |
| Speed and stability | Fast, stable, on every pull request | Slow and the most brittle layer (Crispin and Gregory); nightly and before a release |

Two things turn an "end-to-end" test back into an integration test, whatever it is named: importing another service's package to "call" it, and `httpx.ASGITransport(app=...)` or FastAPI's `TestClient`, which run the application inside the test process. Neither crosses a network hop, so neither proves the chart, the image or the wiring. The validator fails on both.

## Which journeys

`test-pyramid` owns the layers and `go-e2e-test` owns the journey-selection method for every stack; load them for the full reasoning. The rule a Python suite follows:

1. Start from the acceptance criteria (`AC-US-n.m`) of the Must Have stories and the test strategy's risk rating.
2. A criterion becomes a journey only if proving it needs **more than one deployed part**: a call from one service to another, an effect that arrives later through a broker or worker, the web shell reaching the API, configuration that only exists in the chart. A realistic multi-step sequence against one service is a workflow test at the integration layer (Winteringham).
3. Everything else goes down: validation rules to `python-unit-test`, SQL and broker wiring to `python-integration-test`, message shapes to `python-contract-test`. The pyramid's shape is the result of proving each behaviour at the lowest layer that can (Khorikov).
4. One journey per user goal, not per criterion; its docstring lists the criteria. Smoke tests are a handful of **reads**.

A journey through the browser is written with `react-e2e-testing`, in TypeScript whatever the backend is written in (Halstead notes that Playwright has a Python port; the product's frontend is TypeScript, so the browser suite is too). It runs in this same environment. More end-to-end tests than integration tests for the same behaviour is a defect to investigate.

## Test data

- Create it the way a user would, through the public API, in a fixture (`create_loan`). A journey that inserts rows by hand no longer proves the product can reach that state. Direct writes are for state with no public route only: `../templates/direct-database-seed.md`.
- Each test creates, owns and removes its data; the fixture removes what it created after its `yield`, so a failed test cleans up too, and a failed removal fails the test (`test-fixture-design`).
- References are **derived, not random**: `<run id>-<test name>-<counter>` (the `ref` fixture). The run id comes from CI (`gh-<run id>-<attempt>`), so a failure names values that can be searched for in the evidence.
- A tenant in a journey is a test-only tenant of the end-to-end values file, sent the way the product's own clients send it (a token or header set on the client: `env.client("api", headers={...})`).
- Never rely on data another test created, or on order.

## Waiting

An effect that arrives later is awaited by polling for it with a deadline, never by sleeping a fixed time (Winteringham): too short fails for no reason, too long slows every run.

| Form | Use |
|---|---|
| `eventually(what, check, within=...)` | Synchronous tests. `check` returns the value when the effect is there and raises `AssertionError` while it is not |
| `await eventually_async(what, check, within=...)` | `async def` tests; `check` is a coroutine function |

- Both use `time.monotonic()` for the deadline (a wall clock can be set back) and fail with the **last reason**, so the failure says what was still wrong. Run: a wait that never came true failed with `status never: not true within 3s; last: AssertionError("still not 'never' ...` (pytest adds its comparison of the two values).
- A connection error during a check counts as "not yet"; a `Refused` from the guard is never swallowed.
- Poll for the state the user would see (the loan is `confirmed`), then assert on it. Correlate: poll for **this test's** record by its id, never "the list has one more item".
- To assert that something does **not** happen, first wait for proof that the input was processed, then check the absence.
- Choose the limit from what the product promises (an NFR or SLO), with room for a small cluster; never tighten it to make a suite faster.
- `asyncio.timeout(...)` around a polling loop gives the same bound for async code (documented; the shipped helper uses the explicit deadline so both forms read alike).

**An event on the broker.** When a journey must see the event itself and no read model shows it, consume it from the broker of the run's cluster: the address is an endpoint of the run marker (`env.addr("broker")`, checked with `env.require_throwaway`), the consumer is closed in a `finally`, and the wait is `eventually_async` looking for this test's id. A broker was not part of the run for this skill; that path is unverified here.

## Trace correlation

Purpose: a failed journey prints one trace id, and every service on its path received that same id.

Run, with a server that returns the `traceparent` header it received:

| Setup in the test process | Trace id printed | Header received |
|---|---|---|
| No SDK tracer provider (the earlier helper) | `00000000000000000000000000000000` | none |
| SDK provider, plain `httpx.Client` | valid | **none** |
| SDK provider, client on the instrumented transport, built before or after the provider was set | valid | `00-<the same id>-<span id>-03` |
| SDK provider, `HTTPXClientInstrumentor().instrument()`, plain client built before or after that call | valid | sent |
| The same, client on `httpx.MockTransport` or another custom transport | valid | **none** |
| `OTEL_SDK_DISABLED=true` | the `journey` fixture fails the test: `no valid trace id` | |

So three things are needed, and `conftest.py` with `support.py` does all three:

1. **A tracer provider from the SDK**, set once per session. Without it the tracer is a no-op: the id is all zeros and nothing is injected.
2. **The W3C trace-context propagator.** Python sets it by default (`OTEL_PROPAGATORS`), unlike Go; the fixture sets it explicitly so that a variable cannot remove it (run: with `OTEL_PROPAGATORS=none` the header was still sent).
3. **An instrumented client that replaces the plain one.** The bound transport wraps `SyncOpenTelemetryTransport` or `AsyncOpenTelemetryTransport`. The global `instrument()` call is the other documented way; it covers only the standard transports.

And the span must cover the request: the earlier helper ended its span before any request was sent. The `journey` fixture opens the span before the test and closes it after the test's cleanup; it is autouse, so no test can forget it. An `async def` test sees the span of this synchronous fixture (run with pytest-asyncio 1.5.0).

Run in the cluster: the id the test printed was the id in the `traceparent` that the first service received and the one it passed on to the second. The header ended `-03` (sampled, plus the random-trace-id flag), not `-01`: match on the id. On failure the report shows `trace_id=<id>`; the suite runner copies it into the flaky record and the summary.

The test process exports nothing: no exporter is configured, so the test's own span is not in the tracing backend, but each service's spans carry its trace id (when the services record traces; `distributed-tracing-design`). Whether a backend shows a trace whose first span was never exported was not checked.

## Writing one journey

1. Name it `test_journey_<user_goal>` in `tests/e2e/journeys/test_journey_<name>.py`; list the criteria in its docstring.
2. Take clients and create helpers as fixtures (`api`, `create_loan`, `ref`), or `env` for an async client.
3. Create the data through the API helper. Act as the user would.
4. `eventually(...)` for each later effect, then assert the end state the user or a second service would see.
5. See it fail first: break the behaviour (or the expectation) once and confirm the failure message names what is wrong.

No retries inside a journey, no skip, no shared state between journeys.
