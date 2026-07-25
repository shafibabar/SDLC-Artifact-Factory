# Three-Tier Validation Boundary — Precise Division and a Worked Orchestration Check

Full worked material referenced from `SKILL.md`'s "Three-Tier Validation Boundary"
section. Self-contained — reads without the parent body already in context. Covers:
why a Command's validation needs three tiers, not two, precisely restating what
`go-chi-handler` and `go-domain-model` each already own, and a full worked example of
this layer's own narrow slice — an orchestration-level check neither of the other two
tiers can perform.

---

## 1. Why Two Tiers Is Not Enough

`command-catalog` (design phase) already names two validation layers: Layer 1,
Structural — "checks that the Command payload is well-formed... this is the API
handler's responsibility... these checks never touch the database" — and Layer 2,
Business Rule — "checks invariants that require domain state — enforced by the
Aggregate Root." Read literally, those two definitions leave a gap: a check that
*does* require the database (so it cannot be Layer 1) but is *not* an invariant of the
Aggregate this Command targets (so it does not belong inside that Aggregate's method
either) has no named home. That gap is real, not theoretical — "does the user this
Command names as the new owner actually exist" needs a lookup, and `DataAsset` has no
business rule to enforce about `User` rows; asking `DataAsset.AssignOwner` to reach
into a `users` table to check would make the Aggregate impure (`go-domain-model`'s
Purity Rule: domain imports only stdlib, `uuid`, `time` — no repository, no I/O of any
kind). This skill names that gap explicitly as this layer's own tier, sitting between
the other two.

---

## 2. The Three Tiers, Precisely

| Tier | Owner | What it checks | Can it touch I/O? | When it runs | Example |
|---|---|---|---|---|---|
| 1 — Structural | `go-chi-handler` | Shape only: types, required fields, formats, enum membership, ranges — answerable from the request bytes alone | Never | Before the Command reaches the application layer; all violations returned in one pass | `SensitivityLevel` string is not one of the four valid values → 400 with every such violation in one response |
| 2 — Orchestration | `go-service-layer` (this skill) | Does this specific use-case invocation make sense to attempt at all — an ID the Command references actually exists, the primary Aggregate itself is found, a cross-Aggregate reference resolves | Yes — a narrow read (existence check, `FindByID`) is expected; never a write | After structural validation passes, before the domain call; short-circuits without invoking the Aggregate's mutating method | The `OwnerUserID` an `AssignDataAssetOwner` Command names does not correspond to any real user |
| 3 — Business invariant | `go-domain-model` | Rules about the *target* Aggregate's own current state | No — the Aggregate is pure; any state it needs was already loaded and passed in | Inside the Aggregate's mutating method, validate-before-mutate | `DataAsset.Classify` rejects a sensitivity downgrade because the Aggregate's own current `sensitivity` field says so |

**The distinguishing question between Tier 2 and Tier 3 is not "does this need the
database" — both can — it is "whose state is being examined."** Tier 2 checks facts
about *other* things a Command merely references (does this foreign id resolve, does
the primary Aggregate exist at all). Tier 3 checks facts about the *one* Aggregate the
Command targets, using state that Aggregate itself already holds once loaded. A repo
call to check *this Command's own target Aggregate's current field values* is not
Tier 2 — the load in Command Handler Standard's step 2 (`repo.FindByID`) already
brought that state into memory precisely so the domain method in step 4 can examine it
without any I/O of its own.

---

## 3. Worked Example: An Orchestration-Level Check

`AssignDataAssetOwner` carries an `OwnerUserID` referencing a `User` — a different
Aggregate, owned by a different Bounded Context. Neither Tier 1 nor Tier 3 can verify
it resolves to a real row: Tier 1 only has the request bytes (a syntactically valid
UUID is not the same claim as "this user exists"), and `DataAsset` has no business
rule about `User` existence to enforce — asking it to would require the Aggregate to
import a repository, violating its Purity Rule. This check belongs here, in the
command handler, using a narrow, consumer-defined existence port — not the full
`UserRepository`, just the one method this use case actually needs:

```go
// internal/domain/ports.go
type UserExistenceChecker interface {
    Exists(ctx context.Context, id uuid.UUID) (bool, error)
}

// internal/application/commands/assign_data_asset_owner.go
func (h *AssignDataAssetOwnerHandler) Handle(ctx context.Context, cmd AssignDataAssetOwner) (res Result, err error) {
    tx, err := h.pool.Begin(ctx)
    if err != nil {
        return Result{}, fmt.Errorf("begin tx: %w", err)
    }
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    // idempotency insert-or-replay omitted here — identical shape to
    // references/command-handler-transaction-and-idempotency.md §2-3

    repo := h.assets.WithTx(tx)
    asset, err := repo.FindByID(ctx, cmd.DataAssetID) // Tier 2: does the primary Aggregate exist
    if err != nil {
        return Result{}, err
    }

    // Tier 2: does the referenced foreign id resolve — NOT a DataAsset invariant,
    // NOT answerable from the request bytes alone.
    exists, err := h.users.Exists(ctx, cmd.OwnerUserID)
    if err != nil {
        return Result{}, fmt.Errorf("checking owner existence: %w", err)
    }
    if !exists {
        return Result{}, fmt.Errorf("owner %s: %w", cmd.OwnerUserID, ErrReferencedEntityNotFound)
    }

    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return Result{}, ErrUnauthenticated
    }
    resource := domain.Resource{Type: "data-asset", ID: asset.ID(), TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, resource, domain.ActionAssignOwner); err != nil {
        return Result{}, err
    }

    // Tier 3: AssignOwner is free to trust cmd.OwnerUserID now — existence was
    // already settled at Tier 2. The Aggregate's own job is its own invariants only
    // (e.g. "cannot assign an owner to an archived asset") — never re-checking a
    // fact about a different Aggregate it has no way to look up anyway.
    if err := asset.AssignOwner(cmd.OwnerUserID, h.clock()); err != nil {
        return Result{}, err
    }
    if err := repo.Save(ctx, asset); err != nil {
        return Result{}, err
    }
    return res, tx.Commit(ctx)
}
```

`ErrReferencedEntityNotFound` is a sentinel (parameter-free — the diagnostic value,
`cmd.OwnerUserID`, is already carried by the wrapping `%w` error text, per
`go-domain-model`'s Invariant-Violation Error Standard applied here at the
application-layer's own error taxonomy, not inside the domain package itself). It maps
to `404`/`422` at the transport edge through the same single `writeDomainError` switch
`go-chi-handler` already owns — this tier does not invent a second error-mapping path.

---

## 4. What Tier 2 Is Not

Tier 2 is not a place to re-implement Tier 1 (re-checking that `OwnerUserID` is a
syntactically valid UUID — already guaranteed true by the time a Command reaches this
layer) or to smuggle in a Tier 3 check the Aggregate should own instead (checking
`asset`'s own current owner field before calling `AssignOwner` — that is exactly the
kind of target-Aggregate-state rule that belongs inside the Aggregate's method, not in
front of it). A command handler whose orchestration checks have quietly grown into
re-deriving business rules about the *target* Aggregate — rather than merely
confirming referenced *other* entities exist — has drifted into `go-service-layer`'s
own named anti-pattern: "the 'service' that is really the domain."
