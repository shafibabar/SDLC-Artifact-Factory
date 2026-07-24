# Cross-Aggregate Coordination and Sagas

Self-contained — loadable without reading `SKILL.md` first.

This file is the full depth behind Rule 4 (Use Eventual Consistency Outside the Boundary): what actually has to be true for a Domain Event to safely carry a consequence from one Aggregate to another, and when that ordinary one-hop mechanism isn't enough because the business genuinely needs a multi-step, possibly-reversible process spanning several Aggregates. Grounded in Vaughn Vernon's `implementing-ddd-vernon.md` (reliability/idempotency requirements, the two publication mechanisms), Neal Ford et al.'s `software-architecture-hard-parts-ford.md` (the dynamic-coupling dimensions distributed-transaction patterns are built from), and this repo's own `event-driven-patterns`/`domain-event-catalog`/`go-event-publisher`/`go-event-consumer` skills, which this file cross-references rather than re-derives.

---

## Why Eventual Consistency Is the Correct Outcome, Not a Compromise

It is tempting to read Rule 4 as "we couldn't afford a real transaction, so we settled for eventual consistency instead." Vernon's own framing is the opposite of that: **everything correctly pushed outside an Aggregate's boundary is, by construction, exactly the set of things that never belonged inside it.** Rules 1–3 do the actual work — the three-question test (`references/invariants-and-consistency-boundaries.md`) identifies which rules are True Invariants that must hold at every instant, and only those earn a place inside a single transaction. Rule 4 doesn't loosen that guarantee; it names what happens to everything else, which by definition tolerates a brief window of staleness without causing real business harm. A design where every Aggregate is small and internally self-consistent, and cross-Aggregate effects propagate reliably but not instantly, is not a weaker design than one giant transactional cluster — it is the one Rules 1–3 were building toward the whole time.

Vernon's stated rule of thumb sharpens this into something a modeler can check per use case, not just per Aggregate: **a single use case (one Command, one client request) should modify exactly one Aggregate instance within its own transaction.** Anything else that logically needs to change as a consequence of that same use case is updated via eventual consistency — a separate transaction, a separate point in time, driven by the Domain Event the first transaction produced — not folded into the same atomic unit of work. This is a design goal to aim a use case *at* while it's being drafted, not merely a rule to check after the fact once a use case has already accreted multiple Aggregates. Counting how many distinct Aggregate instances a draft use case touches, and treating any count above one as requiring explicit justification (per the two named exceptions in `references/invariants-and-consistency-boundaries.md`), is the practical version of this rule of thumb.

Concretely: `StorageSourceDecommissioned` firing consequences in `DataAsset` (archiving its assets), in a notification service, and in an audit export is not three services awkwardly working around a missing distributed transaction — it is three Bounded Contexts each correctly reacting, on their own schedule, to a fact that already happened. The one thing Vernon is explicit a design must not skip: a business process that depends on a second Aggregate's eventual update should let the user-facing flow show a "pending"/"processing" state honestly, rather than silently assuming the second Aggregate is already updated the instant the first transaction commits. A compliance dashboard showing "Decommissioning in progress — 42 of 130 assets archived" is the correct UI answer to eventual consistency; a dashboard that renders as if the whole cascade already completed is lying to the reviewer about what's actually been enforced yet.

---

## Reliability Requirements for the Publishing Side

Eventual consistency is only as trustworthy as the mechanism that delivers the event. Vernon's requirement on the publishing side is explicit: delivery must be **at-least-once and durable** — the event must survive a crash occurring anywhere between the originating Aggregate's commit and the event actually reaching the consumer. A mechanism that can silently drop an event on a crash turns "eventually consistent" into "maybe never consistent," which is strictly worse than the synchronous coupling Rule 4 replaced.

This repo's implementation already satisfies this requirement, end to end, without gaps:

| Vernon's requirement | Satisfied by |
|---|---|
| Event persisted in the same local transaction as the Aggregate's state change | `go-repository-pattern`'s `Save` — the compare-and-swap `UPDATE` and the `INSERT INTO outbox` happen inside one `tx`; both commit or both roll back |
| A separate, subsequent mechanism reliably forwards the persisted event | `go-event-publisher`'s outbox relay — polls unpublished rows, publishes, marks published only after a successful produce |
| Crash-safety across the whole window | Publish-then-mark ordering (never the reverse): a crash after publish but before mark simply re-publishes on the next tick, which is safe because the consumer side is idempotent (next section) |

**Provenance worth stating explicitly, because neither implementing skill currently credits it:** this is functionally the Transactional Outbox pattern, described in Vernon's own *Implementing Domain-Driven Design* (Ch. 8, "Domain Events") years before that exact term was popularized — the name is most commonly attributed to Chris Richardson's later microservices.io pattern catalog, not to Vernon. Vernon's own treatment of the problem is direct: an Aggregate's state change and the publication of the Domain Event that resulted from it must not be allowed to succeed independently of each other — either both happen or neither does — and his proposed resolution is exactly persist-then-forward. `go-repository-pattern` and `go-event-publisher` arrived at Vernon's prescribed shape independently of any citation to him; this is a strong, faithful alignment, not a coincidence, and worth knowing the lineage of the next time either skill is revised.

---

## Idempotency Requirements for the Consuming Side

At-least-once delivery has a direct, unavoidable consequence on the other end: **the same event may be processed more than once**, so every consumer must be idempotent — processing an event twice must produce exactly the same effect as processing it once. This is not a defensive nicety for rare failure cases; it is a structural requirement of the delivery guarantee the publishing side just committed to.

This repo already implements Vernon's idempotency requirement correctly — `go-event-consumer`'s dedup pattern (`INSERT INTO processed_events (consumer_name, event_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, committed in the **same transaction** as the work it guards) is the concrete mechanism; this file does not re-derive it, only names the two properties that make it correct and worth checking on any new consumer:

- **The dedup check and the state change must be atomic with each other.** `go-event-consumer`'s own named anti-pattern — "Dedup in a separate transaction" — is exactly the failure mode this guards against: marking an event processed, then doing the work (or the reverse order) reopens the same dual-write race the Transactional Outbox exists to close on the publishing side. A crash between the two writes either loses the "already processed" record (re-processing on redelivery, silently double-applying a non-idempotent effect) or loses the work itself while the dedup record survives (permanently dropping a legitimate event). Idempotency is only as real as the transaction that enforces it — the same principle `references/invariants-and-consistency-boundaries.md` states about True Invariants generally.
- **A rebalance-induced redelivery is not an error condition to special-case.** `go-event-consumer`'s rebalance handling treats a mid-batch redelivery as routine — the dedup check makes it a no-op — rather than something the consumer needs bespoke recovery logic for. A consumer whose idempotency depends on careful, hand-rolled bookkeeping for "was this a rebalance redelivery or a genuine duplicate" has built a fragile special case where a durable, transactional dedup key already gives a general answer.

---

## In-Process vs. Durable Publication

Vernon draws a distinction this repo's Go skills don't currently name explicitly, and it matters for deciding when the full outbox-and-relay machinery is actually the right tool. He separates two publication mechanisms:

1. **A simple, synchronous, in-process publisher** for subscribers living in the same process as the Aggregate — invoked directly inside the Aggregate's own method or its immediate caller, with no durability machinery at all, useful when a same-process collaborator needs to react immediately (his own Java framing: a thread-local publish-subscribe registry).
2. **The durable, asynchronous mechanism** — the outbox-and-relay shape covered above — for subscribers outside the process, including subscribers in other Bounded Contexts.

**Given this repo's default architecture — a separate microservice per Bounded Context, communicating only via the broker — the in-process variant is largely moot for cross-service concerns**: any Domain Event a different Bounded Context needs to react to must go through the durable path, full stop, because there is no shared process to publish into synchronously. But the distinction remains directly relevant *within* a single service, for same-process, same-transaction-adjacent reactions that never need to leave the process — updating an in-memory cache, triggering a synchronous same-service side effect, or notifying an in-process observer that doesn't need its own durability guarantee. Neither `go-domain-model` nor `go-event-publisher` currently draws this line; both implicitly assume every Domain Event goes through the full outbox-and-relay path, even for effects that never leave the process. That assumption is *safe* — routing an in-process-only effect through the outbox anyway costs a little latency, never correctness — but it is not *required*, and a design that needs to shave that latency on a hot path has Vernon's own precedent for doing so deliberately.

**The line this distinction must never blur:** an in-process publish is still not a license to mutate a second Aggregate inside the first Aggregate's own transaction. The in-process mechanism is for effects that are not themselves a second Aggregate's state change requiring its own consistency boundary (a cache invalidation, a metric increment, an in-memory notification) — the moment the "same-process reaction" is actually another Aggregate's Repository being asked to `Save`, Rule 4's one-Aggregate-per-transaction discipline still applies in full, and the reaction belongs in its own separate transaction, triggered by (not folded into) the first.

---

## The Saga Pattern for Multi-Aggregate Business Processes

`event-driven-patterns` already owns the mechanics of Sagas in full — choreography-based vs. orchestration-based Sagas, the `saga_instances` persistence table, and the five non-negotiable compensation rules (reverse-order compensation, compensations that never fail permanently, the compensatable/pivot/retryable step classification, compensation-as-semantic-not-rollback, and compensation data captured on the way forward). This section does not re-derive any of that. What it adds is the piece specific to Aggregate design: **what a Saga step and its compensating action actually look like from inside the Aggregate boundary rules this skill teaches.**

**Every Saga step is itself an ordinary Rule-4-governed use case, not an exception to it.** A Saga is a sequence of local transactions, and "local transaction" means exactly what Rule 4 already means: one Aggregate instance, one transaction, invariants enforced, a Domain Event recorded and reliably published. If a candidate Saga step seems to need two Aggregates changed together atomically, that step has not correctly decomposed — it needs to split into two steps, each touching one Aggregate, exactly as an oversized ordinary use case would. A Saga does not grant permission to relax Rule 4; it is Rule 4 applied repeatedly, in a documented, orchestrated (or choreographed) order, with compensations attached.

**A compensating action must be a real, named Command against the target Aggregate's own root — never a bypass of it.** `event-driven-patterns` states this as "compensation is semantic, not rollback": `DisconnectStorageSource` doesn't make `StorageSourceConnected` un-happen, it's a new fact layered on top. The Aggregate-design-specific consequence worth making explicit: this means a compensating action is subject to the *same* Root-controls-mutations discipline as any other state change (`SKILL.md`'s "Root controls mutations" quality criterion, and its "Anemic Aggregate"/"Leaking internal collections" anti-patterns). A Saga orchestrator that reaches past an Aggregate's root to force a field back to its prior value — because "it's just a compensation, not a real business operation" — has broken the same encapsulation Rule-4-governed forward operations are held to. `StorageSource.Reactivate(reason, by, now)` is a legitimate compensating method precisely because it is a real, invariant-checking method on the root, exactly like `Connect` or `Decommission` — not a raw setter reached for because "this path is special."

**Compensation data is a Domain Event payload design question, not a separate concern.** `event-driven-patterns`' rule that "each step records in the Saga payload whatever its compensation will need" connects directly to `domain-event-catalog`'s payload-design guidance ("carry the fact and the fields consumers need to react," illustrated by `DataAssetClassified`'s own `previousLevel` field). A Domain Event that already carries the prior value as a matter of good event design (so a consumer doesn't have to guess what changed) is, for free, carrying exactly what a Saga's compensating step would need to undo that change correctly — this is one design discipline serving two purposes, not two unrelated requirements to satisfy separately.

**A worked, illustrative shape** (this repo's own domain, hypothetical — no such Saga is currently specified in this repo's artifacts): decommissioning a `StorageSource` while it still has `Restricted` `DataAsset`s attached.

| Step | Aggregate | Classification | Forward action | Compensating action |
|---|---|---|---|---|
| 1 | `DataAsset` (per affected asset) | Compensatable | `Archive(reason, now)` | `Unarchive(reason, now)` |
| 2 | `StorageSource` | **Pivot** | `Decommission(by, now)` | *(none past this point — the Saga can only move forward)* |
| 3 | Notification service | Retryable | `NotifyComplianceOfDecommission(...)` | *(always eventually succeeds; retried, never compensated)* |

Step 2 is the pivot: once a `StorageSource` is marked `Decommissioned`, the Saga has crossed its point of no return, and Step 3's job is only ever to eventually succeed, never to be undone. This mirrors `event-driven-patterns`' own classification rule exactly (compensatable steps precede the one pivot; retryable steps follow it) — the only thing this file adds is that each row in that table is, individually, an ordinary single-Aggregate Rule-4 transaction with its own True Invariant check, not a special multi-Aggregate atomic block.

---

## Decision Tree: Is This a Modeling Smell or a Genuine Business Process?

Work through this explicitly whenever a design seems to need coordination across two or more Aggregates — before reaching for Saga machinery (state table, compensations, an orchestrator) at all.

```
START: Does correctness genuinely require two or more Aggregates to reflect
       one business fact with zero tolerance for any staleness window —
       not "it would be nice if this were instant," but real business harm
       from a moment of visible inconsistency?
│
├─ YES → Re-run references/invariants-and-consistency-boundaries.md's
│         three-question test against the specific rule, in writing, before
│         concluding this needs multi-Aggregate machinery at all.
│         │
│         ├─ The rule fails the three-question test once actually written
│         │  down (the common outcome — staleness turns out to be tolerable,
│         │  or the "atomicity" was really just conceptual has-a ownership
│         │  mistaken for a transactional requirement, per Vernon's own
│         │  named root cause of oversized Aggregates) →
│         │  THIS IS A MODELING SMELL, not a Saga candidate. Either the two
│         │  concepts should never have been treated as separate Aggregates
│         │  (reconsider whether the boundary itself is wrong), or the
│         │  correct answer was ordinary Rule 4 eventual consistency all
│         │  along — no compensation, no orchestrator, just a Domain Event
│         │  and an idempotent consumer.
│         │
│         └─ The rule genuinely passes Yes/No/No even under honest scrutiny
│            (a true Exception-1-class invariant, per
│            references/invariants-and-consistency-boundaries.md — e.g. a
│            literal debit/credit pair) →
│            This is not a Saga either — it is evidence the Aggregate
│            boundary should be REDRAWN so both facts live inside one
│            consistency boundary, or (Exception 2's narrower cousin) that
│            references/sizing-contention-and-concurrency.md's SERIALIZABLE-
│            isolation branch is the correct tool. A Saga's whole premise is
│            tolerating an observable intermediate state; a rule with truly
│            zero tolerance for that state is, by definition, not a Saga
│            candidate.
│
└─ NO (some staleness is acceptable) →
    Is there a real, ordered, multi-step business process — one a domain
    expert would name and recognize as a single thing with its own identity
    ("Decommissioning a Storage Source," "Onboarding a Tenant") — where an
    intermediate step can fail AFTER prior steps have already committed,
    such that the business must decide what happens to that already-
    committed state?
    │
    ├─ NO (each Aggregate's reaction is independent; no step's failure
    │      creates a decision about undoing a prior, already-committed
    │      step) →
    │      Plain Rule 4 choreography suffices: publish the Domain Event(s),
    │      let each interested Bounded Context react independently and
    │      idempotently. No saga_instances table, no compensations, no
    │      orchestrator — that machinery would be pure overhead for a
    │      one-hop (or several independent one-hop) reaction.
    │
    └─ YES → This is a genuine Saga. Classify every step compensatable,
             pivot, or retryable (event-driven-patterns); choose
             choreography (≤3 participants, no central visibility need) or
             orchestration (4+ participants, or compensations complex
             enough that "where is this process right now?" needs one
             visible answer) per event-driven-patterns' own selection
             guide; and confirm every compensating action is a real, named,
             invariant-checking Command against its target Aggregate's own
             root — never a direct field write reached for because "it's
             just a compensation."
```

**The single fastest tell, in practice:** if the "coordination" you're designing would disappear entirely the moment you honestly answer `references/invariants-and-consistency-boundaries.md`'s three questions in writing against the specific rule — not the general area of the domain — it was never a Saga candidate. Sagas exist for processes that are genuinely, irreducibly multi-step in the business's own language; they are not a tool for patching over an Aggregate boundary that was drawn in the wrong place.
