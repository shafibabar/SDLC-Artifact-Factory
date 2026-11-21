# Example 1 — Lean: Events in the Domain Model, Not a Catalog

Self-contained. **Gearloop** books bike repairs for a two-mechanic workshop, at the **lean** profile: one deployable, contexts **Bookings** and **Workshop**. The phase plan skips `domain-event-catalog` at lean, so the events live in `aggregate-design`'s `design/domain-model.md`, under the same naming and payload rules.

## Input

> **User:** "Add `CustomerUpdated` and `RepairUpdated` events and publish everything to the broker, so the reminder emails can pick whatever they need."

## Working it

- **Which fact happened?** `RepairUpdated` covers three facts the workshop treats differently:
  - `RepairQuoted`: the customer must approve;
  - `PartsOrdered`: the due date moves;
  - `RepairCompleted`: the customer is told to collect.

  The reminder sender reacts to the first and the last. `CustomerUpdated` turns out to be `ContactDetailsCorrected`, and nothing reacts to it.
- **Publish everything:** declined. In one deployable with one reacting component, these are in-process reactions; there is no other context to publish to. Each event still carries what the reminder needs, so the reminder never reads the repair's internals.
- **Payload:** `RepairQuoted` carries the quote amount and the work, not the whole repair. `RepairCompleted` carries the collection deadline.

## Output: the Domain Events section of `design/domain-model.md`

| Context | Event (past tense) | Raised by | Carries | Who reacts |
|---|---|---|---|---|
| Workshop | RepairQuoted | QuoteRepair | repairId, quoted work, amount, valid until | reminder sender: whenever RepairQuoted, then email the approval link (idempotent on repairId + quote) |
| Workshop | PartsOrdered | OrderParts | repairId, parts, new due date | booking view shows the new date |
| Workshop | RepairCompleted | CompleteRepair | repairId, collect by | reminder sender: whenever RepairCompleted, then email "ready to collect" |
| Bookings | ContactDetailsCorrected | CorrectContactDetails | customerId | nothing yet; recorded for the audit of who changed what |

## Why this is right

- The two generic events became the specific facts the business acts on.
- "Publish everything" was declined with its reason: there is no second context; the reactions are in-process.
- Lean is shorter, but the naming and payload rules still apply.
