# Skill: data/data-pipeline-design

## Purpose
Produce a Data Pipeline Design for one data flow — the specification of how data moves from source to destination, what transformations occur, what errors are handled, and how the pipeline is monitored. Covers both real-time event-driven pipelines and batch aggregation jobs.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/architecture/integration-design.md`
- `artifacts/data/analytics-requirements.md`
- `artifacts/design/data/data-lineage-design.md`
- **Argument required:** pipeline name (e.g. `file-to-entity-extraction`, `nightly-posture-aggregation`)

## Output
**File:** `artifacts/data/pipelines/{pipeline-name}.md`
**Registers in manifest:** yes

## Pipeline Rules (enforced)
- Every pipeline has explicit error handling and a dead letter path.
- Batch pipelines are idempotent — re-running produces the same result.
- Real-time pipelines use the Transactional Outbox or event consumption patterns already defined.
- SLA is defined for every pipeline (how stale can the output be before it's a problem?).

## Artifact Template

```markdown
# Data Pipeline Design: {pipeline-name}

**Product:** {product_name}
**Phase:** Data
**Artifact:** Data Pipeline Design
**Pipeline name:** {pipeline-name}
**Pipeline type:** Real-time (event-driven) | Batch (scheduled)
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Pipeline: Nightly Compliance Posture Aggregation

**Type:** Batch (scheduled)
**Schedule:** 02:00 UTC daily
**Owner service:** Compliance Domain Service
**SLA:** Output available by 03:00 UTC

---

## Data Flow

```
Source: compliance_domain.findings (PostgreSQL)
    │
    ▼
[Extract] SELECT findings WHERE resolved_at IS NULL OR resolved_at >= window_start
    │
    ▼
[Transform]
  - Group by (tenant_id, framework, rule_id)
  - Calculate severity counts per group
  - Calculate posture_score = 100 - (weighted_violation_score / total_rules * 100)
  - Compare with previous day's snapshot
    │
    ▼
[Load] UPSERT INTO compliance_posture_daily (tenant_id, framework, date, posture_score, ...)
    │
    ▼
[Publish] Event: PostureSnapshotCreated → Redpanda (triggers dashboard cache invalidation)
```

---

## Extract Specification

```sql
-- Parameterised: $1 = snapshot_date (yesterday), $2 = tenant_id
SELECT
    tenant_id,
    framework,
    rule_id,
    severity,
    COUNT(*) AS violation_count,
    MIN(created_at) AS oldest_open_finding,
    COUNT(CASE WHEN created_at < NOW() - INTERVAL '30 days' THEN 1 END) AS overdue_count
FROM findings
WHERE
    tenant_id = $2
    AND (resolved_at IS NULL OR resolved_at >= $1::DATE)
    AND deleted_at IS NULL
GROUP BY tenant_id, framework, rule_id, severity;
```

---

## Transform Specification

**Posture Score Formula:**
```
rule_weights = { CRITICAL: 4, HIGH: 3, MEDIUM: 2, LOW: 1 }
weighted_violations = SUM(violation_count * rule_weights[severity]) per framework
max_possible_score = total_active_rules_for_framework * max_weight
posture_score = MAX(0, 100 - (weighted_violations / max_possible_score * 100))
```

Rounding: 1 decimal place.

---

## Load Specification

```sql
INSERT INTO compliance_posture_daily (
    tenant_id, framework, snapshot_date, posture_score,
    total_open_findings, critical_count, high_count, medium_count, low_count,
    overdue_count, computed_at
) VALUES (...)
ON CONFLICT (tenant_id, framework, snapshot_date)
DO UPDATE SET
    posture_score = EXCLUDED.posture_score,
    total_open_findings = EXCLUDED.total_open_findings,
    -- ... update all metrics
    computed_at = NOW();
-- ON CONFLICT ensures idempotency — safe to re-run
```

---

## Error Handling

| Error scenario | Handling |
|---------------|---------|
| Source DB unavailable | Retry 3x with 5-minute backoff; alert on-call if all fail |
| Zero findings for tenant | Valid case — produce snapshot with posture_score = 100; not an error |
| Division by zero (no active rules) | Posture score = NULL; set flag `rules_not_configured = true` |
| Computation timeout (> 10 min) | Kill query; alert; skip that tenant; retry next run |
| Partial failure (some tenants fail) | Log failed tenants; continue with others; report in pipeline run log |

---

## Pipeline Run Log

Every pipeline run writes to `pipeline_runs`:
```sql
INSERT INTO pipeline_runs (
    pipeline_name, run_at, status, tenants_processed, tenants_failed,
    duration_ms, error_details
) VALUES (...);
```

Run log is retained for 90 days and visible in the Operations Dashboard.

---

## Monitoring

| Alert | Condition | Severity |
|-------|-----------|---------|
| `PipelineRunFailed` | status = 'FAILED' in pipeline_runs | WARNING |
| `PipelineRunLate` | run not completed by 03:00 UTC | WARNING |
| `PipelineRunNotStarted` | no run record by 02:15 UTC | CRITICAL |
| `TenantProcessingFailure` | tenants_failed > 0 | WARNING |

---

## Pipeline: File-to-Entity Extraction (Real-Time)

**Type:** Real-time (event-driven via Redpanda)
**Trigger:** `FileProcessed` event on `file-domain.file-processed` topic
**SLA:** Entity extraction begins within 30 seconds of file processing completion
**Owner service:** Entity Domain Service

```
[Redpanda: file-domain.file-processed]
    │
    ▼
[Entity Domain Consumer: cg-entity-file-events]
    │
    ▼
[ACL Translation: FileProcessed → SourceFileReadyForExtraction]
    │
    ▼
[Idempotency check: entity_processed_events table]
    │ (already processed → discard)
    │ (not processed → continue)
    ▼
[ExtractEntities command handler]
    │
    ▼
[NER Model inference: via WorkerNode in customer infra]
    │
    ▼
[Persist: extracted_entities table + outbox]
    │
    ▼
[Redpanda: entity-domain.entities-extracted]
```

**Error handling:** See integration-design.md (DLQ, retry backoff, circuit breaker).
```

## Quality Checks
- [ ] Every pipeline has a named SLA (acceptable output staleness)
- [ ] Batch pipelines use ON CONFLICT / idempotent UPSERTs
- [ ] All error scenarios have explicit handling (not just "handle errors")
- [ ] Pipeline run log is defined for observability
- [ ] Alerts are defined for: late, not started, failed
- [ ] Real-time pipelines reference the integration-design.md error handling
