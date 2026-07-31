# The PII Data Lifecycle — A Control at Every Stage

Reference for `privacy-design`. The body names the five lifecycle stages and the key
control at each; this file is the full control map, grounded in this repo's DataAsset
ingestion → entity-extraction → compliance-classification flow (Go + chi + pgx, Redpanda,
per-tenant physical isolation, Linkerd mTLS, OpenTelemetry/Prometheus/Tempo/Grafana). It
also carries the reference artifacts the body points to: the personal data inventory, the
retention Continuous Control Monitoring mechanism, the erasure implementation, the GDPR
Article 30 record of processing activities, and the DPIA trigger model.

**The core idea (from *The Privacy Engineer's Manifesto*):** PII is the atomic unit, and
every item of PII moves through a lifecycle — **collect → use → retain → disclose →
destroy**. Privacy engineering places an explicit control at *each* stage. An inventory
lists categories; a lifecycle map lists the gate each category passes through at every
transition. A row with a blank stage is an *unguarded lifecycle transition* — a defect.

---

## The five stages and their controls

| Stage | The question it answers | Key control | FIPP served |
|---|---|---|---|
| **Collect** | May we take this data, and only what we need? | Lawful basis + data minimisation (structural — extract types+counts, never raw text) | Collection limitation; purpose specification |
| **Use** | Is this read for the purpose the data was collected for? | Purpose-binding: purpose tag on the column, checked at the pgx access layer; ABAC gate | Use limitation |
| **Retain** | Is the data still within its retention window? | Retention TTL + Continuous Control Monitoring that alarms on any row past its window | Collection limitation; accountability |
| **Disclose** | May *this* subject, for *this* reason, read *this*? | ABAC decision (in the application, not the mesh) + immutable audit-log entry | Security safeguards; individual participation |
| **Destroy** | Was the data provably deleted on schedule? | Verifiable deletion (scheduled partition drop) whose *execution is itself audited* | Accountability |

---

## The lifecycle-control map, applied per data category

| Category | Collect | Use | Retain | Disclose | Destroy |
|---|---|---|---|---|---|
| **User identity** (name, email, role) | Contract basis; onboarding only | Auth/authz only; purpose tag `identity` | Account lifetime + 90 days | ABAC; self-service access | Anonymise on account close, hard-delete after grace |
| **File metadata** (path, name, type, size) | Legitimate interest; source scan | Estate mapping; tag `estate-map` | 90 days (per-tenant override) | ABAC per tenant; no third parties | Partition drop, audited |
| **Extracted entity summary** (type + count) | **Types+counts only — raw text has no data path** | Compliance detection; tag `compliance-detection` | Same as file metadata | ABAC; contractual no-share | Partition drop, audited |
| **Access / audit logs** (actor, action, ts, IP) | Legal obligation | Security audit; tag `security-audit` | 7 years (compliance) | ABAC (security role); Non-Repudiation | Expiry after legal window only |
| **File contents** (raw bytes) | **Never collected into storage** | n/a | n/a | n/a | n/a |

The two structural rows — *extracted entity summary* stores only `(EntityType, Count)`, and
*file contents* are never persisted — are the platform's strongest privacy controls: a
disclosure that has no data source cannot happen. The type-level enforcement of the first is
detailed in `pii-domain-primitive.md`.

---

## Collect stage — minimisation as the strongest control

The most powerful privacy control is *not collecting or not retaining the data in the first
place*. Minimisation designed into the schema makes a violation structurally impossible
rather than a discipline someone must remember. For each candidate data element, the design
must answer "what happens if we don't collect this?" — and if the answer is "we lose
nothing the purpose needs", it is not collected. The extraction pipeline emits
`(EntityType, Count)` per file; the raw span that matched (`"John Smith"`, `SSN
078-05-1120`) is never written to a store, a cache, a log, or an error message.

---

## Retain stage — retention as enforced TTL with Continuous Control Monitoring

A documented retention period with no scheduled deletion proves nothing. Retention is real
only when (a) a mechanism provably deletes on schedule and (b) a monitor continuously
verifies no data has outlived its window.

**Mechanism:** partition the time-series PII tables (extracted entity summaries, file
metadata) by day; a scheduled job drops partitions older than the window. Dropping a
partition is atomic and cheap — far better than row-by-row `DELETE`.

**Continuous Control Monitoring (CCM):** a Prometheus gauge exports the age of the oldest
live partition per tenant per table; an alert fires the moment any partition exceeds its
retention window + grace. This turns retention from a config nobody enforces into a control
that is *observed to hold* — the accountability FIPP made operational.

```promql
# Alert if any retained PII partition outlives its window (90d + 1d grace).
max by (tenant, table) (pii_partition_oldest_age_seconds) > (91 * 86400)
```

The deletion job writes its own execution to the audit log (`retention.partition.dropped`,
with tenant, table, partition date, row count) so the deletion is *demonstrable evidence*,
not a silent side effect.

---

## Destroy stage — verifiable deletion and erasure (GDPR Article 17)

Erasure differs by category, and the controller/processor split governs who may request it:

- **User account data:** soft-delete + anonymise on request, hard-delete after the grace
  period.
- **Extracted entity summaries** (people named in files): governed by the *customer's*
  retention policy — the customer is the controller; individual erasure requests route to
  them, not to us.
- **Access logs:** an erasure request for a log entry under legal retention is *declined
  with the legal reference*; never hard-delete audit history to satisfy an erasure request.
  Anonymise the actor field instead.

```sql
-- User erasure: soft-delete + anonymise (tenant-scoped, physical isolation still applies)
UPDATE users
SET email = 'deleted-' || id || '@deleted.invalid',
    display_name = 'deleted-user',
    deleted_at = now()
WHERE id = $1 AND tenant_id = $2;

-- Hard-delete after the grace window (run by the scheduled reaper, audited)
DELETE FROM users
WHERE deleted_at IS NOT NULL
  AND deleted_at < now() - interval '90 days';
```

---

## GDPR Article 30 — record of processing activities

Article 30 requires a maintained record of processing activities. For a software product it
documents what personal data is processed, on whose behalf, for what purpose, and with what
safeguards. Required fields per activity:

```
Activity name:          [Name]
Controller:             [The customer company — data controller]
Processor:              [Our company — data processor]
Purpose:                [The specific purpose — must generate a prohibited-uses list]
Data categories:        [Types of personal data]
Data subjects:          [Who the data is about]
Recipients:             ["No third parties" is a valid, and here the correct, answer]
Retention period:       [How long — must match an enforced TTL, not just a policy]
Safeguards:             [Encryption at Rest/in Transit, ABAC, per-tenant isolation, audit]
Legal basis (Art 6):    [Contract / Legal obligation / Legitimate interest / Consent]
Transfer (Arts 44-49):  [Whether data leaves the EU/EEA and the mechanism]
```

A purpose that cannot generate a *prohibited-uses* list is not a purpose ("operational
purposes" permits anything and is a defect). Each legal basis carries distinct obligations —
legitimate interest requires a documented balancing test; do not conflate it with contract
performance (Art 6(1)(b)).

---

## DPIA — a risk model, not a yes/no trigger list

A Data Protection Impact Assessment is required (GDPR Article 35) when processing is "likely
to result in a high risk to the rights and freedoms of natural persons." Rather than a
binary trigger checklist, score each PII category on four axes and give the highest-scoring
*lifecycle transitions* the deepest review:

| Axis | What it measures |
|---|---|
| Identifiability | Directly identifying vs. quasi-identifier vs. aggregate (types+counts scores low) |
| Sensitivity | Special-category data (health, financial, HR) scores high |
| Volume | Scale of processing across the tenant estate |
| Lifecycle exposure | Which transitions expose the data most (disclose-stage of sensitive entities scores highest) |

**Triggers that apply to this product:** systematic processing of potentially sensitive data
(health/financial/HR content may appear in scanned files) → yes; new technologies (ML entity
extraction) → yes; large-scale processing → depends on tenant volume; legal/significant
effects on individuals → no (the product *detects*, it does not *decide*). Recommendation:
conduct a DPIA for the first product, in the Design phase, keyed to the lifecycle — the
disclose stage of extracted sensitive-entity summaries is the highest-scoring transition and
gets the deepest review.
