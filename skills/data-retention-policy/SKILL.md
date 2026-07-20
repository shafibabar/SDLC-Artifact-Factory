---
name: data-retention-policy
description: >
  Teaches how to design a data retention and disposal policy — defining retention
  periods per data category, the legal basis for retention, legal hold, the
  GDPR right-to-erasure mechanism, and how data is actually purged (soft delete,
  hard delete, crypto-shredding) across PostgreSQL, the graph, projections, events,
  and backups. Retention turns classification and lineage into enforceable lifecycle
  rules. Produced by the data-architect during the Design phase, feeding
  compliance-design and platform purge jobs.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, retention, erasure, gdpr, legal-hold, disposal, lifecycle]
---

# Data Retention Policy

## Purpose

Data has a lifecycle: it is created, used, and eventually must be disposed of. Keeping data longer than necessary increases breach exposure and regulatory liability; deleting it too soon breaks audit and compliance obligations. A retention policy makes the lifecycle explicit and enforceable: for each category of data, how long it is kept, why, and how it is destroyed.

This skill turns the outputs of `data-classification` (what sensitivity/category data is) and `data-lineage-design` (where derived data came from) into lifecycle rules that platform jobs enforce and that `compliance-design` can evidence.

---

## Retention Schedule

Every data category gets a retention rule: a period, a legal/operational basis, and a disposal method. "Keep forever" is a decision that must be justified, not a default.

| Data category | Retention period | Basis | Disposal method |
|---|---|---|---|
| Audit log | 7 years | SOC 2 / regulatory evidence | Hard delete after period; never before |
| Compliance reports | 7 years | Audit evidence | Hard delete after period |
| Lineage records | Match the longest-retained derived artifact | Evidence integrity | Purged with the artifact they describe |
| Extracted entity metadata | Life of the data asset | Operational | Cascade-deleted with the asset |
| Data asset records | Until source disconnected + grace period | Operational | Soft delete → hard delete after grace |
| Raw file content | **Not retained** | Privacy by design | Never stored — nothing to dispose |
| Personal data (PII) | Minimum needed for purpose; erasable on request | GDPR purpose limitation + erasure | Crypto-shred or hard delete |
| Operational logs/telemetry | 30–90 days | Operations | Rolling deletion |

**Principle:** the retention period is the *shortest* defensible duration that satisfies the legal/operational basis — data minimisation applied to time.

---

## Legal Hold

A legal hold overrides retention: data under hold is **not deleted** even if its retention period expires, until the hold is lifted.

| Concern | Design |
|---|---|
| Trigger | Litigation, investigation, or regulatory request |
| Scope | Identified by tenant + entity/lineage query (use forward lineage to find all affected derived data) |
| Mechanism | A `legal_hold` flag/record checked by every purge job; held rows are skipped |
| Lifting | Explicit, audited action; on lift, normal retention resumes (data past its period becomes eligible for purge) |
| Precedence | Legal hold > retention schedule > erasure request |

A purge job that ignores legal hold is a compliance defect. Hold checks are part of the purge job's contract, not an afterthought.

---

## Right to Erasure (GDPR Art. 17)

A data subject can request deletion of their personal data. The system must locate and erase it everywhere it propagated — which is exactly what `data-lineage-design` enables.

### Erasure procedure

```
1. Resolve the subject → canonical Person + all contributing source records (canonical-data-model).
2. Forward-traverse lineage: find every derived artifact originating from that personal data
   (entities, graph vertices, projections, reports).
3. For each artifact, apply the disposal method for its category:
     - erasable now  → delete / crypto-shred
     - under legal hold → defer, record the deferral, notify
     - required for overriding legal obligation → retain the minimum, record the lawful basis
4. Emit an audited PersonDataErased event; record what was erased, what was retained, and why.
5. Purge propagates to projections, the graph, and the event log per the rules below.
```

Erasure is **audited** — the record that erasure happened is itself retained (you keep proof you complied, not the erased data).

---

## Disposal Methods

| Method | What it does | Use when |
|---|---|---|
| **Soft delete** | Set `deleted_at`; row hidden from queries, still present | Reversible window / grace period before hard delete |
| **Hard delete** | Physically remove the row; cascade to children | Retention period elapsed; no hold; no erasure conflict |
| **Crypto-shredding** | Destroy the per-tenant/per-subject encryption key so ciphertext is unrecoverable | Erasing data that is impractical to locate physically (e.g., in immutable backups) |

**Crypto-shredding is the answer to the backup problem:** you cannot selectively delete one person's rows from an encrypted backup snapshot, but destroying the key renders that data permanently unreadable. This is why per-tenant (and where needed per-subject) encryption keys from `zero-trust-design` matter for retention.

**Key granularity must match the smallest erasure unit you promise.** A per-tenant key supports tenant offboarding — destroy one key and every snapshot of that tenant becomes unreadable — but it cannot erase one person: shredding it destroys everyone's data. If crypto-shredding is the erasure mechanism for personal data (and for backups it is the only one), the sensitive fields must be encrypted under a **per-subject key** — one per canonical Person, wrapped by the tenant key — so erasure destroys exactly that subject's key. The corollary bites early: key granularity cannot be retrofitted onto ciphertext already written, so the erasure units must be decided *before* the first byte of personal data is stored. Shredded keys are destroyed, and the destruction itself is the audited disposal record.

---

## Purging Across All Stores

Deleting from the primary table is not enough — derived copies must also be purged. The policy specifies disposal across every store the data reached (traced via lineage):

| Store / artifact | Purge approach |
|---|---|
| PostgreSQL Aggregate tables | Hard delete with `ON DELETE CASCADE` to child entities |
| Apache AGE graph | Delete the corresponding vertices/edges (tenant-scoped) |
| Projections / Read Models | Rebuilt from source; deleted source → projector removes the projection |
| Event log (Redpanda) | Topic retention (time/size); for erasure of payload-bearing events, rely on crypto-shredding or tombstones — events are immutable |
| Search index (Elasticsearch) | Delete-by-query scoped to the purged refs |
| Backups | Crypto-shredding (key destruction) — cannot edit immutable snapshots |

**Event log caveat:** events are immutable by design, so personal data in event payloads is handled by (a) not putting raw sensitive values in payloads in the first place — only metadata/IDs — and (b) crypto-shredding for anything that must be rendered unrecoverable. This is a design constraint that flows back into `event-schema-design`.

---

## Enforcement

Retention is enforced by scheduled purge jobs (implemented by the platform-engineer, specified here):

| Job | Schedule | Contract |
|---|---|---|
| Retention sweep | Daily | For each category, find rows past retention, not under hold → dispose per method; emit audit record |
| Erasure processor | On request (SLA-bound) | Execute the erasure procedure; emit `PersonDataErased`; report completion within the legal SLA |
| Hold reconciler | On hold change | Re-evaluate eligibility when a hold is placed or lifted |

Every purge action writes to the audit log. A deletion with no audit trail cannot be evidenced and is treated as non-compliant.

### Example — the retention sweep for DataAssets

The sweep for one category, showing the full contract in SQL terms — grace period, legal hold check, cascade, and audit in one unit of work:

```sql
-- Soft-deleted DataAssets whose 30-day grace has elapsed and that are not under hold
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
                AND h.released_at IS NULL)
     LIMIT 1000                                   -- bounded batches: no long locks, resumable
)
DELETE FROM data_assets WHERE id IN (SELECT id FROM eligible);
-- ON DELETE CASCADE removes extracted_entities in the same statement.
-- Same transaction: the audit record of what was purged, and the Transactional Outbox
-- row for the purge event — the projector then removes the AGE vertices and search docs.
```

Note what the batch boundary buys: each 1000-row batch commits its deletions *with* its audit record, so a sweep interrupted halfway leaves no unaudited deletion and simply resumes.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Every category has a rule | Period + basis + disposal method for each data category | A category with no retention decision |
| Minimisation applied | Periods are the shortest defensible duration | "Keep forever" with no justification |
| Legal hold precedence | Holds override retention and erasure; checked by every purge job | Purge jobs that ignore holds |
| Erasure uses lineage | Erasure locates all derived data via forward lineage | Erasure that only deletes the primary record |
| All stores covered | Disposal specified for DB, graph, projections, events, search, backups | Primary table purged while copies persist |
| Backups addressed | Crypto-shredding for immutable backups | Backups ignored, leaving erased data recoverable |
| Disposal audited | Every purge/erasure writes an audit record | Deletions with no evidence trail |
| Key granularity matches erasure unit | Per-subject keys wherever subject erasure relies on crypto-shredding | Per-tenant key relied on to erase one person |

---

## Anti-Patterns

- **"Keep forever" by default.** Retention decided only for data someone remembered to ask about, with everything else accumulating indefinitely. Every category gets an explicit period and basis; unbounded retention is a justified exception, never the fallback.
- **The purge job that skips the hold check.** A sweep written before legal hold existed, never updated. Deleting held data during litigation is a compliance incident with no undo — the hold check is part of every purge job's contract from day one.
- **Erasing only the primary record.** Deleting the Person row while extracted entities, graph vertices, projections, and reports derived from that person's data survive. Erasure without forward lineage traversal is erasure theatre.
- **Erasing the proof of erasure.** Interpreting a GDPR request as "delete everything mentioning this person", including the audit trail. The audit record of what was erased and when is retained under legal obligation — you keep the proof you complied, never the erased data itself.
- **Soft delete as final state.** Rows sit at `deleted_at IS NOT NULL` forever because no hard-delete job follows the grace period. Soft-deleted data is still breached data, still discoverable data, and still in scope for every regulation — the grace period must have an end.
- **Per-tenant keys sold as per-person erasure.** Promising right-to-erasure while the finest key granularity is the tenant. When the first request arrives, the choice is shredding every customer's data in that tenant or breaking the promise. Granularity is decided before write time.
- **Backups as a blind spot.** A flawless online purge while every nightly snapshot still restores the erased data. Every disposal method states its backup story; for immutable snapshots that story is crypto-shredding.

---

## Output Format

```markdown
---
name: data-retention-policy
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Retention & Disposal Policy

## Retention Schedule
| Data category | Period | Basis | Disposal method |
|---|---|---|---|

## Legal Hold
[Trigger, scope, mechanism, lifting, precedence]

## Right to Erasure Procedure
[Step-by-step erasure flow using lineage]

## Cross-Store Disposal
| Store / artifact | Purge approach |
|---|---|

## Enforcement Jobs (handoff to platform-engineer)
| Job | Schedule | Contract |
|---|---|---|
```
