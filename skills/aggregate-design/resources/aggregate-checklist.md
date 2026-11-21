# Aggregate Design Checklist

Run after `./scripts/validate-aggregate-design.sh` exits clean. The script checks structure; these items need judgement.

## Pattern choice
- [ ] Each use case's pattern follows from its rules, not from the subdomain type. A Core context with only Domain Models, or a Generic one with any, has been rechecked.
- [ ] Every `## Use case:` block says which rule was checked and why it doesn't need an Aggregate (no rule across records, or the rule failed the test).

## Invariants
- [ ] Each invariant is one specific sentence, not "these objects are related".
- [ ] The Q1–Q3 answers hold up for *this* business. Q2 "no" means a compensating action would really leave lasting harm, not just effort.
- [ ] Derived values (counts, totals, balances) are not invariants; they are queries or Read Models.
- [ ] Rejected candidates are listed with what handles them instead.
- [ ] Verdicts resting on an assumption about business tolerance are marked *assumed*, with an open question.

## Boundaries
- [ ] Every relationship has both answers, has-a and must-be-atomic; no merge rests on has-a alone.
- [ ] Each use case changes one Aggregate instance per transaction, or the exception is written down.
- [ ] No root holds an unbounded collection (all orders, all bookings, all postings).
- [ ] No Value Object holds another Aggregate; references are by ID.
- [ ] Every child Entity passes the outside-lookup test (nothing looks it up directly); otherwise it is its own Aggregate.
- [ ] A configuring concept (a rule, a policy, a price list) is its own Aggregate, and what it governs records which version applied.
- [ ] Each exception names Exception 1 or Exception 2 and why; a copied field is read-only and never authoritative.

## Identity and concurrency
- [ ] Identity is client-generated unless a business identifier or a written reason says otherwise.
- [ ] A non-optimistic strategy names its condition (hot instance, costly retry, batch job).
- [ ] Every rule spanning two Aggregates says how write skew is handled: a redrawn boundary, a constraint, scoped serialisable isolation, or accepted eventual consistency.
- [ ] Contention is estimated from who writes and how often; a high estimate has prompted a re-size or a stated reason.

## Coordination
- [ ] Each consequence in another Aggregate names its event, its idempotent reaction and what the user sees meanwhile.
- [ ] A Saga is a named business process; its steps are classed compensatable / pivot / retryable; compensations are Commands on roots; semantic-lock states are in the Aggregate's lifecycle.

## Event sourcing
- [ ] Used only where temporal query, retroactive projection or audit-as-record applies to this Aggregate; the costs are stated.
- [ ] Published events are translated and coarser than the internal stream; each Command says as-is, translated or internal only.

## Commands and language
- [ ] Every Command has a guard (requires) and a guarantee, and records one past-tense Domain Event.
- [ ] Names come from the context's Ubiquitous Language; no technical names (`DataService`, `RecordUpdated`).
- [ ] No code: members, rules and events only.

## Hand-off
- [ ] `domain-event-catalog` and `command-catalog` can be written from the Commands-and-events tables without guessing (standard and enterprise).
- [ ] At lean, the Domain Events, Commands and Read Models sections cover every context.
- [ ] `traces-to` names the language, Event Storming and classification documents used.
