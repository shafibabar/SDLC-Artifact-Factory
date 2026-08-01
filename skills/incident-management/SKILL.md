---
name: incident-management
description: >
  Teaches blameless incident management — the incident severity taxonomy, the on-call response protocol, and the blameless postmortem artifact: timeline construction, multiple contributing factors (never a single root cause), corrective actions with owners and target dates, and the just-culture principle that maximises honest disclosure. The artifact type the runbook-authoring post-incident hook feeds into, distinct from a runbook edit. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","incident-response","postmortem","blameless","on-call","reliability","sre"]
produces: blameless-postmortem
domain: platform
status: stable
---

# Incident Management

This skill governs two complementary activities: **responding to incidents** when they occur, and **reviewing them afterward** in a way that produces lasting improvement. The response side is governed by the severity taxonomy and on-call protocol; the review side produces the blameless postmortem artifact.

---

## Scope Boundaries

This skill owns:
- The incident severity taxonomy (SEV1–SEV4)
- The on-call response protocol
- The **blameless postmortem** artifact: when to write one, what it contains, and how it differs from a runbook note

This skill does **not** own:
- The runbook itself — `runbook-authoring` owns per-procedure remediation steps; its post-incident hook ("did the runbook need editing?") is a lightweight runbook update, not a postmortem
- Alert definitions, burn-rate tables, or monthly alert hygiene — `alerting-rules-design` owns those; postmortem corrective actions may feed alert changes back into that skill
- SLO spend policy — `slo-definition` owns "when budget is exhausted, deploys pause"; the postmortem records the incident's budget impact, but the policy itself lives there

---

## Incident Severity Taxonomy

| Severity | Condition | Response SLA | Communications |
|---|---|---|---|
| **SEV1** | Complete service unavailability or confirmed data loss | Immediate — acknowledge within 5 minutes, all available hands | Status page updated within 10 min; stakeholder notification within 15 min |
| **SEV2** | Significant degradation affecting the majority of users; no data loss | Acknowledge within 15 minutes | Status page updated within 30 min |
| **SEV3** | Partial degradation; a workaround is available | Acknowledge within 2 hours | Internal tracking ticket; no immediate status page update required |
| **SEV4** | Minor issue with no user-visible impact; cosmetic or edge-case | Tracked and scheduled; no on-call response required | Filed as a regular engineering ticket |

Full escalation paths and communications templates for each level: `references/severity-and-response-protocol.md`.

---

## Postmortem Trigger Criteria

A blameless postmortem is **mandatory** (not discretionary) when any of these is true at incident close:

1. User-visible downtime or degradation beyond SEV2 threshold
2. Any confirmed data loss (any quantity)
3. A page was acknowledged and a human actively intervened
4. Time-to-resolve exceeded 30 minutes
5. **Monitoring failure**: the incident was detected by a customer report, a routine check, or colleague observation — not by an alert firing. This is the most important trigger, because a monitoring gap revealed is more valuable than a known alert working correctly.
6. A repeat of a previously postmortem'd incident (indicates an action item was not completed or was ineffective)

SEV4 incidents do not trigger a mandatory postmortem. SEV3 incidents trigger one only if criteria 4, 5, or 6 apply.

---

## Blameless Postmortem — Artifact Structure

The postmortem is a **learning artifact**, not a blame artifact. Its purpose is to build the most accurate, complete picture of what happened so corrective actions address systemic conditions rather than individual errors.

### Required Sections (in order)

| Section | Contents |
|---|---|
| **Summary** | Incident title, date, duration, severity level, author, SLO budget consumed |
| **Impact** | User-facing statement: what users experienced, how many tenants or requests were affected, for how long — not internal technical metrics |
| **Detection** | How was this actually noticed? Options: alert fired, customer reported it, routine check, colleague observation. "Customer reported it, no alert fired" is a structured trigger to write a new symptom-based alert in `alerting-rules-design` |
| **Timeline** | Minute-by-minute sequence of events, detections, actions, communications — facts only, no interpretation, no attribution of blame |
| **Contributing Factors** | 2–6 systemic conditions (see below) |
| **What Went Well** | Things that limited impact or accelerated recovery — never omit this; it surfaces practices worth reinforcing |
| **Where We Got Lucky** | Near-misses that worked out by chance — a distinct category that "what went wrong" alone would never surface |
| **Action Items** | Specific, owned, dated, measurable tasks tracked to actual closure |

**What a postmortem is not:** a runbook correction (that goes in `runbook-authoring`'s post-incident note), an alert threshold change (that goes in `alerting-rules-design` as a separate corrective-action-driven change), or a blame document for an individual.

Full fill-in template with a worked example: `references/postmortem-template.md`.

---

## Contributing Factors — Core Rule

**A postmortem must never identify a single root cause.** Incidents are multi-causal; a singular root cause is a proxy for assigning blame, which suppresses the honest disclosure the review depends on.

Contributing factors are **systemic conditions**, not individual actions. Phrase them as states of the system, not decisions of a person:

| Blameful (do not write) | Blameless (write this instead) |
|---|---|
| "Alice forgot to add a circuit breaker" | "The service had no circuit breaker between the API layer and the downstream schema registry" |
| "Bob deployed without running the migration dry-run" | "The deployment pipeline did not enforce a dry-run gate before schema migrations" |
| "The on-call engineer missed the alert" | "The alert fired only at INFO level; no paging channel received it" |

Two to six contributing factors is the target range. Fewer than two suggests the analysis stopped too early. More than six usually means contributing factors were not grouped at the right level of abstraction.

Full identification method (5-Whys adapted for blameless culture) and anti-patterns: `references/contributing-factors-guide.md`.

---

## Just-Culture Principle

Blameless does not mean consequence-free — it means the review is **optimised for learning, not punishment**. The counter-intuitive finding from both Etsy and Google's postmortem practices: teams that are safe to admit mistakes report *more* errors and near-misses, not fewer. Visibility increases, incident rate does not. An engineer who fears punishment will omit the one detail that would have made the corrective action effective.

Practically: the person who caused a contributing factor (by taking an action the system allowed them to take, in conditions the system created) is usually one of the best sources of information about what actually happened. Treat them as a witness, not a defendant.

---

## Action Items — Completion Discipline

A postmortem is not complete when the document is written. It is complete when its **high-priority action items close**. Each action item must have:

- A specific, measurable completion criterion (not "add more monitoring" — instead "add an alert for consumer group lag >10,000 messages, firing within 5 minutes of threshold breach")
- A named owner (an agent role, not "the team")
- A target date
- A tracking issue link

Low action-item completion rates are an organizational health signal worth escalating. Schedule a review of open items at 30 days and 90 days.

---

## Connection to Adjacent Skills

| Adjacent Skill | Relationship |
|---|---|
| `runbook-authoring` | Postmortem → runbook update: the postmortem decides *what* to change; runbook-authoring's post-incident hook records *that* the runbook was checked. The postmortem is upstream and separate from the runbook note. |
| `alerting-rules-design` | Detection field "no alert fired" → new alert ticket. Action items that include alert changes feed back into `alerting-rules-design`. |
| `slo-definition` | Summary section records error-budget consumed by the incident. Policy on when deploys pause is `slo-definition`'s domain. |
| `disaster-recovery-plan` | SEV1 incidents involving data loss or regional failure may activate the DR plan; the postmortem reviews whether the DR plan worked. |
