# Keeping Fakes Honest

Self-contained. Use when writing or reviewing a hand-written Go fake for a managed port. A fake is a working in-memory implementation asserted on by state (Percival and Gregory; Khorikov).

## Why it can lie

A compile-time assertion proves the method set, nothing else. A fake can accept a duplicate the database rejects, return another tenant's row, or keep a change that was never saved. Tests then pass against behaviour the product does not have.

## Rules for the fake

| Check | Do |
|---|---|
| Signatures | `var _ application.OrderRepository = (*OrderRepo)(nil)` beside the type |
| Copies | Store and return copies, including slices and maps inside the value |
| Same errors | Return the port's domain errors (`ErrNotFound`, `ErrDuplicate`) in the cases the real adapter does |
| Tenant scope | Key by whatever the tenancy design scopes by; never invent a tenant column; an undecided design goes to the product owner |
| Order and filters | Match what the port promises; do not rely on map order |
| Concurrency | Guard state with a mutex when the code under test runs goroutines |
| Faults | An exported field the test sets (`SaveErr`). No branching on inputs to guess which test is running |
| Scope | One fake per port, a fresh instance per test; no package-level state |

## One behaviour suite, two implementations

Write the port's promises once, as a function that takes a constructor. Put it in `internal/test/portsuite/`.

- A unit test runs it against the fake.
- An integration test runs it against the real adapter on the throwaway database, with `test-fixture-design`'s isolation (roll back by default; scoped data only when a real commit is needed, with the reason in the test).

Every promise a unit test relies on belongs in the suite: found, not found, duplicate, update, isolation between scopes, saved-copy independence. When the real adapter fails a case the fake passes, one of them is wrong: decide which behaviour the port promises, then fix that side. Behaviour only a real database has (constraints under concurrent writers, commit visibility) stays in the integration test and is not imitated in the fake.

## Coverage

The fake and the suite are hand-written, so they are counted by the 100% gate. The suite exercises the fake's methods; test each fault field. Use `require` assertions in support code so no failure-only block is left unexecuted. Anything still uncovered is listed with a reason for the product owner's approval.
