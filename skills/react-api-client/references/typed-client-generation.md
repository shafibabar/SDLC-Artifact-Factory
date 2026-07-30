# Typed Client Generation Standard

Self-contained reference for `react-api-client`. Covers the codegen tool
choice, the generated/hand-written boundary, the CI freshness check, and
how two contract conventions the frontend does not author — Field Mask
and Resource Revision (ETag) — are represented in the generated types and
handled in the hand-written wrapper.

---

## Tool Choice: `openapi-typescript` + `openapi-fetch`

The same `api/openapi.yaml` the backend consumes (`go-openapi-codegen`)
drives the frontend client too — one spec, two generators, never a
hand-maintained frontend copy of shapes the backend already defines.

**Default: `openapi-typescript` (types only) + `openapi-fetch` (a ~6 KB,
zero-dependency runtime wrapper over `fetch`).** Considered and rejected:

| Alternative | Why not the default |
|---|---|
| `orval` | Also generates TanStack Query hooks directly from the spec. That hook layer already has an owner — `react-state-management`'s feature-local `api.ts` files, which apply the server/client-state litmus test, structured query keys, and the cache-invalidation standard. Letting orval generate hooks too creates two competing generators for the same layer; the frugality constraint favors the narrower tool plus one hand-written wrapper over a heavier one that duplicates an already-owned responsibility. |
| `openapi-generator` (Java-based, multi-language) | General-purpose across many target languages and frameworks; its TypeScript output is more opinionated (class-based clients, its own HTTP abstraction) and heavier to configure than a repo already standardized on `net/http`+`chi`/`fetch` needs. |
| Hand-written `fetch` calls with hand-written types | The exact drift risk `api-contract-design` and `go-openapi-codegen` exist to close on the backend. A hand-typed frontend request/response shape can silently diverge from the contract with no compiler signal. |

`openapi-typescript` generates **types only** — zero runtime footprint,
so there is no generated client class to disagree with `openapi-fetch`'s
own thin runtime. This mirrors `go-openapi-codegen`'s generated/
hand-written split: generated types are never edited by hand; the
hand-written wrapper (`client.ts`) implements behavior against them.

---

## Generation Setup

```jsonc
// package.json
"scripts": {
  "gen:api": "openapi-typescript ../api/openapi.yaml -o src/api/generated.ts"
}
```

```ts
// src/api/generated.ts  — GENERATED, do not edit
export interface paths {
  "/v1/data-assets": {
    get: { /* query params, responses … fully typed */ };
  };
  "/v1/data-assets/{id}/classification": {
    patch: { /* request body, path params, responses … */ };
  };
}
export interface components {
  schemas: {
    DataAsset: { /* … */ };
    ErrorResponse: { /* … */ };  // see error-mapping-standard.md for the exact shape
  };
}
```

## CI Freshness Check

The same pattern `go-openapi-codegen` uses for the backend's generated
code, mirrored on the frontend side — a stale client (spec changed,
types not regenerated) fails the build instead of silently drifting:

```bash
npm run gen:api
git diff --exit-code -- src/api/generated.ts   # fails if the committed file differs
```

`generated.ts` carries a `GENERATED, do not edit` header. An edit is
erased on the next `gen:api` run — extend behavior via `client.ts`,
never by hand-patching the generated file.

---

## The Thin Fetch Wrapper

```ts
// src/api/client.ts
import createClient from "openapi-fetch";
import type { paths } from "./generated";

const raw = createClient<paths>({ baseUrl: "/api" });

// Middleware order matters: auth attachment and 401/refresh handling
// (auth-token-standard.md) run before error mapping ever sees a response.
raw.use(authMiddleware);

export const api = {
  listDataAssets: async (filter: AssetFilter, signal?: AbortSignal) => {
    const { data, error } = await raw.GET("/v1/data-assets", {
      params: { query: toQuery(filter) },
      signal,                          // forwarded from TanStack Query — see cancellation-standard.md
    });
    if (error) throw toAppError(error); // see error-mapping-standard.md
    return data;                        // fully typed DataAsset[]
  },

  classifyDataAsset: async (id: string, level: SensitivityLevel, idempotencyKey: string) => {
    const { error } = await raw.PATCH("/v1/data-assets/{id}/classification", {
      params: { path: { id } },
      body: { sensitivityLevel: level },  // shape checked against the contract at compile time
      headers: { "Idempotency-Key": idempotencyKey },
    });
    if (error) throw toAppError(error);
  },
};
```

The `Idempotency-Key` is **passed in, not generated here**: the mutation
hook generates it once per user intent (e.g. `useRef(crypto.randomUUID())`
scoped to the mutation) so a network retry of the same click reuses the
same key. Generating a fresh UUID inside the client function would give
every retry a new key, defeating the mechanism (`Idempotency` — canonical
glossary term).

---

## Field Mask: Partial Updates Without Ambiguity

`api-contract-design`'s field-mask convention resolves what an omitted
`PATCH` body field means (leave unchanged) versus an explicit `null`
(clear the field). The generated request body type makes every field
optional, which means the client — not the generator — is responsible
for actually preserving that distinction:

```ts
// WRONG — spreading the full previous resource re-sends every field,
// silently "confirming" values the user never touched and defeating
// the omitted-means-unchanged contract.
raw.PATCH("/v1/data-assets/{id}", { body: { ...previousAsset, notes: null } });

// RIGHT — the body carries only the fields the user actually changed.
raw.PATCH("/v1/data-assets/{id}", {
  body: { sensitivityLevel: "Restricted", notes: null }, // notes explicitly cleared
});
```

For a resource where a nested object needs one field updated without
re-sending the whole object, build the `updateMask` query parameter
(`?updateMask=sensitivityLevel,notes`) naming exactly the paths the
request touches — construct it from the same object used to build the
body, never hand-typed separately, or the two can drift apart within a
single call.

---

## Resource Revision (ETag): Optimistic Concurrency on the Frontend

For a resource with real concurrent-writer risk (`api-contract-design`'s
`references/advanced-resource-patterns.md` names `DataAsset` and
`ComplianceGap` as the plausible candidates here), the server returns an
`ETag` response header alongside the representation. The frontend's job:

1. **Store the `ETag` alongside the resource** in the query cache when a
   `GET` returns it — it travels with the cached value, not as separate
   client state.
2. **Send it back as `If-Match`** on the next conditional write for that
   resource.
3. **Treat a `409` with `code: "REVISION_MISMATCH"` (or the equivalent
   `[RESOURCE]_REVISION_MISMATCH`) as its own `AppError` case** — distinct
   from a business-rule `409` (see `error-mapping-standard.md`'s code
   table). The correct UI response is "reload — this changed since you
   loaded it," never the generic conflict-retry path a business-rule 409
   gets.

```ts
const { data, response } = await raw.GET("/v1/data-assets/{id}", { params: { path: { id } } });
const etag = response.headers.get("ETag");
// cache both `data` and `etag` together under the query key

await raw.PATCH("/v1/data-assets/{id}", {
  params: { path: { id } },
  headers: { "If-Match": etag },
  body: { sensitivityLevel: "Restricted" },
});
```

A write that omits `If-Match` on a revisable resource is not "safer" —
it silently opts back into the lost-update problem the mechanism exists
to prevent. Every mutation against a revisable resource carries it.
