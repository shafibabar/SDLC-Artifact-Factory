# Go Mock Implementation Guide

Reference material for `mock-generation`. Self-contained — readable without the
parent SKILL.md in context. Covers all three generation tools (mockery, gomock,
moq), compile-time compliance, and CI freshness.

---

## mockery (vektra/mockery) — Default Tool

`mockery` generates typed mock structs for entire interface packages from a
single `.mockery.yaml` configuration file. It is this repo's default for
consumer-defined ports because a single YAML config generates all mocks in one
`go generate ./...` pass, and its output is readable without reference to
the generation command.

### .mockery.yaml Configuration

Place `.mockery.yaml` at the repository root:

```yaml
# .mockery.yaml
with-expecter: false          # don't generate EXPECT() builder; use direct func assignment
all: false                    # do not auto-discover all interfaces; list packages explicitly
dir: "{{.InterfaceDir}}"      # keep generated file beside the interface by default
outpkg: "{{.PackageName}}"
filename: "{{.InterfaceName|lower}}_mock.go"
packages:
  github.com/your-org/your-service/internal/domain:
    interfaces:
      DataAssetRepository:
      EventPublisher:
  github.com/your-org/your-service/internal/application:
    interfaces:
      ClassificationService:
```

Run once to generate (or regenerate after an interface change):

```bash
go generate ./...
```

Add to the project Makefile as `make generate` and invoke it in CI before the
test step.

### Generated Output and Test Usage

`mockery` generates a struct with one `Func` field per interface method. Tests
configure the double by assigning the field:

```go
// Arrange:
publisher := &EventPublisherMock{
    PublishFunc: func(_ context.Context, e domain.Event) error { return nil },
}
// Act: pass the double into the component under test.
relay := outbox.NewRelay(publisher)
err := relay.DrainOnce(ctx)
require.NoError(t, err)

// Assert the unmanaged interaction (outbox publish is an unmanaged dependency):
require.Len(t, publisher.PublishCalls(), 1)
require.Equal(t, domain.EventTypeAssetClassified, publisher.PublishCalls()[0].E.Type())
```

For managed dependencies (repositories, in-process services), always use a
hand-written fake instead — see `references/test-double-taxonomy.md`.

---

## gomock (uber-go/mock; mockgen) — Rich Expectation DSL

Use `gomock` when a test needs upfront expectation declarations with exact call
counts, argument matchers, and return-value chaining. The `mockgen` CLI generates
the mock struct from an interface; the `gomock.Controller` manages expectation
lifecycle.

### Installation and Generation

```bash
go install go.uber.org/mock/mockgen@latest

# Add beside the interface file (reflect mode — no AST parsing needed):
//go:generate mockgen -destination=mocks/event_publisher_mock.go \
//   -package=mocks github.com/your-org/your-service/internal/domain EventPublisher
```

Run `go generate ./...` to regenerate.

### Expectation DSL Usage

```go
func TestRelay_DrainOnce_PublishesExactlyOne(t *testing.T) {
    ctrl := gomock.NewController(t)

    publisher := mockdomain.NewMockEventPublisher(ctrl)
    // Declare expectations BEFORE acting:
    publisher.EXPECT().
        Publish(gomock.Any(), gomock.AssignableToTypeOf(domain.Event{})).
        Return(nil).
        Times(1)

    relay := outbox.NewRelay(publisher)
    err := relay.DrainOnce(context.Background())
    require.NoError(t, err)
    // gomock.Controller asserts all expectations at t.Cleanup time.
}
```

`gomock.Controller` automatically calls `ctrl.Finish()` at test end (via
`t.Cleanup` in Go 1.14+), so explicit `defer ctrl.Finish()` is dead weight in
new code.

---

## moq (matryer/moq) — Minimal Struct-of-Funcs Output

Use `moq` for small, one-off interfaces where the generated code readability
matters more than a rich expectation DSL. Its output is a plain struct with one
`Func` field per method — essentially the same shape `mockery` produces without
the YAML config overhead.

### Generation

```bash
go install github.com/matryer/moq@latest

# Add a //go:generate directive beside the interface:
//go:generate moq -out dataasset_repo_moq.go . DataAssetRepository
```

### Usage

```go
repo := &DataAssetRepositoryMock{
    FindByIDFunc: func(_ context.Context, id uuid.UUID) (*domain.DataAsset, error) {
        return sampleAsset, nil
    },
    SaveFunc: func(_ context.Context, a *domain.DataAsset) error { return nil },
}
// After exercising:
require.Len(t, repo.SaveCalls(), 1)
require.Equal(t, sampleAsset.ID(), repo.SaveCalls()[0].A.ID())
```

Note: for the managed `DataAssetRepository` this usage still violates the
managed/unmanaged rule — use a hand-written fake for state-based verification,
not interaction-counting via `SaveCalls()`. The moq output pattern is appropriate
here only if the dependency is unmanaged or if the test genuinely needs to
verify the call as a contract.

---

## Hand-Written Fake — Full Pattern

For managed dependencies (repositories, in-process services), a hand-written
fake is almost always the right tool. The complete pattern for the primary repo
interface in this codebase:

```go
// internal/test/fakes/asset_repo.go

package fakes

import (
    "context"
    "sync"

    "github.com/google/uuid"
    "github.com/your-org/your-service/internal/domain"
)

// FakeAssetRepo is an in-memory DataAssetRepository for unit tests.
// Verify outcomes by calling FindByID after the code under test runs;
// never assert on call counts — that is an implementation detail.
type FakeAssetRepo struct {
    mu    sync.Mutex
    store map[uuid.UUID]*domain.DataAsset
}

func NewFakeAssetRepo() *FakeAssetRepo {
    return &FakeAssetRepo{store: make(map[uuid.UUID]*domain.DataAsset)}
}

func (f *FakeAssetRepo) FindByID(_ context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    f.mu.Lock(); defer f.mu.Unlock()
    a, ok := f.store[id]
    if !ok {
        return nil, domain.ErrNotFound
    }
    return a, nil
}

func (f *FakeAssetRepo) Save(_ context.Context, a *domain.DataAsset) error {
    f.mu.Lock(); defer f.mu.Unlock()
    f.store[a.ID()] = a
    return nil
}

func (f *FakeAssetRepo) ListByTenant(_ context.Context, tenantID uuid.UUID) ([]*domain.DataAsset, error) {
    f.mu.Lock(); defer f.mu.Unlock()
    var result []*domain.DataAsset
    for _, a := range f.store {
        if a.TenantID() == tenantID {
            result = append(result, a)
        }
    }
    return result, nil
}

// Compile-time check: fails to compile the moment the interface adds a method
// without a corresponding implementation in this fake.
var _ domain.DataAssetRepository = (*FakeAssetRepo)(nil)
```

**Test usage (state-based, not interaction-based):**

```go
func TestClassifyDataAsset_PersistsNewSensitivity(t *testing.T) {
    repo := fakes.NewFakeAssetRepo()
    repo.Save(ctx, domain.NewDataAsset(assetID, tenantID, "report.pdf"))

    svc := application.NewClassificationService(repo)
    err := svc.Classify(ctx, assetID, domain.SensitivityRestricted)
    require.NoError(t, err)

    // Assert outcome, not calls:
    saved, err := repo.FindByID(ctx, assetID)
    require.NoError(t, err)
    require.Equal(t, domain.SensitivityRestricted, saved.Sensitivity())
}
```

---

## CI Freshness Check

A stale generated mock (interface changed, mock not regenerated) is a silent
drift bug. Gate on this in CI:

```makefile
# In Makefile:
generate:
    go generate ./...

check-generate: generate
    git diff --exit-code -- '*.mock.go' '*.moq.go'

ci: check-generate test lint
```

In GitHub Actions:

```yaml
- name: Verify generated mocks are current
  run: |
    go generate ./...
    git diff --exit-code
```

A nonzero exit (generated files differ from committed files) fails the build
and tells the author to run `go generate ./...` and commit the result.
