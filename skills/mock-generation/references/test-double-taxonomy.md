# Test Double Taxonomy

Reference material for `mock-generation`. Self-contained — readable without the
parent SKILL.md in context. Covers the complete five-type taxonomy, the managed
vs. unmanaged dependency decision, and the Classical vs. London school choice.

---

## The Five Types: Dummy, Stub, Spy, Mock, Fake

The five test double types — from Gerard Meszaros's *xUnit Test Patterns* and
extended by Khorikov's *Unit Testing: Principles, Practices, and Patterns* — are
not interchangeable. Each type has a precise role:

**Dummy** — passed to satisfy a method signature but never actually used by the
test. A `context.Context` in a unit test that only exercises synchronous domain
logic is a dummy: it must be there to compile, but the test does not care what
it contains. Use `context.Background()`.

```go
// Dummy: required by the interface signature; this test doesn't exercise
// any context-derived behaviour.
asset, err := service.Classify(context.Background(), assetID, SensitivityRestricted)
```

**Stub** — returns canned, preconfigured values without any internal logic.
A stub exists so the code under test gets a specific input to proceed; its
calls are never asserted on. The test verifies the *result the SUT produces*,
not how many times the stub was called.

```go
// Stub: returns a known asset so the classification logic can run.
type stubAssetRepo struct{ asset *domain.DataAsset }
func (s *stubAssetRepo) FindByID(_ context.Context, _ uuid.UUID) (*domain.DataAsset, error) {
    return s.asset, nil
}
func (s *stubAssetRepo) Save(_ context.Context, _ *domain.DataAsset) error { return nil }
```

**Spy** — records the calls it receives, then optionally forwards them. A spy is
useful when you want to observe that a call happened *after the fact* without
declaring the expectation upfront (which is what a mock does). In Go, a simple
spy is a hand-written struct with call-count fields.

```go
// Spy: records publish calls; the test reads spy.calls afterward.
type spyPublisher struct{ calls []domain.Event }
func (s *spyPublisher) Publish(_ context.Context, e domain.Event) error {
    s.calls = append(s.calls, e)
    return nil
}
```

**Mock** — declares expected calls upfront and fails the test if the interaction
does not occur as declared. A mock is an *expectation device*: it tests that
the system under test called a dependency in a particular way. Use only when
the interaction itself IS the behaviour under test (an unmanaged dependency
such as an outbox publish or a third-party API call).

```go
// Mock (via mockery-generated struct, configured per test):
publisher := &EventPublisherMock{
    PublishFunc: func(_ context.Context, e domain.Event) error { return nil },
}
relay.DrainOnce(ctx)
// Assert the interaction — the call IS the observable side effect:
require.Len(t, publisher.PublishCalls(), 1)
require.Equal(t, domain.EventAssetClassified, publisher.PublishCalls()[0].E.Type())
```

**Fake** — a working, lightweight alternative implementation. A fake has real
internal logic (it actually stores items in a map, it actually counts calls) but
avoids the real dependency's weight (no database, no network). For managed
dependencies, a fake is almost always the right tool: the test verifies the
*state that results*, not the calls that produced it.

```go
// Fake: fully functional in-memory repository — verifies outcome, not calls.
type fakeAssetRepo struct {
    mu    sync.Mutex
    store map[uuid.UUID]*domain.DataAsset
}
func (f *fakeAssetRepo) FindByID(_ context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    f.mu.Lock(); defer f.mu.Unlock()
    a, ok := f.store[id]
    if !ok { return nil, domain.ErrNotFound }
    return a, nil
}
func (f *fakeAssetRepo) Save(_ context.Context, a *domain.DataAsset) error {
    f.mu.Lock(); defer f.mu.Unlock()
    f.store[a.ID()] = a
    return nil
}

// Compile-time interface compliance — fails to compile if the interface changes:
var _ domain.DataAssetRepository = (*fakeAssetRepo)(nil)
```

The fake's value is that a test using it asserts on *what data ended up in the
repo* after the code ran — which is the actual contract — rather than on whether
Save was called a specific number of times (an implementation detail).

---

## Managed vs. Unmanaged: The Core Decision

Before choosing a double type, classify the dependency on one axis — *is its
side effect observable outside your application's control?*

| Kind | Definition | Examples in this repo | Verify with |
|---|---|---|---|
| **Managed** | Fully owned by your app; the outside world never observes it directly | `DataAssetRepository` (Postgres via `go-repository-pattern`), an in-process cache, your own domain service | A state-based **fake** in a unit test; or a real Testcontainers instance in an integration test (`go-integration-test`) — **never** a call-count mock |
| **Unmanaged** | Its side effect is observable to something outside your app's control | The outbox relay publishing to Redpanda (`go-event-publisher`), an outbound SMTP call, a third-party classification API | A **mock** that verifies the call happened with the right arguments — the interaction IS the observable behaviour |

**The rule with no exception: only mock unmanaged dependencies.** A managed
dependency — your own repository, your own internal service — gets a fake or
gets tested for real. Asserting `repo.SaveCalls()` has length 1 tests an
implementation detail (how the handler happened to call the repository) rather
than the actual contract (the asset's new state is retrievable afterward). This
is Khorikov's *Unit Testing: Principles, Practices, and Patterns* classical-school
position applied concretely.

**Never assert on a stub.** If a double's calls exist only to arrange input and
you find yourself wanting to verify them, it is functioning as a mock — and
should only do that for an unmanaged dependency. Asserting on a stub couples
the test to an implementation detail for zero behavioural payoff.

---

## Classical School vs. London (Mockist) School

Two named schools govern *how much* to isolate a unit test:

**London (mockist) school** — isolate the *class under test* from every
collaborator. Every dependency, however internal, is replaced with a mock, and
the test verifies the resulting web of interactions. Consequence: a pure
refactor that preserves external behaviour but changes how internal collaborators
are invoked still turns the test suite red. This is Khorikov's Resistance to
Refactoring pillar zeroed out.

**Classical (Detroit/Chicago) school** — isolate the *test case* from other test
cases (no shared mutable state), not the class from its collaborators. A "unit"
of test is a unit of *observable behaviour*, which may legitimately span several
collaborating types exercised together, with only true external (unmanaged)
dependencies replaced.

**This repo follows the Classical school.** A test exercising
`ClassifyDataAssetHandler` is free to run the real `DataAsset` Aggregate
underneath it — the Aggregate is not an "external dependency," it is the
behaviour under test, one layer down. Only the outbox publish (unmanaged) gets
replaced with a mock. This choice is a direct consequence of the four pillars
being multiplicative, not additive: London-school over-mocking maximizes Fast
Feedback while zeroing out Resistance to Refactoring, and a zeroed pillar zeroes
the product.

See `go-unit-test`'s `references/mocking-philosophy.md` for the full four-pillars
rationale — this file is the *what* (taxonomy + school decision); that file is
the *why* (the pillar cost model).
