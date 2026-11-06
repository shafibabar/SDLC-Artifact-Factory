# Validation and Rejection: Where Each Check Lives

The detail behind `SKILL.md` § 3–4. Every way a Command can fail is recorded with its kind and the place it is checked, so the API can map kinds to responses and the code puts each check in one place. Grounded in Vernon (*Implementing Domain-Driven Design*: the Aggregate protects its invariants) and Evans (*Domain-Driven Design*: the model, not the application layer, holds the rules), as summarised in `research/domain-driven-design/implementing-ddd-vernon.md` and `research/domain-driven-design/domain-driven-design-evans.md`.

## 1. The decision table

| Question about the check | Kind | Checked where | Uses state? |
|---|---|---|---|
| Is the request well-formed: present, in range, one of the allowed values, from the request alone? | invalid input | input, at the edge, before anything is loaded | no |
| May this actor issue this Command on this target? | not permitted | access check before the Aggregate changes (`access-control-model`) | the actor's attributes and the target's |
| Does the target exist? | not found | loading the target | the target's identity |
| Does another thing the Command names exist and qualify (the table, the courier)? | reference invalid | application, before calling the Aggregate (a read of the other thing, never a write) | another Aggregate or a Read Model |
| Does the Command break a rule about the target's own state? | rule violated | **the Aggregate** | the target, already loaded |
| Did the target change since the actor looked? | conflict | the Aggregate's version | the target's version |

The question that separates *reference invalid* from *rule violated* is not "does it need the database?" but **whose state is examined**: another thing's, or the target's own.

## 2. Why business rules stay in the Aggregate

A rule checked in the API or the handler is enforced only on that path. A Policy issuing the same Command, a batch import, an admin tool and the next API version all bypass it, and the Aggregate can no longer promise its invariant to anyone. Cost is not a reason to move a rule: the target is loaded anyway, and checking its own state in memory is cheap.

Input checks are the opposite: they may be repeated at the edge for a fast answer (a form, the API), because they need nothing but the request and cannot drift from the model's meaning. A rule must never be *only* at the edge.

**Not permitted is not a rule violation.** "Only the venue's own hosts may cancel" is access control: who may act. "A seated booking cannot be cancelled" is a rule about the booking: what may happen. They fail differently (one says "you may not", the other "this cannot happen now") and live in different places.

## 3. Rules about another Aggregate

A rule like "a booking can only be confirmed while the venue is open for bookings" mentions another Aggregate. The target cannot load it (one Aggregate per transaction). Choose per rule:

| Option | How | Use when |
|---|---|---|
| Read-only copy (`aggregate-design` Exception 2) | The target holds the other's relevant status, kept current by its events; the rule is checked in the Aggregate against the copy | The other state changes rarely, and acting on a copy a few seconds old is acceptable to the business |
| Reference check in the application | Read the other thing's current state before calling the Aggregate; reject as *reference invalid* | The rule needs the current state and a tiny race window is acceptable |
| Redraw the boundary | Re-run the three-question test | Neither is acceptable: the two states must be atomic, so they are one Aggregate |

Record which option each such rule uses, and what the business accepts in the window.

## 4. What a rejection does

- **Nothing changes and no event is recorded.** A rejection is an answer to the caller, not a business fact. (Where the business does care about attempts, for example repeated failed withdrawals as a fraud signal, that is a separate fact recorded by its own Command and stated as such.)
- **The caller gets the kind and a reason in the language,** so a person can act on it: "The guest is already seated", not "precondition failed".
- **A duplicate of a rejected Command gets the same rejection** (`./retries-and-outcomes.md`).
- **A rejection is a normal outcome,** never an error that crashes or pages anyone.

## 5. Inputs and their sources

| Source | Examples | Rule |
|---|---|---|
| The caller's intent (the request) | party size, new time, reason | each has a meaning and an input rule |
| The target | the reservation's identity | named by the caller from what it already has |
| The caller's authenticated context | who issued it; the tenant (multi-tenant products only, D047-7) | **never** taken from the request body: a client that can set them can act as anyone, anywhere |
| The triggering event (Policy-issued) | the event's ID, the facts it carries | the Policy names the event in "Whenever X, then Y" |
| The clock | when the Command was received | set by the receiver; the Aggregate records its own time on the event |

An input the intent does not need is not carried. A free-text "reason" is carried only when a person or a later rule reads it.
