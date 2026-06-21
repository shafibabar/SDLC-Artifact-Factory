# Skill: data/analytics-requirements

## Purpose
Produce the Analytics Requirements document — what business questions the product must answer through data, which metrics matter to each persona, and what the data infrastructure must support for analytics queries. This drives dashboard design and pipeline architecture.

## Inputs
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/ideate/jtbd.md`
- `artifacts/strategy/okrs.md`
- `artifacts/strategy/north-star.md`
- `artifacts/design/domain/read-models/`

## Output
**File:** `artifacts/data/analytics-requirements.md`
**Registers in manifest:** yes

## Analytics Rules (enforced)
- Every analytics requirement is phrased as a business question, not a technical query.
- Each question maps to the persona who needs it, the OKR it supports, and the data sources required.
- Real-time vs. near-real-time vs. batch requirements are explicit — they drive architecture choices.
- Privacy requirements for analytics data are stated (aggregation level, anonymisation needed).

## Artifact Template

```markdown
# Analytics Requirements

**Product:** {product_name}
**Phase:** Data
**Artifact:** Analytics Requirements
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Business Questions by Persona

### Persona: Compliance Officer

| # | Business question | Freshness required | Linked OKR | Data source |
|---|------------------|--------------------|-----------|------------|
| Q-CO-01 | What is our current compliance posture score per framework? | Near-real-time (< 5 min) | OKR-2 KR-1 | Compliance Domain (findings read model) |
| Q-CO-02 | How many open findings by severity, and how many are overdue? | Near-real-time (< 5 min) | OKR-2 KR-2 | Compliance Domain |
| Q-CO-03 | Which storage locations contain the most compliance violations? | Daily refresh | OKR-2 KR-1 | File Domain + Compliance Domain |
| Q-CO-04 | What entity types are most commonly found across our estate? | Daily refresh | OKR-1 | Entity Domain |
| Q-CO-05 | How has our posture score changed over the last 90 days? | Daily refresh | OKR-2 KR-1 | Compliance Domain (time-series) |
| Q-CO-06 | Which findings have been open longest without resolution? | Near-real-time | OKR-2 | Compliance Domain |

### Persona: Administrator

| # | Business question | Freshness required | Linked OKR | Data source |
|---|------------------|--------------------|-----------|------------|
| Q-AD-01 | Which storage locations have not been scanned in > 7 days? | Daily | OKR-1 KR-2 | File Domain |
| Q-AD-02 | What is the scan coverage (% of registered locations scanned)? | Daily | OKR-1 | File Domain |
| Q-AD-03 | Are any Worker Nodes disconnected or producing errors? | Real-time (< 1 min) | OKR-3 | Observability (Prometheus) |
| Q-AD-04 | How many files are being processed per hour? | Near-real-time | OKR-1 | File Domain |

### Persona: Auditor (External)

| # | Business question | Freshness required | Notes |
|---|------------------|--------------------|-------|
| Q-AU-01 | Which users accessed what data, and when? | Point-in-time (audit) | Audit Domain — immutable |
| Q-AU-02 | What findings were open during the audit period? | Point-in-time | Compliance Domain (time-slice) |
| Q-AU-03 | What exceptions were approved, by whom, and with what justification? | Point-in-time | Compliance Domain |

---

## North Star Metric Definition

**Metric:** {North Star Metric name from artifacts/strategy/north-star.md}
**Calculation:** {formula}
**Data sources:** {list}
**Refresh:** {frequency}
**Privacy level:** Aggregated — no individual PII in the metric

---

## Freshness Requirements Summary

| Freshness tier | Definition | Mechanism |
|---------------|-----------|-----------|
| Real-time (< 1 min) | Operational alerts and Worker Node status | Prometheus scrape (15s interval) |
| Near-real-time (< 5 min) | Compliance posture, active findings | Elasticsearch near-real-time indexing (1s refresh) |
| Daily | Trend metrics, coverage reports | Nightly batch aggregation job |
| Point-in-time | Audit evidence exports | Query at request time against immutable Audit DB |

---

## Analytics Privacy Requirements

| Analytics use case | Aggregation level | PII in output? | Anonymisation needed? |
|-------------------|-----------------|---------------|----------------------|
| Compliance posture score | Tenant-level summary | No | No |
| Finding count by severity | Counts only | No | No |
| Entity type distribution | Type counts (not values) | No | No |
| Audit trail export | Individual audit entries | Yes (user identities) | No — authorised auditors only |
| Cross-tenant benchmarking | Not permitted | N/A | N/A — prohibited |

---

## Data Aggregation Jobs

| Job | Input | Output | Schedule | Owner |
|-----|-------|--------|---------|-------|
| Daily posture snapshot | Compliance Domain findings | `compliance_posture_daily` table | 02:00 UTC | Compliance Domain |
| Scan coverage report | File Domain scan history | `scan_coverage_daily` table | 03:00 UTC | File Domain |
| Entity type summary | Entity Domain golden records | `entity_type_summary_daily` table | 01:00 UTC | Entity Domain |

---

## Analytics Data Retention

Analytics aggregates and dashboards are subject to the same retention policies as their source data. Exception: anonymised aggregate metrics (posture scores, entity counts) may be retained for 3 years for trend analysis without referencing individual data subjects.
```

## Quality Checks
- [ ] Every persona has at least 3 analytics questions defined
- [ ] Every question maps to a data source and OKR
- [ ] Freshness tier is specified per question (not all "real-time" by default)
- [ ] Privacy requirements explicitly prohibit cross-tenant analytics
- [ ] Aggregation jobs are defined for computed/derived metrics
- [ ] North Star Metric is defined and calculable from available data
