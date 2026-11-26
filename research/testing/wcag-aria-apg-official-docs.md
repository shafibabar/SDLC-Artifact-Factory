# WCAG 2.1 and WAI-ARIA Authoring Practices
**Authors:** W3C Accessibility Guidelines Working Group; W3C WAI
**Domain:** Accessibility standards for testing

Accessed 2026-11-25. W = https://www.w3.org/TR/WCAG21/ (Recommendation, 06 May 2025). A = https://www.w3.org/WAI/ARIA/apg (unversioned). Read through a summarising fetch tool; the last part of W was not read.

## Core Concepts

### Versions (https://www.w3.org/WAI/standards-guidelines/wcag/)
2.0, 2.1 and 2.2 all remain standards; 2.2 content also conforms to 2.1; W3C recommends 2.2. 4.1.1 is obsolete in 2.2.

### Success criteria (W)

| SC | Level | Requirement (paraphrased) |
|---|---|---|
| 1.4.3 | AA | Text contrast 4.5:1; large text 3:1 |
| 1.4.11 | AA | 3:1 for visuals identifying components and states |
| 2.1.1 | A | All functionality by keyboard (path-dependent exception) |
| 2.1.2 | A | No keyboard trap |
| 2.4.3 | A | Focus order preserves meaning and operability |
| 2.4.7 | AA | Visible focus indicator |
| 4.1.2 | A | Name and role programmatically determinable; states and values settable, changes exposed |
| 4.1.3 | AA | Status messages exposed without moving focus |

### Conformance (W, 5.2 and 5.3)
Full pages, including each responsive variation; every page of a process; non-interference. Claims are optional and need date, version and URI, level, pages and technologies.

### Authoring practices
- No ARIA is better than bad ARIA; a role is a promise: `div role="button"` needs scripted keyboard behaviour (A/practices/read-me-first/).
- Button: Enter and Space; accessible name; `aria-disabled`, `aria-pressed` (A/patterns/button/).
- Modal dialog: focus moves in; Tab wraps inside; Escape closes; focus returns to the invoker; a visible close button; named; `aria-modal` only when outside content is truly blocked (A/patterns/dialog-modal/).
- Combobox: Down Arrow into popup, Escape dismisses; `aria-expanded`, `aria-controls`, `aria-activedescendant`, `aria-selected`; a select-only combobox resembles native `select` (A/patterns/combobox/).
- Keyboard: Tab between components, arrows within composites; one tab stop per composite (roving `tabindex`); no positive `tabindex`; focus never lost to body; native `disabled` leaves the tab order, `aria-disabled` keeps discoverability (A/practices/keyboard-interface/).

## Actionable Techniques (design is this note's)

1. State the target (2.1 AA) and note that 2.2 is the recommended version; the choice is the product owner's.
2. For each custom widget, write keyboard and focus tests from its pattern.
3. Report conformance only after automated and manual checks across whole processes.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-accessibility, react-component-testing, react-e2e-testing | W3D-20, 25, 35 | Criteria and keyboard expectations |

## Candidate New Skills/Agents

None.

## Key Terminology

Success criterion, Conformance level, Complete process, Roving tabindex.

## Caveats

- 2.2's changes, conformance and tool coverage are in `wcag-22-official-docs.md` (accessed 2026-11-26). The authoring practices are guidance, separate from the WCAG requirements (their normative status was not read). Pattern lists above are partial.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| W3D-25: role query does not prove keyboard use | A role adds no behaviour; 2.1.1 is separate from 4.1.2 | Confirmed |
| Component skill: role query is direct proof of 4.1.2 | 4.1.2 also covers states, values and change exposure | Overclaim confirmed |
