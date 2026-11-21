# Example 3 — Enterprise: Two Points of No Return Split into Two Sagas

Self-contained. **Tessera** is a commercial insurance platform used by brokers. **Enterprise** profile, separate services: **Quotes**, **Underwriting** (the rules and the human underwriter decide), **Billing**, **Documents**, **Compliance** and a **Registry Gateway** that files policies with a regulator. Binding a policy means: lock the quote, get an underwriting decision (up to 5 days when referred to a human), charge the first premium, issue the policy documents, then file with the regulator.

## Input

> **User:** "Orchestrate policy binding as one saga, kept in the coordinator's memory for speed. The coordinator can score the risk itself so we skip a call to Underwriting. Treat the first premium charge and the registry filing as a single atomic point of no return. Also tell me how the broker portal should query across Quotes, Billing and Documents."

## Working it

- **Trigger check.** Branching (decline, refer, approve), a 5-day human wait, one view of progress for brokers, and compensation across 4 services: all fire. Orchestrate.
- **In-memory** is declined: a restart during a 5-day flow would lose every open policy. State and the next command commit in one transaction through the Transactional Outbox.
- **"The coordinator can score the risk"** is declined: that is Underwriting's rule. The coordinator sends `RequestUnderwritingDecision` and records the reply.
- **One atomic point of no return** is declined: charging the premium and filing with the regulator are two irreversible effects, and a failure between them has no single defined behaviour. Two sagas: **Bind a policy** ends at its pivot, the premium charge, and its completion starts **File with the registry**, whose pivot is the filing.
- **The portal query** is not decided here: it is `cqrs-pattern`'s ladder. The portal's progress for a policy comes from the coordinator's record.
- **Compensation breadth and rules** as in Example 2: captured data, idempotent, escalated. At enterprise the document adds an owner, the progress view and the rule for definition changes.

## Output: `artifacts/tessera/design/architecture/workflow-orchestration.md`

````markdown
---
name: workflow-orchestration-design
product: tessera
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: Policy binding is two orchestrated sagas, each with one pivot: the first premium charge, then the registry filing.
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Workflow Orchestration Design for Tessera

**Readers:** enterprise-architect, backend-engineer, the product owner
**Question it answers:** for each orchestrated flow, what is done, what is undone, and what happens when a step fails or never answers?

- **Profile:** enterprise

## Orchestration Decision

| Flow | Trigger that fired | Why not choreography | Coordinator |
|---|---|---|---|
| Bind a policy | branching (decline, refer, approve), long-running (underwriter up to 5 days), one view of progress for brokers, compensation across 4 services | Five services reacting cannot answer "where is this policy?", and a 5-day wait has no owner | hand-rolled, owned by the Quotes team; two flows do not justify an engine |
| File with the registry | branching (accepted, rejected, needs correction) and one view of progress | The regulator's three outcomes need one place that decides what happens next | hand-rolled, same coordinator service, separate saga |

## Saga: Bind a policy

**Pivot:** step 3, charging the first premium: until it commits the bind can be abandoned at no cost, after it the policy exists
**Coordinator:** a state record per policy bind in the Quotes deployment; owner: Quotes team
**State persistence:** the bind's state and the next command are written in one transaction through the Transactional Outbox; one writer per bind
**Business logic in the coordinator:** none: Underwriting scores and decides; the coordinator sends commands and records replies

### Steps

| # | Step (command) | Owner | Class | Compensation | Captured on the way forward | Lock set or cleared |
|---|---|---|---|---|---|---|
| 1 | LockQuote | Quotes | compensatable | UnlockQuote | quote version and price | sets quote `binding` |
| 2 | RequestUnderwritingDecision | Underwriting | compensatable | WithdrawReferral | referral id | none |
| 3 | ChargeFirstPremium | Billing | pivot | none | none | none |
| 4 | IssuePolicyDocuments | Documents | retriable | none | none | clears quote to `bound` |
| 5 | StartRegistryFiling | Compliance | retriable | none | none | none |

### State Machine

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| Locking quote | LockQuote | Awaiting underwriting | Compensated |
| Awaiting underwriting | RequestUnderwritingDecision | Charging premium | Unlocking quote |
| Charging premium | ChargeFirstPremium | Issuing documents | Withdrawing referral |
| Issuing documents | IssuePolicyDocuments | Starting filing | retry with backoff, then Needs repair |
| Starting filing | StartRegistryFiling | Completed | retry with backoff, then Needs repair |
| Withdrawing referral | WithdrawReferral | Unlocking quote | retry with backoff, then Needs repair |
| Unlocking quote | UnlockQuote | Compensated | retry with backoff, then Needs repair |
| Completed | none | none | none |
| Compensated | none | none | none |
| Needs repair | none | none | none |

### Timeouts

| Wait | Timeout | When it expires |
|---|---|---|
| Underwriting decision (human referral) | 5 days | escalated to the underwriting manager at day 4; at day 5 the bind is withdrawn and compensated, and the broker is told |
| Premium charge reply | 60 seconds | retried (idempotent), then treated as a failure and compensated |

### Isolation

| Record exposed | Anomaly possible | Countermeasure | Cleared by, and how a stale one is released |
|---|---|---|---|
| Quote | lost update (a broker edits the quote while it is being bound) | semantic lock: quote state `binding` | cleared by IssuePolicyDocuments (to `bound`) or UnlockQuote; a lock older than 6 days is released by a sweeper and alerts the Quotes team |

### Progress and Repair

- **Progress view:** the coordinator's record per bind: state, time in state, outcome so far; brokers and support read it.
- **Needs repair:** IssuePolicyDocuments or StartRegistryFiling stuck after retries goes to Needs repair; owner: Documents on-call, alert on any bind in that state.
- **Definition changes:** binds in flight finish under the definition version recorded on their state row; a new version applies to new binds only.

## Saga: File with the registry

**Pivot:** step 2, submitting the filing: until the registry accepts it the filing can be discarded, after it the filing is on public record
**Coordinator:** a state record per filing in the Quotes deployment; owner: Quotes team
**State persistence:** the filing's state and the next command are written in one transaction through the Transactional Outbox; one writer per filing
**Business logic in the coordinator:** none: Compliance prepares the filing and the Registry Gateway talks to the regulator

### Steps

| # | Step (command) | Owner | Class | Compensation | Captured on the way forward | Lock set or cleared |
|---|---|---|---|---|---|---|
| 1 | PrepareFiling | Compliance | compensatable | DiscardDraftFiling | draft filing id | none |
| 2 | SubmitFiling | Registry Gateway | pivot | none | none | none |
| 3 | RecordFilingReference | Compliance | retriable | none | none | none |

### State Machine

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| Preparing filing | PrepareFiling | Submitting filing | Compensated |
| Submitting filing | SubmitFiling | Recording reference | Discarding draft |
| Recording reference | RecordFilingReference | Completed | retry with backoff, then Needs repair |
| Discarding draft | DiscardDraftFiling | Compensated | retry with backoff, then Needs repair |
| Completed | none | none | none |
| Compensated | none | none | none |
| Needs repair | none | none | none |

### Timeouts

| Wait | Timeout | When it expires |
|---|---|---|
| Regulator response | 48 hours | an alert to Compliance; the filing stays in Submitting filing and is never submitted twice (the command carries the filing id) |

### Isolation

| Record exposed | Anomaly possible | Countermeasure | Cleared by, and how a stale one is released |
|---|---|---|---|
| Draft filing | dirty read (a draft that may be discarded is read as filed) | risk-accepted: drafts are internal to Compliance and never shown to brokers | not applicable |

### Progress and Repair

- **Progress view:** the coordinator's record per filing: state, time in state, regulator reference once recorded.
- **Needs repair:** a rejected filing that cannot be corrected goes to Needs repair; owner: Compliance; alert on any filing in that state.
- **Definition changes:** filings in flight finish under the version they started with.

## Open Questions

- Whether a policy in force before its filing is recorded needs a visible "filing pending" label for brokers; owner: product owner.
````
