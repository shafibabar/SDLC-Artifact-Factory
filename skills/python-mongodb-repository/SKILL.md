---
name: python-mongodb-repository
description: >
  Teaches the backend-engineer to implement a MongoDB repository in Python
  with motor (the async driver) — a repository behind a typing.Protocol port
  with a fake for tests, bson mapping to/from the domain, aggregation
  pipelines from Python, multi-document transactions, index management, and
  per-tenant scoping. The Python analog of go-mongodb-repository; the
  document-store counterpart of python-repository-pattern.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, mongodb, repository, python, motor, aggregation, driver]
produces: python-mongodb-repository
domain: backend
status: stable
related: [go-mongodb-repository, document-data-modeling, python-repository-pattern, python-domain-model]
---

# Python MongoDB Repository

## Purpose

A MongoDB repository is the only thing that knows how a document-shaped Aggregate is persisted. It satisfies a small, consumer-defined `typing.Protocol` port declared in the domain layer, hides the async `motor` driver entirely from the application layer, and guarantees three non-negotiables identical in spirit to `python-repository-pattern`: every operation is scoped to the tenant, every driver error crossing out of the package arrives as a domain exception, and the application layer — never a repository method — owns any multi-document transaction boundary.

This is the **document-store analog** of `python-repository-pattern`. Where that skill owns `asyncpg` / Postgres / `$1` SQL, this one owns `motor` / BSON / the aggregation pipeline. The repo default is still PostgreSQL (`document-data-modeling` gates *when* a service earns Mongo at all); this skill governs *how* to build the repository once that decision is made and justified.

As in Cosmic Python, the port exists **primarily for the fake, not for decoupling for its own sake**: a dict-backed `FakeRepository` gives the service layer fast, database-free unit tests, while the real `motor` adapter is exercised only by a small integration suite against a real MongoDB (`testcontainers-python`).

---

## The Protocol Port — Never `AsyncIOMotorClient`

Declare the port as a `typing.Protocol` in the domain layer, in domain vocabulary — it names no driver type. The `motor` adapter matches its shape structurally without importing or subclassing it, keeping the dependency arrow pointing inward.

```python
from typing import Protocol
from uuid import UUID

class DataAssetRepository(Protocol):
    async def get(self, asset_id: UUID) -> "DataAsset | None": ...
    async def save(self, asset: "DataAsset") -> None: ...
    async def list_by_sensitivity(self, level: "SensitivityLevel") -> "list[DataAsset]": ...
```

The adapter receives an `AsyncIOMotorDatabase` and holds a single `AsyncIOMotorCollection` — never an `AsyncIOMotorClient`. The full port, adapter constructor, CRUD body, and the `runtime_checkable` note: **`references/motor-repository.md`**.

**Honest divergence from Go — the port is unchecked at runtime.** Go's `var _ domain.DataAssetRepository = (*MongoRepo)(nil)` fails to *compile* if a method drifts; a `typing.Protocol` is only verified when `mypy`/`pyright` runs. This makes the static type-check a *required* CI gate (`python-tooling`), not an optional nicety — there is no compile-time assertion available.

---

## BSON Mapping Discipline — Dicts and Reconstitute-on-Decode

`motor` speaks plain Python `dict` documents, not tagged structs. The mapping is manual and explicit in two small module-private functions — `_to_doc(asset) -> dict` and `_reconstitute(doc) -> DataAsset` — kept beside the adapter.

- Rebuild every read through the Aggregate's **`reconstitute` classmethod, never the `DataAsset(...)` constructor / `create`** (the consumer side of the split `python-domain-model` defines). Calling the invariant-checked, event-emitting constructor from a read path re-validates already-valid stored data and re-emits the creation Domain Event on every read.
- Store the domain UUID as a canonical string under `assetId`, leaving Mongo's `_id` (a `bson.ObjectId`) for the database's own use. Store the tenant discriminator as `tenantId` and the schema discriminator as `schemaVersion` (`document-data-modeling` owns the handle-on-read upgrade switch).
- **Never leak a `dict`, a `bson.ObjectId`, or a `motor` cursor upward** — callers receive `DataAsset`, never a raw document. Full `_to_doc` / `_reconstitute` pair and field table: **`references/motor-repository.md`**.

---

## Per-Tenant Scoping — `tenantId` in Every Filter

Every filter carries `tenantId` as the leading field, and `tenantId` is the leading field of every compound index (ESR rule — Equality first). This is the application-layer backstop *behind* physical per-tenant isolation (`multi-tenancy-design`), not the sole barrier — the second independent layer, exactly as `python-repository-pattern` treats its `tenant_id = $N` clause.

```python
filter = {"tenantId": _tenant_id().hex, "assetId": str(asset_id)}
```

Read the tenant from a `contextvars.ContextVar`, never a module global. A missing tenant must **raise loudly** at the boundary (auth middleware did not run), never silently become a cross-tenant scan. A filter missing `tenantId` is a code-review defect, no exceptions. Full helper: **`references/motor-repository.md`**.

---

## Error-Translation Standard

Every driver error a method can receive is classified once, in a small private `_translate_mongo_error` helper beside the repository — never a shared `infrastructure/errors.py`. The rule with no exception: **no `pymongo`/`bson` type ever crosses out of `infrastructure/mongodb/`.**

**Honest divergence from Go — a miss is `None`, not an error.** Go's `col.FindOne(...).Decode(...)` returns `mongo.ErrNoDocuments` on a miss, translated to `domain.ErrNotFound`. In motor, `await collection.find_one(filter)` **returns `None`** on a miss — there is no exception to translate. The not-found path is therefore a `None`-check (`get` returns `None`; a caller that requires presence raises), while a duplicate key surfaces as `pymongo.errors.DuplicateKeyError` (server code **11000**), translated to `ConflictError`. Full table and helper: **`references/motor-repository.md`**.

---

## When to Use a Multi-Document Transaction

Single-document writes are **always atomic** in MongoDB — that is the document model's whole point, and the reason a correctly-drawn Aggregate almost never needs a transaction. Reach for one only as a targeted tool, and treat needing one *frequently* as a signal the documents are drawn wrong.

| Situation | Correct tool |
|---|---|
| One Aggregate, all its state in one document | Plain `update_one` — atomic, no session |
| Optimistic concurrency on one document | `update_one` with a `version` predicate in the filter (CAS) |
| Two documents / two collections that must commit together | A session + `session.with_transaction(...)`, `w="majority"` |
| A cross-Aggregate workflow you reach for often | Re-examine the document boundaries first (`document-data-modeling`) |

A transaction adds latency and lock contention, carries a 60-second default runtime limit, and requires a replica set (unavailable on a standalone `mongod`). The session/transaction boundary is the *application layer's* — a repository method never calls `start_session`. Worked session example and cost discussion: **`references/aggregation-transactions-indexes.md`**.

---

## Aggregation, Indexes — Pointers

- **Aggregation from Python** builds a pipeline as a `list[dict]` stage list — `$match` first on an indexed field, then `$group` / `$lookup` / `$project` / `$unwind` — decodes the cursor, and returns a domain Read Model (a dataclass), never a raw `dict`. Keep pipelines *inside* the repository; never leak stages upward. `$lookup` is the exception, not the norm — heavy join-shaped work is the signal to reconsider Postgres.
- **Indexes are created at startup** (idempotently) via `collection.create_indexes([IndexModel(...)])`, following the ESR rule plus a TTL index for anything ephemeral. Mongo has no migration DDL (`python-migration` owns the Postgres story); index creation is code that runs on boot.

Both worked in full, with the dict-backed `FakeRepository`: **`references/aggregation-transactions-indexes.md`**.

---

## Repository Rules

- **No business logic.** Loads, saves, translates — decisions belong in the Aggregate / service layer.
- **Return domain types, not documents.** Callers receive `DataAsset`, never a `dict` or `bson.ObjectId`.
- **`await` everywhere; propagate cancellation.** Every method is `async` and awaits every motor call so the caller's timeout (`asyncio.wait_for` / `maxTimeMS`) propagates.
- **One repository per Aggregate.** No generic `Repository[T]`; small focused Protocol ports.
- **`reconstitute` on decode, the constructor never.** No exceptions.
- **A repository method never calls `start_session`.** The transaction boundary is the application layer's, exactly as `conn.transaction()` is in `python-repository-pattern`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Protocol port, not client | Adapter holds an `AsyncIOMotorCollection` | Adapter holds an `AsyncIOMotorClient` | Read the `__init__` |
| Static assertion in CI | `mypy` type-checks adapter + fake against the Protocol | No type-check gate | `python-tooling` CI runs `mypy` |
| Reconstitute on decode | Every read path calls `.reconstitute(...)` | A read calls the constructor / `create` | `grep -n "DataAsset(" infrastructure/mongodb` — no constructor in a read path |
| Tenant scoping | Every filter carries `tenantId` | A filter missing `tenantId` | Read every filter dict |
| No driver type leaks | No `pymongo`/`bson`/`dict` document past `mongodb/` | A `DuplicateKeyError` inspected in the app layer | `grep -rn "pymongo\|bson" application/ domain/` — empty |
| Error translation complete | `None` miss and `DuplicateKeyError` both handled | Raw driver error returned | Read `_translate_mongo_error` and `get` |
| Session only in app layer | Zero `start_session` inside a repository method | A repository opens its own session | `grep -rn "start_session" infrastructure/mongodb` — empty |
| Fake matches the port | `FakeRepository` implements the same Protocol | Fake drifts from the real adapter's method set | `mypy` type-checks the fake against the Protocol |

---

## Anti-Patterns

- **Depending on `AsyncIOMotorClient` / a bare collection handle** — unswappable, forces a live server for every unit test; depend on the narrow Protocol and inject the collection.
- **Calling the constructor from a decode path** — re-validates stored data and republishes a stale creation event on every read.
- **Leaking a `dict` / `bson.ObjectId` / cursor upward** — the application layer must never speak BSON.
- **`start_session` inside a repository** — steals the transaction boundary the application layer owns; two repo calls needing to commit together can no longer compose.
- **Reaching for a multi-document transaction as a default** — usually a mis-drawn Aggregate; single-document writes are already atomic.
- **A filter with `tenantId` "optimised away"** — it is in every filter, no exceptions, even under physical isolation.
- **Relying on `_underscore` privacy to protect an invariant** — Python encapsulation is convention-only; the repository must not assume callers cannot reach around the Aggregate.

---

## Output Format

Python source built exactly to the standards above, plus integration tests against a real MongoDB via `testcontainers-python` (`python-integration-test` owns the harness; this skill states what must be testable — real filters, real duplicate-key conflicts, real pipeline output):

```
domain/ports.py                                    (the DataAssetRepository Protocol)
infrastructure/mongodb/dataasset_repo.py           (adapter: CRUD, bson mapping, _translate_mongo_error, tenant filter)
infrastructure/mongodb/indexes.py                  (startup index creation — ESR + TTL)
tests/fakes.py                                     (dict-backed FakeRepository — enables DB-free service tests)
tests/infrastructure/test_dataasset_repo.py        (integration test — python-integration-test)
```

Full standards: `references/motor-repository.md` (Protocol port, motor adapter, CRUD with bson mapping, error table, tenant filter, client construction) and `references/aggregation-transactions-indexes.md` (aggregation from Python, multi-document transactions, index creation, dict-backed fake).
