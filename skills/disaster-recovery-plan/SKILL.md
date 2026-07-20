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
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, disaster-recovery, rto, rpo, backup, restore, drill, crypto-shredding]
---

# Disaster Recovery Plan

## Purpose

A backup that has never been restored is a hope, not a capability. **Disaster Recovery (DR)** planning turns "we take backups" into a measured, tested contract: for each way the platform can lose data or availability, how long recovery takes (**Recovery Time Objective**, RTO — the maximum acceptable time to restore service) and how much data can be lost (**Recovery Point Objective**, RPO — the maximum acceptable gap between the last recoverable point and the incident). Both numbers are only real once a drill has actually measured them.

Physical multi-tenancy raises the stakes and the opportunity together: a tenant's blast radius for DR is the same as its blast radius for everything else — one tenant's incident, one tenant's restore, and nineteen others unaffected. That independence is designed in, not assumed.

---

## DR Scope Classes

Not every failure is the same shape. Each class gets its own stated RTO/RPO, because conflating them either wastes effort protecting against an unlikely region loss at the cost of the everyday data-loss case, or leaves the platform assuming a region-loss recovery it never actually built.

| Class | What is lost | Typical cause | Stated RTO | Stated RPO |
|---|---|---|---|---|
| **Data loss** | Rows/tables within a live cluster (bad migration, accidental delete, application bug) | Human or code error | 1 hour | 5 minutes (PITR granularity) |
| **Cluster loss** | An entire Kubernetes cluster (control plane or nodes) for one tenant stamp | Infra fault, botched upgrade | 4 hours | 15 minutes (last successful backup + outbox replay) |
| **Region loss** | The cloud region hosting one or more tenant stamps | Provider-level outage | 24 hours | 1 hour |
| **Tenant-stamp loss** | One tenant's entire physically isolated environment (namespace, DB, broker) | Deletion, corrupted OpenTofu apply, credential compromise | 4 hours | 15 minutes |
| **Supply-chain / registry loss** | Container registry (GHCR) or artifact provenance unavailable | Vendor outage, credential revocation | 8 hours (restore from mirrored artifacts) | 0 (images are immutable and content-addressed; nothing to lose but availability) |

Region loss at MVP scale is the class most likely to get an honest "not fully covered yet" — recording that gap explicitly (with the escalation to Shafi per the agent's rules) is more useful than a plan that quietly assumes multi-region infrastructure the budget hasn't bought.

---

## Backup Inventory per Store

Every store the platform depends on has an explicit backup story — "we didn't think about that store" is the actual disaster, discovered mid-incident.

| Store | Backup method | RPO contribution | Notes |
|---|---|---|---|
| **PostgreSQL** (per-tenant, physically isolated) | Continuous WAL archiving for Point-in-Time Recovery (PITR) + nightly logical dump (`pg_dump`) to object storage | 5 min (PITR) | PITR is the primary mechanism; logical dumps are the fallback if the WAL archive itself is corrupted |
| **Environment repos / Git** | The Git remote itself is the backup — every environment's desired state (`environment-config`, `cd-pipeline`) is fully reconstructable from a repository clone | Effectively 0 — Git history is the record | A cluster with a healthy Git remote can always be re-reconciled from scratch; losing the repo host itself is a supply-chain-class incident, mitigated by a secondary Git mirror |
| **Redpanda topics** | **Not backed up directly as a bulk snapshot.** Re-materialised by replaying the **Transactional Outbox** rows in PostgreSQL (which are themselves under PITR) back onto fresh topics | Matches PostgreSQL's RPO, because the outbox table is the source of truth for "what events should exist" | Topic retention already bounds how much needs re-publishing; the outbox table, not the broker, is authoritative |
| **Apache AGE graph** | **Never backed up as source of truth.** The graph is a **Read Model** projection derived from PostgreSQL Aggregate data and Domain Events; DR rebuilds it by replaying the projector against restored PostgreSQL data | 0 — the graph has no independent state to lose | Backing up AGE snapshots would be backing up a cache; the projector rebuild *is* the recovery mechanism, and it must be drilled like any other restore |
| **Elasticsearch / search index** | Same projection principle as AGE — rebuilt from PostgreSQL via the indexer, not independently backed up | 0 | If reindex time from a cold restore threatens the RTO for a given tenant's data volume, that is a capacity finding for the drill record, not a reason to start snapshotting a derived index |
| **Vault** (secrets) | Vault's own backend (Raft) snapshot, encrypted, stored separately from application backups | 15 min | Owned jointly with `security-engineer`; DR restore order requires Vault back online *before* application services, since they depend on it for credentials at startup |
| **Container registry (GHCR)** | Signed images mirrored to a secondary registry on a schedule | N/A (immutable content) | Protects the supply-chain class; the OpenTofu/Helm definitions that reference digests are themselves in Git, so a registry failure is a pull-source problem, not a lost-artifact problem |

The unifying rule: **PostgreSQL is the one store that needs a real backup mechanism; everything else is either Git (self-backing) or a projection (rebuilt, not restored).** This keeps the DR surface area small and testable rather than multiplying bespoke backup jobs per technology.

---

## Crypto-Shredding Interplay

Backups must honor the same per-subject erasure guarantees as live data — a GDPR erasure that succeeds in PostgreSQL but leaves the person's data recoverable from a six-month-old backup has not actually erased anything. This is `data-retention-policy`'s crypto-shredding contract, extended to the backup layer:

- **PITR and logical dumps are encrypted under the same per-subject/per-tenant key hierarchy as the live data.** A crypto-shred (destroying a subject's key, or a tenant's key on offboarding) renders that subject's data unreadable in *every* WAL segment and every dump that contains it — the backup does not need to be edited or replayed selectively, because the ciphertext everywhere already depends on a key that no longer exists.
- **This is why key granularity is decided before the first byte is written** (per `data-retention-policy`): a backup restored from six months ago, after an intervening crypto-shred, correctly comes back with that subject's fields unreadable — which is the *correct* DR behaviour, not a bug to work around. A restore procedure that "fixes" this by restoring an old, unwrapped key would violate the erasure the platform already promised the subject.
- **The erasure audit record itself is retained and restorable** — `data-retention-policy`'s rule that the record of what was erased survives applies through DR exactly as through normal operation; the audit trail is ordinary PostgreSQL data under PITR like everything else in that category.

DR restore procedures document this explicitly per tenant: "this tenant has N subjects with active crypto-shred records as of the last backup; restoring to point-in-time T will correctly show those subjects as unreadable if the shred occurred before T."

---

## Restore-Test Discipline

**Untested backup ≠ backup.** A backup job that has run successfully for a year with no restore drill has validated exactly one thing: that the job doesn't crash. It has validated nothing about whether the resulting artifact can rebuild a working system, whether the RTO is achievable, or whether the RPO claim is true.

| Rule | Enforcement |
|---|---|
| Every backup mechanism has a scheduled restore drill | Quarterly minimum; more frequent for the classes most likely to occur (data loss, cluster loss) |
| Drills restore into an isolated environment, never production | A DR drill environment, torn down after, mirrors `environment-config`'s dev/staging disposability |
| Drills measure, not assert | Wall-clock time from "declare disaster" to "service verified healthy" is recorded — that number *is* the RTO, replacing whatever was estimated on paper |
| A failed or unmeasured drill blocks the "DR complete" claim | Per the platform-engineer's completion criteria: DR restore must be executed with measured RTO/RPO before first production deploy is considered DR-ready |
| Drill failures escalate | Per the agent's escalation rules — a stated RTO/RPO that a drill proves unachievable with the current backup architecture goes to Shafi, it is not quietly relaxed in the document |

---

## Per-Tenant DR Independence

Physical multi-tenancy's isolation guarantee extends to DR by construction, and the plan states it explicitly rather than leaving it implied:

- **One tenant's restore never touches another tenant's infrastructure.** Each tenant stamp has its own PostgreSQL instance, its own WAL archive, its own Redpanda cluster — restoring `tenant-acme` from backup is an operation entirely scoped to `tenant-acme`'s namespace and data stores (`multi-tenancy-design`'s isolation boundary).
- **Drills rotate through tenants, not just one reference tenant.** A drill that only ever restores the canary tenant proves the mechanism works for that tenant's data volume and shape; a large tenant's restore time can differ meaningfully, and the drill record should show restores exercised across the tenant size spectrum over time.
- **A tenant-stamp-loss drill is the sharpest test of independence** — restoring one tenant's entire stamp from OpenTofu + backups while the rest of the fleet keeps running, unaffected, is the practical proof that physical isolation holds under the worst realistic single-tenant incident.

---

## Worked Example — Drill Script Outline and Drill Record

Quarterly data-loss-class drill for `compliance-engine`'s tenant-acme data:

```bash
#!/usr/bin/env bash
# dr-drill-data-loss-tenant-acme.sh — outline, not the full runbook (see runbook-authoring)
set -euo pipefail

DRILL_TS=$(date -u +%FT%TZ)
echo "Drill start: $DRILL_TS"

# 1. Provision an isolated restore target (never production)
tofu -chdir=infra/tenant-stamp apply -var tenant=acme-drill -var mode=restore-only

# 2. Restore PostgreSQL to a chosen point-in-time (simulating "5 minutes before the incident")
TARGET_TIME=$(date -u -d '10 minutes ago' +%FT%TZ)
pg_basebackup --target-time="$TARGET_TIME" ...   # PITR restore into acme-drill

# 3. Replay the Transactional Outbox to re-materialise Redpanda topics
go run ./cmd/outbox-replay --tenant=acme-drill --since="$TARGET_TIME"

# 4. Rebuild projections (AGE graph, search index) from restored PostgreSQL
go run ./cmd/projector-rebuild --tenant=acme-drill --targets=age,elasticsearch

# 5. Verify: run the smoke subset against the restored stamp
go test ./e2e/... -tags smoke -tenant=acme-drill

# 6. Verify crypto-shred correctness: confirm subjects shredded before TARGET_TIME
#    are unreadable in the restored data (expected pass, not a failure)
go run ./cmd/verify-shred-consistency --tenant=acme-drill --as-of="$TARGET_TIME"

DRILL_END=$(date -u +%FT%TZ)
echo "Drill end: $DRILL_END — measured restore time above"

tofu -chdir=infra/tenant-stamp destroy -var tenant=acme-drill   # never leave drill infra running
```

Drill record, appended to the DR document after every run:

| Date | Class drilled | Tenant | Declared incident → service verified | Measured RTO | Data recovered up to | Measured RPO | Result |
|---|---|---|---|---|---|---|---|
| 2026-07-20 | Data loss | tenant-acme | 09:02 → 09:41 | 39 min (within 1h target) | 08:57 (5 min before drill start) | 5 min (met) | Pass |
| 2026-04-18 | Cluster loss | tenant-canary | 14:10 → 17:55 | 3h 45m (within 4h target) | 13:58 | 12 min (met) | Pass — projector rebuild was the slowest step; noted for capacity review |
| 2026-01-15 | Tenant-stamp loss | tenant-globex | 10:00 → 15:20 | 5h 20m (**breach** — 4h target) | 09:52 | 8 min (met) | Fail — escalated to Shafi; OpenTofu apply time was the bottleneck, module parallelism increased before next drill |

The failed drill in the record is not hidden — a DR document with only passing drills is either lucky or dishonest, and the January breach is exactly the kind of finding this discipline exists to surface before a real incident does.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Scope classes defined | Data/cluster/region/tenant-stamp/supply-chain, each with stated RTO/RPO | Single undifferentiated "we have backups" claim |
| Backup inventory complete | Every store (PostgreSQL, Git, Redpanda, AGE, search, Vault, registry) has an explicit method | A store with no stated backup story |
| AGE/search never primary | Rebuilt from PostgreSQL via projection, never independently backed up as source of truth | Snapshotting a derived Read Model as if it were authoritative |
| Outbox-based re-materialisation | Redpanda topics rebuilt from the Transactional Outbox, not bulk broker snapshots | Broker-level backup treated as the event system's source of truth |
| Crypto-shred honored | Restored backups correctly show shredded subjects as unreadable | Restore procedure that recovers erased data via an old key |
| Restore-tested | Every mechanism has a scheduled, measured drill; numbers are drill-derived | RTO/RPO stated as estimates with no drill evidence |
| Drill record kept | Dated table including failed/breached drills, with escalation | Only passing drills documented, or no record at all |
| Tenant independence | Drills demonstrate one tenant's restore does not touch others | Restore procedures with shared blast radius across tenants |

---

## Anti-Patterns

- **The backup nobody restored** — a nightly `pg_dump` running green in a cron job for a year with zero restore drills is unverified until it is tested; "the job succeeded" and "the data is recoverable" are different claims.
- **Backing up a projection as if it were source of truth** — snapshotting the AGE graph or the search index treats a cache as data, doubles storage for no recovery benefit, and risks restoring a *stale* projection instead of rebuilding a *correct* one from PostgreSQL.
- **RTO/RPO as aspirational numbers** — writing "RTO: 1 hour" in a document with no drill evidence is a guess dressed as a commitment; the number in the plan must be the number a drill measured, updated when drills change it.
- **Crypto-shred bypassed "to help the restore"** — recovering an old wrapped key so a restored backup shows a shredded subject's data again is not a helpful workaround, it is un-erasing data the platform promised was gone. The correct restore leaves shredded data unreadable.
- **Drill environments that touch production** — restoring into a live tenant's namespace "to save the OpenTofu apply time" risks corrupting the very data the drill is supposed to protect. Isolated, disposable drill infrastructure only.
- **One reference tenant drilled forever** — always drilling the same small canary tenant proves nothing about whether a large tenant's PITR restore or projector rebuild fits inside the RTO. Rotate tenant size and class coverage.
- **Hiding failed drills** — a DR document that only ever records passing drills either cherry-picks or has never actually found a gap, and gaps found in a real incident are far more expensive than gaps found in a drill.

---

## Output Format

Produces the disaster recovery plan and drill record for a product:

```markdown
---
name: disaster-recovery-plan-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Disaster Recovery Plan — [product]

## Scope Classes
| Class | Stated RTO | Stated RPO | Last drilled measured RTO/RPO |

## Backup Inventory
| Store | Method | RPO contribution | Restore mechanism |

## Crypto-Shredding Interplay
[How backups honor per-subject/per-tenant erasure; verification step in drills]

## Restore Procedures
[Per class: step-by-step, referencing runbook-authoring's per-procedure runbooks]

## Drill Schedule and Record
| Date | Class | Tenant | Declared → verified | Measured RTO | Measured RPO | Result |

## Per-Tenant Independence Evidence
[Drills demonstrating isolated blast radius]

## Open Gaps
[Any scope class not yet drilled or not achievable at current architecture — escalated to Shafi]

## Traceability
[NFR IDs behind RTO/RPO targets; multi-tenancy-design isolation model; data-retention-policy erasure contract]
```
