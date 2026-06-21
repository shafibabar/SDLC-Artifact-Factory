# Skill: design/read-model-definition

## Purpose
Produce a Read Model Definition — the query-side projection in the CQRS pattern. Read models are purpose-built, denormalised views optimised for a specific user interface or API query. They are built by consuming domain events and should never query the write-side (aggregate) storage.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/ideate/backlog/stories/` (to understand what queries each persona needs)
- `artifacts/design/domain/context.md`
- **Argument required:** read model name (e.g. `ComplianceDashboard`, `EntitySearchView`, `AuditTrail`)

## Output
**File:** `artifacts/design/domain/read-models/{name}.md`
**Registers in manifest:** yes

## Read Model Rules (enforced)
- Read models are NEVER updated via commands. They are only updated by consuming domain events.
- Read models may lag behind the write side — this is acceptable and expected (eventual consistency). Document the expected lag window.
- Read models are denormalised — duplication of data is intentional for query performance.
- Read models may be stored in a different storage technology than the write side (e.g. Elasticsearch for full-text search, PostgreSQL for relational, MongoDB for document).
- Every read model defines exactly which events update it and what projection logic is applied.
- Read models are disposable — they can be rebuilt by replaying all events. Document how to trigger a full rebuild.

## Artifact Template

```markdown
# Read Model: {ReadModelName}

**Product:** {product_name}
**Bounded Context:** {context name}
**Phase:** Design
**Artifact:** Read Model Definition
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Purpose
{One sentence: what question does this read model answer? What persona uses it and for what job?}

**Primary consumer:** {persona name} — {the specific job-to-be-done}
**Secondary consumers:** {API clients, exports, etc.}

---

## Storage Technology
- **Store:** {PostgreSQL | Elasticsearch | MongoDB | Redis}
- **Rationale:** {Why this storage? e.g. "Elasticsearch for full-text entity name search across 10M+ records"}

---

## Document / Row Structure

```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "created_at": "ISO8601",
  "updated_at": "ISO8601",
  "{field_1}": "{type}",
  "{field_2}": "{type}",
  "{nested_object}": {
    "{sub_field}": "{type}"
  }
}
```

**Example (ComplianceDashboardView):**
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "framework": "GDPR",
  "total_findings": 142,
  "critical_findings": 3,
  "high_findings": 17,
  "medium_findings": 62,
  "low_findings": 60,
  "posture_score": 71.4,
  "last_evaluated_at": "ISO8601",
  "open_exceptions": 5,
  "top_violated_rules": [
    { "rule_id": "uuid", "rule_name": "string", "violation_count": "integer" }
  ]
}
```

---

## Projection Logic (Events → Read Model)

| Event | Projection action |
|-------|------------------|
| `FindingCreated` | Increment `total_findings` and appropriate severity counter; recalculate `posture_score`; append to `top_violated_rules` if rule not already present |
| `FindingResolved` | Decrement `total_findings` and severity counter; recalculate `posture_score` |
| `FindingAcknowledged` | Update status in `open_exceptions` counter; no posture change |
| `ExceptionCreated` | Increment `open_exceptions` |
| `ComplianceEvaluationRun` | Update `last_evaluated_at` |

---

## Query Patterns Supported

| Query | Parameters | Result |
|-------|-----------|--------|
| Get dashboard for tenant and framework | `tenant_id`, `framework` | Single `ComplianceDashboardView` |
| List dashboards for tenant | `tenant_id` | List of all framework views for tenant |

---

## Consistency Characteristics

| Attribute | Value |
|-----------|-------|
| **Pattern** | Eventually consistent (event-driven projection) |
| **Expected lag** | < 500ms under normal load (Redpanda consumer lag) |
| **Acceptable lag** | Up to 5 seconds under high load (document in NFRs) |
| **Stale read risk** | Dashboard may not reflect a finding created in the last 500ms — acceptable for this use case |

---

## Rebuild Strategy

If this read model is corrupted or needs to be rebuilt from scratch:

1. Drop and recreate the underlying table / collection / index
2. Replay all relevant events from Redpanda from earliest offset
3. Apply the same projection logic
4. Once caught up, switch consumer to live offset

**Replay time estimate:** {estimate based on expected event volume}
**Rebuild trigger command:** `/sdlc-artifact design/read-model-rebuild <model-name>`
```

## Quality Checks
- [ ] Read model is never updated by a command — only by event projection
- [ ] Every event that modifies this read model is listed in the projection table
- [ ] Storage technology choice is justified against query patterns
- [ ] Consistency characteristics and acceptable lag are documented
- [ ] Rebuild strategy is defined
- [ ] All field names use the bounded context's ubiquitous language
