# The Experiment Definition

Self-contained. Copy one file per hypothesis to `tests/chaos/experiments/<experiment id>.json` and fill every field. `run-chaos-experiment.sh` reads it, refuses a definition with a missing or impossible field (exit 2), and runs it once. The four lab definitions below were run on 2026-11-28 in a throwaway kind cluster, each through the unmodified runner.

| Field | Rule |
|---|---|
| `experiment_id` | Names the result file and the report row |
| `pattern` | The pattern(s) under test, in `integration-design`'s words; `missing` patterns are never listed here |
| `hypothesis` | "Users still get X when Y fails", with the fault and the user's outcome |
| `blast_radius` | Exactly what the fault may touch, in words |
| `steady_state` | The SLO's SLI exactly: `slo_id`, `sli` (its words), `endpoint` (a name from `E2E_ENDPOINTS`), `path`, `good_statuses`, `under_ms`, `objective`, and the probe's `probe_per_second` and `window_seconds`. Required for `toxiproxy` and `chaos-mesh`. Optional `fault_header`: the header the product sets on a degraded answer; when set, a fault that marked no answer is INVALID (it never reached the measured path) |
| `fault` | `toxiproxy`: `endpoint`, `proxy`, `toxic` {`name`, `type`, `stream`, `attributes`}. `chaos-mesh`: `manifest`. `go-test`: `command` (with `-tags chaos` and `-count=1`) and optionally `reset_toxiproxy` (an endpoint name: Toxiproxy is reset and checked empty afterwards) |
| `fault_seconds` | How long the fault stays; at most `abort.max_seconds` |
| `abort` | `sli_below`, `over_seconds`, `max_seconds`; for `go-test` only `max_seconds` |
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

The Go tests of `./pattern-tests.md` and `./toxiproxy-setup.md` as one experiment. Their faults are injected inside the test; the runner checks the run marker, reads `CHAOS-INVALID`, `CHAOS-REFUSED` and `CHAOS-FAULT-LEFT`, and resets Toxiproxy afterwards.
```json
{
 "experiment_id": "patterns-in-process",
 "pattern": "circuit-breaker, retry, timeout, bulkhead, graceful-degradation, load-shedding, lock-order",
 "hypothesis": "Each pattern behaves as integration-design defines it under the fault its test injects",
 "blast_radius": "inside the go test process, and the toxiproxy of this run's cluster",
 "fault": {"tool": "go-test", "command": "go test -tags chaos -count=1 -timeout 10m ./internal/... ./tests/chaos/...", "reset_toxiproxy": "toxiproxy"},
 "abort": {"max_seconds": 600}
}
```

Under a signed chaos statement only `toxiproxy` definitions run, and the runner also refuses one whose toxic attributes, length or abort conditions go beyond what was signed (`./chaos-statement.md`).
