# Type Patterns — Discriminated Unions, Generics, Utility Types, Branding

Comprehensive worked patterns for the TypeScript type model. Each pattern is grounded in this repo's stack — React + TypeScript microfrontend over a Go/chi/pgx/PostgreSQL/Redpanda backend, a physically multi-tenant data-estate and compliance platform serving the Data Steward and Compliance Officer personas. All examples compile under the strict `tsconfig` in `references/boundary-and-strictness.md`.

---

## 1. Discriminated Unions — The Tag Rule

A discriminated (tagged) union is a union of object types that all share one **literal** field — the *discriminant* or *tag*. TypeScript narrows the whole object once you test that one field, so fields that exist in only one member become accessible only inside that member's branch.

```ts
// A remote resource is EXACTLY one of these — never "loading AND has data AND has error".
type AppError = { readonly code: string; readonly message: string };

type RemoteData<T> =
  | { readonly status: "idle" }
  | { readonly status: "loading" }
  | { readonly status: "success"; readonly data: T }
  | { readonly status: "error"; readonly error: AppError };
```

Rules that make the tag work:

1. **The tag is a literal type, not `string`.** `status: "success"` narrows; `status: string` does not.
2. **Every member carries the same tag key.** Mixing `status` on some members and `kind` on others breaks narrowing.
3. **Tag values are mutually exclusive.** No two members share a tag value.
4. **Member-only fields live only on their member.** `data` exists on `success` alone; the compiler forbids reading it elsewhere.

Narrowing in a component render:

```ts
function render(state: RemoteData<DataAsset[]>) {
  switch (state.status) {
    case "idle":    return <Empty />;
    case "loading": return <Skeleton />;
    case "success": return <Table rows={state.data} />;        // state.data exists ONLY here
    case "error":   return <ErrorBanner error={state.error} />; // state.error exists ONLY here
  }
}
```

### Domain variants

Model domain shapes the same way, so shape-specific fields cannot be misused:

```ts
type DataSource =
  | { readonly kind: "google-drive"; readonly folderId: string }
  | { readonly kind: "s3"; readonly bucket: string; readonly region: string }
  | { readonly kind: "upload"; readonly fileName: string; readonly bytes: number };

function locate(src: DataSource): string {
  switch (src.kind) {
    case "google-drive": return `drive:${src.folderId}`;
    case "s3":           return `s3://${src.bucket}/${src.region}`; // region only exists here
    case "upload":       return `upload:${src.fileName}`;
    default:             return assertNever(src);
  }
}
```

---

## 2. Exhaustiveness Checking with `never`

`never` is the type with no values. Any value assignable to `never` is a proof the compiler believes the value cannot occur. In an exhaustive `switch`, once every real case is handled the residual type is `never`; if a new member is added, the residual becomes that member's type — which is **not** assignable to `never` — and the build fails at exactly the `default` line.

```ts
function assertNever(x: never): never {
  throw new Error(`unhandled variant: ${JSON.stringify(x)}`);
}

type SensitivityLevel = "Public" | "Internal" | "Confidential" | "Restricted";

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

Use `assertNever` on every `switch` over a union whose membership might grow. The `default` arm doubles as a runtime guard (throwing on genuinely impossible input) and a compile-time completeness proof. Never write a `default` that silently returns a fallback — that swallows the new variant instead of surfacing it.

---

## 3. Generics for Components and Hooks

Reach for a generic only where the type **genuinely varies by caller**. The two most common legitimate cases in this frontend are a reusable data hook and a reusable container component.

### A generic hook

```ts
// The caller's row type flows in and back out — a real reason to parameterise.
function useResource<T>(key: readonly string[], fetcher: () => Promise<T>): RemoteData<T> {
  // ...delegates to TanStack Query internally (see react-state-management)...
}

const assets = useResource<DataAsset[]>(["assets", tenantId], loadAssets);
// assets is RemoteData<DataAsset[]> — narrowing preserves DataAsset[] on the success branch
```

### A generic component

```ts
interface TableProps<Row> {
  readonly rows: ReadonlyArray<Row>;
  readonly columns: ReadonlyArray<{ readonly key: keyof Row; readonly header: string }>;
  readonly rowKey: (row: Row) => string;
}

function Table<Row>(props: TableProps<Row>) {
  return (
    <table>
      <tbody>
        {props.rows.map((r) => (
          <tr key={props.rowKey(r)}>{/* cells keyed by props.columns */}</tr>
        ))}
      </tbody>
    </table>
  );
}
```

Note `key={props.rowKey(r)}` — a stable identity drawn from the data, never the array index, so the reconciler preserves row state across reordering (see `react-component-design`). `rowKey` being a required prop forces every caller to supply that identity.

### Constrain type parameters

An unconstrained `<T>` states no contract and permits nonsense. Constrain it to the minimum shape the code actually uses:

```ts
function byId<T extends { readonly id: string }>(items: readonly T[]): Map<string, T> {
  return new Map(items.map((i) => [i.id, i]));
}
```

A type parameter that appears exactly once in a signature, and never links an input to an output, is almost always a concrete type in disguise — replace it with the concrete type.

---

## 4. Utility Types — Derive, Don't Duplicate

Derive related types from one source so they cannot drift.

| Utility | Use | Example |
|---|---|---|
| `Pick<T, K>` | A subset of fields | `type AssetRow = Pick<DataAsset, "id" \| "sensitivity">` |
| `Omit<T, K>` | All but some fields | `type NewAsset = Omit<DataAsset, "id" \| "version">` |
| `Partial<T>` / `Required<T>` | Loosen / tighten optionality | form drafts vs validated payloads |
| `Record<K, V>` | Keyed maps | `Record<SensitivityLevel, string>` (badge colours) |
| `ReturnType<F>` | A function's result type | derive a hook's return type once |
| `Parameters<F>` | A function's argument tuple | wrap/decorate a call without re-typing args |
| `NonNullable<T>` | Strip `null`/`undefined` | after a presence check |

```ts
interface DataAsset {
  readonly id: string;
  readonly tenantId: string;
  readonly name: string;
  readonly version: number;
  readonly sensitivity: SensitivityLevel;
  readonly tags: ReadonlyArray<string>;
}

type AssetRow  = Pick<DataAsset, "id" | "name" | "sensitivity">; // the table row
type NewAsset  = Omit<DataAsset, "id" | "version">;              // creation payload
type AssetEdit = Partial<Omit<DataAsset, "id" | "tenantId">>;     // patch payload
```

If `DataAsset` gains a field, `AssetRow`/`NewAsset`/`AssetEdit` stay correct automatically — no shape is restated.

### `satisfies` — check without widening

`satisfies` verifies a value against a type **without** discarding its inferred literal types — the fix for "annotate and lose precision / don't annotate and lose checking":

```ts
const badgeColor = {
  Public: "gray",
  Internal: "blue",
  Confidential: "amber",
  Restricted: "red",
} satisfies Record<SensitivityLevel, string>;
// Completeness IS checked (a 5th SensitivityLevel fails to compile here),
// yet badgeColor.Restricted is still the literal "red" — not widened to string.
```

Use it for config maps, route tables, and theme tokens — anywhere a value must conform to a contract but callers want the precise literals.

---

## 5. Template Literal Types

Encode string patterns the compiler can check — permissions, routes, event names:

```ts
type Resource   = "data-assets" | "compliance-gaps" | "reports";
type Action     = "read" | "classify" | "generate";
type Permission = `${Resource}:${Action}`;   // "data-assets:classify" etc. — typo-proof
```

This mirrors the backend's `[resource-type]:[action]` permission convention (the security `access-control-model`) — the same vocabulary, now compile-checked in the UI.

Two edges to know:

- **Unions multiply.** `Resource × Action` above is 3 × 3 = 9 members. Keep the operand unions small, or the compiler slows and error messages become unreadable.
- **Open-ended patterns lose exhaustiveness.** `` `asset-${string}` `` gives pattern-checking but the set is infinite, so `assertNever`-style completeness no longer applies. Choose deliberately: a closed union of literals when you need exhaustiveness, an open template when you only need a shape check.

---

## 6. Branded (Nominal) Types

TypeScript is structural: two types with the same shape are interchangeable. Every ID is a `string`, so nothing stops `fetchAsset(assetId, tenantId)` with the arguments swapped — in a physically multi-tenant product that is a **cross-tenant data leak**. A brand adds a phantom field that exists only in the type system, making structurally identical types nominally distinct:

```ts
type AssetId  = string & { readonly __brand: "AssetId" };
type TenantId = string & { readonly __brand: "TenantId" };

// The ONE sanctioned cast — at the trust boundary, after validation:
const asAssetId  = (v: string): AssetId  => v as AssetId;
const asTenantId = (v: string): TenantId => v as TenantId;

declare function fetchAsset(tenant: TenantId, id: AssetId): Promise<DataAsset>;

fetchAsset(asTenantId(t), asAssetId(a)); // ok
// fetchAsset(asAssetId(a), asTenantId(t)); // ❌ compile error — swapped arguments cannot type-check
```

The `& { __brand }` intersection is never constructed at runtime — the brand is erased during compilation, so a branded value is just a `string` in the running program. **Zero runtime cost.** Cast into the brand only at trust boundaries (the API client, a validated route param, a parsed URL segment); everywhere else the branded type flows through function signatures and prevents the mix-up.

---

## 7. Compile-Time Immutability

Make state immutable by type so an accidental mutation is a compile error, not a discipline the reviewer must catch:

```ts
interface DataAsset {
  readonly id: string;
  readonly tenantId: string;
  readonly sensitivity: SensitivityLevel;
  readonly tags: ReadonlyArray<string>;   // cannot push/splice
}

// Deeply readonly via a recursive mapped type, for nested structures:
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K];
};

const asset: DeepReadonly<DataAsset> = load();
// asset.sensitivity = "Public";        // ❌ compile error — cannot assign to readonly
// asset.tags.push("x");                // ❌ compile error — ReadonlyArray has no push
```

Props are `readonly` by default; state updates produce **new** objects rather than mutating in place, which aligns with React's referential-equality bail-out model (see `react-performance-optimization`) — a mutated-in-place object keeps the same reference and silently defeats `React.memo`.
