# SLO Output Template Reference

This document is the complete output-format reference for `slo-definition`. It is
self-contained: all field guidance, both record types, and a worked example are here.
Load it when writing an actual SLO document — the SKILL.md body covers the method;
this file covers the artifact shape.

---

## Record Types

Every product that goes through Deploy phase produces **two** SLO records:

| Record | File name convention | Owner | Scope |
|---|---|---|---|
| **Service SLO record** | `slo-<product-name>.md` | platform-engineer | All services in the product; includes reliability + delivery-performance axes |
| **Platform SLO record** | `slo-platform.md` | platform-engineer | CI pipeline, CD pipeline, environment provisioning |

Both records are reviewed on the same monthly cadence. Both records have the same frontmatter schema.

---

## Service SLO Record Template

```markdown
---
name: slo-definition-<product>
product: <product-name>
version: 1.0.0
phase: deploy
created: <ISO-8601 date>
owner: platform-engineer
---

# Service Level Objectives — <Product>

## Sources

- NFR specification: `nfr-<product>.md` (version, date)
- User journeys: list the journeys each SLO section protects
- Baseline measurement: `go-load-test` run date, environment, peak RPS

---

## Reliability SLOs

### SLI Definitions

| # | Service / journey | SLI type | Good event definition | Valid event definition |
|---|---|---|---|---|
| R-01 | <service> — <journey name> | Availability | HTTP response code not 5xx | All requests to `<METHOD /path>` |
| R-02 | <service> — <journey name> | Latency | Request completes < <N>ms | All requests to `<METHOD /path>` |
| R-03 | <pipeline name> end-to-end | Freshness | Item processed within <N> min of ingestion | All items ingested |
| R-04 | <consumer name> | Correctness | Processed with `outcome="ok"` | All messages consumed (DLQ entries are bad events) |

### SLO Targets

| SLI # | Target | Window | Measurement (Prometheus series) |
|---|---|---|---|
| R-01 | 99.5% | Rolling 28 days | `sum(rate(http_requests_total{status!~"5.."}[28d])) / sum(rate(http_requests_total[28d]))` |
| R-02 | 99.5% | Rolling 28 days | `histogram_quantile(0.995, rate(http_request_duration_seconds_bucket[28d]))` — good = bucket ≤ <N>ms |
| R-03 | 99.0% | Rolling 28 days | Ratio of `pipeline_item_latency_seconds` observations ≤ <N>s / all observations |
| R-04 | 99.9% | Rolling 28 days | `1 - (rate(consumer_dlq_total[28d]) / rate(consumer_processed_total[28d]))` |

### Error Budgets

| SLI # | Budget fraction | Time budget (28-day window) | Request/item budget (at peak load) | Spend policy when exhausted |
|---|---|---|---|---|
| R-01 | 0.5% | ≈ 201.6 minutes | <N> failed requests at <peak RPS> | Feature deploys pause; reliability work is P0 |
| R-02 | 0.5% | ≈ 201.6 minutes | <N> slow requests at <peak RPS> | Feature deploys pause; reliability work is P0 |
| R-03 | 1.0% | ≈ 403.2 minutes | <N> late items at <peak items/day> | Investigate pipeline throughput; escalate to platform-engineer |
| R-04 | 0.1% | ≈ 40.3 minutes | <N> DLQ entries at <peak messages/day> | DLQ drain is immediate P0; no new feature work until clear |

### Burn-Rate Policy

| SLI # | Fast-burn (page immediately) | Slow-burn (ticket) | alerting-rules reference |
|---|---|---|---|
| R-01 | Burn rate > 14.4 over 1h AND over 5m | Burn rate > 1 over 6h AND over 30m | `alerting-rules-<product>.md` section R-01 |
| R-02 | Burn rate > 14.4 over 1h AND over 5m | Burn rate > 1 over 6h AND over 30m | `alerting-rules-<product>.md` section R-02 |
| R-03 | Burn rate > 6 over 1h AND over 5m | Burn rate > 1 over 6h AND over 30m | `alerting-rules-<product>.md` section R-03 |
| R-04 | Burn rate > 14.4 over 1h AND over 5m | Burn rate > 1 over 6h AND over 30m | `alerting-rules-<product>.md` section R-04 |

### SLA Mapping

| External SLA commitment | Backing SLO | Headroom (SLO − SLA) |
|---|---|---|
| <Customer-visible availability commitment> | R-01 at 99.5% | 0.5 percentage points |
| <Customer-visible latency commitment> | R-02 at 99.5% | 0.5 percentage points |

---

## Delivery Performance Targets

Definitions and cluster thresholds from `dora-metrics`. These are targets for the team
maintaining this product, not SLIs for end users.

| Metric | Target (High performer threshold) | Measurement source | Current 28-day value |
|---|---|---|---|
| Deployment Frequency | On demand (≥ 1 deploy/day to main) | GitHub Actions workflow runs on main branch (`ci-pipeline`) | <fill at review> |
| Lead Time for Changes | < 1 hour (commit to production) | Commit timestamp → deploy-complete timestamp (`cd-pipeline`) | <fill at review> |
| Time to Restore Service (MTTR) | < 1 hour (alert-open to alert-closed) | Alertmanager alert lifecycle (`alerting-rules-<product>.md`) | <fill at review> |
| Change Failure Rate | < 15% (rollbacks / total deploys) | `git revert` events / total promotion events (`cd-pipeline`) | <fill at review> |

**Current performer cluster:** [ ] High  [ ] Medium  [ ] Low  (see `dora-metrics` for threshold definitions)

A regression in any metric — defined as dropping one performer cluster, or exceeding the target
for two consecutive review periods — is treated with the same weight as an SLO burn alert:
root cause analysis, corrective action, owner, and date.

---

## Review Log

| Date | Reviewer | Reliability SLOs | Delivery performance | Actions |
|---|---|---|---|---|
| <date> | platform-engineer | <summary> | <summary> | <actions with owners> |
```

---

## Platform SLO Record Template

```markdown
---
name: slo-platform
product: platform
version: 1.0.0
phase: deploy
created: <ISO-8601 date>
owner: platform-engineer
---

# Platform Service Level Objectives

The platform is a product whose customers are the engineering teams building on it.
Platform SLOs measure how reliably the platform enables those teams to work.
These are reviewed monthly alongside service SLOs.

## Platform SLIs and Targets

| # | Platform capability | SLI type | Good event definition | Target | Window |
|---|---|---|---|---|---|
| P-01 | CI pipeline (GitHub Actions) | Duration | Job completes in < 10 minutes | P95 duration < 10 min | Rolling 28 days |
| P-02 | Deployment pipeline (CD) | Availability | Pipeline invocation completes without infrastructure error | > 99.5% success rate | Rolling 28 days |
| P-03 | Environment provisioning | Duration | Environment ready (all pods Running) within 5 minutes of PR merge | P95 provisioning time < 5 min | Rolling 28 days |

### Rationale for Targets

- **CI P95 < 10 min**: A CI pipeline exceeding 10 minutes discourages frequent commits
  (Accelerate cluster data shows high performers run CI in under 10 minutes). The P95 rather than
  mean catches the tail that breaks flow without penalising occasional outliers.
- **CD availability > 99.5%**: An unavailable CD pipeline stops all deploys; the platform's
  availability budget must be tighter than any individual service's, since a platform outage
  simultaneously exhausts every service's deployment capacity.
- **Environment provisioning < 5 min**: Platform Engineering (Fournier, Nowland) recommends
  new-environment time as a first-class developer experience (DX) metric. Beyond 5 minutes,
  developers context-switch rather than wait; productivity and Deployment Frequency both drop.

## Error Budgets

| SLI # | Budget | Spend policy when exhausted |
|---|---|---|
| P-01 | 5% of all CI runs may exceed 10 min (P95 budget) | Investigate slow steps; optimize or parallelize before accepting new pipeline stages |
| P-02 | 0.5% pipeline failure rate allowed | Platform incident; no service deployments until resolved |
| P-03 | 5% of environment provisions may exceed 5 min (P95 budget) | Investigate provisioning bottleneck; disable non-essential provisioning steps |

## Data Sources

| SLI # | Where the data comes from |
|---|---|
| P-01 | GitHub Actions API: `workflow_run` events, `updated_at - created_at` per run |
| P-02 | GitHub Actions API: `workflow_run` events with `conclusion = "failure"` / all runs |
| P-03 | Kubernetes events: `Pod` Ready condition timestamp − Helm release timestamp |

## Review Log

| Date | Reviewer | CI P95 | CD availability | Env provisioning | Actions |
|---|---|---|---|---|---|
| <date> | platform-engineer | <value> | <value> | <value> | <actions> |
```

---

## Worked Example — Data Estate Platform

This shows both record types filled in for the data-estate product.

### Service SLO Record (excerpt)

```markdown
---
name: slo-definition-data-estate
product: data-estate
version: 1.0.0
phase: deploy
created: 2026-07-20
owner: platform-engineer
---

# Service Level Objectives — Data Estate

## Sources
- NFR specification: `nfr-data-estate.md` v1.0.0
- User journeys: compliance-officer dashboard view, audit export, real-time asset classification
- Baseline: go-load-test run 2026-07-19, kind-local cluster, 500 RPS peak

## Reliability SLOs

| # | Service / journey | SLI type | Target | Window |
|---|---|---|---|---|
| R-01 | compliance-engine `PATCH /v1/data-assets/{id}/classification` | Availability | 99.5% | Rolling 28 days |
| R-02 | compliance-engine command API | Latency (< 800ms) | 99.5% | Rolling 28 days |
| R-03 | Classification pipeline end-to-end | Freshness (< 15 min) | 99.0% | Rolling 28 days |
| R-04 | entity-extractor consumer | Correctness (no DLQ) | 99.9% | Rolling 28 days |

### Error Budgets

| SLI # | Budget fraction | Time budget | Request budget | Spend policy |
|---|---|---|---|---|
| R-01 | 0.5% | ~202 min/28 days | 100,000 failed at 20M req/28d | Feature deploys pause |
| R-02 | 0.5% | ~202 min/28 days | 100,000 slow at 20M req/28d | Feature deploys pause |
| R-03 | 1.0% | ~403 min/28 days | 14,400 late assets at 1M assets/28d | Pipeline capacity review |
| R-04 | 0.1% | ~40 min/28 days | 1,000 DLQ entries at 1M messages/28d | Immediate P0 DLQ drain |

### SLA Mapping

| External commitment | Backing SLO | Headroom |
|---|---|---|
| 99.0% API availability (contract clause 4.2) | R-01 at 99.5% | 0.5 pp |
| 98.5% classifications within 30 min | R-03 at 99.0% (15 min) | 0.5 pp + tighter window |

## Delivery Performance Targets

| Metric | Target | Current (2026-07-19) | Cluster |
|---|---|---|---|
| Deployment Frequency | ≥ 1/day | 3/week | Medium |
| Lead Time for Changes | < 1 hour | ~4 hours | Medium |
| MTTR | < 1 hour | ~2 hours | Medium |
| Change Failure Rate | < 15% | 8% | High |

**Current cluster: Medium — trending toward High. Lead Time is the primary bottleneck.**
Action: reduce PR review queue time; enable auto-merge for green PRs with required checks.
```

### Platform SLO Record (excerpt)

```markdown
---
name: slo-platform
product: platform
version: 1.0.0
phase: deploy
created: 2026-07-20
owner: platform-engineer
---

# Platform Service Level Objectives

## Platform SLIs and Current Values

| # | Capability | Target | Current (2026-07-19) | Status |
|---|---|---|---|---|
| P-01 | CI pipeline P95 duration | < 10 min | 7 min 22 sec | OK |
| P-02 | CD pipeline availability | > 99.5% | 99.8% | OK |
| P-03 | Environment provisioning P95 | < 5 min | 3 min 47 sec | OK |

## Actions from Last Review

- P-01 trended toward 9 min in late June due to added static-analysis step. Parallelized
  lint and unit-test stages; P95 returned to 7 min. No budget breach.
- P-02 had one CD pipeline failure (exit code 1 from helm upgrade timeout on 2026-07-11).
  Root cause: PVC resize in staging cluster. Fixed by pre-checking PVC capacity in the
  pipeline pre-flight check. Corrective action closed.
```

---

## Notes on Setting Platform SLO Targets

Platform SLO targets are not arbitrary. Start from the observed baseline and tighten only
when the baseline is consistently better than the target for one full quarter:

1. Measure actual P95 CI duration over 4 weeks before setting the target.
2. If measured P95 is 14 minutes, set the initial target at 15 minutes, not 10 minutes —
   an SLO above baseline is a standing false alarm.
3. After investing in CI optimization (parallelization, caching, step elimination), re-measure
   and tighten to 10 minutes once the new baseline is consistently below 8 minutes.

The 10-minute CI, 99.5% CD availability, and 5-minute environment provisioning defaults in
SKILL.md represent High-performer targets from Accelerate cluster data and the Platform
Engineering discipline (Fournier, Nowland). Use them as aspirational targets when the
baseline is not yet known; replace them with baseline-derived targets as soon as data exists.
