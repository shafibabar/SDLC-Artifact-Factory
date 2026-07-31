# Authentication Token-Attachment Standard

Self-contained reference for `react-api-client`. Covers where the bearer
token is attached, where it lives in memory, and the exact refresh-on-401
flow — including the single-flight problem of not firing N parallel
refresh requests when N in-flight requests all 401 at once.

---

## Where the Token Lives

**In memory, never `localStorage`/`sessionStorage`** — web storage is
readable by any script on the page, making it the classic XSS
exfiltration target. (A refresh token, if used, lives in an httpOnly
cookie the backend sets and reads; client JavaScript never touches it
directly.)

`microfrontend-architecture` and `react-state-management` already
establish that a narrow, versioned, read-mostly **shell context** is
where current-user identity crosses a fragment boundary. The access
token is exactly that kind of value — it must not be re-derived or held
separately per fragment. The fetch wrapper (`client.ts`) reads it through
a small accessor the shell exposes, not through `useContext` (the
wrapper is plain module code outside the React tree, and cannot call a
hook):

```ts
// The shell exposes these two functions via its documented, versioned
// shell-context API; every fragment's client.ts imports them.
declare function getAccessToken(): string | null;
declare function refreshAccessToken(): Promise<string>; // resolves with the new token, or rejects
```

Each fragment's `client.ts` still constructs its own `openapi-fetch`
instance and its own middleware (per `microfrontend-architecture`, no
client-side object spans a fragment boundary) — what's shared is the
token accessor itself, not a client instance.

---

## Attaching the Header

```ts
raw.use({
  async onRequest({ request }) {
    const token = getAccessToken();
    if (token) request.headers.set("Authorization", `Bearer ${token}`);
    return request;
  },
});
```

No call site ever sets this header itself — centralizing it in
middleware means no handler can forget it, and there is exactly one place
to change if the header name or scheme ever does.

---

## Refresh-on-401, Single-Flight

A naive per-request 401 handler — "on 401, call `refreshAccessToken()`,
retry" — is correct for exactly one in-flight request. It breaks the
moment two or more requests are in flight when the token expires: each
one independently sees its own 401, each one independently calls
`refreshAccessToken()`, and N requests produce N parallel refresh calls
racing the backend's refresh-token rotation (many refresh-token schemes
invalidate the old token the instant a new one is issued, so the second
concurrent refresh call fails outright, taking down a request that would
otherwise have succeeded on the first refresh's new token).

The fix: **one shared, in-flight refresh promise that every concurrent
401 handler awaits instead of independently calling refresh.**

```ts
// Module-level — shared across every request this client instance makes.
let refreshInFlight: Promise<string> | null = null;

async function getFreshToken(): Promise<string> {
  if (!refreshInFlight) {
    refreshInFlight = refreshAccessToken().finally(() => {
      refreshInFlight = null; // clear once settled so the *next* 401 starts a new refresh
    });
  }
  return refreshInFlight; // every concurrent caller awaits the SAME promise
}

raw.use({
  async onResponse({ request, response }) {
    if (response.status !== 401) return response;

    // Never refresh-and-retry a request that already carries this marker —
    // a 401 on a retried, freshly-tokened request means auth is genuinely
    // invalid, not stale; retrying again would loop forever.
    if (request.headers.get("X-Retried-After-Refresh")) {
      redirectToLogin();
      return response;
    }

    const newToken = await getFreshToken().catch(() => null);
    if (!newToken) {
      redirectToLogin();
      return response;
    }

    const retried = new Request(request, {
      headers: new Headers(request.headers),
    });
    retried.headers.set("Authorization", `Bearer ${newToken}`);
    retried.headers.set("X-Retried-After-Refresh", "1");
    return fetch(retried);
  },
});
```

Three properties this design guarantees, each answering a specific way
the naive version breaks:

| Property | How |
|---|---|
| N concurrent 401s → exactly one refresh call | `refreshInFlight` is checked-then-set as a single module-level slot; the second concurrent caller finds it already set and awaits the same promise instead of starting a second one. |
| The retry-after-refresh attempt can never loop forever | The `X-Retried-After-Refresh` marker caps the retry at exactly one hop — a 401 on the retried request is treated as genuinely invalid auth, not stale-token, and goes straight to `redirectToLogin`. |
| A failed refresh degrades to login, not a silent hang | `getFreshToken().catch(() => null)` — a rejected refresh (e.g., the refresh token itself expired) redirects immediately rather than leaving the original request pending. |

---

## Interaction with the Retry/Backoff Standard

This refresh-and-retry-once flow is **not** the same mechanism as
`error-mapping-standard.md`'s exponential-backoff retry for transient
`network`/`5xx` failures — a `401` is never handed to that generic retry
policy at all. It is intercepted and resolved (or redirected) here,
before the response ever reaches `toAppError`. If it still fails after
the single retry-after-refresh attempt, the *second* response — now
carrying `X-Retried-After-Refresh` — is what error-mapping sees, and it
maps to `AUTHENTICATION_REQUIRED` like any other unresolved 401.
