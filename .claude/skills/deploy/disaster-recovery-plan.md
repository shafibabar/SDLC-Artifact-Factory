# Skill: deploy/disaster-recovery-plan

## Purpose
Produce the Disaster Recovery Plan — the specification of how the system recovers from catastrophic failures. Defines RTO (Recovery Time Objective) and RPO (Recovery Point Objective) targets, recovery procedures for each failure scenario, and the testing schedule that validates the plan works.

## Inputs
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/operations/slos.md` (availability targets)
- `sdlc-config.json` (compliance_frameworks — SOC 2/HIPAA have DR requirements)
- `artifacts/design/data/data-retention-policy.md` (backup schedules)

## Output
**File:** `artifacts/operations/dr-plan.md`
**Registers in manifest:** yes

## DR Plan Rules (enforced)
- RTO and RPO are stated in hours:minutes — not "as fast as possible".
- Every failure scenario has a step-by-step recovery procedure.
- DR procedures are tested at least annually (more frequent for compliance frameworks).
- Backup restoration is tested separately from the DR drill.
- Customer communication SLA is specified for each failure scenario.

## Artifact Template

```markdown
# Disaster Recovery Plan
**Product:** {product_name}
**Phase:** Deploy (Operations)
**Artifact:** Disaster Recovery Plan
**Version:** 1.0
**Date:** {date}
**Status:** Approved
**Compliance:** SOC 2 CC9.1, GDPR Art. 32 (business continuity)

---

## RTO and RPO Targets

| Tier | Services | RTO | RPO | SLO impact |
|------|---------|-----|-----|-----------|
| Tier 1 (Critical) | API Gateway, File Domain, Compliance Domain | 1 hour | 15 minutes | Full production impact |
| Tier 2 (Important) | Entity Domain, Graph Domain | 4 hours | 1 hour | Reduced functionality |
| Tier 3 (Supporting) | Analytics pipelines, Reporting | 24 hours | 4 hours | No real-time impact |

---

## Failure Scenario: Complete Region Failure (AWS us-east-1 down)

**Classification:** P1 — Full service outage
**RTO:** 1 hour | **RPO:** 15 minutes

### Recovery Steps

**Step 1:** Detect failure (automated alert fires within 5 minutes of health check failure)
**Step 2:** Confirm failure is region-wide (check AWS Service Health Dashboard)
**Step 3:** Initiate DR activation
  ```bash
  # Switch DNS to failover region (eu-west-1)
  aws route53 change-resource-record-sets --hosted-zone-id Z123 \
    --change-batch file://dns-failover.json
  ```
**Step 4:** Restore PostgreSQL from point-in-time backup (RPO = 15 minutes = last backup)
  ```bash
  # Restore RDS from latest automated snapshot
  aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier {product-codename}-{tenant-id} \
    --target-db-instance-identifier {product-codename}-{tenant-id}-dr \
    --restore-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
    --region eu-west-1
  ```
**Step 5:** Verify data integrity (row counts, latest event ID matches)
**Step 6:** Update ESO references to point to DR region database
**Step 7:** Restart all services in DR region
**Step 8:** Run smoke tests against DR region
**Step 9:** Notify customers: "We are experiencing a regional disruption. Recovery in progress. ETA: {time}."

---

## Failure Scenario: Database Corruption

**Classification:** P1
**RTO:** 2 hours | **RPO:** 1 hour

### Recovery Steps

**Step 1:** Identify corruption (DQ checks fail; data inconsistency alerts fire)
**Step 2:** Take a forensic snapshot before any changes
**Step 3:** Determine corruption scope: which tables, which tenants, how far back
**Step 4:** Restore from last clean backup (point-in-time)
**Step 5:** Replay events from Redpanda from the backup timestamp to now
  - Redpanda retains events for 7 days — sufficient for recovery within RPO
  - Event replay re-processes all domain events in order
**Step 6:** Verify data quality (run DQ checks from quality-rules.md)
**Step 7:** Resume normal operation

---

## Backup Schedule

| Data | Backup method | Frequency | Retention | Restoration time |
|------|--------------|-----------|-----------|-----------------|
| PostgreSQL (per-tenant) | AWS RDS automated backup | Continuous (5-min snapshots) | 7 days | 30 minutes |
| Elasticsearch indices | Index snapshots to S3 | Daily | 30 days | 2 hours |
| Redpanda topics | Topic retention (no backup needed) | N/A — 7-day retention | 7 days | Replay from offset |
| Secrets (Vault) | Vault auto-unseal + snapshot | Daily | 90 days | 1 hour |

---

## DR Testing Schedule

| Test | Frequency | Scope | Last tested |
|------|-----------|-------|------------|
| Backup restoration test | Monthly | Restore 1 tenant DB to staging | {date} |
| Full DR drill | Annually | Simulate region failure; full recovery | {date} |
| Failover DNS test | Quarterly | Switch DNS; verify traffic routes to DR region | {date} |
| Event replay test | Quarterly | Replay 1 hour of events from backup timestamp | {date} |

**DR drill procedure:** Scheduled maintenance window; customer notified 72 hours in advance; production traffic diverted to maintenance page during drill.

---

## Customer Communication SLA

| Scenario | Time to first notification | Channel | Frequency |
|---------|--------------------------|---------|-----------|
| P1: Full outage | 15 minutes | Status page + email | Every 30 minutes |
| P2: Degraded | 30 minutes | Status page | Every hour |
| Resolution | Immediately | Status page + email | Once |
```

## Quality Checks
- [ ] RTO and RPO are stated in hours:minutes — not vague language
- [ ] Recovery steps are numbered and specific (actual commands)
- [ ] Backup restoration commands are included
- [ ] Event replay from Redpanda is specified as a recovery mechanism
- [ ] Testing schedule with dates is present
- [ ] Customer communication SLA is defined
- [ ] Compliance frameworks (SOC 2, GDPR) are referenced
