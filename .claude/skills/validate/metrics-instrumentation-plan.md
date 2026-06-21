# Skill: validate/metrics-instrumentation-plan

## Purpose
Produce the Metrics Instrumentation Plan — the specification of what product and business metrics are emitted by the application, how they are collected, what dashboards show them, and how they feed into the North Star Metric. Instrumentation is built from day one — not bolted on after launch.

## Inputs
- `artifacts/strategy/north-star.md` (North Star Metric)
- `artifacts/strategy/okrs.md` (Key Results — each KR needs a metric)
- `artifacts/data/analytics-requirements.md` (analytical questions to answer)
- `artifacts/design/platform/observability-design.md` (technical observability — separate from product metrics)

## Output
**File:** `artifacts/validate/metrics-plan.md`
**Registers in manifest:** yes

## Instrumentation Rules (enforced)
- Every OKR Key Result has at least one corresponding instrumented metric.
- North Star Metric is computed from atomic events — not derived from other metrics.
- Every metric has an owner (team responsible for maintaining instrumentation).
- PII is never in metric labels, event properties, or Prometheus labels.
- Product events are distinct from technical observability events (different topic, different schema).

## Artifact Template

```markdown
# Metrics Instrumentation Plan
**Product:** {product_name}
**Phase:** Validate
**Artifact:** Metrics Instrumentation Plan
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## North Star Metric

**NSM:** {From north-star.md — e.g. "Weekly Active Tenants With At Least One Completed Scan"}
**Calculation:**
```sql
-- Computed from product events in analytics DB
SELECT COUNT(DISTINCT tenant_id)
FROM scan_completed_events
WHERE completed_at >= NOW() - INTERVAL '7 days';
```
**Target:** {N} by end of Q{N} {YYYY}
**Instrumented via:** `ScanCompleted` domain event → product analytics pipeline

---

## OKR Key Result Metrics

| KR | Metric | Instrumentation source | Owner |
|----|--------|----------------------|-------|
| KR-1: {N} tenants actively scanning within 30 days of onboarding | `time_to_first_scan_days` | `StorageLocationRegistered` + `ScanCompleted` events; calculate delta | PM |
| KR-2: Compliance posture ≥ 80% across tenant base | `avg_posture_score_30d` | `PostureSnapshotCreated` event → analytics aggregate | PM |
| KR-3: < 5% tenant churn rate | `tenant_churn_rate` | `TenantDeprovisioned` events / total active tenants | PM |

---

## Product Event Schema

Product events are emitted to the analytics pipeline (NOT to domain event bus). They are consumer-facing business events, not domain events.

```json
{
  "event_id": "uuid",
  "event_type": "scan_completed",
  "product": "{product-codename}",
  "tenant_id": "uuid",              // tenant scope — no PII
  "occurred_at": "ISO 8601",
  "properties": {
    "storage_location_id": "uuid",
    "platform": "GOOGLE_DRIVE",
    "files_processed": 1204,
    "entities_extracted": 342,
    "findings_generated": 14,
    "duration_seconds": 327
    // NEVER: user_email, user_name, file_names, entity_values
  }
}
```

---

## Instrumented Events

| Event | Trigger | Key properties (no PII) | Drives |
|-------|---------|------------------------|--------|
| `tenant_onboarded` | Tenant provisioning complete | `tenant_id`, `plan` | KR-3, retention |
| `storage_location_registered` | POST /storage-locations 201 | `platform`, `tenant_id` | Onboarding funnel |
| `scan_initiated` | Scan starts | `storage_location_id`, `tenant_id` | Funnel step |
| `scan_completed` | Scan job finishes | `files_processed`, `entities_extracted`, `findings_generated`, `duration_seconds` | NSM, KR-1 |
| `finding_resolved` | Finding marked resolved | `severity`, `days_to_resolve`, `tenant_id` | KR-2 |
| `compliance_report_exported` | Report download | `format`, `tenant_id` | Engagement |
| `tenant_deprovisioned` | Tenant offboarded | `tenant_id`, `reason` | KR-3 churn |

---

## Implementation

Product events are emitted via a dedicated `AnalyticsPublisher` adapter (NOT the domain event bus):

```go
// internal/infrastructure/analytics/publisher.go
type ProductEvent struct {
    EventID    string         `json:"event_id"`
    EventType  string         `json:"event_type"`
    TenantID   string         `json:"tenant_id"`
    OccurredAt time.Time      `json:"occurred_at"`
    Properties map[string]any `json:"properties"`
}

type AnalyticsPublisher interface {
    Publish(ctx context.Context, event ProductEvent) error
}
```

Publishing to: Redpanda topic `product-analytics.events` (separate from domain topics).

---

## Privacy Review Checklist

Before instrumentation is deployed, confirm:
- [ ] No user email, name, or personal identifier in event properties
- [ ] No entity values in event properties
- [ ] No file names or paths in event properties
- [ ] Tenant ID is the most granular identifier (not user ID, not email)
- [ ] Event schema reviewed by PM for PII risk

---

## Dashboard

Product metrics are visualised in Grafana dashboard `{product-codename}-product-metrics`:
- NSM trend (weekly, 12-week rolling)
- Onboarding funnel (registered → first scan → first finding → posture viewed)
- Scan volume by platform (Google Drive, S3, SharePoint)
- Retention cohort chart (% of tenants active after 7/30/90 days)
```

## Quality Checks
- [ ] NSM is defined with a specific Prometheus or SQL query
- [ ] Every OKR Key Result has a metric with measurement source
- [ ] Product event schema shows exactly what properties are collected (and what is excluded)
- [ ] Events are on a separate topic from domain events
- [ ] PII review checklist is present
- [ ] Instrumentation code shows actual Go interface
- [ ] Dashboard is named and its contents are described
