---
name: react-component-testing
description: >
  Teaches behavior-first component testing with Vitest + React Testing Library and
  MSW — testing what the user experiences (not implementation details), querying by
  accessible role/label, mocking the network at the boundary with Mock Service
  Worker, covering every state variant and interaction from the component spec,
  asserting accessibility with jest-axe, and writing the test before the component
  (TDD). Realizes the UI acceptance criteria. Used by the frontend-engineer during
  Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, testing, react-testing-library, msw, vitest, tdd]
---

# React Component Testing

## Purpose

A component test proves the component behaves correctly from the **user's** point of view — given these props and this user action, the right thing is shown and the right call is made. Tests that assert internal state, prop names, or implementation details break on every refactor and prove nothing about correctness. This skill tests behaviour, queries the way a user (and a screen reader) perceives the UI, and isolates the network hermetically.

These tests realise the UI acceptance criteria (the Gherkin scenarios from `acceptance-criteria`) and are written **before** the component (TDD — enforced by the `tdd-gate` hook).

---

## The Stack

| Tool | Role |
|---|---|
| **Vitest** | Test runner (fast, Vite-native, jsdom environment) |
| **React Testing Library** | Render + query components the way users interact |
| **@testing-library/user-event** | Realistic user interactions (type, click, tab) |
| **MSW (Mock Service Worker)** | Intercept network at the boundary — real fetch, mocked responses |
| **jest-axe** | Automated accessibility assertions |

---

## Behavior Over Implementation

The guiding principle: **test what the user experiences, not how it's built.**

```tsx
// ✅ Behaviour: the user sees the result of their action
it("classifies an asset and shows the new level", async () => {
  const user = userEvent.setup();
  render(<ClassificationModal assetId="a1" assetName="Q3 Report" onClose={vi.fn()} />);

  await user.selectOptions(screen.getByLabelText(/sensitivity level/i), "Confidential");
  await user.click(screen.getByRole("button", { name: /save/i }));

  expect(await screen.findByText(/classified as confidential/i)).toBeInTheDocument();
});

// ❌ Implementation: brittle, proves nothing the user cares about
// expect(wrapper.state("selectedLevel")).toBe("Confidential");
```

Never assert on internal state, instance methods, or CSS classes. If a refactor that preserves behaviour breaks the test, the test was testing the wrong thing.

---

## Query by Role and Label

Queries target the **accessible** UI, in priority order — so a passing test is also evidence of accessibility (see `react-accessibility`):

| Priority | Query | Why |
|---|---|---|
| 1 | `getByRole` (with `name`) | How assistive tech perceives it; the strongest signal |
| 2 | `getByLabelText` | Form fields by their label |
| 3 | `getByText` | Non-interactive content |
| last resort | `getByTestId` | Only when nothing accessible identifies it (a smell) |

```tsx
screen.getByRole("button", { name: /classify/i });
screen.getByLabelText(/sensitivity level/i);
```

If you can't query an element by role or label, a screen-reader user can't find it either — fix the component, don't reach for `getByTestId`.

---

## Hermetic Network Isolation with MSW

MSW intercepts requests at the network layer (Service Worker / fetch interception), so components run their **real** data-fetching code (`react-api-client`, TanStack Query) against mocked responses — no stubbing of hooks, no brittle module mocks.

```ts
// src/test/handlers.ts — shared MSW handlers aligned to the OpenAPI contract
export const handlers = [
  http.get("/api/v1/data-assets", () => HttpResponse.json({ items: sampleAssets, page: 1 })),
  http.patch("/api/v1/data-assets/:id/classification", () => new HttpResponse(null, { status: 204 })),
];
```

```ts
// src/test/setup.ts
const server = setupServer(...handlers);
beforeAll(() => server.listen({ onUnhandledRequest: "error" })); // unmocked call = test failure
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: "error"` means a component that calls an unexpected endpoint fails the test — no silent surprises. Per-test overrides simulate errors, slow responses, and edge cases:

```tsx
it("shows an error state when the list fails", async () => {
  server.use(http.get("/api/v1/data-assets", () => new HttpResponse(null, { status: 500 })));
  render(<DataAssetListPage />, { wrapper: AppProviders });
  expect(await screen.findByRole("alert")).toHaveTextContent(/something went wrong/i);
});
```

Because the mocked shapes come from the **same OpenAPI contract** the client is generated from, the mocks can't drift from reality.

---

## Cover Every State and Interaction

The `ui-component-spec` enumerates state variants and interactions — each becomes a test. The spec table *is* the test plan:

| Spec element | Test |
|---|---|
| Loading state | renders skeleton while the query is pending |
| Empty state | renders the empty CTA when the list is empty |
| Error state | renders an alert + retry on failure |
| Populated state | renders rows for the data |
| Interaction: classify | opens modal, submits, shows result |
| Interaction: sort | clicking a header updates order + URL |
| a11y | `axe` finds no violations |

```tsx
it("has no accessibility violations", async () => {
  const { container } = render(<DataAssetTable assets={sampleAssets} isLoading={false} error={null} onClassify={vi.fn()} />);
  expect(await axe(container)).toHaveNoViolations();
});
```

---

## TDD Flow

1. Read the component spec + the relevant Gherkin scenario.
2. Write the failing behaviour test (query by role/label, assert the user-visible outcome).
3. Implement the component until the test passes.
4. Add state/interaction/a11y tests; refactor with the tests as the safety net.

The test exists before the component — the `tdd-gate` hook verifies the test file is not newer than the implementation.

---

## What Not to Test

- Third-party libraries (TanStack Query, the router) — trust them; test *your* usage.
- Exact markup/CSS — test behaviour and accessible output, not the DOM structure.
- Implementation details — internal state, private handlers, hook call counts.

Aim coverage at behaviour and branches (states, error paths), not a line-count number for its own sake.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Behaviour-focused | Asserts user-visible outcomes | Asserts internal state/CSS/impl details |
| Role/label queries | `getByRole`/`getByLabelText` first | `getByTestId` as the default |
| Hermetic network | MSW at the boundary; unhandled = error | Hook/module mocks; real network calls |
| Contract-aligned mocks | MSW shapes from the OpenAPI contract | Hand-invented response shapes |
| Full state coverage | Every spec state + interaction tested | Happy-path-only tests |
| a11y asserted | `jest-axe` + role queries | No accessibility assertions |
| Test-first | Test precedes component (tdd-gate) | Tests written after, to fit the code |

---

## Output Format

Produces test files (written before the components they cover) and shared test infra:

```
src/**/*.test.tsx               (behaviour + a11y, per component)
src/test/setup.ts                (MSW server lifecycle)
src/test/handlers.ts             (contract-aligned MSW handlers)
src/test/render.tsx              (render-with-providers helper)
```
