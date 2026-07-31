# Blameless Postmortem Template

This file is self-contained. Use it without needing the parent `SKILL.md` in context.

---

## How to Use This Template

Fill every section. Do not skip "What Went Well" or "Where We Got Lucky" — they surface practices worth reinforcing and near-misses that "what went wrong" alone would never catch. A section left blank is a postmortem left incomplete.

Complete this document within 24–48 hours of incident resolution, while details are fresh. Assign a primary author (usually the incident commander or the engineer who diagnosed the issue) and one reviewer who was not directly involved in the response.

---

## POSTMORTEM TEMPLATE

```markdown
# Postmortem: [Incident Title]

**Date:** YYYY-MM-DD
**Duration:** HH:MM (from first symptom to full recovery)
**Severity:** SEV[1–4]
**Author:** [Role, e.g. platform-engineer]
**Reviewer:** [Role]
**Status:** Draft | In Review | Final
**SLO Budget Consumed:** [e.g. 47 minutes of 201-minute monthly error budget (23%)]

---

## Summary

One or two sentences. What happened, when, for how long, at what severity. Written for a reader
who was not involved and who needs to understand the incident without reading the whole document.

---

## Impact

Describe what users experienced, in user-facing terms — not internal metrics.

| Dimension | Value |
|---|---|
| Affected tenants | [e.g. all tenants / tenants in region X / tenants using feature Y] |
| Affected requests | [e.g. ~8,400 API requests returned 503] |
| Duration | [e.g. 34 minutes, from 14:22 UTC to 14:56 UTC] |
| User symptom | [e.g. document ingestion jobs silently failed and returned a success status code] |
| SLO breach | [yes/no; if yes, how much budget consumed] |

---

## Detection

How was this incident actually noticed? Choose one:

- [ ] Alert fired and paged the on-call engineer
- [ ] Alert fired but did not page (wrong severity / routing misconfiguration)
- [ ] Customer reported it before any alert fired
- [ ] Routine check (e.g. daily dashboard review) surfaced it
- [ ] Colleague observation during unrelated work
- [ ] Discovered during a postmortem for a different incident

**If "customer reported it" or "no alert fired"**: this is a structured trigger to open a new
symptom-based alert ticket in `alerting-rules-design`. Do not leave this in the postmortem as
a note — create the ticket and link it in the Action Items section.

**Mean Time to Detect (MTTD):** [time from first symptom to detection]
**Mean Time to Acknowledge (MTTA):** [time from alert/report to on-call acknowledgement]
**Mean Time to Resolve (MTTR):** [time from acknowledgement to full recovery]

---

## Timeline

Minute-by-minute sequence of events. Facts only — what happened, when, and who took what action.
Do not include interpretation ("we think"), attribution ("X made a mistake"), or speculation.
Use UTC timestamps.

| Time (UTC) | Event |
|---|---|
| HH:MM | [First symptom observable in metrics or logs] |
| HH:MM | [Alert fired / customer report received] |
| HH:MM | [On-call acknowledged] |
| HH:MM | [First hypothesis formed] |
| HH:MM | [Diagnostic action taken] |
| HH:MM | [Root cause identified / contributing factor identified] |
| HH:MM | [Mitigation applied] |
| HH:MM | [Service recovering] |
| HH:MM | [Full recovery confirmed] |
| HH:MM | [Status page updated] |
| HH:MM | [Stakeholders notified of resolution] |

---

## Contributing Factors

List 2–6 systemic conditions that, in combination, made this incident possible or made it worse.
Each factor is a state of the system — not an action of an individual.

Phrase rule: "The system [condition]" or "[Component] lacked [property]" — never "Person X did/didn't Y."

**Factor 1:** [Systemic condition]
**Factor 2:** [Systemic condition]
**Factor 3:** [Systemic condition]
[Add up to 6 total]

---

## What Went Well

Things that limited impact, accelerated detection, or accelerated recovery. Do not skip this section.

- [e.g. The runbook for this symptom class was accurate and up to date — the engineer followed it without deviation]
- [e.g. Rollback was fully automated and completed in under 90 seconds once the decision was made]
- [e.g. The status page update went out within 8 minutes of detection]

---

## Where We Got Lucky

Near-misses and fortunate circumstances that helped but cannot be relied on. A pure "what went
wrong" framing would never surface these. This section exists to turn luck into deliberate design.

- [e.g. The migration happened to run on a Saturday at low traffic; a weekday deployment would have affected 10x more users]
- [e.g. An engineer happened to be looking at the dashboard for an unrelated task and noticed the anomaly 12 minutes before any alert fired]
- [e.g. The consumer group offset was recoverable; if the topic had been compacted in the previous hour, data loss would have been confirmed]

---

## Action Items

Each item must have: a specific measurable completion criterion, a named owner (role, not "the team"),
a target date, and a tracking issue link. A postmortem is not complete until high-priority items close.

| Priority | Action | Owner | Due Date | Tracking Issue |
|---|---|---|---|---|
| P1 | [Specific, measurable action] | [Role] | YYYY-MM-DD | #[issue number] |
| P2 | [Specific, measurable action] | [Role] | YYYY-MM-DD | #[issue number] |
| P3 | [Specific, measurable action] | [Role] | YYYY-MM-DD | #[issue number] |

Review open items at: 30 days (YYYY-MM-DD) and 90 days (YYYY-MM-DD).

---

## Lessons Learned

Three sub-sections. Keep each to 2–4 bullets.

### What went wrong (systemic, not individual)
- [e.g. The deployment pipeline had no gate that checked schema backward-compatibility before applying]
- [e.g. No alert existed for consumer group lag on the ingestion topic]

### What went right
- [Mirror of "What Went Well" — include here in condensed form for a reader skimming lessons only]

### What to improve (and how)
- [Each item in this section should have a corresponding Action Item above, or explain why it does not]
```

---

## WORKED EXAMPLE

The following is a complete, filled-in postmortem for a realistic incident in this repo's stack
(Redpanda + Go microservices + PostgreSQL). Use it as a calibration reference for tone and depth.

---

### Postmortem: Schema Migration Broke Backward Compatibility on `document-ingest` Topic

**Date:** 2026-07-28
**Duration:** 34 minutes (14:22 UTC to 14:56 UTC)
**Severity:** SEV2
**Author:** platform-engineer
**Reviewer:** backend-engineer
**Status:** Final
**SLO Budget Consumed:** 34 minutes of 201-minute monthly availability budget (16.9%)

---

### Summary

A Redpanda schema migration for the `document-ingest` topic added a new required field (`tenant_classification`) without a default value. Consumers running the previous schema version rejected every message after the migration landed, causing a 34-minute period during which all document ingestion jobs silently returned a success status code to the caller while the underlying Kafka consumer group stalled at the new-schema boundary.

---

### Impact

| Dimension | Value |
|---|---|
| Affected tenants | All tenants (12 active at time of incident) |
| Affected requests | ~2,100 document ingestion jobs submitted and silently dropped |
| Duration | 34 minutes, 14:22 UTC to 14:56 UTC, Tuesday |
| User symptom | Documents submitted via the ingestion API returned HTTP 202 Accepted but never appeared in the document index. No error was surfaced to the caller. |
| SLO breach | Yes — availability SLO (99.9% over 28 days) consumed 16.9% of the monthly budget in a single incident |

---

### Detection

- [x] Customer reported it before any alert fired

**MTTD:** 29 minutes (14:22 to 14:51, when the first customer ticket arrived)
**MTTA:** 4 minutes (ticket routed to on-call by 14:55)
**MTTR:** 5 minutes (schema rolled back by 14:56; consumer group resumed immediately)

No alert fired. The consumer group lag alert threshold was set to >100,000 messages; the stall reached ~2,100 messages before the customer report arrived. A new alert for consumer group lag >500 messages on the `document-ingest` topic (with a 5-minute window and P2 severity) is required.

**Action:** Open a ticket for `alerting-rules-design` — add consumer group lag alert for `document-ingest` at >500 messages, firing within 5 minutes. Linked in Action Items.

---

### Timeline

| Time (UTC) | Event |
|---|---|
| 14:22 | Schema migration for `document-ingest` topic applied by CI/CD pipeline as part of scheduled release |
| 14:22 | Consumer group `document-ingest-consumer` began rejecting messages; lag counter started incrementing |
| 14:22 | No alert fired (lag threshold was set to >100,000 messages) |
| 14:51 | First customer ticket received: "Documents submitted via API are not appearing in search results" |
| 14:53 | On-call checked Grafana dashboard; consumer group lag for `document-ingest` showed 2,134 messages |
| 14:54 | Schema registry checked; confirmed new `tenant_classification` field was required with no default |
| 14:54 | Decision made to roll back the schema rather than deploy a hotfix to all consumer instances |
| 14:55 | Schema rollback initiated via `schema-registry-cli rollback --subject document-ingest-value --version 3` |
| 14:56 | Consumer group resumed processing; lag dropped to 0 within 90 seconds |
| 14:58 | Status page updated: "Document ingestion fully restored" |
| 15:05 | All 12 tenants' missed jobs confirmed to have been reprocessed from the consumer group offset |
| 15:10 | Postmortem process initiated |

---

### Contributing Factors

**Factor 1:** The schema registry was configured to allow non-backward-compatible schema migrations without a compatibility gate. The compatibility mode for the `document-ingest-value` subject was set to `NONE` rather than `BACKWARD` or `FULL`.

**Factor 2:** The CI/CD pipeline applied the schema migration before deploying the updated consumer binary. Consumers running the previous binary version therefore encountered the new required field immediately on startup after the migration, with no graceful transition period and no default value available.

**Factor 3:** The consumer's error handling on schema deserialization failure returned an HTTP 202 to the caller rather than surfacing the error — the caller received a false success signal and had no mechanism to detect that the submitted document had been dropped.

**Factor 4:** The consumer group lag alert threshold (>100,000 messages) was designed for a high-throughput pipeline scenario and was never calibrated to the actual daily volume on the `document-ingest` topic (~3,000 messages/day). At the observed stall rate, the alert would not have fired for approximately 33 days.

---

### What Went Well

- The schema rollback procedure in the runbook was accurate and current — no steps were missing or out of date.
- The rollback itself was fully scripted (`schema-registry-cli rollback`) and completed in under 10 seconds once the decision was made.
- All 2,134 messages were recoverable from the consumer group offset; no data was permanently lost.
- The customer's report was specific enough (timestamps + API correlation IDs) that diagnosis required only two checks (Grafana lag dashboard and schema registry history).

---

### Where We Got Lucky

- The incident occurred at 14:22 UTC (a Tuesday mid-afternoon, moderate traffic). At peak hours (09:00–11:00 UTC), the same stall would have affected approximately 8,000 messages in the same 34-minute window, not 2,100.
- The consumer group offset was still within the Redpanda topic's retention window (24 hours, configured). If the incident had gone undetected for another 23+ hours, the offset would have been invalid and reprocessing would have required replaying from a different source.
- The on-call engineer happened to have the Grafana dashboard open in a background tab for an unrelated task; the customer report and the visual confirmation arrived within 2 minutes of each other rather than requiring a cold-start investigation.

---

### Action Items

| Priority | Action | Owner | Due Date | Tracking Issue |
|---|---|---|---|---|
| P1 | Add consumer group lag alert for `document-ingest` topic: fire at >500 messages sustained for 5 minutes, P2 severity, paging channel | platform-engineer | 2026-08-04 | #471 |
| P1 | Set schema compatibility mode for `document-ingest-value` subject to `BACKWARD_TRANSITIVE` in schema registry configuration | platform-engineer | 2026-08-04 | #472 |
| P1 | Add a schema compatibility enforcement gate to the CI/CD pipeline: fail the deployment if the new schema version is not backward-compatible with the previous N versions | platform-engineer | 2026-08-11 | #473 |
| P2 | Update consumer deserialization error handler to return HTTP 422 (not 202) when a schema mismatch error is caught, and emit a structured log entry at ERROR level | backend-engineer | 2026-08-11 | #474 |
| P2 | Review and calibrate all consumer group lag alert thresholds against actual daily message volumes per topic; replace any threshold not derived from observed traffic with a traffic-normalized baseline | platform-engineer | 2026-08-18 | #475 |
| P3 | Add a deployment ordering gate: schema migration must complete *and* be verified backward-compatible before consumer binary is deployed | platform-engineer | 2026-08-25 | #476 |

Review open items: 2026-08-28 (30 days) and 2026-10-27 (90 days).

---

### Lessons Learned

**What went wrong (systemic)**
- Schema compatibility enforcement was not automated; it depended on the engineer authoring the migration knowing to check it manually.
- Deployment ordering (schema before binary) is correct in principle but the pipeline had no gate to verify the schema was backward-compatible before proceeding.
- Alert thresholds were not maintained against actual traffic baselines; they were set at initial configuration and never revisited.

**What went right**
- Rollback tooling was scripted, documented, and worked correctly on the first attempt.
- Message offset recovery was successful; no data was permanently lost.
- Detection, diagnosis, and resolution all occurred within 34 minutes from first symptom.

**What to improve**
- Automate schema compatibility validation in the pipeline (Action Item P1 #473) — this removes the human judgment dependency entirely.
- Calibrate alert thresholds on a monthly cadence as part of the existing `alerting-rules-design` monthly review (Action Item P2 #475).
- Surface deserialization errors to callers rather than masking them as successes (Action Item P2 #474) — this alone would have reduced MTTD from 29 minutes to under 2 minutes.
