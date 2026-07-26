---
name: react-component-testing
description: >
  Teaches behavior-first component testing with Vitest + React Testing Library
  and MSW: the exact query-priority standard (getByRole > getByLabelText >
  getByText > getByTestId, and why each rung proves a weaker accessibility
  claim than the last), the user-event-over-fireEvent standard (realistic
  browser event sequencing vs a single synthetic event), the MSW mock-boundary
  standard (mock the network, never a component's own hooks or modules),
  jest-axe accessibility assertions cross-referenced to react-accessibility,
  when a snapshot test is appropriate versus an anti-pattern, and writing the
  test before the component (TDD). Realizes the UI acceptance criteria. Used
  by the frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, testing, react-testing-library, msw, vitest, tdd, query-priority, user-event, snapshot-testing, jest-axe]
related: [react-accessibility, react-api-client, go-unit-test]
---

# React Component Testing

## Purpose

A component test proves the component behaves correctly from the **user's** point of view — given these props and this user action, the right thing is shown and the right call is made. Tests that assert internal state, prop names, or implementation details break on every refactor and prove nothing about correctness. This skill tests behaviour, queries the way a user (and a screen reader) perceives the UI, isolates the network hermetically, and states exactly what "good" looks like for every mechanical decision that behavior-first philosophy raises — which query to reach for, which interaction API to use, where the mock boundary sits, and when a snapshot is or isn't the right assertion.

These tests realise the UI acceptance criteria (the Gherkin scenarios from `acceptance-criteria`) and are written **before** the component (TDD — enforced by the `tdd-gate` hook).

---

## The Stack

| Tool | Role |
|---|---|
| **Vitest** | Test runner (fast, Vite-native, jsdom environment) |
| **React Testing Library** | Render + query components the way users interact |
| **@testing-library/user-event** | Realistic user interactions (type, click, tab) — see standard below |
| **MSW (Mock Service Worker)** | Intercept network at the boundary — real fetch, mocked responses |
| **jest-axe** | Automated accessibility assertions |

---

## Behavior Over Implementation

The guiding principle: **test what the user experiences, not how it's built.**

```tsx
// ✅ Behaviour: the user sees the result of their action
await user.selectOptions(screen.getByLabelText(/sensitivity level/i), "Confidential");
await user.click(screen.getByRole("button", { name: /save/i }));
expect(await screen.findByText(/classified as confidential/i)).toBeInTheDocument();

// ❌ Implementation: brittle, proves nothing the user cares about
// expect(wrapper.state("selectedLevel")).toBe("Confidential");
```

Never assert on internal state, instance methods, or CSS classes. If a refactor that preserves behaviour breaks the test, the test was testing the wrong thing.

---

## Query-Priority Standard

Queries are not interchangeable — they form a strict priority order, because each rung proves a weaker accessibility claim than the one above it:

| Priority | Query | Proves |
|---|---|---|
| 1 | `getByRole` (with `name`) | An AT user can find and name this control — the accessibility tree itself |
| 2 | `getByLabelText` | The field has a real programmatic label, not a placeholder |
| 3 | `getByPlaceholderText` / `getByText` | The content is present — proves nothing about interactivity |
| Last resort | `getByTestId` | Only that a string attribute exists in the DOM — proves nothing about accessibility |

`getByTestId` reaching a "pass" while a `<div>` has no role, no keyboard handler, and no accessible name is exactly why it sits last: it validates markup a screen reader cannot use at all. Full rationale per rung and worked examples: `references/query-priority-and-interaction-standard.md`.

---

## `user-event` Over `fireEvent`

`@testing-library/user-event` simulates the full sequence of real browser events an interaction produces (typing fires `keydown`/`keypress`/`input`/`keyup` per character, in order); `fireEvent` dispatches only the one event named (`fireEvent.change` fires a single synthetic `change`, nothing else). A component whose behaviour depends on any intermediate event — an `onKeyDown` Enter-to-submit handler, an `onFocus`-triggered combobox — is invisible to `fireEvent` and only exercised by `user-event`; a `fireEvent`-based test can report green while that handling is completely broken. Standard: every interaction goes through `userEvent.setup()`; `fireEvent` is reserved for dispatching an event `user-event` has no method for. Worked comparison: `references/query-priority-and-interaction-standard.md`.

---

## Accessibility: jest-axe Plus Role/Label Queries

Two layers, both required — owned in full by `react-accessibility`, cross-referenced here for the testing mechanics:

- **`jest-axe`** catches missing accessible names, invalid ARIA, and text-contrast violations — `react-accessibility` states it covers "~30–40% of issues" and explicitly "does not catch focus management, `prefers-reduced-motion` handling, or non-text (1.4.11) contrast."
- **Role/label queries are themselves an accessibility assertion**: `react-accessibility` states "if a test can't find an element by its accessible name, neither can a screen reader" — a passing `getByRole`/`getByLabelText` query is direct proof of WCAG 4.1.2 (Name, Role, Value). Focus-trap and focus-return assertions (`user.tab()`, `user.keyboard("{Escape}")`, asserting `document.activeElement`) belong here too — axe cannot verify them.

```tsx
it("has no accessibility violations", async () => {
  const { container } = render(<DataAssetTable assets={sampleAssets} isLoading={false} error={null} onClassify={vi.fn()} />);
  expect(await axe(container)).toHaveNoViolations();
});
```

---

## Mock-Boundary Standard: MSW at the Network, Never Internal Modules

MSW intercepts requests at the network layer, so a component runs its **real** data-fetching code (`react-api-client`, TanStack Query) against a mocked response — never stub the hook or client module under test:

```ts
export const handlers = [
  http.get("/api/v1/data-assets", () => HttpResponse.json({ items: sampleAssets, page: 1 })),
];
// setup.ts: onUnhandledRequest: "error" — an unmocked call is a test failure, not a silent pass
```

Mocking `vi.mock("./useDataAssets", ...)` or the API client module directly replaces exactly the code the test exists to verify — a component calling the hook correctly and one calling it wrong both pass. `go-unit-test`'s own isolation rule draws the identical boundary on the backend: it replaces only true external dependencies ("file system, network, database, clock") and requires asserting "behaviour through the public surface, not internal state" — never "a private field or internal call count." Mock the network; run the component's real code. Full standard and the go-unit-test analogue in detail: `references/mocking-and-snapshot-standard.md`.

---

## Snapshot-Testing Standard

Appropriate for a small, stable, semantically-meaningful serialization — a resolved config or theme-token object where the full shape matters and changes are rare. An anti-pattern for an interactive component's rendered markup: a large DOM snapshot diff tells a reviewer nothing actionable about behaviour, gets rubber-stamped with `--update-snapshots` under time pressure, and stops catching real regressions the moment that happens. For interactive UI, write a behaviour assertion (`getByRole`, `toHaveTextContent`) instead — it fails with a specific, actionable message a blind re-record can't satisfy. Criteria and worked examples of both: `references/mocking-and-snapshot-standard.md`.

---

## Cover Every State and Interaction

The `ui-component-spec` enumerates state variants and interactions — each becomes a test:

| Spec element | Test |
|---|---|
| Loading / empty / error / populated | One test per state, each asserting its user-visible outcome |
| Interaction | Opens/submits/updates as specified — via `user-event`, not `fireEvent` |
| a11y | `axe` finds no violations; every control reachable by role/label |

---

## TDD Flow

1. Read the component spec + the relevant Gherkin scenario.
2. Write the failing behaviour test (query by role/label, assert the user-visible outcome).
3. Implement the component until the test passes.
4. Add state/interaction/a11y tests; refactor with the tests as the safety net.

The test exists before the component — the `tdd-gate` hook verifies the test file is not newer than the implementation.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Behaviour-focused | Asserts user-visible outcomes | Asserts internal state/CSS/impl details |
| Query-priority order | `getByRole`/`getByLabelText` first; `getByTestId` a documented last resort | `getByTestId` as the default query |
| Interaction API | `userEvent.setup()` for every interaction | `fireEvent` as the default interaction mechanism |
| Hermetic network | MSW at the boundary; unhandled request = error | Hook/module mocks; real network calls |
| Mock boundary respected | Only the network is mocked; component's own code runs | `vi.mock` on the component's own hook/client module |
| Contract-aligned mocks | MSW shapes from the OpenAPI contract | Hand-invented response shapes |
| Full state coverage | Every spec state + interaction tested | Happy-path-only tests |
| a11y asserted | `jest-axe` + role/label queries + focus assertions | No accessibility assertions |
| Snapshot use is scoped | Only stable, non-interactive serializations | Full-component DOM snapshots |
| Test-first | Test precedes component (tdd-gate) | Tests written after, to fit the code |

---

## Anti-Patterns

- **Mocking your own hooks/modules** — stubs out the very integration under test. Mock the network (MSW), run the real code.
- **`getByTestId` as the default query** — bypasses the accessibility tree; role/label first, test-id a documented last resort.
- **`fireEvent` instead of `user-event`** — dispatches one synthetic event where a real interaction fires a sequence; misses any behaviour keyed to an intermediate event.
- **Full-component DOM snapshots** — an illegible diff for interactive UI, rubber-stamp-updated instead of reviewed.
- **`waitFor` with an empty callback / arbitrary `setTimeout`** — await a concrete outcome (`await screen.findByText(…)`) instead of sleeping until things "probably" settle.
- **Shared mutable fixtures** — build fixtures per test (factory functions); reset MSW handlers `afterEach`.
- **Testing loading states by racing** — use a delayed MSW handler (`await delay(…)`) to hold the pending state deterministically, not an unguarded assertion against a real timing race.
- **Happy-path-only suites** — the spec's error/empty states are where user trust is won or lost; each is a required test.

---

## Output Format

Produces test files (written before the components they cover) and shared test infra:

```
src/**/*.test.tsx               (behaviour + a11y, per component)
src/test/setup.ts                (MSW server lifecycle)
src/test/handlers.ts             (contract-aligned MSW handlers)
src/test/render.tsx              (render-with-providers helper)
```
