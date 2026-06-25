---
name: typescript-types
description: >
  Teaches enterprise-grade TypeScript type modeling — discriminated unions for
  state and domain variants, template literal types, advanced utility types
  (Pick/Omit/ReturnType/Record), readonly and mapped types for compile-time
  immutability, exhaustiveness checking with never, and the unknown-over-any rule
  with narrow type guards for untrusted runtime data. Sound types make whole
  classes of UI bugs unrepresentable. Used by the frontend-engineer during Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, typescript, types, discriminated-union, immutability, exhaustiveness]
---

# TypeScript Types

## Purpose

Types are the frontend's first line of defence. A precise type model makes illegal states unrepresentable — a component literally cannot be given a contradictory combination of props, and a network shape cannot be used before it is validated. The compiler catches the bug before the browser ever runs. This skill is the type standard every other frontend skill follows.

The governing rule, from the blueprint: **avoid `any` at all costs.** `any` switches off the compiler exactly where you most need it. Use `unknown` plus a narrow type guard when runtime data is unpredictable.

---

## Discriminated Unions — Model State by Its Shape

A discriminated union encodes "these fields only exist together" so impossible combinations cannot be constructed. This is the single most valuable pattern for UI state.

```ts
// A remote resource is EXACTLY one of these — never "loading AND has data AND has error".
type RemoteData<T> =
  | { readonly status: "idle" }
  | { readonly status: "loading" }
  | { readonly status: "success"; readonly data: T }
  | { readonly status: "error"; readonly error: AppError };

// The compiler forces handling every case and narrows the type inside each branch:
function render(state: RemoteData<DataAsset[]>) {
  switch (state.status) {
    case "idle":    return <Empty />;
    case "loading": return <Skeleton />;
    case "success": return <Table rows={state.data} />; // state.data exists ONLY here
    case "error":   return <ErrorBanner error={state.error} />; // state.error exists ONLY here
  }
}
```

Model domain variants the same way — e.g., a `DataSource` that is `{ kind: "google-drive"; folderId: string } | { kind: "s3"; bucket: string }`, so S3-only fields can't be accessed on a Drive source.

---

## Exhaustiveness Checking with `never`

When a new variant is added to a union, every `switch` over it should fail to compile until it's handled. The `never` type makes that happen — it is the compile-time guarantee that you didn't forget a case.

```ts
function assertNever(x: never): never {
  throw new Error(`unhandled variant: ${JSON.stringify(x)}`);
}

function label(level: SensitivityLevel): string {
  switch (level) {
    case "Public":       return "Public";
    case "Internal":     return "Internal";
    case "Confidential": return "Confidential";
    case "Restricted":   return "Restricted";
    default:             return assertNever(level); // adding a 5th level breaks the build HERE
  }
}
```

This turns "we added a sensitivity level and forgot to update the badge" from a production bug into a compile error.

---

## `unknown` over `any` for Untrusted Data

Data crossing a runtime boundary (network, `localStorage`, `postMessage`, URL params) is not yet the type you hope it is. Type it `unknown` and **narrow with a guard** before use. The generated API client validates server responses (see `react-api-client`); for everything else, write the guard.

```ts
// A user-defined type guard: proves the shape at runtime, narrows it at compile time.
function isAppError(v: unknown): v is AppError {
  return typeof v === "object" && v !== null
    && "code" in v && typeof (v as Record<string, unknown>).code === "string";
}

function handle(raw: unknown) {
  if (isAppError(raw)) {
    // raw is AppError here — safe to use raw.code
  }
}
```

For complex external schemas, a runtime validator (e.g., Zod) generates both the guard and the type from one schema — preferred over hand-written guards when the shape is large.

---

## Compile-Time Immutability

State should be immutable by type, not just by discipline — so an accidental mutation is a compile error.

```ts
// readonly fields + ReadonlyArray
interface DataAsset {
  readonly id: string;
  readonly tenantId: string;
  readonly sensitivity: SensitivityLevel;
  readonly tags: ReadonlyArray<string>;
}

// Deeply readonly via a mapped type for nested structures:
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K];
};

const asset: DeepReadonly<DataAsset> = load();
// asset.sensitivity = "Public"; // ❌ compile error — cannot assign to readonly
```

Props are `readonly` by default; state updates produce **new** objects (aligning with React's referential-equality model — see `react-performance-optimization`).

---

## Advanced Utility Types — Derive, Don't Duplicate

Derive related types from one source so they cannot drift. Restate nothing you can compute.

| Utility | Use | Example |
|---|---|---|
| `Pick<T, K>` | A subset of fields | `type AssetRow = Pick<DataAsset, "id" \| "sensitivity">` |
| `Omit<T, K>` | All but some fields | `type NewAsset = Omit<DataAsset, "id" \| "version">` |
| `Partial<T>` / `Required<T>` | Loosen / tighten optionality | form drafts vs validated payloads |
| `Record<K, V>` | Keyed maps | `Record<SensitivityLevel, string>` (badge colours) |
| `ReturnType<F>` | A function's result type | derive a hook's return type once |

### Template literal types

Encode string patterns the compiler can check — permissions, routes, event names:

```ts
type Resource = "data-assets" | "compliance-gaps" | "reports";
type Action   = "read" | "classify" | "generate";
type Permission = `${Resource}:${Action}`;   // "data-assets:classify" etc. — typo-proof
```

This mirrors the backend's `[resource-type]:[action]` permission convention from the security `access-control-model` — the same vocabulary, now compile-checked in the UI.

---

## Typing Component Props

- Props interfaces are `readonly`, named `…Props`, and use the narrowest types (unions over `string` where values are known).
- Discriminate prop variants so impossible prop combinations don't type-check (e.g., a button that is `{ variant: "link"; href: string } | { variant: "button"; onClick: () => void }`).
- Derive props from domain/API types with `Pick`/`Omit` rather than re-typing fields.
- No `React.FC` (it implies `children` and weakens inference) — type props explicitly: `function Badge(props: BadgeProps)`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No `any` | `unknown` + guards for untrusted data; `any` lint-banned | `any` anywhere |
| Discriminated unions | State/variants modeled as tagged unions | Boolean soup (`isLoading && hasData && …`) |
| Exhaustiveness | `assertNever` on union switches | `default` that silently swallows new variants |
| Immutability typed | `readonly` props/fields; ReadonlyArray | Mutable props/state mutated in place |
| Derived types | `Pick`/`Omit`/`ReturnType` derive from one source | Duplicated, drift-prone shape declarations |
| Narrow string types | Unions / template-literal types | Bare `string` where values are known |

---

## Output Format

Produces TypeScript type modules and guards (with type-level tests where useful):

```
src/shared/lib/types.ts          (shared domain types, utility types, guards)
src/features/*/types.ts          (feature-local derived types)
*.test-d.ts                       (optional: type-level assertions, e.g. expectTypeOf)
```
