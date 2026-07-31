# DR Drill Guide — Worked Examples, Record Formats, and Output Template

Reference material for `disaster-recovery-plan`. Load this document when:
- Authoring a drill script for a specific failure class
- Filling in a drill record after a completed exercise
- Designing a weekly chaos experiment schedule
- Producing the final DR plan artifact for a product

---

## Quarterly Drill — Worked Script (Data-Loss Class)

This shell script outline covers the data-loss class for `tenant-acme`. It is not the full runbook (see `runbook-authoring` for the per-step runbook); it is the driver that orchestrates the restore sequence and measures elapsed time.

```bash
#!/usr/bin/env bash
# dr-drill-data-loss-tenant-acme.sh
# Quarterly data-loss DR drill for the compliance-engine platform.
# Usage: bash dr-drill-data-loss-tenant-acme.sh [--target-time "2026-07-20T09:00:00Z"]
set -euo pipefail

DRILL_TS=$(date -u +%FT%TZ)
TARGET_TIME="${1:-$(date -u -d '10 minutes ago' +%FT%TZ)}"
DRILL_TENANT="acme-drill"   # never the real tenant namespace
DRILL_DIR="infra/tenant-stamp"

echo "=== DR Drill Start: $DRILL_TS ==="
echo "Class:       data-loss"
echo "Tenant:      tenant-acme (restoring into $DRILL_TENANT)"
echo "Target time: $TARGET_TIME"
echo ""

# ── Step 1: Provision isolated restore target ──────────────────────────────
# Never restore into the live tenant namespace — provision a disposable copy.
echo "[1/7] Provisioning isolated drill environment..."
tofu -chdir="$DRILL_DIR" apply \
  -var tenant="$DRILL_TENANT" \
  -var mode=restore-only \
  -auto-approve
echo "      Done."

# ── Step 2: PostgreSQL PITR restore ────────────────────────────────────────
# Restore to TARGET_TIME using WAL archive. The logical dump is the fallback
# if the WAL archive is unavailable (corrupted, not yet promoted).
echo "[2/7] Restoring PostgreSQL to $TARGET_TIME..."
pg_basebackup \
  --pgdata=/var/lib/postgresql/data-drill \
  --wal-method=stream \
  --target-time="$TARGET_TIME" \
  --host=wal-archive.internal \
  --username=replication \
  --no-password
echo "      Done."

# ── Step 3: Replay Transactional Outbox onto fresh Redpanda topics ─────────
# The outbox table (now restored in PostgreSQL) is the source of truth for
# what events should exist. The broker is rebuilt from it, never the other way.
echo "[3/7] Replaying Transactional Outbox to re-materialise Redpanda topics..."
go run ./cmd/outbox-replay \
  --tenant="$DRILL_TENANT" \
  --since="$TARGET_TIME" \
  --broker=redpanda-drill.internal:9092
echo "      Done."

# ── Step 4: Rebuild projections from restored PostgreSQL ───────────────────
# AGE graph and Elasticsearch index are Read Models — they are rebuilt from
# PostgreSQL aggregate data and domain events, never restored from snapshots.
echo "[4/7] Rebuilding projections (AGE graph, search index)..."
go run ./cmd/projector-rebuild \
  --tenant="$DRILL_TENANT" \
  --targets=age,elasticsearch \
  --postgres-dsn="postgres://drill-user@pg-drill.internal/drill-db"
echo "      Done."

# ── Step 5: Bring Vault online for the drill environment ───────────────────
# Application services depend on Vault for credentials at startup.
# Vault must be restored and unsealed before services are started.
echo "[5/7] Restoring and unsealing Vault..."
vault operator raft snapshot restore \
  --force \
  /var/lib/vault/snapshots/latest-drill.snap
vault operator unseal "$VAULT_UNSEAL_KEY"
echo "      Done."

# ── Step 6: Run smoke suite against restored stamp ────────────────────────
echo "[6/7] Running smoke tests against $DRILL_TENANT..."
go test ./e2e/... \
  -tags smoke \
  -tenant="$DRILL_TENANT" \
  -timeout 10m
echo "      Done."

# ── Step 7: Verify crypto-shred correctness ────────────────────────────────
# Subjects whose keys were shredded before TARGET_TIME must be unreadable
# in the restored data. This is the expected pass — data un-erased by
# restoring an old key is a security defect, not a successful restore.
echo "[7/7] Verifying crypto-shred consistency..."
go run ./cmd/verify-shred-consistency \
  --tenant="$DRILL_TENANT" \
  --as-of="$TARGET_TIME"
echo "      Done."

DRILL_END=$(date -u +%FT%TZ)
echo ""
echo "=== DR Drill End: $DRILL_END ==="
echo "Record the measured elapsed time from $DRILL_TS to $DRILL_END in the drill record."
echo ""

# ── Teardown ───────────────────────────────────────────────────────────────
# Never leave drill infrastructure running — it incurs cost and can cause
# confusion if mistaken for a real tenant environment.
echo "Tearing down drill environment..."
tofu -chdir="$DRILL_DIR" destroy \
  -var tenant="$DRILL_TENANT" \
  -auto-approve
echo "Teardown complete."
```

### Step Order Rationale

The sequence above is not arbitrary. Dependencies constrain the order:

1. **Infrastructure first** — PostgreSQL, Redpanda, and Vault all need network endpoints before any application-layer step can address them.
2. **Vault before application services** — application services request credentials from Vault at startup. If Vault is not running and unsealed, service startup fails.
3. **PostgreSQL before outbox replay** — the outbox table lives in PostgreSQL; it must be restored before the replay reads from it.
4. **Outbox replay before projector rebuild** — the projector reads domain events from Redpanda; topics must exist before the projector can consume them.
5. **Projections before smoke tests** — the smoke suite exercises the full read path including the AGE graph and search; projections must be complete for reads to succeed.
6. **Crypto-shred verification last** — this is a correctness check on the restored state, not a prerequisite for any subsequent step.

---

## Drill Record Format

Append one row per drill to the drill record table in the product's DR plan document. **Do not omit failed or breached drills** — the record is only useful if it is honest.

| Date | Class drilled | Tenant | Declared incident | Service verified | Measured RTO | Data recovered up to | Measured RPO | Vault-first order followed | Result |
|---|---|---|---|---|---|---|---|---|---|
| 2026-07-20 | Data loss | tenant-acme | 09:02Z | 09:41Z | 39 min (target: 1h) | 08:57Z (5 min before drill) | 5 min (met) | Yes | Pass |
| 2026-04-18 | Cluster loss | tenant-canary | 14:10Z | 17:55Z | 3h 45m (target: 4h) | 13:58Z | 12 min (met) | Yes | Pass — projector rebuild was the slowest step; noted for capacity review |
| 2026-01-15 | Tenant-stamp loss | tenant-globex | 10:00Z | 15:20Z | 5h 20m (**breach** — target: 4h) | 09:52Z | 8 min (met) | Yes | **Fail** — escalated to Shafi; OpenTofu apply time was the bottleneck; module parallelism increased before next drill |

The failed drill in the record is not hidden — a DR document with only passing drills is either lucky or dishonest. The January breach is exactly the kind of finding this discipline exists to surface before a real incident does.

**After a breached drill:**
1. Open a corrective action item (owner + due date) immediately.
2. Do not update the stated RTO/RPO target downward without Shafi's approval.
3. Run the corrective action to completion.
4. Schedule a re-drill of the same class within 30 days to verify the fix.

---

## Weekly Chaos Experiment Log

Record each weekly experiment in a separate log (or a section of the DR document). Format:

| Date | Service | Assumption tested | Hypothesis | Blast radius controls | Observed behavior | Pass / Fail | Corrective action (if Fail) |
|---|---|---|---|---|---|---|---|
| 2026-07-28 | compliance-api | Replica failure recovery | Killing one of three replicas causes no user-visible errors within 5s | One replica in tenant-acme namespace only; abort if p99 > 2s for other tenants | Load balancer rerouted within 3s; no 5xx in Prometheus | Pass | — |
| 2026-07-21 | data-ingestor | Circuit breaker on dependency timeout | Severing upstream-registry dependency causes circuit breaker to open within 2 failures | One dependency path in tenant-beta; rollback if error rate > 5% | Circuit breaker opened after 3 failures (not 2); 12s of elevated errors before open | Fail | Issue #89: circuit breaker threshold misconfigured (open.after=3 instead of 2); fix deployed 2026-07-22 |

**Fail entry treatment:** A failed experiment follows the same corrective-action structure as a blameless postmortem — timeline, contributing factors, corrective actions with owners and due dates. The entry in the log is permanent; the corrective action is tracked separately. Do not delete or overwrite failed entries.

### Designing the Weekly Experiment Schedule

Map experiments to the DR scope classes to ensure coverage over a rolling eight-week window:

| Week | Assumption family | Example experiment |
|---|---|---|
| 1 | Replica failure (data-loss class) | Kill one replica of the highest-traffic service; verify load balancer reroutes within SLO |
| 2 | Circuit breaker (cluster-loss class dependency) | Sever one downstream dependency; verify circuit breaker opens and fallback activates |
| 3 | Outbox replay (data-loss class) | Pause Redpanda consumer; verify outbox accumulates and replays without message loss on resume |
| 4 | Vault credential rotation (all classes) | Rotate a service account secret in Vault; verify the service re-fetches without restart |
| 5 | Projector catchup (cluster-loss class) | Pause the AGE projector; resume; verify it catches up from the last consumed event offset |
| 6 | Cross-tenant isolation | Inject a synthetic error in tenant-acme's pod; verify tenant-beta is unaffected |
| 7 | WAL archive availability | Simulate WAL archive slowness; verify monitoring alerts before the PITR window shrinks below RPO |
| 8 | Registry mirror failover | Point image pulls at the secondary registry; verify services start from mirrored images |

Rotate and extend this schedule as new services and dependencies are added. An assumption that has not been exercised in eight weeks is an untested assumption.

---

## Output Format — DR Plan Artifact

Use this template to produce the disaster recovery plan artifact for a product. Every section is required; "Open Gaps" is where honest coverage gaps live.

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

| Class | Stated RTO | Stated RPO | Architecture basis | Last drilled | Measured RTO | Measured RPO |
|---|---|---|---|---|---|---|
| Data loss | 1h | 5 min | PITR + outbox replay | [date] | [measured] | [measured] |
| Cluster loss | 4h | 15 min | PITR + outbox replay + projector rebuild | [date] | [measured] | [measured] |
| Region loss | 24h | 1h | Cross-region backup + GitOps reconciliation | [date or "not yet drilled"] | — | — |
| Tenant-stamp loss | 4h | 15 min | OpenTofu re-apply + PITR | [date] | [measured] | [measured] |
| Supply-chain / registry | 8h | 0 | Secondary registry mirror | [date] | [measured] | — |

## Backup Inventory

| Store | Method | RPO contribution | Restore mechanism | Last restore-tested |
|---|---|---|---|---|
| PostgreSQL | WAL PITR + nightly pg_dump | 5 min | pg_basebackup + WAL replay | [date] |
| Git / environment repos | Git remote clone | ~0 | tofu apply from clean clone | [date] |
| Redpanda topics | Outbox replay from PostgreSQL | Matches PG RPO | outbox-replay cmd | [date] |
| Apache AGE | Projector rebuild | 0 | projector-rebuild cmd | [date] |
| Elasticsearch | Projector rebuild | 0 | projector-rebuild cmd | [date] |
| Vault | Raft snapshot | 15 min | vault raft snapshot restore | [date] |
| GHCR images | Secondary registry mirror | N/A | Update image pull secret to mirror | [date] |

## Crypto-Shredding Interplay

Active crypto-shred records as of [date]: [N] subjects in [M] tenants.

Restore procedure correctly leaves shredded subjects unreadable — this is verified by the `verify-shred-consistency` step in every drill (step 7 in the drill script). A restore that shows shredded data readable is a security defect, not a successful restore.

Key hierarchy: [per-subject / per-tenant — reference the data-retention-policy decision here]

## Restore Procedures

Per class, step-by-step — each step references its runbook (see `runbook-authoring`):

- **Data loss:** [link to runbook or inline steps]
- **Cluster loss:** [link to runbook]
- **Region loss:** [link to runbook or "not yet authored — gap, see Open Gaps"]
- **Tenant-stamp loss:** [link to runbook]
- **Supply-chain / registry:** [link to runbook]

Restore step order (always): infrastructure → Vault → PostgreSQL → outbox replay → projector rebuild → application services → smoke tests → crypto-shred verification.

## Drill Schedule and Record

Quarterly drills:
[Drill record table — include failed/breached drills. See references/dr-drill-guide.md for format.]

Weekly chaos experiment schedule:
[Eight-week rolling schedule. See references/dr-drill-guide.md for per-week template.]

Weekly chaos experiment log:
[Log table — include failed experiments. See references/dr-drill-guide.md for format.]

## Per-Tenant Independence Evidence

- Tenant restore procedures are scoped to a single tenant namespace; no shared infrastructure is modified.
- Drills completed across the following tenants: [list tenant names + class drilled]
- Largest tenant drilled: [tenant name, data volume at time of drill, measured restore time]
- Drill demonstrating independence (tenant-stamp-loss class): [date, tenant, result — other tenants unaffected confirmed by monitoring during drill window]

## Open Gaps

[Every scope class not yet drilled, not yet achievable at current architecture, or with a known breach:
- Region loss: cross-region infrastructure not yet provisioned at MVP scale — escalated to Shafi 2026-07-20.
- Cluster loss: region-loss-class runbook not yet authored.
- Any breached drill: reference the corrective action item and re-drill date.]

## Traceability

- RTO/RPO targets derived from NFR-[ID] (product requirements)
- Physical isolation model: `multi-tenancy-design`
- Erasure contract: `data-retention-policy`
- Drill scripts: `references/dr-drill-guide.md`
- Chaos experiment implementation: `go-chaos-test` skill
- Blameless postmortem structure for failed experiments: `incident-management` skill
```
