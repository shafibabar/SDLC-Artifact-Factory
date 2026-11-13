# Layering and Dependency Rules

Reference for `component-diagram`. Self-contained: the constraint every arrow of a Level 3 diagram must obey, the rings and how they map to the default stack, who owns each interface, the forbidden dependencies, a violation and its fix, and the fitness function that keeps the rule true. Grounded in Martin, *Clean Architecture* (`research/software-architecture/clean-architecture-martin.md`). The code that realises these rules belongs to backend-engineer's skills (`go-project-structure`, `go-service-layer`, `go-repository-pattern`) for the default stack, or the overriding stack's equivalents in `sdlc-config.json`.

## 1. The Dependency Rule

> **Source-code dependencies point only inward, toward higher-level policy. Nothing in an inner ring knows anything about an outer one: not a name, a signature or a data format.**

The layers are folders; this rule is the architecture. Four folders in the right order with the domain importing a database driver is not a layered architecture.

### The Dependency Rule is not the Dependency Inversion Principle

| | Dependency Rule | Dependency Inversion Principle |
|---|---|---|
| Scope | Every ring crossing in the system | One crossing where inner policy must reach an outer detail |
| Statement | All source dependencies point inward | Depend on an abstraction, not a concrete type |
| Also governs | Data formats never leaking inward; naming | — |
| Relationship | The invariant | One mechanism the invariant uses |

Dependency Inversion is how an inward arrow is possible when control flows outward at runtime: the domain needs an Aggregate saved, which physically happens in a database. The Rule also covers crossings DIP never touches, such as a Domain Event that must not carry a database row type.

## 2. The Rings and the Default Stack

| Ring (Clean Architecture) | Holds | Role in the diagram | Default stack (Go) |
|---|---|---|---|
| Entities (innermost) | Business rules least likely to change | Domain | `domain/`: Aggregates, Value Objects, Domain Events, port interfaces |
| Use Cases | Application rules orchestrating entities | Use cases | `application/`: command and query handlers |
| Interface Adapters | Convert between use-case formats and external formats | Entry points and adapters | `handlers/` (web or consumer to command) and `infrastructure/` (domain to database or broker) |
| Frameworks and Drivers (outermost) | The web framework, database driver, broker client | Outside the components; used from adapters | `chi`, `pgx`, the Redpanda client |

Two simplifications the default stack makes deliberately (and Martin allows):
- **Interface Adapters and Frameworks and Drivers share a package** per external system. Splitting them is worth it only with a concrete reason, such as swapping the database engine while keeping the mapping.
- **"Entities" vs DDD's Entity.** The ring is broader than a DDD Entity; the default stack calls the innermost layer `domain`, never `entities`, to avoid the collision.

**Screaming architecture.** The same per-service skeleton is fine: the business domain shows one level up, in the service and Bounded Context names on the container diagram, and inside the domain in its concept names.

## 3. Who Owns the Interface

The inward arrow from an adapter to the domain exists because **the inner ring owns the interface**:
- The **domain declares** each port it needs: a repository for each Aggregate, an event publisher, a read-model writer, a client for an external capability, named in the domain's language.
- The **adapter implements** it, importing the domain; the domain imports neither the adapter nor its driver.
- The build proves the adapter satisfies the port (in the default stack, a compile-time assertion; `go-repository-pattern`).
- The adapter is a **humble object**: thin, logic-free, tested against the real database or system; the Aggregate it loads is tested alone, because nothing in the domain touches I/O.

On the diagram, these are the **implements** arrows from each adapter to the domain.

## 4. Forbidden Dependencies

1. **The domain importing a framework or driver**: the database driver, the HTTP router, the broker client. The innermost ring now knows the outermost, and the domain can't be tested without them.
2. **An entry point reaching the database directly** ("it's just a read"): it skips the use-case layer's authorization, idempotency and orchestration, and points outward. Even a trivial read goes through a query handler.
3. **A cycle** between two components: break it with a port in the inner ring.
4. **A data format leaking inward**: a Domain Event or Aggregate holding a driver's row type, an HTTP request struct, or a broker message type.

All are the same defect: an arrow that points outward or skips a ring.

## 5. A Violation and Its Fix

**Violation.** In a locker service, `Locker.reserve()` must refuse a locker under maintenance. The domain code opens a database connection and queries a maintenance table inside the Aggregate method.

**Why it fails:** the domain imports the driver (forbidden dependency 1); the invariant is tangled with I/O; the Aggregate can't be unit-tested.

**Fix:**
- The **state the invariant needs lives on the Aggregate** (an `under maintenance` flag), and the method checks it with no I/O.
- The **use case** loads the Aggregate through the domain's repository port, calls `reserve()`, and saves; the save also enqueues the outbox event.
- The **persistence adapter** fills the flag when it reconstitutes the Aggregate.

All arrows now point inward: use cases to the domain; the adapter implements the domain's port. The domain imports only the standard library.

## 6. The Fitness Function

A rule stated only in a picture drifts with the next import. A **fitness function** is an automated, continuously run check that an architecture characteristic still holds (Richards & Ford, `fundamentals-of-software-architecture-richards-ford.md`). For the Dependency Rule:
- An **import check in the build** that fails when anything in the domain imports outside the standard library (no driver, router, broker client, adapter or entry-point package). Default stack: `go-makefile`'s `arch` target runs `check-imports.sh`.
- Optionally, checks that entry points don't import adapters' drivers, and that there are no import cycles between components.

The artifact names the fitness function as a deliverable alongside the picture. Drawing the rule and enforcing it are separate.

## 7. Checklist

- [ ] The domain imports the standard library only.
- [ ] Every port is declared in the domain and implemented by an adapter.
- [ ] No entry point reaches the database or an external system directly.
- [ ] Invariants live on Aggregates, not in use cases.
- [ ] No cycles; every arrow points inward.
- [ ] A named fitness function enforces it in the build.
