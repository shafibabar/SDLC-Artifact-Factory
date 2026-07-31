# Strategy Selection Guide — Progressive Delivery

Self-contained reference. Use alongside `progressive-delivery/SKILL.md` which names the four strategies.
This file provides the full decision matrix, tie-breaker rules, and worked examples per bounded context type.

---

## Full Decision Matrix

The rows represent the service's structural characteristics. The columns gate from left to right — a "No" in any column eliminates that strategy for the release.

| Service type | Schema impact | Consumer type | Instant-rollback required | Recommended strategy |
|---|---|---|---|---|
| Stateless HTTP service | None or backward-compatible | N/A | No | **Canary** (default) |
| Stateless HTTP service | None or backward-compatible | N/A | Yes | **Blue-Green** |
| Stateless HTTP service | Expand/contract in flight | N/A | No | **Canary** (after expand completes) |
| Stateless HTTP service | Non-backward-compatible cutover | N/A | No | **Blue-Green** (during cutover window) → **Canary** (after schema stable) |
| Stateless HTTP service (UI/UX change) | None | N/A | No | **Feature-Flag-Only** (if code already deployed) |
| Stateless HTTP service | None | N/A | No, high-risk behaviour | **Canary + Feature Flag** |
| Partitioned event consumer | None | Partitioned Redpanda | No | **Blue-Green** (partition offset preserved) |
| Partitioned event consumer | None | Partitioned Redpanda | Yes | **Blue-Green** |
| Non-request-driven workload (batch, CronJob) | N/A | N/A | No | **Blue-Green** |
| Non-request-driven workload | N/A | N/A | Yes | **Blue-Green** |
| Schema cutover complete, behavioral change pending | None (schema already migrated) | N/A | No | **Blue-Green + Feature Flag** |

---

## Tie-Breaker Rules

When the matrix produces two valid strategies, apply these rules in order until one strategy wins:

1. **Canary beats Blue-Green when both are valid** — canary is cheaper (no 2x capacity) and provides real traffic signal; blue-green's instant-rollback benefit only justifies the cost when instant rollback is actually required.

2. **Feature-Flag-Only beats Canary when the code is already deployed** — if the binary is already running in production and only the flag state differs, a traffic split adds no isolation value; the flag is already the precise exposure control.

3. **Blue-Green beats Canary when the consumer is partitioned** — there is no valid partial-traffic canary for a partitioned consumer group without a partition-subset assignment; the simpler correct answer is blue-green.

4. **Combination beats single strategy only when both layers serve a distinct purpose** — if the combination provides no isolation benefit that the single strategy does not, use the single strategy.

---

## Worked Examples by Bounded Context Type

### Example 1: Document Processing Service (Stateless HTTP, `estate-scanner`)

**Change**: New fingerprinting algorithm for `DocumentDiscovered` event's `content_hash` field. The new field is additive — the old field remains populated; the schema change is backward-compatible (expand already complete).

**Matrix walk**:
- Service type: Stateless HTTP → eligible for Canary
- Schema impact: backward-compatible expand done → no barrier
- Consumer type: N/A (HTTP service)
- Instant rollback required: No → Canary wins

**Strategy: Canary**

```
Stages: 5% (15 min) → 25% (30 min) → 50% (30 min) → 100% (terminal)
Gate: SLO fast-burn + p99 latency vs baseline
Argo Rollouts: Rollout CRD with canary strategy, AnalysisTemplate querying
  estate_scanner_content_hash_mismatch_total as a custom metric gate
Rollback trigger: CanaryFastBurnBreach alert → abort AnalysisRun → revert to 0%
```

---

### Example 2: Tenant Authorization Service (Schema Cutover, `auth-service`)

**Change**: Migrating from flat-permissions schema to ABAC attribute model. The schema change is non-additive — the old permissions table is being replaced, not extended. Expand/contract is in flight: the expand migration ran in the previous release, both old and new code paths write to both tables. The cutover migration (contract step) will drop the old table.

**Matrix walk**:
- Service type: Stateless HTTP → eligible for Canary or Blue-Green
- Schema impact: Contract migration (non-backward-compatible at cutover step) → Blue-Green during cutover window
- Instant rollback required: Yes (auth failure is a P0 incident) → Blue-Green confirmed

**Strategy: Blue-Green**

```
Pre-condition: Green environment provisioned with contract migration applied.
  Blue environment still running expand-phase schema (tolerates both v1 and v2 code).
Cutover: Service selector flip from blue to green.
  Window: 06:00–07:00 UTC (lowest traffic, per SLO burn-rate data).
  Rollback: Selector flip back to blue within 60 seconds of any P0 alert.
  Previous version (blue) stays warm for 1 hour post-cutover before scale-down.
Post-cutover: Blue-green window complete → remaining behavioral changes use Canary.
```

---

### Example 3: Document Upload UI (Feature Flag, `upload-ui`)

**Change**: New drag-and-drop upload component replacing the legacy file-picker modal. The React component is already deployed to 100% of production instances (shipped in the previous release, hidden behind `upload_drag_drop_enabled: false`). No schema or API change — purely a UI change.

**Matrix walk**:
- Code already deployed: Yes → Feature-Flag-Only eligible
- Schema impact: None → no barrier
- Instant rollback: Flag flip is instant → Feature-Flag-Only wins

**Strategy: Feature-Flag-Only**

```
Flag: upload_drag_drop_enabled
Targeting: percentage_rollout: 5 → validate 48h → 25 → validate 48h → 100
Rollback: Set targeting to 0% (flag off for all users) — no code deploy required.
Monitoring: New Relic Browser error rate + drag-drop event completion rate
  gate for flag-flip advancement, same as Canary's p99 gate but measured at
  browser session level, not HTTP response level.
```

---

### Example 4: Payment Processor (High-Risk Behavior, `payment-processor`)

**Change**: New fraud-scoring model with a changed decision threshold. The model produces a different approve/decline outcome for borderline transactions. Risk: a threshold miscalibration could incorrectly decline legitimate transactions (revenue loss) or approve fraudulent ones (compliance incident).

**Matrix walk**:
- Service type: Stateless HTTP → eligible for Canary
- Schema impact: None
- High-risk behavioral change: Yes → Canary + Feature Flag for maximum isolation

**Strategy: Canary + Feature Flag**

```
Deploy: Canary to 5% of HTTP traffic (Linkerd HTTPRoute weight)
Release within canary: Feature flag payment_new_fraud_model targets
  5% of users within the 5% canary traffic slice.
Effective exposure: ~0.25% of production requests touch the new model.
Advancement: Canary advances to 25% only after flag targeting reaches 100%
  within the 5% slice and all SLO gates are clean.
Rollback options:
  - Flag off within canary slice (seconds, no redeploy)
  - Canary weight back to 0% (minutes, no redeploy)
  - Both for belt-and-suspenders rollback before investigation
```

---

### Example 5: Audit Event Consumer (Partitioned Consumer, `audit-consumer`)

**Change**: New event schema enrichment — the consumer now writes an additional `actor_ip` field to the audit log from event metadata.

**Matrix walk**:
- Consumer type: Partitioned Redpanda consumer group → Canary not valid (no traffic percentage dial)
- Schema impact: Additive (backward-compatible) → no barrier to Blue-Green
- Instant rollback required: Yes (audit gaps are a compliance incident) → Blue-Green confirmed

**Strategy: Blue-Green**

```
Pre-condition: v2 consumer deployed as a separate Deployment (not yet consuming).
  Consumer group offset for audit-events topic recorded before any switch.
Cutover:
  1. Pause v1 consumer (scale to 0 replicas, allow in-flight batch to complete)
  2. Verify v1 lag = 0 on all partitions (Prometheus: redpanda_consumer_group_lag)
  3. Scale v2 consumer to production replica count
  4. Monitor for 15 minutes: audit_event_processing_errors_total = 0
Rollback: Scale v1 back to production replica count; scale v2 to 0.
  Consumer group resumes from the committed offset — no replay required
  because v1 committed offsets before pause.
Scale-down: v1 Deployment deleted after 24-hour bake window.
```

---

## Operator Pattern for Rollouts (Argo Rollouts vs. Manual)

When the matrix recommends Argo Rollouts `Rollout` CRD:

**Use Argo Rollouts when ALL of these are true:**
- The service is a `Deployment`-equivalent (stateless, horizontally scalable)
- Promotion and rollback criteria must be versioned in Git (GitOps-reconciled)
- The platform has the Argo Rollouts operator installed (check `opentofu-module`'s cluster provisioning)
- The team wants automated promotion without a human advancing stages manually

**Use manual canary (Linkerd HTTPRoute weight PRs) when:**
- Argo Rollouts is not yet installed
- The rollout cadence is slow enough (days, not hours) that manual PR review is not the bottleneck
- Han-Solo-scale operation where the human IS the automation

Both approaches are valid; the choice is documented in the release strategy artifact, not in a per-release decision.

---

## Strategy Cost and Risk Summary

| Strategy | Capacity cost | Rollback speed | Blast radius (if wrong) | Automation dependency |
|---|---|---|---|---|
| Canary | 1x (canary pods only, typically small fraction) | Minutes (weight revert) | Limited (% of traffic exposed) | Argo Rollouts or Flagger |
| Blue-Green | 2x during window | Seconds (selector flip) | Full (if cutover is wrong, all traffic affected) | None required (manual selector flip valid) |
| Feature-Flag-Only | 1x (code already running) | Seconds (flag off) | User-segment (flag targeting controls blast radius) | OpenFeature/flags.json |
| Canary + Feature Flag | 1x + flag overhead | Minutes (canary) or Seconds (flag off) | ~0.25% (dual-layer isolation) | Both Argo Rollouts and OpenFeature |
