# Standard: an Observatory's Telescope Booking

Two Go services, `bookings` (PostgreSQL) and `scheduler`, plus a web shell. A booking is accepted at once and the scheduler allocates telescope time for it a little later. This example shows the suite passing, a journey failing, a flaky journey, a release that never becomes ready, and an interrupted run.

Run on 2026-11-28: Go 1.27.4, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, GNU Make 3.81, macOS arm64. The services were a lab stand-in configured with this product's resources and charts; the script, guard and suite files are the shipped ones. The Go files are exactly those of `../templates/go-suite.md` and `../templates/direct-database-seed.md`, and the configuration is that of `../templates/environment-config.md`, so they are not repeated here.

## Plan

| Journey | Acceptance criteria | Why it is end-to-end |
|---|---|---|
| A booked slot is allocated | AC-US-4.1, AC-US-4.2 | Two deployed services; the allocation arrives later |
| A cancelled booking is gone | AC-US-5.1 | Service and database as deployed |
| An archived booking is still readable | AC-US-6.2 | The state has no public route, so it is seeded straight into the throwaway database |

| Considered and pushed down | Layer |
|---|---|
| Overlapping bookings are refused; night must be in the future | Unit |
| Two requests for the same slot at once | Integration (real commit, `go-integration-test`) |
| The message the scheduler accepts | Contract (`go-contract-test`) |
| Create, read back, change, read again against `bookings` alone | Integration: a workflow test through the real router |

Smoke: one read, "bookings can be listed".

### `tests/e2e/values/scheduler.yaml`

```yaml
env:
  RESOURCE: allocations
service:
  type: NodePort
  nodePort: 30081
```

### `tests/e2e/values/web-shell.yaml`

```yaml
env:
  STATIC_TITLE: Observatory bookings
service:
  type: NodePort
  nodePort: 30082
```

## A passing run

```text
== suite: ./tests/e2e/run-go-e2e-suite.sh journeys
--- PASS: TestGuard_ClientRefusesAnotherHost (0.00s)
--- PASS: TestGuard_SeedingRefusesAnAddressOutsideTheCluster (0.00s)
--- PASS: TestGuard_MarkerMustBeThisRunAndLoopback (0.00s)
--- PASS: TestJourney_ArchivedBookingStillReadable (0.01s)
--- PASS: TestJourney_BookedSlotIsAllocated (1.61s)
--- PASS: TestJourney_CancelledBookingIsGone (0.00s)
== journeys: 6 ran, 6 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: ./tests/e2e/run-go-e2e-suite.sh smoke
--- PASS: TestSmoke_BookingsCanBeListed (0.00s)
--- PASS: TestSmoke_WritesAreRefused (0.00s)
== smoke: 2 ran, 2 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: ./tests/e2e/run-go-e2e-suite.sh quarantine
quarantine: the list is empty; nothing to run
== deleting cluster e2e-local-1795825374-65001
== end-to-end run local-1795825374-65001 passed; cluster deleted
```

`TestJourney_BookedSlotIsAllocated` took 1.61 seconds because it polled until the booking was confirmed; the scheduler answers after 1.5 seconds in this configuration. Nothing slept for a fixed time.

A lab-only test in the same cluster confirmed the trace id: the test printed `b85e022a138f39b7c7c8ecb217b70146`, `bookings` received `traceparent: 00-b85e022a138f39b7c7c8ecb217b70146-efac9d7b6da8ba74-01`, and `scheduler` received the same value from `bookings`.

## A journey that fails

One test was made to fail on every attempt.

```text
    lab_only_test.go:57: lab: failing on purpose
    trace_test.go:37: trace_id=246ff90dbaf4dff34e6ac79a20fbd1fd
--- FAIL: TestLab_Controlled (0.00s)
== retrying once, by exact name: TestLab_Controlled
    lab_only_test.go:57: lab: failing on purpose
    trace_test.go:37: trace_id=d97f744ce353180857159a1fc15e9aa7
--- FAIL: TestLab_Controlled (0.00s)
== journeys: 8 ran, 7 passed first time, 0 flaky, 1 failed, 0 skipped, 0 quarantined
FAIL TestLab_Controlled: failed twice (trace_id=d97f744ce353180857159a1fc15e9aa7)
== suite: ./tests/e2e/run-go-e2e-suite.sh smoke
== smoke: 2 ran, 2 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== collecting evidence into .../e2e-evidence
== deleting cluster e2e-local-1795824070-49898
== end-to-end run local-1795824070-49898 FAILED; evidence in .../e2e-evidence
make: *** [e2e] Error 1
```

- One retry, by exact name, then a verdict. The smoke suite still ran.
- Evidence was collected **before** the cluster was deleted: `cluster-state.txt`, `describe-pods.txt`, `events.txt`, `helm-releases.txt`, `kind-nodes/`, `logs/` with one file per Pod (the database's held 61 lines; a selector's default would have cut it to 10), `results/` and `run.txt`.
- `make e2e` exited non-zero and `kind get clusters` no longer listed the run's cluster.

The reply to the person who asked: which test failed twice, both trace ids, where the evidence is, and that the release job that needs this suite will not publish.

## A flaky journey

The same test was made to fail on its first attempt only.

```text
== retrying once, by exact name: TestLab_Controlled
== journeys: 8 ran, 7 passed first time, 1 flaky, 0 failed, 0 skipped, 0 quarantined
FLAKY TestLab_Controlled: failed, then passed on the one retry (trace_id=f271b2ef46bd6baaa5126191de8de7c6). Record it; a second flake means quarantine.
== end-to-end run local-1795824121-50623 passed; cluster deleted
```

The run passes and the report says **flaky**, with the trace id of the failed attempt. It is not reported as green. On its second flake across recent runs the test goes into `tests/e2e/quarantine.txt` with an issue and a deadline (`test-pyramid`; `../references/retry-and-quarantine.md`).

## A release that never becomes ready

The scheduler's image was replaced with one that cannot be pulled, with `E2E_INSTALL_TIMEOUT=25s`.

```text
== installing scheduler from charts/scheduler
Error: resource Deployment/observatory/scheduler not ready. status: InProgress, message: Available: 0/1
ERROR: release scheduler did not become ready
== collecting evidence into .../e2e-evidence
== deleting cluster e2e-local-1795824222-51988
== end-to-end run local-1795824222-51988 FAILED; evidence in .../e2e-evidence
```

No suite ran against a half-installed environment. `helm-releases.txt` showed `scheduler ... failed` and the events held the image pull failure, because the install did not use `--rollback-on-failure`: with that flag Helm would have removed the release and its Pods before anything could be collected. Without `--wait` the same install reported success.

## An interrupted run

| Signal | When | Result |
|---|---|---|
| SIGINT | While the cluster was being created | Exit 130 after 0.6 s; no cluster left |
| SIGTERM | While Helm was installing the database | Exit 130 after 0.6 s; no cluster, no `helm` process left |
| SIGHUP | While Helm was installing a service | Exit 130 after 0.7 s; no cluster left |
| SIGINT, SIGTERM | While a journey was polling | Exit 130 after 0.8 s and 0.7 s; no cluster, no test process left |

## The guard, by hand

Someone runs the journeys directly, with an address they believe is right:

```text
$ E2E_BASE_URL=https://staging.observatory.example go test -tags e2e ./tests/e2e/
REFUSED: end-to-end journeys run only against the throwaway cluster of their own run.
  E2E_RUN_ID is not set: start the suite with tests/e2e/run-e2e-environment.sh (make e2e)
FAIL	example.test/product/tests/e2e	0.198s
```

`E2E_BASE_URL` is not read by anything. Pointed at another kind cluster on the same machine, the journeys refuse as well: `this cluster carries no run marker, so this run did not create it`.

## What this environment did not prove

One node; entry through NodePorts, not the production ingress; no service mesh; an empty database. The report says so and names what covers each (`go-load-test` for behaviour under load, the staging soak for the ingress and mesh path).
