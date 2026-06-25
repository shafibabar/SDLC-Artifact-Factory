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
version: 1.0.0
phase: design
owner: data-architect
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

---

## Output Format

```markdown
---
artifact: data-retention-policy
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
