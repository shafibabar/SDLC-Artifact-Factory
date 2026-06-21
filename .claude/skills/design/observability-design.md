# Skill: design/observability-design

## Purpose
Produce the Observability Design — the complete specification for metrics, logs, traces, and alerts. Answers: what signals tell us the system is healthy, and what do we do when they don't?

## Inputs
- `artifacts/design/architecture/c4-container.md`
- `artifacts/ideate/requirements/nfrs.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/platform/observability-design.md`
**Registers in manifest:** yes

## Observability Rules (enforced)
- The THREE PILLARS are all required: Metrics (Prometheus), Logs (Elasticsearch via Fluent Bit), Traces (Tempo via OpenTelemetry).
- Every service emits OpenTelemetry spans for all inbound requests and all outbound calls.
- Every domain event processed has a trace span.
- SLO-based alerting: alerts fire on error budget burn rate, not on raw error rate.
- No PII in logs, metrics labels, or trace attributes — C4 data is referenced by ID only.
- On-call runbooks are linked from every alert.

## Artifact Template

```markdown
# Observability Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Observability Design
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Observability Stack

| Signal | Collection | Storage | Visualisation |
|--------|-----------|---------|--------------|
| Metrics | Prometheus (pull via scrape) | Prometheus TSDB (15 days hot) | Grafana |
| Logs | Fluent Bit (DaemonSet) | Elasticsearch | Grafana (Elasticsearch datasource) |
| Traces | OpenTelemetry SDK → OTel Collector | Grafana Tempo | Grafana |
| Events (domain) | Redpanda consumer lag metric | Prometheus | Grafana |
| Alerts | Prometheus AlertManager | — | PagerDuty / Slack (via Alert Domain) |

---

## Instrumentation Standards

### All Services Must Emit

**Metrics (Prometheus):**
```go
// RED method — for every endpoint and every event handler
http_requests_total{service, endpoint, method, status_code, tenant_id}
http_request_duration_seconds{service, endpoint, method, tenant_id}  // histogram
http_requests_in_flight{service, endpoint}

// Domain-specific
domain_events_processed_total{service, event_type, result}  // result: success|failure|dlq
domain_events_processing_duration_seconds{service, event_type}  // histogram
outbox_relay_lag_seconds{service}
```

**WARNING: `tenant_id` in metric labels must use tenant slug (not UUID) — Prometheus cardinality risk if UUIDs used.**

**Traces (OpenTelemetry):**
Every span must include:
```go
span.SetAttributes(
    attribute.String("service.name", "file-domain-service"),
    attribute.String("tenant.id", tenantID),           // non-PII
    attribute.String("event.type", eventType),          // domain events
    attribute.String("trace.correlation_id", corrID),  // causal chain
)
// NEVER include entity values, file content, or credentials in span attributes
```

**Logs (structured JSON via `slog`):**
```json
{
  "time": "ISO8601",
  "level": "INFO|WARN|ERROR",
  "service": "file-domain-service",
  "tenant_id": "uuid",
  "trace_id": "uuid",
  "span_id": "uuid",
  "msg": "human readable message",
  "event_type": "FileProcessed",
  "duration_ms": 142
}
```

**NEVER log:** entity values, file content, credential values, JWT contents.

---

## Service Level Objectives (SLOs)

| Service | SLI | SLO | Error budget (30d) |
|---------|-----|-----|-------------------|
| API Gateway | Request success rate | 99.5% | 3.6 hours |
| File Domain Service | Scan initiation success rate | 99% | 7.2 hours |
| Entity Domain Service | Entity extraction success rate | 98% | 14.4 hours |
| Compliance Domain Service | Rule evaluation success rate | 99% | 7.2 hours |
| API Gateway | p99 latency < 500ms | 99% of requests | — |
| End-to-end scan pipeline | File discovered → Finding created latency < 5 min | 95% | — |

---

## Alert Definitions

### Critical (page on-call immediately)

| Alert | Condition | Runbook |
|-------|-----------|--------|
| `APIGatewayDown` | No successful health check responses for 1 minute | runbooks/api-gateway-down.md |
| `DLQMessagesPresent` | DLQ depth > 0 for > 5 minutes | runbooks/dlq-investigation.md |
| `SLOErrorBudgetCritical` | Error budget burn rate > 14.4x for 1h window | runbooks/slo-burn.md |
| `AuditTrailConsumerLag` | Audit consumer lag > 10,000 messages | runbooks/audit-lag.md |
| `CrossTenantAccessAttempt` | ABAC DENY with tenant_id mismatch | runbooks/security-incident.md |

### Warning (business hours response)

| Alert | Condition | Runbook |
|-------|-----------|--------|
| `SLOErrorBudgetWarning` | Error budget burn rate > 6x for 6h window | runbooks/slo-burn.md |
| `HighConsumerLag` | Any consumer group lag > 1,000 messages for 10 minutes | runbooks/consumer-lag.md |
| `CertificateExpiringSoon` | Any mTLS cert expiring in < 7 days | runbooks/cert-rotation.md |
| `OutboxRelayStalled` | Outbox relay has not processed any events for 5 minutes | runbooks/outbox-stall.md |
| `WorkerNodeDisconnected` | Worker Node has not checked in for 30 minutes | runbooks/worker-node-reconnect.md |

---

## Distributed Tracing

Every cross-service call propagates trace context via W3C TraceContext headers (`traceparent`, `tracestate`).

**Key trace scenarios to instrument:**
1. User initiates scan → Worker Node executes → results received → events published → entity extracted → compliance evaluated → finding created
2. User acknowledges finding → audit entry written
3. Admin registers storage location → credentials validated → scan initiated

Traces are retained for 7 days in Tempo (cost vs. utility trade-off).

---

## Dashboards

| Dashboard | Audience | Key panels |
|-----------|---------|-----------|
| Platform Overview | On-call engineer | SLO burn rate, DLQ depth, consumer lag, error rate by service |
| Scan Pipeline | Engineering | Scan throughput, entity extraction rate, E2E latency histogram |
| Compliance Pipeline | Product | Finding creation rate, rule evaluation rate, posture score trend |
| Security | Security team | Auth failures, ABAC deny rate, cross-tenant attempts |
| Tenant Health | Customer Success | Per-tenant: last scan, finding count, SLO status |

All dashboards are stored as code (JSON) in the `{product}-platform` repo under `grafana/dashboards/`.
```

## Quality Checks
- [ ] All three observability pillars (metrics, logs, traces) are specified
- [ ] RED metrics (rate, errors, duration) are defined for all services
- [ ] SLOs are defined with error budgets
- [ ] PII-free logging is explicitly stated
- [ ] Alerts include runbook references
- [ ] Critical vs warning alert tiers are distinguished
- [ ] Dashboard-as-code is mentioned
