---
name: disaster-recovery-plan
description: >
  Teaches Disaster Recovery planning — the DR scope classes (data loss,
  cluster loss, region loss, tenant-stamp loss, supply-chain/registry loss)
  each with a stated and drill-measured Recovery Time Objective (RTO) and
  Recovery Point Objective (RPO), the backup inventory per store (PostgreSQL
  point-in-time recovery and logical dumps, environment/Git repos as config
  backup, Redpanda topic re-materialisation from the Transactional Outbox,
  Apache AGE rebuilt as a projection never backed up as source of truth), the
  crypto-shredding interplay that keeps backups honoring per-subject erasure,
  the restore-test discipline that makes an untested backup not a backup, and
  per-tenant DR independence. Used by the platform-engineer during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, disaster-recovery, rto, rpo, backup, restore, drill, crypto-shredding, chaos-engineering]
---

# Disaster Recovery Plan

## Purpose

A backup that has never been restored is a hope, not a capability. **Disaster Recovery (DR)** planning turns "we take backups" into a measured, tested contract: for each way the platform can lose data or availability, how long recovery takes (**Recovery Time Objective**, RTO — the maximum acceptable time to restore service) and how much data can be lost (**Recovery Point Objective**, RPO — the maximum acceptable gap between the last recoverable point and the incident). Both numbers are only real once a drill has actually measured them.

Physical multi-tenancy raises the stakes and the opportunity together: a tenant's blast radius for DR is the same as its blast radius for everything else — one tenant's incident, one tenant's restore, and nineteen others unaffected. That independence is designed in, not assumed.

---

## DR Scope Classes

| Class | What is lost | Stated RTO | Stated RPO |
|---|---|---|---|
| **Data loss** | Rows/tables within a live cluster (bad migration, accidental delete, application bug) | 1 hour | 5 minutes (PITR granularity) |
| **Cluster loss** | An entire Kubernetes cluster for one tenant stamp | 4 hours | 15 minutes (last backup + outbox replay) |
| **Region loss** | The cloud region hosting one or more tenant stamps | 24 hours | 1 hour |
| **Tenant-stamp loss** | One tenant's entire physically isolated environment | 4 hours | 15 minutes |
| **Supply-chain / registry loss** | Container registry unavailable | 8 hours (restore from mirrored artifacts) | 0 (images are immutable) |

Region loss at MVP scale is the class most likely to get an honest "not fully covered yet" — recording that gap explicitly is more useful than a plan that quietly assumes multi-region infrastructure the budget hasn't bought.

---

## Backup Inventory per Store

| Store | Backup method | RPO contribution | Notes |
|---|---|---|---|
| **PostgreSQL** | Continuous WAL archiving (PITR) + nightly `pg_dump` to object storage | 5 min | PITR is primary; logical dumps are the fallback if WAL archive is corrupted |
| **Environment repos / Git** | The Git remote itself is the backup — fully reconstructable from a clone | ~0 | Losing the repo host is a supply-chain-class incident; mitigated by a secondary Git mirror |
| **Redpanda topics** | Not backed up directly. Re-materialised by replaying the Transactional Outbox rows from PostgreSQL | Matches PostgreSQL's RPO | The outbox table, not the broker, is authoritative |
| **Apache AGE graph** | Never backed up as source of truth — rebuilt by replaying the projector against restored PostgreSQL data | 0 | The projector rebuild *is* the recovery mechanism; AGE has no independent state |
| **Elasticsearch / search index** | Same projection principle as AGE — rebuilt from PostgreSQL via the indexer | 0 | If reindex time threatens RTO at a given data volume, that is a capacity finding for the drill record |
| **Vault** (secrets) | Vault Raft snapshot, encrypted, stored separately | 15 min | Vault must come back online *before* application services at startup |
| **Container registry (GHCR)** | Signed images mirrored to a secondary registry on a schedule | N/A (immutable) | A registry failure is a pull-source problem, not a lost-artifact problem |

The unifying rule: **PostgreSQL is the one store that needs a real backup mechanism; everything else is either Git (self-backing) or a projection (rebuilt, not restored).**

---

## Crypto-Shredding Interplay

Backups must honor the same per-subject erasure guarantees as live data — a GDPR erasure that succeeds in PostgreSQL but leaves the person's data in a six-month-old backup has not erased anything.

- **PITR and logical dumps are encrypted under the same per-subject/per-tenant key hierarchy as live data.** A crypto-shred renders that subject's ciphertext unreadable in every WAL segment and every dump without selective editing — the backup does not need to be modified because the key no longer exists.
- **Key granularity is decided before the first byte is written** — a backup restored after an intervening crypto-shred correctly returns with that subject's fields unreadable. This is the correct DR behaviour, not a bug. A restore procedure that recovers an old wrapped key un-erases data the platform already promised was gone.
- **The erasure audit record is retained and restorable** — the record of what was erased is ordinary PostgreSQL data under PITR, surviving DR exactly as it survives normal operation.

---

## Restore-Test Discipline

**Untested backup ≠ backup.** A backup job running green for a year with no restore drill has validated that the job does not crash — nothing more.

| Rule | Enforcement |
|---|---|
| Every backup mechanism has a scheduled restore drill | Quarterly minimum; weekly chaos experiments provide continuous verification between drills (see below) |
| Drills restore into an isolated environment, never production | DR drill environment torn down after, mirrors dev/staging disposability |
| Drills measure, not assert | Wall-clock time from "declare disaster" to "service verified healthy" is recorded — that number *is* the RTO |
| A failed or unmeasured drill blocks the "DR complete" claim | DR restore must be executed with measured RTO/RPO before first production deploy is DR-ready |
| Drill failures escalate | A stated RTO/RPO a drill proves unachievable goes to Shafi; it is not quietly relaxed in the document |

Worked drill script, step-by-step restore order, and drill record format: `references/dr-drill-guide.md`.

---

## Continuous Fault Injection — Weekly Chaos Cadence

A quarterly drill tests the whole system against a named failure class but leaves an **89-day gap** between drills during which failure assumptions are untested. Validated architecture at the moment of a drill can silently degrade — a new dependency added, a circuit breaker misconfigured, a replica count reduced — without any mechanism to surface the regression before the next quarterly exercise.

**The Chaos Monkey model (DevOps Handbook Ch. 14)** closes this gap with a weekly cadence of small-blast-radius production experiments. Each experiment probes exactly one assumption: *this service recovers without user impact when one replica is killed*, or *this circuit breaker engages when the dependency is severed*. The goal is not to induce a widespread incident; it is to stress one specific assumption under controlled conditions.

**Every chaos experiment has four mandatory parts:**

| Part | Content |
|---|---|
| **Hypothesis** | A single, falsifiable claim: "Killing replica N of service X in tenant-acme's namespace will cause no user-visible errors because the load balancer routes to remaining replicas within 5 seconds." |
| **Blast radius controls** | Scope: one replica, one tenant namespace, one dependency path. Auto-rollback if error rate exceeds threshold; abort if any other tenant shows impact. |
| **Observation** | Error rate, latency p99, circuit-breaker state transitions, time to recovery — from OpenTelemetry traces and Prometheus metrics, not manual observation. |
| **Pass / Fail** | Pass: system behaved as the hypothesis predicted. Fail: the service did NOT recover as expected, or blast radius escaped its controls. |

A **failed experiment generates corrective action items** using the same structure as a blameless postmortem (per `incident-management`): timeline, contributing factors, corrective actions with owners and due dates. A failed weekly experiment is a near-miss surfaced cheaply; left undiscovered, it becomes a quarterly-drill failure or a real incident.

**Bridge to `go-chaos-test`:** This skill (`disaster-recovery-plan`) owns the DR strategy and experiment schedule — *what experiments to run* and *when*. The `go-chaos-test` skill owns the implementation — *how to write chaos tests in Go* using testcontainers or chaos frameworks. The DR plan defines hypothesis and blast-radius controls; `go-chaos-test` implements the executable test. Both are required; neither replaces the other.

**Quarterly drill vs. weekly chaos experiment — not interchangeable:**

| Dimension | Quarterly DR drill | Weekly chaos experiment |
|---|---|---|
| **Blast radius** | Large — full failure class (regional outage, cluster loss, data loss across a tenant) | Small — one replica, one dependency, one namespace |
| **Schedule** | Quarterly, planned, measured against RTO/RPO | Weekly, lightweight, measured against a specific hypothesis |
| **Purpose** | Prove recovery from the worst realistic failure class within stated RTO/RPO | Verify one failure assumption still holds; surface architectural drift |
| **Failure consequence** | Escalated to Shafi (RTO/RPO breach is a commitment failure) | Corrective action items (near-miss postmortem per `incident-management`) |

Both practices are necessary. The quarterly drill proves the system can survive a catastrophe. The weekly experiment proves it is not accumulating quiet fragility in the 89 days between catastrophe rehearsals.

---

## Per-Tenant DR Independence

- **One tenant's restore never touches another tenant's infrastructure.** Each tenant stamp has its own PostgreSQL instance, WAL archive, and Redpanda cluster.
- **Drills rotate through tenants, not just one reference tenant.** A large tenant's restore time can differ meaningfully from a canary tenant; the drill record shows restores across the tenant size spectrum.
- **A tenant-stamp-loss drill is the sharpest test of independence** — restoring one tenant's entire stamp while the fleet keeps running is the practical proof that physical isolation holds under the worst realistic single-tenant incident.
- **Weekly chaos experiments scope to one tenant namespace** — blast-radius controls explicitly prevent cross-tenant impact; any escape is an immediate abort condition.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Scope classes defined | Data/cluster/region/tenant-stamp/supply-chain, each with stated RTO/RPO | Single undifferentiated "we have backups" claim |
| Backup inventory complete | Every store has an explicit method | A store with no stated backup story |
| AGE/search never primary | Rebuilt from PostgreSQL via projection | Snapshotting a derived Read Model as source of truth |
| Outbox-based re-materialisation | Redpanda topics rebuilt from the Transactional Outbox | Broker-level backup treated as the event system's source of truth |
| Crypto-shred honored | Restored backups correctly show shredded subjects as unreadable | Restore procedure that recovers erased data via an old key |
| Quarterly drills with records | Every mechanism has a measured drill; failed drills documented; numbers are drill-derived | RTO/RPO stated as estimates with no drill evidence |
| Continuous fault injection | Weekly chaos experiments with stated hypothesis and blast-radius controls; failures become corrective actions | Quarterly drills only, 89-day gap unaddressed |
| Tenant independence | Drills and chaos experiments demonstrate isolated blast radius | Restore procedures with shared blast radius across tenants |

---

## Anti-Patterns

- **The backup nobody restored** — a nightly `pg_dump` green for a year with no restore drills is unverified; "the job succeeded" and "the data is recoverable" are different claims.
- **Backing up a projection as source of truth** — snapshotting AGE or the search index treats a cache as data, doubles storage, and risks restoring a stale projection instead of rebuilding a correct one.
- **RTO/RPO as aspirational numbers** — writing "RTO: 1 hour" with no drill evidence is a guess dressed as a commitment; the number must be what a drill measured.
- **Crypto-shred bypassed to help the restore** — recovering an old wrapped key to show a shredded subject's data is not a workaround; it un-erases data the platform promised was gone.
- **Drill environments that touch production** — restoring into a live tenant's namespace risks corrupting the very data the drill is supposed to protect.
- **One reference tenant drilled forever** — always drilling the same small canary tenant proves nothing about whether a large tenant's PITR restore fits inside the RTO.
- **Hiding failed drills** — a DR document that only records passing drills either cherry-picks or has never actually found a gap.
- **Relying on quarterly drills alone** — the 89-day gap between drills is enough time for silent architectural drift to invalidate assumptions the last drill verified; a weekly chaos cadence closes this gap.
- **Chaos experiments without hypothesis or controls** — injecting failure without a specific hypothesis produces noise; without blast-radius controls a small experiment can become a real incident.

Output format template and artifact schema: `references/dr-drill-guide.md`.
