---
name: python-integration-test
description: >
  Teaches the backend-engineer to write Python integration tests —
  testcontainers-python spinning a real Postgres and Redpanda, session-scoped
  async fixtures composing into per-test rolled-back transactions (or
  fresh-tenant isolation), running Alembic migrations against the container, and
  asserting real end-state for managed dependencies (repository, outbox,
  consumer). The Python analog of go-integration-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, integration-test, testcontainers, postgres, redpanda, asyncpg, aiokafka, alembic, pytest-asyncio, tenant]
related: [go-integration-test, python-repository-pattern, python-migration, python-event-consumer]
tools: [Bash]
---

# Python Integration Test

## Purpose

Unit tests prove your logic; integration tests prove it works against the
**real** dependency — the SQL actually runs on PostgreSQL, the CAS on `version`
actually conflicts, the outbox row actually publishes to Redpanda, the
idempotent consumer actually dedups on redelivery. A `FakeRepository`
(`python-repository-pattern`) can't catch a wrong column name, a broken Alembic
revision, or a real transaction-isolation surprise; only the genuine engine can.
This is Khorikov's rule made concrete: a **managed** dependency (your own
Postgres, your own outbox) is verified through **real end-state**, never mocked.
The discipline is identical to `go-integration-test`; only the runner (`pytest`
+ `pytest-asyncio`), the container library (`testcontainers-python`), and the
isolation mechanics differ.

---

## Testcontainers-python Standard

Every Postgres/Redpanda-dependent test gets its container from a **session-scoped
async fixture** in the top-level `tests/conftest.py` — one throwaway
`PostgresContainer` and one `RedpandaContainer` per whole run, not one per test.
A Postgres/Redpanda pair costs seconds to become ready; a large suite cannot pay
that per test. Container-level isolation is deliberately given up here and
recovered at the test level below (exactly `go-integration-test`'s tradeoff).

**Migrate, then test.** The session fixture runs the **real Alembic revision
chain** (`python-migration`) against the fresh container via `alembic upgrade
head` before yielding — a broken migration must fail the suite, not just
production. Never hand-create the schema in test setup; that ships a broken
migration green.

**Wait past `initdb`'s first-boot restart.** Postgres logs its readiness line
*twice* — once during `initdb`, once for the real server after a restart — and a
fixture that proceeds on the first sighting races a connection-refused window.
This is the Python analog of Go's "a port-only wait races `initdb`'s restart".
Full session fixtures, the two-sighting wait, the `alembic upgrade head` call
inside the fixture, and connection/pool wiring: **`references/testcontainers-setup.md`**.

---

## Test-Isolation Standard: Per-Test Rollback vs Fresh-Tenant

**Default: per-test transaction rollback.** A function-scoped fixture opens
`conn.transaction()` on a connection bound to the running event loop, hands that
same `conn` to the repository, and **never commits** — teardown rolls the outer
transaction back. Because the repository's own `async with conn.transaction()`
opens as a **SAVEPOINT** nested inside the never-committed outer transaction, its
"commit" only releases the savepoint; the outer rollback still discards
everything. Writes are invisible to every other test and vanish for free.

**The one exception — fresh-tenant isolation.** A test whose subject *is*
commit/transaction-boundary behavior itself (outbox atomicity, the relay's
polling `SELECT`, a real concurrent-commit CAS race, a consumer processing a
genuinely committed message) cannot use an uncommitted wrapper — there is
nothing for a second connection or the relay to observe. These commit for real,
scoped to a unique `tenant_id` minted per test, with teardown deleting only that
tenant's rows. This doubles as the **tenant-isolation** proof: seed two tenants,
assert a tenant-scoped query returns exactly one tenant's rows even though the
physical schema holds both. Strategy comparison, the async savepoint mechanics,
and worked isolation fixtures: **`references/isolation-and-assertions.md`**.

**Honest divergence from Go — parallelism costs containers, not just goroutines.**
Go recovers speed with `t.Parallel()` while one container pair serves the whole
test binary. Python's GIL means real test parallelism needs `pytest-xdist`, which
spawns **separate worker processes** — and a `session`-scoped fixture runs **once
per worker**, so `-n 4` starts **four** Postgres/Redpanda pairs, not one. There
is no shared-across-goroutines single container the way Go gets it for free;
budget container RAM against worker count, or keep the suite serial and lean on
transaction rollback for speed instead.

---

## What Belongs Here vs. a Unit Test

Mirrors `python-unit-test`'s complexity quadrants from the integration side. The
repository (`python-repository-pattern`) is the clearest case: it is a **Humble
Object** whose correctness lives in real SQL, real constraints, and real
transaction semantics a fake cannot verify — so integration tests **replace**
unit tests here rather than supplement them. Domain Aggregates
(`python-domain-model`) are the opposite: rich logic, few collaborators, thorough
**unit** coverage, and a real database would add cost with no signal a fake
didn't already give. The asyncpg adapter, the outbox relay
(`python-event-publisher`), and the consumer's transport shell
(`python-event-consumer`) are this skill's territory.

---

## Verify Through Real End-State

Never assert on *how* code called a managed dependency — assert on the state it
left behind:

- **Repository** — `save`, then read the row back with a fresh connection and
  assert the persisted fields, the incremented `version`, and (for the CAS race)
  that the second stale-version `save` raised `ConcurrentModificationError`.
- **Outbox** — `save` inside one transaction, then `SELECT` the outbox table on
  the same connection and assert exactly one un-relayed row with the expected
  event type and payload — proving atomicity, not just intent.
- **Consumer** — publish a real message to the Redpanda topic via `aiokafka`,
  poll (never `asyncio.sleep`) until the consumer's effect appears in Postgres,
  then **redeliver the same message** and assert the effect happened **once** —
  idempotency proven against a real broker. Worked repository, outbox, and
  idempotent-consumer round-trip tests: **`references/isolation-and-assertions.md`**.

---

## Timeout, Flakiness, and CI

Wait for every async effect (relay publish, consumer processing) by **polling
with a deadline** — an `async` poll helper with a bounded timeout, never
`await asyncio.sleep(n)` as a "give it a second" guess. testcontainers-python
allocates a **dynamic host port** per container, so parallel `pytest-xdist`
workers never collide and no fixed host port is ever mapped. Integration tests
carry a `@pytest.mark.integration` marker so `pytest -m "not integration"` skips
them where Docker is unavailable — the analog of Go's `-short`. Poll helper,
marker wiring, and the local-vs-CI notes: **`references/testcontainers-setup.md`**.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Real dependencies | testcontainers-python Postgres/Redpanda | Mocked DB/broker called "integration" |
| Migrations verified | `alembic upgrade head` runs in the fixture | Schema hand-built in test setup |
| Container strategy | Session-scoped fixture, one pair per worker | Fresh container per test function |
| Isolation strategy | Per-test rollback (or documented fresh-tenant exception) | Tests leaking committed data |
| Readiness | Waits past `initdb`'s restart (two sightings) | Proceeds on first readiness log |
| Async gated | `pytest-asyncio`; conn bound to the running loop | Sync driver, or conn shared across loops |
| Concurrency proven | Stale-version CAS actually raises | CAS assumed, never exercised |
| Idempotency proven | Redelivery asserts effect happened once | Dedup assumed, not verified |
| No sleeps | Async effects polled with a deadline | `asyncio.sleep` waiting for relay/consumer |
| CI-portable & marked | Docker-only; `-m "not integration"` skips | Depends on an external shared DB / fixed port |

---

## Anti-Patterns

- **Mocking the database in an "integration" test** — the point is real SQL, real
  constraints, real transaction semantics; a mock makes it a mislabeled unit test.
- **One container per test function** — startup cost dominates runtime; share a
  session-scoped fixture and isolate at the test level instead.
- **Hand-creating schema in test setup** — bypasses Alembic, so a broken revision
  ships green; always run `alembic upgrade head`.
- **Per-test rollback for a commit-behavior test** — an outbox-atomicity or
  real-CAS-race test needs an actual commit; use the fresh-tenant exception.
- **`asyncio.sleep` to "wait for" the relay or consumer** — poll with a deadline
  so the test is fast when the system is fast and fails with a message when not.
- **Sharing one asyncpg connection across event loops** — an asyncpg connection
  is bound to the loop it was created on; each test's transactional fixture must
  acquire on the loop the test runs on.
- **Fixed host-port container mappings** — defeats dynamic allocation and
  reintroduces the port collisions xdist workers rely on it to avoid.
- **Forcing the repository through a unit test with a mocked driver** — tests the
  mock, not the repository; verify against the real engine.

---

## Output Format

Produces integration test files and the container/fixture harness:

```
tests/conftest.py                              (session Postgres/Redpanda fixtures, alembic upgrade head)
tests/integration/conftest.py                  (per-test rollback fixture, fresh_tenant factory)
tests/integration/test_dataasset_repo.py       (repository + outbox real-SQL round-trips)
tests/integration/test_event_consumer.py       (aiokafka publish → poll → redeliver, idempotency)
```

Full standards: `references/testcontainers-setup.md` (session containers, async
fixtures, Alembic in the fixture, poll helper, connection wiring) and
`references/isolation-and-assertions.md` (rollback vs fresh-tenant, savepoint
mechanics, worked repository/outbox/consumer tests, tenant-isolation assertions).
