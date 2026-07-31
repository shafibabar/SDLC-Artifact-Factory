# Severity Taxonomy and On-Call Response Protocol

This file is self-contained. Use it without needing the parent `SKILL.md` in context.

---

## Overview

The severity taxonomy gives every incident a shared label that sets concrete expectations for response speed, communication, and escalation. Consistent labelling prevents the two failure modes at the extremes: treating every incident as SEV1 (alert fatigue, unsustainable load) and treating every incident as SEV4 (real user impact goes unaddressed for days).

---

## Severity Definitions

### SEV1 — Critical: Complete Service Unavailability or Data Loss

**Trigger conditions (any one is sufficient):**
- The service is completely unavailable to all or substantially all users
- Confirmed or suspected data loss (any quantity — write failures, dropped events, corrupted records)
- An active security breach or confirmed unauthorized data access
- A cascading failure actively spreading to additional services

**Initial response SLA:** Acknowledge within **5 minutes** of alert or report. No other work takes priority.

**Response posture:** All available hands. The on-call engineer immediately opens an incident channel, declares SEV1, and begins the response protocol below.

**Communications:**
- Status page updated with "Investigating" within 10 minutes of declaration
- Stakeholder notification (Shafi, any affected tenant contacts) within 15 minutes
- Status page updates every 15 minutes until resolved
- Resolution update published within 1 hour of full recovery

**Postmortem:** Mandatory, no exceptions. Begin within 24 hours of resolution.

---

### SEV2 — Major: Significant Degradation Affecting Majority of Users

**Trigger conditions:**
- Significant performance degradation (latency p99 > 3× normal, error rate > 5%) affecting the majority of users
- A major feature is unavailable but the service is partially functional
- An integration or dependency failure affecting a large portion of workflow types
- No confirmed data loss, but data integrity is in question

**Initial response SLA:** Acknowledge within **15 minutes** of alert or report.

**Response posture:** On-call engineer investigates immediately; other engineers on standby if the on-call engineer requests help.

**Communications:**
- Status page updated with "Investigating" within 30 minutes of declaration
- Stakeholder notification if impact is sustained beyond 30 minutes
- Status page updates every 30 minutes until resolved
- Resolution update published within 2 hours of full recovery

**Postmortem:** Mandatory unless resolved in under 5 minutes with a known, fully-reversible cause and no SLO budget consumed.

---

### SEV3 — Minor: Partial Degradation with Available Workaround

**Trigger conditions:**
- A subset of users or a non-critical feature is affected
- A workaround exists and has been communicated
- Error rate elevated but below 1%; latency elevated but below 2× normal
- No data loss; no integrity concerns

**Initial response SLA:** Acknowledge within **2 hours** of alert or report.

**Response posture:** On-call engineer investigates at next available opportunity within the response window; no interruption of scheduled work if alert arrives during a focus block.

**Communications:**
- No public status page update required unless impact persists beyond 4 hours
- Internal tracking ticket opened and linked in the on-call log

**Postmortem:** Triggered only if: resolution time exceeded 30 minutes, incident was detected by a customer report or routine check (not an alert), or it is a repeat of a previously postmortem'd incident.

---

### SEV4 — Low: No User-Visible Impact

**Trigger conditions:**
- Cosmetic issue (UI label, log message format)
- Edge-case affecting a tiny fraction of requests with no user-facing symptom
- An alert fired for a condition that self-resolved without intervention
- A build warning or test flakiness that does not affect production

**Initial response SLA:** No on-call response required. File a ticket during regular working hours.

**Response posture:** Scheduled engineering work. Does not interrupt on-call rotation.

**Communications:** None required. Tracked in the engineering backlog.

**Postmortem:** Not required.

---

## Severity Decision Guide

When uncertain between two severity levels, always assign the higher severity and downgrade later if warranted. Upgrading a severity mid-incident is disruptive; starting higher and downgrading is not.

```
Is there confirmed or suspected data loss?
  YES → SEV1

Is the service completely unavailable to all users?
  YES → SEV1

Is the service significantly degraded for the majority of users?
  YES → SEV2 (upgrade to SEV1 if data integrity is in question or degradation is worsening)

Is the service partially degraded with a workaround available?
  YES → SEV3

Is there any user-visible impact at all?
  NO → SEV4
```

---

## On-Call Response Protocol

### Step 1: Acknowledge (within SLA window)

Acknowledge the alert in the alerting system (Alertmanager). This stops the repeat-notification clock. Acknowledging does not mean you have diagnosed the issue — it means you have received the page and are actively working it.

If you cannot acknowledge within the SLA window due to circumstances beyond your control (travel, medical, connectivity), the incident escalates to the backup contact defined in the on-call configuration.

### Step 2: Open Incident Tracking

For SEV1 and SEV2: open an incident tracking entry immediately (a GitHub issue with the `incident` label is sufficient for a solo-operator context). Record:
- Declared severity
- UTC timestamp of declaration
- First observed symptom
- Current hypothesis (can be empty at declaration time)

This is the seed of the postmortem timeline. Every subsequent action, decision, and observation is appended to this entry in real time as you work the incident. Do not reconstruct from memory after the fact — the reconstruction is always less accurate than the real-time notes.

### Step 3: Diagnose (Four Golden Signals First)

Before investigating specific components, check the four golden signals in order:

1. **Errors** — What is the error rate, and is it rising? Which endpoints or operations are failing?
2. **Latency** — Is p99 elevated? Does it track with the error rate or is it independent?
3. **Traffic** — Is traffic volume normal? An anomalous spike or a sudden drop are both signals.
4. **Saturation** — Is any resource approaching its limit? Check DB connection pool utilization, consumer group lag, disk usage, memory pressure.

The signal that is anomalous first narrows the hypothesis space. Do not skip to component-specific investigation until you have oriented on which signal is the primary one.

### Step 4: Form and Test Hypotheses

Use the `runbook-authoring` skill's diagnostic trees for known symptom patterns. For novel situations:

1. State the hypothesis explicitly: "I believe the issue is X because of observation Y."
2. Identify the fastest check that would confirm or refute it.
3. Perform the check.
4. Either confirm and proceed to mitigation, or refute and form the next hypothesis.

Do not take mitigation actions (restarts, rollbacks, configuration changes) until you have a confirmed hypothesis. Undirected remediation actions generate noise in the timeline and can mask the actual signal.

### Step 5: Mitigate

Prefer reversible mitigations over permanent fixes during an active incident:
- **Rollback** over hotfix (faster; restores a known-good state)
- **Feature flag disable** over code change (no deployment required)
- **Traffic rerouting** over instance restart (less state disruption)
- **Rate limiting** over kill-and-restart (preserves in-flight requests)

Record every mitigation action in the incident tracking entry with its UTC timestamp and the rationale.

### Step 6: Confirm Recovery

Recovery is confirmed when all three conditions are met:
1. Error rate has returned to baseline (below SLO threshold)
2. Latency has returned to normal range
3. All affected services have confirmed normal operation (not just the primary service)

Do not declare recovery based on a single check. Run the same checks that confirmed the incident at the start and verify each is in normal range.

### Step 7: Update Communications

- Update the status page to "Resolved" with a brief, user-facing description of what happened and that it is fixed.
- Notify any stakeholders who received the initial notification.
- Close the on-call alert in the alerting system.

### Step 8: Trigger Postmortem (if applicable)

Apply the postmortem trigger criteria from the parent `SKILL.md`:
1. User-visible downtime or degradation beyond SEV2
2. Any confirmed data loss
3. A page was acknowledged and a human actively intervened
4. Time-to-resolve exceeded 30 minutes
5. Incident detected by something other than monitoring
6. Repeat of a previously postmortem'd incident

If any criterion is met: open the postmortem document within 24 hours, using the template in `references/postmortem-template.md`.

---

## Escalation Paths

### Primary Escalation Path (SEV1 and SEV2)

| Step | Action | Timing |
|---|---|---|
| 1 | On-call acknowledges and begins investigation | Within SLA window |
| 2 | On-call posts initial diagnosis to incident channel | Within 15 min of acknowledgement |
| 3 | On-call requests additional resources if diagnosis is not progressing | After 20 min without a confirmed hypothesis |
| 4 | Notify Shafi (stakeholder) | SEV1: at declaration; SEV2: at 30 min if unresolved |
| 5 | Consider external escalation (cloud provider support, vendor) | Only after internal diagnosis exhausted |

### Unacknowledged Alert Escalation

An unacknowledged alert is the on-call failure mode with the highest risk. Configure Alertmanager's `repeat_interval` for SEV1 to fire again every 5 minutes. After three repeat firings with no acknowledgement (15 minutes total), send a notification to the backup channel (e.g. a different messaging app, email, or SMS — a distinct channel from the primary paging route).

For a solo-operator context: document an explicit answer to "what happens if I am unavailable for a SEV1?" The answer must be concrete (not "someone else will handle it") — options include: a scheduled Alertmanager silence with a defined reinstatement procedure, an automated runbook that performs a pre-authorized safe action (scale up the affected service; activate a feature flag; initiate a rollback), or a defined stakeholder notification that communicates the incident and sets expectations.

---

## Communications Templates

### SEV1 Initial Status Page Update

```
[Investigating] We are currently investigating reports of [user-facing symptom, e.g. "document
ingestion failures"]. Our engineering team has been notified and is actively investigating.
We will provide an update within 15 minutes.

Incident start: [HH:MM UTC]
```

### SEV1 Ongoing Update (every 15 minutes)

```
[Update — HH:MM UTC] We continue to investigate [symptom]. We have identified [brief, non-technical
description of what we know, e.g. "a component affecting document processing"] and are working on
a fix. Our next update will be in 15 minutes.
```

### SEV1/SEV2 Resolution

```
[Resolved — HH:MM UTC] The issue affecting [symptom] has been resolved. Service has been fully
restored as of [HH:MM UTC]. [Optional: one sentence on what was done, e.g. "We rolled back a
configuration change that was causing processing failures."]

We will be conducting a full review of this incident and will publish a summary of our findings.
Total impact duration: [HH min].
```

### SEV2 Initial Stakeholder Notification

```
Subject: [SEV2] [Brief description of impact]

We are currently experiencing [brief user-facing description of impact] affecting [scope, e.g.
"document ingestion for all tenants"]. Our on-call engineer is actively investigating.

Current status: Investigating
Estimated impact: [e.g. "Document submission is delayed; submitted documents will be processed
once the issue is resolved. No data loss is expected."]
Next update: [time, e.g. "in 30 minutes or sooner if resolved"]

We will notify you when the issue is resolved.
```

---

## On-Call Hygiene

### Alert Volume as a System Health Signal

If any given week produces more than 3–5 genuine pages requiring active intervention, that volume is itself a trigger for an unscheduled alert-hygiene pass — do not wait for the monthly `alerting-rules-design` review cadence. Apply the SRE principle: on-call load is a measurable signal that the system (or its alert configuration) is unhealthy, not a personal endurance benchmark.

### Sustainable On-Call Load (Solo-Operator Version)

Google's SRE book recommends that on-call-related reactive work should not exceed 25–50% of total engineering time. For a solo operator, a practical weekly heuristic: if on-call response plus associated toil (restarting services, manual cleanup, incident-tracking updates) is consuming more than half a working day per week, that is an automation deficit worth escalating to Shafi as a resourcing or tooling decision, not a condition to absorb indefinitely.

### Post-Incident Toil Tracking

After each paged incident, before closing the incident tracking entry, answer:
- "Did resolving this require the same manual steps as the last time this symptom appeared?"
- If yes, and this is the third or more repetition: the manual steps are a toil candidate. Open a ticket to automate them or to make the system self-heal.

This converts the `alerting-rules-design` monthly review's "did a human act?" question into a forward-looking automation trigger.

---

## Runbook Relationship

The on-call response protocol tells you *how* to respond to an incident. The runbook for a specific symptom tells you *what steps to take* for that symptom. These are distinct documents:

- This skill's response protocol governs the meta-level behavior: acknowledge, orient, hypothesize, mitigate, confirm, communicate.
- `runbook-authoring`'s per-symptom runbooks govern the object-level steps: "if consumer group lag is >X, run this command."

During an active incident, the response protocol is the outer loop; the runbook is consulted at Step 4 (hypothesize) and Step 5 (mitigate). The postmortem produced afterward feeds both: it may generate a new runbook for a novel symptom or a correction to an existing runbook, and it produces corrective actions that go into the engineering backlog.
