# Keyboard Operability and Focus Management — Full Standard

Self-contained reference for `react-accessibility`. Deepens the SKILL.md
body's keyboard/focus tables into the exact, checkable behaviour a
reviewer verifies for every custom widget and every focus-changing
transition (modal open/close, route change, async load, validation
error).

---

## 1. Keyboard Operability — WCAG Success Criteria

| SC | Level | Requirement |
|---|---|---|
| 2.1.1 Keyboard | A | Every function operable through a keyboard interface, with no path that requires a specific timing of individual keystrokes |
| 2.1.2 No Keyboard Trap | A | If focus can move into a component via keyboard, it can move out using only the keyboard (Tab/Shift+Tab, or a documented method announced to the user) |
| 2.4.3 Focus Order | A | A sequential keyboard navigation order that preserves meaning and operability — follows the visual/reading order |
| 2.4.7 Focus Visible | AA | Any keyboard-operable UI has a mode of operation where the keyboard focus indicator is visible |

A component that satisfies all four is "keyboard operable" in the sense this standard means. Missing any one is a defect, not a stylistic gap.

## 2. Custom Widget Keyboard Contracts

Each pattern below is the WAI-ARIA Authoring Practices contract for that widget. Follow it exactly — a half-implemented contract (arrow keys but no Home/End, Escape but no focus restore) is worse than the native element it's replacing would have been.

| Widget | Keyboard contract |
|---|---|
| Tabs | Arrow Left/Right moves selection between tabs; Home/End jump to first/last; Tab moves focus *out* of the tablist to the active panel |
| Menu / menu button | Arrow Down opens and moves into the menu; Arrow Up/Down moves between items; Escape closes and returns focus to the trigger; typeahead (typing a letter) jumps to a matching item |
| Combobox / autocomplete | Arrow Down/Up moves through suggestions without leaving the input; Enter selects the highlighted suggestion; Escape closes the listbox without altering the input's committed value |
| Modal / dialog | Tab/Shift+Tab cycle only within the modal (focus trap, §3); Escape closes; focus returns to the trigger on close (§4) |

## 3. The Focus-Trap Effect — Preserved Verbatim

This effect was confirmed textbook-correct by a prior discovery pass (matches the "run once, clean up on unmount" pattern a hooks-era React reference book uses as its canonical `useEffect` teaching example — an empty dependency array is correct here because the effect intentionally runs once on mount, refs are exempt from exhaustive-deps since a ref's identity is stable, and the cleanup restores focus on unmount). Do not alter its substance:

```tsx
// Modal: trap + restore (from ui-component-spec ClassificationModal a11y)
useEffect(() => {
  const prev = document.activeElement as HTMLElement;
  firstFieldRef.current?.focus();
  return () => prev?.focus();        // restore focus to the trigger on unmount
}, []);
```

## 4. Focus-Return-on-Close — the Exact Behaviour

The effect above captures `document.activeElement` at the instant the modal mounts — this is, by construction, the element that triggered the modal's opening (the button the user clicked, the row they activated). The standard this repo enforces:

- **Focus returns to the triggering element specifically — never to `document.body`.** A close handler that merely calls `.blur()` or does nothing drops focus to the document body, which is a silent "focus reset to nowhere" from a keyboard/screen-reader user's perspective — they lose their place in the page entirely.
- **Capture the trigger reference at open time, not at close time.** By the time the modal is closing, `document.activeElement` is usually an element *inside* the modal (the button just clicked to submit/cancel) — capturing it then would restore focus to the wrong place. The effect above gets this right specifically because it reads `document.activeElement` in the effect body, which runs once on mount (before the modal has any internal focusable content to steal `document.activeElement`'s value).
- **If the trigger element has been unmounted while the modal was open** (e.g. the row it lived in was deleted by the same action that closed the modal), fall back to the nearest stable landmark — the page's `<h1>` or the container that used to hold the trigger — never let focus silently fall through to `<body>`. Guard the restore: `if (document.body.contains(prev)) prev.focus(); else fallbackRef.current?.focus();`.

## 5. Tab-Order Management

- **The modal container itself gets `tabIndex={-1}`.** This makes the container a legitimate *programmatic* focus target (a screen reader can be told "focus moved to this dialog") without inserting it into the natural Tab sequence — `-1` means "focusable via `.focus()` calls, not via Tab." This is the one legitimate use of a non-zero `tabIndex` alongside a ref-based programmatic focus call.
- **Never use a positive `tabIndex`.** `tabIndex="1"`+ creates a shadow tab order that fights DOM order; the only legitimate values are `0` (join the natural order) and `-1` (programmatic-only target, as above).
- **The trap cycles only the modal's own focusable descendants.** Tab from the last focusable element wraps to the first; Shift+Tab from the first wraps to the last. Compute the focusable set at trap-activation time (`querySelectorAll` against the standard focusable-selector list — links with `href`, buttons, form fields, elements with `tabindex >= 0`) rather than hard-coding which fields exist, so the trap survives a spec change to the modal's contents without a second edit.
- **Route changes get the same non-`body` treatment**: move focus to the new page's `<h1>` or main landmark (`mainRef.current?.focus()` with `tabIndex={-1}` on `<main>`), not to `document.body`, and not silently left wherever it was on the old page.

## 6. Verification

- **Automated (`jest-axe`) does not catch focus management** — axe checks static accessibility-tree properties, not runtime focus transitions. A modal can pass every axe assertion and still fail to trap or restore focus.
- **Assert focus behaviour directly with Testing Library + `user-event`**: render the trigger and modal together, `await user.click(trigger)`, assert `document.activeElement` is inside the modal; `await user.tab()` repeatedly and assert focus never leaves the modal's descendant set; `await user.keyboard("{Escape}")` and assert `document.activeElement === trigger`. See `react-component-testing` for the query and assertion conventions these tests share with every other component test.
- **Manual keyboard-only pass** for every modal/menu/combobox before it ships: Tab in, confirm the trap, Escape out, confirm focus lands exactly on the trigger — not "somewhere on the page."
