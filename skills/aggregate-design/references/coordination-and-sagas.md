# Coordination Between Aggregates

The detail behind `SKILL.md` § 5's Rule 4: how a change in one Aggregate reaches another, and when a multi-step process is a genuine Saga rather than a boundary drawn in the wrong place. Grounded in Vernon (*Implementing Domain-Driven Design*, Ch. 8, 10) and Richardson (*Microservices Patterns*, Ch. 4), as summarised in `research/domain-driven-design/implementing-ddd-vernon.md` and `research/software-architecture/microservices-patterns-richardson.md`. The mechanics (outbox, consumers, Saga state, choreography vs orchestration) belong to `event-driven-patterns`; this file covers only what the Aggregate design must decide.

## 1. Eventual consistency is the outcome, not a compromise

Everything correctly pushed outside a boundary is exactly what never belonged inside it: the three-question test already showed those rules tolerate a moment of staleness. Vernon's rule of thumb is a design target: **one use case changes one Aggregate instance in its transaction.** Other consequences follow from the Domain Event it records, in their own transactions.

What the design must state for each such consequence:
- **the Domain Event** that carries it, with the fields the reaction needs (including the prior value when a reaction may need to undo it);
- **who reacts**, and that the reaction is idempotent (it may run more than once);
- **what the user sees meanwhile.** A flow that depends on the second update shows a pending state honestly ("refund requested, 2 of 3 steps done") instead of pretending it is complete.

Delivery rules the design relies on, without designing them: events are recorded in the same transaction as the state change and published after commit (`event-driven-patterns`' Transactional Outbox), at least once; consumers are idempotent. Vernon also allows a simple in-process publisher for reactions inside the same process (a cache refresh). That is never a licence to change a second Aggregate in the first one's transaction.

## 2. Modelling smell or genuine Saga?

```
Does correctness need two or more Aggregates to reflect one fact with ZERO tolerance for a
visible in-between state?
├─ Yes → re-run the three-question test on that exact rule.
│   ├─ Fails (the usual outcome) → a MODELLING SMELL. Either the boundary is wrong, or plain
│   │    eventual consistency was the answer all along.
│   └─ Passes → NOT A SAGA EITHER. A Saga exposes in-between states by design. Redraw the
│        boundary so one Aggregate holds the rule, or use a constraint or scoped serialisable
│        isolation (./sizing-and-concurrency.md § 4).
└─ No → is there an ordered, named multi-step business process (one a domain expert names:
    "issuing a payout", "onboarding a tenant") where a later step can fail after earlier steps
    committed, so the business must decide what happens to them?
    ├─ No  → PLAIN CHOREOGRAPHY: publish the event; each reaction is independent and idempotent.
    └─ Yes → A GENUINE SAGA. Classify each step (Richardson): compensatable, pivot (the point of
         no return) or retryable (after the pivot, retried until it succeeds). Choreography or
         orchestration is event-driven-patterns' choice.
```

The fastest tell: if the "coordination" disappears once the three questions are answered honestly against the specific rule, it was never a Saga.

## 3. What a Saga step looks like from inside an Aggregate

- **Each step is an ordinary one-Aggregate transaction** with its own invariant checks and its own Domain Event. A step that seems to need two Aggregates changed together has not been decomposed far enough: split it.
- **A compensation is a real, named Command on the target root**, checked like any other (`ReleaseReservation`, `CancelPayout`), never a field forced back to its old value because "it's only a compensation". It is a new fact layered on top, not an undo.
- **Compensation data comes from good event design.** An event that already carries the prior value gives the compensating step what it needs.
- **Semantic locks** (Richardson): a step that must stop other work touching a record mid-Saga sets a status on its Aggregate (`Reserved`, `PayoutPending`) that a later step clears. Name these states in the Aggregate's design; they are part of its lifecycle.
