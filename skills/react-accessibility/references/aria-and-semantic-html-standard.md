# ARIA and Semantic HTML — Full Standard

Self-contained reference for `react-accessibility`. States the First
Rule of ARIA precisely, the decision procedure for when ARIA is
genuinely needed versus when native HTML alone suffices, and the exact
WCAG success criteria this standard satisfies.

---

## 1. The First Rule of ARIA — Precise Statement

> If a native HTML element or attribute already has the semantics and
> behaviour you need, **use it** — do not re-purpose a different
> element and add an ARIA role, state, or property to make it
> accessible. ARIA can only *describe* a widget's semantics to
> assistive technology; it cannot grant the keyboard behaviour,
> focusability, or built-in interaction handling that a native element
> provides for free. ARIA is a patch for gaps native HTML genuinely
> cannot express — not a general-purpose substitute for choosing the
> right element.

This is the WAI-ARIA specification's own stated first rule, not an
in-repo convention — it is the standard every ARIA Authoring Practice
pattern below assumes as a precondition. Concretely: `role="button"`
on a `div` announces the *role* "button" to a screen reader, but grants
none of `<button>`'s native behaviour — Enter/Space activation,
inclusion in the Tab order, disabled-state handling, form submission
on Enter. Every one of those has to be hand-built and kept in sync by
the author, and every omission is a silent accessibility regression
`<button>` would never have allowed.

## 2. Native Element First — Decision Table

| Need | Use the native element | Never |
|---|---|---|
| Clickable action | `<button>` | `<div role="button" tabindex="0" onClick>` |
| Navigation to another view/URL | `<a href>` | `<div role="link" onClick>` |
| Page structure/landmarks | `<nav> <main> <header> <footer> <aside>` | `<div className="nav">` with no landmark role |
| Tabular data | `<table><th scope>` | `<div role="grid">` reproducing a data table |
| Form field + its label | `<label htmlFor>` + `<input>` | placeholder-as-label, or a bare `<input>` with no associated label |
| Grouped form controls | `<fieldset><legend>` | a `<div>` wrapper with a visually-styled heading and no `<legend>` |
| Disabled control | native `disabled` attribute | `aria-disabled` alone on an element still in the Tab order and still firing click handlers |

The pattern in every row is the same: the native element carries
behaviour and semantics as a unit. Reproducing only the visual
appearance and bolting on a `role` reproduces neither.

## 3. When ARIA Fills a Genuine Gap

ARIA is correct — required, even — for widget patterns HTML has no
native element for. Follow the WAI-ARIA Authoring Practices (APG)
pattern for each exactly; a half-implemented pattern (the role with
none of the accompanying states/keyboard contract) is a false promise
to assistive technology, arguably worse than no ARIA at all:

| Widget with no native equivalent | ARIA pattern |
|---|---|
| Tabs | `role="tablist"`/`"tab"`/`"tabpanel"`, `aria-selected`, roving `tabindex` — see `references/keyboard-and-focus-management.md` §2 |
| Combobox / autocomplete | `role="combobox"` + `aria-expanded`, `aria-controls`, `aria-activedescendant` on the input |
| Tree view | `role="tree"`/`"treeitem"`, `aria-expanded`, `aria-level` |
| Toast / status announcement | `aria-live="polite"`/`"assertive"` region (no native element announces dynamic text) |
| Modal dialog | `role="dialog"` (or `"alertdialog"`), `aria-modal="true"`, `aria-labelledby` pointing at the visible heading |
| Custom checkbox/switch visual (rare — prefer native `<input type="checkbox">` styled with CSS) | `role="switch"`/`"checkbox"` + `aria-checked` only if the native input genuinely cannot be styled to the required visual, which is rare |

## 4. WCAG Success Criteria This Standard Satisfies

| SC | Level | What it requires |
|---|---|---|
| 1.3.1 Info and Relationships | A | Structure and relationships conveyed visually (a label next to a field, a heading over a section) are also conveyed programmatically — the reason `<label htmlFor>`, `<fieldset><legend>`, and heading hierarchy matter, not just `<div>`s styled to look the part |
| 4.1.2 Name, Role, Value | A | Every UI component has a programmatically determinable name, role, and (where applicable) state/value, and changes to these are exposed to assistive technology — the SC a `role="button"`-without-a-name violates directly |
| 2.5.3 Label in Name | AA | A component's accessible name contains the visible label text verbatim — an icon button labelled `aria-label="Close"` next to visible text "Dismiss" fails this; keep the visible text and the accessible name in sync |

## 5. Verification

- **`jest-axe`** catches missing accessible names, invalid ARIA
  attribute/role combinations, and several 4.1.2 violations
  automatically — see `react-component-testing` for the assertion
  pattern.
- **`getByRole(role, { name })`** in a Testing Library query is a
  direct proof of 4.1.2: if the query can find the element, the
  element has a computed role and accessible name; if it can't, neither
  can a screen reader, regardless of what the DOM visually renders.
- **Manual**: turn on a screen reader (VoiceOver, NVDA) and confirm
  each custom widget announces its role, state, and any change to that
  state (`aria-expanded` toggling, `aria-selected` moving) — automated
  tools do not verify that ARIA *state* is kept in sync at runtime,
  only that it is present and valid at render time.
