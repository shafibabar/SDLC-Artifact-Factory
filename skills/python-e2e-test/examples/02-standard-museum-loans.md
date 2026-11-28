# Standard: a Museum's Exhibit Loans

Two Python services, `loans` (FastAPI, PostgreSQL) and `couriers`, plus a web shell. A loan request is accepted at once and the courier service schedules a pickup for it a little later. This example shows the suite passing, a journey failing, a flaky journey, the guard stopping a run by hand, an interrupted run, and the smoke tests against a server outside any cluster.

Run on 2026-11-28: Python 3.15.2, pytest 9.2.0, pytest-asyncio 1.5.0, httpx 0.29.0, asyncpg 0.32.0, uv 0.13.9, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, GNU Make 3.81, macOS arm64. The services were a lab stand-in configured with this product's resources and charts; the scripts, guard and suite files are the shipped ones. The Python files are exactly those of `../templates/python-suite.md` and `../templates/direct-database-seed.md`, the configuration is that of `../templates/environment-config.md` and the targets those of `../templates/make-targets.md`, so they are not repeated here.

## Plan

| Journey | Acceptance criteria | Why it is end-to-end |
|---|---|---|
| A requested loan gets a courier pickup | AC-US-3.1, AC-US-3.2 | Two deployed services; the pickup arrives later |
| A withdrawn loan request is gone | AC-US-3.4 | Service and database as deployed |
| A returned loan is still readable | AC-US-5.2 | The state has no public route, so it is seeded straight into the throwaway database |

| Considered and pushed down | Layer |
|---|---|
| A loan cannot be due before today; an exhibit already on loan is refused | Unit |
| Two requests for the same exhibit at once | Integration (real commit, `python-integration-test`) |
| The message the courier service accepts | Contract (`python-contract-test`) |
| Create, read back, change, read again against `loans` alone | Integration: a workflow test through the real application |

Smoke: one read, "loans can be listed".

## A passing run

```text
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh journeys
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_client_refuses_another_address PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_client_refuses_a_redirect_to_another_address PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_seeding_refuses_an_address_outside_the_cluster PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_marker_must_be_this_run_and_loopback PASSED
tests/e2e/journeys/test_journey_loan.py::test_journey_requested_loan_gets_a_courier_pickup PASSED
tests/e2e/journeys/test_journey_loan.py::test_journey_withdrawn_loan_is_gone PASSED
tests/e2e/journeys/test_journey_loan.py::test_journey_loan_is_confirmed_async PASSED
tests/e2e/journeys/test_journey_returned_loan.py::test_journey_returned_loan_is_still_readable PASSED
== python journeys: 8 ran, 8 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh smoke
tests/e2e/smoke/test_smoke.py::test_smoke_loans_can_be_listed PASSED
tests/e2e/smoke/test_smoke_guard.py::test_smoke_writes_are_refused PASSED
tests/e2e/smoke/test_smoke_guard.py::test_smoke_client_refuses_another_address PASSED
== python smoke: 3 ran, 3 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
quarantine: the list is empty; nothing to run
== deleting cluster e2e-pe2e-lab-14
== end-to-end run pe2e-lab-14 passed; cluster deleted
```

The per-test lines are shortened by their percentage column only. The synchronous and the async journey waited by polling: the courier service answers after 1.5 seconds in this configuration, and nothing slept for a fixed time. The whole run took 54 seconds, images already built.

Another run of the same suite, with three lab-only tests added (11 ran), confirmed the trace id: the test's id was `cef5ff38c24631a821b2153f3f5ca26c`, `loans` received `traceparent: 00-cef5ff38c24631a821b2153f3f5ca26c-4ea9b8d37cc0b99e-03`, and `couriers` received the same value from `loans`.

## A journey that fails

One lab-only test was made to wait for a state that never comes. The output is shortened to the lines that matter.

```text
tests/e2e/journeys/test_lab_only.py::test_lab_controlled FAILED
E   AssertionError: status never: not true within 3s; last: AssertionError("still not 'never'\nassert 'confirmed' == 'never' ...")
------------------------------------ trace -------------------------------------
trace_id=c3d35de5ec3f36dee52cc160d31d1658
== retrying once, by exact node id: tests/e2e/journeys/test_lab_only.py::test_lab_controlled
tests/e2e/journeys/test_lab_only.py::test_lab_controlled FAILED
trace_id=9f08e91c1d613e0dde32638cda93f988
== python journeys: 11 ran, 10 passed first time, 0 flaky, 1 failed, 0 skipped, 0 quarantined
FAIL tests/e2e/journeys/test_lab_only.py::test_lab_controlled: failed twice (trace_id=9f08e91c1d613e0dde32638cda93f988)
suite FAILED: uv run ./tests/e2e/run-python-e2e-suite.sh journeys
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh smoke
== python smoke: 3 ran, 3 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== collecting evidence into .../e2e-evidence
== deleting cluster e2e-pe2e-lab-12
== end-to-end run pe2e-lab-12 FAILED; evidence in .../e2e-evidence
make: *** [e2e] Error 1
```

- The wait failed at its deadline with the last thing it saw, not with a bare timeout.
- One retry, by exact node id, in a new pytest process (a new trace id), then a verdict. The smoke suite still ran.
- Evidence was collected **before** the cluster was deleted: `cluster-state.txt`, `describe-pods.txt`, `events.txt`, `helm-releases.txt`, `kind-nodes/`, `logs/` with one file per Pod (the database's held 62 lines), `results/` and `run.txt`.
- `make e2e` exited non-zero and `kind get clusters` no longer listed the run's cluster.

The reply to the person who asked: which test failed twice, both trace ids, where the evidence is, and that the release job that needs this suite will not publish.

## A flaky journey

The same test was made to fail on its first attempt only.

```text
== retrying once, by exact node id: tests/e2e/journeys/test_lab_only.py::test_lab_controlled
== python journeys: 11 ran, 10 passed first time, 1 flaky, 0 failed, 0 skipped, 0 quarantined
FLAKY tests/e2e/journeys/test_lab_only.py::test_lab_controlled: failed, then passed on the one retry (trace_id=8357435896dbe9cf404a19ab87d073be). Not green: record it; a second flake means quarantine.
== end-to-end run pe2e-lab-13 passed; cluster deleted
```

The run passes and the report says **flaky**, with the trace id of the failed attempt. It is not reported as green. pytest alone could not say this: with a rerun plugin its exit status for this run would be 0 and its JUnit file would show an ordinary pass. On its second flake across recent runs the test goes into `tests/e2e/quarantine-python.txt` with an issue and a deadline (`test-pyramid`; `../references/retry-and-quarantine.md`).

## The guard, by hand

Someone runs the journeys directly, with an address they believe is right:

```text
$ E2E_BASE_URL=https://staging.museum.example pytest tests/e2e/journeys
REFUSED: end-to-end journeys run only against the throwaway cluster of their own run.
  E2E_RUN_ID is not set: start the suite with tests/e2e/run-e2e-environment.sh (make e2e)
```

`E2E_BASE_URL` is not read by anything. Every journey ends as that error and no request is sent. Pointed at another kind cluster on the same machine, the journeys refuse as well (`this cluster carries no run marker, so this run did not create it`), and with another run's marker planted in it (`run marker says run 'someone-else'`). Through the runner the same refusal is reported once: `FAIL: the run broke: the guard refused the target. Not retried.`

## An interrupted run

| Signal | When | Result |
|---|---|---|
| SIGINT | While a Python journey was polling | The script exited 130 after 1.0 s; no cluster, no pytest and no runner process left |
| SIGTERM | The same | The same, after 1.0 s |

## Smoke tests outside the cluster

`E2E_SMOKE_URL=http://127.0.0.1:<port> make e2e-smoke` against a plain server on the machine: three tests passed and the server's log held one line, `GET /loans`, with a `traceparent`.

| Tried | Result |
|---|---|
| A smoke test that POSTs | `Refused: refusing POST /loans: smoke tests are read-only`, twice (first attempt and retry); `make e2e-smoke` failed; the server received no write; the validator reports `FAIL SMOKEWRITE` |
| A journey file copied into the smoke folder | `fixture 'api' not found`; the journey that asks for `env` is `REFUSED`; the server received no write; the validator reports eleven `FAIL SMOKEWRITE` lines |
| A journey marked `@pytest.mark.smoke` | pytest stops with a usage error (exit 4): `an end-to-end test is either a journey ... or a read-only smoke test ..., never both` |
| A smoke folder with no test; every smoke test skipped | The runner exits 3 both times. pytest itself exits 5 for the first and **0** for the second |

## What this environment did not prove

One node; entry through NodePorts, not the production ingress; no service mesh; an empty database. The report says so and names what covers each (`python-load-test` for behaviour under load, the staging soak for the ingress and mesh path).
