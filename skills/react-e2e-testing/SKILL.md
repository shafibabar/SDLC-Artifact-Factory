---
name: react-e2e-testing
description: >
  Teaches end-to-end testing of the frontend with Playwright — testing complete
  user journeys in a real browser, the test pyramid's place for e2e (few, high-value,
  full-flow), role/label-based selectors, network strategy (mock at the edge vs run
  against a real backend), authentication setup, accessibility scans in-flow, visual
  and cross-browser checks, and stability practices that avoid flakiness. Realizes
  the journey-level acceptance criteria. Used by the frontend-engineer during Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, e2e, playwright, user-journey, testing]
---

# React E2E Testing

## Purpose

End-to-end tests verify that the whole frontend works as a user actually uses it — real browser, real navigation, real flows from start to finish. Where component tests prove a piece behaves, e2e tests prove the *journey* works: a compliance officer can log in, connect a source, review the gap report, and export it. This skill covers Playwright-based e2e for the high-value journeys the ux-architect mapped (`user-journey-mapping`).

E2E sits at the **top** of the test pyramid (from the test-strategist's `test-pyramid`): few, high-value, comprehensive — not a replacement for the many fast component tests below.

---

## The Pyramid's Top — Few and High-Value

E2E tests are slow and more brittle than unit tests, so cover the **critical journeys**, not every permutation (edge cases belong in fast component tests):

| Cover with e2e | Cover with component tests |
|---|---|
| Primary user journeys (the P1 journeys from `user-journey-mapping`) | Individual component states |
| Critical paths: auth, classify, generate report, connect source | Validation rules, error formatting |
| Cross-page flows and navigation | Single-component interactions |
| Smoke of the happy path on each release | Exhaustive variant coverage |

A handful of well-chosen journeys gives most of the confidence; resist turning e2e into a second, slower copy of the component suite.

---

## Playwright Setup

Playwright is the default (fast, reliable auto-waiting, multi-browser, built-in tracing). Tests live in `tests/e2e/`.

```ts
// playwright.config.ts
export default defineConfig({
  testDir: "./tests/e2e",
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173",
    trace: "on-first-retry",       // capture a trace for debugging failures
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: devices["Desktop Chrome"] },
    { name: "firefox",  use: devices["Desktop Firefox"] },
    { name: "webkit",   use: devices["Desktop Safari"] }, // cross-browser
  ],
});
```

---

## Role-Based Selectors (Same Discipline as Component Tests)

Playwright's recommended locators target the accessible UI — `getByRole`, `getByLabel`, `getByText` — the same role/label discipline as component tests (`react-component-testing`). This keeps tests resilient to markup changes and doubles as accessibility verification.

```ts
test("compliance officer reviews and exports the gap report", async ({ page }) => {
  await page.goto("/compliance");
  await expect(page.getByRole("heading", { name: /compliance gaps/i })).toBeVisible();

  await page.getByRole("row", { name: /CC6.1/ }).getByRole("button", { name: /review/i }).click();
  await expect(page.getByText(/marked as reviewed/i)).toBeVisible();

  await page.getByRole("button", { name: /export report/i }).click();
  const download = await page.waitForEvent("download");
  expect(download.suggestedFilename()).toMatch(/gap-report.*\.pdf/);
});
```

Avoid CSS/XPath selectors and `data-testid` except as a last resort — role/label locators are both more stable and more meaningful.

---

## Network Strategy

Two valid modes, chosen per suite:

| Mode | How | Use for |
|---|---|---|
| **Mocked edge** | Playwright `route()` interception (or MSW) returns fixtures | Deterministic UI-journey tests; fast; no backend needed in CI |
| **Real backend** | Run against a seeded test environment (the platform-engineer's ephemeral stack) | True end-to-end smoke; contract reality |

A pragmatic split: most journey tests run **mocked-edge** for speed and determinism; a small **real-backend** smoke suite runs against an ephemeral environment in CD to catch integration drift. Mocked responses use the same OpenAPI-contract shapes (no drift).

```ts
await page.route("**/api/v1/data-assets", (route) =>
  route.fulfill({ json: { items: sampleAssets, page: 1 } }));
```

---

## Authentication

Logging in through the UI on every test is slow and flaky. Authenticate **once** and reuse the storage state:

```ts
// global setup: sign in once, save the session
await page.context().storageState({ path: "tests/e2e/.auth/user.json" });
// tests reuse it:
test.use({ storageState: "tests/e2e/.auth/user.json" });
```

For real-backend runs, mint a test JWT via the backend's test auth path (never a production credential; tokens are test-only — see `secrets-management`).

---

## Accessibility In-Flow

Run an axe scan at key points within a journey so accessibility is verified in the real, assembled page (not just isolated components):

```ts
import AxeBuilder from "@axe-core/playwright";
const results = await new AxeBuilder({ page }).analyze();
expect(results.violations).toEqual([]);
```

---

## Stability — Avoiding Flakiness

Flaky e2e tests are worse than none (they erode trust). Practices:
- **Rely on Playwright's auto-waiting** (`expect(locator).toBeVisible()`) — never `waitForTimeout` / arbitrary sleeps.
- **Assert on user-visible state**, not on timing or internal requests.
- **Isolate tests** — each seeds/cleans its own data; no order dependence; parallel-safe.
- **Use traces/screenshots on failure** to debug, not retries-to-green (a test that only passes on retry is a bug).
- Keep the suite **fast enough to run in CI** on every PR (mocked-edge) with the real-backend smoke in CD.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Pyramid-appropriate | Few high-value journeys; edge cases in unit tests | E2E duplicating the component suite |
| Journey coverage | The P1 user journeys are covered end to end | Critical journeys untested |
| Role/label locators | `getByRole`/`getByLabel` | CSS/XPath/testid-driven selectors |
| Deterministic network | Mocked-edge (contract shapes) + small real smoke | Tests hitting uncontrolled live services |
| Fast auth | Reused storage state; test-only tokens | UI login per test; production creds |
| a11y in-flow | axe scans at journey checkpoints | No in-flow accessibility checks |
| Stable | Auto-waiting; isolated; no sleeps; no retry-to-green | `waitForTimeout`; order-dependent; flaky |

---

## Anti-Patterns

- **The inverted pyramid** — hundreds of e2e tests re-checking what component tests already prove. Every permutation added to e2e slows the suite and multiplies flake surface; edge cases live below.
- **`page.waitForTimeout(3000)`** — a sleep is a guess. It fails on slow CI and wastes time on fast machines. Await a visible outcome; Playwright's auto-waiting does the rest.
- **CSS/XPath selector archaeology** — `.MuiButton-root:nth-child(3)` breaks on every restyle and says nothing about the user. Role/label locators survive refactors and verify accessibility.
- **UI login in every test** — multiplies runtime and couples every journey to the auth UI. One authenticated `storageState`, reused; the login flow itself gets exactly one dedicated test.
- **Order-dependent tests** — test B relying on data test A created serialises the suite and makes failures cascade. Each test seeds and cleans its own world.
- **Retry-to-green** — configuring retries to bury flakiness. A test that passes on attempt two has a bug — in the test or the app — and it's hiding.
- **Live third-party dependencies** — journeys hitting a real Google Drive or S3 fail on their weather, not yours. Mock external edges; reserve real integration for the contract-owned smoke suite.
- **Asserting on network internals** — `waitForResponse` + JSON body assertions turn an e2e test into a worse contract test. Assert what the user sees; contracts are verified by Consumer-Driven Contract tests.

---

## Output Format

Produces Playwright specs and e2e infrastructure:

```
tests/e2e/*.spec.ts              (journey tests — role/label locators, axe scans)
tests/e2e/global-setup.ts         (auth storage state)
playwright.config.ts
tests/e2e/fixtures/*.ts            (contract-aligned route fixtures)
```
