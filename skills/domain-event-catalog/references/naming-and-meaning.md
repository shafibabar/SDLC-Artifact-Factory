# Finding, Naming and Shaping Domain Events

The detail behind `SKILL.md` § 1–3: where events come from, how they are named, and what each one carries. Grounded in Evans (Domain Events as his later addition to the tactical patterns), Vernon (*Implementing Domain-Driven Design*, Ch. 8), Khononov (*Learning Domain-Driven Design*) and Brandolini (*Introducing EventStorming*), as summarised in `research/domain-driven-design/domain-driven-design-evans.md`, `research/domain-driven-design/implementing-ddd-vernon.md`, `research/domain-driven-design/learning-ddd-khononov.md` and `research/domain-driven-design/introducing-eventstorming-brandolini.md`.

## 1. Where events come from

- **The Event Storming wall.** Orange stickies are facts in the past tense that matter to the business (Brandolini). The catalog starts from the Process Modelling or Software Design wall for this context, not from the code or the tables.
- **`aggregate-design`'s Commands-and-events tables.** Each Command records one event, with its guard and guarantee. An event in the catalog that no Aggregate records, or an Aggregate Command that records nothing, is a gap to close.
- **Policies and time.** "Whenever X, then Y" reactions, and time passing ("the hold expired"), also raise events.

Evans's reason for the pattern: an event lets an Aggregate tell the rest of the system what happened without a reference to, or a call into, any other Aggregate. That is how one-Aggregate-per-transaction stays workable.

## 2. Naming

- **Past tense, in the context's Ubiquitous Language, naming the business fact**: `ParcelDeposited`, `RefundIssued`, `HoldExpired`. A domain expert should recognise it unprompted.
- **Ask which fact happened.** A generic name hides several facts that consumers treat differently:

  | Generic | The facts it hides | Why it matters |
  |---|---|---|
  | `CustomerUpdated` | `CustomerRelocated`, `AddressCorrected`, `ContactPreferenceChanged` | Tax and delivery react to a move but not to a typo fix |
  | `OrderChanged` | `OrderItemAdded`, `DeliverySlotRescheduled`, `OrderCancelled` | Each has different consumers and different follow-ups |
  | `StatusChanged` | one event per transition that matters (`ClaimApproved`, `ClaimRejected`) | Consumers otherwise decode the status to learn what happened |

- **No CRUD verb as the fact.** `Created`, `Updated`, `Changed`, `Modified`, `Deleted` and `Saved` describe what the database did. The language almost always has a better word (`MemberEnrolled`, not `MemberCreated`; `ListingWithdrawn`, not `ListingDeleted`).
- **No Command disguised as an event.** `SendReminder` is an instruction. The fact is `PaymentOverdue`, and a Policy in the consumer decides to send the reminder.
- **No technical events.** `RowInserted`, `CacheRefreshed` and `MessageProcessed` are not domain facts and don't belong in the catalog.
- **No version in the name.** `RefundIssuedV2` is a wire-contract problem. A changed shape or meaning is handled by `event-schema-design`'s protocol.
- **Name format:** PascalCase `[Subject][PastTenseVerb]` in the catalog. The published wire type is derived from it by `event-schema-design` (lower-case reverse-DNS, e.g. `com.fernpost.lockers.parcel.deposited`).

## 3. One fact, the right size

One event per business fact, not one per field change and not one per transaction. If a single Command produces two facts that different consumers care about (`OrderPlaced` and `LoyaltyPointsEarned`), record both. If several field changes are one fact (`DeliveryRescheduled` changes the date and the slot), record one.

## 4. What the payload carries (meaning, not format)

The catalog says what each field *means* in the language and why a consumer needs it; `event-schema-design` fixes its type, whether it is required, and its default.

- **Carry what consumers need to react without calling back:** the identifiers (by ID, never embedded objects of other Aggregates: `aggregate-design` Rule 3), the values that changed, the **prior value** when consumers act on transitions, the actor, and the business reason where it matters.
- **Not a state dump.** The whole Aggregate couples every consumer to the write model; every internal change becomes a contract negotiation.
- **Not anaemic.** An ID alone forces every consumer to call back, coupling them in time to the producer.
- **Not envelope facts.** Event ID, type, occurrence time, source, tenant and correlation are envelope attributes (`event-schema-design`), not payload fields.
- **No raw sensitive values** on a retained, replicated topic. Carry a reference; consumers fetch under access control (`data-retention-policy`).

**Thin "something changed" events (house guidance, not from the research files).** An event carrying only the ID, with consumers fetching state, is a deliberate choice when consumers would always re-read the latest state anyway and the facts are many and small. State it per event, with the cost: every consumer depends on the producer being up to answer the call-back.
