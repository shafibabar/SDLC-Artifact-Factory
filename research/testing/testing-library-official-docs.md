# Testing Library, user-event and jest-dom Official Documentation
**Authors:** The Testing Library project
**Domain:** Testing (React component, TypeScript)

Accessed 2026-11-25. `@testing-library/react` 16.3.3: React 18 or 19, peer `@testing-library/dom ^10` (https://registry.npmjs.org/@testing-library/react/latest). `@testing-library/user-event` 14.6.13: peer dom >=7.21.4 (https://registry.npmjs.org/@testing-library/user-event/latest). Base T = https://testing-library.com/docs (unversioned; user-event pages are v14). Read through a summarising fetch tool. Nothing was run.

## Core Concepts

### Queries (T/queries/about)

| Variant | 0 | 1 | many | Retries |
|---|---|---|---|---|
| getBy | throws | element | throws | no |
| queryBy | null | element | throws | no |
| findBy | throws | element | throws | yes (1000 ms) |

`All` forms return arrays (`queryAllBy` returns `[]`). Priority: Role, LabelText, PlaceholderText, Text, DisplayValue; then AltText, Title; TestId last. `within` scopes queries; `screen` is recommended.

### Async (T/dom-testing-library/api-async)
`waitFor`: timeout 1000 ms, interval 50 ms, retries only when the callback throws, also re-runs on DOM mutations. `waitForElementToBeRemoved` throws if already removed.

### React API (T/react-testing-library/api, /setup)
- Auto cleanup needs a global `afterEach`: in Vitest enable `globals`, or call `cleanup` in an `afterEach` in a `setupFiles` file.
- Custom `render` with `wrapper` for providers; `renderHook` exists, `render` preferred.

### user-event (T/user-event/intro, /options, /pointer, /utility)
- Call `userEvent.setup()` before render. It models whole interactions; `fireEvent` dispatches one event.
- It refuses impossible interactions, e.g. clicking a hidden element or typing into a disabled text box.
- Options: `advanceTimers` (set for fake timers; avoid `delay: null`), `delay` 0, `pointerEventsCheck` (each API call), `skipClick`, `skipHover`.
- jsdom has no layout; the library does not check whether a pointer action is possible at a position.
- `pointer-events: none` on the element or an ancestor throws "Unable to perform pointer interaction..." (https://raw.githubusercontent.com/testing-library/user-event/v14.6.1/src/utils/pointer/cssPointerEvents.ts).
- `type` returns early on a disabled element; otherwise one `click` (unless skipped), then `keyboard` (https://raw.githubusercontent.com/testing-library/user-event/main/src/utility/type.ts).
- `selectOptions` triggers pointer events.
- On a disabled target, mouse `down`/`up` skip `mousedown`, `mouseup`, `click` and `dblclick`; move and hover events still fire; focus is still attempted; nothing there throws explicitly (https://raw.githubusercontent.com/testing-library/user-event/v14.6.1/src/system/pointer/mouse.ts; pointer events themselves not read).
- Per printable key: `keydown`, `keypress` (if not prevented), later `keyup` (https://raw.githubusercontent.com/testing-library/user-event/v14.6.1/src/system/keyboard.ts).

### Environment limits and query clients
- jsdom implements neither layout (geometry returns dummy values) nor navigation; canvas needs the optional `@napi-rs/canvas`; `pretendToBeVisual` adds no rendering (https://github.com/jsdom/jsdom).
- TanStack Query defaults to three retries with exponential backoff, which can time out error tests; set `retry: false` and use a new `QueryClient` per test (https://tanstack.com/query/latest/docs/framework/react/guides/testing).

### jest-dom (https://raw.githubusercontent.com/testing-library/jest-dom/main/README.md)
Import `@testing-library/jest-dom/vitest` in a setup file listed in `setupFiles`. v8 supports Vitest 5 or later; v7 up to Vitest 4.

## Actionable Techniques

1. Setup file: jest-dom import and explicit `afterEach(cleanup)`.
2. Absence: `queryBy`; appearance: `findBy`; set longer timeouts explicitly.
3. Disabled control: assert it is disabled and the handler was not called.
4. Fake timers: `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })` (Vitest function name [unverified]).
5. Overlap and layout checks belong in a browser test.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-component-testing | W3D-21, 22, 26 to 28 | Query table, setup, limits |

## Candidate New Skills/Agents

None.

## Key Terminology

Query variant, Priority order, `within`, Custom render.

## Caveats

- [unverified] Pointer events on disabled targets; version tags of the `main` source files; how role queries compute the accessibility tree.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| W3D-21: disabled click does not throw | Click events skipped, no explicit throw | Confirmed (source) |
| W3D-21: overlap not detectable | No layout checks | Confirmed |
| W3D-21: skill says disabled or covered element throws | Only `pointer-events: none` throws | Skill claim refuted (cover case inferred) |
| W3D-22: pointer and focus events per character | `type` clicks once; each key is `keydown`, `keypress`, `keyup` | Skill claim refuted |
| W3D-25: jsdom accessibility tree approximate | Not found | [unverified] |
| W3D-26: getBy/queryBy/findBy, extra queries | As above | Confirmed |
| W3D-27: harness | Cleanup, jest-dom, wrapper, query retries | Confirmed |
| W3D-28: jsdom limits; fake timers need `advanceTimers` | No layout; canvas optional. WebGL, workers, observers, federated imports not documented there | Layout, canvas, timers confirmed; rest [unverified] |
