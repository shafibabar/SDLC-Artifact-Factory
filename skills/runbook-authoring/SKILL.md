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
produces: runbook
domain: platform
status: stable
---

# Runbook Authoring

## Purpose

An alert without a runbook turns every incident into improvisation: the on-call reconstructs, from memory or from Slack archaeology, what the last person tried. A runbook replaces improvisation with a rehearsed procedure — copy-pasteable commands, a decision tree that doesn't assume context the reader doesn't have, and a clear line for when the fix is outside the runbook's authority and must escalate.

Two kinds of runbook exist here, and both are mandatory:

1. **Per-alert runbooks** — one for every page-severity alert `alerting-rules-design` defines, fulfilling that skill's `runbook_url` contract. No page ships without one.
2. **Per-procedure runbooks** — deploy, rollback, restore, tenant provisioning/deprovisioning: operations executed on a schedule or on demand, not triggered by an alert, but just as much in need of a rehearsed script.

A runbook that has never been followed under real (or drilled) conditions is a draft, not a runbook — `disaster-recovery-plan`'s "untested backup ≠ backup" rule applies here verbatim: an untested runbook is not a runbook; it is a hypothesis.

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

Every branch terminates. "Investigate further" is not an acceptable leaf — if the tree runs out of known branches, the terminal leaf is a named escalation, not an open-ended instruction to figure it out.

A full annotated decision tree example for the entity-extractor DLQ alert — including branch logic, escalation targets, and post-incident notation — is in `references/runbook-examples-and-quality.md`.

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

## Freshness Discipline and Runbook SLA

A runbook is a claim about how the system currently behaves. Systems change; runbooks that don't change with them lie with confidence, which is worse than a missing runbook because the on-call trusts the wrong instructions.

- **Runbooks are tested during drills**, exactly as backups are (`disaster-recovery-plan`). A DR or rollback drill that follows the written runbook step-by-step *is* the freshness test.
- **A stale runbook found during a drill counts as a failed drill.** If step 3 references a command that no longer exists, the drill did not pass just because the on-call improvised past it — the drill record shows a fail, and the runbook is corrected before the next scheduled run.
- **Runbooks are versioned alongside the systems they describe.** A chart or pipeline change that alters an operational command updates the runbook in the same PR, the same way a schema change updates its migration.

### Runbook SLA — Freshness as a Service Level

Each runbook carries an implied freshness SLA determined by execution frequency:

- **Frequently-executed procedures** (more than 3 executions per week): verified against the current system state after every execution. Any discrepancy found during execution is recorded as a corrective-action item in the post-procedure note — not adapted on the fly and forgotten.
- **Rarely-executed procedures** (at or below the 3x/week threshold): verified against the current system state at least once per quarter, aligned with the DR drill cadence.
- **Never-tested runbooks**: a runbook that has not been followed under real or drilled conditions is a hypothesis, not a runbook. "I wrote it thoughtfully" is not a test; one successful execution or drill where the procedure was followed as written is the minimum bar.

### Post-Incident Hook and Blameless Postmortem

Every real incident closes with a note against the runbook used — worked as written / needed a correction / didn't cover this case. This note is a corrective action on the runbook document. **It is not the same as a blameless postmortem, and cannot substitute for one.**

For any **SEV1 or SEV2 incident**, the post-incident hook must also trigger a blameless postmortem, owned by the `incident-management` skill:

- The blameless postmortem captures: a complete incident timeline, multiple contributing factors (not a single root cause), and corrective actions with owners and target dates — written so a reader understands what happened without individual blame.
- The runbook edit is one corrective action *inside* the postmortem, not the postmortem itself.
- A team that only updates the runbook after a SEV1 has performed housekeeping, not a blameless review.

For SEV3 and below, the post-procedure correction note alone is sufficient — a full postmortem is not required, but the note must still be recorded.

---

## Toil Threshold — When a Runbook Step Signals an Automation Gap

Any runbook procedure executed more than **3 times per week consistently** has crossed the **toil threshold**. At or above that frequency, the procedure is no longer an exceptional operation — it is undifferentiated, manual, recurring work that has exceeded its viable operational lifetime.

The runbook's **per-procedure execution log** tracks execution date and frequency. The monthly runbook review checks each procedure's execution frequency against the threshold:

| Frequency | Action |
|---|---|
| Below 3x/week | Continue drilling on the quarterly cadence; verify freshness on the SLA schedule |
| At or above 3x/week consistently | Escalate immediately as a **platform automation candidate** to `platform-engineering-design`, with the execution log as evidence |

The escalation goal: convert the manual procedure into a self-service platform capability — a CLI command, a CRD, a GitOps-triggerable workflow — not to execute it more efficiently. A rollback procedure executed three times in one week is not a sign of operational maturity; it is a platform design gap. A runbook step executed 20 times without change is an automation gap that `platform-engineering-design`'s toil-reduction lens must address.

---

## References

Full worked example (entity-extractor DLQ alert), quality criteria, anti-patterns, output format, and execution log template: `references/runbook-examples-and-quality.md`
