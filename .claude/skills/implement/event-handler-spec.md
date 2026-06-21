# Skill: implement/event-handler-spec

## Purpose
Produce an Event Handler Specification for one domain event — the detailed specification for how a consumer handles an incoming event: ACL translation, idempotency check, command dispatch or projection update, and error handling. This spec is the guide a developer follows when implementing a Redpanda consumer handler.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/domain/policies.md`
- `artifacts/design/architecture/integration-design.md` (for consumer group and ACL specs)
- `artifacts/design/contracts/event-schemas.md`
- `artifacts/implement/standards/coding-standards.md`
- **Argument required:** event name (e.g. `FileProcessed`, `EntitiesExtracted`)

## Output
**File:** `artifacts/implement/events/{event-name}-handler-spec.md`
**Registers in manifest:** yes

## Event Handler Rules (enforced)
- Every handler checks idempotency FIRST — before any state changes.
- ACL translation is a separate function — it is tested independently of the handler logic.
- Handlers are pure application logic — they do not call infrastructure directly; they call repositories and command handlers.
- Handlers must be testable without a real Redpanda consumer — they receive a decoded event struct.
- Error handling distinguishes: transient (retry), deterministic (DLQ immediately), idempotent (discard).

## Artifact Template

```markdown
# Event Handler Specification: {EventName}

**Product:** {product_name}
**Phase:** Implement
**Artifact:** Event Handler Specification
**Event:** `{EventName}`
**Source context:** {source bounded context}
**Consumer service:** {consumer bounded context service}
**Consumer group:** `{cg-name}`
**Date:** {date}
**Status:** Approved

---

## Event Source

| Attribute | Value |
|-----------|-------|
| **Redpanda topic** | `{source-bc}.{event-name-kebab}` |
| **Schema version** | v1 |
| **Producer** | {Source BC Service} |
| **Schema file** | `contracts/{EventName}.v1.schema.json` |

---

## Triggered By (Policy)

Policy `{P-XCTX-01}`: {Policy name}
> "When `{EventName}` is received, then issue `{CommandName}` command to `{TargetAggregate}` aggregate"

---

## Processing Flow

```
[Redpanda Consumer]
        │
        ▼
[Decode event envelope] ── schema mismatch ──► [DLQ immediately]
        │
        ▼
[Validate tenant_id] ──── no matching tenant ──► [DLQ: UNKNOWN_TENANT]
        │
        ▼
[Idempotency check] ───── already processed ──► [Discard (log INFO)]
        │
        ▼
[ACL Translation] ──────── translation error ──► [DLQ immediately]
        │
        ▼
[Dispatch command/update projection]
        │
        ├── success ──────────────────────────► [Mark idempotency key processed]
        │
        └── transient error (DB down, etc.) ──► [Return error → consumer retries with backoff]
            deterministic error (business rule) ──► [DLQ with error detail]
```

---

## Idempotency Implementation

```go
// Idempotency table: {consumer_bc}_processed_events
// Schema:
//   CREATE TABLE IF NOT EXISTS {consumer_bc}_processed_events (
//       idempotency_key TEXT PRIMARY KEY,
//       processed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
//       event_type      TEXT NOT NULL
//   );

func (h *FileProcessedEventHandler) isAlreadyProcessed(ctx context.Context, key string) (bool, error) {
    var exists bool
    err := h.db.QueryRow(ctx,
        `SELECT EXISTS(SELECT 1 FROM entity_processed_events WHERE idempotency_key = $1)`, key,
    ).Scan(&exists)
    return exists, err
}

func (h *FileProcessedEventHandler) markProcessed(ctx context.Context, key, eventType string) error {
    _, err := h.db.Exec(ctx,
        `INSERT INTO entity_processed_events (idempotency_key, event_type) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        key, eventType,
    )
    return err
}
```

---

## ACL Translation

The incoming event uses the source context's types. Translation produces the consumer context's types:

```go
// acl/file_domain_acl.go — tested independently

// FileProcessedEvent is the wire type decoded from the Redpanda message
type FileProcessedEvent struct {
    EventID         string `json:"event_id"`
    EventType       string `json:"event_type"`
    SchemaVersion   string `json:"schema_version"`
    OccurredAt      string `json:"occurred_at"`
    IdempotencyKey  string `json:"idempotency_key"`
    TenantID        string `json:"tenant_id"`
    Payload         struct {
        FileID          string `json:"file_id"`
        StorageLocationID string `json:"storage_location_id"`
        FileChecksum    string `json:"file_checksum"`
        ExtractedTextRef string `json:"extracted_text_ref"`
        FileMetadata    struct {
            MIMEType     string `json:"mime_type"`
            SizeBytes    int64  `json:"size_bytes"`
            LastModified string `json:"last_modified"`
        } `json:"file_metadata"`
    } `json:"payload"`
}

// SourceFileReadyForExtraction is the Entity Domain's internal type
type SourceFileReadyForExtraction struct {
    SourceReferenceID string    // maps from file_id — renamed to domain language
    OriginLocationID  string    // maps from storage_location_id
    ContentFingerprint string   // maps from file_checksum — renamed
    ContentType       string    // maps from file_metadata.mime_type — renamed
    TextRef           string    // maps from extracted_text_ref
    TenantID          uuid.UUID
}

// TranslateFileProcessed translates from File Domain wire type to Entity Domain type
// This function is pure — no side effects, fully testable
func TranslateFileProcessed(e FileProcessedEvent) (SourceFileReadyForExtraction, error) {
    tenantID, err := uuid.Parse(e.TenantID)
    if err != nil {
        return SourceFileReadyForExtraction{}, fmt.Errorf("invalid tenant_id: %w", err)
    }
    return SourceFileReadyForExtraction{
        SourceReferenceID:  e.Payload.FileID,
        OriginLocationID:   e.Payload.StorageLocationID,
        ContentFingerprint: e.Payload.FileChecksum,
        ContentType:        e.Payload.FileMetadata.MIMEType,
        TextRef:            e.Payload.ExtractedTextRef,
        TenantID:           tenantID,
    }, nil
}
```

---

## Complete Handler Implementation

```go
// internal/application/eventhandlers/file_processed.go

type FileProcessedEventHandler struct {
    db                   *pgxpool.Pool
    extractEntitiesHandler *commands.ExtractEntitiesHandler
}

func (h *FileProcessedEventHandler) Handle(ctx context.Context, raw []byte) error {
    // 1. Decode
    var event acl.FileProcessedEvent
    if err := json.Unmarshal(raw, &event); err != nil {
        // Schema mismatch — deterministic failure; send to DLQ immediately
        return &DLQError{Reason: "schema_decode_failed", Err: err}
    }

    // 2. Validate tenant
    if _, err := uuid.Parse(event.TenantID); err != nil {
        return &DLQError{Reason: "invalid_tenant_id", Err: err}
    }

    // 3. Idempotency check
    processed, err := h.isAlreadyProcessed(ctx, event.IdempotencyKey)
    if err != nil {
        return fmt.Errorf("idempotency check: %w", err) // transient — retry
    }
    if processed {
        slog.InfoContext(ctx, "event already processed, discarding",
            "idempotency_key", event.IdempotencyKey,
            "event_type", event.EventType,
        )
        return nil
    }

    // 4. ACL translation
    source, err := acl.TranslateFileProcessed(event)
    if err != nil {
        return &DLQError{Reason: "acl_translation_failed", Err: err}
    }

    // 5. Dispatch command
    cmd := commands.ExtractEntitiesCommand{
        TenantID:          source.TenantID,
        SourceReferenceID: source.SourceReferenceID,
        TextRef:           source.TextRef,
        ContentType:       source.ContentType,
    }
    if err := h.extractEntitiesHandler.Handle(ctx, cmd); err != nil {
        if domain.IsBusinessError(err) {
            return &DLQError{Reason: "business_rule_violation", Err: err}
        }
        return fmt.Errorf("extract entities command: %w", err) // transient — retry
    }

    // 6. Mark idempotency key processed
    return h.markProcessed(ctx, event.IdempotencyKey, event.EventType)
}
```

---

## Error Classification

| Error type | Handler action | Retry? |
|-----------|---------------|--------|
| JSON decode failure | Return `DLQError` | No — deterministic |
| Schema version mismatch | Return `DLQError` | No — deterministic |
| Unknown tenant_id | Return `DLQError` | No — deterministic |
| ACL translation error | Return `DLQError` | No — deterministic |
| Business rule violation (domain error) | Return `DLQError` with context | No — deterministic |
| Database transient error | Return wrapped error | Yes — consumer retries with backoff |
| Downstream service unavailable | Return wrapped error | Yes — circuit breaker applies |
| Idempotency conflict | Discard (return nil) | N/A |

---

## TDD Test Cases for This Handler

```go
func TestFileProcessedEventHandler_Handle_DispatchesExtractEntitiesCommand(t *testing.T) { ... }
func TestFileProcessedEventHandler_Handle_DiscardsAlreadyProcessedEvent(t *testing.T) { ... }
func TestFileProcessedEventHandler_Handle_SendsToMalformedEventToDLQ(t *testing.T) { ... }
func TestFileProcessedEventHandler_Handle_RetriesOnDatabaseError(t *testing.T) { ... }
func TestTranslateFileProcessed_MapsAllFieldsCorrectly(t *testing.T) { ... }
func TestTranslateFileProcessed_RejectsInvalidTenantID(t *testing.T) { ... }
```
```

## Quality Checks
- [ ] Idempotency check is the first action after decoding (before any state changes)
- [ ] ACL translation is a pure function (no side effects) tested independently
- [ ] Error classification distinguishes deterministic (DLQ) from transient (retry)
- [ ] Handler receives a decoded event struct — not a raw Redpanda message object
- [ ] TDD test cases are listed for all error paths and the happy path
- [ ] Processing flow diagram covers all branches including DLQ paths
