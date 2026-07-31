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
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, runbooks, on-call, incident-response, escalation, drills]
related: [incident-management, platform-engineering-design, alerting-rules-design, disaster-recovery-plan]
---

# Runbook Authoring

## Purpose

An alert without a runbook turns every incident into improvisation: the on-call reconstructs, from memory or from Slack archaeology, what the last person tried. A runbook replaces improvisation with a rehearsed procedure — copy-pasteable commands, a decision tree that doesn't assume context the reader doesn't have, and a clear line for when the fix is outside the runbook's authority and must escalate.

Two kinds of runbook exist here, and both are mandatory:

1. **Per-alert runbooks** — one for every page-severity alert `alerting-rules-design` defines, fulfilling that skill's `runbook_url` contract. No page ships without one.
2. **Per-procedure runbooks** — deploy, rollback, restore, tenant provisioning/deprovisioning: operations executed on a schedule or on demand, not triggered by an alert, but just as much in need of a rehearsed script.

An untested runbook is not a runbook — `disaster-recovery-plan`'s "untested backup ≠ backup" rule applies here verbatim.

---

## Runbook Anatomy

Every runbook, alert-triggered or procedural, has the same five sections, in this order:

| Section | Answers | Audience |
|---|---|---|
| **Trigger** | What fired, and where to see it live (alert name, dashboard link, or the manual condition that starts a procedure) | On-call, orienting |
| **Impact statement** | What does this mean for the product, in terms a PM understands — not "consumer lag high," but "compliance findings are arriving late; customers may see a stale dashboard" | Anyone assessing severity |
| **Verification steps** | Exact, copy-pasteable commands that confirm the diagnosis before acting | On-call, executing |
| **Remediation decision tree** | Branches on what verification found, each branch ending in either a fix or an escalation | On-call, executing |
| **Escalation line** | Who owns the fix if this runbook's authority ends — named by agent role per CLAUDE.md's ownership boundaries, never "ask around" | On-call, when blocked |

A sixth, implicit section binds every runbook together: the **execution log** — every time the runbook is followed, the date, on-call, and outcome are recorded. This log feeds the post-incident hook, the toil threshold check, and the freshness SLA verification.

---

## Style Rules

- **Imperative, not descriptive.** "Run `kubectl get pods -n tenant-acme`" — not "you might want to check the pods."
- **Copy-pasteable commands, with placeholders marked.** Every command block is runnable as written except for explicitly bracketed values (`[TENANT_ID]`), never prose describing a command.
- **No tribal knowledge.** If a step assumes "you know the DB password is in Vault under `secret/data/[tenant]/postgres`" — say that. The test: could someone who joined yesterday follow this at 3 a.m. without pinging anyone?
- **PM-comprehensible impact line.** No metric names, no internal service jargon — what a customer would notice and how bad it is.
- **One page, one screen where possible.** Long procedures split into linked, single-purpose runbooks.
- **Dated and versioned like any artifact** (CLAUDE.md's frontmatter standard) — a runbook with no `created`/`version` cannot be checked for staleness.

---

## Per-Alert Runbooks — the `runbook_url` Contract

`alerting-rules-design` requires every page-severity alert to carry a live `runbook_url` annotation. This skill is what makes that link resolve to something real:

```yaml
annotations:
  runbook_url: "runbooks/pipeline/dlq-drain.md"
```

Rule: **the runbook is authored and reviewed in the same PR that introduces the alert.** CI checks that every `runbook_url` referenced in a rules file resolves to a real file in the repo:

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

Not every runbook is reactive. Four procedures always get one:

| Procedure | Trigger | Ties to |
|---|---|---|
| **Deploy** | New release ready to promote | `cd-pipeline`'s promotion flow |
| **Rollback** | A promotion needs reverting | `cd-pipeline`'s git-revert model; `blue-green-deployment`'s selector-revert; `canary-deployment`'s weight-revert |
| **Restore** | A DR drill or a real incident | `disaster-recovery-plan`'s restore procedures |
| **Tenant provisioning / deprovisioning** | New tenant onboarded, or a tenant offboards | `opentofu-module`'s per-tenant stamping; `data-retention-policy`'s crypto-shred-on-offboard step |

These are drilled on the same cadence as DR (`disaster-recovery-plan`'s quarterly rhythm) even when no incident forces the issue.

---

## Remediation Decision Trees

The decision tree branches on what verification actually found, and every leaf is either "fixed, confirm resolution" or "escalate, to whom." A tree with a leaf that says "investigate further" has not finished being written.

Every branch terminates. "Investigate further" is not an acceptable leaf — if the tree runs out of known branches, the terminal leaf is an escalation, not an open-ended instruction to figure it out.

See `references/runbook-template-and-examples.md` for a complete worked example showing a full decision tree with all terminating branches.

---

## Escalation Lines — Named by Owning Agent

Escalation names the **agent role that owns the fix**, per CLAUDE.md's agent boundaries — never "the team" or "whoever's around."

| Symptom class | Escalates to | Because |
|---|---|---|
| Application logic bug, unexpected business outcome | The owning feature engineer (`backend-engineer`, `frontend-engineer`) | App defects are fixed in app code, never patched around in config |
| Infrastructure, pipeline, chart, or observability config issue | `platform-engineer` (self) | Within this agent's own domain |
| Security control failure (auth, ABAC, secrets) | `security-engineer` | Owns control internals |
| Data model, retention, or lineage inconsistency | `data-architect` | Owns the contracts platform purge jobs execute against |
| Architecture-level capacity or SLO-unachievable finding | Shafi, via platform-engineer's escalation rule | A product/spend decision, not an operational fix |

---

## Freshness Discipline and Runbook SLA

A runbook is a claim about how the system currently behaves. Systems change; runbooks that don't change with them lie with confidence.

**Verification cadence — the runbook's implied freshness SLA:**

| Execution frequency | Freshness SLA |
|---|---|
| Rarely executed (< 1/month) | Must be verified against the current system state at least **quarterly** — the same cadence as DR drills |
| Frequently executed (≥ 1/week) | Must be verified **after every execution** — the execution log IS the freshness record |
| Never executed since authoring | Not a runbook — it is a hypothesis. Must be drilled before it can be referenced in a live alert's `runbook_url` |

- **Runbooks are tested during drills** — a DR or rollback drill that follows the written runbook step-by-step *is* the freshness test.
- **A stale runbook found during a drill counts as a failed drill.** If step 3 references a command that no longer exists, the drill did not pass just because the on-call improvised past it.
- **Runbooks are versioned alongside the systems they describe.** A chart change that alters an operational command updates the runbook in the same PR.

---

## Toil Threshold

Every runbook procedure carries an **execution log** (date, on-call, outcome, frequency). The monthly review checks this log against the toil threshold:

**If a runbook procedure is executed more than 3 times per week consistently, it has crossed the toil threshold.**

At that point, the procedure must be escalated as a **platform automation candidate** to `platform-engineering-design`. The runbook is not deleted — it remains the fallback if automation is not yet in place — but the procedure's frequency signals that a human is repeatedly doing what a button, CLI command, or CRD controller should be doing.

Mechanics:
- The per-runbook execution log records frequency per procedure (not just "was it used?").
- The monthly runbook review checks every procedure's trailing-4-week frequency.
- Any procedure exceeding 3 executions/week for 2 consecutive months is written up as a platform automation request, referencing the `platform-engineering-design` skill's automation-candidate escalation path.
- A runbook step executed 20+ times without change is not a runbook step — it is an automation gap.

---

## Post-Incident Hook — Runbook Update vs. Blameless Postmortem

The post-incident hook has **two distinct outputs**. Conflating them is a defect:

**Output 1 — Runbook update (always):** After any incident that exercised a runbook, the execution log is updated: did the runbook work as written, did a step need correction, did a branch prove missing? Corrections go into a PR against the runbook file. This is a corrective action against *this document*.

**Output 2 — Blameless postmortem (SEV1 and SEV2 only, owned by `incident-management`):** For any SEV1 or SEV2 incident, the post-incident hook must also trigger a blameless postmortem. A blameless postmortem is not a runbook update — it is a separate artifact with a timeline, multiple contributing factors (never a singular root cause), and corrective actions with owners and target dates. The runbook edit is *one possible corrective action inside the postmortem*, not the postmortem itself.

**The boundary:**

| What it is | Who owns it | Where it lives |
|---|---|---|
| Note that step 4 had a wrong command | `platform-engineer` | PR against `runbooks/*.md` |
| Timeline of contributing factors and corrective actions | `incident-management` skill | Blameless postmortem document |

A post-incident hook that ends with "did the runbook need editing?" has completed the runbook update. It has not completed the postmortem. For SEV1 and SEV2, both must occur. The runbook-authoring skill's responsibility ends at the runbook update; the postmortem is `incident-management`'s artifact.

See DevOps Handbook Ch. 14: blameless postmortems are distinct from the operational documents they exercise.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Coverage | Every page-severity alert has a `runbook_url` resolving to a real file | Alerts pointing at nonexistent or placeholder runbooks |
| Procedure coverage | Deploy, rollback, restore, tenant provisioning/deprovisioning each have a runbook | Procedures executed from memory |
| Anatomy complete | Trigger, impact, verification, decision tree, escalation all present | Missing sections |
| Impact in product terms | A PM can read the impact line and understand customer effect | Metric-name-only impact statements |
| Copy-pasteable | Every command runs as written except bracketed placeholders | Prose descriptions in place of commands |
| Tree terminates | Every branch ends in a fix or a named escalation | "Investigate further" as a leaf |
| Escalation named correctly | Owner is the agent role per CLAUDE.md boundaries | Vague "the team" or wrong agent |
| Freshness SLA met | Rarely-executed runbooks verified quarterly; frequently-executed verified after every use | Runbook untouched since authoring |
| Toil threshold checked | Monthly review flags procedures exceeding 3 executions/week | No execution log maintained |
| Postmortem separation | SEV1/SEV2 triggers a blameless postmortem in addition to runbook correction | Post-incident hook ends at runbook edit for SEV1/SEV2 |
| Same-PR authoring | Runbook merges in the same PR as the alert/procedure it documents | Alert shipped first, runbook "to follow" |

---

See `references/runbook-template-and-examples.md` for: full worked example (DLQ alert runbook), runbook template, anti-patterns, and output format.
