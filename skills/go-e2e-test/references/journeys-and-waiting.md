# Journeys, Waiting and Trace Correlation

Self-contained. Read when choosing which journeys to automate, writing one, or working out why one failed. Code named here is in `../templates/go-suite.md`; it was run on Go 1.27.4 with OpenTelemetry Go v1.47.0 and `otelhttp` v0.72.0.

## What an end-to-end test is

A test that drives the **deployed** product from outside, over the network, through at least one real hop: the built image running as a Pod, reached through its Service. It imports no package of the product.

| | Integration (`go-integration-test`) | End-to-end (this skill) |
|---|---|---|
| Code under test runs | Inside the test binary | In Pods, from the image that would ship |
| Proves | Our code against the real database and broker | The deployed parts work together: charts, configuration, service-to-service calls, the asynchronous path |
| Speed and stability | Fast, stable, on every pull request | Slow and the most brittle layer (Crispin and Gregory); nightly and before a release |

A test that imports another service's package to "call" it crossed no network hop: it is an integration test whatever it is named.

## Which journeys

The pyramid's shape is a result of proving each behaviour at the lowest layer that can (Khorikov), so this layer stays small. `test-pyramid` owns that rule and the test strategy lists the journeys; this is how to fill that list.

1. Start from the acceptance criteria (`AC-US-n.m`) of the Must Have stories and the test strategy's risk rating.
2. A criterion becomes an end-to-end journey only if proving it needs **more than one deployed part**: a call from one service to another, an effect that arrives later through a broker or worker, the web shell reaching the API, configuration that only exists in the chart. A realistic multi-step sequence against one service (create, read back, change, read again) is a workflow test at the integration layer (Winteringham).
3. Everything else goes down: validation rules and permutations to unit tests, SQL and broker wiring to integration tests, message shapes to contract tests.
4. Write one journey per user goal, not per criterion: a journey may prove several criteria, and its comment lists them.
5. Add one journey per critical failure a user would meet across parts (the second service is down and the first says so), where the strategy rates the risk high.
6. Pick the smoke tests: a handful of **reads** that show the deployed product is alive and can reach its dependencies. Breadth, not depth (smoke testing in the standard vocabulary; Quigley).

A journey through the browser is written with `react-e2e-testing` and runs in this same environment. This skill covers journeys through the API.

More end-to-end tests than integration tests for the same behaviour is a defect to investigate, not thoroughness.

## Test data

- Create it the way a user would, through the public API, inside the test (`createBooking`). A journey that inserts rows by hand no longer proves the product can reach that state. Direct writes are for state with no public route only: `../templates/direct-database-seed.md`.
- Each test creates, owns and removes its data, and removal is registered at creation so a failed test cleans up too (`test-fixture-design`).
- References are **derived, not random**: `<run id>-<test name>-<counter>` (`ref(t)`). The run id comes from CI (`gh-<run id>-<attempt>`), so a failure names values that can be searched for in the evidence. Ids the product generates are whatever the product returns.
- Never rely on data another test created, or on order.

## Waiting

An effect that arrives later is awaited by polling for it with a deadline, never by sleeping a fixed time (Winteringham): too short fails for no reason, too long slows every run.

- `eventually(t, ctx, limit, what, check)` calls `check` until it returns nil, and on timeout fails with the **last reason**, so the failure says what was still wrong.
- Poll for the state the user would see (the booking is `confirmed`), then assert on it. Do not assert straight after the request that starts asynchronous work.
- Correlate: poll for **this test's** record by its id, never "the list has one more item".
- To assert that something does **not** happen, first wait for proof that the input was processed, then check the absence.
- Choose the limit from what the product promises (an NFR or SLO), with room for a small cluster; never tighten it to make a suite faster.

## Trace correlation

Purpose: a failed journey prints one trace id, and every service on its path logged or recorded that same id.

Run, with a server that returns the `traceparent` header it received:

| Setup in the test process | Trace id printed | Header received |
|---|---|---|
| No SDK tracer provider (with or without a propagator) | `00000000000000000000000000000000` | none |
| SDK provider, no propagator | valid | **none** |
| SDK provider and propagator, plain `http.Client` | valid | **none** |
| SDK provider, propagator set **after** the transport was built | valid | **none** |
| SDK provider, then propagator, then `otelhttp.NewTransport` | valid | `00-<the same id>-<span id>-01` |

So four things are needed, and the template does all four:

1. `setupTracing()` in `TestMain`, before any client exists: an SDK tracer provider and the W3C propagator (`propagation.TraceContext{}`).
2. A client whose transport is `otelhttp.NewTransport(...)`, built after step 1.
3. `startJourney(t)` starts one span, fails the test if its id is not valid, and ends the span when the test ends.
4. Every request is built with the context `startJourney` returned.

Run in the cluster: the id the test printed was the id in the `traceparent` that the first service received and the one it passed on to the second. On failure the test prints `trace_id=<id>`; the suite runner copies it into the flaky record and the summary.

The test process exports nothing: no exporter is configured, so the test's own span is not in the tracing backend, but each service's spans carry its trace id (when the services record traces; `distributed-tracing-design`). Whether a backend shows a trace whose first span was never exported was not checked. Other header formats work too if the services use them; W3C Trace Context is what the product's default stack propagates.

## Writing one journey

1. Name it `TestJourney_<UserGoal>` and list the criteria in its comment.
2. `ctx, _ := startJourney(t)`; get clients from `env.Client(...)`.
3. Create the data through the API helper.
4. Act as the user would.
5. `eventually(...)` for each later effect, then assert the end state the user or a second service would see.
6. See it fail first: break the behaviour (or the expectation) once and confirm the failure message names what is wrong.

No retries inside a journey, no `t.Skip`, no shared state between journeys.
