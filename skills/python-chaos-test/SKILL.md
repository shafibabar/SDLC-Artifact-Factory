---
name: python-chaos-test
description: >
  Use when test-strategist or anyone writes, reviews, runs or fixes chaos or
  fault-injection experiments for a Python service (FastAPI, asyncio, uvicorn)
  in the Quality phase: proving a circuit breaker (pybreaker, aiobreaker,
  purgatory), a tenacity retry with backoff and jitter, an asyncio.timeout
  deadline, an asyncio.Semaphore bulkhead or graceful degradation under an
  injected fault; an event-loop stall (a blocking call in async def, the whole
  worker looks hung); a fault-injecting httpx transport, Toxiproxy toxics,
  Chaos Mesh on kind; pytest -m chaos through the runner (make chaos), the
  steady-state hypothesis on the SLO, abort conditions, fault removal, the
  signed chaos statement, PASS, FAIL, REFUSED or INVALID, the chaos-experiment
  report; or "kill the broker container with testcontainers", "run chaos on
  staging", "is one fast failure proof the breaker works". Produces
  chaos-experiment-suite.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-07-31
tags: [quality, python, chaos, fault-injection, resilience, circuit-breaker, retry, bulkhead, event-loop, asyncio, pytest, httpx, toxiproxy, chaos-mesh, kind, steady-state, abort]
produces: chaos-experiment-suite
domain: testing
status: stable
related: [go-chaos-test, python-e2e-test, python-load-test, python-integration-test, python-unit-test, python-async-concurrency, python-error-handling, python-middleware, python-makefile, integration-design, slo-definition, test-pyramid, disaster-recovery-plan, ci-pipeline, test-fixture-design, glossary-management]
sources:
  - research/testing/python-resilience-libraries-official-docs.md
  - research/testing/chaos-engineering-method-official-docs.md
  - research/testing/chaos-mesh-and-toxiproxy-details-official-docs.md
  - research/testing/toxiproxy-official-docs.md
  - research/testing/python-service-saturation-official-docs.md
  - research/testing/httpx-guards-and-polling-official-docs.md
  - research/testing/pytest-e2e-mechanics-official-docs.md
  - research/testing/pytest-asyncio-official-docs.md
  - research/testing/chaos-mesh-official-docs.md
  - research/testing/kind-official-docs.md
  - research/software-architecture/python-backend-development-halstead.md
  - research/devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.md
  - research/devops-and-delivery/devops-handbook-kim-humble-debois-willis.md
  - research/software-architecture/building-microservices-newman.md
---

# Python Chaos Test

## Purpose

This skill owns how a Python product's resilience patterns are proven under a deliberately injected fault: a dependency that answers late, fails or vanishes; an event loop blocked; a pod killed. `test-strategist` authors and runs it. An experiment states a steady state on the product's own SLI before anything is injected, injects one fault, and tries to disprove that users keep getting what the SLO promises (Principles of Chaos Engineering; Netflix's ChAP). Each pattern is proven by its defined behaviour, measured, never by "it failed fast once". The method, the runner, the statement, the Chaos Mesh manifests and the Toxiproxy chart are `go-chaos-test`'s, kept here as copies a test holds identical; what is Python's is the fault tooling (httpx, pytest, asyncio), the libraries' traps, and the event loop. The patterns' definitions belong to `integration-design`; their code to the Python build skills (none implements a breaker, retry or bulkhead yet); the throwaway cluster to `go-e2e-test` and `python-e2e-test`; load as the stressor to `python-load-test`; DLQ, idempotency and 429 to `python-integration-test`.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| C1 | **Where: by default only the run's own throwaway kind cluster**, never a per-test testcontainers stack. Any other system only with the product owner's **signed chaos statement** (where, which faults and limits, blast radius, abort conditions, impact); the runner **refuses** otherwise, with nothing injected | A fault on a shared system is an incident for everyone on it (D048, 2026-11-28) |
| C2 | **Chaos Mesh only inside the throwaway cluster**, in its default cluster-wide mode, every selector held to one namespace | Its daemon runs privileged with host PID and host mounts |
| C3 | **Application-level and proxy faults first**: `FaultTransport` or the stand-in dependency, then `stall_app`, then Toxiproxy through its HTTP API; cluster faults in the throwaway cluster at every size | The narrowest tool that produces the fault is the most deterministic |
| C4 | **No standing production chaos.** Scheduled in the throwaway cluster; a production experiment needs a signed statement each time | Decision of 2026-11-28 |
| C5 | **The steady state is the SLO's own SLI, written before injection**, measured from outside; if it does not hold before the fault, INVALID | No baseline, no result |
| C6 | **A pattern is proven only by a measurable assertion of its defined behaviour**, against the product's own configured settings (table below). Every injection's answer is checked and the fault confirmed active | One fast failure proves no breaker (seen: the 1.2.0 test passed with a breaker that never tripped) |
| C7 | **Abort conditions are numbers set before injection**; the abort removes the fault | A threshold chosen while watching is no rail |
| C8 | **The fault is removed on every path and its removal verified** | A left fault poisons every later test |
| C9 | **Verdicts: PASS, FAIL, REFUSED, INVALID.** No confirmed fault, no steady state before it, no test collected, or a skipped test: INVALID | An experiment that injected nothing proves nothing |
| C10 | **No retries.** One run, one result; no rerun plugin, no cache narrowing | `test-pyramid`: zero retries below end-to-end |
| C11 | **Every chaos file is under `tests/chaos/`, marked `chaos` by its `conftest.py`, which refuses any run the runner did not start**; the coverage gate leaves the folder out (`--skip-suite chaos`); never in `make ci` or on a pull request | W3-D10; Python has no build tag |
| C12 | **Test what the product implements, and name a missing pattern as missing.** Never build it in the test | Decision of 2026-11-28 |
| C13 | **DLQ, idempotency and 429 are proven in `python-integration-test`**; here only confirmed under a fault | W3-D23 |
| C14 | **A chaos-experiment report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner | D048.5 |

Every product size follows all fourteen; size changes how many experiments, never which rules.

## What each pattern must show

| Pattern | Assertion (settings read from the product) | Fails on |
|---|---|---|
| Circuit breaker | Closed below the threshold; open at exactly it; while open every call fails fast and the dependency counts **zero** calls; after the reset **one** probe from five callers; a failed probe reopens; a good probe closes; the caller's cancellation is not a failure | No threshold; one-call tests; purgatory's unlimited half-open |
| Retry | Exactly the attempt cap reaches the dependency; each wait within its doubling cap, with jitter; a 4xx tried once; the caller's deadline stops it; at most threshold × attempts while the dependency stays down; a `stop` exists | tenacity's bare `@retry` (never stops) |
| Timeout | The caller's `TimeoutError` by its `asyncio.timeout` deadline, and the dependency sees its request end then | A shielded or threaded call |
| Bulkhead | A full `asyncio.Semaphore` refuses at once (its acquire bounded: it takes no timeout itself); another downstream is still served | A shared semaphore |
| Event loop | A blocking call in `async def` stalls its own worker (lag probe, health check) and no other; the product's CPU-bound handler stalls nothing | Work on the loop |
| Degradation | The answer the SLI counts: 200 under the threshold, marked degraded | No fallback |

Library differences, every assertion and its failure message: `./references/patterns-and-assertions.md`.

## What every answer states

**Keep the answer as short as the question, within any length the user sets.** Answer the user's own points first, one by one, each with its rule in words; add a point below only where the question touches it, never a general tour of the method. Do not only follow a rule or point at a file.

1. **Where it runs:** by default only the run's own throwaway kind cluster (not a testcontainers stack per test), **at every product size, lean included**; any other system, staging and production included, only under the product owner's **signed chaos statement** saying **exactly where** it runs, which faults, the blast radius, the abort conditions and the impact, and the runner **refuses** otherwise, with nothing injected.
2. **Chaos Mesh only inside the throwaway cluster** (privileged daemon); application-level and Toxiproxy faults first; **a lean product may run cluster-level faults such as a pod kill there too**. Toxiproxy's API is unauthenticated: it stays reachable only inside the test environment, never published on all interfaces.
2a. **Whenever a Python breaker library is named:** pybreaker's `call_async` depends on Tornado and does not suit an asyncio service; aiobreaker is effectively unmaintained; recommend a breaker that works natively with asyncio, and test whatever the product actually uses.
3. **The steady-state hypothesis on the SLO's output metric**, named by its id and worded as the SLO defines it, measured before injection.
4. **Each pattern's measurable assertion**, never "it failed fast". For a breaker say the threshold **as configured** (`integration-design`'s number) and each state in words: open at the threshold, failing fast with the dependency receiving no calls, half-open after the reset with one probe, closed on success, reopened by a half-open failure; and the library's own trip rule (pybreaker and aiobreaker raise `CircuitBreakerError` on the tripping call; purgatory re-raises the original error and raises its open-state error from the next call). For the event loop say that **a blocking call in `async def` stalls every request in that worker, health checks included**, and that the fix (offload with `asyncio.to_thread` or a process pool) belongs to the service.
5. **The abort conditions as numbers**, and that the fault is removed on every path and its **removal verified**.
6. **INVALID** when the fault was never confirmed active, the steady state did not hold before it, or pytest collected nothing (exit 5) or skipped a test; **no retries**.
7. **Every chaos file sits under `tests/chaos/`, marked `chaos` by the folder, so neither `make ci` nor the coverage gate (`--skip-suite chaos`) runs it** (say both); a bare `pytest` is refused; never on a pull request; scheduled in the throwaway cluster, no standing production chaos.
8. **A pattern the product lacks is named as missing**, not built in the test: no Python build skill provides a breaker, retry or bulkhead yet.
9. **The report is an artifact the product owner approves**, and says what the run does not prove.
10. **One line on what was run**; anything not run is called unverified.

## Procedure

1. Read the SLO record, `integration-design`'s inventory for each downstream, the product's client code (which patterns exist, with which library and settings), the test strategy and `sdlc-config.json`. List each pattern as present or **missing**.
2. Plan: read `./references/where-it-runs.md`. Default target: the throwaway cluster. Any other system: draft `./templates/chaos-statement.md` for the product owner to sign; until signed, plan nothing there.
3. Write one experiment definition per hypothesis from `./templates/experiment-definition.md`. Read `./references/experiment-method.md` first.
4. Copy the support unchanged (`./templates/chaos-support.md`); write the pattern tests from `./templates/pattern-tests.md` and the stall experiment from `./templates/event-loop-stall.md` against the product's own client and settings.
5. Add Toxiproxy (`./templates/toxiproxy-setup.md`) and, for cluster faults, Chaos Mesh (`./templates/chaos-mesh-manifests.md`, `./references/chaos-mesh-on-kind.md`).
6. Copy `./scripts/run-chaos-experiment.sh` and `./scripts/validate-python-chaos-tests.sh` to `tests/chaos/` unchanged; add the suite lines, make targets and workflow from `./templates/environment-and-make.md`.
7. Run `./scripts/validate-python-chaos-tests.sh <product root>`; fix every FAIL, judge each WARN, and run it again until clean.
8. Run `make chaos`. Break one pattern on purpose and see its experiment fail for that reason, then restore it. Confirm the cluster is gone.
9. Write the report from `./templates/chaos-experiment-report.md` and put it to the product owner; a FAIL becomes a corrective action for the owning build skill.
10. Tick `./resources/checklist.md`; after any change, go back to step 7.

Worked: `./examples/01-lean-community-fridge.md` (patterns missing, a synchronous client in `async def`), `./examples/02-standard-bike-share-docks.md` (the lab that was run: every pattern both ways, the stall, real Toxiproxy, the runner), `./examples/03-enterprise-water-meter-readings.md` (several downstreams, pybreaker, a signed statement).

## Gotchas

- **One call while the link resets, asserting a fast error, as "the breaker test".** *Reason:* seen: it passed in 0.11 s with a breaker that never trips. *Instead:* drive to the threshold and assert every state, counting at the dependency.
- **A recovery poll as proof of recovery.** *Reason:* it passes when the breaker never opened. *Instead:* assert open first, then the transitions.
- **`toxiproxy-python`.** *Reason:* its `add_toxic` returns nothing: a toxic refused with HTTP 400 is never noticed. *Instead:* the `toxics` fixture (seen: `Toxiproxy answered 400` became INVALID).
- **Reading half-open by sleeping and checking the state.** *Reason:* seen with pybreaker and purgatory: the state stays open until a call arrives. *Instead:* assert half-open through the probe call.
- **purgatory without a probe limit, or without `exclude=[asyncio.CancelledError, ...]`.** *Reason:* seen: five callers all went through in half-open; caller cancellations opened the breaker. *Instead:* one lock; exclude the caller's cancellation and 4xx.
- **A test with no deadline of its own around a retry.** *Reason:* seen: with `stop` removed, the call never returned. *Instead:* `bounded` around every call.
- **`async with semaphore:` as a bulkhead.** *Reason:* `acquire()` takes no timeout; a full pool queues without bound. *Instead:* bound the acquire.
- **`time.sleep` or `requests` inside `async def`.** *Reason:* seen: the same worker's health check took 913 ms during a 1 s stall. *Instead:* async clients, `asyncio.to_thread`, or a process pool.
- **A bare `pytest tests/chaos`, or a definition without `-p no:rerunfailures` and `-o addopts=""`.** *Reason:* the guard refuses it; the runner refuses the definition. *Instead:* `make chaos`.

## Output

| File | When to open it |
|---|---|
| `./references/where-it-runs.md` | Where a fault may go; the statement; the privileged injector; cadence |
| `./references/experiment-method.md` | Steady state, hypothesis, blast radius, abort, verdicts |
| `./references/patterns-and-assertions.md` | Each pattern's assertion; library differences; missing patterns; DLQ, idempotency, 429 |
| `./references/chaos-mesh-on-kind.md` | Chaos Mesh 2.8.8 in the throwaway cluster |
| `./templates/experiment-definition.md` | Writing `tests/chaos/experiments/<id>.json` |
| `./templates/chaos-support.md` | `conftest.py`, `FaultTransport`, the stand-in dependency, the Toxiproxy helper, `stall_app` |
| `./templates/pattern-tests.md` | The pytest tests for breaker, retry, timeout, bulkhead |
| `./templates/event-loop-stall.md` | The event-loop stall experiment |
| `./templates/toxiproxy-setup.md` | Toxiproxy in the throwaway cluster; the deployed experiment |
| `./templates/chaos-mesh-manifests.md` | Chaos Mesh values, PodChaos, NetworkChaos, Schedule |
| `./templates/environment-and-make.md` | Suite lines, make targets, the workflow |
| `./templates/chaos-statement.md` | Any system other than the throwaway cluster |
| `./templates/chaos-experiment-report.md` | Reporting a run |
| `./scripts/run-chaos-experiment.sh` | Copied to the product; the only way an experiment starts |
| `./scripts/validate-python-chaos-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |
