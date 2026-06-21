# Skill: deploy/runbook

## Purpose
Produce an Operations Runbook for one scenario — a step-by-step procedure that an on-call engineer can follow to diagnose and resolve a specific operational scenario. Runbooks are written for humans under pressure; they must be unambiguous, ordered, and actionable.

## Inputs
- `artifacts/design/platform/observability-design.md` (alerts, metrics, SLOs)
- `artifacts/design/architecture/integration-design.md` (circuit breakers, DLQ)
- `artifacts/deploy/` (deployment topology)
- **Argument required:** scenario name (e.g. `deployment`, `rollback`, `incident-response`, `dlq-handling`, `worker-node-down`)

## Output
**File:** `artifacts/operations/runbooks/{scenario}.md`
**Registers in manifest:** yes

## Runbook Rules (enforced)
- Steps are numbered. Every step has exactly one action. No compound steps.
- Decision points are explicit: "If X, go to step N. If Y, go to step M."
- Every destructive step has a verification step immediately after.
- Commands are fully specified — no placeholders that require guessing.
- Runbooks are tested at least once before a production incident requires them.

## Artifact Template

```markdown
# Runbook: {scenario}
**Product:** {product_name}
**Phase:** Deploy (Operations)
**Artifact:** Operations Runbook
**Scenario:** {scenario display name}
**Severity:** P1 | P2 | P3 (potential impact)
**Last tested:** {date}
**Owner:** {team name}
**Version:** 1.0

---

## Runbook: DLQ Handling

**Trigger:** Alert `DLQNonEmpty` fires — Dead Letter Queue has messages
**SLA:** Investigate within 15 minutes; resolve within 2 hours for CRITICAL messages

---

### Step 1: Identify which DLQ has messages
```bash
# List all consumer groups and their DLQ topics
kafka-consumer-groups.sh --bootstrap-server $REDPANDA_BROKERS \
  --list | grep dlq

# Check message count on DLQ topics
kafka-consumer-groups.sh --bootstrap-server $REDPANDA_BROKERS \
  --describe --group $(cat /etc/service/consumer-group)
```

**Expected:** Output shows which DLQ topic has messages and how many.

---

### Step 2: Read the first DLQ message (without consuming it)
```bash
# Peek at first message
kafka-console-consumer.sh --bootstrap-server $REDPANDA_BROKERS \
  --topic {product-codename}.{service}.dlq \
  --from-beginning --max-messages 1 | jq .
```

**Look for:**
- `event_type` — what type of event failed?
- `error_reason` — why did processing fail?
- `retry_count` — how many times was this attempted?
- `tenant_id` — which tenant is affected?

---

### Step 3: Classify the failure
**If** `error_reason` contains "connection refused" or "timeout":
  → Transient failure. Check if the downstream service is healthy. Go to Step 4a.

**If** `error_reason` contains "validation" or "schema" or "missing field":
  → Deterministic failure. The event is malformed or the schema has changed. Go to Step 4b.

**If** `error_reason` contains "tenant not found" or "permission denied":
  → Business rule failure. Contact tenant admin. Go to Step 4c.

---

### Step 4a: Transient failure — replay after downstream recovery
```bash
# Verify downstream is healthy
curl https://{product-codename}.internal/api/v1/health/ready

# If healthy, replay DLQ messages
kafka-console-consumer.sh --bootstrap-server $REDPANDA_BROKERS \
  --topic {product-codename}.{service}.dlq --from-beginning \
  | kafka-console-producer.sh --bootstrap-server $REDPANDA_BROKERS \
  --topic {original-topic}
```

**Verify:** Consumer group lag on original topic increases then returns to 0 within 10 minutes.

---

### Step 4b: Deterministic failure — investigate and discard
Deterministic failures cannot be retried — the event is malformed. They are evidence of a producer bug.

```bash
# Export all DLQ messages for investigation
kafka-console-consumer.sh --bootstrap-server $REDPANDA_BROKERS \
  --topic {product-codename}.{service}.dlq --from-beginning \
  > /tmp/dlq-messages-$(date +%Y%m%d).json

# File a bug report with the exported messages as evidence
# Open ticket: "DLQ: deterministic failures in {service}.dlq — {date}"
```

**After investigation:** If root cause is fixed and events can be re-processed:
```bash
# Replay from DLQ export (with fix applied)
cat /tmp/dlq-messages-$(date +%Y%m%d).json | kafka-console-producer.sh \
  --bootstrap-server $REDPANDA_BROKERS --topic {original-topic}
```

---

### Step 5: Verify DLQ is draining
```bash
# Watch DLQ depth decrease to 0
watch kafka-consumer-groups.sh --bootstrap-server $REDPANDA_BROKERS \
  --describe --group {dlq-consumer-group}
```

**Expected:** `LAG` column decreases to 0 within 10 minutes.

---

### Step 6: Resolve the alert
Once DLQ depth = 0:
1. Update the incident ticket with root cause and resolution
2. If root cause was a producer bug: file a bug report; assign to owning team
3. Close the PagerDuty alert
4. If this was a new failure mode: add a new runbook section for it

---

## Related Runbooks
- [deployment.md](deployment.md) — Standard deployment procedure
- [rollback.md](rollback.md) — Emergency rollback
- [incident-response.md](incident-response.md) — General incident response
```

## Quality Checks
- [ ] Every step is numbered and contains exactly one action
- [ ] Decision points are explicit with "If X → step N; If Y → step M"
- [ ] Commands are fully specified (no placeholders to guess)
- [ ] Verification step follows every destructive action
- [ ] SLA is defined (time to investigate, time to resolve)
- [ ] "Last tested" field is present (runbooks must be tested before incidents need them)
- [ ] Related runbooks are cross-linked
