# Command Format Reference

Self-contained reference for the Command envelope specification, Go struct patterns,
worked examples from the DataAsset Bounded Context, and the idempotency implementation
pattern with edge cases. Read alongside `SKILL.md`'s Command Envelope section.

---

## Command Envelope: Field Specification

Every Command struct in this repo carries six standard envelope fields before its
domain-specific payload. These fields are non-negotiable: they enable tracing,
idempotency, routing, and audit across all write operations.

| Field | Go type | Required | Description |
|---|---|---|---|
| `CommandID` | `uuid.UUID` | Yes | Globally unique identifier for this invocation. Client-generated (not server-assigned). Serves as the idempotency key — if the same `CommandID` arrives twice, the second is a no-op returning the first result. |
| `AggregateID` | `uuid.UUID` | Yes | Identity of the specific Aggregate instance being operated on. Used by the handler to load the Aggregate from its Repository. |
| `AggregateType` | `string` | Yes | Canonical type name of the target Aggregate (`"DataAsset"`, `"StorageSource"`). Used for routing, logging, and defensive checks inside the handler. |
| `IssuedBy` | `uuid.UUID` | Yes | Identity of the actor issuing the Command — a `UserID` for human actions, a `ServiceID` for automated policies. Written to the audit trail on every state change. |
| `IssuedAt` | `time.Time` | Yes | UTC timestamp when the Command was issued by the client. Distinct from `CreatedAt` on the Domain Event, which reflects when the state change was applied by the Aggregate. |
| `TenantID` | `uuid.UUID` | Yes | Tenant scoping for physical multi-tenancy. All persistence operations must filter on this field; the Repository enforces it at query time. Not a payload field — it is part of the envelope. |

> **Note on payload:** the sixth envelope concept is the Command-specific payload
> struct embedded inline (not a field named `payload`). In Go, embed the domain
> fields directly in the command struct after the envelope fields — do not nest
> them under a `Payload` sub-struct, which adds unnecessary indirection.

---

## Go Struct Pattern

```go
// package commands — lives in internal/application/commands/

// BaseCommand carries envelope fields shared by every command.
// Embed this in every concrete command struct.
type BaseCommand struct {
    CommandID     uuid.UUID `json:"commandId"     validate:"required"`
    AggregateID   uuid.UUID `json:"aggregateId"   validate:"required"`
    AggregateType string    `json:"aggregateType" validate:"required"`
    IssuedBy      uuid.UUID `json:"issuedBy"      validate:"required"`
    IssuedAt      time.Time `json:"issuedAt"      validate:"required"`
    TenantID      uuid.UUID `json:"tenantId"      validate:"required"`
}

// Concrete command — embed BaseCommand, add domain fields directly.
type ClassifyDataAsset struct {
    BaseCommand

    // Domain payload — fields specific to this Command's intent.
    SensitivityLevel  domain.SensitivityLevel `json:"sensitivityLevel"  validate:"required,oneof=Public Internal Confidential Restricted"`
    ClassificationNote string                 `json:"classificationNote" validate:"max=500"`
}
```

**Conventions:**

- Struct name is the Command name (PascalCase, no `Command` suffix except in the
  package path). Handler is `ClassifyDataAssetHandler`, not `ClassifyDataAssetCommandHandler`.
- `validate` tags use `go-playground/validator/v10` conventions. Structural validation
  calls `validator.Validate(cmd)` in the API handler before any domain logic.
- Value Object types (e.g., `domain.SensitivityLevel`) carry their own `IsValid()`
  method; the `validate:"oneof=..."` tag and the `IsValid()` guard provide two
  checkpoints (Layer 1 and Layer 2 respectively — see `references/validation-patterns.md`).
- `IssuedAt` is set by the client (or the API handler on the client's behalf). It is
  **not** set by the Aggregate — the Aggregate uses its own `occurredAt` from the
  clock at the time it applies the change, not the time the request arrived.

---

## Worked Example: ClassifyDataAsset

Below is a fully-populated Command for the DataAsset Bounded Context — all fields
filled exactly as they would appear in a real handler invocation.

```go
cmd := commands.ClassifyDataAsset{
    BaseCommand: commands.BaseCommand{
        CommandID:     uuid.MustParse("a1b2c3d4-e5f6-7890-abcd-ef1234567890"),
        AggregateID:   uuid.MustParse("d7e8f9a0-b1c2-3456-d7e8-f9a0b1c23456"),
        AggregateType: "DataAsset",
        IssuedBy:      uuid.MustParse("f0e1d2c3-b4a5-6789-f0e1-d2c3b4a56789"),
        IssuedAt:      time.Date(2026, 6, 25, 14, 32, 0, 0, time.UTC),
        TenantID:      uuid.MustParse("00000001-0000-0000-0000-000000000001"),
    },
    SensitivityLevel:   domain.SensitivityConfidential,
    ClassificationNote: "Contains PII fields identified during estate scan",
}
```

**How each field is sourced in practice:**

| Field | Source |
|---|---|
| `CommandID` | Generated by the API client or by the HTTP handler: `uuid.New()` |
| `AggregateID` | Extracted from the URL path parameter: `/v1/data-assets/{id}/classification` |
| `AggregateType` | Hard-coded in the handler for this endpoint: `"DataAsset"` |
| `IssuedBy` | Extracted from the authenticated request context (JWT `sub` claim mapped to `UserID`) |
| `IssuedAt` | Set by the API handler at request-receipt time: `time.Now().UTC()` |
| `TenantID` | Extracted from the authenticated request context (JWT `tenant_id` claim) |
| `SensitivityLevel` | Deserialized from the JSON request body |
| `ClassificationNote` | Deserialized from the JSON request body (optional, may be empty) |

---

## Idempotency: The commandId as Idempotency Key

Commands issued over a network may be retried by the client (network timeout, proxy
failure, client retry logic). A handler that is not idempotent applies the same change
twice on retry, corrupting state or double-emitting Domain Events.

`CommandID` is the idempotency key for every Command. It is client-generated, globally
unique per invocation, and persisted in a `command_log` table. If the same `CommandID`
arrives a second time, the handler returns the stored result without re-applying the
Command.

### command_log Table

```sql
CREATE TABLE command_log (
    idempotency_key UUID        NOT NULL,
    tenant_id       UUID        NOT NULL,
    command_type    TEXT        NOT NULL,
    result          JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (idempotency_key, tenant_id)
);

CREATE INDEX command_log_cleanup_idx ON command_log (created_at);
```

The composite primary key `(idempotency_key, tenant_id)` prevents cross-tenant key
collisions while still enforcing uniqueness within a tenant.

### Handler Pattern

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    // 1. Check idempotency before loading the Aggregate.
    existing, err := h.commandLog.Find(ctx, cmd.CommandID, cmd.TenantID)
    if err != nil && !errors.Is(err, ErrNotFound) {
        return fmt.Errorf("command log lookup: %w", err)
    }
    if existing != nil {
        // Already processed — return the stored result (success or the original error).
        return existing.ReplayError()
    }

    // 2. Load Aggregate.
    asset, err := h.repo.FindByID(ctx, cmd.TenantID, cmd.AggregateID)
    if err != nil {
        return fmt.Errorf("load DataAsset: %w", err)
    }

    // 3. Apply the command to the Aggregate (business-rule validation is inside Classify).
    if err := asset.Classify(cmd); err != nil {
        // Record the rejection in command_log so retries return the same error.
        _ = h.commandLog.Record(ctx, cmd.CommandID, cmd.TenantID, "ClassifyDataAsset", err)
        return err
    }

    // 4. Persist Aggregate + outbox event + command_log record in one transaction.
    return h.repo.Save(ctx, asset, func(tx pgx.Tx) error {
        return h.commandLog.RecordTx(tx, cmd.CommandID, cmd.TenantID, "ClassifyDataAsset", nil)
    })
}
```

---

## Idempotency Edge Cases

The naive "check then process" pattern has four failure modes that must all be addressed:

### Edge Case 1: Same Transaction or Nothing

The state change (Aggregate save) and the `command_log` insert must commit in the same
database transaction. If the handler commits the Aggregate and then crashes before
inserting the `command_log` row, the retry re-applies the change.

**Fix:** The `RecordTx` callback in the example above writes the `command_log` row
inside the same `pgx.Tx` that saves the Aggregate and the outbox event. All three
succeed together or all three roll back.

### Edge Case 2: Concurrent Duplicates

Two simultaneous requests carrying the same `CommandID` can both pass the `Find` check
before either inserts into `command_log`. The `PRIMARY KEY` constraint on
`(idempotency_key, tenant_id)` rejects the loser's insert with a unique-key violation.
Treat that `23505` PostgreSQL error code as "already processed" — read the winning
row and return its stored result, not an error to the client.

```go
if pgErr, ok := err.(*pgconn.PgError); ok && pgErr.Code == "23505" {
    // Lost the race — another goroutine already inserted this key.
    // Re-read and replay the winner's result.
    return h.commandLog.ReplayResult(ctx, cmd.CommandID, cmd.TenantID)
}
```

### Edge Case 3: Return the Stored Result

The duplicate invocation must return the **same** response as the original — including
the original's failure if the Command was rejected. Returning a fresh success for a
Command that originally failed breaks the idempotency contract and can confuse clients
that rely on result consistency across retries.

The `result JSONB` column stores a serialised `CommandResult` (success event ID, or
a structured error). `ReplayError()` deserialises it and returns the original error
type so the handler's response code is identical on retry.

### Edge Case 4: Retention Window

Prune `command_log` on a scheduled job (e.g., nightly `DELETE WHERE created_at < now() - INTERVAL '7 days'`), but keep rows at least as long as the client's maximum retry
horizon. A key pruned too early re-opens the duplicate window: a retried Command
with a pruned key would be treated as new and re-applied.

The `command_log_cleanup_idx` on `created_at` makes range-delete scans efficient at
scale.

---

## API Endpoint Mapping

Each Command maps to exactly one API endpoint. The endpoint uses a state-changing HTTP
method (POST, PUT, PATCH, DELETE) — never GET.

| Command | HTTP Method | Path |
|---|---|---|
| `ClassifyDataAsset` | PATCH | `/v1/data-assets/{id}/classification` |
| `ArchiveDataAsset` | DELETE | `/v1/data-assets/{id}` |
| `ConnectStorageSource` | POST | `/v1/storage-sources` |
| `TriggerEstateScan` | POST | `/v1/storage-sources/{id}/scans` |
| `DetachStorageSource` | DELETE | `/v1/storage-sources/{id}` |

The HTTP response for a successfully-accepted Command returns:
- `202 Accepted` (not `200 OK`) — the state change is applied but downstream
  projections may not yet reflect it (eventual consistency via outbox)
- Body: `{"commandId": "<uuid>", "eventId": "<uuid>"}` — the client uses the
  `eventId` to correlate with the projected Read Model update

This mapping is the authoritative input to the API contract design step (`api-contract-design` skill).
