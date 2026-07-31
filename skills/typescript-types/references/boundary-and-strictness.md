# The Boundary, tsconfig Strictness, and Cross-Fragment Contracts

How untrusted data becomes trusted, which compiler flags make the type model bite, and when a type stops being local and becomes a versioned federated contract. Grounded in this repo's stack — React + TypeScript microfrontend, Go/chi backend, physically multi-tenant data-estate and compliance platform.

---

## 1. Parse, Don't Validate — At the Boundary

"Validate" implies you check a value and hand back the same untyped thing, hoping the check holds everywhere downstream. "Parse" means you consume the untrusted input **once** and produce a value of a *stronger type* — after which the type system carries the guarantee for you, and no downstream code re-checks. Once parsed, an invalid shape is unrepresentable; there is no `unknown` left to leak.

The rule: **every runtime boundary produces `unknown`; parse it into a typed domain model at that boundary and nowhere else.** Boundaries in this frontend:

- `fetch` / the generated API client (server responses)
- `localStorage` / `sessionStorage` (`JSON.parse` returns `any` — immediately annotate `unknown`)
- `postMessage` and cross-fragment event buses (Module Federation seams)
- URL params, query strings, and route loaders

### Small shapes: a user-defined type guard

A guard is a function returning `v is T` — it proves the shape at runtime and narrows it at compile time:

```ts
type AppError = { readonly code: string; readonly message: string };

function isAppError(v: unknown): v is AppError {
  return (
    typeof v === "object" && v !== null &&
    "code" in v && typeof (v as Record<string, unknown>).code === "string" &&
    "message" in v && typeof (v as Record<string, unknown>).message === "string"
  );
}

function handle(raw: unknown) {
  if (isAppError(raw)) {
    // raw is AppError here — raw.code is safe
  }
}
```

A guard's body is unchecked assertion glue — the `as Record<string, unknown>` cast inside it is the price of hand-writing one. Keep guards tiny and single-purpose; the compiler trusts the `v is T` claim without verifying the body matches it, so a wrong guard is a silent hole.

### Larger shapes: parse with a runtime validator (Zod)

For anything beyond a couple of fields, hand-written guards drift out of sync with the type. A schema-first runtime validator derives **both** the type and the parser from one declaration, so they cannot diverge:

```ts
import { z } from "zod";

const SensitivityLevel = z.enum(["Public", "Internal", "Confidential", "Restricted"]);

const DataAssetSchema = z.object({
  id: z.string().uuid(),
  tenantId: z.string().uuid(),
  name: z.string().min(1),
  version: z.number().int().nonnegative(),
  sensitivity: SensitivityLevel,
  tags: z.array(z.string()).readonly(),
});

// One source of truth: the type is INFERRED from the schema, never restated.
type DataAsset = z.infer<typeof DataAssetSchema>;

async function loadAsset(id: string): Promise<DataAsset> {
  const res = await fetch(`/api/assets/${id}`);
  const raw: unknown = await res.json();
  return DataAssetSchema.parse(raw); // throws on the boundary if the server lied; typed after
}
```

After `.parse()`, the rest of the app receives a `DataAsset` it can trust — no `as` casts, no re-validation. The generated API client already applies this discipline to server responses (see `react-api-client`); for `localStorage`, `postMessage`, and route params you write the parse yourself. This is the frugal choice too: one open-source dependency (Zod) removes a whole class of hand-written guard bugs.

### The cast that is never allowed

```ts
const data = (await res.json()) as DataAsset[]; // ❌ a lie the compiler believes
```

`as` tells the compiler to stop checking. It does not inspect the value; a malformed or malicious response now flows through the app typed as something it is not. Replace every such cast with a parse.

---

## 2. tsconfig Strictness — What Each Flag Buys

`strict: true` is the floor, not the ceiling. It enables a family of flags together (`noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `useUnknownInCatchVariables`, `alwaysStrict`, `noImplicitThis`). Beyond it, several individually-toggled flags each close a specific hole the boundary discipline depends on:

```jsonc
{
  "compilerOptions": {
    "strict": true,                         // the whole strict family — non-negotiable floor
    "noUncheckedIndexedAccess": true,       // arr[i] and map[k] are T | undefined, not T
    "exactOptionalPropertyTypes": true,     // `x?: T` cannot be set to `undefined` explicitly
    "noImplicitOverride": true,             // an override must say `override`
    "noImplicitReturns": true,              // every code path returns, or none does
    "noFallthroughCasesInSwitch": true,     // a case must break/return — no accidental fallthrough
    "noUnusedLocals": true,                 // dead locals fail the build
    "noUnusedParameters": true,             // dead params fail the build (prefix _ to keep)
    "verbatimModuleSyntax": true,           // type-only imports stay erasable — clean tree-shaking
    "forceConsistentCasingInFileNames": true
  }
}
```

| Flag | Hole it closes | Why it matters here |
|---|---|---|
| `strict` | Implicit `any`, nullable-blind access, unsound `this` | The baseline the whole `unknown`-over-`any` rule rests on |
| `noUncheckedIndexedAccess` | `arr[i]` typed as `T` even when the index is out of range | A `DataAsset[]` row lookup is honestly `DataAsset \| undefined`; forces a presence check before use, preventing the classic `undefined is not an object` runtime crash |
| `exactOptionalPropertyTypes` | `field?: T` silently accepting an explicit `undefined` | Keeps "absent" and "present but undefined" distinct — matters for patch payloads (`AssetEdit`) where the two mean different things to the API |
| `noImplicitReturns` / `noFallthroughCasesInSwitch` | Missing return paths, leaked `switch` fallthrough | Reinforces the exhaustive-`switch`/`assertNever` pattern from `references/type-patterns.md` |
| `noUnusedLocals` / `noUnusedParameters` | Dead code accumulating silently | Keeps derived-type refactors honest — an orphaned local after a `Pick` change fails CI |
| `verbatimModuleSyntax` | `import type` collapsing into runtime imports | Type-only imports across a fragment boundary must erase cleanly so they don't drag runtime code into a federated chunk |

`any` is additionally lint-banned (an ESLint `no-explicit-any` rule), so the escape hatch `strict` still technically permits is closed at the lint layer. The `frontend-engineer`'s `npm run ci` gate runs `typecheck` with this config plus `lint` including the no-`any` rule.

---

## 3. Cross-Fragment Shared Types Are Versioned Contracts

In a Module Federation microfrontend, most types are **local** — defined inside one fragment, changed at will, invisible to everyone else. A small number cross a seam and become **contracts**, governed exactly like an API schema.

A type is a contract the moment it appears in any of these:

- A **prop shape** a shell (host) passes into a remote it mounts.
- An **event payload** published on a shared event bus or `postMessage` channel between fragments.
- A type **re-exported through the shared dependency layer** (`exposes` in the federation config) that another fragment imports.

### Versioning rules

Treat the shared type's shape as a public API and version it (SemVer on the shared package / the exposed module):

| Change to a shared type | Compatibility | Version bump |
|---|---|---|
| Add an **optional** field | Backward-compatible — old consumers ignore it | MINOR |
| Add a new **union member** to a payload | Backward-compatible **only if** consumers already have a `default`/`assertNever` fallback; otherwise breaking | MINOR if defended, else MAJOR |
| Add a **required** field | Breaking — old producers don't send it | MAJOR |
| **Remove** or **rename** a field | Breaking — consumers read a field that's gone | MAJOR |
| **Narrow** a field's type (`string` → a literal union) | Breaking — previously valid values now rejected | MAJOR |
| **Widen** a field's type (a literal union → `string`) | Breaking for *consumers* that exhaustively switch on it | MAJOR |

A MAJOR change means both sides — the producing fragment and every consuming fragment — must be released together (or the shared type must be dual-versioned during a transition). This is the whole reason to keep the shared surface **small**.

### Keep the shared surface minimal — derive, don't expose

Never export a fat local type across a seam. Export the narrowest shape the seam actually needs, derived from the fuller local type so it can't drift:

```ts
// LOCAL to the data-assets fragment — rich, changes freely:
interface DataAsset {
  readonly id: AssetId;
  readonly tenantId: TenantId;
  readonly name: string;
  readonly version: number;
  readonly sensitivity: SensitivityLevel;
  readonly tags: ReadonlyArray<string>;
  readonly internalScanState: ScanState; // internal — must NOT cross the seam
}

// The CONTRACT exposed to the shell — a deliberately narrow, versioned view:
export type DataAssetSummaryV1 = Pick<
  DataAsset,
  "id" | "name" | "sensitivity"
>;
```

Deriving `DataAssetSummaryV1` via `Pick` means adding an internal field to `DataAsset` never accidentally widens the contract, and the `V1` suffix makes a breaking change a visible, deliberate `V2` alongside it during migration. This aligns with the component contract defined in `ui-component-spec` and the seam boundaries in `microfrontend-architecture` — the type contract and the component contract describe the same seam and must agree.

### Event payloads on the shared bus

A cross-fragment event is a contract with **no compiler link** between publisher and subscriber — they compile independently. Define the payload as a discriminated union (tag = event name) in the shared layer, version it by the rules above, and have every subscriber `assertNever` the default so an unrecognised (newer) event is caught rather than silently dropped:

```ts
// Shared, versioned:
export type EstateEvent =
  | { readonly type: "asset.classified"; readonly assetId: string; readonly level: SensitivityLevel }
  | { readonly type: "gap.opened";        readonly gapId: string; readonly severity: "low" | "high" };
```

Adding a third event member is MINOR only because subscribers are written to tolerate an unknown `type`; removing or renaming one is MAJOR and forces a coordinated release.
