# Runbook Authoring — Worked Examples, Quality Criteria, Anti-Patterns, and Templates

This reference is self-contained: it can be read and applied without the parent `SKILL.md` in context. It provides the full decision tree example, quality gate table, anti-pattern catalog, output format templates, and the execution log format needed for toil tracking.

---

## Worked Example — DLQ Depth Alert for entity-extractor

This example demonstrates every section of a per-alert runbook, including a complete remediation decision tree that terminates every branch.

```markdown
---
name: runbook-entity-extractor-dlq-drain
version: 1.2.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
---

# Runbook: entity-extractor DLQ Not Empty

## Trigger
Alert `PipelineDLQNotEmpty` fires when `sum by (service, topic) (pipeline_dlq_depth)`
for `service="entity-extractor"` is greater than 0 for 15 minutes.
Dashboard: `grafana/d/entity-extractor-pipeline`

## Impact
Documents that failed extraction are parked, unprocessed. Their compliance
classification will not appear on customer dashboards until this is resolved —
customers may notice missing or delayed findings for the affected documents.
No data is lost; the Dead Letter Queue (DLQ) exists precisely to hold these
safely while a human investigates. Severity: ticket unless volume grows large
enough to threaten the freshness SLO, in which case the paired
`PipelineConsumerLagGrowing` alert will also fire and this becomes a page.

## Verification Steps

1. Confirm the DLQ depth and get message samples:
   ```bash
   kubectl exec -n tenant-[TENANT_ID] deploy/entity-extractor -- \
     rpk topic consume entity-extractor.dlq --num 5 --tenant [TENANT_ID]
   ```
2. Check the failure reason recorded on each DLQ message's headers:
   ```bash
   kubectl exec -n tenant-[TENANT_ID] deploy/entity-extractor -- \
     rpk topic consume entity-extractor.dlq --num 5 --format json \
     | jq '.headers[] | select(.key=="x-failure-reason")'
   ```
3. Cross-check recent deploys (a bad release is a common cause):
   ```bash
   git log --oneline -5 -- deploy/clusters/tenants/[TENANT_ID]/entity-extractor.yaml
   ```

## Remediation Decision Tree

```
Failure reason header says "unsupported-mime-type"
  → Source document type is genuinely unsupported (not a bug)
  → FIX: no code action; tag the message reviewed, confirm with customer
     success if source-side exclusion is warranted. Resolve, do not requeue.

Failure reason header says "extraction-timeout"
  → Check document size distribution of DLQ'd messages
  → All large documents (>50MB)?
      → Known limit; FIX: requeue is not appropriate, escalate:
        backend-engineer (entity-extractor) to evaluate streaming extraction
  → Mixed sizes, including small documents timing out
      → Recent deploy present in verification step 3?
          → YES → suspect regression; escalate: backend-engineer (entity-extractor)
                  with the deploy commit identified
          → NO  → escalate: backend-engineer (entity-extractor), unexplained
                  timeout regression with no deploy correlation

Failure reason header is missing or unrecognized
  → The consumer's error-handling path itself may be broken
  → escalate: backend-engineer (entity-extractor) — DLQ header contract violation
```

Every branch terminates: the two "FIX" leaves end in resolution actions;
every other leaf ends in a named escalation. No branch says "investigate further."

## Escalation
- Application-side extraction bugs, unsupported handling, header contract →
  **backend-engineer** (owns `entity-extractor` service code)
- DLQ depth growing without a fixable pattern, or infra-side broker issue →
  **platform-engineer** (self) — check Redpanda broker health, topic config
- If freshness SLO burn accompanies this (paired alert firing) →
  escalation path in `runbooks/pipeline/consumer-lag.md` takes precedence

## Post-Incident / Post-Procedure
[Filled in after each use: date, on-call, which branch was taken, whether the
runbook needed correction. For SEV1/SEV2: a blameless postmortem is opened
separately in the incident-management skill — this note is one corrective
action inside that postmortem, not the postmortem itself.]
```

---

## Worked Example — Remediation Decision Tree Detail (Consumer Lag Growing)

A more complex tree, demonstrating multi-level branching and the rule that every
leaf must name a specific agent:

```
Verification found consumer lag growing AND DLQ empty
├── Is the downstream dependency (compliance-engine) healthy?
│   ├── NO  → dependency outage; this is not entity-extractor's fault
│   │         → escalate: backend-engineer (compliance-engine)
│   │           page as dependent-service incident
│   └── YES → check consumer replica count vs partition count
│       ├── Replicas < partitions, autoscaler not keeping up
│       │         → FIX: scale replicas manually (kubectl scale)
│       │           open a values PR to increase replica floor permanently
│       └── Replicas = partitions, still lagging
│                 → throughput-per-replica has dropped; check recent deploys
│                 → recent deploy on entity-extractor in the past 48h?
│                     ├── YES → suspect regression
│                     │         canary-deployment auto-rollback should have caught this
│                     │         if it didn't, escalate: platform-engineer (canary gate failure)
│                     └── NO  → escalate: backend-engineer (entity-extractor)
│                               unexplained throughput drop — no deploy correlation
```

---

## Quality Criteria

The checklist a platform-engineer uses to gate a runbook before it is merged:

| Criterion | Pass | Fail |
|---|---|---|
| **Coverage — alert runbooks** | Every page-severity alert has a `runbook_url` resolving to a real file | Alerts pointing at nonexistent or placeholder runbooks |
| **Coverage — procedure runbooks** | Deploy, rollback, restore, tenant provisioning/deprovisioning each have a runbook | Procedures executed from memory or ad-hoc scripts |
| **Anatomy complete** | Trigger, impact, verification, decision tree, escalation all present | Missing sections, especially escalation |
| **Impact in product terms** | A PM can read the impact line and understand customer effect without context | Metric-name-only impact statements |
| **Copy-pasteable** | Every command runs as written except bracketed placeholders | Prose descriptions in place of commands |
| **Tree terminates** | Every branch ends in a fix or a named escalation | "Investigate further" as a leaf node |
| **Escalation named correctly** | Owner is the agent role per CLAUDE.md boundaries | App bugs escalated to platform-engineer; vague "the team" as escalation target |
| **Freshness** | Runbook exercised in a drill within the last cycle, or verified quarterly (rarely-executed); corrections applied | Runbook untouched since authoring, never tested |
| **Same-PR authoring** | Runbook merges in the same PR as the alert/procedure it documents | Alert shipped first, runbook "to follow" |
| **Post-incident / postmortem distinction** | SEV1/SEV2 runbook use triggers both a runbook correction note and a blameless postmortem in incident-management | Post-incident note written but blameless postmortem skipped for SEV1/SEV2 |
| **Toil threshold tracked** | Per-procedure execution log exists; monthly review checks frequency against 3x/week threshold | No execution frequency tracking; repeated manual procedures never escalated to platform-engineering-design |

---

## Anti-Patterns

Each anti-pattern is a named failure mode. The platform-engineer checks for all of them before merging a runbook PR.

**The `runbook_url` that 404s**
An alert shipped with a link to a file that doesn't exist is worse than no link, because it promises help that isn't there at exactly the moment someone is under pressure. The CI gate (`check-runbook-links.sh`) must catch this before merge — if it doesn't, it's a CI configuration defect, not an acceptable operational state.

**Prose in place of commands**
"Restart the affected pods" instead of the actual `kubectl rollout restart deploy/entity-extractor -n tenant-[TENANT_ID]` forces the on-call to reconstruct the command under pressure. That reconstruction is exactly what the runbook exists to prevent. Every executable step is a command block, not a sentence.

**Escalation to "the team" or "on-call"**
The on-call *is* the reader; telling them to escalate to on-call is circular. "Ask in Slack" is not an escalation; it is the absence of one. Name the owning agent role per CLAUDE.md's ownership table. If you genuinely don't know who owns the fix, that is a gap in the system design, not a valid runbook leaf.

**The infinite decision tree leaf**
"If none of the above, investigate further" is an admission the tree wasn't finished. Every unresolved branch needs a named escalation — "escalate: backend-engineer (service-name), cause unknown, include the output of verification step 2" — not an open door.

**Impact statements in internal jargon**
"Consumer lag exceeds SLO threshold on partition 3" tells Shafi nothing about whether customers are affected right now. Translate: "Document processing for tenant-[TENANT_ID] is backed up — customers may see stale classification results for up to [N] minutes." The metric name can appear in the Trigger section; the Impact section is for the product-level consequence.

**Runbooks that never get drilled**
Authored once, referenced in an alert, never followed until a real incident — which is the worst possible first test of whether the runbook is correct. The freshness SLA and drill cadence exist to prevent this. A runbook at zero executions and zero drills is not a runbook.

**Confusing a runbook correction with a blameless postmortem**
After a SEV1, updating the runbook's post-incident section is housekeeping. The blameless postmortem is a separate artifact, owned by `incident-management`, covering the full incident timeline, multiple contributing factors, and corrective actions across systems. A team that only updates the runbook has not done a postmortem. A postmortem whose only corrective action is "update the runbook" may have stopped its analysis too early.

**Fixing app bugs in the runbook itself**
A remediation step that patches a ConfigMap to work around an application defect (rather than escalating for a real code fix) is the platform-engineer quietly overstepping its "operates, never patches app code" boundary. It also hides the defect from the team that owns it, so the root behavior recurs. If the fix requires editing application code or its direct configuration, the leaf is an escalation, not a workaround.

**Ignoring the toil threshold**
A rollback procedure executed four times in a single week is not "the team is getting good at rollbacks." It is a signal that the deployment or quality gate process has a structural defect that keeps requiring manual intervention. The toil threshold (3x/week) is the trigger to escalate to `platform-engineering-design` as an automation candidate — not an excuse to optimize the manual steps.

---

## Output Format — Runbook Library Index

The platform-engineer produces this index artifact when completing a runbook library for a product:

```markdown
---
name: runbook-authoring-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Runbook Library — [product]

## Per-Alert Runbooks
| Alert | Severity | Runbook path | Last drilled | Status |
|---|---|---|---|---|
| PipelineDLQNotEmpty | page | runbooks/pipeline/dlq-drain.md | 2026-07-01 | current |
| PipelineConsumerLagGrowing | page | runbooks/pipeline/consumer-lag.md | 2026-07-01 | current |

## Per-Procedure Runbooks
| Procedure | Runbook path | Last drilled | Status |
|---|---|---|---|
| Deploy | runbooks/procedures/deploy.md | 2026-07-01 | current |
| Rollback | runbooks/procedures/rollback.md | 2026-07-01 | current |
| Restore | runbooks/procedures/restore.md | 2026-07-01 | current |
| Tenant provisioning | runbooks/procedures/tenant-provision.md | 2026-07-01 | current |
| Tenant deprovisioning | runbooks/procedures/tenant-deprovision.md | 2026-07-01 | current |

## Coverage Check
[Output of check-runbook-links.sh — all runbook_url references resolved]
PASS: 2/2 alert runbooks resolve to existing files.

## Escalation Map
| Symptom class | Owning agent | Rationale |
|---|---|---|
| Extraction logic defect | backend-engineer | Owns entity-extractor service code |
| Broker / infra | platform-engineer | Within platform ownership boundary |
| Auth / secrets | security-engineer | Owns ABAC and Vault control internals |

## Drill and Freshness Log
| Date | Runbook | Followed as written? | Correction applied |
|---|---|---|---|
| 2026-07-01 | runbooks/procedures/rollback.md | Yes | None — passed |
| 2026-07-01 | runbooks/procedures/restore.md | No — step 3 kubectl path stale | Updated deploy path in v1.1.0 |

## Toil Log
| Month | Procedure | Execution count | Above 3x/week threshold? | Action taken |
|---|---|---|---|---|
| 2026-07 | rollback | 2 | No | Continue monitoring |

## Traceability
- alerting-rules-design alert inventory: all page-severity alerts covered
- disaster-recovery-plan procedures: restore runbook covers DR drill procedure
```

---

## Execution Log Template — Per-Procedure Toil Tracking

Each runbook with procedure-level tracking should carry or link to an execution log in this format. The monthly review uses this log to evaluate the toil threshold:

```markdown
## Execution Log — [procedure name]

| Date | Executor | Followed as written? | Deviation / correction | Execution count this week |
|---|---|---|---|---|
| 2026-07-28 | platform-engineer | Yes | None | 1 |
| 2026-07-29 | platform-engineer | Yes | None | 2 |
| 2026-07-30 | platform-engineer | No — step 4 had wrong namespace | Corrected inline, PR raised | 3 |
| 2026-07-31 | platform-engineer | Yes (after correction) | None | 4 ← THRESHOLD BREACHED |

**Toil threshold status**: 4 executions in 7 days — threshold (3x/week) exceeded.
**Action required**: Escalate to platform-engineering-design as automation candidate.
**Escalation raised**: [link to platform-engineering-design issue or PR]
```

A procedure that has been executed 20 times without change but still requires manual intervention is a strong automation candidate — the execution log is the evidence that makes the escalation concrete rather than anecdotal.
