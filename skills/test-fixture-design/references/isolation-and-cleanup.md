# Isolation and Cleanup

Self-contained. Use for any test that touches a database, a broker or a second process. Your own database is a managed dependency: verify it through its real end state, not through a mock (Khorikov).

## Order of choice

1. **Roll back each test.** The fixture begins a transaction, hands it to the code under test, and rolls it back at the end. The repository must accept something both a pool and a transaction satisfy. If it only accepts a pool, say so: that is a production design change to raise, not a reason to switch isolation quietly.
2. **Savepoint inside the test's transaction**, when the code under test begins and commits its own transaction and can run nested without any change to its production shape. The outer transaction still rolls back. Never restructure production code to suit a test.
3. **Scoped data with real commits**, only when one of these is true, and write which in the test:
   - the behaviour under test is the commit or transaction boundary itself (state and outbox row commit atomically; two writers see each other's committed rows);
   - something outside the test's connection must see the data (a running server handling a request, a relay or consumer, a contract verifier, an end-to-end run).

A savepoint release is not a commit: it proves nothing about what another connection sees.

Resetting the schema or starting a container per test is not an option here: per-test isolation comes from rollback or from scope. Container lifetime belongs to the integration test skills.

## Scoped data

- **Key:** from the tenancy design. Pooled: a tenant ID unique to the test. Schema per tenant: a schema unique to the test. Database per tenant: the throwaway database for that tenant plus the test's row IDs. No tenancy: the test's own aggregate IDs. Undecided design: use the test's own IDs and put the question to the product owner.
- **Unique and repeatable:** derive the key from the test's name, so a failure can be replayed with the same values.
- **Cleanup first:** register it before the first insert.
- **Delete everything owned:** every table written by the seed or by the code under test, children before parents, filtered by the scope. Includes outbox, processed-message and audit tables the code writes. Check by counting rows under the scope after cleanup while writing the fixture.
- **Report failures:** a failed delete fails the test.
- **Global readers:** a relay, scheduler or aggregate query ignores your scope. Give it a filter, or give that test its own schema or database.
- **Assertions** filter by the scope too. "The table has 3 rows" is wrong in a shared database; "this scope has 3 rows" is right.

## Where teardown lives

Register it beside the setup, on the test that owns the resource: `t.Cleanup` (runs in reverse order of registration, after subtests, on failure too) or the code after a pytest `yield`. A `defer` in a helper fires when the helper returns. Package-level teardown in `TestMain` is for the shared container only; it runs too late to protect one test from another's data.

## Brokers and messages

A published message cannot be rolled back. Each test uses a topic and a consumer group of its own (named from the test), waits by polling with a deadline, and removes what the broker lets it remove. Container setup and the polling helper belong to the integration test skills.

## Containers and addresses

- Fixtures take the database address only from the container (or throwaway instance) this run started. An address from the environment, such as `DATABASE_URL`, can point at a real database: set it from the container for any tool that reads it, and refuse any other address.
- Go Testcontainers: register the container's cleanup before checking the start error, because a container can exist after a failed start; pin image tags.

## Layers and who owns the seeding

| Layer | Isolation | Owner of the mechanics |
|---|---|---|
| Unit | None needed; no shared package or module state | `go-unit-test`, `python-unit-test` |
| Integration | Rollback; scoped by exception | `go-integration-test`, `python-integration-test` |
| Contract provider states | Scoped (the verifier is a separate request); IDs taken from the state's name | `go-contract-test` |
| End-to-end | Scoped by run in a throwaway environment | `go-e2e-test`, `python-e2e-test` |

Where a test may only reach a system through its API (an API you cannot query directly), create and remove its data through that API (Winteringham). Where the team owns the database, seed it directly.

## Parallel runs

Rollback isolates concurrent transactions from each other's uncommitted writes. Two tests can still block each other on the same unique key, so give them different IDs. Process-level parallel runners create session fixtures once per worker, so each worker has its own container. A transaction or connection is never shared between parallel tests.

## Order independence

Run the suite in a different order (`go test -shuffle=on`; in Python run the affected files reversed or with the ordering plugin the project already has). A test that passes alone and fails in sequence reads or leaves shared state. Fix the fixture; retries and quarantine follow `test-pyramid`.
