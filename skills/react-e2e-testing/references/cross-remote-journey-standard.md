# Cross-Remote Journey Standard — Full Worked Example

Self-contained — loadable without the parent `SKILL.md` body already in
context. Covers Playwright setup, role-based locators, and one complete
journey test that proves the shell + remotes composition itself, not just
one fragment in isolation.

---

## Playwright Config

```ts
// playwright.config.ts
export default defineConfig({
  testDir: "./tests/e2e",
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173", // the shell's own origin
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: devices["Desktop Chrome"] },
    { name: "firefox",  use: devices["Desktop Firefox"] },
    { name: "webkit",   use: devices["Desktop Safari"] },
  ],
});
```

`baseURL` is the **shell's** origin — a journey always enters through the
shell (`react-routing`'s Standard 1: the shell owns the top-level
path-to-fragment mapping), never a remote's dev URL directly, because a
remote loaded outside the shell has no shell context to read tenant/auth
state from (`react-routing`'s route-tree ownership table).

---

## Role-Based Selectors

Same discipline as component tests (`react-component-testing`'s
query-priority standard): `getByRole`, `getByLabel`, `getByText`. This
keeps journeys resilient to markup changes inside any one fragment and
doubles as an accessibility check spanning fragment boundaries.

```ts
await page.getByRole("row", { name: /CC6.1/ }).getByRole("button", { name: /review/i }).click();
await expect(page.getByText(/marked as reviewed/i)).toBeVisible();
```

Avoid CSS/XPath/`data-testid` selectors except as a last resort, for the
same reason `react-component-testing`'s query-priority standard gives:
each rung down proves a weaker accessibility claim, and a selector scoped
to one fragment's internal markup is exactly what breaks first when that
fragment's owning team ships an unrelated refactor.

---

## The Worked Journey: Classify in One Remote, Observe in Another

The single highest-value thing a cross-remote journey test proves that no
number of component tests can: that the **composition** works — that an
action a user takes inside one independently-deployed fragment has its
effect correctly surfaced inside a *different* independently-deployed
fragment, through whatever real channel connects them (a Domain Event
through the backend, not any cross-fragment client-side store —
`microfrontend-architecture` forbids the latter outright). A component
test can prove the `data-assets` fragment's classify button works, and a
separate component test can prove the `compliance-dashboard` fragment's
report table renders a given prop shape correctly — neither can prove the
second reacts correctly to the first's real-world consequence, because
each renders only its own fragment in isolation.

```ts
test("classifying a data asset in one remote surfaces it in a different remote's compliance dashboard", async ({ page }) => {
  // 1. Enter through the shell.
  await page.goto("/data-assets");
  await expect(page.getByRole("heading", { name: /data assets/i })).toBeVisible();

  // 2. Act inside the data-assets remote.
  await page.getByRole("row", { name: /customer-exports\.csv/ })
    .getByRole("button", { name: /classify/i }).click();
  await page.getByRole("option", { name: /restricted/i }).click();
  await expect(page.getByText(/classified as restricted/i)).toBeVisible();

  // 3. Navigate — a shell-level transition, not a page reload — into a
  //    DIFFERENT remote entirely.
  await page.getByRole("link", { name: /compliance dashboard/i }).click();
  await expect(page.getByRole("heading", { name: /compliance gaps/i })).toBeVisible();

  // 4. Assert the second remote reflects the first remote's action.
  //    This is eventually consistent (the projection updates once the
  //    Domain Event is processed) — poll, don't assert immediately.
  await expect
    .poll(async () => page.getByRole("row", { name: /customer-exports\.csv/ }).isVisible())
    .toBe(true);
  await expect(page.getByRole("row", { name: /customer-exports\.csv/ }))
    .toContainText(/restricted/i);
});
```

Notes on why each step is shaped this way:

- **Step 1 enters through the shell**, never `page.goto("/compliance-dashboard-remote-dev-url")` directly — a direct remote URL bypasses the shell's routing, auth guard, and shell-context provisioning entirely, so it isn't testing the same thing a real user does.
- **Step 3 navigates via a shell-owned link**, exercising the actual Module Federation remote-loading path (`react-routing`'s Standard 2/3) rather than a fresh page load — a fresh `page.goto` to the second remote's route would skip over exactly the boundary this test exists to prove.
- **Step 4 polls rather than asserts immediately** — the same Eventual Consistency `go-e2e-test`'s own worked example poll-waits for on the backend side (`awaitGapReportReflects`) applies identically here: the compliance-dashboard remote's data comes from a Read Model projection that updates after the classify command's Domain Event is processed, not synchronously with the click.

---

## Network Strategy

Two valid modes, chosen per suite — the same split the pre-rebuild skill
already used, retained because it holds up:

| Mode | How | Use for |
|---|---|---|
| **Mocked edge** | Playwright `page.route()` interception returns fixtures | Deterministic per-fragment journey tests; fast; runs standalone against a dev server, no backend needed |
| **Real backend** | Run against the SAME ephemeral stack `go-e2e-test` provisions (see `SKILL.md`'s Standard 2) | The cross-remote journey smoke suite — the one place mocking would hide the exact integration this test exists to prove |

```ts
await page.route("**/api/v1/data-assets", (route) =>
  route.fulfill({ json: { items: sampleAssets, page: 1 } }));
```

Mocked-edge fixtures use the same OpenAPI-contract response shapes the
backend actually returns (no drift between fixture and reality). The
cross-remote journey in the worked example above is exactly the case that
belongs on the **real-backend** tier, not mocked-edge: mocking the
compliance-dashboard remote's API response would make the test pass
whether or not the two remotes are actually wired together correctly
through the real backend, defeating its entire purpose.

---

## Authentication

Logging in through the UI on every test is slow and flaky. Authenticate
**once** and reuse the storage state:

```ts
// global setup: sign in once, save the session
await page.context().storageState({ path: "tests/e2e/.auth/user.json" });
// tests reuse it:
test.use({ storageState: "tests/e2e/.auth/user.json" });
```

The saved session populates the shell's own auth/tenant context
(`react-routing`'s Standard 1) — a remote never maintains independent
auth state, so one shell-level sign-in is sufficient for a journey that
crosses multiple remotes; there is no per-remote login step to reuse or
skip. For real-backend runs, mint a test JWT via the backend's test auth
path — never a production credential (test-only tokens, per
`secrets-management`).

---

## Accessibility In-Flow

Run an axe scan at key points within a journey, including immediately
after a cross-remote navigation, so accessibility is verified in the
real, assembled page — not just inside one fragment's isolated component
tree:

```ts
import AxeBuilder from "@axe-core/playwright";
const results = await new AxeBuilder({ page }).analyze();
expect(results.violations).toEqual([]);
```
