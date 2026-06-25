---
name: react-accessibility
description: >
  Teaches how to build and verify WCAG 2.1 AA accessible React UIs — semantic HTML
  first, ARIA only when needed, keyboard operability, focus management (modals,
  routing), accessible forms and error messaging, colour-contrast and
  not-colour-alone rules, accessible names, live regions, and automated +
  manual a11y testing (axe, role/label queries). Implements the accessibility
  requirements from each ui-component-spec. Used by the frontend-engineer during
  Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, accessibility, wcag, aria, keyboard, axe]
---

# React Accessibility

## Purpose

Accessibility is a requirement, not a polish step. Every `ui-component-spec` (Chunk 10) carries WCAG 2.1 AA requirements; this skill implements and verifies them. The target is concrete: a keyboard-only user and a screen-reader user can complete every flow the product supports. Accessibility also makes the UI more robust for everyone and is part of the product's compliance posture.

The blueprint's testing rule drives the approach: tests query by **role and label** (`getByRole`, `getByLabelText`), so building accessibly and testing accessibly are the same activity.

---

## Semantic HTML First, ARIA Second

The first rule of ARIA is: don't use ARIA if a native element does the job. Native elements come with behaviour, focus, and semantics for free.

| Use the native element | Not a div with ARIA |
|---|---|
| `<button>` | `<div role="button" tabindex="0" onClick>` |
| `<a href>` | `<div role="link" onClick>` |
| `<nav> <main> <header>` | `<div className="nav">` |
| `<table><th scope>` | `<div role="grid">` |
| `<label htmlFor>` + `<input>` | placeholder-as-label |

ARIA is for the gaps native HTML can't express (custom widgets: tabs, comboboxes, the graph fallback). When you do use it, follow the WAI-ARIA Authoring Practices for that pattern exactly.

---

## Keyboard Operability

Everything that works with a mouse works with a keyboard — WCAG 2.1.1.

- **Logical tab order** follows visual order (don't fight the DOM order with `tabindex` > 0).
- **Custom widgets implement their keyboard contract**: tabs (arrow keys), menus (arrows + Escape), modals (Tab trap + Escape), comboboxes (arrows + Enter).
- **Visible focus indicator** — never `outline: none` without a stronger replacement. Focus must always be visible.
- **No keyboard traps** — focus can always move on (except a deliberately trapped modal, which Escape releases).

```tsx
// A custom interactive element gets the full button contract — or just use <button>.
<button type="button" onClick={onClassify}>Classify</button> // free focus, Enter/Space, role
```

---

## Focus Management

Focus is where keyboard and screen-reader users "are." Manage it at transitions:

| Transition | Focus behaviour |
|---|---|
| Modal opens | Move focus into the modal (first field/heading); trap within; restore to the trigger on close |
| Route change (SPA) | Move focus to the new page's `<h1>` / main; announce the page (no automatic focus loss to `<body>`) |
| Async content loaded | Move focus or announce via a live region if context changed |
| Validation error | Move focus to the first invalid field (or a summary) |

```tsx
// Modal: trap + restore (from ui-component-spec ClassificationModal a11y)
useEffect(() => {
  const prev = document.activeElement as HTMLElement;
  firstFieldRef.current?.focus();
  return () => prev?.focus();        // restore focus to the trigger on unmount
}, []);
```

SPA routing breaks the browser's native focus reset — `react-routing` transitions must restore focus explicitly.

---

## Accessible Forms and Errors

- Every input has a programmatic **label** (`<label htmlFor>` or `aria-label`/`aria-labelledby`).
- **Errors are associated** with their field via `aria-describedby` and announced; `aria-invalid` marks the field.
- Error summaries use `role="alert"` so they're announced immediately (mirrors the backend's validation-error envelope — see `react-api-client`).
- Required fields are marked both visually and with `aria-required`.

```tsx
<label htmlFor="sensitivity">Sensitivity level</label>
<select id="sensitivity" aria-invalid={!!error} aria-describedby={error ? "sensitivity-err" : undefined}>…</select>
{error && <p id="sensitivity-err" role="alert">{error.message}</p>}
```

---

## Colour and Contrast

- **Text contrast ≥ 4.5:1** (≥ 3:1 for large text); UI component/graphics contrast ≥ 3:1 — WCAG 1.4.3 / 1.4.11.
- **Never colour alone** to convey meaning (WCAG 1.4.1). A sensitivity badge uses colour **and** text; a chart series uses colour **and** label/pattern; an error uses colour **and** an icon **and** text.
- Respect `prefers-reduced-motion` — gate non-essential animation/transitions.

```tsx
<SensitivityBadge level="Restricted" /> // renders the word "Restricted" + colour + icon, not colour alone
```

---

## Accessible Names and Live Regions

- Every interactive element and image has an **accessible name** (visible label, `aria-label`, or `alt`). Icon-only buttons need an `aria-label`.
- **Live regions** (`aria-live="polite"`/`"assertive"`) announce dynamic changes a sighted user would see: "Asset classified", "3 results", toast notifications.
- Decorative images/icons are hidden from AT (`aria-hidden="true"` / empty `alt`).

---

## The Graph and Charts

The estate graph (WebGL) and charts are inaccessible by default; each ships an equivalent accessible representation:
- Graph → a navigable list/tree of the same nodes/edges (see `react-graph-visualization`).
- Chart → a text summary + data table alternative (see `react-dashboard-components`).

The visual is an enhancement; the data is always reachable without sight.

---

## Testing Accessibility

Two layers, both required:

### Automated (catches ~30–40%)
- **`jest-axe` / `axe-core`** assertion in component tests — fails on violations.
- a11y lint (`eslint-plugin-jsx-a11y`) in `npm run ci`.

```tsx
it("has no a11y violations", async () => {
  const { container } = render(<ClassificationModal {...props} />);
  expect(await axe(container)).toHaveNoViolations();
});
```

### Behavioural (catches the rest)
- Tests **query by role/label** (`getByRole("button", { name: /classify/i })`, `getByLabelText`) — if a test can't find an element by its accessible name, neither can a screen reader. This makes every component test an accessibility test (see `react-component-testing`).
- Manual keyboard-only and screen-reader passes for key flows.

Automated tools are necessary but not sufficient — role/label-based tests and manual checks cover what axe can't.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Semantic first | Native elements; ARIA only for gaps | `div`s with bolted-on ARIA reinventing buttons |
| Keyboard operable | Every action keyboard-reachable; visible focus | Mouse-only controls; `outline:none` |
| Focus managed | Modal trap/restore; route focus reset | Focus lost to `<body>` on navigation; no modal trap |
| Forms labelled | Programmatic labels; errors associated + announced | Placeholder-as-label; silent errors |
| Not colour-alone | Meaning via text/icon + colour; contrast met | Colour-only status; failing contrast |
| Accessible names | All controls/images named; live regions announce | Icon buttons unnamed; silent dynamic updates |
| Tested | axe clean + role/label queries + manual passes | No a11y tests; query by test-id only |

---

## Output Format

Produces accessible components and a11y tests (woven into component tests, written first):

```
src/shared/ui/*.tsx                 (semantic, ARIA-correct primitives)
src/**/__tests__/*.a11y.test.tsx     (jest-axe + role/label queries)
.eslintrc.cjs                        (jsx-a11y rules)
```
