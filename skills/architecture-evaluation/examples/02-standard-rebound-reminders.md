# Example 2 — Standard: A Reminder Service with a Retry-Window Risk and a Resolved Trade-off

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (about 40 clinics on one shared service), at the **standard** profile. The NFR specification's Architecture Handoff lists three scenarios rated high on architectural impact. **NFR-COMPAT-01:** a clinic's SMS provider rejects or times out for up to 2 hours; reminders lost must be 0, the front desk is alerted within 15 minutes, and the queue drains within 30 minutes of recovery. **NFR-REL-01:** a hosting-zone failure; RTO at most 30 minutes, RPO at most 5 minutes. **NFR-DEPLOY-01:** deploys with no manual step, no reply lost, rollback within 10 minutes. The handoff carries a trade-off point, **TP-1**, on NFR-REL-01. The design has a durable outbound message queue written in the same transaction as the booking (ADR-0004), a warm standby in a second zone with replicated storage (ADR-0005), and a rolling deployment with health-checked rollback.

## Input

> **User:** "The design is done: evaluate it against the NFRs. Keep it brief; I just need to know where we're exposed."

## Working it

- **Self-check, stated.** The designing agent evaluates its own design; the record says it is a self-check, not independent, and not an ATAM.
- **Scenarios:** the three in the handoff, each with a response measure, so all three can be evaluated. Nothing is invented.
- **Findings.**
  - **R-1 (NFR-COMPAT-01):** the retry policy gives up on a send after 60 minutes, but the scenario assumes a provider outage of up to 2 hours with zero reminders lost. A reminder dropped after 60 minutes breaks the "lost: 0" measure. Action: retry until the outage ends, with the queue bounded by clinic and day.
  - **N-1 (NFR-DEPLOY-01):** a rolling deployment with in-flight work kept in the durable queue is safe, because a restarted worker re-reads unsent messages; the reason is recorded.
  - **S-1:** the replication lag of the standby's storage is critical to the RPO response (at most 5 minutes).
  - **T-1 (carried from TP-1):** the replication mode is a **trade-off point**. Synchronous replication raises data safety (RPO 0) and lowers reply speed (it adds a cross-zone round trip to every write, against the performance scenario for reply handling). Asynchronous replication does the opposite. It is costly to reverse and widely depended on, so it passes the ADR gate: ADR-0005 resolves it as asynchronous replication with an alert on lag over 2 minutes, accepting up to 5 minutes of lost work, which meets the Must.
- **No risk themes:** the findings share no systemic cause, and a theme needs two or more risks.
- **Fitness functions:** a release test that fails if any reminder is lost in a simulated provider outage (NFR-COMPAT-01), a replication-lag alert (the sensitivity point), and the quarterly zone-failover drill already in the NFR's measure.

## Output: `artifacts/rebound/design/architecture/architecture-evaluation.md` (frontmatter omitted in a reply)

````markdown
---
name: architecture-evaluation
product: rebound
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
summary: Self-check of Rebound's three top scenarios: one risk (a 60-minute retry window) and a replication trade-off resolved in ADR-0005.
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md, ADR-0004, ADR-0005]
self-check: true
---

# Architecture Evaluation for Rebound

**Readers:** enterprise-architect, the product owner, backend-engineer, platform-engineer
**Question it answers:** does the design, as it stands, meet its highest-impact scenarios, and where does it not, or only at a cost?

- **Profile:** standard
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days).

## Scenarios Evaluated

| Scenario | Rating (value, impact) | Response measure | Approaches that serve it |
|---|---|---|---|
| NFR-COMPAT-01 | (H, H) | reminders lost 0; front desk alerted within 15 min; queue drained within 30 min of recovery | durable outbound queue (ADR-0004), retry, condition monitoring of the provider |
| NFR-REL-01 | (H, H) | RTO at most 30 min; RPO at most 5 min | warm standby in a second zone with replicated storage (ADR-0005) |
| NFR-DEPLOY-01 | (M, H) | no manual step; no reply lost; rollback within 10 min | rolling deployment with health-checked rollback |

## Tactics Questionnaire

| Scenario | Tactic family | Question | Answer | Where in the design |
|---|---|---|---|---|
| NFR-COMPAT-01 | recover from faults | are failed sends retried until the provider recovers? | partial | the retry policy gives up after 60 minutes |
| NFR-COMPAT-01 | detect faults | is the provider's failure detected and shown to the front desk? | yes | condition monitoring and the unsent-reminders list |
| NFR-REL-01 | recover from faults | is there a warm standby with state resynchronised? | yes | the second-zone standby (ADR-0005) |
| NFR-REL-01 | detect faults | is a failed zone detected quickly? | yes | health checks and a heartbeat on the primary |
| NFR-DEPLOY-01 | manage the pipeline | is rollout gradual with a health-checked rollback? | yes | the rolling deployment |

## Risks

| ID | Scenario | Decision | Why it may fail | Action |
|---|---|---|---|---|
| R-1 | NFR-COMPAT-01 | the retry policy stops after 60 minutes | an outage of up to 2 hours would drop reminders, against "lost: 0" | retry until the outage ends, bounded by clinic and day; update the design |

## Non-Risks

| ID | Scenario | Decision | Reason it is safe |
|---|---|---|---|
| N-1 | NFR-DEPLOY-01 | a rolling deployment with unsent work kept in the durable queue | a restarted worker re-reads unsent messages, so no reply or reminder is lost in a deploy |

## Sensitivity Points

| ID | Property | Response it governs | Value or limit that matters |
|---|---|---|---|
| S-1 | replication lag of the standby's storage | the RPO | under 2 minutes, so the 5-minute RPO holds |

## Trade-off Points

Each ADR's Trade-off line names the characteristics traded (for example, security traded against latency).

| ID | Property | Raises | Lowers | Carried from | Resolution |
|---|---|---|---|---|---|
| T-1 | replication mode of the standby (synchronous or asynchronous) | data safety | reply speed | TP-1 | ADR-0005 |

## Fitness Functions

These fitness functions are objective automated checks that run continuously and keep each rule true as the system changes; they complement this one-time evaluation and do not replace it.

| Characteristic | Rule that must stay true | Check | Where it runs | Owner |
|---|---|---|---|---|
| reliability | no reminder is lost in a provider outage | a release test that simulates a 2-hour provider outage | every release build | backend-engineer |
| recoverability | replication lag stays under 2 minutes | an alert on replication lag | production monitoring | platform-engineer |
| availability | a zone failure recovers within 30 minutes | the zone-failover drill | every quarter, scheduled | platform-engineer |

## Actions

- Change the retry policy to run until the provider recovers; owner: backend-engineer; this reopens the reminder-service design for re-approval.
- ADR-0005 records the asynchronous replication choice and its accepted cost.

## Open Questions

- Whether a clinic may choose a shorter retry window for its own reminders; owner: product owner.
````

> **Reply summary:** this is a self-check by the designing agent, not independent and not an ATAM; the three scenarios come from the NFR handoff; one risk (a 60-minute retry window against a 2-hour outage), one non-risk with its reason, one sensitivity point and the replication trade-off resolved in ADR-0005; three fitness functions; the retry change reopens the approved reminder-service design; no implementation code.
