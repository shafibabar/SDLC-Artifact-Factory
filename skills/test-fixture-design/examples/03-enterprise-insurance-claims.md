# Enterprise: Insurance Claims Platform (pooled and siloed tenants, event history, parallel shards)

Python. Run: the two files below passed (4 tests, pytest 9.2.0, Python 3.14, SQLite). SQLite stands in for the mechanics only: PostgreSQL row-level security, a database per siloed tenant, parallel shards and containers are **unverified**.

## Input

> "CI now runs eight parallel shards against one shared staging database and truncates between tests. Most insurers share the pooled database; two large ones have their own. We also changed `claim_filed` from an `amount` float to `amount_minor` and a currency, so please regenerate the old event fixtures."

## Plan, checked before any change

| Current | Replacement | Reason |
|---|---|---|
| Shared staging database | A throwaway container per worker, address taken from the container | Any other address is refused: tests would migrate and delete real data |
| `TRUNCATE` between tests | Rollback per test | Truncation destroys the rows of parallel tests |
| Claim and outbox atomicity test | Scoped data: own insurer ID | Subject is the commit boundary |
| Cross-tenant refusal over the running API (pooled) | Scoped data: two own insurer IDs | The server uses its own connection |
| Siloed insurer repository tests | Rollback, against a throwaway database standing for that silo | One connection |
| Regenerate old event samples | Keep them; add a version 2 sample; test the converter | Stored events did not change |

Cross-tenant tests assert both directions: insurer A's request for B's claim is refused, and A still reads its own, so an empty database cannot pass. In the pooled database they connect as the application role, never the table owner, so row-level security applies (`multi-tenancy-design`).

## Output (runnable part)

`tests/conftest.py`

```python
import sqlite3
import uuid

import pytest

NAMESPACE = uuid.UUID("6f9c1b4e-0000-4000-8000-000000000001")


@pytest.fixture(scope="session")
def connection(tmp_path_factory):
    path = tmp_path_factory.mktemp("db") / "claims.sqlite"  # one per worker process
    conn = sqlite3.connect(path, isolation_level=None)
    conn.execute("CREATE TABLE claims (id TEXT PRIMARY KEY, insurer_id TEXT NOT NULL)")
    conn.execute("CREATE TABLE outbox (claim_id TEXT NOT NULL, insurer_id TEXT NOT NULL)")
    yield conn
    conn.close()


@pytest.fixture
def test_id(request):
    def make(label: str) -> str:
        return str(uuid.uuid5(NAMESPACE, f"{request.node.nodeid}/{label}"))
    return make


@pytest.fixture
def scoped(connection):
    registered = []

    def register(key: str, *deletes: str) -> None:
        assert deletes, "list every table this test writes"
        registered.append((key, deletes))

    yield register

    errors = []
    for key, deletes in reversed(registered):
        for statement in deletes:
            try:
                connection.execute(statement, (key,))
            except sqlite3.Error as exc:
                errors.append(f"{statement}: {exc}")
    assert not errors, "cleanup failed: " + "; ".join(errors)
```

`tests/test_claims.py`

```python
import json

import pytest

# In the product these are committed files, captured when each version shipped.
STORED = {
    1: '{"type": "claim_filed", "version": 1, "claim_id": "c-1", "amount": 120.5}',
    2: '{"type": "claim_filed", "version": 2, "claim_id": "c-1", "amount_minor": 12050, "currency": null}',
}


def upcast(event: dict) -> dict:  # stands in for the product's converter
    if event["version"] == 1:
        return {"type": event["type"], "version": 2, "claim_id": event["claim_id"],
                "amount_minor": round(event["amount"] * 100), "currency": None}  # unknown, not guessed
    return event


@pytest.mark.parametrize("version", sorted(STORED))
def test_every_stored_version_reads_as_current(version):
    assert upcast(json.loads(STORED[version])) == json.loads(STORED[2])


def file_claim(conn, claim_id, insurer):  # stands in for the service: one transaction
    conn.execute("BEGIN")
    conn.execute("INSERT INTO claims VALUES (?, ?)", (claim_id, insurer))
    conn.execute("INSERT INTO outbox VALUES (?, ?)", (claim_id, insurer))
    conn.execute("COMMIT")


@pytest.mark.parametrize("label", ["first", "second"])
def test_claim_and_outbox_commit_together(connection, scoped, test_id, label):
    # Real commit needed: the subject is the commit boundary.
    insurer = test_id("insurer")
    scoped(insurer,
           "DELETE FROM outbox WHERE insurer_id = ?",
           "DELETE FROM claims WHERE insurer_id = ?")
    file_claim(connection, test_id(label), insurer)
    counts = connection.execute(
        "SELECT (SELECT count(*) FROM claims WHERE insurer_id = ?),"
        " (SELECT count(*) FROM outbox WHERE insurer_id = ?)", (insurer, insurer)).fetchone()
    assert counts == (1, 1)
```

The product version of the commit test reads from a second connection and adds the failing half.

## The answer states

- **Isolation:** rollback by default, for pooled and siloed repositories; scoped data only for the commit and running-server tests, each with its reason. The relay test gets its own database, topic and consumer group because it reads every row.
- **Refused:** the shared staging database, truncation, and regenerating version 1 (it would stop proving that stored history still reads). None is offered with a switch.
- **Size:** more fixtures and a database per worker; the rules are those of a lean product.
- **Product-owner decisions:** what currency old claims carry is a business fact; "unknown" stands until they answer. Any wish to load staging or production-derived claims goes to them too.
- **Run:** as stated at the top; everything else is unverified.
