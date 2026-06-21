# Skill: deploy/slo-definition

## Purpose
Produce the SLO Definitions document — the formal specification of Service Level Objectives for all services, their SLIs (measurements), error budgets, and alerting policies. SLOs are the contract between engineering and stakeholders about reliability. Every production service has SLOs.

## Inputs
- `artifacts/ideate/requirements/nfrs.md` (reliability and performance NFRs)
- `artifacts/design/platform/observability-design.md` (metrics, dashboards)
- `sdlc-config.json` (compliance_frameworks — HIPAA/SOC 2 have availability requirements)

## Output
**File:** `artifacts/operations/slos.md`
**Registers in manifest:** yes

## SLO Rules (enforced)
- Every SLO has a corresponding SLI (the metric that measures it).
- SLOs are more aggressive than SLAs by at least the error budget buffer.
- Error budget is calculated as: `(1 - SLO target) × rolling window`
- Burn rate alerts fire at 2×, 5×, and 10× the expected burn rate.
- SLOs are defined per service — no single product-level SLO that masks service failures.

## Artifact Template

```markdown
# Service Level Objectives
**Product:** {product_name}
**Phase:** Deploy (Operations)
**Artifact:** SLO Definitions
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## SLO Framework

**Rolling window:** 30 days
**Error budget formula:** (1 − SLO_target) × 30 days × 24 hours × 60 minutes

---

## {Service Name} SLOs

### SLO-FILE-01: API Availability
| Attribute | Value |
|-----------|-------|
| **SLI** | `rate(http_requests_total{service="file-domain",status!~"5.."}[5m]) / rate(http_requests_total{service="file-domain"}[5m])` |
| **Target** | 99.9% (3 nines) |
| **Error budget** | 43.8 minutes per 30 days |
| **SLA (external)** | 99.5% (buffer: 0.4%) |

**Burn rate alerts:**
| Alert | Condition | Severity | Response |
|-------|-----------|---------|---------|
| `SLOBurnRateCritical` | Burn rate > 14.4× (1hr window) | Page on-call immediately | < 5 min |
| `SLOBurnRateHigh` | Burn rate > 6× (6hr window) | Slack #incidents | < 30 min |
| `SLOBurnRateWarning` | Burn rate > 3× (3 day window) | Ticket in backlog | Next sprint |

---

### SLO-FILE-02: API Latency (p99)
| Attribute | Value |
|-----------|-------|
| **SLI** | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{service="file-domain"}[5m]))` |
| **Target** | 95% of requests complete in < 500ms |
| **Error budget** | 5% of requests per rolling window may exceed 500ms |

---

### SLO-FILE-03: Scan Completion Latency
| Attribute | Value |
|-----------|-------|
| **SLI** | % of scans completing within 24 hours of initiation |
| **Target** | 99% of scans complete within 24 hours |
| **Measurement** | `scan_jobs_completed_total{tenant_id="..."}` / `scan_jobs_initiated_total{tenant_id="..."}` over 24h window |

---

## Compliance SLO Requirements

| Framework | Requirement | SLO translation |
|-----------|------------|----------------|
| SOC 2 Type II | High availability (system availability commitment) | 99.9% availability SLO |
| HIPAA (if applicable) | No single point of failure for PHI access | Multi-AZ deployment + 99.9% SLO |

---

## Error Budget Policy

**When error budget is consumed at > 50%:**
- Feature work stops; reliability work takes priority
- Weekly error budget review in engineering standup

**When error budget is consumed at > 80%:**
- All feature work freezes; only reliability fixes merge
- Daily error budget review with engineering lead

**When error budget is exhausted (100%):**
- Freeze until budget is restored (unless safety/compliance fix)
- Post-mortem required within 48 hours

---

## SLO Dashboard

Grafana dashboard: `{product-codename}-slo-overview` (provisioned by `artifacts/design/platform/observability-design.md`)

Shows per service: current availability, error budget remaining %, burn rate trend.
```

## Quality Checks
- [ ] Every SLO has a corresponding SLI with a Prometheus query
- [ ] Error budget is calculated (not just stated)
- [ ] Burn rate alerts at 2×, 5×, and 10× are defined
- [ ] SLO is more aggressive than SLA by a stated buffer
- [ ] Error budget policy defines what happens at 50%, 80%, and 100% consumption
- [ ] Compliance framework availability requirements are mapped to SLOs
