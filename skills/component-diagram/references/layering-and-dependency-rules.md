# Layering and Dependency Rules

Self-contained reference for the Clean Architecture constraints a C4 Level 3
Component diagram must encode in this repo. Read together with
`c4-component-notation.md` (how the arrows are drawn) and `diagram-template.md`
(a fully worked example). Grounded in Robert C. Martin, *Clean Architecture*
(the Dependency Rule and the four rings), with the Go mapping specific to this
repo's stack (Go + chi + pgx + Redpanda, per-tenant physical isolation).

---

## 1. The Dependency Rule (the actual architecture)

Clean Architecture's central, load-bearing invariant:

> **Source-code dependencies must point only inward, toward higher-level
> policy. Nothing in an inner circle may know anything — not a name, not a
> signature, not a data format — about anything in an outer circle.**

The layers are folders; *this rule* is the architecture. Four Go directories in
the same order but with `domain/` importing `pgx` is not layered architecture —
it is cosmetic folders. What makes it real is that the arrows only ever point
inward, verified mechanically (Section 6).

### The Dependency Rule is NOT the Dependency Inversion Principle

These are constantly conflated; keep them distinct:

| | Dependency Rule | Dependency Inversion Principle (DIP) |
|---|---|---|
| Scope | Architecture-wide invariant governing *every* ring crossing | A class/interface-level SOLID technique used *at one* crossing |
| Statement | "All source dependencies point inward" | "Depend on an abstraction, not a concrete type" |
| What it governs | Direction of every import; data formats never leaking outward-to-inward; naming | One specific inward-facing seam where an outer detail must be called by inner policy |
| Relationship | The broad rule | *One mechanism* the rule uses when policy must reach a detail |

DIP is *how* you make an inward arrow possible when control must flow outward at
runtime (domain policy needs to persist an Aggregate, which physically lives in
a database). The Dependency Rule is the *whole invariant* — it also governs
crossings DIP never touches (e.g., a Domain Event struct must not carry a
`pgx.Rows` field; a data format must not leak inward). Saying "the dependency
direction rule is DIP applied at the architectural level" is imprecise: DIP is
one tool of the Rule, not a synonym for it.

---

## 2. Clean Architecture's four rings, mapped to this repo's Go layers

| Ring (Clean Architecture) | Holds | This repo's Go layer |
|---|---|---|
| **Entities** (innermost) | Enterprise-wide business rules; least likely to change | `domain/` — Aggregates, Value Objects, Domain Events, port interfaces |
| **Use Cases** | Application-specific rules; orchestrate Entities to fulfil a use case | `application/` — command handlers, query handlers |
| **Interface Adapters** | Convert between the format convenient for use cases and the format convenient for an external agency | `handlers/` (web→command) and `infrastructure/` (domain↔db/broker translation) |
| **Frameworks & Drivers** (outermost) | The actual web framework, database driver, glue | `chi`, `pgx`, the Redpanda client — depended upon *from* `handlers/`/`infrastructure/` |

Two deliberate simplifications in this repo, both reasonable per Uncle Bob's own
notes, not defects:

- **Interface Adapters and Frameworks & Drivers are merged.** `infrastructure/`
  contains both the translation logic (Reconstitute mapping, pgx-error → domain
  sentinel translation) *and* the raw `pgx` calls in the same package. Splitting
  them into two rings is only worth it with a concrete driver — e.g. swapping
  the database engine while keeping the adapter logic — which this repo does not
  have. Do not propose the split without one.
- **A word-collision to watch.** Clean Architecture's "Entities" ring is a
  *broader* concept than DDD's "Entity" (an object with identity inside an
  Aggregate). This repo names its innermost layer **`domain/`**, not
  `entities/`, precisely to avoid the collision. Never rename it "Entities."

### Screaming Architecture — why the generic skeleton is fine

Every service uses the same `cmd/` + `internal/{domain,application,infrastructure,handlers}`
skeleton regardless of business domain. That is *not* a Screaming Architecture
violation: the business domain screams one ring up, at the service/Bounded-Context
name chosen in the Container diagram (`dataasset-management-service/`,
`compliance-service/`, `reporting-service/`), and inside `domain/` the file
names scream the concept (`dataasset.go`, `sensitivity.go`, `classification.go`).
The generic per-service tree is intentional and correct.

---

## 3. The interface-ownership mechanism (who owns the port)

The inward arrow from `infrastructure/` to `domain/` is only possible because
**the interface is owned by the inner layer**. The port is *declared* in
`domain/` and *implemented* in `infrastructure/`:

```go
// domain/ports.go  — the INNER layer owns the abstraction
package domain

type DataAssetRepository interface {
    FindByID(ctx context.Context, id DataAssetID) (*DataAsset, error)
    Save(ctx context.Context, a *DataAsset) error
}

type EventPublisher interface {
    Publish(ctx context.Context, events []DomainEvent) error
}
```

```go
// infrastructure/postgres/dataasset_repository.go — the OUTER layer conforms
package postgres

import (
    "github.com/jackc/pgx/v5/pgxpool"
    "dataasset-management/internal/domain" // outer imports inner — legal
)

type DataAssetRepository struct { pool *pgxpool.Pool }

// compile-time proof the outer type satisfies the inner interface
var _ domain.DataAssetRepository = (*DataAssetRepository)(nil)
```

Note the import direction: `infrastructure/postgres` imports `domain`; `domain`
imports neither `pgx` nor `infrastructure`. The `var _ domain.X = (*Y)(nil)`
line is a compile-time assertion that the Humble Object satisfies the port. The
repository is a **Humble Object**: thin, logic-free, and verified by
integration tests against a real database — while the Aggregate it loads/saves
is unit-tested in complete isolation because nothing in `domain/` touches I/O.

---

## 4. The forbidden dependencies

Two arrows, if you can draw them, prove the layering has collapsed:

1. **`domain/` importing a framework** — `domain` importing `pgx`, `chi`,
   `net/http`, or the Redpanda client. The domain must depend on the standard
   library only. The moment it imports a driver, it can no longer be unit-tested
   in isolation and the innermost ring knows about the outermost — a direct
   Dependency Rule violation.
2. **A handler importing `pgx` directly** (layer skipping) — a `handlers/` file
   calling the database "because it's just a read." This bypasses the
   Application layer's idempotency check, authorization, and orchestration, and
   inverts nothing. Even a trivial read goes through a query handler.

Both are the same class of defect: an arrow that points *outward* or *skips a
ring*.

---

## 5. A worked violation-and-fix

**The violation.** A `dataasset-management` service ships with a compliance
lookup done directly in the domain:

```go
// domain/dataasset.go  — VIOLATION: domain imports pgx and runs SQL
package domain

import "github.com/jackc/pgx/v5/pgxpool"

type DataAsset struct {
    ID          DataAssetID
    Sensitivity Sensitivity
    pool        *pgxpool.Pool // domain now holds a DB handle
}

func (a *DataAsset) Reclassify(ctx context.Context, s Sensitivity) error {
    // domain reaching into the database to check a policy row
    row := a.pool.QueryRow(ctx, "SELECT locked FROM policies WHERE tenant=$1", a.tenant)
    var locked bool
    _ = row.Scan(&locked)
    if locked { return ErrClassificationLocked }
    a.Sensitivity = s
    return nil
}
```

Why it fails: `domain/` imports `pgx` (forbidden dependency #1); the Aggregate
can no longer be unit-tested without a live PostgreSQL; the invariant ("cannot
reclassify a locked asset") is entangled with an infrastructure call.

**The fix.** Move the *decision data* into the Aggregate and the *fetching* out
to the Application/Infrastructure layers, using a domain-owned port:

```go
// domain/dataasset.go — pure: no imports beyond stdlib
package domain

type DataAsset struct {
    ID          DataAssetID
    Sensitivity Sensitivity
    Locked      bool // state the invariant needs, held on the Aggregate
}

func (a *DataAsset) Reclassify(s Sensitivity) error {
    if a.Locked {
        return ErrClassificationLocked // invariant lives on the Aggregate
    }
    a.Sensitivity = s
    return nil
}
```

```go
// application/reclassify_dataasset.go — orchestration only
func (h *ReclassifyHandler) Handle(ctx context.Context, c ReclassifyCommand) error {
    a, err := h.repo.FindByID(ctx, c.ID) // repo loads Locked from the row
    if err != nil { return err }
    if err := a.Reclassify(c.NewSensitivity); err != nil { return err }
    return h.repo.Save(ctx, a) // Save enqueues the outbox event
}
```

Now the arrows all point inward: `application` → `domain`, `infrastructure`
(the repo) → `domain` (implements the port). The domain imports nothing. The
invariant is unit-testable with a plain struct.

---

## 6. The fitness function (enforce it, don't just draw it)

A dependency rule stated only in prose drifts the moment someone adds an import.
Per Richards & Ford, a **fitness function** is an automated, continuously-run
check that objectively verifies an architecture characteristic still holds — a
governance test, not a one-time review. The Dependency Rule's fitness function
in this repo is an import check wired into the build:

- `go-makefile`'s **`arch`** target runs **`scripts/check-imports.sh`**, which
  fails the build if any file under `internal/domain/` imports a package outside
  the standard library (no `pgx`, no `chi`, no Redpanda client, no
  `infrastructure`/`handlers`).
- A pure-Go alternative is a test using `go/parser` (or an ArchUnit-style
  library) asserting the `domain` package's import set is a subset of the
  standard library.

The Level 3 diagram's Output Format should name this fitness function explicitly
as a deliverable alongside the picture — the mechanism to keep the inward-only
arrows true after the diagram is approved. Drawing the rule and enforcing the
rule are two separate artifacts; the diagram without the check is a wish.

---

## 7. Checklist for the enterprise-architect

- [ ] `domain/` imports the standard library only — no framework, no sibling layer.
- [ ] Every port interface (`Repository`, `EventPublisher`) is declared in `domain/`.
- [ ] `infrastructure/` implements ports; a `var _ domain.X = (*Y)(nil)` proves it.
- [ ] No handler imports `pgx`/the DB directly — every read goes via a query handler.
- [ ] Invariants live on the Aggregate, not in application handlers (no anemic domain).
- [ ] A named fitness function (`check-imports.sh` / `arch` target) enforces the rule in CI.
- [ ] The diagram's arrows all point inward; no cycles.
