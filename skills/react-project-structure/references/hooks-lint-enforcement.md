# Rules of Hooks — Mechanical Enforcement Standard

The exact `eslint-plugin-react-hooks` configuration every fragment's
`eslint.config.js` carries, what each of its two rules mechanically
catches, and — just as important — what neither rule catches. Grounded in
Banks & Porcello's *Learning React*
(`research/frontend-engineering/learning-react-banks-porcello.md`), which
explains *why* the Rules of Hooks exist (React tracks each hook call by
its position in an ordered per-component call list — call order, not
naming, is the actual mechanism), not just that they exist. Self-contained
— loadable without reading `SKILL.md` first.

---

## The Exact Configuration

```js
// eslint.config.js (excerpt) — identical in the shell and every remote
import reactHooks from "eslint-plugin-react-hooks";

export default [
  {
    plugins: { "react-hooks": reactHooks },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
    },
  },
];
```

Two rules, two different severities, for two different reasons — treating
them as interchangeable ("hooks linting is on") misses the point of why
each is set the way it is.

## Why React Needs a Call-Order Rule At All

React does not identify a piece of state by name — it identifies each
hook call by its **position** in the ordered list of hook calls a
component makes on a given render. `useState`'s second call in one render
must be the second `useState` call in every render of that same component
instance, or React hands back the wrong state cell (or crashes outright
when the count itself changes). A hook called inside an `if`, a loop, or
after an early `return` changes how many hook calls happen on some
renders and not others — this is the actual mechanism the rule below
protects, not an arbitrary style preference.

## `rules-of-hooks` — `error` — What It Mechanically Catches

Build-breaking, not advisory. Every one of these patterns fails lint:

```tsx
// CAUGHT — hook called conditionally
function Widget({ isEnabled }: Props) {
  if (isEnabled) {
    const [value, setValue] = useState(0); // rules-of-hooks: error
  }
  // ...
}

// CAUGHT — hook called inside a loop
function List({ items }: Props) {
  items.forEach(() => {
    useEffect(() => { /* ... */ }, []); // rules-of-hooks: error
  });
}

// CAUGHT — hook called after an early return
function Panel({ data }: Props) {
  if (!data) return null;
  const [open, setOpen] = useState(false); // rules-of-hooks: error
}

// CAUGHT — hook called from a plain (non-component, non-hook) function
function formatLabel(id: string) {
  const value = useContext(LabelContext); // rules-of-hooks: error — not a component or a hook
  return value[id];
}

// CAUGHT — hook called from a nested function inside a component
function Form() {
  function handleSubmit() {
    const [x] = useState(0); // rules-of-hooks: error — nested function, not top level
  }
}
```

The rule's static analysis is purely structural: it checks *where* in the
code a hook call appears (top level of a function whose name is
capitalized like a component, or a function whose name starts with `use`)
— not what the hook does, not what it's called with, not whether the
resulting behavior is correct. This is exactly why it can run as a fast,
deterministic lint pass with zero false negatives on the call-order class
of bug: the check is about *shape*, and shape is syntactically decidable.

## `exhaustive-deps` — `warn` — What It Mechanically Catches

Flags a `useEffect`/`useMemo`/`useCallback` dependency array that omits a
reactive value the function body actually reads:

```tsx
// FLAGGED — effect reads `userId` but doesn't declare it
function Profile({ userId }: Props) {
  useEffect(() => {
    fetchUser(userId); // exhaustive-deps: warn — userId used but not in deps below
  }, []); // should be [userId]
}
```

This is a **warning**, deliberately, not an error — the rule cannot know
that an omission is genuinely safe. React itself guarantees a `dispatch`
function returned by `useReducer` (and a `setX` setter from `useState`) is
referentially stable for the component's whole lifetime; omitting one of
these from a dependency array is correct, not a bug, and the rule cannot
distinguish that case from a real omission by inspection alone. Per this
skill's Anti-Patterns table, a deliberate omission gets a one-line comment
naming *why* it's safe — never a bare `// eslint-disable-next-line` with
no explanation, which hides the next, genuinely unsafe omission behind an
identical-looking suppression.

## What Neither Rule Catches — the Boundary a Reviewer Must Still Check

Both rules verify **shape**: call order for `rules-of-hooks`, and
dependency-array completeness for `exhaustive-deps`. Neither rule — and
no ESLint rule ever could — verifies that what a hook's body actually
*does* is correct. Two concrete cases that pass both rules cleanly while
still being wrong:

```tsx
// PASSES both rules — call order is correct, every dependency is declared —
// and is still a semantically wrong effect: the range calculation has an
// off-by-one that excludes the end date, but the dependency array is complete
// and the hook is called unconditionally at the top level.
function useDateRange(start: Date, end: Date) {
  useEffect(() => {
    const days = daysBetween(start, end) - 1; // WRONG — should not subtract 1
    reportRangeLength(days);
  }, [start, end]); // exhaustive-deps has nothing to flag — this is complete
}
```

```tsx
// PASSES both rules — a hook called correctly, at the top level, with a
// complete dependency array — that subscribes to the wrong event entirely.
function useConnectionStatus(socket: Socket) {
  useEffect(() => {
    socket.on("connect", handleDisconnect); // WRONG event name, right shape
    return () => socket.off("connect", handleDisconnect);
  }, [socket]);
}
```

Neither example has a call-order violation or a missing dependency — both
lint clean. The bug in each is in what the effect *computes* or *which
event it binds*, which is business logic, not hook mechanics. This class
of bug is caught by behavior-level tests (`react-component-testing`), not
by lint — mechanical enforcement and test coverage are complementary
layers, not substitutes for each other, and neither rule should be
mistaken for "the hook is correct" beyond "the hook is structurally
sound."

## How a Reviewer Verifies This Mechanically

1. Run the lint step (`npm run lint` / the CI `eslint .` gate) and confirm
   **zero** `react-hooks/rules-of-hooks` violations — this is
   build-blocking by design; a violation here means the PR does not merge,
   full stop.
2. Triage every `react-hooks/exhaustive-deps` warning individually — do
   not treat a clean `npm run lint` exit code as proof there are no
   `exhaustive-deps` warnings; warnings do not fail the build by default,
   so they must be read, not just tolerated.
3. For every warning suppressed with `// eslint-disable-next-line
   react-hooks/exhaustive-deps`, confirm a same-line or next-line comment
   names the specific reason the omission is safe (a React-guaranteed-
   stable identity, most commonly). A bare suppression with no comment is
   an audit failure — flag it in review the same way an unexplained `any`
   would be.
4. For the semantic-correctness class neither rule reaches (wrong
   computation, wrong event name, subtly incorrect condition), verify
   there is a corresponding behavior-level test asserting the effect's
   actual observable outcome (`react-component-testing`) — a hook that
   lints clean with no test covering its actual behavior has only been
   verified at the shape level, not the correctness level.
