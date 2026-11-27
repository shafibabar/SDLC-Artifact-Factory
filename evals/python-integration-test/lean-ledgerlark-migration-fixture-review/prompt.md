---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ledgerlark**, an invoicing tool for freelancers, on the **lean** profile. It is Python with asyncpg and Alembic on PostgreSQL. Our Alembic `env.py` is the async template: it does `config.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])` and runs migrations with `asyncio.run(...)`. My laptop has `DATABASE_URL` exported and pointing at my working database. Here is the draft `conftest.py` for integration tests:

```python
@pytest_asyncio.fixture(scope="session")
async def pool():
    with PostgresContainer("postgres:16.4") as pg:
        cfg = Config("alembic.ini")
        cfg.set_main_option("sqlalchemy.url", pg.get_connection_url())
        command.upgrade(cfg, "head")
        pool = await asyncpg.create_pool(pg.get_connection_url())
        yield pool
```

Please approve it with two additions: set `asyncio_default_fixture_loop_scope = "session"` to cure our "attached to a different loop" errors (that one line should be all it needs), and add an autouse fixture that truncates every table after each test.

Use this plugin's python-integration-test skill. Answer in your reply, not in a file, and keep it short: what is wrong and the corrected snippets.
