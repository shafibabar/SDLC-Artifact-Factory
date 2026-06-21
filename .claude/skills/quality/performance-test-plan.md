# Skill: quality/performance-test-plan

## Purpose
Produce the Performance Test Plan — the specification of what performance tests will be run, against which endpoints and workflows, with what load shape, and with what measurable acceptance thresholds tied to SLOs. A performance test without defined thresholds is not a test — it is a benchmark.

## Inputs
- `artifacts/design/platform/observability-design.md` (SLOs)
- `artifacts/ideate/requirements/nfrs.md`
- `artifacts/quality/test-plan.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/quality/performance-test-plan.md`
**Registers in manifest:** yes

## Performance Test Rules (enforced)
- Every scenario has explicit acceptance thresholds (p50, p95, p99, error rate).
- Thresholds are derived from SLOs — not invented.
- Load shape is realistic: ramp-up, steady state, ramp-down.
- Tests run against staging (production-like), never against production.
- k6 is the tool — scripts are committed to the platform repo.

## Artifact Template

```markdown
# Performance Test Plan

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Performance Test Plan
**Tool:** k6 v0.55+
**Environment:** Staging (k3s, production-like configuration)
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## SLO-Derived Thresholds

These thresholds are derived directly from the SLOs in `artifacts/design/platform/observability-design.md`. A performance test passing below these thresholds is a blocking defect.

| SLO | Target | Performance test threshold |
|-----|--------|--------------------------|
| API p99 latency (read endpoints) | < 500ms | p(99) < 500 |
| API p99 latency (write endpoints) | < 1000ms | p(99) < 1000 |
| API error rate | < 0.1% | error_rate < 0.001 |
| Scan initiation latency | < 2 seconds | p(99) < 2000 |
| Dashboard load (read model) | < 300ms | p(99) < 300 |

---

## Test Scenarios

### Scenario PT-01: Normal Load — API Read Endpoints

**Objective:** Verify API read endpoints meet SLOs under expected concurrent user load.
**Load shape:**
- Ramp-up: 0 → 50 VUs over 2 minutes
- Steady state: 50 VUs for 10 minutes
- Ramp-down: 50 → 0 VUs over 1 minute

**Target endpoints:**
```
GET /api/v1/storage-locations          (list, cursor pagination)
GET /api/v1/storage-locations/{id}     (by ID)
GET /api/v1/findings                   (list, filtered)
GET /api/v1/compliance/posture         (dashboard read model)
```

**Acceptance thresholds:**
```javascript
export const options = {
  thresholds: {
    http_req_duration: ['p(50)<100', 'p(95)<300', 'p(99)<500'],
    http_req_failed: ['rate<0.001'],
  },
};
```

---

### Scenario PT-02: Normal Load — Write Endpoints

**Objective:** Verify write endpoints (commands) meet SLOs without degrading read latency.

**Load shape:**
- Ramp-up: 0 → 20 VUs over 1 minute
- Steady state: 20 VUs for 5 minutes

**Target endpoints:**
```
POST /api/v1/storage-locations         (register)
POST /api/v1/storage-locations/{id}/scans  (initiate scan)
POST /api/v1/findings/{id}/acknowledge     (acknowledge)
```

**Acceptance thresholds:**
```javascript
thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.001'],
}
```

---

### Scenario PT-03: Concurrent Scan Initiation

**Objective:** Verify that 10 concurrent scan initiations do not cause deadlocks, timeout errors, or SLO degradation.

**Load shape:** 10 VUs each initiating a scan simultaneously (burst pattern).

**Acceptance thresholds:**
- All 10 scans accepted (no 429, no 500)
- p(99) scan initiation response time < 2000ms
- No database deadlocks (verify via PostgreSQL `pg_stat_activity` query post-test)

---

### Scenario PT-04: Compliance Dashboard Under Load

**Objective:** Verify the compliance posture read model responds within SLO when multiple compliance officers load their dashboards simultaneously.

**Load:** 25 VUs hitting dashboard endpoints for 5 minutes.

**Acceptance threshold:**
```javascript
thresholds: {
    http_req_duration: ['p(99)<300'],
    http_req_failed: ['rate<0.001'],
}
```

---

## k6 Script Structure

Scripts live in `{platform-repo}/performance-tests/`:

```
performance-tests/
  scenarios/
    pt-01-read-endpoints.js
    pt-02-write-endpoints.js
    pt-03-concurrent-scans.js
    pt-04-dashboard-load.js
  helpers/
    auth.js       # JWT acquisition helper
    setup.js      # Test data setup (create test tenant, populate data)
    teardown.js   # Clean up test data
  run-all.sh      # Runs all scenarios sequentially
```

---

## Test Data Requirements

| Scenario | Pre-seeded data |
|----------|----------------|
| PT-01 | 1,000 storage locations per tenant; 5,000 findings |
| PT-02 | 10 empty storage locations ready for scan initiation |
| PT-03 | 10 ACTIVE storage locations (one per VU) |
| PT-04 | Posture daily snapshot populated for 90 days |

---

## Pass / Fail

A performance test run **fails** if any threshold is breached. Results are published to Grafana k6 Cloud or stdout JSON. CI fails on threshold breach — the release is blocked.
```

## Quality Checks
- [ ] All thresholds are derived from SLOs — not invented
- [ ] Every scenario has explicit p(50)/p(95)/p(99) and error_rate thresholds
- [ ] Load shapes specify ramp-up, steady state, ramp-down
- [ ] Test data requirements are specified per scenario
- [ ] Script structure is documented (paths in platform repo)
- [ ] CI failure condition is explicit
