# Skill: design/event-catalogue

## Purpose
Produce the Domain Event Catalogue — the authoritative, complete list of all domain events in the system. This is the backbone of the event-driven architecture. Every event schema, every consumer, every policy, and every audit log entry traces back to this catalogue.

## Inputs
- Event Storming session output (if run)
- `artifacts/ideate/requirements/functional.md`
- `artifacts/design/domain/context.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/domain/events.md`
**Registers in manifest:** yes

## Domain Event Rules (enforced)
- Names are in past tense, PascalCase: `FileProcessed`, `EntityExtracted`, `FindingCreated`
- Events represent facts — things that happened. They are never instructions.
- Events carry all data consumers need — consumers must not query back to the producer.
- Events are immutable. Once published, an event cannot be modified.
- Every event has an idempotency key to support safe replay.
- Events are versioned from day one (`v1`, `v2`). Breaking changes require a new version.

## Process
1. Read functional requirements and Event Storming output if available.
2. Identify all domain events across all subdomains in scope.
3. For each event: define name, owning aggregate, trigger, payload, and consumers.
4. Group events by bounded context.
5. Flag events that cross bounded context boundaries — these drive the integration design.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Domain Event Catalogue

**Product:** {product_name}
**Phase:** Design
**Artifact:** Domain Event Catalogue
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Event Naming Conventions
- Past tense, PascalCase
- Format: `{Noun}{PastVerb}` — e.g. `FileProcessed`, `EntityExtracted`, `FindingCreated`
- Cross-context events prefixed with source context: `FileDomain.FileProcessed`

---

## {Bounded Context: e.g. File Domain}

### FileDiscovered
| Attribute | Value |
|-----------|-------|
| **Description** | A new file has been detected at a registered storage location |
| **Trigger** | Storage connector worker node detects a new file system event |
| **Owning aggregate** | StorageLocation |
| **Version** | v1 |
| **Idempotency key** | `{storage_location_id}:{file_path}:{detected_at}` |
| **Consumers** | File Processing Service, Audit Service |

**Payload (v1):**
```json
{
  "event_id": "uuid",
  "event_type": "FileDiscovered",
  "event_version": "1",
  "occurred_at": "ISO8601",
  "idempotency_key": "string",
  "storage_location_id": "uuid",
  "file_path": "string",
  "file_size_bytes": "integer",
  "detected_at": "ISO8601",
  "detection_source": "polling | webhook | cdc"
}
```

**What is NOT in this payload (and why):**
- File content — never transmitted; extracted at processing time within customer infrastructure
- User identity — the detection is system-initiated, not user-initiated

---

### FileProcessed
| Attribute | Value |
|-----------|-------|
| **Description** | A file's text and metadata have been successfully extracted and are ready for entity extraction |
| **Trigger** | File Processing Service completes text extraction for a discovered or modified file |
| **Owning aggregate** | FileProcessingJob |
| **Version** | v1 |
| **Idempotency key** | `{file_id}:{processing_job_id}` |
| **Consumers** | Entity Extraction Service, Audit Service |

**Payload (v1):**
```json
{
  "event_id": "uuid",
  "event_type": "FileProcessed",
  "event_version": "1",
  "occurred_at": "ISO8601",
  "idempotency_key": "string",
  "file_id": "uuid",
  "storage_location_id": "uuid",
  "file_checksum": "sha256-hex",
  "extracted_text_ref": "internal-ref",
  "file_metadata": {
    "mime_type": "string",
    "last_modified": "ISO8601",
    "size_bytes": "integer"
  },
  "processing_duration_ms": "integer"
}
```

---

### {Next Event Name}
{Same structure}

---

## {Bounded Context: e.g. Entity Domain}

### EntitiesExtracted
{Same structure}

---

## {Bounded Context: e.g. Compliance Domain}

### FindingCreated
{Same structure}

---

## Cross-Context Events Summary

| Event | Source context | Consumer contexts | Integration pattern |
|-------|---------------|-------------------|---------------------|
| `FileProcessed` | File Domain | Entity Domain | Published event on Redpanda topic |
| `EntitiesExtracted` | Entity Domain | Compliance Domain, Graph Domain | Published event on Redpanda topic |
| `FindingCreated` | Compliance Domain | Alert Domain, Audit Domain | Published event on Redpanda topic |

---

## Event Inventory Summary

| Context | Event count | Events list |
|---------|-------------|-------------|
| File Domain | {n} | FileDiscovered, FileProcessed, FileModified, FileDeleted, ... |
| Entity Domain | {n} | EntitiesExtracted, GoldenRecordCreated, GoldenRecordUpdated, ... |
| Compliance Domain | {n} | FindingCreated, FindingAcknowledged, FindingResolved, ... |
| **Total** | {n} | |
```

## Quality Checks
- [ ] All event names are past tense and PascalCase
- [ ] Every event has an idempotency key defined
- [ ] Every event's payload includes `event_id`, `event_type`, `event_version`, `occurred_at`
- [ ] Cross-context events are documented in the summary table
- [ ] "What is NOT in this payload" is populated for events containing sensitive data
- [ ] No undefined ubiquitous language terms
