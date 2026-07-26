---
name: react-api-client
description: >
  Teaches how to build the frontend's typed API client from the shared
  OpenAPI contract, so it can never drift from what the backend
  (go-chi-handler, go-openapi-codegen) actually serves: generating
  TypeScript types with openapi-typescript, a thin openapi-fetch wrapper
  that attaches the JWT and traceparent header, the exact ErrorResponse
  envelope mapped to a typed AppError discriminated union (never a
  generic catch-all Error), request cancellation via AbortController
  wired through TanStack Query's own signal (cross-referencing
  react-state-management for the caching policy this plumbing serves),
  an exponential-backoff retry standard distinguishing transient
  failures (network, 5xx, 429) from failures that must never be
  retried (4xx), and the auth-token-attachment standard including the
  single-flight refresh-on-401 flow. Also covers Field Mask and
  Resource Revision (ETag) handling on the wire. Used by the
  frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, openapi, typescript, fetch, jwt, tracing, api-client, error-mapping, retry, cancellation]
related: [react-state-management, typescript-types, api-contract-design, go-chi-handler, go-openapi-codegen, go-error-handling, microfrontend-architecture]
---

# React API Client

## Purpose

The frontend and backend must agree, exactly, on every request and
response shape. They do — both are generated from the **same** OpenAPI
3.1 contract (`api-contract-design`). The backend generates its server
from it (`go-openapi-codegen`); the frontend generates its TypeScript
types from it. Neither side hand-writes the shapes, so they cannot
drift: a breaking contract change fails the frontend build the same day
it fails the backend's.

This skill produces the typed client and its five standards: type
generation, error mapping, cancellation, retry/backoff, and auth-token
attachment. Each has a full worked reference; this body states the rule
each enforces and why.

---

## Generate the Client from the Contract

Default: **`openapi-typescript`** (types only, zero runtime) plus
**`openapi-fetch`** (a ~6 KB wrapper inferring path/params/body/response
from the generated types — a typo in a path or a wrong body shape is a
compile error). Rejected: `orval`, because it also generates TanStack
Query hooks — a layer `react-state-management`'s feature-local `api.ts`
already owns; a heavier generator duplicating an owned responsibility
fails the frugality constraint. CI regenerates and diffs
(`git diff --exit-code`), the same freshness check `go-openapi-codegen`
runs on the backend's generated code — a stale client fails the build.
Full setup, generated-file boundary, and worked client code:
`references/typed-client-generation.md`.

---

## Wire-Contract Fidelity

Two contract conventions the frontend does not author still have to be
handled correctly on this side: an omitted `PATCH` field means
"unchanged," an explicit `null` means "clear it" (**Field Mask**), and a
revisable resource's `ETag`/`If-Match` pair (**Resource Revision**)
detects a lost update rather than silently letting the second writer
clobber the first. Both are handled in the client, not left to each
call site to reinvent: `references/typed-client-generation.md`.

---

## Error Mapping: Envelope → Typed `AppError`

`go-chi-handler`'s envelope, exactly: `{ error: { code, message, fields?,
traceId? } }`, one `writeDomainError` mapping point on the backend. The
client mirrors that discipline with **one** `toAppError` function
producing a discriminated union — `{ kind: "api", code, ... }` (see
`typescript-types` for the pattern) or `{ kind: "network" }` or
`{ kind: "aborted" }` — never a generic `Error` UI code has to
string-match against. `code` is switched on exhaustively, so a new
backend code is a compile error to leave unhandled, not a silent
fallthrough. Full envelope verification against `go-chi-handler`'s actual
struct, the union, and the exhaustive switch:
`references/error-mapping-standard.md`.

---

## Cancellation

Every read forwards the `AbortSignal` TanStack Query already supplies to
its `queryFn` (`react-state-management` owns when/why a query is
cancelled — query keys, `enabled`, unmount, superseding refetch; this
skill only forwards the signal into `openapi-fetch`'s own `signal`
option, unmodified). Mutations never accept a signal — a write may have
already landed server-side by the time a client wants to abandon
interest in the result, and aborting the `fetch` doesn't undo it. An
aborted request is checked (`e.name === "AbortError"`) and classified as
`{ kind: "aborted" }` **before** it can reach error mapping or retry — it
is never a network error and never retried. Full plumbing:
`references/cancellation-standard.md`.

---

## Retry and Backoff for Transient Failures

Retry `network` failures, any `5xx`, and `429` (honoring a present
`Retry-After` header). **Never** automatically retry any other `4xx` —
the request was rejected on its merits, and unchanged input reproduces
the identical failure. `401` is handled by the auth flow's own capped
refresh-and-retry-once, not this policy. A mutation is only safe to
retry when it carries an `Idempotency-Key`; one with none must not be
retried by this layer. Exponential backoff with full jitter (250ms base,
×2 factor, 4s cap, 3 attempts) plugs into **TanStack Query's own**
`retry`/`retryDelay` options — it does not compete with a second,
hand-rolled retry loop. Full table and backoff function:
`references/error-mapping-standard.md`.

---

## Authentication Token Attachment

The bearer token is attached by request middleware, held in memory only
— never `localStorage`/`sessionStorage` (the classic XSS exfiltration
target) — read through an accessor the shell exposes via its narrow,
read-mostly shell context (`microfrontend-architecture`,
`react-state-management`), not re-derived per fragment. On a `401`, a
**single, shared, in-flight refresh promise** is what every concurrent
401 handler awaits — N simultaneous 401s trigger exactly one refresh
call, never N. The retried request is marked so a second `401` after
refresh redirects to login instead of looping. Full flow and the
single-flight guard: `references/auth-token-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One source of truth | Types generated from the shared `openapi.yaml`; CI diff-checks freshness | Hand-written request/response types; drift undetected |
| Generated not edited | `generated.ts` regenerated only | Hand-edits to the generated file |
| Field Mask respected | Body carries only changed fields; explicit `null` clears | Full previous object spread into every `PATCH` |
| Resource Revision honored | `ETag` cached with the resource; `If-Match` sent on write; `REVISION_MISMATCH` handled distinctly | Writes with no `If-Match` on a revisable resource; mismatch treated as a generic conflict |
| Envelope fidelity | `toAppError` matches `go-chi-handler`'s exact `code`/`message`/`fields`/`traceId` shape | Invented field names; assumed shape not checked against the backend skill |
| Typed errors | Envelope → discriminated `AppError`; exhaustive `code` switch | Parsing error strings; `any`/generic `Error` |
| Cancellation | Reads forward TanStack Query's `signal`; aborted requests classified before retry/error-mapping | Uncancellable requests; an aborted request treated as a network failure |
| Retry discipline | Network/5xx/429 retried with backoff + jitter; other 4xx never retried; non-idempotent mutations never retried | Blanket retry-on-any-failure; a duplicate non-idempotent write from an automatic retry |
| Retry ownership | Backoff policy implemented via TanStack Query's `retry`/`retryDelay` | A second hand-rolled retry loop racing the query library's own |
| Auth centralized | JWT injected by middleware; in-memory, shell-context-sourced token | Token in `localStorage`; per-call auth logic |
| Single-flight refresh | One shared in-flight refresh promise for N concurrent 401s; retry capped at one hop | N parallel refresh calls; unbounded retry-after-refresh loop |
| Trace propagated | `traceparent` on every request | Broken trace at the browser boundary |

---

## Anti-Patterns

- **Hand-written request/response types** — drifts from the contract silently. Every shape comes from `generated.ts`.
- **Editing `generated.ts`** — erased on regeneration; extend via `client.ts`.
- **Spreading the previous resource into a `PATCH` body** — defeats the Field Mask's omitted-means-unchanged contract.
- **Writing a revisable resource with no `If-Match`** — silently reopens the lost-update problem `ETag` exists to prevent.
- **Inventing the `ErrorResponse` shape instead of reading `go-chi-handler`'s** — the two silently diverge the moment either side changes independently.
- **Parsing error message strings** (`if (message.includes("forbidden"))`) — breaks on the first copy change; switch on the typed `code`.
- **Cancelling mutations** — aborting a `PATCH` after the server processed it leaves the UI believing the write didn't happen.
- **An aborted request treated as a network error** — gets retried and/or shown to the user; check `AbortError` before classifying.
- **Retrying any non-401 `4xx`** — reproduces the identical failure; the fix is different input, not another attempt.
- **Retrying a non-idempotent mutation with no `Idempotency-Key`** — risks a duplicate write, a worse outcome than a surfaced error.
- **A second hand-rolled retry loop alongside TanStack Query's own `retry`** — the two race and double the effective attempt count.
- **JWT in `localStorage`/`sessionStorage`** — readable by any injected script.
- **Per-request 401 handling with no single-flight guard** — N concurrent 401s fire N refresh calls, racing refresh-token rotation.
- **No cap on the retry-after-refresh attempt** — a `401` on the retried request must redirect to login, not refresh again.

---

## Output Format

```
src/api/generated.ts        (GENERATED from openapi.yaml — never edited)
src/api/client.ts            (typed wrapper: auth, tracing, field-mask/etag, cancellation)
src/api/errors.ts            (AppError union + toAppError)
src/api/retry.ts             (backoff function; wired into TanStack Query's retry/retryDelay)
src/api/client.test.ts       (MSW-backed; written first)
```
