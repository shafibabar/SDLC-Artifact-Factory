# Lean: Community Tool Library (Python, one service, single tenant)

Run: the two Python files below passed (3 tests, pytest 9.2.0, Python 3.14, SQLite), including with the test order reversed. This small product's database is SQLite.

## Input

> "Our loan tests share a seeded `drill-1` row and wipe the tables afterwards. They fail when run in a different order. It's a tiny app, so keep it simple."

Rule under test: a tool already on loan cannot be lent again.

## Output

`tests/conftest.py`

```python
import sqlite3

import pytest

SCHEMA = """
CREATE TABLE tools (id TEXT PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE loans (tool_id TEXT PRIMARY KEY REFERENCES tools(id), member TEXT NOT NULL);
"""


@pytest.fixture(scope="session")
def connection(tmp_path_factory):
    path = tmp_path_factory.mktemp("db") / "library.sqlite"  # throwaway, made by this run
    conn = sqlite3.connect(path, isolation_level=None)
    conn.executescript(SCHEMA)  # the product runs its real migrations here
    yield conn
    conn.close()


@pytest.fixture
def db(connection):
    connection.execute("BEGIN")
    try:
        yield connection
    finally:
        connection.execute("ROLLBACK")


@pytest.fixture
def make_tool(db):
    def make(tool_id: str = "tool-1", name: str = "Cordless drill") -> str:
        db.execute("INSERT INTO tools (id, name) VALUES (?, ?)", (tool_id, name))
        return tool_id
    return make
```

`tests/test_loans.py`

```python
import sqlite3

import pytest


def lend(db, tool_id, member):  # stands in for the product's repository
    db.execute("INSERT INTO loans (tool_id, member) VALUES (?, ?)", (tool_id, member))


def test_lend_records_the_borrower(db, make_tool):
    tool = make_tool()
    lend(db, tool, "asha")
    assert db.execute("SELECT member FROM loans WHERE tool_id = ?", (tool,)).fetchone() == ("asha",)


def test_tool_on_loan_cannot_be_lent_again(db, make_tool):
    tool = make_tool()
    lend(db, tool, "asha")
    with pytest.raises(sqlite3.IntegrityError):
        lend(db, tool, "ben")


def test_each_test_starts_empty(db):
    assert db.execute("SELECT count(*) FROM tools").fetchone() == (0,)
```

## The answer states

- **Isolation:** each test rolls back. No behaviour here needs a real commit.
- **Replaced:** the shared `drill-1` seed row (tests depended on state they did not create) by a factory fixture; the table wipe by rollback (a wipe destroys rows of any test running alongside, and is skipped or half done when something fails).
- **Size:** lean needs two small fixtures and no builder classes or scoped helper. The rules are the same as for a large product.
- **No tenant column:** the product has one tenant.
- **Product-owner decisions:** none.
- **Run:** as stated at the top; the real product's repository was not run.
