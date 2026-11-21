# Example 3 — Enterprise: A Retried Capture Across a Regional Failover

Self-contained. **Corvid Pay** processes card payments for online merchants across two regions (EU-West and EU-Central), at the **enterprise** profile, multi-tenant (each merchant is a tenant). This is the **Payments** context. A merchant first authorises a payment (funds held on the card), then captures it when the goods ship. Capture calls the card network.

## Input

> **User:** "Merchants complain about double captures after the EU-West outage last month. Make `CapturePayment` idempotent: the server can generate a fresh key per request and check it in a Redis cache in each region. And let merchants capture several payments in one call."

## Working it

- **What went wrong:** the merchant's client timed out during the failover and retried. The retry landed in EU-Central with a new server-generated key, the regional cache had no record, and the capture ran again, calling the card network twice.
- **A fresh key per request:** declined. A retry then looks like a new Command. The merchant sends an idempotency key once per capture intent and repeats it on every retry.
- **A regional cache for keys:** declined. The dedupe record must commit with the capture, in the same store and transaction, so it fails over with it. A cache in one region knows nothing of the other.
- **The card network:** the same key goes downstream on the network call, so a network-side retry is not a second charge either. Which payments are captured is still decided by the Payment Aggregate.
- **Key retention:** merchants retry for up to 24 hours, and failover plus replay of queued requests adds up to a day. Keys are kept 7 days.
- **Same key, different amount:** the merchant reused a key for a different intent. That is rejected as invalid input, not replayed.
- **Several payments in one call:** declined as one Command. Each capture is its own Payment and its own transaction; a batch that fails half-way would leave merchants guessing. A `CaptureBatch` process issues one `CapturePayment` per payment and reports each outcome.
- **Rules:** capture no more than the authorised amount minus what was already captured; not after the authorisation expired (7 days); not on a voided payment. All are rules about the Payment's own state, in the Aggregate.
- **Tenant:** comes from the merchant's credentials, never from the body (multi-tenant, D047-7).

## Output: `design/payments/command-catalog.md` (excerpt)

```markdown
---
name: command-catalog
product: corvid-pay
bounded-context: Payments
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-08-03
summary: Payments makes CapturePayment idempotent on the merchant's key across regions, with the key passed to the card network; batches run as a tracked process.
profile: enterprise
traces-to: [design/payments/aggregates.md, design/event-storming/process-capture.md, design/payments/ubiquitous-language.md, design/payments/domain-event-catalog.md]
---

# Command Catalog: Payments

Version 2.0.0: the idempotency key changed from server-generated to the merchant's key (MAJOR; agreed with api-contract-design and merchants' integration team).

## Commands

| Command | Aggregate | Issued by | Records |
|---|---|---|---|
| CapturePayment | Payment | merchant system; CaptureBatch process | PaymentCaptured |
| StartCaptureBatch | CaptureBatch | merchant system | CaptureBatchStarted |

## Command: CapturePayment

| Field | Value |
|---|---|
| **Intent** | Take money that was authorised on the card, now that the goods are on their way |
| **Aggregate** | Payment — by payment ID, within the merchant |
| **Issued by** | the merchant's system with the capture permission; the CaptureBatch process for each payment in a batch |
| **Records** | PaymentCaptured (amount, total captured so far) |
| **Idempotency key** | the merchant's idempotency key, kept across retries of one capture; for a batch, the batch ID plus the payment ID |
| **On a duplicate** | returns the first outcome, refusal included, in either region; keys kept 7 days (24 h merchant retries plus failover and queued replay); the record commits with the capture |
| **Already in effect** | not applicable — partial captures are allowed, so a new key is a new capture, checked against the remaining amount |
| **Concurrency** | none needed — the remaining amount is re-checked on the Payment's current state |
| **Caller needs** | the outcome now (the merchant marks the order paid) |
| **Source** | design/event-storming/process-capture.md; incident review of the EU-West failover |

### Inputs

| Input | Meaning (in the language) | From | Input rule (checked before the Aggregate) |
|---|---|---|---|
| payment ID | the authorised payment to capture | target | present |
| amount | how much to take now, in the payment's currency | request | positive, at most 2 decimal places |
| idempotency key | the merchant's name for this one capture | request | present, at most 64 characters |
| merchant | the tenant: whose payment it is | authenticated context | — |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| Amount must be positive with at most 2 decimal places | invalid input | input |
| This idempotency key was already used for a different capture | invalid input | input (compared with the stored request) |
| Your credentials can't capture payments | not permitted | access check |
| No such payment for this merchant | not found | loading the target |
| Amount is more than what remains authorised | rule violated | Aggregate |
| The authorisation has expired; ask the customer to pay again | rule violated | Aggregate |
| The payment was voided | rule violated | Aggregate |

## Command: StartCaptureBatch

| Field | Value |
|---|---|
| **Intent** | Capture many authorised payments at once, for a merchant's daily dispatch |
| **Aggregate** | CaptureBatch — by batch ID |
| **Issued by** | the merchant's system with the capture permission |
| **Records** | CaptureBatchStarted; each payment's outcome is reported on the batch |
| **Idempotency key** | the merchant's idempotency key for the batch |
| **On a duplicate** | returns the first outcome (the same batch ID); keys kept 7 days |
| **Already in effect** | not applicable — each batch is new |
| **Concurrency** | none needed — the batch is new |
| **Caller needs** | an acknowledgement now, each payment's outcome via the batch's Read Model |
| **Source** | design/event-storming/process-capture.md |

### Inputs

| Input | Meaning (in the language) | From | Input rule (checked before the Aggregate) |
|---|---|---|---|
| captures | the payment IDs and amounts | request | 1 to 1,000 entries, no payment twice |
| merchant | the tenant: whose batch it is | authenticated context | — |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| A batch holds 1 to 1,000 captures, each payment once | invalid input | input |
| Your credentials can't capture payments | not permitted | access check |

## Open questions

- Should a capture after expiry offer a re-authorisation in one step? (product owner)
```

## Why this is right

- The cause of the double capture (a server key and a regional cache) is fixed at the design level: the merchant's key, a record that commits with the capture, and the key passed to the card network.
- Retention covers the real retry horizon, failover included.
- The batch became a tracked process, so each capture stays one Payment in one transaction.
- `validate-command-catalog.sh` exits clean on the excerpt.
