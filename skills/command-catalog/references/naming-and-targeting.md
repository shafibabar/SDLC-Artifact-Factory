# Naming Commands and Choosing Their Aggregate

The detail behind `SKILL.md` § 1–2: where Commands come from, how to name one, when to split, how to find the one Aggregate it targets, and what to do with bulk actions. Grounded in Evans (*Domain-Driven Design*, Ch. 10), Vernon (*Implementing Domain-Driven Design*, Ch. 10), Brandolini (*Introducing EventStorming*) and Geewax (*API Design Patterns*), as summarised in `research/domain-driven-design/domain-driven-design-evans.md`, `research/domain-driven-design/implementing-ddd-vernon.md`, `research/domain-driven-design/introducing-eventstorming-brandolini.md` and `research/software-architecture/api-design-patterns-geewax.md`.

## 1. Where Commands come from

| Source | What it gives | Check |
|---|---|---|
| Event Storming Process Modelling or Software Design | Blue stickies between an actor (or Policy) and an event | Brandolini's chain: read model → actor → Command → system → event → policy, and every path reaches a stable end. A break is a question, not a gap to fill silently |
| `aggregates.md` Commands-and-events tables | Each Command with its guard, guarantee and event | Every Command there appears in the catalog, and the reverse |
| `domain-event-catalog` consumers | "Whenever `PaymentOverdue`, then `SendReminder`" | The Command after "then" belongs to the reacting context's catalog, issued by that Policy |
| User stories | "As a host, I want to cancel a booking…" | The story's verb is a candidate; the language decides the name |

**Agent-run:** record each Command's source (the artifact it came from, or *assumed*). Brandolini's reason: provenance is lost in transcription otherwise, and an assumed Command looks just as real as one the domain expert named.

## 2. Naming

- **`[DomainVerb][What]`, imperative, PascalCase:** `ConfirmBooking`, `WaiveLateFee`, `ReassignCourier`. The verb is the one the domain expert uses in the context's Ubiquitous Language.
- **The test:** could a domain expert say what happens, who may do it and what can stop it, from the name alone? `UpdateBooking` fails; `MoveBookingToAnotherTable` passes.

| Poor | Why | Better |
|---|---|---|
| `UpdateOrder` with `status` | Each status value is a different intent with different rules | `ConfirmOrder`, `CancelOrder`, `MarkOrderReady` |
| `UpdateMember` with optional fields | A bag of intents; nobody can state the guard | `ChangeMemberEmail`, `UpgradeMembership`, `SuspendMember` |
| `CreateLoan` | Database verb | `IssueLoan` |
| `DeleteListing` | Is it withdrawn by the owner, or removed for breaking rules? | `WithdrawListing`, `RemoveListingForAbuse` |
| `ProcessRefund` | Technical verb; which decision? | `ApproveRefund`, `RejectRefund` |
| `GetInvoice` | A query, not a Command | read from a Read Model |
| `CancelOrderCommand`, `CancelOrderV2` | Suffixes say nothing about the intent | `CancelOrder`; a changed intent is a new name |

**Splitting a CRUD-shaped request.** Ask "what is the user trying to do when they change this field?" for each field or status value. Values that share an actor, a rule and an event can be one Command; values that differ in any of those are separate Commands. Fields that always change together for one reason (a delivery date and slot) stay in one Command.

## 3. One Command, one Aggregate

Vernon's rule of thumb: a single use case should modify **one Aggregate instance in one transaction**, and that is a goal to aim the design at, not a check after the fact. A Command that seems to need two Aggregates means one of:

1. **They share a True Invariant** and should be one Aggregate: re-run `aggregate-design`'s three-question test.
2. **The second change is a consequence** that can wait: the first Aggregate records an event, and a Policy issues a Command to the second.
3. **It is a named multi-step process** whose later step can fail after earlier ones committed: a Saga (`aggregate-design` § 5), each step its own Command.

**Finding the target:**
1. Which state does the Command change, and who owns that state? That owner is the target, even when the rule mentions another Aggregate.
2. *Has-a* in the language ("a venue has tables") is not *must be atomic with*. Linguistic ownership does not make a transaction.
3. The caller must be able to name the target by identity from what it already has. If it can't, the boundary is wrong, not the Command.
4. The Command maps to one behaviour of the target, named in the language. If no single behaviour fits, revisit the boundary.

A Command that **creates** an Aggregate (`OpenAccount`) targets the new instance; its identity is supplied by the caller or assigned on success, and uniqueness ("one open account per customer") is a rule to state like any other.

## 4. Bulk actions: the command-storm trap

A client loop that issues 50 `ReassignCourier` Commands for "reassign all of a sick courier's deliveries":
- has no atomicity: the 30th fails, 29 are committed, and nothing records the intent;
- has no invariant across the 50; the batch is a UI convenience, not a domain rule;
- multiplies round trips and failure windows.

**Instead:** one Command (`ReassignCourierDeliveries`) starts a tracked process. The process records the targets and the intent, issues the single-Aggregate Commands, retries failures, and reports done or partly failed to the requester. Each single Command stays simple. The process itself is catalogued as a Command on its own Aggregate (the process record).

## 5. From Commands to the API

Commands are the upstream source the API's operations draw their names from (Geewax). `api-contract-design` decides whether each one is a standard method on a resource (a state change that maps onto a field) or a custom method named with the Command's verb (`:cancel`), and its status codes. The catalog does not choose HTTP methods or paths. It gives the API skill what it needs to decide: the intent, the target, who may call it, the rejections by kind, the idempotency key, and whether the caller needs the outcome now.
