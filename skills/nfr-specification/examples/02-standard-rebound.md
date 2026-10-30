# Example 2 — Standard: the FRD's hand-off becomes rated, six-part scenarios with Must and Plan

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners each; about 40 clinics on one shared service), at the **standard** profile. Its functional requirements document (`ideate/requirements.md`, approved) handed three quality concerns and a confidentiality rule to the NFR specification. This example shows each hand-off item consumed exactly once, the rule cited rather than restated, availability written as failure scenarios, ratings that decide what reaches the architect, and a conflict recorded rather than resolved.

## Input

> **FRD Quality-Attribute Hand-off:** QA-1 how quickly a reply registers and the slot is released (constrains FR-1.2, FR-2.2, FR-1.4; "a late release cannot be refilled the same day"); QA-2 delivery reliability of outbound messages (FR-1.1, FR-2.1; "a reminder that never arrives is a no-show"); QA-3 privacy of message content on a shared phone (FR-1.1, FR-2.1; BR-3).
>
> **FRD Business Rules (cited):** BR-1 confirm request 72 h before, reminder 24 h before; BR-3 messages name the clinic, date and time only, never the treatment. **Constraint:** CON-1 messages go through each clinic's existing SMS account. **Interface:** IF-1 SMS provider.
>
> **Drivers:** KR-2.1 no-show rate 12% → 7%. Clinics open 07:00–20:00. Reminders go out in a batch at 08:00. The clinic owner at C-2 said "it must never be down"; `competitive-analysis` notes rival booking tools publish 99.9% uptime.

## Working it

- **QA-1** becomes a latency scenario with its load: the 08:00 batch produces the reply peak.
- **QA-2** is not about our uptime: the risk is the SMS provider (IF-1, CON-1). Written as a failure scenario for the dependency: queue, retry, tell the front desk.
- **QA-3** is BR-3. The rule stays in the FRD; here the obligation is that no template can carry a treatment, and how that is checked.
- **"Never be down"** is a wish. Written as failure scenarios with RTO and RPO over clinic hours; 99.9% in clinic hours is the Plan, backed by the competitor table stakes; the Must is what a clinic can survive (paper diary for half an hour).
- **One service, many clinics**: the FRD's disfavoured class "front desk of another clinic" gives a security scenario nobody asked for.
- **Ratings** decide the handoff: anything H on architectural impact goes to `enterprise-architect`.
- **Process targets**: optional at standard. The user chose to track lead time for changes; the value is theirs, calibrated against `dora-metrics`.

## Output — `ideate/nfr-specification.md`

````markdown
---
name: nfr-specification
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-28
summary: Rebound's rated quality attributes: reply-to-release latency at the 08:00 peak, SMS-outage handling, clinic-hours recovery, cross-clinic isolation, BR-3 message privacy.
profile: standard
status: draft
linked-frd: ideate/requirements.md
traces_to: ideate/requirements.md (QA-1, QA-2, QA-3, BR-3, CON-1, IF-1); strategy/okrs.md (KR-2.1); strategy/competitive-analysis.md
architecture-handoff: [NFR-COMPAT-01, NFR-REL-01, NFR-DEPLOY-01]
---

# Non-Functional Requirements — Rebound

**Translation.** The FRD's hand-off (QA-1 to QA-3), BR-3 and the clinics' opening hours become rated quality-attribute scenarios for `enterprise-architect`, `security-architect`, `slo-definition` and the Quality phase.

Targets use Planguage: **Must** is the minimum acceptable, **Plan** the target. Planguage *Must* is not a MoSCoW priority. Ratings were drafted by the requirements-analyst and are confirmed by the user at the gate.

## Inputs Consumed

| Input | Says (cited, not restated) | Became |
|---|---|---|
| QA-1 | Reply registers and slot released quickly | NFR-PERF-01 |
| QA-2 | Delivery reliability of outbound messages | NFR-COMPAT-01 |
| QA-3 | Privacy of message content on a shared phone | NFR-OBL-01 (cites BR-3) |
| BR-3 | Message content rule | NFR-OBL-01 |
| CON-1, IF-1 | Clinic's own SMS account; SMS provider | Environment and source of NFR-COMPAT-01 |
| Owner's "never down" | — | NFR-REL-01, with RTO/RPO; "never" recorded as a wish |

## Characteristics Considered

| Characteristic | Decision |
|---|---|
| Functional suitability | Declined: the FRD's fit criteria own it |
| Performance efficiency | Kept: NFR-PERF-01 (time behaviour) |
| Compatibility | Kept: NFR-COMPAT-01 (interoperability with the SMS provider) |
| Interaction capability | Kept: NFR-USE-01 (learnability of the day-end checklist, FR-3.1) |
| Reliability | Kept: NFR-REL-01 (availability, recoverability) |
| Security | Kept: NFR-SEC-01 (confidentiality between clinics) |
| Maintainability | Declined: no frequent change type identified yet; revisit after the first release |
| Flexibility | Declined: 40 clinics to 80 in two years fits one region and one database; revisit at 200 |
| Safety | Declined: appointment booking cannot harm a patient; clinical decisions stay with practitioners |
| Deployability | Kept: NFR-DEPLOY-01 |

## Ranking

| Rank | NFR | Business value | Architectural impact | Why |
|---|---|---|---|---|
| 1 | NFR-COMPAT-01 | H | H | A lost reminder is a no-show (KR-2.1); needs a durable outbound queue |
| 2 | NFR-REL-01 | H | H | Front desks run the day from it; needs redundancy and tested restore |
| 3 | NFR-SEC-01 | H | M | One service holds many clinics' patients; tenant check on every request |
| 4 | NFR-PERF-01 | H | M | A late release cannot be refilled (JS-1.2); asynchronous processing |
| 5 | NFR-DEPLOY-01 | M | H | Replies arrive all day; a release must not drop them |
| 6 | NFR-USE-01 | M | L | Front desks enter paper bookings at day end (FR-3.1) |

## Quality-Attribute Scenarios

| ID | Characteristic (sub) | Source | Stimulus | Environment | Affected part | Response | Response measure | Traces to | Verification |
|---|---|---|---|---|---|---|---|---|---|
| NFR-PERF-01 | Performance efficiency (time behaviour) | Patients of all clinics | Reply "X" to a confirm request or reminder | 08:00–09:00 batch peak: up to 600 replies an hour, 40 clinics | Reply handling and waitlist offer | Cancels the appointment and offers the slot to the waitlist (FR-1.4) | Reply received → first waitlist offer sent: P95 ≤ 2 min (Must), ≤ 30 s (Plan) | QA-1; FR-1.2, FR-2.2, FR-1.4; KR-2.1 | Load test replaying a 600-reply hour on staging, each release candidate |
| NFR-COMPAT-01 | Compatibility (interoperability) | A clinic's SMS provider (IF-1, CON-1) | Rejects or times out on sends for up to 2 h | The 08:00 reminder batch | Outbound messaging | Queues and retries; tells the front desk which reminders are unsent; sends them when the provider recovers | Reminders lost: 0 (Must); front desk alerted within 15 min (Must), 5 min (Plan); queue drained within 30 min of recovery (Must), 10 min (Plan) | QA-2; FR-1.1, FR-2.1 | Fault-injection test with a stubbed provider returning errors for 2 h |
| NFR-REL-01 | Reliability (availability, recoverability) | The hosting zone | Fails | Clinic hours 07:00–20:00 | Whole service | Detects, fails over to a second zone, resumes | RTO ≤ 30 min (Must), ≤ 5 min (Plan); RPO ≤ 5 min (Must), 0 (Plan); availability in clinic hours, monthly ≥ 99.5% (Must), ≥ 99.9% (Plan, rivals' published figure) | Owner's concern; competitive-analysis | Zone-failover drill each quarter; monthly availability report (formalised as an SLO by `slo-definition`) |
| NFR-SEC-01 | Security (confidentiality) | Front desk user of clinic A (disfavoured class) | Requests clinic B's diary or a patient record by ID | Normal operation | Diary and patient APIs | Refuses, logs, alerts on repeated attempts | Disclosed: 0 of 200 scripted attempts (Must); 5+ attempts in 10 min alerted within 5 min (Must), 1 min (Plan) | FRD user classes | Automated cross-tenant access suite per release |
| NFR-DEPLOY-01 | Deployability | Developer, through the pipeline | A fix is ready | Clinic hours, replies arriving | Reply handling service | Deployed with no manual step; no reply lost; rolled back automatically if health checks fail | Replies lost during deploy: 0 (Must); rollback ≤ 10 min (Must), ≤ 3 min (Plan) | Product property | Release rehearsal under the NFR-PERF-01 load |
| NFR-USE-01 | Interaction capability (learnability) | A front desk new to Rebound | Enters a day's 12 paper bookings | Day end, unaided after the 5-minute walkthrough (TR-2) | Day-end checklist screen | All 12 entered correctly | Time ≤ 10 min (Must), ≤ 6 min (Plan); errors ≤ 1 (Must), 0 (Plan) | FR-3.1; TR-2 | Moderated test with 3 front desks |

## Obligations from Business Rules

| ID | Business rule | Measurable obligation on this system | Verification |
|---|---|---|---|
| NFR-OBL-01 | BR-3 | No outbound message template has a field for treatment, practitioner speciality or notes; messages contain only clinic, date and time fields | Template test fails the build if any template references another field; monthly sample of 100 sent messages reviewed |

## Candidate Trade-off Points

| ID | Scenarios | Why they pull apart | Options open (not chosen) | Decided by |
|---|---|---|---|---|
| TP-1 | NFR-REL-01 × price per clinic | RTO 5 min (Plan) needs a warm second zone; small clinics pay a low monthly price | Warm standby (Plan met, higher cost); cold restore (Must met only) | The user (pricing), then `enterprise-architect` (ADR) |
| TP-2 | NFR-OBL-01 × NFR-COMPAT-01 | A patient with two appointments the same day cannot tell which one a reply cancels when messages carry no detail | Include the time in every message (already allowed); add the practitioner's first name (needs a BR-3 change) | The user, if BR-3 should change |

## Derived Requirements

| From | Functional requirement sent to the FRD | Status |
|---|---|---|
| NFR-COMPAT-01 | Front desk sees a list of reminders not yet sent, with the reason | Change request CR-1 raised (FRD approved) |
| NFR-SEC-01 | Repeated refused access attempts are shown to the clinic owner | Change request CR-2 raised |

## Process Targets

| ID | Target | Scope | Value (chosen by the user) | Calibration | Measured by |
|---|---|---|---|---|---|
| PT-1 | Lead time for changes | Reply handling service | Within 1 working day | `dora-metrics` clusters | Merge-to-deploy time from pipeline events |

## Architecture Handoff

| NFR | Rating (value, impact) | Trade-off points | Tactic families (pointers only) |
|---|---|---|---|
| NFR-COMPAT-01 | (H, H) | TP-2 | Retry; queue with durable storage; condition monitoring of the dependency |
| NFR-REL-01 | (H, H) | TP-1 | Redundancy (warm standby or cold restore); heartbeat; rollback |
| NFR-DEPLOY-01 | (M, H) | — | Gradual rollout; health-checked rollback; keep in-flight work durable |

## Open Questions

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | TP-1 pricing decision | NFR-REL-01 Plan | the product owner | Before the Design phase gate |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| Every QA-n has a row in Inputs Consumed | Nothing the FRD handed over is lost |
| BR-3 cited, obligation measurable | One home for the rule; this artifact says how it is proved |
| Availability as a failure scenario with RTO/RPO | An uptime number alone says nothing about what fails; `slo-definition` turns the uptime measure into an SLO later |
| The SMS dependency as its own scenario | The real risk to KR-2.1 is outside our uptime |
| Must and Plan, each Plan with a driver | Standard aims at the target, can ship at the minimum |
| H on impact → handoff; NFR-SEC-01 (H, M) is not an ASR | The rule, not a fixed list of "important" categories, decides |
| One user-chosen process target | Optional at standard; the value is the user's, never a default cluster |
