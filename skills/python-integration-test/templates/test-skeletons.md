# Test File Skeletons

Copy what the test needs into `tests/integration/<layer>/test_<module>.py` (the path the `tdd-gate` hook accepts for `src/<pkg>/<layer>/<module>.py`); replace `product`, the `things` table and `create_app`. Run against the harness with a one-table migration and a stand-in `create_app` that returns an empty `FastAPI()`.

The `integration` marker is added by `conftest.py`; do not repeat it. Broker tests (duplicate delivery, dead letters, relay) are copied from `../examples/02-standard-bike-workshop.md`.

These async tests and the harness fixtures they use need `asyncio_mode = "auto"` in `[tool.pytest.ini_options]`.

## Rollback (default), real commit, API behaviour

### `tests/integration/adapters/test_things.py`

```python
import asyncpg
import httpx

from product.app import create_app


# Default: roll back. Replace the SQL with calls to the repository under test, built on db.
async def test_a_thing_is_stored(db, test_id):
    thing = test_id("thing")
    async with db.transaction():  # the caller's transaction: a savepoint here
        await db.execute("INSERT INTO things (id, name) VALUES ($1, $2)", thing, "lamp")

    assert await db.fetchval("SELECT name FROM things WHERE id = $1", thing) == "lamp"


# Real commit needed: <name the reason>. scoped is registered before any write and
# lists every table the test or the code under test writes, children first.
async def test_a_thing_is_visible_to_another_connection(pool, scoped, postgres_server, test_id):
    thing = test_id("thing")
    scoped(thing, "DELETE FROM things WHERE id = $1")
    await pool.execute("INSERT INTO things (id, name) VALUES ($1, $2)", thing, "lamp")

    other = await asyncpg.connect(postgres_server.url())
    try:
        assert await other.fetchval("SELECT count(*) FROM things WHERE id = $1", thing) == 1
    finally:
        await other.close()


# API behaviour through the real app, in the test's event loop, so its transaction
# becomes a savepoint inside the test's. Replace create_app with the service's own.
async def test_an_unknown_thing_is_404(one_pool):
    transport = httpx.ASGITransport(app=create_app(one_pool), raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as api:
        reply = await api.get("/things/unknown")

    assert reply.status_code == 404
```

## Migration test (synchronous: `env.py` calls `asyncio.run`)

Copy from `../examples/01-lean-choir-library.md` (down and up again) or `../examples/03-enterprise-parcel-lockers.md` (the previous release on the new schema).
