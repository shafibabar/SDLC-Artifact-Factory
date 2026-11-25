# Mock Service Worker (MSW) Official Documentation
**Authors:** The MSW project (mswjs)
**Domain:** Testing (network mocking, TypeScript)

Accessed 2026-11-25. Latest 3.0.7, Node >=22.12.0; optional peers vite >=6, graphql >=16, typescript >=5.9 (https://registry.npmjs.org/msw/latest). Base M = https://mswjs.io/docs. Read through a summarising fetch tool. Nothing was run.

## Core Concepts

### Version 3 changes (M/migrations/2.x-to-3.x)
- Node 22 minimum. Handlers move to subpaths (`msw/http`, `msw/graphql`, `msw/ws`, `msw/sse`, `msw/utils/delay`); `setupServer` stays in `msw/node`.
- `onUnhandledRequest` is renamed `onUnhandledFrame`; custom callbacks receive `{ frame, defaults }`.
- Calling `listen`/`start` twice throws; `worker.stop()` returns a Promise; `handleRequest()` removed in favour of `getResponse()`.
- GraphQL mocking is link-first.

### Unhandled requests (M/api/setup-server/listen)
- `"warn"` (default) prints and lets it through; `"error"` prints an error and halts that request; `"bypass"` is silent.
- A function may be passed (`frame.data.request`, `defaults.warn()`/`error()`); it opts out of the default static-asset ignoring (`isCommonAssetRequest()`).
- The page does not say that `"error"` fails the test.

### Overrides (M/best-practices/network-behavior-overrides)
`server.use()` prepends handlers, permanent until reset; `{ once: true }` matches once (`restoreHandlers()` revives); `resetHandlers()` removes runtime handlers, normally in `afterEach`.

### Delay (M/api/delay)
Milliseconds, `"real"` (about 100-400 ms; also the no-argument form), or `"infinite"`. In Node the implicit delay is disabled, so pass a value or mode.

### URLs (M/http/intercepting-requests)
Browsers resolve relative handler paths against the document location; the page says Node.js tests need a configured base URL. It does not address jsdom.

### Typing (M/best-practices/typescript)
`http.get<Params, RequestBody, ResponseBody, Path>`; `ResponseBody` constrains `HttpResponse.json()`.

### Test caches (M/faq)
Clear data-library caches between tests (React Query: `queryCache.clear()`). `server.boundary()` scopes overrides for concurrent tests.

## Actionable Techniques (design is this note's)

1. Setup: `listen({ onUnhandledFrame: ... })`, `afterEach(resetHandlers)`, `afterAll(close)`.
2. To fail the test, record unhandled requests in the callback (also call `defaults.error()`), assert the list is empty in `afterEach`, then clear it.
3. Hold a loading state with `delay("infinite")`; add error cases with per-test `server.use`.
4. Pass generated contract types as the `ResponseBody` generic and type-check test files.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-component-testing | W3D-23, 24, 27 | v3 API, override and delay rules |

## Candidate New Skills/Agents

None.

## Key Terminology

Request handler, Runtime override, Unhandled frame.

## Caveats

- [unverified] Whether v3 silently ignores the old `onUnhandledRequest` key; exact `"error"` effect seen by `fetch`; relative-path matching under jsdom with a `/api` base URL.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| W3D-23: unhandled request does not fail the test | Documented effect is print and halt that request only | Partly confirmed; test outcome not stated and not run |
| Skill uses `onUnhandledRequest` | Renamed in 3.x | Stale |
| `delay("infinite")` gives a deterministic hold | Pends forever | Confirmed |
| W3D-24: handlers can drift | Generics type the body; untyped literals get no such constraint (inference) | Confirmed |
| W3D-27: per-test override, fresh cache | Documented; query retry default in the Testing Library note | Confirmed |
