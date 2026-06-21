# Skill: design/integration-design

## Purpose
Produce the Integration Design document — the specification for all integration patterns between bounded contexts and external systems. Covers the event routing topology, consumer group strategy, error handling, DLQ strategy, and synchronous integration patterns. This is the operational contract for the event-driven backbone.

## Inputs
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/events.md`
- `artifacts/design/domain/policies.md`
- `artifacts/design/contracts/event-schemas.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/architecture/integration-design.md`
**Registers in manifest:** yes

## Integration Rules (enforced)
- Every consumer group has a unique, immutable name. Consumer group names are documented here.
- At-least-once delivery is the default. All consumers must be idempotent.
- Dead Letter Queue (DLQ) is mandatory for all integration event consumers. No event is silently dropped.
- Circuit Breaker is required for all synchronous external calls (storage APIs, secrets manager, identity provider).
- No synchronous calls from one bounded context service to another's internal API — only events and read models.
- The Transactional Outbox pattern is required on all event producers.
- Cross-context event consumers implement an ACL translation layer before dispatching to application logic.

## Artifact Template

```markdown
# Integration Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Integration Design
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Integration Architecture Overview

```mermaid
graph LR
  subgraph "File Domain"
    FS[File Service] --> FO[(Outbox)]
    FO --> RP1[Redpanda\nfile-domain.events]
  end

  subgraph "Entity Domain"
    RP1 -- FileProcessed --> EC1[Event Consumer\ncg-entity-file-events]
    EC1 --> ACL1[ACL Translator]
    ACL1 --> ES[Entity Service]
    ES --> EO[(Outbox)]
    EO --> RP2[Redpanda\nentity-domain.events]
  end

  subgraph "Compliance Domain"
    RP2 -- EntitiesExtracted --> EC2[Event Consumer\ncg-compliance-entity-events]
    EC2 --> ACL2[ACL Translator]
    ACL2 --> CS[Compliance Service]
    CS --> CO[(Outbox)]
    CO --> RP3[Redpanda\ncompliance-domain.events]
  end

  subgraph "Audit Domain"
    RP1 -- all events --> EC3[Event Consumer\ncg-audit-file]
    RP2 -- all events --> EC4[Event Consumer\ncg-audit-entity]
    RP3 -- all events --> EC5[Event Consumer\ncg-audit-compliance]
    EC3 & EC4 & EC5 --> AUD[Audit Service\n(append-only)]
  end

  RP1 -- DLQ path --> DLQ1[(DLQ\nfile-domain.dlq)]
  RP2 -- DLQ path --> DLQ2[(DLQ\nentity-domain.dlq)]
  RP3 -- DLQ path --> DLQ3[(DLQ\ncompliance-domain.dlq)]
```

---

## Topic Registry

| Topic | Producer | Schema | Retention | Partitions |
|-------|---------|--------|-----------|-----------|
| `file-domain.events` | File Domain Service | See event-schemas.md | 7 days | 12 |
| `entity-domain.events` | Entity Domain Service | See event-schemas.md | 7 days | 12 |
| `compliance-domain.events` | Compliance Domain Service | See event-schemas.md | 7 days | 12 |
| `file-domain.dlq` | DLQ relay | Original event envelope | 30 days | 3 |
| `entity-domain.dlq` | DLQ relay | Original event envelope | 30 days | 3 |
| `compliance-domain.dlq` | DLQ relay | Original event envelope | 30 days | 3 |
| `audit.all-events` | Audit Domain fan-in | All event types | 365 days (immutable) | 6 |

**Partition strategy:** Keyed by `tenant_id` — ensures all events for one tenant land on the same partition (ordered per tenant).

---

## Consumer Group Registry

| Consumer Group ID | Consumer Service | Topic(s) consumed | Isolation |
|------------------|----------------|------------------|-----------|
| `cg-entity-file-events` | Entity Domain Service | `file-domain.events` | Dedicated group — no other consumer shares this group |
| `cg-compliance-entity-events` | Compliance Domain Service | `entity-domain.events` | Dedicated |
| `cg-graph-entity-events` | Graph Domain Service | `entity-domain.events` | Dedicated |
| `cg-alert-compliance-events` | Alert Domain Service | `compliance-domain.events` | Dedicated |
| `cg-audit-file` | Audit Domain Service | `file-domain.events` | Dedicated |
| `cg-audit-entity` | Audit Domain Service | `entity-domain.events` | Dedicated |
| `cg-audit-compliance` | Audit Domain Service | `compliance-domain.events` | Dedicated |

**Rule:** One consumer group per (consumer service × topic). Never share a consumer group between services.

---

## Anti-Corruption Layer (ACL) Specifications

### ACL-01: File Domain → Entity Domain

**Location:** Entity Domain Service — `internal/infrastructure/messaging/acl/file_domain_acl.go`

**Input type** (from File Domain): `FileProcessed` event envelope
**Output type** (Entity Domain model): `SourceFileReadyForExtraction`

**Translation mapping:**
| File Domain field | Entity Domain type | Notes |
|------------------|-------------------|-------|
| `payload.file_id` | `SourceReference.origin_file_id` | UUID preserved; concept renamed |
| `payload.storage_location_id` | `SourceReference.origin_location_id` | UUID preserved |
| `payload.file_checksum` | `SourceReference.content_fingerprint` | Renamed to domain language |
| `payload.file_metadata.mime_type` | `SourceReference.content_type` | Renamed |
| `payload.extracted_text_ref` | `SourceReference.text_ref` | Opaque ref; not interpreted |

**Rejected fields** (not translated): `processing_duration_ms` — internal File Domain metric, not meaningful in Entity Domain.

---

### ACL-02: Entity Domain → Compliance Domain

**Location:** Compliance Domain Service — `internal/infrastructure/messaging/acl/entity_domain_acl.go`

**Input type** (from Entity Domain): `EntitiesExtracted` event
**Output type** (Compliance Domain model): `DataSubjectPresenceDetected`

**Translation mapping:**
| Entity Domain field | Compliance Domain type | Notes |
|--------------------|----------------------|-------|
| `payload.source_reference_id` | `DataSubjectSource.source_id` | Renamed |
| `payload.entity_type_summary[].entity_type` | `SensitiveDataCategory` (enum) | Mapped to compliance taxonomy: `PERSON_NAME` → `PII_DIRECT_IDENTIFIER` |
| `payload.entity_type_summary[].count` | `SensitiveDataCategory.instance_count` | |
| `payload.extraction_model_version` | `DataSubjectSource.detection_model_version` | |

---

## Error Handling and Retry Strategy

### Consumer Error Policy

| Scenario | Retry strategy | After max retries |
|----------|---------------|-------------------|
| Transient error (network, DB timeout) | Exponential back-off: 1s, 2s, 4s, 8s, 16s (max 5 retries) | Move to DLQ |
| Validation error (bad schema, missing field) | No retry (deterministic failure) | Move to DLQ immediately |
| Idempotency conflict (already processed) | Log and discard — not an error | — |
| Downstream service unavailable | Circuit Breaker (see below) | Move to DLQ after circuit opens |

### Dead Letter Queue (DLQ) Handling

All DLQ entries include:
```json
{
  "original_event": { "..." },
  "error": {
    "consumer_group": "string",
    "attempt_count": "integer",
    "last_error_message": "string",
    "last_attempted_at": "ISO8601"
  }
}
```

DLQ messages are:
1. Visible in the Operations Dashboard (alert on DLQ depth > 0)
2. Reviewable by operators
3. Re-processable by operators after root cause fix
4. Purged after 30 days retention

---

## Circuit Breaker Configuration

Required for all synchronous external calls:

| External call | CB threshold | Recovery period | Half-open probes |
|--------------|-------------|-----------------|-----------------|
| Google Drive API | 5 failures in 10s | 60s | 1 probe |
| AWS S3 API | 5 failures in 10s | 60s | 1 probe |
| SharePoint API | 5 failures in 10s | 60s | 1 probe |
| Secrets Manager | 3 failures in 10s | 120s | 1 probe |
| Identity Provider (OIDC) | 5 failures in 10s | 60s | 1 probe |

**Library:** `github.com/sony/gobreaker` (Go)

---

## Transactional Outbox Configuration

| Setting | Value |
|---------|-------|
| Outbox poll interval | 100ms |
| Max batch size per poll | 100 events |
| Published event retention in outbox | 24 hours (then archived or deleted) |
| Outbox table name pattern | `{bc_slug}_outbox` |
| Outbox relay deployment | Sidecar goroutine in each service |
```

## Quality Checks
- [ ] Every integration event (cross-BC) has a consumer group documented
- [ ] Every consumer group is isolated (dedicated, not shared)
- [ ] ACL translation is defined for every cross-BC boundary
- [ ] DLQ is defined for every consumer (no events silently dropped)
- [ ] Circuit breaker is defined for every synchronous external call
- [ ] Partition key strategy is documented (tenant_id)
- [ ] Outbox relay configuration is documented
