# Provider State Setup Standard

Self-contained detail for the fixture-setup mechanism a Pact provider verification needs — read after `pact-consumer-driven-workflow.md`'s provider-side section names `StateHandlers`.

## What a Provider State Is

A provider's real behavior depends on prior state: "a classified data asset with id abc123 exists" is not something a fresh, empty database satisfies. Each interaction recorded in a pact file carries the exact string passed to the consumer test's `Given(...)` (`pact-consumer-driven-workflow.md`) — a **Provider State**: a named precondition the provider side maps to setup code, run before the Verifier fires that specific interaction's request. Without this, verification flakes against whatever data happens to already exist, or fails outright against an empty database.

## StateHandlers: One Entry Per Named State

```go
// internal/test/contract/provider/state_handlers.go
var providerStateHandlers = map[string]models.StateHandler{
    "a classified data asset with id abc123 exists": func(setup bool, s models.ProviderState) (models.ProviderStateResponse, error) {
        if setup {
            seedDataAsset(t, testPool, "abc123", "Restricted")
        }
        // no explicit else: teardown happens via t.Cleanup registered inside seedDataAsset
        return nil, nil
    },
    "no data asset with id missing-999 exists": func(setup bool, s models.ProviderState) (models.ProviderStateResponse, error) {
        // deliberately a no-op: absence is the fixture
        return nil, nil
    },
}
```

Rules:

- **The map key is the exact `Given(...)` string** the consumer test wrote — a typo on either side silently produces "state not found" rather than a useful failure; treat these strings as part of the wire contract, not free text.
- **`setup == true` runs before the interaction's request; `setup == false` (when Pact calls the handler a second time) is teardown** — most handlers only need the `setup` branch when cleanup is delegated to `t.Cleanup` inside the seed helper itself, consistent with `go-integration-test`'s hermetic-seeding standard (every test cleans up exactly what it created).
- **One state, one handler.** Do not build a generic handler that branches on substring matching against the state string — an unrecognized or misspelled state should fail loudly (Pact's own "no handler registered" error), not silently no-op.

## Why This Needs Real Commits, Not Transaction Rollback

`go-integration-test`'s default test isolation is transaction rollback per test (`references/test-isolation-standard.md` there) — a test wraps its work in a `pool.Begin(ctx)` transaction never committed. Provider State setup **cannot** use that default: the Pact Verifier issues its HTTP request as a real, separate call against the provider's real running server, in its own goroutine/process — there is no shared transaction for that request's handler to see uncommitted rows in. This is a direct instance of `go-integration-test`'s stated real-commit exception ("a test whose subject is commit/transaction-boundary behavior itself... cannot use an uncommitted wrapper") extended to provider verification generally: fixture data must actually be visible to a request the test itself did not issue.

Use the same tenant-scoped-commit pattern `go-integration-test` uses for its own real-commit exception: seed through a `freshTenant(t, pool)`-scoped id, and register `t.Cleanup` to delete only that tenant's rows after the verifier run completes — never a global schema reset between interactions, which would make provider verification the slowest, flakiest job in either pipeline.

## Ordering and Isolation Across Interactions

A single `VerifyProvider` run replays every interaction from every applicable pact file in sequence. Two interactions that use the same named state must produce identical results independent of run order — do not let one interaction's setup leak into fixture state a later, unrelated interaction depends on. Scope every seed to the specific ids the `Given(...)` string names (`abc123`, not "a data asset"), so two interactions naming two different ids never collide even when both run in the same provider-verification pass.
