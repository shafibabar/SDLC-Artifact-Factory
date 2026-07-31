---
name: data-retention-policy
description: >
  Define a data-retention policy — retention rules by data class (a retention
  window per class), the deletion mechanics (soft vs hard delete, verifiable
  and cryptographic deletion), the legal-hold override, and archival vs
  deletion. Match a data class to a window and a disposition; decide soft
  delete versus hard delete; require verifiable deletion for PII; make
  legal hold take precedence over the retention window; choose archival
  (cold-tier retain) versus disposal. Integrates with privacy-design PII
  lifecycle retain/destroy stages and with data-classification. Used during
  Design for any dataset holding regulated or personal data — audit logs,
  extracted entities, data-asset records, personal data, event payloads.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
related:
  - data-classification
  - privacy-design
  - data-lineage-design
  - compliance-design
  - zero-trust-design
  - event-schema-design
tags: [design, data-governance, retention, deletion, legal-hold, archival, pii]
---

# Data Retention Policy

## Purpose

Data has a lifecycle: created, used, then disposed. Keeping data longer than
necessary increases breach exposure and regulatory liability; deleting it too
soon breaks audit and compliance obligations. A retention policy makes the
lifecycle explicit and enforceable — for each **data class**, how long it is
kept, why, and how it is destroyed.

This is a **Data Management** deliverable in DAMA-DMBOK terms: a concrete rule
set enacting a policy decision. It turns the outputs of `data-classification`
(what class/sensitivity data is) and `data-lineage-design` (where derived data
came from) into rules that platform purge jobs enforce and that
`compliance-design` can evidence. It implements the retain/destroy stages of
the `privacy-design` PII lifecycle.

---

## The Core Artifact: Retention Window by Data Class

Every data class gets one rule — a **retention window**, a legal/operational
**basis**, and a **disposition** (what happens when the window elapses).
"Keep forever" is a decision that must be justified, never a default.

| Data class | Window | Basis | Disposition |
|---|---|---|---|
| Audit log | 7 years | SOC 2 / regulatory evidence | Hard delete after window; cold-tier while aging |
| Compliance report | 7 years | Audit evidence | Hard delete after window |
| Data-asset record | Source disconnect + grace | Operational | Soft delete → hard delete after grace |
| Extracted entity metadata | Life of the data asset | Operational | Cascade-deleted with the asset |
| Personal data (PII) | Minimum for purpose; erasable | GDPR purpose limitation + Art. 17 | Verifiable deletion (see references) |
| Raw file content | **Not retained** | Privacy by design | Never stored — nothing to dispose |
| Operational telemetry | 30–90 days | Operations | Rolling deletion |

**Principle — minimisation applied to time:** the window is the *shortest*
defensible duration that satisfies the basis. How a class maps to a window,
the full worked schedule, the regulatory drivers, and the artifact template:
**`references/retention-schedule.md`**.

---

## Deletion Mechanics: Soft vs Hard vs Verifiable

| Method | What it does | Use when |
|---|---|---|
| **Soft delete** | Set a `deleted_at` tombstone; row hidden, still present | A reversible grace window before hard delete |
| **Hard delete** | Physically remove the row; cascade to children | Window elapsed; no hold; no erasure conflict |
| **Verifiable / cryptographic deletion** | Render the data provably unrecoverable everywhere it reached | PII erasure, and anything in immutable backups |

**Soft delete is never a final state** — every soft delete must have a
hard-delete job behind it; a tombstone that never advances is still breached,
discoverable, in-scope data.

**PII requires *verifiable* deletion.** For a regulated dataset it is not enough
to `DELETE` the primary row — the policy must be able to prove the data is
unrecoverable across PostgreSQL, the Apache AGE graph, projections, the
Elasticsearch index, Redpanda event payloads, **and backups**. Immutable backup
snapshots cannot be edited row-by-row, so the mechanism there is destroying the
encryption key. The full technique, key granularity, cross-store cascade, and
the deletion audit-evidence record: **`references/deletion-mechanics.md`**.

Deletion follows lineage. Erasing a subject means forward-traversing
`data-lineage-design` to find every derived artifact, then applying each class's
disposition — not deleting the primary record and calling it done.

---

## Legal Hold Overrides the Window

A legal hold **suspends deletion**: data under hold is not deleted even when its
retention window elapses, until the hold is lifted.

**Precedence — this ordering is absolute:**

```
legal hold  >  retention window  >  erasure request
```

A purge job that ignores the hold check is a compliance defect with no undo —
deleting held data during litigation cannot be reversed. The hold check is part
of every purge job's contract from day one, not an afterthought. Hold trigger,
scope (found via lineage), mechanism, the hold lifecycle, and how holds interact
with erasure requests: **`references/legal-hold-and-archival.md`**.

---

## Archival vs Deletion

Reaching the end of an *access* need is not the same as reaching the end of a
*retention* need. Data that is still within its window but rarely accessed —
audit logs past 90 days but short of their 7-year disposal date — is an
**archival** candidate: move it to a cheaper cold storage tier, retained and
retrievable, distinct from and prior to the eventual disposal decision. This is
a FinOps cost lever, not a compliance one; archival never shortens a window and
never substitutes for deletion. Tiers, retrieval latency/cost trade-offs, and
the window interplay: **`references/legal-hold-and-archival.md`**.

---

## Ties to Adjacent Skills

- **`data-classification`** supplies the classes this policy assigns windows to;
  a new class with no retention rule is an incomplete classification.
- **`privacy-design`** owns the PII lifecycle stages; this policy implements its
  retain and destroy stages with concrete windows and verifiable deletion.
- **`data-lineage-design`** is what makes both erasure and hold *scoping*
  possible — you can only delete or hold everywhere data reached if you can
  trace where it went.
- **`zero-trust-design`** supplies the per-tenant/per-subject encryption keys
  that verifiable deletion of backups depends on.
- **`compliance-design`** consumes the audit evidence this policy produces.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Every class has a rule | Window + basis + disposition per class | A class with no retention decision |
| Minimisation applied | Windows are the shortest defensible duration | "Keep forever" with no justification |
| Legal hold precedence | Holds override window and erasure; checked by every purge job | Purge jobs that skip the hold check |
| Deletion follows lineage | Erasure locates all derived data via forward lineage | Deleting only the primary record |
| All stores covered | Disposition specified for DB, graph, projections, events, search, backups | Primary table purged while copies persist |
| Backups addressed | Verifiable (key-destruction) deletion for immutable snapshots | Backups ignored, erased data still restorable |
| Disposal audited | Every purge/erasure writes an audit record | Deletions with no evidence trail |
| Archival ≠ deletion | Cold-tiering is a cost lever separate from the disposal date | Archival treated as satisfying erasure |

---

## Anti-Patterns

- **"Keep forever" by default.** Every class gets an explicit window and basis;
  unbounded retention is a justified exception, never the fallback.
- **The purge job that skips the hold check.** Deleting held data during
  litigation is a compliance incident with no undo.
- **Erasing only the primary record.** Leaving derived entities, graph vertices,
  projections, and reports alive is erasure theatre.
- **Erasing the proof of erasure.** The audit record of *what* was erased and
  *when* is retained under legal obligation — you keep the proof, never the data.
- **Soft delete as final state.** A tombstone with no hard-delete job behind it
  is still in scope for every regulation.
- **Archival mistaken for disposal.** Cold-tiering data past its access need does
  not satisfy an erasure obligation — the window still governs.

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

## Retention Schedule (window by data class)
| Data class | Window | Basis | Disposition |
|---|---|---|---|

## Legal Hold
[Trigger, scope, mechanism, lifecycle, precedence]

## Deletion & Erasure Procedure
[Soft/hard/verifiable choice per class; lineage-driven erasure flow]

## Cross-Store Disposal
| Store / artifact | Purge approach |
|---|---|

## Archival Tiers
| Class | Cold-tier trigger | Retrieval SLA |
|---|---|---|

## Enforcement Jobs (handoff to platform-engineer)
| Job | Schedule | Contract |
|---|---|---|
```

Full templates, worked examples, SQL, and regulatory mapping live in
`references/`.
