---
name: runbook-authoring
description: >
  Teaches runbook authoring — one runbook per alert honoring
  alerting-rules-design's runbook_url contract plus per-procedure runbooks
  (deploy, rollback, restore, tenant provisioning/deprovisioning), the
  standard runbook anatomy (trigger, product-terms impact statement,
  copy-pasteable verification commands, a remediation decision tree, and an
  escalation line that names the owning agent per CLAUDE.md's agent
  boundaries), the style rules that keep runbooks imperative and free of
  tribal knowledge, and the freshness discipline that treats a stale runbook
  as a failed drill. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, runbooks, on-call, incident-response, escalation, drills]
---

# Runbook Authoring

## Purpose

An alert without a runbook turns every incident into improvisation: the on-call reconstructs, from memory or from Slack archaeology, what the last person tried. A runbook replaces improvisation with a rehearsed procedure — copy-pasteable commands, a decision tree that doesn't assume context the reader doesn't have, and a clear line for when the fix is outside the runbook's authority and must escalate.

Two kinds of runbook exist here, and both are mandatory:

1. **Per-alert runbooks** — one for every page-severity alert `alerting-rules-design` defines, fulfilling that skill's `runbook_url` contract. No page ships without one.
2. **Per-procedure runbooks** — deploy, rollback, restore, tenant provisioning/deprovisioning: operations executed on a schedule or on demand, not triggered by an alert, but just as much in need of a rehearsed script.

A runbook that has never been followed under real (or drilled) conditions is a draft, not a runbook — `disaster-recovery-plan`'s "untested backup ≠ backup" rule applies here verbatim: an untested runbook is not a runbook.

---

## Runbook Anatomy

Every runbook, alert-triggered or procedural, has the same five sections, in this order:

| Section | Answers | Audience |
|---|---|---|
| **Trigger** | What fired, and where to see it live (alert name, dashboard link, or the manual condition that starts a procedure) | On-call, orienting |
| **Impact statement** | What does this mean for the product, in terms a PM understands — not "consumer lag high," but "compliance findings are arriving late; customers may see a stale dashboard" | Anyone assessing severity, including Shafi if the incident surfaces |
| **Verification steps** | Exact, copy-pasteable commands that confirm the diagnosis before acting | On-call, executing |
| **Remediation decision tree** | Branches on what verification found, each branch ending in either a fix or an escalation | On-call, executing |
| **Escalation line** | Who owns the fix if this runbook's authority ends — named by agent role per CLAUDE.md's ownership boundaries, never "ask around" | On-call, when blocked |

A sixth, implicit section binds every runbook together: the **post-incident hook** — closing an incident triggers a note back into the runbook (did it work, did a step need updating) so runbooks improve from real use instead of decaying from neglect.

---

## Style Rules

- **Imperative, not descriptive.** "Run `kubectl get pods -n tenant-acme`" — not "you might want to check the pods." A runbook gives instructions, it does not muse.
- **Copy-pasteable commands, with placeholders marked.** Every command block is runnable as written except for explicitly bracketed values (`[TENANT_ID]`), never prose describing a command in words.
- **No tribal knowledge.** If a step assumes "you know the DB password is in Vault under `secret/data/[tenant]/postgres`" — say that, don't assume it. The test: could someone who joined yesterday follow this at 3 a.m. without pinging anyone?
- **PM-comprehensible impact line.** The impact statement is the one section Shafi (or any PM) reads without translation — no metric names, no internal service jargon, just what a customer would notice and how bad it is.
- **One page, one screen where possible.** A runbook that requires scrolling through six unrelated procedures to find the relevant branch slows down exactly the moment speed matters most. Long procedures split into linked, single-purpose runbooks.
- **Dated and versioned like any artifact** (CLAUDE.md's frontmatter standard) — a runbook with no `created`/`version` cannot be checked for staleness.

---

## Per-Alert Runbooks — the `runbook_url` Contract

`alerting-rules-design` requires every page-severity alert to carry a live `runbook_url` annotation. This skill is what makes that link resolve to something real:

```yaml
# from alerting-rules-design — the contract this skill fulfills
annotations:
  runbook_url: "runbooks/pipeline/dlq-drain.md"
```

Rule: **the runbook is authored and reviewed in the same PR that introduces the alert.** An alert merged with a `runbook_url` pointing at a file that doesn't exist yet is exactly the "page without a procedure" anti-pattern `alerting-rules-design` forbids — CI checks that every `runbook_url` referenced in a rules file resolves to a real file in the repo:

```bash
#!/usr/bin/env bash
# check-runbook-links.sh — CI gate on any PR touching prometheus/rules/*.yaml
for f in prometheus/rules/*.yaml; do
  yq '.groups[].rules[].annotations.runbook_url // empty' "$f" | while read -r url; do
    [ -f "$url" ] || { echo "MISSING RUNBOOK: $url referenced by $f" >&2; exit 1; }
  done
done
```

---

## Per-Procedure Runbooks

Not every runbook is reactive. Four procedures always get one, regardless of whether any alert triggers them:

| Procedure | Trigger | Ties to |
|---|---|---|
| **Deploy** | New release ready to promote | `cd-pipeline`'s promotion flow — the runbook is the human-readable narration of what the pipeline automates, for the moments automation needs a human decision |
| **Rollback** | A promotion needs reverting | `cd-pipeline`'s git-revert model; `blue-green-deployment`'s selector-revert; `canary-deployment`'s weight-revert — one runbook per strategy in use |
| **Restore** | A DR drill or a real incident | `disaster-recovery-plan`'s restore procedures, expressed as an executable runbook rather than a prose plan |
| **Tenant provisioning / deprovisioning** | New tenant onboarded, or a tenant offboards | `opentofu-module`'s per-tenant stamping; deprovisioning ties to `data-retention-policy`'s crypto-shred-on-offboard step |

These are drilled on the same cadence as DR (`disaster-recovery-plan`'s quarterly rhythm) even when no incident forces the issue — a rollback runbook nobody has followed since it was written is no more trustworthy than an untested backup.

---

## Remediation Decision Trees

The decision tree is what separates a runbook from a wiki page: it branches on what verification actually found, and every leaf is either "fixed, confirm resolution" or "escalate, to whom." A tree with a leaf that just says "investigate further" has not finished being written.

```
Verification found consumer lag growing AND DLQ empty
├── Is the downstream dependency (compliance-engine) healthy?
│   ├── NO  → dependency outage; this is not entity-extractor's fault
│   │         → escalate: backend-engineer (compliance-engine), page as dependent-service incident
│   └── YES → check consumer replica count vs partition count
│       ├── Replicas < partitions, autoscaler not keeping up
│       │         → FIX: scale replicas manually (kubectl scale, values PR to follow)
│       └── Replicas = partitions, still lagging
│                 → throughput-per-replica has dropped; check recent deploys
│                 → recent deploy on entity-extractor?
│                     ├── YES → suspect regression; canary-deployment auto-rollback should have caught this —
│                     │         if it didn't, escalate: platform-engineer (canary gate failure)
│                     └── NO  → escalate: backend-engineer (entity-extractor), unexplained throughput drop
```

Every branch terminates. "Investigate further" is not an acceptable leaf — if the tree runs out of known branches, the terminal leaf is an escalation, not an open-ended instruction to figure it out.

---

## Escalation Lines — Named by Owning Agent

Escalation names the **agent role that owns the fix**, per CLAUDE.md's agent boundaries — never "the team" or "whoever's around." This mirrors the platform-engineer's own rule: it operates what other agents build and never patches application code to fix an operational problem.

| Symptom class | Escalates to | Because |
|---|---|---|
| Application logic bug, unexpected business outcome | The owning feature engineer (`backend-engineer` for the specific service, `frontend-engineer` for UI) | App defects are fixed in app code, never patched around in config — CLAUDE.md's component boundary |
| Infrastructure, pipeline, chart, or observability config issue | `platform-engineer` (self) | Within this agent's own domain — the runbook resolves it directly |
| Security control failure (auth, ABAC, secrets) | `security-engineer` | Owns control internals; platform-engineer operates the sidecars, not the policy |
| Data model, retention, or lineage inconsistency | `data-architect` | Owns the contracts platform purge jobs execute against |
| Architecture-level capacity or SLO-unachievable finding | Shafi, via the platform-engineer's own escalation rule | A product/spend decision, not an operational fix |

A runbook that ends every failing branch in "escalate: platform-engineer" for a problem that is actually an application bug just relocates the improvisation one level up. Naming the correct owner is part of the runbook's job, not an afterthought.

---

## Freshness Discipline

A runbook is a claim about how the system currently behaves. Systems change; runbooks that don't change with them lie with confidence, which is worse than a missing runbook because the on-call trusts the wrong instructions.

- **Runbooks are tested during drills**, exactly as backups are (`disaster-recovery-plan`). A DR or rollback drill that follows the written runbook step-by-step *is* the freshness test.
- **A stale runbook found during a drill counts as a failed drill.** If step 3 references a command that no longer exists, the drill did not pass just because the on-call improvised past it — the drill record shows a fail, and the runbook is corrected before the next scheduled run.
- **Runbooks are versioned alongside the systems they describe.** A chart or pipeline change that alters an operational command (`kubectl rollout status deploy/X` → a renamed Deployment) updates the runbook in the same PR, the same way a schema change updates its migration.
- **The post-incident hook**: every real incident closes with a note against the runbook used — worked as written / needed a correction / didn't cover this case — feeding directly into the next drill or the next PR.

---

## Worked Example — DLQ Depth Alert for entity-extractor

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

## Post-Incident
[Filled in after each use: date, on-call, which branch was taken, whether the
runbook needed correction — feeds the next quarterly drill review.]
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Coverage | Every page-severity alert has a `runbook_url` resolving to a real file | Alerts pointing at nonexistent or placeholder runbooks |
| Procedure coverage | Deploy, rollback, restore, tenant provisioning/deprovisioning each have a runbook | Procedures executed from memory or ad-hoc scripts |
| Anatomy complete | Trigger, impact, verification, decision tree, escalation all present | Missing sections, especially escalation |
| Impact in product terms | A PM can read the impact line and understand customer effect | Metric-name-only impact statements |
| Copy-pasteable | Every command runs as written except bracketed placeholders | Prose descriptions in place of commands |
| Tree terminates | Every branch ends in a fix or a named escalation | "Investigate further" as a leaf |
| Escalation named correctly | Owner is the agent role per CLAUDE.md boundaries | App bugs escalated to platform-engineer; vague "the team" |
| Freshness | Runbook exercised in a drill within the last cycle; corrections applied | Runbook untouched since authoring, unverified against current system |
| Same-PR authoring | Runbook merges in the same PR as the alert/procedure it documents | Alert shipped first, runbook "to follow" |

---

## Anti-Patterns

- **The `runbook_url` that 404s** — an alert shipped with a link to a file that doesn't exist is worse than no link, because it promises help that isn't there at exactly the moment someone is under pressure.
- **Prose in place of commands** — "restart the affected pods" instead of the actual `kubectl rollout restart` invocation forces the on-call to reconstruct the command under pressure, exactly what the runbook exists to prevent.
- **Escalation to "the team" or "on-call"** — the on-call *is* the reader; telling them to escalate to on-call is circular. Name the owning agent role, per the ownership table.
- **The infinite decision tree leaf** — "if none of the above, investigate further" is an admission the tree wasn't finished. Every unresolved branch needs a named escalation, not an open door.
- **Impact statements in internal jargon** — "consumer lag exceeds SLO threshold on partition 3" tells Shafi nothing about whether customers are affected right now; translate to product terms every time.
- **Runbooks that never get drilled** — authored once, referenced in an alert, never followed until a real incident — which is the worst possible first test. Drill cadence applies to runbooks exactly as it applies to backups.
- **Fixing app bugs in the runbook itself** — a remediation step that patches a ConfigMap to work around an application defect (rather than escalating for a real code fix) is the platform-engineer quietly overstepping its "operates, never patches app code" boundary, and it hides the defect from the team that owns it.

---

## Output Format

Produces the runbook library index and individual runbook files:

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

## Per-Procedure Runbooks
| Procedure | Runbook path | Last drilled | Status |

## Coverage Check
[Output of check-runbook-links.sh — all runbook_url references resolved]

## Escalation Map
| Symptom class | Owning agent | Rationale |

## Drill and Freshness Log
| Date | Runbook | Followed as written? | Correction applied |

## Traceability
[alerting-rules-design alert inventory covered; disaster-recovery-plan procedures covered]
```
