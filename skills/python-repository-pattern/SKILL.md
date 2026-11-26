---
name: python-repository-pattern
description: >
  Teaches the backend-engineer to build a Python repository — a
  typing.Protocol/ABC port with a set-backed FakeRepository for
  database-free unit tests, and the real asyncpg adapter using the same $1
  positional SQL as pgx, CAS on version, outbox insert in the same
  transaction, and tenant_id in every query. The Python analog of
  go-repository-pattern.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, asyncpg, repository, postgres, outbox, optimistic-concurrency, tenant, protocol, fake]
produces: python-repository-implementation
domain: backend
status: stable
related: [go-repository-pattern, python-domain-model, python-service-layer, python-migration]
---

# Python Repository Pattern

## Purpose

A repository is the only thing that knows how an Aggregate is persisted. It satisfies a small, consumer-defined port declared in the domain layer, hides `asyncpg` entirely from the application layer, and guarantees three non-negotiables carried over unchanged from `go-repository-pattern`: every write drains the Aggregate's Domain Events into the Transactional Outbox *in the same transaction* as the state change, in a multi-tenant product every query is scoped to `tenant_id`, and every update is a compare-and-swap on `version`.

This is `asyncpg`-direct throughout — no SQLAlchemy ORM. That is a deliberate departure from the Python mainstream (Percival & Gregory and Halstead both default to SQLAlchemy) taken so the same Postgres-specific, `$1`-placeholder SQL as `pgx` is written by hand, not generated. `asyncpg`'s positional-placeholder syntax already resembles `pgx`'s, which makes this one of the closest 1:1 ports in the roster.

The primary justification for the port is **not decoupling for its own sake — it is the fake for tests** (Cosmic Python, Ch. 2). Because the port is an abstraction, a `FakeRepository` backed by a `set` is a few lines, so the service and domain layers get fast, database-free unit tests, while the real `asyncpg` adapter is exercised only by a small integration suite (`python-integration-test`). The abstraction earns its keep at the test seam.

---

## The Port and Its Fake-for-Tests Payoff (the primary reason this exists)

Declare the port as a `typing.Protocol` in the domain/service layer; the `asyncpg` adapter matches its shape structurally without importing or subclassing it — the closest Python gets to Go's implicit interface satisfaction, keeping the dependency arrow pointing inward.

```python
from typing import Protocol

class DataAssetRepository(Protocol):
    async def get(self, asset_id: UUID) -> DataAsset | None: ...
    async def save(self, asset: DataAsset) -> None: ...
    async def list_by_source(self, source_id: UUID) -> list[DataAsset]: ...
```

The set-backed `FakeRepository` is a real, working implementation of that same port — asserted against by **state and outcome**, never by mock call-expectations (Cosmic Python's fakes-over-mocks discipline). It is what makes the entire service layer unit-testable with no Postgres, no event loop bound to a socket, no `testcontainers`. Full Protocol port, the set-backed `FakeRepository`, and a worked service-layer unit test that never touches a database: **`references/port-and-fake.md`**.

**Honest divergence from Go — the Protocol is unchecked at runtime.** A `typing.Protocol` port is only verified if `mypy`/`pyright` runs. Nothing at runtime stops a wrong-shaped object from being injected, unlike Go where interface satisfaction is a compile error. This makes the static type-check step a *required* CI gate for this skill (`python-tooling`), not an optional nicety — there is no compile-time `var _ DataAssetRepository = (*Repo)(nil)` assertion available; the equivalent guarantee is `mypy` in CI.

---

## The asyncpg Adapter

The real adapter lives at the edge (`src/<pkg>/adapters/postgres.py`, `python-project-structure`'s layout). Its methods run against a caller-supplied connection so the service layer's Unit of Work owns the transaction boundary:

```python
async with pool.acquire() as conn:
    async with conn.transaction():
        await repo.save(asset)   # UPDATE + outbox INSERT, one atomic transaction
```

`async with conn.transaction():` replaces Go's `pool.Begin(ctx)` plus deferred rollback — the block commits on clean exit and rolls back on any exception. Reads use `conn.fetchrow(...)`/`conn.fetch(...)`; writes use `conn.execute(...)` or `fetchrow ... RETURNING`, all with `$1`/`$2` positional placeholders identical to `pgx` — never f-strings or `%`-formatting into SQL text (`asyncpg` sends SQL and values as separate protocol messages; a value can never be re-parsed as SQL). Full adapter — CAS `UPDATE` returning the affected count, outbox `INSERT` in the same transaction, tenant scoping, the worked `DataAssetRepo`, error translation, and the integration-test note: **`references/asyncpg-adapter.md`**.

Rows read back are mapped through the **`reconstitute` classmethod, never `register` or the `DataAsset(...)` constructor** — the consumer side of the split `python-domain-model` defines. Calling the invariant-checked, event-emitting constructor from a read path would re-validate already-valid stored data and re-emit a stale creation event into the outbox on every read.

---

## The Three Carried-Over Non-Negotiables

These transfer from `go-repository-pattern` with the SQL text essentially unchanged:

1. **CAS on `version`.** The Aggregate bumps its own `version_number` in each mutating method and remembers `persisted_version`. A never-saved Aggregate (`persisted_version == 0`) is `INSERT`ed; every later write is `... SET version = <version_number> ... WHERE id = $n AND tenant_id = $m AND version = <persisted_version>`, followed by `mark_persisted()`. A row count of 0 means a concurrent write won — raise `OptimisticConcurrencyError`, never last-write-wins. `asyncpg`'s `conn.execute` returns a status string (`"UPDATE 1"`); parse the count or use `fetchrow ... RETURNING`.
2. **Outbox insert in the same transaction.** The Aggregate's Domain Events (`pull_events()`) are `INSERT`ed into the outbox table inside the *same* `conn.transaction()` block as the state `UPDATE`. Publishing after commit reintroduces the dual-write problem the Transactional Outbox closes — the relay (`python-event-publisher`) delivers them later.
3. **`tenant_id` in every query (multi-tenant products).** Every `WHERE` clause filters `tenant_id`, whichever isolation model the tenancy design chose — the application-layer backstop, not the isolation mechanism itself. A missing tenant id must fail loudly (read it from the `contextvars.ContextVar` in `domain/context.py`, not a module-level value), never silently become a cross-tenant query. A single-tenant product has no `tenant_id`.

---

## Repository Rules

- **No business logic.** Loads, saves, translates — decisions belong in the Aggregate/service layer.
- **Return domain types, not records.** Callers receive `DataAsset`, never an `asyncpg.Record`.
- **One repository per Aggregate.** No generic `Repository[T]`; small focused Protocol ports.
- **`reconstitute` on read, the constructor never.** See the standard above — no exceptions.
- **The adapter never opens its own transaction.** The Unit of Work / service layer owns the boundary; `save` is a hard precondition on running inside a caller-supplied `conn.transaction()`.
- **No `asyncpg` exception or record crosses out of the adapter.** `asyncpg.PostgresError` subclasses are translated to domain exceptions (or `RepositoryError`) at this edge; no caller inspects a `sqlstate` itself.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Atomic state + events | `UPDATE` and outbox `INSERT` share one `conn.transaction()` | Two calls with no shared transaction | Read `save`; confirm both writes are inside one `async with conn.transaction()` |
| No transaction opened in the adapter | The adapter receives `conn`; the UoW owns `conn.transaction()` | A repository method opens its own transaction and commits | Read `save` — it takes a connection, does not call `pool.acquire()` itself |
| Reconstitute on read | Every read path calls `DataAsset.reconstitute` | A read calls `register` or the constructor | `grep -n "DataAsset(\|DataAsset.register" src/<pkg>/adapters` — no hits |
| Optimistic concurrency | CAS on `persisted_version`; 0 rows → `OptimisticConcurrencyError` | Last-write-wins, or the CAS compares against the already-bumped version | Read the `UPDATE`'s `WHERE` for `version = $N` bound to `persisted_version` |
| Tenant scoping | Every query filters `tenant_id` | A query missing the tenant filter | Read every `WHERE` clause for `tenant_id = $N` |
| Parameterised SQL | Only `$N` placeholders, values passed as args | Any f-string / `%`-formatted SQL | `grep -n 'f"""\|f"\|%' ` over the SQL strings — none feeding a query |
| No asyncpg type leaks | `asyncpg` errors translated at this edge | An `asyncpg` type referenced in the inner layers | `grep -rn "import asyncpg" src/<pkg>/domain src/<pkg>/service_layer` — empty |
| Fake matches the port | `FakeRepository` implements the same Protocol | Fake drifts from the real adapter's method set | `mypy` type-checks the fake against the Protocol in CI |

---

## Anti-Patterns

- **Opening a transaction inside the adapter** — reintroduces the composability problem the Unit-of-Work boundary closes; two repository calls can no longer commit together.
- **Calling the constructor from a read path** — re-validates stored data and republishes a stale creation event into the outbox on every read.
- **Publish-after-commit** — reintroduces the dual-write problem the Transactional Outbox closes.
- **Last-write-wins saves** — an `UPDATE` with no `version` predicate silently overwrites a concurrent write.
- **Tenant filter "optimised away"** — in a multi-tenant product `tenant_id` is in every `WHERE` clause, no exceptions, whatever the isolation model.
- **f-string / `%` SQL assembly** — even "safe" fragments normalise the habit that ends in injection; `asyncpg` has `$N` for exactly this.
- **Mock-heavy repository tests** — asserting on *how* the service calls the repo couples the test to implementation; use the set-backed fake and assert on state.
- **Relying on `_underscore` privacy to protect an invariant** — Python's encapsulation is convention-only (weaker than Go's compiler-enforced unexported fields); the repository must not assume external callers cannot reach around the Aggregate.

---

## Output Format

Python source built exactly to the standards above, plus integration tests run against a real PostgreSQL via `testcontainers-python` — this skill states what a repository method must be testable against (real SQL, real CAS conflicts, real constraint violations); `python-integration-test` owns the harness:

```
src/<pkg>/domain/ports.py                       (the DataAssetRepository Protocol)
src/<pkg>/adapters/postgres.py                  (the asyncpg adapter: reads, CAS save, outbox insert)
src/<pkg>/adapters/errors.py                    (RepositoryError, the translation fallback)
tests/fakes.py                                  (set-backed FakeRepository — enables DB-free service tests)
tests/integration/test_dataasset_repo.py        (integration test — python-integration-test)
```

Full standards: `references/port-and-fake.md` (Protocol port, set-backed `FakeRepository`, DB-free service test) and `references/asyncpg-adapter.md` (real adapter, `$1` SQL, CAS, outbox-in-transaction, tenant scoping, worked `DataAssetRepo`).
