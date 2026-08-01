---
name: react-accessibility
description: >
  Teaches the WCAG 2.1 Level AA accessibility standard this repo enforces for
  every React UI: the First Rule of ARIA (native HTML before ARIA), the
  keyboard-operability and focus-management standard (focus-trap effect,
  focus-return-to-trigger-never-body, tab-order via tabIndex={-1}), accessible
  forms and error messaging, the exact colour-contrast ratios (4.5:1 / 3:1) and
  prefers-reduced-motion handling, accessible names and live regions, and how
  each success criterion is verified mechanically (jest-axe, Testing Library
  role/label queries — see react-component-testing). Implements the
  accessibility requirements from each ui-component-spec. Used by the
  frontend-engineer during Implement, and the accessibility minimum every
  other react-* skill (react-component-design, react-dashboard-components)
  cites.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, accessibility, wcag, aria, keyboard, axe]
produces: react-accessible-components
domain: frontend
status: stable
related: [react-component-testing, react-component-design, react-dashboard-components, react-graph-visualization]
---

# React Accessibility

## Purpose

Accessibility is a requirement, not a polish step. Every `ui-component-spec` carries WCAG requirements; this skill implements and verifies them. The target is concrete: a keyboard-only user and a screen-reader user can complete every flow the product supports. The blueprint's testing rule drives the approach: tests query by **role and label** (`getByRole`, `getByLabelText`), so building accessibly and testing accessibly are the same activity — see `react-component-testing`.

---

## Conformance Level: WCAG 2.1, Level AA

This repo targets **WCAG 2.1 Level AA**, exactly — not A, not AAA:

- **A alone is insufficient** for a real product: it omits contrast minimums (1.4.3), focus visibility (2.4.7), and several other criteria users hit constantly, not edge cases.
- **AAA is not the target** — WCAG's own guidance states AAA is not achievable for all content types (e.g. 7:1 text contrast, sign-language alternatives for all audio) and recommends AA as the general conformance target for web content; requiring AAA site-wide produces either false compliance claims or design constraints disproportionate to the benefit for arbitrary product content.
- **WCAG 2.2 (Oct 2023) is backward-compatible with 2.1** — it adds success criteria, it does not remove any 2.1 AA criterion. Meeting this repo's 2.1 AA floor is a prerequisite for 2.2 AA, not in tension with it.

Every section below states the exact success criteria it satisfies so a reviewer can check conformance criterion-by-criterion, not by vibe.

---

## Semantic HTML First: The First Rule of ARIA

**If a native element already has the semantics/behaviour you need, use it — never re-purpose a different element and bolt on ARIA to fake accessibility.** ARIA can describe a role to assistive tech; it cannot grant the keyboard handling, focusability, or built-in behaviour a native element provides for free.

| Use the native element | Not a div with ARIA |
|---|---|
| `<button>` | `<div role="button" tabindex="0" onClick>` |
| `<a href>` | `<div role="link" onClick>` |
| `<nav> <main> <header>` | `<div className="nav">` |
| `<table><th scope>` | `<div role="grid">` |
| `<label htmlFor>` + `<input>` | placeholder-as-label |

ARIA is for gaps native HTML can't express — tabs, comboboxes, tree views, live-region announcements. When you do use it, follow the WAI-ARIA Authoring Practices pattern for that widget exactly, including its keyboard contract. Full decision procedure, the complete native-vs-ARIA table, and the WCAG criteria this satisfies (1.3.1, 4.1.2, 2.5.3): `references/aria-and-semantic-html-standard.md`.

---

## Keyboard Operability and Focus Management

Everything that works with a mouse works with a keyboard (2.1.1), with no trap (2.1.2), in visual order (2.4.3), with a visible focus indicator always (2.4.7).

| Transition | Focus behaviour |
|---|---|
| Modal opens | Move focus into the modal; trap Tab/Shift+Tab within it |
| Modal closes | Restore focus to the **specific element that triggered the open** — never to `document.body` |
| Route change (SPA) | Move focus to the new page's `<h1>`/`<main>` (`tabIndex={-1}`); never leave it wherever it was |
| Async content loaded | Move focus, or announce via a live region, if context changed |
| Validation error | Move focus to the first invalid field or an error summary |

The modal container itself carries `tabIndex={-1}` — a legitimate programmatic focus target that stays out of the natural Tab sequence. Positive `tabIndex` is never legitimate.

```tsx
// Modal: trap + restore (from ui-component-spec ClassificationModal a11y) —
// confirmed textbook-correct; preserved verbatim.
useEffect(() => {
  const prev = document.activeElement as HTMLElement;
  firstFieldRef.current?.focus();
  return () => prev?.focus();        // restore focus to the trigger on unmount
}, []);
```

SPA routing breaks the browser's native focus reset — `react-routing` transitions must restore focus explicitly, with the same never-`body` rule. Full standard — custom-widget keyboard contracts, the exact focus-return guard for an unmounted trigger, and the focus-trap tab-cycling mechanics: `references/keyboard-and-focus-management.md`.

---

## Accessible Forms and Errors

- Every input has a programmatic **label** (`<label htmlFor>` or `aria-label`/`aria-labelledby`) — 1.3.1, 3.3.2.
- **Errors are associated** with their field via `aria-describedby`, and `aria-invalid` marks the field — 3.3.1.
- Error summaries use `role="alert"` so they're announced immediately (mirrors the backend's validation-error envelope — see `react-api-client`).
- Required fields are marked visually and with `aria-required`.

```tsx
<label htmlFor="sensitivity">Sensitivity level</label>
<select id="sensitivity" aria-invalid={!!error} aria-describedby={error ? "sensitivity-err" : undefined}>…</select>
{error && <p id="sensitivity-err" role="alert">{error.message}</p>}
```

---

## Colour Contrast and Motion Reduction

- **Text contrast ≥ 4.5:1** (≥ 3:1 for large text, ≥18pt regular or ≥14pt bold) — 1.4.3. **UI component/graphic contrast ≥ 3:1** — 1.4.11.
- **Never colour alone** to convey meaning — 1.4.1. A badge uses colour **and** text; a chart series uses colour **and** label; an error uses colour **and** an icon **and** text.
- **Honour `prefers-reduced-motion`** for any animation/transition this app ships — not strictly mandated at AA (2.3.3 sits at AAA) but adopted here as required practice regardless; gate CSS transitions via the media query and JS-driven motion via a hook.

Exact ratios, verification tooling, and the `prefers-reduced-motion` implementation (CSS media query + hook): `references/contrast-and-motion-standard.md`.

---

## Accessible Names and Live Regions

- Every interactive element and image has an **accessible name** (visible label, `aria-label`, or `alt`) — 4.1.2. Icon-only buttons need an `aria-label`.
- **Live regions** (`aria-live="polite"`/`"assertive"`) announce dynamic changes a sighted user would see ("Asset classified", a toast) — 4.1.3. The region must exist in the DOM **before** its content changes, or the announcement is lost.
- Decorative images/icons are hidden from AT (`aria-hidden="true"` / empty `alt`) — never on focusable content.

---

## The Graph and Charts

The estate graph (WebGL) and charts are inaccessible by default; each ships an equivalent accessible representation, not an afterthought:
- Graph → a navigable list/tree of the same nodes/edges (see `react-graph-visualization`).
- Chart → a text/table alternative with the same data points, not a placeholder (see `react-dashboard-components`'s `chart-accessibility-standard.md`, which cites this skill for the underlying 1.4.1/1.4.11 rules it applies).

---

## Testing Accessibility

Two layers, both required — full stack, TDD flow, and query-priority table owned by `react-component-testing`; this skill states only what each layer must assert:

- **Automated (`jest-axe`)** — catches missing accessible names, invalid ARIA, and text-contrast violations (~30–40% of issues); does not catch focus management, `prefers-reduced-motion` handling, or non-text (1.4.11) contrast.
- **Behavioural (Testing Library)** — `getByRole("button", { name })`/`getByLabelText` queries are proof of 4.1.2: if a test can't find an element by its accessible name, neither can a screen reader. Focus-trap/focus-return assertions (`user.tab()`, `user.keyboard("{Escape}")`, asserting `document.activeElement`) belong here — axe cannot verify them.
- **Manual** keyboard-only and screen-reader passes for every custom widget and every focus transition before it ships.

---

## Quality Criteria

| WCAG SC | Level | Pass | Fail |
|---|---|---|---|
| 1.3.1 Info & Relationships | A | Structure conveyed programmatically (`label`, `legend`, headings) | Visual-only structure via unlabelled `div`s |
| 1.4.1 Use of Color | A | Meaning via text/icon + colour | Colour-only status (badge, chart series) |
| 1.4.3 Contrast (Minimum) | AA | Text ≥4.5:1 (≥3:1 large) | Fails ratio — verify with a contrast checker |
| 1.4.11 Non-text Contrast | AA | UI components/graphics ≥3:1 | Icon/border/focus-ring below ratio |
| 2.1.1 / 2.1.2 Keyboard | A | Every action keyboard-reachable; no trap | Mouse-only controls; focus can't escape a widget |
| 2.4.3 Focus Order | A | Tab order matches visual order | `tabindex` > 0 fighting DOM order |
| 2.4.7 Focus Visible | AA | Visible focus indicator always | `outline: none` with no replacement |
| 3.3.1 / 3.3.2 Error handling | A | Errors associated + announced; labels present | Silent errors; placeholder-as-label |
| 4.1.2 Name, Role, Value | A | `getByRole`/`getByLabelText` finds every control | Query fails — no accessible name |
| 4.1.3 Status Messages | AA | Live region announces dynamic change | Silent dynamic update |
| — | — | axe clean + role/label queries + manual passes | No a11y tests; query by test-id only |

---

## Anti-Patterns

- **ARIA as a paint job** — `role="button"` on a `div` without `tabindex`, key handlers, and focus styling. Use `<button>`.
- **Positive `tabindex`** — only `0` and `-1` are legitimate.
- **`outline: none` with no replacement** — restyle focus (`:focus-visible`), never remove it.
- **Placeholder as the only label** — vanishes on input and fails contrast; a hint, not a label.
- **Focus restored to `document.body`** — a silent "lost my place" for keyboard/AT users; restore to the specific trigger (`references/keyboard-and-focus-management.md` §4).
- **Live region mounted with its message** — the region must exist before content changes, or the announcement is lost.
- **`aria-hidden` on focusable content** — a silent focus stop for keyboard users.
- **Querying by test-id** — sidesteps the accessibility tree; role/label queries keep tests honest.
- **Animation shipped with no `prefers-reduced-motion` path** — treat every transition as needing a reduced-motion gate, not a per-component judgment call.

---

## Output Format

Produces accessible components and a11y tests (woven into component tests, written first):

```
src/shared/ui/*.tsx                 (semantic, ARIA-correct primitives)
src/shared/hooks/usePrefersReducedMotion.ts
src/**/__tests__/*.a11y.test.tsx     (jest-axe + role/label + focus assertions)
.eslintrc.cjs                        (jsx-a11y rules)
```
