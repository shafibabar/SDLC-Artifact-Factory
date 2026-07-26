# Mocking and Snapshot Standard

Self-contained reference for `react-component-testing`. Two standards live here: exactly where the mock boundary sits for a component test (the network, never the component's own code), and when a snapshot test is the right tool versus an anti-pattern.

---

## The Mock Boundary: MSW at the Network, Never Internal Modules

A component test's job is to prove the component's **own code** — its data fetching, its state transitions, its rendering logic — behaves correctly. Every mock decision follows from that one sentence: mock the thing outside the component's own code (the network), never a piece of the component's own code (a hook, a client module, an internal function).

**MSW (Mock Service Worker) intercepts at the network layer**, not inside the application. A component using `react-api-client`'s typed client or a TanStack Query hook still calls the real `fetch`, still runs its real request-building, error-mapping, and cache logic — only the actual bytes that come back over the (intercepted) wire are faked. This means a component test using MSW is exercising the exact same code path production traffic exercises, all the way down to the generated OpenAPI types deserializing the mocked JSON.

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

`onUnhandledRequest: "error"` is load-bearing: a component that calls an endpoint the test didn't anticipate fails loudly instead of silently hanging or hitting a real network. Because the mocked response shapes are written against the **same OpenAPI contract** `react-api-client`'s types are generated from, a handler can't drift into a shape the real backend would never send.

**What this rules out — mocking the component's own collaborators:**

```tsx
// ❌ Mocks the hook under test — the "test" now only proves the mock works
vi.mock("./useDataAssets", () => ({
  useDataAssets: () => ({ data: sampleAssets, isLoading: false, error: null }),
}));

// ❌ Mocks the API client module directly — bypasses error mapping, retry,
// auth-header attachment (react-api-client) entirely
vi.mock("../api/client", () => ({ dataAssetsClient: { list: vi.fn().mockResolvedValue(sampleAssets) } }));
```

Both examples above replace exactly the code the test exists to verify. A component that calls `useDataAssets` correctly and one that calls it with the wrong arguments produce an identical passing test under either mock — the test has stopped being able to fail for the reason it should. Mock the network (MSW); run the component's real code against it.

### The Analogue to `go-unit-test`'s Mocking Discipline

`go-unit-test`'s own isolation rule draws the same boundary from the backend side: its "Isolation — No Real World" section replaces only true external dependencies — "file system, network, database, clock" — with test doubles, injected at the port (`fakeRepo`, `stubPolicy`, `fakeIdem`), while its "Decoupled from Implementation" section requires tests to "assert behaviour through the public surface, not internal state," explicitly naming "asserting a private field or internal call count" as the anti-pattern to avoid. That is the identical shape as the React standard above, applied to a different stack: mock only at the true external boundary (there, the repository/broker port; here, the network via MSW), and assert through the component's real, public behaviour rather than replacing an internal collaborator and checking that the replacement was called correctly. Neither skill's current text uses the "classical/Detroit school vs. London/mockist school" labels verbatim, but the substance both converge on is the classical position: prefer real collaborators wherever they're cheap enough to run, reserve test doubles for the genuinely external, and verify state/output rather than interaction counts with an internal mock.

---

## Snapshot Testing: When It's the Right Tool, and When It's an Anti-Pattern

A snapshot test serializes a value and asserts it matches a previously-committed baseline, failing on any difference. That mechanism is only useful when a *human reviewing the diff* can tell, at a glance, whether the change is expected — which depends entirely on what's being snapshotted.

**Appropriate — a small, stable, semantically-meaningful serialization:**

- A generated configuration object (a resolved theme object, a computed permission matrix) where the full shape matters and changes are rare and deliberate.
- A pure data-transformation function's output (a normalizer, a formatter) where the snapshot is really asserting "this exact object shape," which could equally be a `toEqual` assertion but reads more conveniently as a snapshot when the shape is large but stable.

```tsx
// ✅ Appropriate: a small, rarely-changing derived object; a diff is legible
it("resolves the theme tokens for the dark palette", () => {
  expect(resolveThemeTokens("dark")).toMatchSnapshot();
});
```

**Anti-pattern — a large or interactive component's rendered markup:**

```tsx
// ❌ Anti-pattern: hundreds of lines of DOM, no assertion about behaviour
it("renders the data asset table", () => {
  const { container } = render(<DataAssetTable assets={sampleAssets} />);
  expect(container).toMatchSnapshot();
});
```

This fails the same test every other standard in this skill applies: does the assertion prove something about user-visible behaviour? A full-component DOM snapshot does not — it proves the markup is byte-identical to whatever was committed last, which is a claim about implementation, not behaviour. Two concrete failure modes follow directly:

1. **The diff is illegible.** A snapshot failure on a 200-line rendered tree shows a wall of `+`/`-` lines a reviewer cannot map to "is this the change I intended." Compare to a `getByRole`/`getByText` assertion, whose failure message states exactly what was expected and what was found.
2. **It gets rubber-stamped, not reviewed.** Faced with an illegible diff and time pressure, the near-universal response is `--update-snapshots` without truly reading it — at which point the test asserts nothing; it has become a change-detector that always "passes" one commit later, and a genuine regression slips through disguised as an expected update.

**Standard:** snapshot a small, stable, non-interactive value when the full shape is the thing under test and a diff would be legible. For any interactive component's rendered output, write behaviour assertions (`getByRole`, `getByText`, `toHaveTextContent`) instead — they fail with a specific, actionable message and can't be satisfied by blindly re-recording a baseline.
