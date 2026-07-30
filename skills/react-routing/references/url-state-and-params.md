# URL-State Standard: Route Params, Search Params, and Component State

The full URL-state standard: the exact test for which of three places a
value belongs in, deep-linking correctness as the standard's pass/fail
check, and the validated parse/serialise code for both param kinds. This
content is largely unchanged from the single-app model — nothing about
URL-as-state or param validation differs inside a fragment versus a
single app; it's split out here because it's substantial worked code, not
because it's microfrontend-specific. Self-contained — loadable without
reading `SKILL.md` first.

---

## The Three-Way Test

Every value a page displays falls into exactly one of three places, and
the question that decides which is always the same: **if a colleague
opened this exact URL in a fresh tab, what would they need to see
reproduced?**

| Question | If yes | Where it lives |
|---|---|---|
| Does this value identify *which* resource the route is about — the route resolves to a different page entirely without it? | Yes | **Route param** (`:id`) |
| Does this value describe *a view* over that same resource — filter, sort, page, active tab, the selected row — that a colleague should see reproduced exactly? | Yes | **Search param** |
| Does this value have no meaning to anyone but this one render — a live keystroke before submit, a hover state, an in-flight animation frame? | Yes | **Component state** |

A value that fails the first two tests and is nonetheless tempting to put
in the URL "for consistency" almost always belongs in component state —
putting it in the URL adds churn to browser history and shareable links
with no actual shareability benefit. A value that passes the first or
second test but is kept in component state instead is the far more common
and more damaging mistake: it silently breaks every one of the scenarios
below.

## Deep-Linking Correctness Is the Pass/Fail Check

The standard isn't "does it look right when I click through the app" —
it's **paste the URL in a fresh tab (or send it to a colleague) and check
whether the exact visible state reproduces**, specifically:

- **Direct URL entry** — typing or pasting the full URL, not navigating
  via in-app links, must render the same page a user would reach by
  clicking through.
- **Refresh** — reloading the current page must not lose the active
  filter, sort, page, or selection.
- **Share** — sending the URL to a colleague must reproduce their exact
  view, not a default/empty one they then have to reconstruct by hand.
- **Back/forward** — browser history must step through prior view states
  (a previous filter, a previous selected row), not just prior routes.

Any of these four failing for a value that passed the route-param or
search-param test in the table above is a defect in *placement*, not a
router bug — the fix is moving the value into the URL, never adding
`sessionStorage`/`localStorage` to patch over the symptom.

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

## Worked Ambiguous Cases

Three cases that look like they could go either way, resolved by the
three-way test:

- **A "compare" view with two selected records** — both records are
  *which resource* the route is about, so both are route params or a
  structured search param (`?compare=id1,id2`), never component state:
  a colleague's pasted link must open the same comparison.
- **A wizard's current step** — if refreshing mid-wizard should resume at
  that step (usually desirable for a long form), the step is a search
  param; if the wizard is meant to always restart from step one on
  refresh (a deliberate product decision, not a default), it's component
  state — decide explicitly, don't default to component state by
  omission.
- **A table's expanded-row set** — genuinely no one needs to reproduce
  this from a shared link and it's high-churn (changes on every click);
  component state, not search params — putting it in the URL would churn
  browser history without adding shareability anyone asked for.
