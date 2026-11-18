# Choreography, Consistency and Choreographed Sagas

Reference for `event-driven-patterns`: coordinating a flow by events, the three decisions every flow needs, and the sagas that can stay choreographed. Orchestrated sagas (step classes, the pivot, compensation design, the state machine) are `workflow-orchestration`'s. Grounded in Ford (*The Hard Parts*, dynamic coupling and the saga archetypes), Richardson (choreography versus orchestration), Newman (smart endpoints, dumb pipes) and Kleppmann (eventual consistency, no two-phase commit).

## Event Choreography

Each service reacts to events others emit. No one holds the flow; every service encodes "what I do when I see event X".

- **Select when:** the flow is simple (2 or 3 services), the steps are natural independent reactions, no one needs a single view of progress, and no compensation spans services. It keeps coupling lowest: events are the public interface.
- **Orchestrate instead** when Richardson's rule fires (`event-driven-patterns` step 4).
- **Smart endpoints, dumb pipes** (Newman): all logic lives in producers and consumers, none in the broker or topics. No routing rules or business filters in the pipe.
- **Failure it introduces:** *choreography sprawl* (a six-service process nobody can trace; recovery means reading six services' logs) and *circular event chains* (A reacts to B's event with an event B reacts to). Draw the full event-flow graph in Design; break every cycle with a terminating condition, or merge the cycle into one saga.

## The three decisions (Ford)

A flow is classified on three independent axes; "sync or async" and "choreography or orchestration" each hide one of them.

1. **Communication:** synchronous or asynchronous. Does the caller wait for a reply?
2. **Consistency:** atomic or eventual. Must all effects commit together, or may they converge?
3. **Coordination:** orchestrated or choreographed. Is there a conductor?

Three binary axes give eight combinations, named in *The Hard Parts*:

| Archetype | Communication | Consistency | Coordination | Verdict |
|---|---|---|---|---|
| Epic Saga | sync | atomic | orchestrated | A distributed monolith: simple to reason about, highly coupled |
| Phone Tag Saga | sync | atomic | choreographed | Brittle: every service must know the next |
| Fairy Tale Saga | sync | eventual | orchestrated | Moderate coupling, tolerable |
| Time Travel Saga | sync | eventual | choreographed | Workable, hard to trace |
| Fantasy Fiction Saga | async | atomic | orchestrated | Atomicity over async is awkward |
| Horror Story | async | atomic | choreographed | **Avoid.** No coordinator and an assumed all-or-nothing |
| Parallel Saga | async | eventual | orchestrated | A sound default for complex multi-step processes |
| Anthology Saga | async | eventual | choreographed | The most decoupled; for genuinely independent reactions |

**In artifacts,** write the three axes ("async · eventual · orchestrated"); add the archetype name only as a parenthetical, if at all. The names are memory aids, not vocabulary a product owner shares.

**The Horror Story fix** is either to accept eventual consistency explicitly (and design the consumers to tolerate in-between states), or to move the flow to an orchestrated, eventual shape (`workflow-orchestration`).

## Eventual Consistency: when it is acceptable

Eventual consistency is Kleppmann's weak guarantee: if writes stop, replicas converge, with no promise about timing or order. Every asynchronous flow accepts it, so state it per flow.

- **Acceptable** when the in-between state is a tolerable, visible fact: a record "classified" seconds after it is "ingested", a dashboard lagging the write side. Consumers must tolerate seeing work that is in flight or was later compensated.
- **A synchronous call is required** when the caller cannot proceed without a current answer (an authorization check gating a request) or a rule must hold *now* (a uniqueness constraint, a linearizability need). These are the deliberate exceptions; everything else defaults to events.
- **Causal order.** `causationid` and `correlationid` in the envelope record what happened before what; they are tracing metadata. Order across different Aggregates is not guaranteed even with them (`./ordering-and-partitioning.md`). A flow that truly needs it names that as a design constraint.

## No distributed transactions

Two-phase commit across services is a blocking protocol: a coordinator crash after the "yes" votes strands participants holding locks, and availability collapses (Kleppmann). Atomicity is local (the Transactional Outbox: one transaction, one node); cross-service effects propagate as an idempotently retriable event stream. A saga's compensations replace the cross-service rollback two-phase commit would have given.

## Choreographed sagas

A saga is a sequence of local transactions across services; if a step fails, compensating transactions undo the completed ones. Richardson: it gives atomicity by compensation, consistency and durability, and gives up isolation.

**A choreographed saga is for 2 or 3 steps** that are genuinely independent. Each participant knows its own compensation and reacts to the previous step's event, and a failure is itself an event:

```
Step 1  ConnectSource        → emits SourceConnected
Step 2  CreateConsumerGroup  → emits GroupCreated   (or GroupCreationFailed → step 1 compensates)
Step 3  TriggerInitialScan   → emits ScanStarted    (or ScanFailed → steps 1 and 2 compensate)
```

Rules for the compensation, even choreographed:
1. **Compensation is semantic, not rollback.** Disconnecting a source does not un-happen "connected"; both facts stay in history. A consumer that saw the first event must tolerate the corrective one.
2. **Capture what the compensation needs on the way forward.** A compensation that looks up current state to know what to undo races concurrent changes.
3. **A compensation must always eventually succeed:** idempotent, retried, and escalated (dead letter, alert) if it cannot.
4. **Undo in reverse order.**

**Beyond that, hand it over.** A saga with 4 or more steps, branching, a long wait, a need for a progress view, or compensation spanning 4 or more services is orchestrated: the step classes (compensatable, pivot, retriable), where the pivot sits, the state machine and its persistence are in `workflow-orchestration`. A saga with two pivots is two sagas.
