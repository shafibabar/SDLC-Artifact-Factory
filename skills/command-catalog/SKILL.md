---
name: command-catalog
description: >
  Catalog the Commands of a Bounded Context: what each Command intends in the
  Ubiquitous Language, how it is named (an imperative domain verb, one
  Command per intent, never UpdateX with a status field or a bag of optional
  fields), which actor, Policy or schedule issues it, which single Aggregate
  it targets, what inputs it carries and where they come from, every way it
  can be rejected and where each check lives (input shape before the
  Aggregate, business rules inside it), how a retried or duplicated Command
  is made idempotent, and which Domain Event it records. Use when naming or
  reviewing a Command, splitting a CRUD-shaped update, deciding where a
  validation belongs, defining idempotency and the duplicate outcome, or
  writing the context's command catalog. HTTP methods, paths and status
  codes are api-contract-design; handler code is go-service-layer. Used by
  domain-modeler.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, commands, command-catalog, validation, idempotency, cqrs]
produces: command-catalog
domain: domain-modeling
status: stable
related: [aggregate-design, domain-event-catalog, event-storming-facilitation, ubiquitous-language, read-model-design, cqrs-pattern, api-contract-design, access-control-model, go-service-layer, go-domain-model, go-chi-handler]
sources:
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/implementing-ddd-vernon.md
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
  - research/software-architecture/api-design-patterns-geewax.md
---

# Command Catalog

## Purpose

A Command is a request to change state, named for the intent behind it. Unlike a Domain Event, which already happened, a Command **may be rejected**. It targets **one Aggregate instance** (Vernon: one use case, one Aggregate, one transaction) and answers only success or failure, never read data (Evans's separation of commands from side-effect-free queries). The catalog is the context's record of **what each Command intends**, who may issue it, what it needs, every way it can fail, and what it records.

What the catalog does **not** hold:
- Aggregate boundaries, guards and the events each Command records are decided in `aggregate-design`; the catalog lists them per Command.
- HTTP methods, paths, status codes and async responses are `api-contract-design`'s. The catalog gives it the Commands, their rejections by kind and their idempotency keys.
- Code (structs, handlers, validators) is `go-service-layer`, `go-domain-model` and `go-chi-handler` (D047-10).

At **lean** the catalog is skipped. Commands go in the Commands table of `aggregate-design`'s `domain-model.md`, under the same naming, validation and idempotency rules.

## 1. Where Commands Come From

The blue stickies of the Event Storming wall (Brandolini's chain: read model → actor → Command → system → event → policy), the Commands-and-events tables in `aggregates.md`, the "whenever X, then Y" policies in `domain-event-catalog` (Y is a Command in the reacting context), time passing that the business acts on (a loan falls due: a schedule issues `MarkLoanOverdue`; a state nobody acts on is just read from a Read Model), and the user stories. A Command that records no event, or an event no Command or Policy raises, is a gap to close first.

## 2. Naming: Which Intent?

- **Imperative, a domain verb from the context's language, then what it acts on:** `ConfirmBooking`, `ReassignCourier`, `WaiveLateFee`. A domain expert should recognise the intent unprompted.
- **One Command per intent.** `UpdateOrder` with a `status` field, or with a bag of optional fields, hides several intents with different rules, actors and events. Ask what the user is trying to do and split: `ConfirmOrder`, `CancelOrder`, `ChangeDeliveryAddress`. Each can then state its own guard.
- **No CRUD or technical verb** (`Update`, `Set`, `Edit`, `Save`, `Process`, `Handle`). `Create` and `Delete` usually have a better word (`EnrolMember`, `WithdrawListing`).
- **Not a query** (`Get`, `List`, `Find`): reads go to a Read Model.
- No `Command` suffix and no version in the name. The event it records is a past-tense fact (`OrderCancelled`), never `CancelOrderEvent`.

Splitting worked through, and the command-storm trap: `./references/naming-and-targeting.md`.

## 3. What a Command Carries

- **The intent's inputs, in the language:** only what this intent needs, each with its meaning.
- **The target:** which Aggregate instance, by identity.
- **Facts from the caller's context, never from the request body:** who issued it (the actor or the Policy), and, where the product is multi-tenant, the tenant (D047-7). The Command still carries both; they are filled from the authenticated context, because a client that can set them can act as someone else. A globally unique target ID does not remove the tenant: it says which thing, not whether this caller may touch it.
- **An idempotency key** (§ 5), and where concurrency matters, the **version the actor saw** (§ 6).

Field types and formats are not decided here. Each input records its meaning, its source, and the rule it must meet before it reaches the Aggregate.

## 4. Rejections and Where Each Is Checked

List every way the Command can fail, each with its **kind** and **where it is checked**:

| Kind | Checked where | Example |
|---|---|---|
| invalid input | input: the request alone, no lookups | party size missing or zero |
| not permitted | access check before the Aggregate (`access-control-model`) | a host cancelling another venue's booking |
| not found | loading the target | no such reservation |
| reference invalid | application: another thing the Command names | the table it names doesn't exist |
| rule violated | **the Aggregate** | cancelling after the guest was seated |
| conflict | the Aggregate's version | the booking changed since the host opened it |

**A business rule lives in the Aggregate**, even when it is cheap to check earlier. A check placed in the API or handler is skipped by every other way in: a Policy, a batch job, an admin tool, a second API. Input checks may repeat cheaply at the edge; rules may not move there. A rule about another Aggregate's state is either a reference check or a read-only copy the Aggregate holds (`aggregate-design` Exception 2). Detail and the decision table: `./references/validation-and-rejection.md`.

## 5. Retries and Idempotency

Every Command can arrive twice: a client retries after a timeout, a gateway replays, a Policy's event is delivered at least once. For each Command, state:
- **The idempotency key:** a request ID the caller keeps for every retry of one intent; for a Policy, the triggering event's ID.
- **The duplicate outcome:** a repeat with the same key returns **the first outcome, including its rejection**, and changes nothing. A fresh success for a Command that first failed tells the caller something false.
- **How long keys are kept:** at least the longest retry horizon, failover included. A key forgotten too early lets a late retry apply twice.
- **A repeat with a new key** when the state already matches (cancel a cancelled booking): either succeed without recording anything, or reject. Choose one per Command and say which.

The dedupe record commits with the state change, in the same store, so it fails over with it. An external effect (a payment provider call) passes the same key downstream. Detail: `./references/retries-and-outcomes.md`.

## 6. Outcome and Concurrency

- **Success records the event(s) from `aggregates.md`:** usually one, two only when the success is two distinct facts different consumers act on (`domain-event-catalog` § 3), never none.
- **The reply is an acknowledgement and identifiers**, not the changed state. Callers read the Read Model. Whether the caller needs the outcome now or can learn it later is recorded; how the API responds is `api-contract-design`'s.
- **Concurrency:** where acting on stale information would break the actor's intent, the Command carries the version the actor saw and a mismatch is a *conflict*. Otherwise say why none is needed.

## Producing the Catalog

One `design/<context>/command-catalog.md` per Bounded Context (`./templates/command-catalog.md`). No code, no HTTP.

1. **Read** the context's `aggregates.md`, the Event Storming Process or Software Design output, the `domain-event-catalog` policies that issue Commands here, the Ubiquitous Language and the user stories.
2. **List the intents.** Reconcile the sources, close gaps, and name each by § 2, splitting CRUD-shaped requests.
3. **Per Command:** intent, target Aggregate, issuer, inputs with source and input rule, every rejection with kind and place, idempotency key and duplicate outcome, concurrency, events recorded. Mark the source of each Command; one resting on an assumption is *assumed*, with an open question.
4. **Plan → validate → execute** for renaming or retiring a Command that an API or another context already calls: agree it with `api-contract-design` and the callers first.
5. **Validate, then loop.** Run `./scripts/validate-command-catalog.sh design/<context>/command-catalog.md`. Fix every FAIL and re-run until it exits clean, then go through `./resources/catalog-checklist.md`.
6. **Present** the Commands, the splits you made, and for every request you declined, its reason in full (§ Gotchas). Hand the catalog to enterprise-architect for `api-contract-design`.

Examples: `./examples/01-lean-commands-in-domain-model.md` (lean: no catalog), `./examples/02-standard-cancel-reservation.md` (input vs rule rejections), `./examples/03-enterprise-capture-across-failover.md` (a retried capture across a regional failover).

## Gotchas

Each trap comes with the reason to give in full.

- **"One `UpdateBooking` endpoint with optional fields is simpler."** *Reason:* it hides several intents with different rules, actors and events, so no guard can be stated and the audit loses what the user meant. *Instead:* one Command per intent.
- **"Check that rule in the API handler; it's cheaper there."** *Reason:* every other entry point (a Policy, a batch job, an admin tool) skips it, and the Aggregate can no longer promise its invariant. *Instead:* the rule lives in the Aggregate; only input-shape checks belong at the edge.
- **"Take `userId` and `tenantId` from the request body."** *Reason:* a caller who can set them can act as anyone in any tenant. *Instead:* both come from the authenticated context.
- **"Generate the idempotency key on the server per request."** *Reason:* a retry gets a new key, so the Command applies twice. *Instead:* the caller keeps one key for all retries of one intent; a Policy uses the triggering event's ID.
- **"A retry after a rejection can just run again."** *Reason:* if state moved meanwhile, the retry succeeds, and the caller sees two answers to one request. *Instead:* a duplicate returns the first outcome, rejection included.
- **"Return the updated booking from the Command."** *Reason:* the write path takes on read concerns and the two can't scale or change apart (Evans). *Instead:* return an acknowledgement and identifiers; read the Read Model.
- **"Change two Aggregates in one Command."** *Reason:* that is a transaction across consistency boundaries (Vernon). *Instead:* change one; the event it records drives the other, or a Saga (`aggregate-design` § 5).
- **"Send 50 Commands in a client loop for the bulk action."** *Reason:* a failure part-way leaves no record of what was meant or done. *Instead:* one Command starts a tracked process that issues the single Commands and reports progress.

## References

| Question | File |
|---|---|
| Is this the right name? Split or not? One Aggregate? Bulk actions? | `./references/naming-and-targeting.md` |
| Where does this check live? Which kind of rejection? Rules about other Aggregates? | `./references/validation-and-rejection.md` |
| Idempotency key, duplicate outcome, key retention, failover, concurrency, the reply | `./references/retries-and-outcomes.md` |
| Checking before hand-off | `./resources/catalog-checklist.md` |
