# URL State and Typed Route Params

Full code for URL-as-source-of-truth and typed route param parsing. This
content is unchanged from the single-app model — nothing about
URL-as-state or param validation differs inside a fragment versus a
single app; it's split out here because it's substantial worked code, not
because it's microfrontend-specific. Self-contained — loadable without
reading `SKILL.md` first.

---

## URL as the Source of Truth

Filters, sort, pagination, and the active selection live in the URL
(search params), not component state — so a filtered view is shareable
and survives refresh (the decision recorded in `react-state-management`).
The IA defines these query params (`?sensitivity=Confidential&sort=name`).

```tsx
const SENSITIVITY_LEVELS = ["Public", "Internal", "Confidential", "Restricted"] as const;

// Validated parse — a bad or stale URL value becomes a safe default, never a garbage query key.
function parseSensitivity(v: string | null): SensitivityLevel | null {
  return SENSITIVITY_LEVELS.find((l) => l === v) ?? null;
}

function DataAssetListPage() {
  const [params, setParams] = useSearchParams();
  const filter: AssetFilter = {
    sensitivity: parseSensitivity(params.get("sensitivity")),   // validated, not cast
    sort: params.get("sort") ?? "name",
    page: Math.max(1, Number(params.get("page")) || 1),         // NaN-proof
  };
  const { data, isPending, error } = useDataAssets(filter); // URL → query key → fetch
  // changing a filter updates the URL, which re-derives the query:
  const onFilter = (s: SensitivityLevel) => setParams((p) => { p.set("sensitivity", s); return p; });
  // …
}
```

The URL flows into the TanStack Query key, so navigation and data stay in
sync automatically.

**Round-trip rule:** every param has a typed parse (unknown value →
default) and a serialiser that writes only canonical values, so
`parse(serialise(x)) === x`. Search params are as untrusted as route
params — a user can type anything into the address bar. This applies
identically inside a fragment's own routes as it did in the single-app
model.

## Typed Route Params

Route params are strings and must be parsed/validated, not trusted.
Centralise typed accessors so pages don't sprinkle `as` casts.

```tsx
function useDataAssetId(): string {
  const { id } = useParams();
  if (!id || !isUuid(id)) throw new Response("Not Found", { status: 404 }); // → nearest errorElement
  return id;
}
```

Invalid params route to the not-found/error UI rather than crashing or
fetching garbage.
