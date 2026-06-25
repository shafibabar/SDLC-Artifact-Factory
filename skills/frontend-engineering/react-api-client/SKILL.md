---
name: react-api-client
description: >
  Teaches how to build a type-safe API client from the shared OpenAPI contract —
  generating TypeScript types with openapi-typescript, a thin typed fetch wrapper
  (openapi-fetch) that injects the JWT and the W3C traceparent header, maps the
  standard error envelope to typed errors, forwards AbortSignal for cancellation,
  and keeps the frontend and backend in lockstep on one source of truth. The
  client is consumed by the TanStack Query hooks. Used by the frontend-engineer
  during Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, openapi, typescript, fetch, jwt, tracing, api-client]
---

# React API Client

## Purpose

The frontend and backend must agree, exactly, on every request and response shape. They do — because both are generated from the **same** OpenAPI 3.1 contract (`api-contract-design`, owned by the enterprise-architect). The backend generates its server from it (`go-openapi-codegen`); the frontend generates its TypeScript types from it. Neither side hand-writes the shapes, so they cannot drift. A breaking contract change fails the frontend build the same day it fails the backend's.

This skill produces the typed client: generated types + a thin fetch wrapper that handles auth, tracing, errors, and cancellation uniformly.

---

## Generate Types from the Contract

Use `openapi-typescript` to turn `openapi.yaml` into a `.ts` types file. This runs in CI and via an npm script — the generated file is committed and never edited.

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
export interface components { schemas: { DataAsset: { /* … */ }; ErrorResponse: { /* … */ } } };
```

A CI step regenerates and diffs (`git diff --exit-code`) so a stale client (spec changed, types not regenerated) fails the build — the mirror image of the backend's freshness check.

---

## The Typed Fetch Wrapper

`openapi-fetch` gives a tiny, fully-typed client over `fetch` — path, params, body, and response are all inferred from the generated `paths`. A typo in a path or a wrong body shape is a compile error.

```ts
// src/api/client.ts
import createClient from "openapi-fetch";
import type { paths } from "./generated";

const raw = createClient<paths>({ baseUrl: "/api" });

// Middleware: inject auth + trace context on every request; normalise errors.
raw.use({
  async onRequest({ request }) {
    const token = getAccessToken();                         // from auth store; never localStorage for tokens
    if (token) request.headers.set("Authorization", `Bearer ${token}`);
    injectTraceparent(request.headers);                     // W3C trace context (see react-observability)
    return request;
  },
});

export const api = {
  listDataAssets: async (filter: AssetFilter, signal?: AbortSignal) => {
    const { data, error } = await raw.GET("/v1/data-assets", {
      params: { query: toQuery(filter) },
      signal,                                                // cancellation from TanStack Query
    });
    if (error) throw toAppError(error);                      // typed ErrorResponse → AppError
    return data;                                             // fully typed DataAsset[]
  },

  classifyDataAsset: async (id: string, level: SensitivityLevel) => {
    const { error } = await raw.PATCH("/v1/data-assets/{id}/classification", {
      params: { path: { id } },
      body: { sensitivityLevel: level },                     // shape checked against the contract
      headers: { "Idempotency-Key": crypto.randomUUID() },   // backend honours this (go-service-layer)
    });
    if (error) throw toAppError(error);
  },
};
```

---

## Inject the JWT (Safely)

- The `Authorization: Bearer <jwt>` header is added by request middleware so no call forgets it.
- The token is held in memory (an auth store), **not** `localStorage`/`sessionStorage` — web storage is readable by any script and is an XSS exfiltration target. (A refresh token, if used, lives in an httpOnly cookie set by the backend.)
- On `401`, the client triggers a token refresh / redirect to login once, centrally — handlers never deal with auth expiry individually.

This is the frontend half of the Zero Trust JWT design (`zero-trust-design`); validation and issuance stay on the backend.

---

## Propagate the Trace (W3C traceparent)

Every outgoing request carries a `traceparent` header so the browser span links to the backend server span — completing the end-to-end trace. The backend's `distributed-tracing-design` already extracts it. (Detail in `react-observability`.)

```ts
function injectTraceparent(headers: Headers) {
  const span = trace.getActiveSpan();
  if (span) propagation.inject(context.active(), headers, { set: (h, k, v) => (h as Headers).set(k, v) });
}
```

---

## Map the Standard Error Envelope

The backend returns one error envelope (`api-contract-design`): `{ error: { code, message, fields?, traceId? } }`. The client maps it to a typed `AppError` so UI code switches on `code`, never parses strings.

```ts
function toAppError(raw: components["schemas"]["ErrorResponse"]): AppError {
  return {
    code: raw.error.code,            // "FORBIDDEN" | "CONFLICT" | "UNPROCESSABLE" | …
    message: raw.error.message,
    fields: raw.error.fields ?? [],  // field-level validation errors → form display
    traceId: raw.error.traceId,      // shown in the error UI for support correlation
  };
}
```

`code` is a discriminated union (see `typescript-types`), so error handling is exhaustive — a new backend error code surfaces as a compile prompt to handle it.

---

## Cancellation

Every read forwards an `AbortSignal` from TanStack Query (`react-state-management`). When a component unmounts or a query key changes, the in-flight request is aborted — no wasted bandwidth, no state updates on dead components. Mutations generally are not cancelled (the write may have already landed).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One source of truth | Types generated from the shared `openapi.yaml` | Hand-written request/response types |
| Generated not edited | `generated.ts` regenerated; CI diff-checks freshness | Hand-edits; drift from the contract |
| Auth centralised | JWT injected by middleware; in-memory token | Token in localStorage; per-call auth |
| Trace propagated | `traceparent` on every request | Broken trace at the browser boundary |
| Typed errors | Envelope → discriminated `AppError` | Parsing error strings; `any` errors |
| Cancellation | `AbortSignal` forwarded on reads | Uncancellable requests racing |

---

## Output Format

Produces the generated types, the client, and contract-aligned tests (MSW):

```
src/api/generated.ts        (GENERATED from openapi.yaml)
src/api/client.ts            (typed wrapper: auth, tracing, errors, cancellation)
src/api/errors.ts            (AppError mapping)
src/api/client.test.ts       (MSW-backed; written first)
```
