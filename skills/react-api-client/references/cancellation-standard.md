# Request-Cancellation Standard

Self-contained reference for `react-api-client`. Covers `AbortController`
wiring through the typed client, exactly where that plumbing meets
TanStack Query's own signal support, and how an aborted request must be
kept out of the error-mapping and retry paths.

This file owns the **plumbing** of forwarding a signal from caller to
`fetch`. It does not own query keys, `staleTime`/`gcTime`, or
cache-invalidation — those are `react-state-management`'s territory;
see that skill for the caching policy this plumbing serves.

---

## Where the Signal Comes From

TanStack Query provides an `AbortSignal` to every `queryFn` automatically
— it does not need to be created by hand. When a component unmounts, a
query key changes (e.g., a filter changes so the old query is no longer
observed), or a newer request for the same key supersedes an in-flight
one, the library aborts that signal itself:

```ts
// react-state-management's feature-local api.ts — this file's caller
useQuery({
  queryKey: ["data-assets", filter],
  queryFn: ({ signal }) => api.listDataAssets(filter, signal), // signal supplied by TanStack Query
});
```

`react-api-client`'s job is narrower: every read method accepts that
`signal` as a parameter and forwards it, unmodified, into `openapi-fetch`'s
own `signal` option — never wrapping it, never creating a second
`AbortController` that races the one TanStack Query already manages:

```ts
listDataAssets: async (filter: AssetFilter, signal?: AbortSignal) => {
  const { data, error } = await raw.GET("/v1/data-assets", {
    params: { query: toQuery(filter) },
    signal,   // the exact signal TanStack Query passed in — not a new one
  });
  if (error) throw toAppError(error, /* status */ 0);
  return data;
},
```

---

## Mutations Are Not Cancelled

Reads cancel; writes settle. A `PATCH`/`POST`/`DELETE` may have already
been received and processed by the server by the time a component
decides to abandon interest in its result — aborting the client-side
`fetch` at that point does not undo the write, it only makes the UI
falsely believe nothing happened. Mutation methods on the client
therefore do not accept a `signal` parameter at all; there is nothing to
forward, and adding one invites exactly this bug.

---

## Aborted Requests Must Never Reach Error Mapping or Retry

When `fetch` is aborted, it rejects with an error whose `name` is
`"AbortError"` — distinguishable from a genuine network failure. This
must be checked **before** anything is classified into the `AppError`
union `error-mapping-standard.md` defines:

```ts
try {
  return await raw.GET(/* … */, { signal });
} catch (e) {
  if (e instanceof DOMException && e.name === "AbortError") {
    throw { kind: "aborted" } satisfies AppError; // never surfaced as a network error, never retried, never toasted
  }
  throw { kind: "network", message: String(e) } satisfies AppError;
}
```

TanStack Query already treats a query aborted by its own cancellation as
"not a failure" internally and will not call `onError`/render an error
state for it — this check exists so the `AppError` value itself is
correct if it is ever inspected directly (e.g., in a test, or a lower-level
caller not going through the query hook), not to duplicate work TanStack
Query already does at the hook layer.

---

## What This File Does Not Decide

- **Whether a query is `enabled`, how long it stays fresh, or when it's
  invalidated** — `react-state-management`.
- **Whether a failure is worth retrying, and with what backoff** —
  `error-mapping-standard.md`. A retried attempt after a transient
  `"network"` failure gets a fresh call into this same forwarding path,
  with whatever signal is current at the time of the retry — the signal
  is re-read per attempt, never cached from the first attempt.
