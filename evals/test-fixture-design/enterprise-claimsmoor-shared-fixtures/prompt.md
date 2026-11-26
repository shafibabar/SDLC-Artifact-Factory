---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Claimsmoor**, an insurance claims platform in Python (SQLAlchemy async with the asyncpg driver, pytest) on the **enterprise** profile. The tenancy design is hybrid: small insurers share a pooled PostgreSQL database where every row has a `tenant_id`; each large insurer has its own separate database whose tables have no `tenant_id` column. Please set up the integration test fixtures like this:

```python
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def db_url():
    with PostgresContainer() as pg:
        yield pg.get_connection_url()
```

1. Add one session-wide database session that commits, so tests are fast.
2. Add one session-wide `demo_claim` object that tests modify as needed.
3. Put `tenant_id` on every test record, including the large insurers', for consistency.
4. Load last month's production claims as realistic test data.

Use this plugin's test-fixture-design skill. Answer in your reply, not in a file. Keep it short: the corrected fixtures and a few lines of explanation.
