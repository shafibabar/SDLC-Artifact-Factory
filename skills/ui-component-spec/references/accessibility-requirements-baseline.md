# Accessibility Requirements Baseline

The WCAG 2.1 AA criteria every component spec's Accessibility section
checks against. Self-contained — loadable without reading `SKILL.md`
first. Every accessibility row in a spec cites its specific success
criterion — "must be accessible" with no testable criterion is not a
spec.

| Requirement | WCAG 2.1 AA criterion | Implementation |
|---|---|---|
| Keyboard navigation | 2.1.1 Keyboard, 2.1.2 No Keyboard Trap | Tab order follows visual order; all actions reachable by keyboard; focus can always leave the component |
| Visible focus | 2.4.7 Focus Visible | Every interactive element has a visible focus indicator — never `outline: none` without a replacement |
| Screen reader | 1.3.1 Info and Relationships, 4.1.2 Name Role Value | Semantic structure (`<th scope="col">`, `aria-label`, `aria-sort`) conveys what's visually implied |
| Focus management | 2.4.3 Focus Order | After a modal/overlay opens, focus moves to its first interactive element; on close, focus returns to the trigger |
| Colour contrast | 1.4.3 Contrast (Minimum), 1.4.11 Non-text Contrast | Normal text ≥ 4.5:1; large text (≥ 24px, or ≥ 18.66px bold) ≥ 3:1; non-text UI parts (badge boundaries, icons, focus indicators, input borders) ≥ 3:1 |
| Colour independence | 1.4.1 Use of Color | Status/level is never conveyed by colour alone — text always accompanies it |
| Loading state | 4.1.3 Status Messages | `aria-busy="true"` during loading; a polite live region announces the loading state |
| Error state | 4.1.3 Status Messages, 3.3.1 Error Identification | Error message has `role="alert"` so screen readers announce it immediately; the field in error is identified in text |
| Reflow | 1.4.10 Reflow | Component remains usable at 320px width / 400% zoom without two-dimensional scrolling (data tables may scroll horizontally as an allowed exception) |

Every component spec's Accessibility section picks the rows that apply to
that component (a presentational Atom like `SensitivityBadge` needs
Colour contrast/independence; an interactive Organism like
`ClassificationModal` needs most of the table) — not every row applies to
every component, but every row that applies must be present, cited, and
implemented, not asserted.
