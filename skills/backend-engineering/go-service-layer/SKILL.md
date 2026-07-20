---
name: go-service-layer
description: >
  Teaches how to implement the application layer — the command and query handlers
  that orchestrate use cases (CQRS write/read separation). Covers the handler
  shape, transaction/consistency boundaries, ABAC policy enforcement before
  mutation, idempotency, parallel orchestration with errgroup, and the rule that
  the application layer coordinates but never contains domain rules. Implements
  the enterprise-architect's CQRS design. Used by the backend-engineer during
  Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, cqrs, application-layer, command-handler, query-handler, abac, errgroup]
---

# Go Service Layer (Application Layer)

## Purpose

The application layer expresses use cases: "classify a data asset," "list compliance gaps." Each use case is a handler that orchestrates the domain and infrastructure — load the Aggregate, check the policy, call the domain method, save — but contains **no business rules itself**. Those rules live in the Aggregate. The application layer is thin glue with one job: run the use case correctly, once.

This implements the `cqrs-pattern` from the enterprise-architect: commands (writes) and queries (reads) are separate handlers in separate packages.

---

## Command Handler (Write Side)

One handler per Command, one file, one `Handle` method. Dependencies are the small consumer-defined ports, injected at construction.

```go
// internal/application/commands/classify_data_asset.go
package commands

type ClassifyDataAsset struct {                 // the Command (input DTO)
    DataAssetID  uuid.UUID
    Sensitivity  domain.SensitivityLevel
    ClassifiedBy uuid.UUID
    IdempotencyKey string
}

type ClassifyDataAssetHandler struct {
    repo   domain.DataAssetRepository
    policy domain.AccessPolicy
    idem   IdempotencyStore
    clock  func() time.Time          // injected for deterministic tests
}

func NewClassifyDataAssetHandler(r domain.DataAssetRepository, p domain.AccessPolicy, i IdempotencyStore) *ClassifyDataAssetHandler {
    return &ClassifyDataAssetHandler{repo: r, policy: p, idem: i, clock: time.Now}
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    // 1. Idempotency: a retried command must not classify twice.
    if done, err := h.idem.Seen(ctx, cmd.IdempotencyKey); err != nil {
        return fmt.Errorf("idempotency check: %w", err)
    } else if done {
        return nil // already applied — return success, do nothing
    }

    // 2. Load the Aggregate.
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return err // already a wrapped domain error from the repo
    }

    // 3. Authorise BEFORE mutating (ABAC — enforced here, in the application layer).
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return ErrUnauthenticated
    }
    res := domain.Resource{Type: "data-asset", ID: asset.ID(), TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, res, domain.ActionClassify); err != nil {
        return err // ErrForbidden — do not reveal why (see access-control-model)
    }

    // 4. Execute the domain rule (the business logic lives in the Aggregate).
    if err := asset.Classify(cmd.Sensitivity, cmd.ClassifiedBy, h.clock()); err != nil {
        return err
    }

    // 5. Persist (state + events atomically — see go-repository-pattern).
    if err := h.repo.Save(ctx, asset); err != nil {
        return err
    }
    return h.idem.Record(ctx, cmd.IdempotencyKey)
}
```

The five steps are always in this order: **idempotency → load → authorise → domain call → save**. Authorisation precedes mutation; persistence is last.

Note the check-then-record shape leaves a small window where two concurrent retries both pass `Seen`. That is acceptable **only** because the repository's compare-and-swap on `version` is the backstop — the second save fails with `ErrConcurrentModification`. Where even that is too weak (e.g., non-versioned side effects), record the idempotency key inside the same transaction as the save, exactly as the consumer does with `processed_events` (see `go-event-consumer`).

---

## Query Handler (Read Side)

Queries never load Aggregates and never go through the domain. They read projections / Read Models directly (see `read-model-design`) and return read DTOs. This is the CQRS separation: the read side is optimised for reading.

```go
// internal/application/queries/list_data_assets.go
package queries

type ListDataAssets struct {
    Sensitivity *domain.SensitivityLevel // optional filter
    Page        Pagination
}

type ListDataAssetsHandler struct {
    view DataAssetView // a read-model port; reads the *_view table, not data_assets
}

func (h *ListDataAssetsHandler) Handle(ctx context.Context, q ListDataAssets) (Page[DataAssetDTO], error) {
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return Page[DataAssetDTO]{}, ErrUnauthenticated
    }
    // Read queries still enforce the tenant boundary and read permission.
    if !sub.HasPermission("data-assets:read") {
        return Page[DataAssetDTO]{}, ErrForbidden
    }
    return h.view.List(ctx, sub.TenantID, q.Sensitivity, q.Page)
}
```

---

## Consistency Boundary

A command handler changes **exactly one Aggregate per transaction** (the aggregate-design rule). If a use case appears to need two Aggregates changed atomically, that is a signal to either (a) reconsider the Aggregate boundaries, or (b) use eventual consistency via Domain Events / a Saga (see `event-driven-patterns`). The application layer never opens a transaction spanning two Aggregates.

---

## Parallel Orchestration with errgroup

When a query must gather independent data from several sources, fan out with `errgroup` so the slowest source bounds latency — not the sum. Every goroutine uses the group context, so a failure or client cancellation stops all of them.

```go
func (h *DashboardHandler) Handle(ctx context.Context, q Dashboard) (DashboardDTO, error) {
    g, gctx := errgroup.WithContext(ctx)
    var assets AssetSummary
    var gaps   GapSummary

    g.Go(func() error {
        var err error
        assets, err = h.assetView.Summary(gctx, q.TenantID)
        return err
    })
    g.Go(func() error {
        var err error
        gaps, err = h.gapView.Summary(gctx, q.TenantID)
        return err
    })
    if err := g.Wait(); err != nil {
        return DashboardDTO{}, fmt.Errorf("loading dashboard: %w", err)
    }
    return DashboardDTO{Assets: assets, Gaps: gaps}, nil
}
```

Each goroutine writes to its own variable (no shared mutable state, no race); `g.Wait()` is the join point. (Patterns: `go-concurrency-patterns`.)

---

## Rules

- **No business logic in handlers.** Decisions live in the Aggregate; handlers orchestrate.
- **No HTTP/SQL/broker types.** Handlers take Commands/Queries and ports — never `*http.Request`, never pgx.
- **Authorise before mutate.** Policy check precedes the domain call, always.
- **Idempotent commands.** Every state-changing command honours an idempotency key.
- **`ctx` first, propagated everywhere.** Carries deadline, cancellation, tenant, and trace span.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Thin handlers | Orchestration only; no business rules | Domain logic implemented in the handler |
| Write/read separation | Commands mutate Aggregates; queries read projections | Queries loading Aggregates; commands reading views |
| Authorise before mutate | Policy evaluated before the domain call | Mutation then check, or no check |
| One Aggregate per tx | Each command touches one Aggregate | Transactions spanning multiple Aggregates |
| Idempotency | State-changing commands honour an idempotency key | Retries causing duplicate effects |
| Framework-free | No HTTP/SQL/broker types in the application layer | `*http.Request` or pgx leaking in |

---

## Anti-Patterns

- **The "service" that is really the domain** — sensitivity-downgrade rules, invariant checks, or state math written in the handler. The moment a rule lives here, the Aggregate can no longer guarantee it.
- **Authorise-after-mutate** — calling `asset.Classify` and only then evaluating policy means a forbidden caller already changed in-memory state (and one missed early return away from persisting it).
- **Queries through the write model** — loading Aggregates to answer a list screen drags invariant machinery and N+1 loads into a path that needed one `SELECT` from a Read Model.
- **Transactions spanning Aggregates** — "just this once" atomically updating two Aggregates dissolves the consistency boundary; use Domain Events and eventual consistency instead.
- **A god `Service` struct** — `DataAssetService` with twelve methods and eight dependencies. One use case, one handler, one file; dependencies stay honest.
- **Returning `nil` on unauthenticated/unauthorised** — silently succeeding on a failed policy check is a security defect, not graceful degradation. `ErrUnauthenticated`/`ErrForbidden`, mapped at the edge.
- **Shared mutable state across errgroup goroutines** — two goroutines appending to one slice or map in a fan-out query is a race; one destination variable per goroutine.

---

## Output Format

Produces Go source plus test-first unit tests (handlers tested with mocked ports):

```
internal/application/commands/classify_data_asset.go
internal/application/commands/classify_data_asset_test.go   (written first; mocked ports)
internal/application/queries/list_data_assets.go
internal/application/queries/list_data_assets_test.go
```
