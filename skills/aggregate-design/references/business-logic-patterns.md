# Business-Logic Patterns and Event Sourcing

The detail behind `SKILL.md` § 1 and § 6: which of Khononov's four business-logic patterns a use case needs, and when an Aggregate should go further to event sourcing. Grounded in Khononov (*Learning Domain-Driven Design*, Ch. 5–7) as summarised in `research/domain-driven-design/learning-ddd-khononov.md`. Stack-neutral (D047-10): how each pattern is coded is `go-domain-model` (`./references/aggregate-implementation-patterns.md` there) and `go-repository-pattern`.

## The four patterns

| Pattern | Shape | Fits (Khononov) | Never pays for |
|---|---|---|---|
| **Transaction Script** | One procedure per use case, straight against storage. No object model. | Generic subdomains (a bought or adopted capability with a thin wrapper); the simplest Supporting use cases: a few sequential steps, no rule across records. | Entities, Value Objects, invariant methods |
| **Active Record** | One object per stored row, data plus simple behaviour; the object mirrors the table. | Supporting use cases with moderate, mostly single-record logic: validation, a status change on one row. | Isolation from the schema; cross-object invariants |
| **Domain Model** | Aggregates, Entities, Value Objects; the root enforces invariants; isolated from storage. | A rule that spans several objects and must hold at every instant (a True Invariant). Usually Core. | — |
| **Event-Sourced Domain Model** | A Domain Model whose state is derived by replaying its own events instead of read from a current-state row. | A Domain Model that also has one of the three needs below. | — |

Pick **per Aggregate or per use case**, never once per Bounded Context. A Core context routinely holds use cases too simple for a Domain Model, and a Supporting context can hold one Aggregate that earns it.

## Choosing: the decision path

```
1. Is there a rule this use case must enforce across more than one record, atomically?
   ├─ No  → 2.
   └─ Yes → run the three-question test (./invariants-and-boundaries.md § 1) on that exact rule.
            ├─ Fails → it is not a True Invariant; go to 2 as if the answer were No.
            └─ Passes → DOMAIN MODEL. Then 3.
2. Is there single-record behaviour beyond plain create/read/update/delete
   (validation, a status rule on one row)?
   ├─ No  → TRANSACTION SCRIPT.
   └─ Yes → ACTIVE RECORD. (A single-record rule such as "a plot has one tenant" is a
            uniqueness constraint on that record, not a reason for a Domain Model.)
3. Event sourcing: does the Aggregate have at least one of the three needs below?
   ├─ No  → current-state persistence. Record "not used" and which needs were checked.
   └─ Yes → EVENT-SOURCED DOMAIN MODEL. Record which need, and accept the costs.
```

Use the subdomain classification as a check on the result, not as the input: `subdomain-distillation`'s Modelling column gives the expected pattern per subdomain. A Generic subdomain that comes out as Domain Model, or a Core context where *every* use case comes out as Domain Model, is a reason to recheck either the classification or the invariant test.

## Event sourcing: the three needs

Adopt it only when at least one of these is true **for this Aggregate** (Khononov):

1. **Temporal query.** The business must rehydrate what the Aggregate looked like at an arbitrary past moment ("its status as of the last audit date"), not just "we log changes".
2. **Retroactive projection.** New Read Models will need to be built later from history that happened before they were designed, and a current-state row would already have overwritten it.
3. **Audit-as-record.** The event stream itself, not a log maintained beside a current-state row, must be the authoritative record a regulator or auditor is shown. A separate log can drift from the row the first time one code path updates one and not the other.

**Not a fourth need:** "the subdomain is Core and deserves the best patterns". That is premature event sourcing, Khononov's named failure mode. "We need an audit trail" is also not enough on its own: current-state persistence plus the Domain Events it already publishes, kept in an audit store, satisfies most audit needs. Ask whether the stream *must be* the record (need 3) or only whether a history must *exist*.

**The costs, stated in the design when it is adopted:**
- an upcasting chain kept forever for every stored event type, because a stored event can never be deleted or rewritten (unlike an integration event, which can run two versions on the wire until consumers move);
- a snapshot cadence to bound replay time;
- tests built from event sequences rather than one constructor call;
- more for the team to understand.

**What changes and what doesn't.** Event sourcing is a persistence choice for one Aggregate, not a different model. Its commands, invariants and Domain Events are designed exactly as for a current-state Aggregate. Four rules carry over into the design document:
- state changes only by applying events; replay and the command path use the same apply step;
- optimistic concurrency becomes a conditional append on the expected stream version (the same principle as a version check on a row);
- a snapshot is never authoritative and can always be regenerated from the stream;
- **internal events are not the published contract.** The stream's events are as fine-grained as the Aggregate's own state needs. Other Bounded Contexts get coarser, business-meaningful events through a deliberate translation step; some internal events are never published. Publishing the whole stream couples consumers to how this Aggregate stores itself. Record, per Command, whether its event is published as-is, translated or internal only.
