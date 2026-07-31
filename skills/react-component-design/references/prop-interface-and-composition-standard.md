# Prop-Interface Design and Composition-Pattern Selection — Full Standard

The two standards `SKILL.md` states as rules and tables, expanded here with
worked rationale and edge cases. Read `SKILL.md` first for the summary
form; this file is for the reviewer or author who needs the full argument,
not just the rule.

---

## Part 1 — Prop-Interface Design Standard

### 1.1 Every prop interface is a plain `interface`, never `React.FC`

```tsx
// ✅ — plain typed function, explicit props interface
interface SensitivityBadgeProps {
  readonly level: SensitivityLevel;
}
function SensitivityBadge({ level }: SensitivityBadgeProps) { /* … */ }

// ❌ — React.FC obscures the props type in the signature, historically
// implied an implicit `children` prop even when the component takes none,
// and adds nothing a plain typed function doesn't already give you.
const SensitivityBadge: React.FC<SensitivityBadgeProps> = ({ level }) => { /* … */ };
```

Props are `readonly` — a prop reassigned inside the component body is
almost always a bug (the value should have been derived into a local
`const`, or the reassignment belongs in a parent's state instead). Arrays
in props are `ReadonlyArray<T>`, not `T[]`, for the same reason: a
component that `.push()`es onto a prop array is mutating something it
doesn't own.

### 1.2 Discriminated unions for variant props — invalid states unrepresentable

A component with two or more mutually exclusive "modes" gets a
discriminated union keyed on a literal `variant`/`kind`/`type` field, never
a flat interface with several optional fields that happen to correlate:

```tsx
// ❌ — every field optional; nothing stops `{ variant: "link", onClick }`
// (a link with a click handler and no href) or `{ variant: "button" }`
// with neither onClick nor href — both compile, both are wrong at runtime.
interface ButtonProps {
  variant?: "button" | "link";
  onClick?: () => void;
  href?: string;
}

// ✅ — a discriminated union: TypeScript narrows on `variant` and refuses
// to compile the invalid combination. There is no runtime check needed
// for "a link must have an href" — the type system already forbids
// constructing the invalid shape.
type ButtonProps =
  | { readonly variant: "button"; readonly onClick: () => void }
  | { readonly variant: "link"; readonly href: string };

function Button(props: ButtonProps) {
  return props.variant === "link"
    ? <a href={props.href} className="btn" role="button">{/* … */}</a>
    : <button type="button" onClick={props.onClick} className="btn">{/* … */}</button>;
}
```

The test for whether a prop set needs this treatment: **can two of the
optional props be present, or both absent, in a combination that is
meaningless or ambiguous for the component to handle?** If yes, the props
aren't independent — they're a tagged variant, and the tag belongs in the
type, not just in a runtime `if`. This is the same discriminated-union
technique `typescript-types` teaches for domain modeling, applied at the
component-prop boundary instead of the domain-model boundary.

### 1.3 Required-vs-optional prop rules

A prop is optional **only if the component has a genuinely sensible
default behavior for its absence** — never "optional because most callers
happen not to pass it," which just relocates undefined behavior from a
compile error to a runtime surprise.

```tsx
interface CardProps {
  readonly title: string;               // required — no sensible "no title" rendering exists
  readonly icon?: React.ReactNode;       // optional — sensible default: render with no icon slot
  readonly onDismiss?: () => void;       // optional — sensible default: not dismissible at all
  readonly children: React.ReactNode;    // required — a Card with no body isn't a smaller Card, it's a bug
}
```

Two failure modes this rule rejects:

- **Optional-with-no-stated-default** — a prop typed `foo?: string` where
  the component's behavior when `foo` is `undefined` is never decided, just
  whatever the first `if (foo)` branch happens to fall through to. Decide
  the default explicitly (a default parameter, a documented fallback
  render) before marking the prop optional.
- **Required props with a fake default smuggled in** — marking a prop
  required and then giving it a default value in destructuring anyway
  (`{ variant = "primary" }: Props` where `Props.variant` is *not*
  optional) is a type lie: the type says every caller must pass it, the
  code says most won't need to. If there's a sensible default, the prop is
  optional in the type, full stop.

Set `exactOptionalPropertyTypes` (per `react-project-structure`'s strict
TypeScript family) so that `foo?: string` genuinely means "may be
omitted," not "may be omitted or explicitly passed as `undefined`" — those
are different contracts a caller can otherwise satisfy either way, and the
component would have to handle both.

### 1.4 Boolean props are named as a predicate, and never multiply past two

`isLoading`, `hasError`, `disabled` — a predicate name, not a bare noun. A
component accumulating three or more independent booleans
(`compact`/`bordered`/`selectable`/`withActions`) is the boolean-prop-
proliferation anti-pattern (`SKILL.md`'s Anti-Patterns) — the fix is a
single discriminated `variant` union (§1.2) if the flags are mutually
exclusive, or a Compound Component (Part 2) if they represent structural
composition rather than flags at all.

---

## Part 2 — Composition-Pattern Selection Standard (Full Decision Criteria)

| Pattern | Choose when | Do not choose when | Cost | Worked example |
|---|---|---|---|---|
| **Custom hook** | Default choice for logic reuse: data fetching, derived state, effect wiring, any behavior with no rendering opinion of its own | The reusable part must decide *what renders*, not just *what value/callback* the caller gets | None beyond an extra function — no wrapper component, no extra tree depth | `worked-examples.md` §2 (`useClassifyDataAsset`) |
| **Render prop / function-as-child** | The caller must control rendering of something the reusable part measures/manages internally (a virtualizer, a data-boundary that hands back loading/error/data as arguments) | The problem is state/effect reuse with no caller-side rendering variance — that's a hook, not a render prop | One extra JSX indirection (children-as-function reads less directly than a hook call); doesn't compose as freely as calling several hooks side by side | `worked-examples.md` §4 (`VirtualizedList`) |
| **Compound components** | Several sub-components share implicit state and a fixed, structural parent-child relationship (`Tabs`/`Tabs.List`/`Tabs.Panel`, an accordion, a stepper, a menu) — the fix for boolean-prop proliferation when the flags are really structural slots | The pieces don't have a genuine structural relationship — forcing unrelated components into a compound family just to share one value is a Context misuse, not a compound component | A small feature-private Context; every consumer re-renders on any Provider-value change unless memoized (`worked-examples.md` §3) | `worked-examples.md` §3 (`Tabs`) |
| **HOC (`withX(Component)`)** | Legacy only — reading old code, or the rare class-component-only integration surface a hook genuinely cannot reach | Any new code. Roldán and Banks & Porcello both frame HOCs as the pre-hooks answer to cross-cutting logic reuse, superseded by custom hooks: a HOC wraps a component to inject props at the cost of wrapper-hell (nested `displayName`s in DevTools) and prop-name collisions between multiple HOCs that obscure where a given prop actually came from | Wrapper depth, naming collisions, harder-to-trace DevTools tree | Not modeled in this skill — write a custom hook instead |

**How to use this table**: start at "custom hook" as the default for any
reuse problem. Move down a row only when the *specific* condition in that
row's "Choose when" column is true — not because the hook felt like too
little abstraction, and not because a pattern looks more sophisticated.
Two custom hooks side by side (`const a = useAssets(); const b =
useFilters();`) is ordinary, idiomatic code; a render prop or compound
component that could have been two hooks is unnecessary indirection.

### Recognizing a HOC or render prop already in the codebase

Migrate a HOC or a render prop used purely for state/effect sharing (not
caller-controlled rendering) to a custom hook when the surrounding code is
touched anyway — not as a mandatory standalone rewrite, but as a live
signal in code review: removing a wrapper layer and a naming-collision
risk with no behavior change is close to free the moment you're already
editing that file.

---

## Cross-Reference Accuracy Note

This file and `SKILL.md` cite `react-component-testing`, `react-
accessibility`, and `react-observability` for the testing-hook,
accessibility-baseline, and error-boundary standards this skill's
components must meet at minimum. Those three skills own the full depth —
this skill states only what a component produced here must satisfy, and
points at the owning skill's actual current sections (query-priority
table, focus-management transitions, granular error-boundary placement)
rather than restating them.
