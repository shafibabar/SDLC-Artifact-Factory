# Skill: data/data-model-spec

## Purpose
Produce a Data Model Specification for one entity — the precise definition of its attributes, types, constraints, and persistence mapping. This is the contract between the domain model and the database. Developers implement tables and repository code from this spec.

## Inputs
- `artifacts/design/domain/aggregates/{name}.md`
- `artifacts/design/data/data-architecture.md`
- `artifacts/design/data/data-classification.md`
- `artifacts/design/data/canonical-data-model.md`
- **Argument required:** entity name (e.g. `StorageLocation`, `GoldenRecord`, `Finding`)

## Output
**File:** `artifacts/data/models/{entity-slug}.md`
**Registers in manifest:** yes

## Data Model Rules (enforced)
- Every attribute has an explicit type, nullable/non-null constraint, and default value (or "none").
- Data classification tier (C1–C4) is stated per attribute.
- Field-level encryption is specified for all C4 attributes.
- No ORM mapping — tables are hand-crafted SQL; this spec produces the DDL.
- Soft delete is mandatory for entities that participate in compliance or audit flows.
- Every table has: `id UUID PK`, `tenant_id UUID NOT NULL`, `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ`.

## Artifact Template

```markdown
# Data Model: {EntityName}

**Product:** {product_name}
**Bounded Context:** {context name}
**Phase:** Data
**Artifact:** Data Model Specification
**Schema:** `{bc_slug}_schema`
**Table:** `{table_name}`
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Entity Overview

**Domain concept:** {What this entity represents in the domain}
**Aggregate root?** Yes | No (belongs to {AggregateName})
**Data classification:** {C1 | C2 | C3 | C4 — highest tier of any attribute}
**Data owner:** {Bounded context name}

---

## Attribute Specification

| Column | Type | Nullable | Default | Classification | Encrypted | Description |
|--------|------|----------|---------|---------------|-----------|-------------|
| `id` | `UUID` | NOT NULL | `gen_random_uuid()` | C2 | No | Aggregate identity |
| `tenant_id` | `UUID` | NOT NULL | — | C2 | No | Tenant isolation key |
| `storage_path` | `TEXT` | NOT NULL | — | C3 | No | Full path to the storage resource |
| `platform` | `TEXT` | NOT NULL | — | C2 | No | Enum: GOOGLE_DRIVE, AWS_S3, SHAREPOINT, DROPBOX |
| `credential_ref` | `TEXT` | NOT NULL | — | C3 | No | Reference key to secrets manager entry (never the credential value) |
| `status` | `TEXT` | NOT NULL | `'PENDING'` | C2 | No | Enum: PENDING, ACTIVE, SCANNING, SCAN_ERROR, DEREGISTERED |
| `scan_config` | `JSONB` | NOT NULL | `'{}'::jsonb` | C2 | No | ScanConfiguration value object (serialised) |
| `last_scan_initiated_at` | `TIMESTAMPTZ` | NULL | — | C2 | No | When the most recent scan began |
| `last_scan_completed_at` | `TIMESTAMPTZ` | NULL | — | C2 | No | When the most recent scan completed |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | C2 | No | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | C2 | No | Last modification timestamp |
| `deleted_at` | `TIMESTAMPTZ` | NULL | — | C2 | No | Soft delete timestamp; NULL = active |

---

## Constraints

```sql
ALTER TABLE storage_locations
    ADD CONSTRAINT pk_storage_locations PRIMARY KEY (id),
    ADD CONSTRAINT uq_storage_locations_tenant_path UNIQUE (tenant_id, storage_path),
    ADD CONSTRAINT chk_storage_locations_platform CHECK (
        platform IN ('GOOGLE_DRIVE', 'AWS_S3', 'SHAREPOINT', 'DROPBOX')
    ),
    ADD CONSTRAINT chk_storage_locations_status CHECK (
        status IN ('PENDING', 'ACTIVE', 'SCANNING', 'SCAN_ERROR', 'DEREGISTERED')
    ),
    ADD CONSTRAINT chk_storage_locations_resource_cap CHECK (
        (scan_config->>'resource_cap_percent')::int BETWEEN 1 AND 100
    );
```

---

## Indexes

```sql
-- Tenant-scoped list query (primary query pattern)
CREATE INDEX idx_storage_locations_tenant_status
    ON storage_locations (tenant_id, status)
    WHERE deleted_at IS NULL;

-- Audit/lineage lookup
CREATE INDEX idx_storage_locations_tenant_created
    ON storage_locations (tenant_id, created_at DESC)
    WHERE deleted_at IS NULL;
```

---

## Full DDL

```sql
CREATE TABLE storage_locations (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id               UUID        NOT NULL,
    storage_path            TEXT        NOT NULL,
    platform                TEXT        NOT NULL,
    credential_ref          TEXT        NOT NULL,
    status                  TEXT        NOT NULL DEFAULT 'PENDING',
    scan_config             JSONB       NOT NULL DEFAULT '{}',
    last_scan_initiated_at  TIMESTAMPTZ,
    last_scan_completed_at  TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ,

    CONSTRAINT pk_storage_locations PRIMARY KEY (id),
    CONSTRAINT uq_storage_locations_tenant_path UNIQUE (tenant_id, storage_path),
    CONSTRAINT chk_storage_locations_platform CHECK (
        platform IN ('GOOGLE_DRIVE', 'AWS_S3', 'SHAREPOINT', 'DROPBOX')
    ),
    CONSTRAINT chk_storage_locations_status CHECK (
        status IN ('PENDING', 'ACTIVE', 'SCANNING', 'SCAN_ERROR', 'DEREGISTERED')
    )
);

-- Row-level security (defence in depth)
ALTER TABLE storage_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY storage_locations_tenant_isolation ON storage_locations
    USING (tenant_id = current_setting('app.tenant_id')::UUID);

-- Auto-update updated_at
CREATE TRIGGER trg_storage_locations_updated_at
    BEFORE UPDATE ON storage_locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## Field-Level Encryption (C4 entities only)

Not applicable for StorageLocation (highest tier is C3).

**For C4 entities (e.g. ExtractedEntity):** the `value` column is encrypted before write:
```sql
-- value column stores AES-256-GCM ciphertext + nonce, base64-encoded
-- Encryption/decryption happens in the application layer (Entity Domain Service)
-- The database holds only opaque ciphertext
value_encrypted TEXT NOT NULL
```

---

## Outbox Table

```sql
CREATE TABLE storage_location_outbox (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    aggregate_id    UUID        NOT NULL REFERENCES storage_locations(id),
    event_type      TEXT        NOT NULL,
    event_payload   JSONB       NOT NULL,
    idempotency_key TEXT        NOT NULL UNIQUE,
    published_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_storage_location_outbox PRIMARY KEY (id)
);

CREATE INDEX idx_storage_location_outbox_unpublished
    ON storage_location_outbox (created_at)
    WHERE published_at IS NULL;
```

---

## Soft Delete Convention

Records are soft-deleted by setting `deleted_at = NOW()`. Hard delete is prohibited at the application layer.

All queries add `WHERE deleted_at IS NULL` via the Row-Level Security policy or explicit filter.

For GDPR erasure: `deleted_at` is set AND the Row-Level Security policy is updated to also exclude on erasure status, then a scheduled job performs hard delete after the 90-day confirmation window.
```

## Quality Checks
- [ ] Every attribute has type, nullable, default, classification, and encryption specified
- [ ] All C4 attributes have field-level encryption specified
- [ ] Full DDL is syntactically valid PostgreSQL
- [ ] Row-Level Security policy is present for tenant isolation
- [ ] Outbox table is defined (for aggregate events)
- [ ] Soft delete column `deleted_at` is present
- [ ] `tenant_id` column exists on every table
