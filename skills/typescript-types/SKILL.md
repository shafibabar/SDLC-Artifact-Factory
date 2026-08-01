---
name: typescript-types
description: >
  Model TypeScript types so invalid UI and domain states are unrepresentable —
  choose discriminated unions over boolean flags for loading/success/error and
  domain variants, decide when to reach for generics versus concrete types,
  apply parse-don't-validate at the fetch/postMessage/localStorage boundary,
  ban any in favour of unknown plus narrow type guards, brand IDs so tenant and
  asset ids cannot be swapped, and set tsconfig strictness. Covers exhaustiveness
  with never, utility types (Pick/Omit/Record/ReturnType), satisfies, template
  literal types, and when a cross-fragment shared type becomes a versioned
  federated contract rather than a local type. Used by frontend-engineer in Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, typescript, types, discriminated-union, generics, parse-dont-validate]
produces: typescript-type-modules
domain: frontend
status: stable
related: [react-api-client, react-state-management, react-performance-optimization, ui-component-spec, microfrontend-architecture, glossary-management, methodology-review]
---

# TypeScript Types

## Purpose

Types are the frontend's first line of defence. A precise type model makes illegal states unrepresentable — a component cannot be given a contradictory combination of props, and a network shape cannot be used before it is validated. The compiler catches the bug before the browser runs it. This skill is the type standard every other frontend skill follows.

## Three Governing Principles

1. **Make invalid states unrepresentable.** If two fields only ever exist together, model them together (a discriminated union), never as independent optionals or boolean flags that can drift into an impossible combination. The goal is that the *wrong* code fails to compile, not that the right code passes review.
2. **Parse, don't validate — at the boundary.** Data crossing a runtime edge (network, `localStorage`, `postMessage`, URL params) is `unknown` until proven. Validate it **once**, at the boundary, into a fully typed domain model; everything inside the app trusts the type. Never `as`-cast an external shape into your type — that is a lie the compiler believes.
3. **Prefer failures at compile time over runtime.** Exhaustiveness checks, branded IDs, `readonly`, and narrow string unions all convert a class of production bug into a build error. Reach for the construct that moves the failure earliest.

The hard rule under all three, from the frontend blueprint: **avoid `any` at all costs.** `any` switches off the compiler exactly where you most need it. Use `unknown` plus a narrow type guard when runtime data is unpredictable. `any` is lint-banned in this repo.

## Discriminated Unions First — For State and Domain Variants

A discriminated union encodes "these fields only exist together" so impossible combinations cannot be constructed. It is the single most valuable pattern for UI state and the default reach for:

- **Remote data** — one of `idle | loading | success | error`, never `isLoading && hasData && hasError` boolean soup.
- **Domain variants** — a `DataSource` that is `{ kind: "google-drive"; folderId } | { kind: "s3"; bucket }`, so S3-only fields can't be read on a Drive source.
- **Prop variants** — a button that is `{ variant: "link"; href } | { variant: "button"; onClick }`, so impossible prop combinations don't type-check.

Every union carries a literal **tag** field (`status`, `kind`, `variant`) the compiler narrows on. Pair every `switch` over a union with an `assertNever(x: never)` default so adding a variant breaks the build until it is handled — this turns "we added a sensitivity level and forgot the badge" from a production bug into a compile error. The tag rule, the exhaustiveness pattern, and worked examples are in **`references/type-patterns.md`**.

## Generics vs Concrete Types — When to Reach for Each

Generics buy reuse; they cost readability and inference clarity. Choose deliberately:

| Reach for a **generic** when… | Prefer a **concrete type** when… |
|---|---|
| The type genuinely varies by caller — `RemoteData<T>`, a `useQuery<T>` hook, a `Table<Row>` | The shape is fixed and domain-specific — a `DataAsset`, a `ComplianceGap` |
| Two or more call sites parameterise the same structure over different payloads | You are tempted to add a type parameter "for flexibility" no caller uses |
| A container/hook must return the caller's own type back to them | A single concrete union already expresses every case |

A type parameter used exactly once, or one with an unconstrained `<T>` that never flows through a return, is usually a concrete type wearing a costume. Constrain parameters (`<T extends { id: string }>`) so the generic states its own contract. Full component-generic and hook-generic examples, plus the utility-type catalogue (`Pick`/`Omit`/`Partial`/`Record`/`ReturnType`), `satisfies`, template literal types, and branded/nominal types, are in **`references/type-patterns.md`**.

## Deriving Types — Restate Nothing You Can Compute

Derive related types from one source so they cannot drift: `Pick`/`Omit` for row and payload subsets, `ReturnType` for a hook's result, `Record<SensitivityLevel, …>` for keyed maps. Use `satisfies` to check a config/theme/route map against a contract **without** widening its literal types away. Template literal types (`` `${Resource}:${Action}` ``) encode string patterns the compiler checks — but their unions **multiply**, so keep the operands small. Catalogue and worked examples: **`references/type-patterns.md`**.

## Branded IDs — Nominal Distinctions the Compiler Enforces

Every ID is a `string` at runtime, so nothing stops `fetchAsset(assetId, tenantId)` with the arguments swapped — in a physically multi-tenant product, that bug class is a **data leak**. A brand (`type TenantId = string & { readonly __brand: "TenantId" }`) makes structurally identical types nominally distinct at zero runtime cost. Cast into a brand only at trust boundaries (the API client, a validated route param); the branded type flows everywhere else. Pattern and the single-sanctioned-cast rule: **`references/type-patterns.md`**.

## Compile-Time Immutability

State should be immutable by type, not by discipline: `readonly` fields, `ReadonlyArray`, and a `DeepReadonly<T>` mapped type for nested structures, so an accidental mutation is a compile error. Props are `readonly` by default; updates produce **new** objects, aligning with React's referential-equality model (see `react-performance-optimization`). The `DeepReadonly` example lives in **`references/type-patterns.md`**.

## The Boundary and Strictness

Untrusted data is `unknown` and narrowed with a **user-defined type guard** (`function isX(v: unknown): v is X`) before use. For anything larger than a couple of fields, a runtime validator (Zod) generates both the guard and the type from one schema — the parse-don't-validate mechanism the generated API client already applies to server responses (see `react-api-client`). This is not optional strictness; it is the only place raw shapes are allowed to exist.

`tsconfig` strictness is what makes the whole model bite. `strict: true` is the floor; several additional flags each close a specific hole (unchecked index access, unused locals, implicit override, exact optional properties). The full boundary walkthrough (guard vs Zod, validate-once-into-a-typed-model), the strictness settings table with *why each matters*, and the cross-fragment shared-type contract discipline are in **`references/boundary-and-strictness.md`**.

## Microfrontend Note — Local Type vs Federated Contract

Most types are **local**: defined in one fragment, changed freely, seen by no one else. A type that crosses a Module Federation seam — a prop shape a shell passes into a remote, an event payload published on a shared bus, a type re-exported through the shared dependency layer — is a **versioned contract**, not a local type. It is governed the way an API schema is: additive changes are a minor version, a removed or narrowed field is a breaking change that both sides must be released for, and it aligns with the component contract in `ui-component-spec` and the seams defined in `microfrontend-architecture`. Keep the shared surface small: export the narrowest type the seam actually needs, derived (via `Pick`/`Omit`) from the fuller local type rather than exposing the whole thing. Versioning rules and a worked shared-contract example: **`references/boundary-and-strictness.md`**.

## Typing Component Props

- Props interfaces are `readonly`, named `…Props`, and use the narrowest types (unions over `string` where values are known).
- Discriminate prop variants so impossible combinations don't type-check.
- Derive props from domain/API types with `Pick`/`Omit` rather than re-typing fields.
- No `React.FC` (it implies `children` and weakens inference) — type props explicitly: `function Badge(props: BadgeProps)`.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No `any` | `unknown` + guards for untrusted data; `any` lint-banned | `any` anywhere |
| Discriminated unions | State/variants modeled as tagged unions | Boolean soup (`isLoading && hasData && …`) |
| Exhaustiveness | `assertNever` on union switches | `default` that silently swallows new variants |
| Boundary parsing | External data validated once into a typed model | `data as DataAsset[]` casts |
| Immutability typed | `readonly` props/fields; `ReadonlyArray` | Mutable props/state mutated in place |
| Derived types | `Pick`/`Omit`/`ReturnType` derive from one source | Duplicated, drift-prone shape declarations |
| Narrow string types | Unions / template-literal types | Bare `string` where values are known |
| Shared types versioned | Cross-fragment types treated as contracts | A federated type changed like a local one |

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| `any` (or `as unknown as T` laundering) | `unknown` + a type guard; fix the model, don't silence it |
| Boolean flags for state (`isLoading`, `hasError`, `hasData`) | One discriminated union — impossible combinations unrepresentable |
| `default:` branch that silently handles "everything else" | `assertNever` so new variants break the build |
| Casting API responses (`data as DataAsset[]`) | Generated client types + runtime validation at the boundary |
| A generic with one unconstrained parameter no caller varies | A concrete type — generics only where the type truly varies |
| Re-declaring a shape that exists elsewhere | `Pick`/`Omit`/`ReturnType` — one source, derived views |
| `React.FC<Props>` | Explicitly typed props: `function Badge(props: BadgeProps)` |
| Annotating a config object and losing its literals | `satisfies` — contract checked, inference kept |
| Changing a federated type like a local one | Version it as a contract — additive is minor, narrowing is breaking |

## Output Format

Produces TypeScript type modules and guards (with type-level tests where useful):

```
src/shared/lib/types.ts          (shared domain types, utility types, guards)
src/features/*/types.ts          (feature-local derived types)
*.test-d.ts                      (optional: type-level assertions, e.g. expectTypeOf)
```
