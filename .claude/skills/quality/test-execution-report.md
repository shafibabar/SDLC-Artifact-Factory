# Skill: quality/test-execution-report

## Purpose
Produce a Test Execution Report for a completed test run — the structured record of what was tested, what passed, what failed, and what the outcome means for the release. Used as evidence for the Quality DoD gate, compliance audits, and retrospective analysis.

## Inputs
- Test run output (passed as context or via CI artifact)
- `artifacts/quality/test-plan.md`
- **Argument required:** run ID in format `YYYY-MM-DDTHH-MM-{type}` (e.g. `2026-06-20T14-30-integration`)

## Output
**File:** `artifacts/quality/reports/{run-id}.md`
**Registers in manifest:** yes

## Report Rules (enforced)
- Run ID is in ISO 8601 format — machine-parseable, sortable.
- Every test layer is reported with pass/fail counts (not just overall).
- Failures are listed with: test name, failure message, link to CI job.
- Coverage numbers are reported against targets from test-plan.md.
- Release recommendation is explicit: APPROVED / BLOCKED / CONDITIONAL.

## Artifact Template

```markdown
# Test Execution Report: {run-id}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Test Execution Report
**Run ID:** {run-id}
**Run type:** {integration | e2e | performance | load | security | chaos | compliance | full}
**Environment:** {CI | Staging | Local}
**Started:** {ISO 8601 timestamp}
**Completed:** {ISO 8601 timestamp}
**Duration:** {HH:MM:SS}
**Triggered by:** {commit SHA | schedule | manual}
**Version:** 1.0
**Status:** {PASS | FAIL | PARTIAL}

---

## Executive Summary

| Category | Result | Notes |
|----------|--------|-------|
| Unit tests | {PASS / FAIL} | {N passed, N failed, N skipped} |
| Integration tests | {PASS / FAIL} | — |
| Contract tests | {PASS / FAIL} | — |
| E2E tests | {PASS / FAIL} | — |
| Performance tests | {PASS / FAIL / SKIP} | — |
| Security tests (SAST) | {PASS / FAIL} | — |
| Compliance tests | {PASS / FAIL / SKIP} | — |
| **Overall** | **{PASS / FAIL}** | — |

---

## Coverage Report

| Package type | Target | Actual | Status |
|-------------|--------|--------|--------|
| `internal/domain/aggregates` | 90% | {actual}% | {PASS/FAIL} |
| `internal/application/commands` | 80% | {actual}% | {PASS/FAIL} |
| `internal/application/queries` | 70% | {actual}% | {PASS/FAIL} |
| `internal/api/handlers` | 75% | {actual}% | {PASS/FAIL} |
| `internal/infrastructure` | 60% | {actual}% | {PASS/FAIL} |

---

## Unit Test Results

**Service:** {service name}
**Passed:** {N} | **Failed:** {N} | **Skipped:** {N} | **Duration:** {Xs}

### Failures (if any)

| Test name | Failure message | CI link |
|-----------|----------------|---------|
| `TestStorageLocation_Register_RejectsEmptyPath` | `expected ErrInvalidStoragePath, got nil` | [Run #1234](https://github.com/...) |

---

## Integration Test Results

**Passed:** {N} | **Failed:** {N} | **Duration:** {Xs}
**Infrastructure:** PostgreSQL 16 (testcontainers), Redpanda {version}

### Failures (if any)

| Test name | Failure message | CI link |
|-----------|----------------|---------|
| — | — | — |

---

## Contract Test Results

| Consumer | Provider | Contract | Result |
|---------|---------|---------|--------|
| entity-domain | file-domain | FileProcessed.v1 | PASS |
| compliance-domain | entity-domain | EntitiesExtracted.v1 | PASS |

---

## E2E Test Results

**Environment:** Staging (k3s)
**Passed:** {N} | **Failed:** {N}

### Scenario Results

| Scenario | Result | Duration | Notes |
|---------|--------|---------|-------|
| Register and scan storage location | PASS | 45s | — |
| Compliance posture visible after scan | PASS | 62s | — |
| Cross-tenant isolation | PASS | 12s | — |

---

## Performance Test Results (if run)

| Scenario | p50 | p95 | p99 | Error rate | Threshold | Result |
|---------|-----|-----|-----|-----------|----------|--------|
| PT-01 Read | 45ms | 120ms | 380ms | 0.001% | p(99)<500ms | PASS |
| PT-02 Write | 89ms | 220ms | 780ms | 0.0% | p(99)<1000ms | PASS |

---

## Security Test Results (if run)

| Tool | Findings | Severity | Disposition |
|------|---------|---------|-------------|
| gitleaks | 0 | — | PASS |
| gosec | 2 | LOW | Acknowledged (.gosec-ignore) |
| govulncheck | 0 | — | PASS |
| trivy (image) | 1 | MEDIUM | Under review — tracking issue #142 |

---

## Compliance Test Results (if run)

| Framework | Controls tested | Passed | Failed | Result |
|----------|----------------|--------|--------|--------|
| GDPR | 8 | 8 | 0 | PASS |
| SOC 2 | 12 | 11 | 1 | FAIL |

### Compliance Failures

| Test ID | Control | Failure |
|---------|---------|---------|
| CT-SOC2-07 | Audit trail retention 7 years | Retention enforcer not deployed in staging |

---

## Known Issues

| Issue | Severity | Ticket | Disposition |
|-------|---------|--------|-------------|
| trivy MEDIUM in base image | MEDIUM | #142 | PR open — fix before release |

---

## Release Recommendation

**Recommendation:** {APPROVED / BLOCKED / CONDITIONAL}

**BLOCKED if:**
- Any unit, integration, or contract test failed
- Any CRITICAL/HIGH SAST or vulnerability finding not acknowledged
- Any security gate test failed (cross-tenant isolation, auth)

**CONDITIONAL if:**
- Performance thresholds met but at the edge (within 10% of threshold)
- MEDIUM security finding with open tracking issue

**Approved:** {name of QA lead} | **Date:** {date}
```

## Quality Checks
- [ ] Run ID is in ISO 8601 sortable format
- [ ] All test layers reported with pass/fail counts (not just "all passed")
- [ ] Coverage actuals vs targets for each package type
- [ ] Failures listed with test name, message, and CI link
- [ ] Security findings listed with severity and disposition (not just count)
- [ ] Release recommendation is explicit (APPROVED / BLOCKED / CONDITIONAL) with criteria
- [ ] Known issues table is present even when empty
