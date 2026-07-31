# Runbook Template, Worked Examples, Anti-Patterns, and Output Format

Self-contained reference for `runbook-authoring`. Use this when authoring a new runbook or
reviewing an existing one against the standard. Load alongside `SKILL.md`; this document does
not repeat SKILL.md's decision-shaping guidance — it provides the templates and worked examples.

---

## Runbook File Template

Copy this template for every new runbook. Fill in all sections before the PR merges.

```markdown
---
name: runbook-[service]-[trigger-slug]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [YYYY-MM-DD]
---

# Runbook: [Human-readable title]

## Trigger
Alert `[AlertName]` fires when [condition in plain terms].
Dashboard: `[grafana dashboard link or path]`
[OR, for a per-procedure runbook: "This procedure is executed when [condition]"]

## Impact
[What does this mean for the product, in terms a PM understands. No metric names.
No internal service jargon. What would a customer notice, and how bad is it?
State whether data is lost, delayed, or just unavailable while being fixed.
State the severity: ticket-severity (non-urgent), page-severity, or incident-severity.]

## Verification Steps

1. [Step 1 — copy-pasteable command]
   ```bash
   [command with [PLACEHOLDER] for variable values]
   ```
2. [Step 2]
   ```bash
   [command]
   ```
3. [Step 3]
   ```bash
   [command]
   ```

## Remediation Decision Tree

```
[Finding from verification]
├── [Condition A]
│   └── FIX: [exact steps] / escalate: [agent role]
└── [Condition B]
    ├── [Sub-condition B1]
    │   └── FIX: [exact steps]
    └── [Sub-condition B2]
        └── escalate: [agent role] ([reason])
```

Every branch must terminate in either "FIX: [steps]" or "escalate: [agent]".
"Investigate further" is not an acceptable leaf.

## Escalation
- [Symptom class] → **[agent-role]** ([reason])
- [Symptom class] → **[agent-role]** ([reason])

## Execution Log
[Filled in after each use — date, on-call, which branch was taken, outcome,
whether the runbook needed correction. This log is checked against the toil
threshold during monthly review: if this procedure appears > 3 times/week
for 2+ consecutive months, it is escalated as a platform automation candidate.]

| Date | On-call | Branch taken | Runbook correct? | Correction PR |
|------|---------|--------------|-----------------|---------------|
```

---

## Worked Example — DLQ Depth Alert for entity-extractor

This example demonstrates all five sections with complete copy-pasteable commands
and a fully terminating decision tree. Every leaf ends in a fix or an escalation.

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

## Escalation
- Application-side extraction bugs, unsupported handling, header contract →
  **backend-engineer** (owns `entity-extractor` service code)
- DLQ depth alone growing without a fixable pattern, or infra-side broker issue →
  **platform-engineer** (self) — check Redpanda broker health, topic config
- If freshness SLO burn accompanies this (paired alert firing) →
  escalation path in `runbooks/pipeline/consumer-lag.md` takes precedence

## Execution Log
| Date | On-call | Branch taken | Runbook correct? | Correction PR |
|------|---------|--------------|-----------------|---------------|
```

---

## Worked Example — Rollback Runbook (Per-Procedure)

This demonstrates a per-procedure runbook for the rollback case, showing how it
differs from an alert runbook: no Prometheus alert fires — a human decision triggers it.

```markdown
---
name: runbook-rollback-entity-extractor
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
---

# Runbook: Rollback entity-extractor

## Trigger
This procedure is executed when: (a) the canary gate fires a rollback automatically
and a human must confirm the selector revert completed, OR (b) a human decision
to rollback is made before the canary gate fires.

CD pipeline dashboard: `grafana/d/cd-pipeline-status`

## Impact
The most recent production release of `entity-extractor` will be reverted to the
previously-known-good version. Customers will continue to receive results from
the prior version; any features introduced in the reverted release will be
unavailable until a corrected release is promoted.

## Verification Steps

1. Confirm the current production version:
   ```bash
   kubectl get deployment entity-extractor -n tenant-[TENANT_ID] \
     -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```
2. Identify the target rollback version from the deployment history:
   ```bash
   kubectl rollout history deployment/entity-extractor -n tenant-[TENANT_ID]
   ```
3. Check for in-flight document processing (do not rollback mid-batch):
   ```bash
   kubectl exec -n tenant-[TENANT_ID] deploy/entity-extractor -- \
     rpk topic lag --brokers redpanda:9092 --group entity-extractor-consumer
   ```

## Remediation Decision Tree

```
Consumer lag is zero (no in-flight processing)
  → Safe to rollback immediately
  → FIX:
    kubectl rollout undo deployment/entity-extractor -n tenant-[TENANT_ID]
    kubectl rollout status deployment/entity-extractor -n tenant-[TENANT_ID]
  → Confirm rollback image matches target from step 2
  → Open a PR reverting the deployment YAML in the GitOps repo to the prior version
    (the kubectl undo is the emergency fix; the PR is the durable record)

Consumer lag is non-zero (in-flight processing active)
  → Wait for lag to reach zero (check every 60 seconds)
  → If lag does not reach zero within 10 minutes:
      → Is the consumer in an error loop (restarting)?
          → YES → consumer is already broken; proceed with rollback immediately:
                  kubectl rollout undo deployment/entity-extractor -n tenant-[TENANT_ID]
          → NO  → consumer is processing; wait it out; re-check at 10-minute intervals
  → After lag reaches zero: follow "Consumer lag is zero" branch above

Rollback fails (kubectl rollout undo returns error)
  → escalate: platform-engineer (self) — Kubernetes rollout state may be corrupted
  → If platform-engineer cannot resolve: escalate: Shafi (spend decision —
    may require emergency image pin or a hotfix deploy rather than a rollback)
```

## Escalation
- Rollback fails at the kubectl level → **platform-engineer** (self)
- Emergency outside kubectl rollout scope → **Shafi** (product decision)

## Execution Log
| Date | On-call | Branch taken | Runbook correct? | Correction PR |
|------|---------|--------------|-----------------|---------------|
```

---

## Anti-Patterns

**The `runbook_url` that 404s** — an alert shipped with a link to a file that doesn't exist is
worse than no link, because it promises help that isn't there at exactly the moment someone is
under pressure. CI must catch this (see check-runbook-links.sh in SKILL.md).

**Prose in place of commands** — "restart the affected pods" instead of the actual
`kubectl rollout restart` invocation forces the on-call to reconstruct the command under
pressure, exactly what the runbook exists to prevent. Every action in a runbook is a
copy-pasteable command, not a description of one.

**Escalation to "the team" or "on-call"** — the on-call *is* the reader; telling them to
escalate to on-call is circular. The escalation line names the agent role that owns the fix
(per CLAUDE.md's ownership table), never "the team" or "whoever's available."

**The infinite decision tree leaf** — "if none of the above, investigate further" is an
admission the tree wasn't finished. Every unresolved branch needs a named escalation, not
an open door. If the author genuinely does not know what to do in a case, that is a signal
to involve the owning agent before the runbook ships, not after the incident fires.

**Impact statements in internal jargon** — "consumer lag exceeds SLO threshold on partition 3"
tells Shafi nothing about whether customers are affected right now. Translate to product terms:
"compliance scan results may be delayed by up to 4 hours for customers in the affected tenant."

**Runbooks that never get drilled** — authored once, referenced in an alert, never followed
until a real incident — which is the worst possible first test. An untested runbook is a
hypothesis (SKILL.md's freshness SLA rule). Drill cadence applies to runbooks exactly as it
applies to backups.

**Fixing app bugs in the runbook itself** — a remediation step that patches a ConfigMap to
work around an application defect (rather than escalating for a real code fix) is the
platform-engineer quietly overstepping its "operates, never patches app code" boundary. It
hides the defect from the team that owns it and creates config drift that will bite again.

**Treating the runbook update as the postmortem** — after a SEV1 or SEV2 incident, noting
"step 4 had a wrong command" in the runbook is a runbook update. It is not a blameless
postmortem. The postmortem is a separate artifact (owned by `incident-management`) with a
timeline and multiple contributing factors. Conflating them means the structural causes of
the incident are never surfaced or acted on.

**No execution log maintained** — without a per-procedure execution log, the monthly review
cannot check the toil threshold, and the freshness SLA cannot be verified for frequently-executed
procedures. The execution log is mandatory, not optional.

---

## Output Format

The agent produces the runbook library index and individual runbook files:

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
|-------|----------|-------------|--------------|--------|
| [AlertName] | page | runbooks/[service]/[slug].md | [date] | verified |

## Per-Procedure Runbooks
| Procedure | Runbook path | Last drilled | Status |
|-----------|-------------|--------------|--------|
| deploy | runbooks/ops/deploy.md | [date] | verified |
| rollback | runbooks/ops/rollback.md | [date] | verified |
| restore | runbooks/ops/restore.md | [date] | verified |
| tenant-provision | runbooks/ops/tenant-provision.md | [date] | verified |
| tenant-deprovision | runbooks/ops/tenant-deprovision.md | [date] | verified |

## Coverage Check
[Output of check-runbook-links.sh — all runbook_url references resolved]

## Toil Threshold Review
| Procedure | Trailing 4-week execution count | Threshold | Action |
|-----------|--------------------------------|-----------|--------|
| [procedure] | [N] | 12 (3/week × 4 weeks) | escalated to platform-engineering-design |

## Escalation Map
| Symptom class | Owning agent | Rationale |
|---------------|-------------|-----------|

## Drill and Freshness Log
| Date | Runbook | Followed as written? | Correction applied |
|------|---------|----------------------|-------------------|

## Postmortem Record
| Date | Severity | Postmortem owner | Runbook correction PR | Postmortem document |
|------|----------|-----------------|----------------------|---------------------|

## Traceability
[alerting-rules-design alert inventory covered; disaster-recovery-plan procedures covered]
```
