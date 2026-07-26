# Mocking Philosophy: Classical School, Managed vs. Unmanaged Dependencies

Full grounding for `go-unit-test`'s "Mocking Philosophy" section — *when to mock at all*, not the Go tooling that generates a mock once the decision is made (that is `mock-generation`'s domain; this file never restates it).

---

## Two Schools, and Which One This Repo Uses

Khorikov (*Unit Testing: Principles, Practices, and Patterns*) names two competing philosophies for isolating a test:

- **London (mockist) school** — isolate the *class under test* from *all* of its collaborators. Every dependency, however trivial, is replaced with a mock, and the test verifies the resulting web of interactions.
- **Classical (Detroit/Chicago) school** — isolate the *test case* from other test cases (no shared mutable state), not the class from its collaborators. A "unit" of test is a unit of *observable behaviour*, which may legitimately span several collaborating types exercised together, with only true external dependencies replaced.

**This repo follows the classical school.** A test exercising `ClassifyDataAssetHandler` is free to run the real `DataAsset` Aggregate underneath it — the Aggregate is not an "external dependency," it is the behaviour under test, just one layer down. Only the boundary the application genuinely does not control gets replaced.

This is not a stylistic preference — it is the direct consequence of Khorikov's four pillars (`go-unit-test`'s "Decoupled from Implementation" section) being multiplicative. London-school over-mocking maximizes Fast Feedback and looks like it maximizes Protection Against Regressions (every call is checked), but it minimizes Resistance to Refactoring: any internal restructuring that changes *how* collaborators are called, without changing what a caller observes, still turns the suite red. A zeroed pillar zeroes the product, not just discounts it — so the classical school's willingness to run more real code inside a "unit" test is the pillar-correct choice, not a shortcut.

---

## The Real Question: Managed vs. Unmanaged Dependencies

The classical/London split answers *how much* to isolate; it does not by itself say *what* to mock. Khorikov's sharper, decisive test is the **managed vs. unmanaged dependency** distinction:

| Dependency kind | Definition | Example in this repo | Verify with |
|---|---|---|---|
| **Managed** | Fully controlled by your own application; reachable only through your own code; the outside world never observes it directly | `DataAssetRepository` over Postgres (`go-repository-pattern`) | A state-based **fake** (`mock-generation`'s in-memory `fakeAssetRepo`) in a unit test, or a real instance in an integration test (`go-integration-test`) — **never** a call-count mock |
| **Unmanaged** | Its side effect is observable to something outside your app's control | The outbox relay's publish to Redpanda (`go-event-publisher`), an outbound email/SMTP call, a third-party payment API call | A **mock** that verifies the call happened, with the right arguments — the interaction itself is the behaviour that matters |

**The rule with no exception: only mock unmanaged dependencies.** A managed dependency — your own repository, your own internal service — gets a fake or gets tested for real; asserting `repo.SaveCalls()` has length 1 tests an implementation detail (how the handler happened to call the repository) rather than the actual contract (the asset's new state is retrievable afterward). This is also why `go-repository-pattern` explicitly frames a repository as a **Humble Object**: it is thin enough, and its correctness is entirely in real SQL semantics, that mocking its driver out to unit-test it would be testing nothing — its real test is the integration suite (`go-repository-pattern.contract.sh`) against a real PostgreSQL, not a mocked one.

---

## Mock vs. Stub — Not Interchangeable

- A **mock** verifies that the system under test *called* a dependency in a particular way — it tests an interaction, and its calls are asserted on.
- A **stub** feeds a canned input into the system under test so a scenario can be arranged — its calls are never asserted on.

**Never assert on a stub.** If a double's calls exist only to arrange input and you find yourself wanting to verify them, it is functioning as a mock and the test should say so explicitly (and, per the table above, should only do that for an unmanaged dependency). Asserting on a stub couples the test to an implementation detail for zero behavioural payoff — the same failure mode as over-mocking, arrived at from the opposite direction.

---

## Applying This in Go

`mock-generation` supplies the mechanics once a mock is the right tool: generate from the consumer-defined port with `moq`/`mockgen`, assert compile-time interface compliance, prefer a small hand-written fake for the common state-based case. This file's job ends at the decision — an engineer reading both should leave `mock-generation` knowing *how* to build the double, and this file knowing *whether it should be a double that verifies calls at all*.

```go
// Managed dependency (repository) — a fake, verified by resulting state, never by call count.
repo := &fakeAssetRepo{store: map[uuid.UUID]*domain.DataAsset{}}
err := handler.Handle(ctx, cmd)
require.NoError(t, err)
saved, _ := repo.FindByID(ctx, cmd.AssetID)
require.Equal(t, domain.SensitivityConfidential, saved.Sensitivity()) // state, not "was Save called"

// Unmanaged dependency (outbox → broker publish) — a mock, because the call IS the contract.
publisher := &EventPublisherMock{PublishFunc: func(_ context.Context, e domain.Event) error { return nil }}
relay.drainOnce(ctx)
require.Len(t, publisher.PublishCalls(), 1) // the interaction itself is what's under test
```
