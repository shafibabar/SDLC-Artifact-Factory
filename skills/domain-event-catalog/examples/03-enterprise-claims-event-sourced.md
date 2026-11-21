# Example 3 — Enterprise: An Event-Sourced Claim, Translated for Other Contexts

Self-contained. **Harbour Mutual** insures homes and small businesses, at the **enterprise** profile, under a financial regulator that requires every claim decision to be evidenced for 7 years. The **Claims** context's `Claim` Aggregate is event-sourced: its stream is the record (`aggregate-design`). **Payments**, **Fraud** and **Customer Communications** react to claims, and each is owned by a different team.

## Input

> **User:** "Publish the Claim's event stream as-is; it's the most complete. And add a `PayClaim` event when a claim is approved so Payments knows to pay."

## Working it

- **The stream, as-is:** declined. It holds `ClaimReviewStarted`, `ClaimNoteAdded`, `AssessorAssigned`, `ClaimAssessed` and `ClaimDecided`, the steps Claims needs to rebuild a claim. Payments, Fraud and Communications care about two facts: a decision was made, and money was paid. Publishing the stream would make every internal change a breaking change for three teams (Khononov). Instead, **`ClaimDecided` (published)** is translated from the stored decision event, and **`ClaimSettled`** from the stored payment confirmation.
- **`PayClaim`:** a Command in disguise. The fact is `ClaimDecided` with outcome "approved" and an amount. Payments' own policy issues `PayClaim` in its context.
- **Retention:** the stored stream is the 7-year evidence. The published events need only consumer replay (90 days), because the evidence is kept in the stream, not on the broker.
- **Consumers and order:** Payments must not pay a claim whose decision was later reversed, so it halts the claim's partition if a decision event is stuck. Fraud tolerates out-of-order replay.

## Output: `design/claims/domain-event-catalog.md` (excerpt)

```markdown
---
name: domain-event-catalog
product: harbour-mutual
bounded-context: Claims
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-11-05
summary: Claims publishes ClaimDecided and ClaimSettled, translated from the event-sourced Claim stream, to Payments, Fraud and Communications; review steps stay stored.
profile: enterprise
traces-to: [design/claims/aggregates.md, design/event-storming/software-design.md, design/claims/ubiquitous-language.md, design/context-map.md]
---

# Domain Event Catalog: Claims

## Events

| Event | Aggregate | Visibility | Consumers |
|---|---|---|---|
| ClaimAssessed | Claim | stored | none outside Claims |
| ClaimDecided | Claim | published | Payments, Fraud, Customer Communications |
| ClaimSettled | Claim | published | Customer Communications, Fraud |

## Event: ClaimAssessed

| Field | Value |
|---|---|
| **Means** | An assessor recorded their findings and recommended amount |
| **Aggregate** | Claim |
| **Raised by** | Command RecordAssessment |
| **Visibility** | stored (event-sourced) |
| **Published as** | translated to ClaimDecided when the decision follows; the assessment itself is not published |
| **Ordering** | per Aggregate |
| **Retention need** | audit evidence 7 years — the regulator reviews how each decision was reached |
| **Sensitive data** | the assessor's notes may hold health details; they never leave Claims |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| claimId | the claim | replay key |
| assessorId | who assessed | evidence of who decided what |
| recommendedAmount | the amount the assessor recommends | the decision's basis |
| findings | the assessor's findings | evidence |

## Event: ClaimDecided

| Field | Value |
|---|---|
| **Means** | The claim was approved (with an amount) or declined (with a reason) |
| **Aggregate** | Claim |
| **Raised by** | Command DecideClaim |
| **Visibility** | published |
| **Published as** | see design/data/event-schemas.md |
| **Ordering** | per Aggregate |
| **Retention need** | consumer replay 90 days — the 7-year evidence is the stored stream |
| **Sensitive data** | no health details or notes: outcome, amount and a reason code only |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| claimId | the claim | key |
| policyId | the policy claimed under | Fraud's pattern checks |
| outcome | approved or declined | Payments pays only approved claims |
| approvedAmount | the amount to pay; absent when declined | Payments' instruction |
| reasonCode | why declined, from the published reason list; absent when approved | Communications writes the letter |
| previousOutcome | the earlier outcome when a decision is reversed on appeal; absent on a first decision | Payments stops or recovers a payment |

### Guarantees

- Raised once per decision; a reversal is a new ClaimDecided carrying previousOutcome.

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| Payments | Whenever ClaimDecided with outcome approved, then PayClaim | claimId + decision sequence | halts this Aggregate's partition until fixed |
| Fraud | Whenever ClaimDecided, then ScoreClaimPattern | event id within source | tolerates out-of-order replay |
| Customer Communications | Whenever ClaimDecided, then SendDecisionLetter | claimId + decision sequence | tolerates out-of-order replay (assumed — confirm with the Communications team) |

## Event: ClaimSettled

| Field | Value |
|---|---|
| **Means** | The approved amount reached the claimant |
| **Aggregate** | Claim |
| **Raised by** | Policy: whenever PaymentConfirmed (from Payments), then RecordSettlement |
| **Visibility** | published |
| **Published as** | see design/data/event-schemas.md |
| **Ordering** | per Aggregate |
| **Retention need** | consumer replay 90 days |
| **Sensitive data** | none: bank details stay in Payments |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| claimId | the claim | key |
| paidAmount | what reached the claimant | Communications confirms it; Fraud compares with the decision |
| paymentRef | Payments' reference | traceability across contexts |

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| Customer Communications | Whenever ClaimSettled, then SendSettlementConfirmation | claimId | tolerates out-of-order replay |
| Fraud | Whenever ClaimSettled, then CloseFraudWatch | claimId | tolerates out-of-order replay |

## Translations

| Internal or stored events | Published as | Never published |
|---|---|---|
| ClaimDecisionRecorded (stored) | ClaimDecided | — |
| SettlementRecorded (stored) | ClaimSettled | — |
| ClaimReviewStarted, ClaimNoteAdded, AssessorAssigned, ClaimAssessed (stored) | — | review steps: Claims' own process; notes may hold health details |

## Open questions

- Does Communications need the reason text, or only the code? (assumed: code only)
```

## Why this is right

- The stream stayed inside Claims, and other contexts get two coarse business facts. The translation table shows exactly what maps to what.
- `PayClaim` was declined as a Command in disguise. Payments' policy issues it in Payments' own context.
- The retention need differs by visibility: the evidence lives in the stored stream, and the broker keeps only what replay needs.
- Payments' stuck-event choice protects against paying a reversed decision. An assumed reaction is marked as assumed.
