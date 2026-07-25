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
