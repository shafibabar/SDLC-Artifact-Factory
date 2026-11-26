# WCAG 2.2 and Its Tool Coverage
**Authors:** W3C Accessibility Guidelines Working Group; W3C WAI; Deque Systems (axe-core); Microsoft (Playwright)
**Domain:** Accessibility standards for testing

Accessed 2026-11-26. Read through a summarising fetch tool. Nothing was run. Extends `wcag-aria-apg-official-docs.md` (2.1 criteria, ARIA practices) and `jest-axe-axe-core-official-docs.md` (jsdom limits).

| Key | Source | Version or page date |
|---|---|---|
| T | https://www.w3.org/TR/WCAG22/ | Recommendation, 12 December 2024 (dated: https://www.w3.org/TR/2024/REC-WCAG22-20241212/) |
| N | https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/ | 5 October 2023 |
| O | https://www.w3.org/WAI/standards-guidelines/wcag/ | 17 September 2026 |
| U | https://www.w3.org/WAI/WCAG22/Understanding/conformance | WCAG 2.2 |
| E | https://www.w3.org/WAI/test-evaluate/tools/selecting/ | 13 May 2024 |
| P | https://www.w3.org/WAI/test-evaluate/preliminary/ | 9 August 2023 |
| C | https://www.w3.org/WAI/standards-guidelines/act/rules/ | undated |
| R | https://raw.githubusercontent.com/dequelabs/axe-core/v4.14.1/doc/rule-descriptions.md | axe-core 4.14.1 |
| S | https://raw.githubusercontent.com/dequelabs/axe-core/v4.14.1/lib/core/utils/rule-should-run.js and `/lib/rules/target-size.json` | axe-core 4.14.1 |
| PW | https://playwright.dev/docs/accessibility-testing, `/docs/aria-snapshots`, `/docs/api/class-keyboard` | unversioned |

## Core Concepts

### Changes from 2.1 (T, N, O)
- Nine success criteria added; one removed: 4.1.1 Parsing, now obsolete with no level or requirement. Organisations bound to 2.0 or 2.1 may still need to test and report it.
- The other 2.0 and 2.1 criteria are essentially unchanged. New criteria are appended to their guideline, so numbering is stable and not grouped by level.
- Backward compatible, same conformance model: content conforming to 2.2 also conforms to 2.1 and 2.0.
- 2.2 is also ISO/IEC 40500:2025, which matches the October 2023 release; the December 2024 update was expected as a 2026 ISO edition (O).

### New success criteria (T, N; paraphrased)

| SC | Name | Level | Plain statement | Exceptions and notes |
|---|---|---|---|---|
| 2.4.11 | Focus Not Obscured (Minimum) | AA | Author content must not entirely hide the focused component | Movable content judged at initial position; user-opened content is allowed if the component can be revealed without moving focus |
| 2.4.12 | Focus Not Obscured (Enhanced) | AAA | No part of the focused component is hidden | None listed |
| 2.4.13 | Focus Appearance | AAA | Indicator area at least a 2 CSS px perimeter, with 3:1 change between focused and unfocused | Unmodified browser indicator and background |
| 2.5.7 | Dragging Movements | AA | Anything done by dragging also works with a single pointer without dragging | Essential; unmodified user agent behaviour |
| 2.5.8 | Target Size (Minimum) | AA | Pointer targets are at least 24 by 24 CSS px | Spacing (24 px circles do not intersect), equivalent control, inline, unmodified user agent size, essential or legally required |
| 3.2.6 | Consistent Help | A | Help mechanisms repeated across pages keep the same relative order | User-initiated change |
| 3.3.7 | Redundant Entry | A | Do not ask again for information within a process; fill it or offer it | Essential, security, no longer valid |
| 3.3.8 | Accessible Authentication (Minimum) | AA | No cognitive function test (such as recalling a password) without a way around it | Alternative method, assisting mechanism (password manager, paste), object recognition, personal content |
| 3.3.9 | Accessible Authentication (Enhanced) | AAA | As 3.3.8 | Only the alternative or the assisting mechanism |

By level: A 2 (3.2.6, 3.3.7); AA 4 (2.4.11, 2.5.7, 2.5.8, 3.3.8); AAA 3.

### Conformance (T section 5; U)
- Only normative content creates requirements.
- A level requires all its criteria and those of lower levels, or a conforming alternate version.
- Full pages only, including each responsive variation; every page of a complete process; only accessibility-supported uses of technology relied upon.
- Non-interference: 1.4.2, 2.1.2, 2.2.2 and 2.3.1 apply to all content, and other technology must not block the page.
- Claims are optional; if made: date, title, version and URI, level, pages, relied-upon technologies.
- Third-party content: conformance may be claimed if it is monitored and fixed within two business days; otherwise a partial conformance statement. A separate partial statement covers language support.

### Which level
- W3C encourages the latest version (O).
- Level is a policy choice; no required level is named (U). AAA is not recommended as a general policy for entire sites (U).
- No page read recommends AA by name. D048 fixes version 2.2 and states no level.

### What tools can check
- Tools cannot check everything, need human judgement and can be wrong (E). Testing combines automation and human evaluation (U). Playwright says the same and recommends manual assessment and inclusive user testing (PW).
- ACT Rules are informative; none were listed for any of the nine new criteria (C).
- axe-core 4.14.1 has one WCAG 2.2 rule, `target-size` (2.5.8, tag `wcag22aa`), with `enabled: false`. No rule carries `wcag22a` (R, S).
- From the source (S): a default run skips `target-size`; a tag `runOnly` that includes `wcag22aa` or `wcag258` selects it even though disabled; an explicit `rules` setting overrides tags; `runOnly` of type `rule` overrides both.
- Tag selection must therefore list `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`. Playwright's examples stop at the 2.1 tags (PW).

### Coverage of the 55 A and AA criteria (classification derived by this note from T and R)
2.2 has 31 A and 24 AA criteria. A tag on an axe rule means partial evidence only; no source read says any criterion is fully checked by a tool.

| Class | Count | Criteria |
|---|---|---|
| Partly (at least one axe rule) | 21 | 1.1.1, 1.2.2, 1.3.1, 1.3.5, 1.4.1, 1.4.2, 1.4.3, 1.4.4, 1.4.12, 2.1.1, 2.2.1, 2.2.2, 2.4.1, 2.4.2, 2.4.4, 2.5.3, 2.5.8, 3.1.1, 3.1.2, 3.3.2, 4.1.2 |
| No standard axe rule | 34 | 1.2.1, 1.2.3, 1.2.4, 1.2.5, 1.3.2, 1.3.3, 1.3.4, 1.4.5, 1.4.10, 1.4.11, 1.4.13, 2.1.2, 2.1.4, 2.3.1, 2.4.3, 2.4.5, 2.4.6, 2.4.7, 2.4.11, 2.5.1, 2.5.2, 2.5.4, 2.5.7, 3.2.1, 3.2.2, 3.2.3, 3.2.4, 3.2.6, 3.3.1, 3.3.3, 3.3.4, 3.3.7, 3.3.8, 4.1.3 |

1.3.4 has only an experimental rule (`css-orientation-lock`), disabled by default.

### Manual and keyboard checks (P)
Quick checks, stated as not definitive (a page can pass them and still have significant barriers): page title; alt text quality; heading structure; contrast; 200% text resize; keyboard (reach and leave every control, logical order, visible focus, all functions without a mouse, arrowing options triggers nothing); form labels, required fields and error messages; moving or flashing content; captions, transcripts and audio description; reading order without styles.

### Playwright (PW)
- ARIA snapshots compare the accessibility tree (roles, names, states, order). A template is partial, so unlisted nodes are not checked.
- `locator.press()` is advised over `keyboard.press()`. The keyboard page does not state that Tab moves focus.

## Actionable Techniques (design is this note's)

1. Scan with all five A and AA tags; assert `target-size` ran (present in passes, violations, incomplete or inapplicable).
2. Report each A and AA criterion as automated-partial, scripted keyboard or browser test, or manual, with evidence. A clean scan never marks a criterion as passed.
3. Candidate scripted Playwright checks (each partial): 2.1.1, 2.1.2, 2.1.4, 2.4.3, 2.4.7, 2.4.11 (hit-test the focused element under sticky content), 2.5.2, 2.5.7 (complete the task by clicks), 3.2.1, 3.2.2, 3.2.3, 3.2.6 (compare order across pages), 3.3.1, 3.3.7, 3.3.8 (paste and autofill allowed), 1.4.10 (320 CSS px viewport [unverified here]), 4.1.3 (live region content).
4. Keep human judgement for text and media quality (1.1.1, 1.2.x, 1.3.3, 2.4.6, 3.3.3), flashing (2.3.1), exceptions such as "essential", and assistive-technology use.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-accessibility, react-component-testing, react-e2e-testing | Target moves from 2.1 to 2.2 (D048) | New criteria, tag list, `target-size` behaviour, coverage classes |

## Candidate New Skills/Agents

None.

## Key Terminology

Success criterion, Conformance level, Complete process, Cognitive function test, Accessibility supported, ACT Rule.

## Caveats

- Levels and statements come from fetch-tool summaries of T; check exact wording against T before quoting it. The last part of T (from character 200000) was summarised only for glossary and change log headings; the glossary definitions were not read.
- Understanding pages for the individual new criteria were not read.
- The coverage classes rest on rule tags, not on testing what each rule detects.
- [unverified] That `AxeBuilder.withTags` passes a tag `runOnly` unchanged, so it enables `target-size`.
- [unverified] The behaviour of `target-size` in axe-core 4.12.1 (the jest-axe dependency); it also needs real layout, so jsdom results should not be trusted.
- [unverified] Scripted checks in technique 3 are this note's design and were not run.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| 2.1 AA tags cover a 2.2 AA target | `wcag22aa` is also needed | Not supported |
| A default axe run covers 2.2 | `target-size` is disabled by default | Not supported |
| 4.1.1 must pass under 2.2 | Obsolete and removed | Not supported |
