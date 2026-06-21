# Skill: design/event-schema

## Purpose
Produce the Event Schema Registry — formal, versioned JSON Schema definitions for all domain events that cross bounded context boundaries. These schemas are the contract between producers and consumers on the Redpanda topics. Schema evolution rules prevent breaking consumers.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/policies.md` (to understand which events drive cross-context policies)

## Output
**File:** `artifacts/design/contracts/event-schemas.md`
**Individual schemas:** `artifacts/design/contracts/events/{event-name}.v{N}.schema.json`
**Registers in manifest:** yes

## Schema Rules (enforced)
- Every integration event (crosses a bounded context boundary) has a formal JSON Schema.
- Schemas are versioned from day one: `v1`, `v2`.
- Version increment rules:
  - **Patch** (no version bump): Documentation change only
  - **Minor** (no version bump, additive): Adding a new optional field
  - **Major** (new schema version `v2`): Removing a field, renaming a field, changing a field type, making an optional field required
- New schema versions must be backwards-compatible for at least one version (v1 and v2 must both be accepted by consumers during migration window).
- The event envelope is standard across all events; only the `payload` section is event-specific.
- `null` values are explicitly typed — do not use them when `undefined` (field absence) is intended.

## Standard Event Envelope

```json
{
  "$schema": "http://json-schema.org/draft-07/schema",
  "type": "object",
  "required": ["event_id", "event_type", "event_version", "schema_version", "occurred_at", "idempotency_key", "tenant_id", "payload"],
  "additionalProperties": false,
  "properties": {
    "event_id":        { "type": "string", "format": "uuid" },
    "event_type":      { "type": "string", "description": "PascalCase event name" },
    "event_version":   { "type": "integer", "minimum": 1 },
    "schema_version":  { "type": "string", "pattern": "^v[0-9]+$", "description": "Schema version, e.g. v1" },
    "occurred_at":     { "type": "string", "format": "date-time" },
    "idempotency_key": { "type": "string" },
    "tenant_id":       { "type": "string", "format": "uuid" },
    "correlation_id":  { "type": "string", "format": "uuid", "description": "Traces causal chain across multiple events" },
    "causation_id":    { "type": "string", "format": "uuid", "description": "The event_id that caused this event" },
    "payload":         { "type": "object", "description": "Event-specific payload — defined per-event" }
  }
}
```

## Artifact Template

```markdown
# Event Schema Registry

**Product:** {product_name}
**Phase:** Design
**Artifact:** Event Schema Registry
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Schema Naming Convention

- File: `{EventName}.v{N}.schema.json` — e.g. `FileProcessed.v1.schema.json`
- Topic: `{bounded-context-slug}.{event-name-kebab}` — e.g. `file-domain.file-processed`
- Schema ID: `{product}/{bc}/{EventName}/v{N}`

---

## Integration Events Registry

| Event | Source BC | Consumer BCs | Current schema | Topic |
|-------|----------|-------------|----------------|-------|
| `FileDiscovered` | File Domain | Entity Domain | v1 | `file-domain.file-discovered` |
| `FileProcessed` | File Domain | Entity Domain, Audit Domain | v1 | `file-domain.file-processed` |
| `EntitiesExtracted` | Entity Domain | Compliance Domain, Graph Domain, Audit Domain | v1 | `entity-domain.entities-extracted` |
| `GoldenRecordCreated` | Entity Domain | Compliance Domain, Graph Domain | v1 | `entity-domain.golden-record-created` |
| `GoldenRecordUpdated` | Entity Domain | Compliance Domain, Graph Domain | v1 | `entity-domain.golden-record-updated` |
| `FindingCreated` | Compliance Domain | Alert Domain, Audit Domain | v1 | `compliance-domain.finding-created` |
| `FindingResolved` | Compliance Domain | Audit Domain | v1 | `compliance-domain.finding-resolved` |

---

## Schema Definitions

### FileProcessed — v1
**Topic:** `file-domain.file-processed`
**File:** `artifacts/design/contracts/events/FileProcessed.v1.schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema",
  "$id": "{product}/file-domain/FileProcessed/v1",
  "title": "FileProcessed",
  "description": "A file's content has been extracted and is ready for entity extraction",
  "type": "object",
  "required": ["event_id", "event_type", "event_version", "schema_version", "occurred_at", "idempotency_key", "tenant_id", "payload"],
  "additionalProperties": false,
  "properties": {
    "event_id":        { "type": "string", "format": "uuid" },
    "event_type":      { "type": "string", "const": "FileProcessed" },
    "event_version":   { "type": "integer", "const": 1 },
    "schema_version":  { "type": "string", "const": "v1" },
    "occurred_at":     { "type": "string", "format": "date-time" },
    "idempotency_key": { "type": "string", "description": "{file_id}:{processing_job_id}" },
    "tenant_id":       { "type": "string", "format": "uuid" },
    "correlation_id":  { "type": "string", "format": "uuid" },
    "causation_id":    { "type": "string", "format": "uuid" },
    "payload": {
      "type": "object",
      "required": ["file_id", "storage_location_id", "file_checksum", "extracted_text_ref", "file_metadata"],
      "additionalProperties": false,
      "properties": {
        "file_id":                { "type": "string", "format": "uuid" },
        "storage_location_id":    { "type": "string", "format": "uuid" },
        "file_checksum":          { "type": "string", "pattern": "^sha256:[a-f0-9]{64}$" },
        "extracted_text_ref":     { "type": "string", "description": "Internal reference — text is not in the event payload" },
        "processing_duration_ms": { "type": "integer", "minimum": 0 },
        "file_metadata": {
          "type": "object",
          "required": ["mime_type", "size_bytes", "last_modified"],
          "properties": {
            "mime_type":     { "type": "string" },
            "size_bytes":    { "type": "integer", "minimum": 0 },
            "last_modified": { "type": "string", "format": "date-time" }
          }
        }
      }
    }
  }
}
```

**What is NOT in this payload:**
- Extracted text content — stored internally; `extracted_text_ref` is an opaque reference
- File access path — derived from `storage_location_id` by the consumer if needed
- PII indicators — Entity Domain determines this after extraction; File Domain does not classify

---

### EntitiesExtracted — v1
**Topic:** `entity-domain.entities-extracted`
**File:** `artifacts/design/contracts/events/EntitiesExtracted.v1.schema.json`

```json
{
  "payload": {
    "type": "object",
    "required": ["source_reference_id", "entity_count", "entity_type_summary", "extraction_model_version"],
    "properties": {
      "source_reference_id":        { "type": "string", "format": "uuid", "description": "Entity Domain's reference to the source — NOT File Domain's file_id" },
      "entity_count":               { "type": "integer", "minimum": 0 },
      "entity_type_summary": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["entity_type", "count"],
          "properties": {
            "entity_type": { "type": "string", "description": "e.g. PERSON_NAME, EMAIL_ADDRESS, SSN, CREDIT_CARD" },
            "count":       { "type": "integer" }
          }
        }
      },
      "extraction_model_version": { "type": "string", "description": "Version of the NER/classification model used" }
    }
  }
}
```

**What is NOT in this payload:**
- Individual entity values (e.g. actual names, emails) — entities are stored in Entity Domain's database; this event carries only counts and type summaries for routing
- Compliance judgements — that is Compliance Domain's job

---

## Schema Evolution Guidelines

### Adding a field (backwards-compatible — no version bump)
- Add the field as optional (`not` in `required`)
- Consumers that do not know about the new field continue working

### Removing or renaming a field (breaking change — increment to v2)
1. Publish `v2` schema alongside `v1`
2. Producer publishes both `v1` and `v2` events for a migration window (configurable, default 30 days)
3. All consumers migrate to `v2` during the window
4. Producer stops publishing `v1` after window closes
5. `v1` schema is archived but never deleted (event replay must remain possible)

### Topic Naming for Multiple Versions
- `file-domain.file-processed.v1` — version-specific topic (preferred for breaking changes)
- Or: consumers filter by `schema_version` field from a shared topic
```

## Quality Checks
- [ ] All integration events (crossing BC boundaries) have a schema defined
- [ ] Standard envelope fields are present on all schemas (`event_id`, `occurred_at`, `idempotency_key`, `tenant_id`, `payload`)
- [ ] "What is NOT in this payload" is documented for events containing entity or compliance data
- [ ] Schema versioning strategy is documented
- [ ] Topic naming convention is consistent
- [ ] `additionalProperties: false` is set to catch undocumented fields
