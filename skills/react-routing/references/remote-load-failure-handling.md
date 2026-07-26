# Remote-Load-Failure Handling Standard

The retry-with-backoff and fallback-UI standard for when a Module
Federation remote fails to load. Self-contained — loadable without
reading `SKILL.md` first, though it assumes `microfrontend-architecture`'s
singleton/negotiation mechanics and `react-project-structure`'s
Vite-federation config.

---

## The Distinction This Standard Exists to Preserve

A **remote-load failure** is a dynamic `import()` of a remote's
`remoteEntry.js` that never arrives — a network failure, a remote
mid-deploy briefly 404ing, or a `strictVersion` negotiation conflict
(`microfrontend-architecture`'s `references/module-federation-config.md`).
This is categorically different from an **ordinary route render error** —
a thrown exception from code that *did* load and *did* run. The
distinction matters because it dictates who owns the fallback: a render
error can show something the failed component itself contributed (a
partial UI, a component-level retry); a load failure means the remote's
code never executed at all, so there is nothing of the remote's own left
to render — the fallback must be entirely shell-owned content.

Both need their own `errorElement` at the fragment's mount point in the
shell's router, but they resolve to different UI and, as this file
covers, different retry behavior.

## Two Causes, Two Retry Policies

Not every load failure should be retried the same way — the cause
determines whether retrying can possibly help:

| Cause | Example | Retry? |
|---|---|---|
| **Transient** | A network blip; a remote's CDN edge briefly 404s during a rolling deploy | Yes — automatic, with backoff |
| **Deterministic** | A `strictVersion` negotiation conflict; the remote was removed/renamed and the URL now 404s permanently | No — retrying reproduces the identical failure |

Retrying a deterministic failure wastes the retry budget and delays the
fallback for no benefit — `strictVersion: true` fails *because* the
negotiated versions are genuinely incompatible, not because of a timing
fluke; a `strictVersion` failure is caught and routed straight to the
fallback, never retried. Only a transient failure (a caught network error
with no `strictVersion` signature) enters the retry path below.

## Retry With Backoff, at the Import Layer

The retry happens by re-invoking the `import()` call itself, not by
retrying an already-failed `fetch` — the browser's own module cache can
hold onto a failed dynamic import for the same specifier, so a bare
re-`import()` of the identical URL can resolve to the same cached
rejection without a cache-busting query param appended per attempt.

```tsx
// apps/shell/src/app/remote-loading.ts
const BASE_DELAY_MS = 250;
const MAX_DELAY_MS = 4_000;
const MAX_ATTEMPTS = 3;

function isDeterministicFailure(err: unknown): boolean {
  // Module Federation's own negotiation error, not a network/load error —
  // see microfrontend-architecture's references/module-federation-config.md
  // for the shape this actually throws.
  return err instanceof Error && err.name === "ModuleFederationVersionError";
}

function backoffDelay(attempt: number): number {
  const exp = Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** attempt);
  return Math.random() * exp;                       // full jitter
}

// Wraps a remote's dynamic import with retry-with-backoff for transient
// failures only. Mirrors react-api-client's own backoff shape (250ms
// base, x2 factor, 4s cap, 3 attempts) so the codebase has one retry
// policy shape, not a second bespoke one invented for this layer.
export async function retryRemoteImport<T>(
  load: () => Promise<T>,
  attempt = 0,
): Promise<T> {
  try {
    return await load();
  } catch (err) {
    if (isDeterministicFailure(err) || attempt >= MAX_ATTEMPTS - 1) throw err;
    await new Promise((r) => setTimeout(r, backoffDelay(attempt)));
    return retryRemoteImport(load, attempt + 1);
  }
}
```

Wired into the router's `lazy` loader:

```tsx
// apps/shell/src/app/router.tsx
{
  path: "data-assets/*",
  lazy: async () => {
    const { DataAssetsApp } = await retryRemoteImport(
      () => import("dataAssets/DataAssetsApp"),
    );
    return { Component: DataAssetsApp };
  },
  errorElement: <RemoteLoadError fragment="data-assets" />,
}
```

## Fallback UI: Shell-Owned, Distinct From a Render-Error Fallback

Once retries exhaust (or immediately, for a deterministic cause), the
route's `errorElement` renders a **shell-owned** fallback — never a
generic "Something went wrong" shared with ordinary render errors, since
the messaging differs (a load failure is often transient and worth a
manual retry; a render error inside a loaded remote might not be):

```tsx
// apps/shell/src/app/RemoteLoadError.tsx
function RemoteLoadError({ fragment }: { fragment: string }) {
  const [reloading, setReloading] = useState(false);
  return (
    <ErrorRegion>
      <p>The {fragment} section is temporarily unavailable.</p>
      <RetryButton
        pending={reloading}
        onRetry={() => { setReloading(true); window.location.reload(); }}
      />
    </ErrorRegion>
  );
}
```

A full page reload (rather than re-invoking the `lazy` loader in place)
is the deliberate choice here: it also re-fetches the shell's own
manifest of remote URLs (`microfrontend-architecture`'s dynamic remote
resolution), so a genuinely stale or renamed remote reference gets a
chance to resolve correctly too, not just retry the same doomed URL.

## Reviewer Checklist

- Every fragment's mount path has its own `errorElement` distinct from
  any route-level render-error boundary within that fragment.
- The retry wrapper is used for every remote's `lazy` loader — a fragment
  added without it silently skips the retry/backoff standard.
- `isDeterministicFailure` (or the real negotiation-error type it
  eventually matches) is checked **before** the retry loop increments —
  never retry a `strictVersion` conflict.
- The fallback component never renders any markup, string, or asset that
  would have shipped from the failed remote itself.
