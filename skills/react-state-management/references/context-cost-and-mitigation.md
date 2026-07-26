# Context Performance Cost and Mitigation

The worked example behind `SKILL.md`'s Context Performance Cost section.
Self-contained — loadable without reading `SKILL.md` first, though it
assumes `react-component-design`'s framing of Context as "not a state
manager."

---

## The Model, and Where It Comes From

Banks & Porcello's *Learning React* (2nd ed., O'Reilly) states the cost
precisely: `useContext` gives a consumer no way to select a slice of the
Provider's value the way a store-with-selectors does — a component
re-renders on **any** change to the value passed to its Provider, whether
or not that component reads the specific field that changed. The book
names the sharpest, easiest-to-miss version of this: a Context value
recreated as a fresh object literal on every Provider render
(`<Ctx.Provider value={{a, b}}>`) defeats even React's own bail-out
optimizations, because the object's *reference* changes every render
regardless of whether `a` or `b` actually did.

This skill independently arrived at the same model before this book was
consulted to ground it: `SKILL.md`'s Client-State Library table already
named "Context causes re-render storms" as the trigger for escalating to
Zustand, and this skill's Anti-Patterns already listed "Context for
high-frequency values." What follows is that same finding made concrete —
the exact broken shape, a rendered count, and each fix in order of how
much it costs to apply.

---

## The Cost, Concretely

A fragment's filter bar needs three independent filters — status, owner,
date range — read by three separate chip components. The natural-looking
first draft shares them through one Context:

```tsx
// DON'T: one Context, one object literal recreated every parent render
function FiltersProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<Status | null>(null);
  const [owner, setOwner] = useState<string | null>(null);
  const [dateRange, setDateRange] = useState<DateRange | null>(null);

  return (
    <FiltersContext.Provider
      value={{ status, setStatus, owner, setOwner, dateRange, setDateRange }} // fresh object every render
    >
      {children}
    </FiltersContext.Provider>
  );
}

function StatusFilterChip() {
  const { status, setStatus } = useContext(FiltersContext); // only reads `status`
  return <Chip label={status ?? "Any status"} onClick={() => setStatus(next(status))} />;
}
```

`StatusFilterChip`, `OwnerFilterChip`, and `DateRangeFilterChip` each read
exactly one field. But every one of the three state setters lives in the
same `FiltersProvider`, so calling any one of them — a user changing only
the date range — re-renders `FiltersProvider`, which constructs a **new**
`value` object literal, which is a new reference regardless of whether
`status` or `owner` changed. Result: changing one filter re-renders all
three chips, every time, with no way for a chip to opt out — this is the
"re-render storm" this skill's Anti-Patterns table already names, made
concrete: 1 user action → 3 component re-renders where 1 was correct.

---

## Mitigation 1: Memoize the Value Object

```tsx
const value = useMemo(
  () => ({ status, setStatus, owner, setOwner, dateRange, setDateRange }),
  [status, owner, dateRange],
);
return <FiltersContext.Provider value={value}>{children}</FiltersContext.Provider>;
```

**What this fixes, and what it doesn't.** `useMemo` stops the object
reference from changing when `FiltersProvider` re-renders for a reason
*unrelated* to `status`/`owner`/`dateRange` (a parent re-render, an
unrelated sibling state change bubbling through). It does **not** fix the
three-chips-re-render-on-one-change problem above — `status`, `owner`,
and `dateRange` are still three fields on **one** memoized value, so any
one of them changing still produces a new memoized object (correctly —
one of its dependencies changed) and still re-renders every consumer of
that one Context. Memoizing the value is the fix for phantom re-renders
from an unrelated cause; it is not a fix for genuinely-coupled fields
sharing one Context.

---

## Mitigation 2: Split Into Narrower Contexts

The real fix for the three-chips case: the three filters were never one
piece of state — they're independent, so give each its own Context:

```tsx
// DO: three narrow contexts; a chip subscribes to only the one it reads
<StatusContext.Provider value={statusValue}>
  <OwnerContext.Provider value={ownerValue}>
    <DateRangeContext.Provider value={dateRangeValue}>
      {children}
    </DateRangeContext.Provider>
  </OwnerContext.Provider>
</StatusContext.Provider>
```

Now changing `dateRange` only re-renders `DateRangeContext`'s consumers —
`StatusFilterChip` and `OwnerFilterChip` read a Context whose value
didn't change and don't re-render at all. Split along the same lines the
data was never coupled on in the first place: if two fields always change
together for the same reason, they can stay one Context; if they change
for independent reasons (as here — three independent user actions), they
get independent Contexts.

---

## Mitigation 3: Escalate to a Selector-Based Store

Context-splitting stops paying off once the consumer set is large (dozens
of chips, not three) or values change at high frequency (every keystroke,
not every filter click) — at that point even a narrowly-split Context's
per-consumer re-render cost adds up faster than a selector-based store's
subscription model. This is the exact trigger `SKILL.md`'s Client-State
Library table already names: escalate to Zustand, where each consumer
subscribes to a slice and re-renders only when that slice's value changes,
regardless of how many other fields the store holds or how often they
change:

```ts
const useFiltersStore = create<FiltersState>((set) => ({
  status: null, owner: null, dateRange: null,
  setStatus: (s) => set({ status: s }),
  // ...
}));

const status = useFiltersStore((s) => s.status); // re-renders only when `status` changes, however large the store
```

There is no fourth tier past this — a selector-based store is the ceiling
for client state within one fragment (`SKILL.md`'s escalation table); past
that, the state either belongs in TanStack Query (it wasn't client state
to begin with) or the component boundary itself needs reconsidering.

---

## Choosing Among the Three

| Symptom | Fix | Cost |
|---|---|---|
| Consumers re-render on a Provider re-render even when the fields they read didn't change, but genuinely-related fields belong together | Memoize the value object (Mitigation 1) | Cheapest — one `useMemo`, no structural change |
| A handful of independent fields share one Context and re-render each other's consumers | Split into narrower Contexts (Mitigation 2) | Low — more Providers, same mental model, no new dependency |
| Many consumers, high update frequency, or the consumer set will keep growing | Selector-based store (Mitigation 3) | Highest — a new dependency (Zustand/Jotai), justified only once the first two stop paying off |

Apply them in this order — reach for a store first only when co-location
and Context have already been tried and named as insufficient, per
`SKILL.md`'s "escalate only when justified" rule; jumping straight to
Mitigation 3 for a three-chip filter bar is over-engineering the same way
reaching for Redux for a single modal's open state is.
