# Deletion Mechanics

When a retention window elapses (and no legal hold applies), data must actually
be destroyed. This reference details the three deletion methods, when each
applies, how deletion cascades across every store the data reached, the
**crypto-shredding** technique that solves the immutable-backup problem, and the
audit evidence every deletion must leave behind.

The governing rule from `data-retention-policy`: for regulated or personal data,
deletion must be **verifiable** — the policy must be able to *prove* the data is
unrecoverable everywhere, not merely that a `DELETE` statement ran once.

---

## The Three Methods

### Soft delete (tombstone)

Set a `deleted_at` timestamp; the row remains physically present but is filtered
out of every query. Use it only as a **reversible grace window** before a hard
delete — for example, a data-asset record whose source connector was removed and
might be re-added within 30 days.

```sql
-- Soft delete: a reversible tombstone, NOT a final state
UPDATE data_assets
   SET deleted_at = now()
 WHERE tenant_id = $1 AND id = $2;
```

**Soft delete is never a terminal state.** A tombstone with no hard-delete job
behind it is still breached data, still discoverable in litigation, still in
scope for every regulation. Every soft delete must have a scheduled hard delete
that advances it once the grace window elapses.

### Hard delete

Physically remove the row and cascade to its children. Use it when the window
has elapsed, no hold applies, and no erasure conflict exists.

```sql
-- Child rows go with the parent via ON DELETE CASCADE declared in the schema:
--   CREATE TABLE extracted_entities (
--     ...,
--     data_asset_id uuid REFERENCES data_assets(id) ON DELETE CASCADE
--   );
DELETE FROM data_assets WHERE tenant_id = $1 AND id = $2;
```

Hard delete removes data from the *live* database. It does **not** reach data
that has already been copied into an immutable backup snapshot — which is why
personal data needs the third method.

### Verifiable / cryptographic deletion (crypto-shredding)

Encrypt sensitive data at rest under a key you can destroy; to make the data
permanently unrecoverable, **destroy the key** rather than the ciphertext. The
ciphertext may still sit in a backup snapshot, a replica, or a WAL segment, but
without the key it is unreadable noise. This is **crypto-shredding**, and it is
the *only* way to make personal data in an immutable backup unrecoverable.

```
Live delete  → removes ciphertext from the live DB.
Crypto-shred → destroys the key, so every remaining copy (backups, replicas,
               WAL, event payloads) becomes permanently unreadable at once.
```

Crypto-shredding is required for:

- **PII erasure** under GDPR Art. 17 — because you cannot chase a subject's bytes
  into every snapshot.
- **Backups** — immutable snapshots cannot be edited row-by-row.
- **Redpanda event payloads** — events are immutable; you cannot rewrite history.

---

## Key Granularity Must Match the Erasure Unit

This is the single most consequential design decision, and it cannot be
retrofitted onto ciphertext already written.

| Key granularity | Can erase | Cannot erase |
|---|---|---|
| **Per-tenant key** | An entire tenant (offboarding): destroy one key, every snapshot of that tenant becomes unreadable | One person within a tenant — shredding the key destroys *everyone's* data in that tenant |
| **Per-subject key** | One canonical Person: destroy that subject's key, exactly that subject's data across all copies becomes unreadable | (This is the granularity right-to-erasure requires) |

**Rule:** the finest erasure unit you *promise* dictates the key granularity you
must provision *before the first byte is written*. If you promise per-person
right-to-erasure, sensitive fields must be encrypted under a **per-subject key**
— one per canonical Person, itself wrapped by the tenant key (envelope
encryption). The per-tenant and per-subject keys come from `zero-trust-design`.

```
tenant_key (KEK)
   └── wraps → subject_key (DEK) per canonical Person
                  └── encrypts → that person's sensitive columns / event payloads

Erase one person  = destroy that subject_key.
Offboard a tenant = destroy that tenant_key (invalidates every wrapped subject_key).
```

The corollary bites early: **key granularity cannot be retrofitted.** Ciphertext
written under a per-tenant key can never be selectively erased per person later.
The erasure units are decided at design time, before write time — an
`event-schema-design` and storage-design constraint, not a runtime toggle.

---

## Cross-Store Cascade

Deleting from the primary Postgres table is not enough — derived copies flow to
many stores via the pipeline, traced by `data-lineage-design`. Every store needs
a named disposal approach:

| Store / artifact | Purge approach |
|---|---|
| **PostgreSQL Aggregate tables** | Hard delete with `ON DELETE CASCADE` to child entities |
| **Apache AGE graph** | Delete the corresponding vertices and edges, tenant-scoped |
| **Projections / Read Models** | Rebuilt from source; deleted source → the projector removes the projection |
| **Event log (Redpanda)** | Topic retention (time/size) for the operational window; for erasure of anything sensitive in a payload, crypto-shred — events are immutable |
| **Search index (Elasticsearch)** | Delete-by-query scoped to the purged refs |
| **Backups** | Crypto-shred (key destruction) — immutable snapshots cannot be edited |

**Event-log caveat.** Because events are immutable by design, sensitive data in
payloads is handled two ways: (a) don't put raw sensitive values in payloads in
the first place — carry IDs and metadata, resolve the value from the live store;
(b) for anything that must become unrecoverable, crypto-shred the subject key the
payload was encrypted under. This constraint flows back into `event-schema-design`.

The erasure *propagation* uses the Transactional Outbox: the primary delete and
an outbox row for the purge event commit in one transaction; a projector then
removes the AGE vertices and Elasticsearch docs — so the derived stores converge
even under Eventual Consistency, and no purge is lost if a projector is down.

---

## Worked Example — The Retention Sweep for DataAssets

One category's sweep, showing grace window, legal-hold check, cascade, batching,
and audit as a single unit of work:

```sql
-- Soft-deleted DataAssets whose 30-day grace has elapsed and are NOT under hold
WITH eligible AS (
    SELECT a.id
      FROM data_assets a
     WHERE a.tenant_id = $1
       AND a.deleted_at IS NOT NULL
       AND a.deleted_at < now() - interval '30 days'
       AND NOT EXISTS (
             SELECT 1 FROM legal_hold_items h
              WHERE h.tenant_id = a.tenant_id
                AND h.dataset   = 'data_assets'
                AND h.ref       = a.id
                AND h.released_at IS NULL)      -- an ACTIVE hold blocks the purge
     LIMIT 1000                                 -- bounded batches: no long locks, resumable
)
DELETE FROM data_assets WHERE id IN (SELECT id FROM eligible);
-- ON DELETE CASCADE removes extracted_entities in the same statement.
-- Same transaction: the audit record of what was purged, and the Transactional
-- Outbox row for the purge event — the projector then removes AGE vertices and
-- Elasticsearch docs.
```

**What the batch boundary buys:** each 1000-row batch commits its deletions
*with* its audit record and outbox row, so a sweep interrupted halfway leaves no
unaudited deletion and simply resumes on the next run. No long-held locks, no
partial state that can't be evidenced.

---

## Deletion Audit Evidence

Every purge and every erasure writes an audit record. A deletion with no audit
trail cannot be evidenced and is treated as **non-compliant** — from
`compliance-design`'s standpoint it did not happen.

The audit record retains the *proof of deletion*, never the deleted data:

```sql
CREATE TABLE deletion_audit (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     uuid NOT NULL,
    subject_ref   text,                 -- canonical Person id for erasure; NULL for retention sweeps
    dataset       text NOT NULL,        -- which class/store
    method        text NOT NULL,        -- 'hard_delete' | 'cascade' | 'crypto_shred'
    row_count     integer,              -- how many rows / vertices / docs
    key_id        text,                 -- for crypto_shred: the destroyed key's id (NOT the key)
    reason        text NOT NULL,        -- 'retention_window_elapsed' | 'erasure_request' | ...
    executed_at   timestamptz NOT NULL DEFAULT now(),
    executed_by   text NOT NULL         -- job name or operator
);
```

For crypto-shredding, the destroyed key's **identifier** is recorded, never the
key material — the record proves the key was destroyed. The `deletion_audit`
table is itself an audit-log class: 7-year window, hard delete only after it. You
keep the proof you complied; you never keep the erased data.

**Erasing the proof of erasure is an anti-pattern.** A GDPR request means "erase
this person's data," not "erase every trace the person existed." Art. 17(3)
preserves records needed to establish/defend legal claims — the deletion-audit
record is exactly that.

---

## Go: The Erasure Executor (sketch)

```go
// EraseSubject applies each derived artifact's disposition for one canonical
// Person, following lineage. Returns the audit records to persist in the same tx.
func (e *Eraser) EraseSubject(ctx context.Context, tenantID, subjectID string) ([]DeletionAudit, error) {
    artifacts, err := e.lineage.ForwardTraverse(ctx, tenantID, subjectID) // every derived copy
    if err != nil {
        return nil, err
    }
    var audits []DeletionAudit
    for _, a := range artifacts {
        if e.holds.Active(ctx, tenantID, a.Dataset, a.Ref) {
            audits = append(audits, deferralRecord(tenantID, subjectID, a)) // hold wins — defer, notify
            continue
        }
        switch a.Disposition {
        case HardDelete:
            audits = append(audits, e.hardDelete(ctx, a))
        case CryptoShred:
            audits = append(audits, e.shredKey(ctx, tenantID, subjectID, a)) // destroy the subject key
        }
    }
    return audits, nil // caller commits deletes + audits + PersonDataErased outbox row in ONE tx
}
```

The hold check comes *first* inside the loop: an active hold defers the erasure of
that artifact and records the deferral — legal hold outranks the erasure request.
See `legal-hold-and-archival.md`.

---

## Cross-References

- Which class gets which disposition, and the windows: `retention-schedule.md`
- Hold precedence that can defer any deletion here: `legal-hold-and-archival.md`
- The keys crypto-shredding destroys: `zero-trust-design`
- Lineage traversal that finds every derived copy to purge: `data-lineage-design`
