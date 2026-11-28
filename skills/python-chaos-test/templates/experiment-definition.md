# The Experiment Definition

Self-contained. Copy one file per hypothesis to `tests/chaos/experiments/<experiment id>.json` and fill every field. `run-chaos-experiment.sh` reads it, refuses a definition with a missing or impossible field (exit 2), and runs it once. A definition does not depend on the product's language: the three `toxiproxy` and `chaos-mesh` definitions below are `go-chaos-test`'s, run there on 2026-11-28 in a throwaway kind cluster, and are kept identical in both skills (`tests/scripts/python-chaos-copies.test.sh`). The `pytest` definition is this skill's lab's, run on 2026-11-28 through the runner (`../examples/02-standard-bike-share-docks.md`).

| Field | Rule |
|---|---|
| `experiment_id` | Names the result file and the report row |
| `pattern` | The pattern(s) under test, in `integration-design`'s words; `missing` patterns are never listed here |
| `hypothesis` | "Users still get X when Y fails", with the fault and the user's outcome |
| `blast_radius` | Exactly what the fault may touch, in words |
| `steady_state` | The SLO's SLI exactly: `slo_id`, `sli` (its words), `endpoint` (a name from `E2E_ENDPOINTS`), `path`, `good_statuses`, `under_ms`, `objective`, and the probe's `probe_per_second` and `window_seconds`. Required for `toxiproxy` and `chaos-mesh`. Optional `fault_header`: the header the product sets on a degraded answer; when set, a fault that marked no answer is INVALID (it never reached the measured path) |
| `fault` | `toxiproxy`: `endpoint`, `proxy`, `toxic` {`name`, `type`, `stream`, `attributes`}. `chaos-mesh`: `manifest`. `pytest`: `command` (`pytest`, `python -m pytest` or `uv run pytest`, with `-m chaos`, `-p no:cacheprovider`, `-p no:rerunfailures` and `-o addopts=""`; never `--reruns`, `--lf`, `--ff`, `--sw`, `--count` or `--junitxml`: the runner adds its own report path) and optionally `reset_toxiproxy` (an endpoint name: Toxiproxy is reset and checked empty afterwards). `go-test` is `go-chaos-test`'s |
| `fault_seconds` | How long the fault stays; at most `abort.max_seconds` |
| `abort` | `sli_below`, `over_seconds`, `max_seconds`; for `pytest` (and `go-test`) only `max_seconds` |
| `recovery.within_seconds` | How soon the steady state must return after removal |
| `does_not_prove` | Optional: what this experiment does not show, copied into the result and the report |

### `tests/chaos/experiments/degrade-on-tides-latency.json`

```json
{
 "experiment_id": "degrade-on-tides-latency",
 "pattern": "graceful-degradation",
 "hypothesis": "Users still get a tide window, answered 200 in under 800 ms, while the tide tables answer 2 s late",
 "blast_radius": "the tides proxy of this run's cluster: every call from harbour to tides",
 "steady_state": {
  "slo_id": "SLO-TIDE-01",
  "sli": "share of tide-window requests answered 200 in under 800 ms",
  "endpoint": "api",
  "path": "/v1/tide-window?berth=B1",
  "good_statuses": [
   200
  ],
  "under_ms": 800,
  "fault_header": "X-Degraded",
  "objective": 0.99,
  "probe_per_second": 5,
  "window_seconds": 20
 },
 "fault": {
  "tool": "toxiproxy",
  "endpoint": "toxiproxy",
  "proxy": "tides",
  "toxic": {
   "name": "tides-latency",
   "type": "latency",
   "stream": "downstream",
   "attributes": {
    "latency": 2000
   }
  }
 },
 "fault_seconds": 30,
 "abort": {
  "sli_below": 0.9,
  "over_seconds": 10,
  "max_seconds": 60
 },
 "recovery": {
  "within_seconds": 30
 }
}
```

### `tests/chaos/experiments/pod-kill-harbour.json`

```json
{
 "experiment_id": "pod-kill-harbour",
 "pattern": "redundancy",
 "hypothesis": "Users still get a tide window when one of the two harbour pods is killed",
 "blast_radius": "one harbour pod in namespace harbour of this run's cluster",
 "steady_state": {"slo_id": "SLO-TIDE-01", "sli": "share of tide-window requests answered 200 in under 800 ms", "endpoint": "api",
   "path": "/v1/tide-window?berth=B1", "good_statuses": [200], "under_ms": 800, "objective": 0.99, "probe_per_second": 5, "window_seconds": 20},
 "fault": {"tool": "chaos-mesh", "manifest": "tests/chaos/mesh/pod-kill-harbour.yaml"},
 "fault_seconds": 30,
 "abort": {"sli_below": 0.5, "over_seconds": 10, "max_seconds": 60},
 "recovery": {"within_seconds": 60}
}
```

### `tests/chaos/experiments/network-partition-tides.json`

```json
{
 "experiment_id": "network-partition-tides",
 "pattern": "circuit-breaker, graceful-degradation",
 "hypothesis": "Users still get a tide window while the tide-tables pod is cut off from the network",
 "blast_radius": "the tides pod in namespace harbour of this run's cluster",
 "steady_state": {
  "slo_id": "SLO-TIDE-01",
  "sli": "share of tide-window requests answered 200 in under 800 ms",
  "endpoint": "api",
  "path": "/v1/tide-window?berth=B1",
  "good_statuses": [
   200
  ],
  "under_ms": 800,
  "fault_header": "X-Degraded",
  "objective": 0.99,
  "probe_per_second": 5,
  "window_seconds": 20
 },
 "fault": {
  "tool": "chaos-mesh",
  "manifest": "tests/chaos/mesh/network-partition-tides.yaml"
 },
 "fault_seconds": 30,
 "abort": {
  "sli_below": 0.9,
  "over_seconds": 10,
  "max_seconds": 60
 },
 "recovery": {
  "within_seconds": 60
 }
}
```

### `tests/chaos/experiments/patterns-in-process.json`

The pytest experiments of `./pattern-tests.md`, `./event-loop-stall.md` and `./toxiproxy-setup.md` as one experiment. Their faults are injected inside the tests; the runner checks the run marker, gives them `CHAOS_EXPERIMENT_ID` (without which `tests/chaos/conftest.py` refuses every test), clears `PYTEST_ADDOPTS`, adds `--junitxml` and reads it, reads `CHAOS-INVALID`, `CHAOS-REFUSED` and `CHAOS-FAULT-LEFT`, and resets Toxiproxy afterwards. Run: PASS with 8 tests; FAIL on a copy with a breaker that never trips (`pytest: 2 failed, 0 error(s) of 5`); INVALID for a misspelt toxic (`Toxiproxy answered 400`), for a selection that collected nothing (`pytest collected no test (exit 5)`) and for a skipped test (`pytest skipped 1 of 1 test(s)`). `--tb=short` keeps pytest from echoing whole functions, so a marker is read only where a test raised it.
```json
{
 "experiment_id": "patterns-in-process",
 "pattern": "circuit-breaker, retry, timeout, bulkhead, event-loop-stall, graceful-degradation",
 "hypothesis": "Each pattern behaves as integration-design defines it under the fault its test injects",
 "blast_radius": "inside the pytest process and the worker processes it starts, and the toxiproxy of this run's cluster",
 "fault": {"tool": "pytest", "command": "python -m pytest tests/chaos -m chaos -p no:cacheprovider -p no:rerunfailures -o addopts=\"\" --tb=short -q", "reset_toxiproxy": "toxiproxy"},
 "abort": {"max_seconds": 600}
}
```

Under a signed chaos statement only `toxiproxy` definitions run, and the runner also refuses one whose toxic attributes, length or abort conditions go beyond what was signed (`./chaos-statement.md`).
