---
name: domain-event-catalog
description: >
  Catalog the Domain Events of a Bounded Context: what each event means in
  the Ubiquitous Language, how it is named (a past-tense business fact, never
  a CRUD verb like Updated or a command in disguise), which Command, Policy
  or deadline raises it, what its payload carries and why, whether it stays
  internal or is published to other contexts (and how internal events
  translate to coarser published ones), who consumes it with which reaction,
  and how long the business needs it. Use when naming or reviewing an event,
  deciding what goes in its payload, choosing between one generic event and
  several specific facts, deciding which events to publish, listing an
  event's consumers and policies, or writing the context's event catalog. The
  envelope, wire type and versioning are event-schema-design; delivery
  (outbox, relay, dead-letter queue) is event-driven-patterns. Used by
  domain-modeler.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, domain-events, event-naming, event-catalog, policies, integration-events]
produces: domain-event-catalog
domain: domain-modeling
status: stable
related: [aggregate-design, event-storming-facilitation, ubiquitous-language, event-schema-design, event-driven-patterns, context-map-patterns, command-catalog, read-model-design, cqrs-pattern, data-retention-policy, go-event-publisher, go-event-consumer]
sources:
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/implementing-ddd-vernon.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
  - research/software-architecture/microservices-patterns-richardson.md
---

# Domain Event Catalog

## Purpose

A Domain Event is something that happened in the domain that matters to the business: immutable, past tense, named in the Ubiquitous Language. Evans added it to the tactical patterns so an Aggregate can tell the rest of the system what happened without a reference to, or a call into, another Aggregate. The catalog is the context's record of **what each event means**, who raises it, and who reacts. Any integration not in a catalog is undocumented coupling.

What the catalog does **not** hold (D047-1, D047-2):
- the envelope, wire type, field types, versioning and registry, which are `event-schema-design`'s (`design/data/event-schemas.md`);
- delivery (the Transactional Outbox, relay, Change Data Capture, the Dead Letter Queue), which is `event-driven-patterns`';
- the code, which is `go-event-publisher` and `go-event-consumer`.

At **lean** the catalog is skipped; events are listed in `aggregate-design`'s `domain-model.md`, under the same naming and payload rules.

## 1. Where Events Come From

From the Event Storming wall (orange stickies, Brandolini), from `aggregate-design`'s Commands-and-events tables (each Command records one event), and from Policies and deadlines ("the hold expired"). An event no Aggregate records, or a Command that records nothing, is a gap to close before cataloguing.

## 2. Naming: Which Fact Happened?

- **Past tense, in the context's language, naming the business fact**, so a domain expert recognises it: `ParcelDeposited`, `RefundIssued`, `HoldExpired`.
- **Ask which fact happened.** `CustomerUpdated` hides `CustomerRelocated`, `AddressCorrected` and `ContactPreferenceChanged`, and Tax reacts to a move but not to a typo fix. One event per business fact; several field changes that are one fact are one event.
- **Never a CRUD or technical verb as the fact** (`Updated`, `Changed`, `Modified`, `Saved`, `RowInserted`). `Created` and `Deleted` usually have a better word (`MemberEnrolled`, `ListingWithdrawn`).
- **Never a Command disguised as an event.** `SendReminder` is an instruction; the fact is `PaymentOverdue`, and a Policy in the consumer decides to remind.
- **No version in the name.** A changed shape or meaning follows `event-schema-design`'s protocol.
- PascalCase here; `event-schema-design` derives the lower-case wire type from it.

Worked contrasts: `./references/naming-and-meaning.md`.

## 3. What the Payload Carries

The catalog states what each field **means** and why a consumer needs it; `event-schema-design` fixes its type and default. Carry what consumers need to react **without calling back**: identifiers (other Aggregates by ID), the values that changed, the **prior value** when consumers act on transitions, the actor, the reason where it matters. Not the whole Aggregate (it couples every consumer to the write model), not an ID alone unless that is a stated choice, not envelope facts (event ID, time, tenant, correlation), never raw sensitive values on a retained topic.

## 4. Internal or Published

- **Internal:** stays inside the context. **Stored:** an event-sourced Aggregate's own stream. **Published:** a fact other contexts react to, and therefore a contract.
- **Publish the business-meaningful fact, not every internal step** (Khononov). Translate fine-grained internal or stored events into coarser published ones, and record which map to which and which are never published. Publishing the internal stream couples consumers to how the Aggregate stores itself.
- A published event sits on a context-map line; the line's pattern (`context-map-patterns`) says what the contract obliges.

## 5. Consumers, Policies, Retention Need

- For each published event, every known consumer with its reaction as a policy: **"Whenever `PaymentOverdue`, then `SendReminder`"**. The Command belongs to the consumer's context.
- Delivery is at least once (Vernon), so **every reaction is idempotent**; say on what. Order holds only within one Aggregate; a causal chain is followed through `correlationid` and `causationid`. Record per consumer what a stuck (dead-lettered) event does to its order.
- **Retention need:** why and how long the business needs the event (audit evidence, consumer replay, operational only). The schedule is `data-retention-policy`'s.

Detail, the causation chain and the stuck-event choice: `./references/visibility-and-consumers.md`.

## Producing the Catalog

One `design/<context>/domain-event-catalog.md` per Bounded Context (`./templates/domain-event-catalog.md`). No code, no DDL.

1. **Read** the context's `aggregates.md` (Commands and events), the Event Storming Process or Software Design output, the context's Ubiquitous Language and the context map (which lines carry events).
2. **List the facts.** Reconcile the wall and the Aggregates; close gaps. Name each fact by § 2, splitting generic events into the facts they hide.
3. **Per event:** its meaning in one sentence, the Aggregate, what raises it, visibility, payload meaning, guarantees, consumers and policies, ordering and retention need. For internal and stored events, the translation to published ones.
4. **Agent-run:** a consumer or reaction that rests on an assumption (another context's intent) is marked *assumed*, with an open question.
5. **Plan → validate → execute** for a change to a published event (rename, changed meaning, retirement): agree it with `event-schema-design`'s protocol and the consumers before editing the catalog.
6. **Validate, then loop.** Run `./scripts/validate-domain-event-catalog.sh design/<context>/domain-event-catalog.md`. Fix every FAIL and run it again until it exits clean, then go through `./resources/catalog-checklist.md`.
7. **Present** the published events and their consumers, the translations, and for every request you declined, its reason in full (§ Gotchas). Then hand the published events to data-architect for `event-schemas.md`.

Examples: `./examples/01-lean-events-in-domain-model.md` (lean: no catalog), `./examples/02-standard-food-delivery.md` (a generic event split; coarse published facts), `./examples/03-enterprise-claims-event-sourced.md` (a stored stream translated for other contexts).

## Gotchas

Each trap comes with the reason to give in full.

- **"Call it `CustomerUpdated`; consumers can work out what changed."** *Reason:* a generic event hides several business facts that consumers react to differently; each consumer then decodes fields to guess which fact happened, and the language loses the words. *Instead:* ask which fact happened and name each one (`CustomerRelocated`, `AddressCorrected`).
- **"Publish every event in the stream so consumers have full detail."** *Reason:* internal and stored events mirror how this Aggregate stores itself; publishing them makes every internal change a breaking change for other contexts (Khononov). *Instead:* publish coarser business facts and record the translation.
- **"Emit `SendInvoice` when the order ships."** *Reason:* that is a Command in disguise; the producer would be deciding the consumer's work. *Instead:* publish the fact (`OrderShipped`); Billing's policy decides to invoice.
- **"Put the whole Order in the payload so nobody has to call back."** *Reason:* a state dump couples every consumer to the write model and carries data no consumer needs, sensitive data included. *Instead:* the fact, the identifiers, what changed and the prior value where it matters.
- **"Add `eventId`, `occurredAt` and `tenantId` to the payload."** *Reason:* those are envelope attributes (`event-schema-design`); duplicates drift. *Instead:* the payload holds the fact only.
- **"Consumers can rely on events arriving in order."** *Reason:* order holds only within one Aggregate's partition, and a dead-lettered event lets later ones overtake it. *Instead:* record per consumer what it needs and what it does with a stuck event; follow causation IDs for chains.
- **"Add the outbox table and DLQ topics to the catalog."** *Reason:* delivery is `event-driven-patterns`' and the code is the go-* skills'; the catalog is meaning (D047-10, W2-10). *Instead:* name the events, consumers and retention need; point to those skills.
- **"Version it as `RefundIssuedV2`."** *Reason:* a version in the name is a wire-contract fix applied in the wrong place; `event-schema-design` owns the one protocol (D047-1). *Instead:* keep the business name; a changed meaning is a new fact with a new name.

## References

| Question | File |
|---|---|
| Where do events come from? Is this the right name? What goes in the payload? | `./references/naming-and-meaning.md` |
| Internal or published? Consumers, idempotency, ordering? Retention need? | `./references/visibility-and-consumers.md` |
| Checking before hand-off | `./resources/catalog-checklist.md` |
