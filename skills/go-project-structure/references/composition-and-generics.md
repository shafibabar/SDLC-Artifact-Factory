# Composition Over Inheritance, and Where Generics Belong

Full worked material referenced from `SKILL.md`'s "Composition Over Inheritance" and "Where Generics Belong" sections.

---

## Composition Over Inheritance

Go has no inheritance. Reuse is by **embedding** and **small focused types**, not type hierarchies.

```go
// Embed to compose behaviour, not to "extend a base class"
type instrumentedRepo struct {
    domain.DataAssetRepository           // embedded interface — decorator pattern
    tracer trace.Tracer
}

func (r instrumentedRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    ctx, span := r.tracer.Start(ctx, "repo.FindByID")
    defer span.End()
    return r.DataAssetRepository.FindByID(ctx, id) // delegate to the embedded impl
}
```

This is the decorator pattern via interface embedding: `instrumentedRepo` embeds the `domain.DataAssetRepository` interface (not a concrete type), gets every method promoted for free, and overrides only the one it wants to instrument. Callers holding a `domain.DataAssetRepository` cannot tell the difference — structural typing again.

---

## Where Generics Belong

Generics (`[T any]`) eliminate duplication in **data-agnostic** containers and transformations — never to make the domain abstract. Use them for:

- Reusable result/pagination wrappers: `Page[T any]`, `Result[T any]`
- Type-safe collection helpers: `Map[T,U any](in []T, f func(T) U) []U`
- Generic worker-pool/pipeline plumbing (see `go-concurrency-patterns`)

Do **not** use generics to build a `Repository[T any]` god-interface — that re-creates the weak, wide abstraction the minimalist-interface rule forbids. Each Aggregate gets its own small repository port.

---

## Where This Code Lives

Data-agnostic generic plumbing (a `Page[T]`, a `fanIn[T any]`, a generic worker pool) belongs in `internal/pkg/<name>/` — never in `internal/domain`, which imports nothing beyond stdlib/uuid/time and has no reason to depend on generic collection helpers it doesn't itself define. `internal/pkg/` is a narrow, deliberate exception to "no shared `pkg/`": it never crosses a *service* boundary (Go's toolchain already makes `internal/` unimportable outside this module), and it carries zero domain knowledge — the moment a file here would need to import `internal/domain`, it no longer belongs in `internal/pkg/`. Full placement rules and the distinction from the forbidden cross-service "fat `pkg/`" anti-pattern: `references/package-layout-standard.md`.
