# Saga Design: Triggers, Step Classes, the Pivot and Compensation

Reference for `workflow-orchestration` steps 2 to 5. Design level only; the code is the `go-*` skills. Grounded in Richardson (*Microservices Patterns*, sagas and the three step classes), Ford (*The Hard Parts*, the three axes and the saga archetypes), Richards and Ford (*Fundamentals of Software Architecture*, mediator topology) and Kleppmann (why two-phase commit is not the answer).

## What a saga is

A saga is a sequence of **local transactions**, one per service, coordinated by messages. If a step fails, **compensating transactions** undo the steps already committed. Richardson: it gives atomicity (by compensation), consistency and durability, and gives up **isolation** (`./isolation-countermeasures.md`). It replaces two-phase commit, which blocks: a coordinator crash after the "yes" votes strands participants holding locks (Kleppmann).

A saga exists only where steps cross a transaction boundary. Steps inside one deployable and one database share one ordinary transaction; that is not a saga and needs none of this.

## When to orchestrate: Richardson's rule

**Choreography is the default** (`event-driven-patterns`): each service reacts to events and no one holds the flow. **Orchestrate** (a central coordinator sends commands and consumes replies; Richards and Ford call this the mediator topology) when any one of these fires:

| Trigger | Why choreography fails here |
|---|---|
| **Branching or looping** (parallel fan-out and join, a retry loop, a path chosen by a reply) | The logic smears across services and the implicit event order cannot be traced |
| **Long-running** (a human approval, an external signal, hours or days) | No participant owns the suspended flow; it is lost between reactions |
| **One view of progress** ("where is this one now?" must have one answer) | Choreography answers only by reading every service's logs |
| **Compensation across 4 or more services** in a defined reverse order | Autonomous reactors have no one to sequence the undo |

Name the trigger that fired in the document. None fired: do not orchestrate. A simple flow of 2 or 3 independent steps stays choreographed, and every orchestrator adds a component all participants depend on. Choreography also has its own faults (circular event chains, a six-service process nobody can trace); those are the reason the triggers exist, not a reason to orchestrate by habit.

**Three axes.** An orchestrated flow is written "async · eventual · orchestrated" (communication, consistency, coordination; `event-driven-patterns`). Ford's archetype for it is the *Parallel Saga*, a sound default for a complex multi-step process. The archetype names are memory aids; keep them out of artifacts a product owner reads, or add one as a parenthetical. "Atomic" across services does not exist here: it means a boundary was drawn wrong.

## The three step classes

A committed local transaction is visible at once and cannot be rolled back. So designing a saga is deciding where the **pivot** sits.

| Class | Where | Obligation |
|---|---|---|
| **Compensatable** | Before the pivot | A written compensating transaction, run in reverse order |
| **Pivot** | Exactly one | The point of no return: once it commits the saga runs forward to completion. It is the last step at which abandoning the whole flow is acceptable |
| **Retriable** | After the pivot | Retried until it succeeds, never compensated |

**Placing the pivot.** Put it at the step that authorizes an irreversible effect (a payment captured, a contract signed, a record published to outside parties), or at the step after which finishing is better than undoing. Steps with effects that cannot be undone sit at or after the pivot; reorder so that irreversible effects come as late as the business allows (the "pessimistic view", `./isolation-countermeasures.md`). The pivot may be the last compensatable step, or a confirm step that commits nothing to undo.

**The pivot's own failure.** If the pivot step fails it has not committed, so the steps before it are compensated. Once it commits, there is no backward path. State this precisely: "no compensation after the pivot commits".

**Two pivots is two sagas.** A flow with two points of no return has no single behaviour on late failure. Split it: the first saga ends at its pivot, and its completion starts the second.

**A saga with no pivot named, or a compensatable step with no compensation, fails review.**

## Writing a compensation

1. **Semantic, not rollback.** Cancelling a hold does not un-happen "held"; both facts stay in history. Consumers that saw the first event tolerate the corrective one.
2. **Capture on the way forward.** Record what the undo needs (the hold id, the amount, the prior value) when the step runs. A compensation that looks up current state races concurrent changes.
3. **Always eventually applicable.** Idempotent, retried with backoff, and escalated (an alert, a manual-repair queue) if it cannot succeed. A compensation that can fail for good leaves a half-done flow no one owns.
4. **Reverse order.** Undo the most recent compensatable step first.
5. **It is a step too.** It has an owner, is sent as a command, and a reply moves the coordinator on; it is not a catch block.

## Forward recovery after the pivot

Retriable steps are safe to repeat (idempotent) and retried with exponential backoff and jitter. A step that can fail permanently (an external party refuses) is handled forward: the flow moves to a visible "needs repair" state with an owner, never silently unwound. Say which steps can fail for good and who repairs them.

## What each step records

For every step: the command it sends, the context that owns it, its class, its compensation and the data captured for it, the semantic lock it sets or clears, and its timeout. The template holds these as columns.
