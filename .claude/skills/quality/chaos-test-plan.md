# Skill: quality/chaos-test-plan

## Purpose
Produce the Chaos Test Plan — the specification of controlled failure injection experiments that verify the system's resilience engineering actually works. Each experiment has a hypothesis, a failure injection, a steady-state assertion before and after, and a success criterion. Chaos tests prove that runbooks, circuit breakers, DLQs, and graceful degradation behave as designed.

## Inputs
- `artifacts/design/architecture/integration-design.md` (circuit breakers, DLQ config)
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/design/platform/observability-design.md` (SLOs, alerts)
- `artifacts/operations/runbooks/` (if available)

## Output
**File:** `artifacts/quality/chaos-test-plan.md`
**Registers in manifest:** yes

## Chaos Test Rules (enforced)
- Every experiment has a written hypothesis ("we believe that X will happen when Y fails").
- Steady state is verified BEFORE and AFTER injection.
- Blast radius is limited (test on one tenant at a time; not the whole cluster).
- Rollback procedure is defined before each experiment runs.
- Experiments are approved and scheduled — never run ad hoc in staging.

## Artifact Template

```markdown
# Chaos Test Plan

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Chaos Test Plan
**Tool:** Chaos Mesh v2.x (Kubernetes fault injection)
**Environment:** Staging only (never production)
**Approval required:** Platform Engineering lead
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Chaos Engineering Principles

1. **Define steady state first.** Chaos is not about breaking things — it is about proving resilience. Steady state = SLOs met, no DLQ messages, no alerts firing.
2. **Blast radius is minimal.** Each experiment targets one component. Cross-service cascades are observed, not induced.
3. **Hypothesis-driven.** "We believe that [circuit breaker / DLQ / graceful degradation] will [protect / handle / route] when [component] fails."
4. **Rollback defined before start.** The rollback command is written and tested before the experiment begins.
5. **Stop conditions.** If SLO breach persists > 5 minutes or data corruption is detected, the experiment is terminated and the platform team is notified.

---

## Experiment Register

### CE-01: PostgreSQL Unavailability (File Domain)

**Hypothesis:** When the File Domain PostgreSQL is unavailable, API write requests fail with 503 (not 500), circuit breaker opens, and the system recovers automatically when PostgreSQL returns within 2 minutes.

**Steady state (before):**
- `GET /api/v1/health/ready` → 200 for all services
- p(99) API latency < 500ms
- No alerts firing

**Failure injection:**
```yaml
# chaos-mesh NetworkChaos targeting file-domain PostgreSQL
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: ce-01-postgres-partition
spec:
  action: partition
  mode: all
  selector:
    labelSelectors:
      app: file-domain-postgres
  duration: "3m"
```

**Expected behaviour during injection:**
- First 3 requests to write endpoints: fail with connection error (circuit breaker CLOSED — counting failures)
- After failure threshold (5 failures in 10 seconds): circuit breaker OPEN
- Write endpoint returns 503 Service Unavailable (not 500 Internal Server Error)
- `file_domain_circuit_breaker_state` metric shows OPEN
- Alert `FileDomainDatabaseUnavailable` fires within 1 minute

**Expected behaviour after injection (PostgreSQL restored):**
- Circuit breaker transitions to HALF-OPEN (probe request)
- Probe succeeds → circuit breaker CLOSED
- Write endpoints return 2xx within 30 seconds of PostgreSQL recovery
- No data loss (outbox events re-processed if applicable)

**Success criteria:**
- [ ] No 500s during injection (all failures are 503)
- [ ] Circuit breaker opens within 30 seconds of first failure
- [ ] Alert fires within 1 minute
- [ ] System fully recovers within 2 minutes of PostgreSQL restoration
- [ ] No data corruption in PostgreSQL after recovery

**Rollback:**
```bash
kubectl delete networkchaos ce-01-postgres-partition -n staging
```

---

### CE-02: Redpanda Partition — Consumer Lag and DLQ

**Hypothesis:** When Redpanda is unavailable for 5 minutes, events queue, the consumer group resumes from the last committed offset on recovery, DLQ does not fill (no messages exceed retry limit), and event processing completes within 10 minutes of recovery.

**Failure injection:**
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: ce-02-redpanda-partition
spec:
  action: partition
  mode: all
  selector:
    labelSelectors:
      app: redpanda
  duration: "5m"
```

**Expected behaviour:**
- Consumer groups report offline; consumer lag metric visible in Grafana
- Alert `RedpandaConsumerGroupLag` fires when lag > 1000 messages
- Event publisher (Outbox Relay): enters retry with exponential backoff; does not lose events
- On recovery: consumer resumes from committed offset; all queued events processed
- DLQ count: 0 (no message should hit retry limit in 5 minutes — retry window is 30 minutes)

**Success criteria:**
- [ ] Consumer lag drains to 0 within 10 minutes of Redpanda recovery
- [ ] No DLQ messages from this experiment
- [ ] No duplicate processing of events (idempotency verified via entity count check)
- [ ] Alert fires during outage and resolves automatically on recovery

---

### CE-03: Worker Node Disconnection

**Hypothesis:** When a Worker Node loses connectivity to the platform, scan jobs stop and the platform marks them as SCAN_ERROR after the timeout period, without data loss or corruption of other tenant data.

**Failure injection:**
```yaml
# NetworkChaos targeting the Worker Node's outbound connectivity to platform
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: ce-03-workernode-partition
spec:
  action: partition
  mode: all
  selector:
    labelSelectors:
      component: worker-node
      tenant: chaos-test-tenant
  duration: "10m"
```

**Expected behaviour:**
- Platform detects heartbeat loss from Worker Node within 60 seconds
- In-flight scan job transitions to SCAN_ERROR after 5-minute timeout
- Alert `WorkerNodeHeartbeatMissing` fires within 90 seconds
- Other tenants' Worker Nodes are unaffected
- On reconnection: Worker Node re-registers; no automatic restart of failed scan (requires manual re-trigger)

**Success criteria:**
- [ ] `WorkerNodeHeartbeatMissing` alert fires within 90 seconds
- [ ] Scan job status = SCAN_ERROR (not SCANNING forever)
- [ ] Other tenants' scans continue unaffected
- [ ] No customer data leaks in any log or metric during the experiment

---

### CE-04: Pod Kill — Entity Domain Service

**Hypothesis:** When the Entity Domain service pod is killed, Kubernetes restarts it within 30 seconds, in-flight events are not lost (consumer group offset not committed), and processing resumes from the correct offset on restart.

**Failure injection:**
```bash
# PodChaos via Chaos Mesh
kubectl apply -f chaos/ce-04-entity-pod-kill.yaml
# OR direct pod kill
kubectl delete pod -l app=entity-domain -n staging --grace-period=0
```

**Expected behaviour:**
- Kubernetes restarts pod within 30 seconds (Readiness probe blocks traffic during restart)
- Consumer group retains uncommitted offset — no events skipped
- Events that were in-flight (received but not committed) are reprocessed on restart
- Idempotency ensures re-processing produces the same result
- p(99) API latency spike within 30-second restart window (acceptable — within error budget)

**Success criteria:**
- [ ] Pod restarts within 30 seconds
- [ ] No events lost (consumer lag returns to 0 within 5 minutes)
- [ ] No duplicate entities created (idempotency check on entity count)
- [ ] Health check page shows healthy within 60 seconds of pod restart

---

### CE-05: Elasticsearch Unavailability — Graceful Degradation

**Hypothesis:** When Elasticsearch is unavailable, the system continues to process scans and store findings in PostgreSQL, but search and entity indexing are degraded. The dashboard shows a "search unavailable" indicator rather than returning an error page.

**Failure injection:** Network partition to Elasticsearch for 3 minutes.

**Expected behaviour:**
- Write path (scanning, finding creation): unaffected (PostgreSQL)
- Read model queries that require ES (entity search, text search): return 503 with `degraded: true` flag in response
- Compliance posture dashboard: shows from PostgreSQL read model (not degraded)
- Alert `ElasticsearchUnavailable` fires
- On ES recovery: index catch-up from outbox / CDC pipeline within 5 minutes

**Success criteria:**
- [ ] Write path remains fully functional during ES outage
- [ ] ES-dependent endpoints return 503, not 500
- [ ] UI shows degraded mode indicator (not blank page or 500 error page)
- [ ] Index catch-up completes within 5 minutes of ES recovery

---

## Experiment Schedule

| Experiment | Frequency | Prerequisites | Approver |
|-----------|-----------|--------------|---------|
| CE-01 | Monthly | Staging healthy, no active users | Platform Engineering |
| CE-02 | Monthly | Staging healthy | Platform Engineering |
| CE-03 | Quarterly | Dedicated test tenant only | Platform Engineering |
| CE-04 | Monthly | Staging healthy | Platform Engineering |
| CE-05 | Quarterly | Staging healthy | Platform Engineering |

---

## Stop Conditions

Any experiment is terminated immediately if:
- SLO breach persists > 5 minutes after injection ends
- Data corruption detected in any PostgreSQL table
- DLQ count unexpectedly exceeds 0 during CE-01 or CE-04
- Cross-tenant data is observed in any log or metric output
```

## Quality Checks
- [ ] Every experiment has a written hypothesis
- [ ] Steady state is defined (before) and verified (after) for each experiment
- [ ] Failure injection YAML or command is specified
- [ ] Success criteria are checkboxes — binary pass/fail
- [ ] Rollback procedure is defined
- [ ] Stop conditions are listed for all experiments
- [ ] Worker Node isolation experiment verifies no cross-tenant data leakage
