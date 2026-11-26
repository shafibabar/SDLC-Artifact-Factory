# Fakes, Mocks and What a Test Is Worth

Self-contained. Use when deciding what to replace in a Python unit test, or how to judge a test. School: Khorikov's classical one; fakes behind ports from Percival and Gregory, *Architecture Patterns with Python*. `mock-generation` owns the shared rules; its generator rule is Go only.

## What to replace

Isolate each test from other tests; run the real domain code; replace only what lies outside the application. Double only a port the consumer defines (a `typing.Protocol`), never `asyncpg`, `aiokafka` or a vendor client.

| Dependency | In a unit test | Assert |
|---|---|---|
| Own database, repository, Unit of Work, outbox table (managed) | Fake | The state read back; never its calls |
| Publish by the outbox relay, email, text, third-party API (unmanaged) | Mock of your port | The awaited call, its arguments and count |
| A call that only feeds data in (stub) | Canned return | Never its calls |
| A command handler in a product with a Transactional Outbox | Fake | The outbox row saved with the state change; mock the publisher only in the relay's test |

Refuse by name and give the replacement: "`repo.save.assert_called_once()` is removed: the repository is ours, so the test reads the saved state."

## Fakes

`python-repository-pattern` owns `FakeRepository` and `python-service-layer` owns `FakeUnitOfWork`, both in `tests/fakes.py`. Use those; do not write a second one. A fake is only useful if it can fail the test:

- it hands out copies, so an unsaved change is not visible;
- it publishes writes only on commit and rolls back otherwise, so a missing `commit()` leaves no trace;
- it enforces what the real adapter enforces (version check, tenant filter).

A fake that stores the caller's object makes a state assertion pass with no save at all. Matching method names proves nothing about behaviour: run one behaviour suite against the fake and the real adapter (`mock-generation`).

## Mocking an unmanaged port

```python
mailer = create_autospec(Mailer, instance=True)   # Mailer is a Protocol; async methods become AsyncMock
...
mailer.send.assert_awaited_once_with("a@example.test", "Ticket 7 closed")
mailer.send.assert_not_awaited()                  # on a refused path
```

Autospec rejects a call with the wrong arguments (seen). `create_autospec` is in the standard library. The `pytest-mock` plugin's `mocker` fixture offers the same with automatic undo (not required, not run here); either way patch a boundary your code receives, not a function inside it.

## Four pillars

Judge a test on protection against regressions, resistance to refactoring, fast feedback and maintainability. They multiply: a zero on one makes the test poor however well it does on the others (Khorikov). A private-field or call-count assertion breaks on a refactor that preserved behaviour. Python lets a test read `_field`; the discipline, not the language, forbids it.

## Which code, which tests

| Quadrant | Domain complexity | Collaborators | Where its behaviour is proven |
|---|---|---|---|
| 1 Domain logic | High | Few | Thorough parametrized unit tests: most of the effort |
| 2 Overcomplicated | High | Many | Split first: logic to quadrant 1, wiring to quadrant 3 (Humble Object) |
| 3 Controllers (use cases, handlers) | Low | Many | One test per way a use case ends, against fakes; adapters and routes in integration tests |
| 4 Trivial | Low | Few | Exercised through the behaviour that uses it, else a small test of its own or a listed exclusion |

The quadrant decides which test covers the code, never whether it is covered: no per-layer floor replaces 100% of lines and branches.
