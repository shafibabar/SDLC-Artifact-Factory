# Example 3 — Enterprise: A Balanced Entry, Write Skew, a Saga and Justified Event Sourcing

Self-contained. **Tallyfield** pays out to the sellers of several online marketplaces, at the **enterprise** profile, under an e-money licence. This is the **Merchant Funds** context (Core): the ledger, each merchant's funds available for payout, and payouts to bank accounts. The regulator requires the full history of each payout and month-end safeguarding reconciliations.

## Input

> **User:** "Event-source everything in Merchant Funds; it's Core and regulated. Make each Account an Aggregate and update the debit and credit accounts together, and let a payout check the merchant's balance before it's created."

## Working it

- **Event sourcing per Aggregate, not per context (§ 6).**
  - A `Payout` has a lifecycle (requested, funds reserved, approved, sent, settled or returned). The regulator must be shown its history as the record, and the safeguarding reconciliation asks for its state as of month-end. That is audit-as-record and temporal query → **event-sourced**.
  - A `JournalEntry` is immutable once posted. The journal *is* already the record, and balances as of a date are sums over posted entries. Nothing to replay → current state.
  - "It's Core and regulated" is not one of the three needs.
- **Debit and credit.** Updating two Account Aggregates in one transaction breaks one-Aggregate-per-transaction. Splitting them across two transactions would leave a moment where the books don't balance. Neither is needed: the rule "postings sum to zero" lives in the entry. **`JournalEntry` holds both postings and is the Aggregate.** Account balances are derived values, so they are a Read Model. That also avoids a hot instance: the platform-fee account receives a posting on every sale.
- **"Check the balance, then create the payout" is write skew.** Two payout requests each read the same balance and each create their own Payout; both commits succeed and the merchant is overdrawn. The rule "reserved funds never exceed funds available for payout" must live in one Aggregate: **`MerchantPayoutAccount`**, one per merchant, holding the available amount (credited by `FundsSettled` events) and its reservations. Contention is per merchant: low.
- **Issuing a payout is a genuine Saga.** It is a named process, and the bank step can fail after funds were reserved:
  1. Reserve funds on the account: compensatable (`ReleaseReservation`).
  2. Risk approval on the payout: compensatable (reject, then release).
  3. Send to the bank: the **pivot**.
  4. Record the settlement and post the journal entry: retryable.

  `FundsReserved` is the semantic lock.

## Output: `design/merchant-funds/aggregates.md` (excerpt)

```markdown
---
name: aggregate-design
product: tallyfield
bounded-context: Merchant Funds
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-11-05
summary: Merchant Funds has JournalEntry (balanced postings), MerchantPayoutAccount (no over-reservation) and an event-sourced Payout justified by audit-as-record and state-as-of.
profile: enterprise
traces-to: [design/merchant-funds/ubiquitous-language.md, design/event-storming/software-design.md, design/subdomain-classification.md, design/context-map.md, requirements/nfr-specification.md]
---

# Aggregate Design: Merchant Funds

## Aggregate: JournalEntry

| Field | Value |
|---|---|
| **Root** | JournalEntry: one balanced set of postings recording a money movement |
| **Pattern** | Domain Model — the postings must balance within the entry |
| **Identity** | client-generated |
| **Concurrency** | optimistic — posted entries never change (a correction is a reversing entry), so conflicts arise only on drafts |
| **Event sourcing** | not used — checked temporal query (the journal of immutable entries already answers balance-as-of), retroactive projection and audit-as-record (the journal is the record): none needs a replayed stream |
| **Contention** | low — each entry is written once |
| **Cohesion buys / coupling costs** | the balance rule in one transaction / none: entries are independent |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| An entry's postings sum to zero, with debits equal to credits in each currency. | yes | no | no | True Invariant |
| A posted entry is never changed; corrections are new reversing entries. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| An account's balance field always equals the sum of its postings. | no | yes | yes | account-balance Read Model projected from EntryPosted |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| Posting | Entity (local) | line number within the entry | takes part in the balance rule |
| Money | Value Object, self-validating | all attributes | amount and a known currency |
| AccountCode | Value Object, self-validating | all attributes | must exist in the chart of accounts |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| PostEntry | postings balance per currency | entry posted, immutable | EntryPosted | as-is |
| ReverseEntry | entry posted, not already reversed | a new entry with opposite postings | EntryReversed | as-is |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| Payout | no | no | separate | by ID (source of a settlement entry) |

### Coordination

PayoutSettled → PostEntry for the settlement, idempotent on the payout ID.

### Exceptions taken

None. The balanced pair lives inside one entry, so no rule is broken; the rejected alternative, two Account Aggregates in one transaction, would have needed Exception 1.

## Aggregate: MerchantPayoutAccount

| Field | Value |
|---|---|
| **Root** | MerchantPayoutAccount: one merchant's funds available for payout and their reservations |
| **Pattern** | Domain Model — reservations must never exceed available funds |
| **Identity** | client-generated (one per merchant, keyed by the merchant's ID) |
| **Concurrency** | optimistic |
| **Event sourcing** | not used — none of the three needs applies; reservations are recorded in Payout's stream |
| **Contention** | medium — hourly settlement credits plus a few payout requests a day per merchant |
| **Cohesion buys / coupling costs** | the over-reservation rule, safe against write skew / settlement credits and reservations contend per merchant |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| Reserved funds never exceed the funds available for payout. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| A payout checks the merchant's ledger balance before it is created. | yes | no | no | moved here: a check outside this Aggregate is write skew |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| Reservation | Entity (local) | the payout's ID within this account | counted by the invariant |
| Money | Value Object, self-validating | all attributes | available and reserved amounts |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| CreditSettledFunds | settlement not already credited | available increased | SettledFundsCredited | internal only |
| ReserveFunds | amount ≤ available minus reserved | a reservation for the payout | FundsReserved | as-is |
| ReleaseReservation | the reservation exists | reservation removed | ReservationReleased | as-is |
| ConsumeReservation | the reservation exists | available and reserved reduced | ReservationConsumed | internal only |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| Payout | yes | no | separate: the reservation happens here first | by ID |

### Coordination

Saga step 1 (compensatable): ReserveFunds; compensation ReleaseReservation. Step 4 (retryable): ConsumeReservation on PayoutSettled.

### Exceptions taken

None.

## Aggregate: Payout

| Field | Value |
|---|---|
| **Root** | Payout: one transfer of a merchant's funds to their bank account |
| **Pattern** | Event-Sourced Domain Model — a payout is sent to the bank at most once, and its lifecycle must be replayable |
| **Identity** | business identifier via the Repository — the payout reference the merchant and the bank quote |
| **Concurrency** | optimistic — a conditional append on the expected stream version |
| **Event sourcing** | used — audit-as-record (the licence requires the payout's history as the authoritative record) and temporal query (state as of month-end for safeguarding); costs accepted: upcasting kept forever, snapshots every 50 events, event-sequence tests |
| **Contention** | low — a handful of events per payout, from the Saga and the risk team |
| **Cohesion buys / coupling costs** | the send-once rule and the lifecycle / none observed |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| A payout is sent to the bank at most once. | yes | no | no | True Invariant |
| A payout is sent only after funds are reserved and risk has approved it. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| A returned payout's funds are back in the account the same instant. | no | yes | no | PayoutReturned → CreditSettledFunds, eventual |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| BankAccount | Value Object, self-validating | all attributes | snapshot of the destination as approved |
| Money | Value Object, self-validating | all attributes | the amount |
| RiskDecision | Value Object | all attributes | the approval the send rule needs |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| RequestPayout | a valid bank account | status requested | PayoutRequested | translated to PayoutStatusChanged |
| RecordReservation | requested | status funds reserved | PayoutFundsReserved | translated to PayoutStatusChanged |
| ApprovePayout | funds reserved | status approved | PayoutApproved | translated to PayoutStatusChanged |
| AddRiskNote | not settled | note recorded | RiskNoteAdded | internal only |
| SendToBank | approved, never sent | status sent | PayoutSentToBank | translated to PayoutStatusChanged |
| RecordSettlement | sent | status settled | PayoutSettled | as-is |
| RecordReturn | sent | status returned | PayoutReturned | as-is |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| MerchantPayoutAccount | yes | no | separate | by ID |

### Coordination

Saga "Issue payout": 1 ReserveFunds (compensatable), 2 ApprovePayout (compensatable: reject, then ReleaseReservation), 3 SendToBank (pivot), 4 RecordSettlement → ConsumeReservation and PostEntry (retryable). Semantic lock: funds reserved / payout pending, shown to the merchant as "payout in progress". Orchestration or choreography is event-driven-patterns' choice.

### Exceptions taken

None.

## Open questions

- Does the licence require risk notes in the published record, or only in the internal stream? (assumed: internal only)
```

## Why this is right

- Event sourcing went to the one Aggregate with two named needs, not to the whole context because it is Core and regulated.
- The balanced pair is one Aggregate. The rejected two-Account design is named, with the exception it would have needed.
- The "check then create" request is declined with its reason, write skew, and the rule moved into the one Aggregate that can enforce it.
- The Saga is a named process with a pivot. Each step changes one Aggregate, and each compensation is a Command on a root.
- Internal events (risk notes, reservations consumed) stay internal; consumers get a coarse status change.
