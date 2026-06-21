# Skill: quality/load-test-plan

## Purpose
Produce the Load Test Plan — the specification for sustained, above-normal, and breaking-point load tests. Where the performance test verifies SLOs under normal load, the load test finds where the system degrades, what the failure mode is, and whether it recovers. Identifies horizontal scaling thresholds and DLQ back-pressure behaviour.

## Inputs
- `artifacts/quality/performance-test-plan.md`
- `artifacts/design/platform/observability-design.md` (SLOs, capacity targets)
- `artifacts/ideate/requirements/nfrs.md`

## Output
**File:** `artifacts/quality/load-test-plan.md`
**Registers in manifest:** yes

## Load Test Rules (enforced)
- Peak load scenario is defined as 2× the expected normal concurrent load.
- Breaking point scenario ramps until SLO breach, then records the breaking VU count.
- Recovery behaviour is observed and documented: does the system recover after load drops?
- DLQ behaviour is observed: does back-pressure on Redpanda cause DLQ fill? Is it visible?

## Artifact Template

```markdown
# Load Test Plan

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Load Test Plan
**Tool:** k6 v0.55+
**Environment:** Staging (k3s, production-like — with autoscaling disabled to test hard limits)
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Load Test Scenarios

### Scenario LT-01: Peak Load — 2× Normal

**Objective:** Verify the system sustains SLOs under 2× expected peak concurrent load for 30 minutes.

**Normal VU baseline (from PT-01):** 50 VUs read, 20 VUs write
**Peak load:** 100 VUs read + 40 VUs write concurrent

**Load shape:**
```
VUs
100 ──────────────────────────────────────
 │                  ↑ hold 30 min        │
50  ───────────
 │  2 min ramp │                         │ 5 min ramp-down
 0  ───────────────────────────────────────────────────────> time
```

**Acceptance thresholds (same as SLO — must hold at 2× load):**
- p(99) read < 500ms
- p(99) write < 1000ms
- error_rate < 0.001
- No pod OOMKilled events
- No DLQ messages

**Failure criteria:**
- Any SLO threshold breached
- Any pod crash or OOMKill
- DLQ filling (indicates consumer can't keep up)

---

### Scenario LT-02: Sustained Load — 8-Hour Soak

**Objective:** Verify no memory leaks, connection pool exhaustion, or goroutine leaks under sustained normal load over 8 hours.

**Load:** 50 VUs, continuous, 8 hours

**Observations (sampled every 30 minutes):**
| Metric | Baseline | 2h | 4h | 6h | 8h |
|--------|----------|----|----|----|----|
| p99 latency | — | — | — | — | — |
| Error rate | — | — | — | — | — |
| Memory (MB) | — | — | — | — | — |
| Goroutine count | — | — | — | — | — |
| DB connections active | — | — | — | — | — |

**Failure criteria:**
- Memory growth > 20% from baseline to 8h mark (indicates leak)
- Goroutine count grows monotonically (indicates goroutine leak)
- DB connection pool exhaustion (pgxpool max_conns exceeded)

---

### Scenario LT-03: Breaking Point Test

**Objective:** Find the VU count at which the first SLO is breached. Document the failure mode and recovery.

**Load shape:**
- Start: 10 VUs
- Increase: +10 VUs every 2 minutes
- Stop: when first SLO breach detected OR when 200 VUs reached

**Observations to record:**
- VU count at first p(99) breach
- Which SLO was breached first
- Error types at breaking point
- Pod resource utilisation (CPU, memory) at breaking point

**Recovery test (run immediately after LT-03):**
- Drop load to 0 VUs
- Wait 5 minutes
- Ramp back to 50 VUs
- Verify SLOs return to normal within 2 minutes of ramp-up

---

### Scenario LT-04: Redpanda Back-Pressure

**Objective:** Verify that when the Entity Domain consumer is slowed (simulated by adding artificial latency), Redpanda back-pressure behaviour is observable, DLQ fill is visible in monitoring, and alerts fire.

**Setup:**
1. Deploy Entity Domain consumer with 2000ms artificial processing delay (feature flag)
2. Run File Domain at 50 VUs generating FileProcessed events

**Observations:**
- Consumer lag growing on `file-domain.file-processed` topic
- DLQ fill rate (if retry limit exceeded)
- Alert fires within 5 minutes of lag threshold breach
- When delay removed: lag drains within {expected_drain_time} minutes

---

## Reporting

Load test results are stored in `artifacts/quality/reports/{run-id}.md` using the `quality/test-execution-report` skill.

Key metrics to capture in the report:
- Breaking point VU count
- Peak load SLO compliance (pass/fail per threshold)
- Soak test memory/goroutine trend (graph)
- DLQ fill rate and drain rate
```

## Quality Checks
- [ ] Peak load is defined as at least 2× normal baseline
- [ ] Soak test is at least 4 hours (8 preferred)
- [ ] Breaking point test records the failure mode (not just the VU count)
- [ ] Recovery test is specified after breaking point
- [ ] DLQ back-pressure behaviour is explicitly tested
- [ ] Observability metrics (memory, goroutines, DB connections) are in the soak test
