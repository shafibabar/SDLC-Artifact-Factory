# Flakiness-Hardening and Visual-Regression Standard

Self-contained — loadable without the parent `SKILL.md` body already in
context.

---

## Condition-Based Waits, Never a Fixed Sleep

`go-e2e-test`'s own flakiness-mitigation standard states the rule for the
backend's API-level journey tests: "Arbitrary `time.Sleep` is the
cardinal sin of e2e: too short and it's flaky, too long and the suite
crawls. Wait for a condition, not a duration." The identical rule applies
to the Playwright side of the same journey suite — this is one
flakiness-hardening standard shared across both surfaces of `go-e2e-test`'s
"Two Surfaces, One Journey" split, not two separate philosophies:

| Instead of | Do |
|---|---|
| `page.waitForTimeout(3000)` | `await expect(locator).toBeVisible()` — Playwright's own auto-waiting |
| Polling a projection by hand with a sleep loop | `await expect.poll(async () => ..., { timeout: 10_000 }).toBe(true)` |
| Sleeping to "let the remote finish loading" | `await expect(page.getByRole("heading", { name: ... })).toBeVisible()` inside the now-loaded remote |
| Sleeping for an eventually-consistent projection | Poll for the expected state with a timeout — the same shape `go-e2e-test`'s `awaitGapReportReflects` uses on the backend, applied via `expect.poll` here |

```ts
// Condition-based wait with a deadline — mirrors go-e2e-test's
// awaitGapReportReflects shape, expressed as a Playwright expect.poll.
await expect
  .poll(async () => {
    const report = await fetchGapReport(page);
    return report.restrictedAssets.includes(assetId);
  }, { timeout: 10_000, intervals: [250, 500, 1000] })
  .toBe(true);
```

Playwright's built-in locator assertions (`toBeVisible`, `toHaveText`,
`toContainText`) already auto-wait and auto-retry against the DOM — reach
for `expect.poll` only when the condition being waited on isn't itself a
DOM assertion (an API response, a projection's derived state).

---

## Flaky-Test Quarantine

A flaky e2e test is worse than no test: it trains a team to re-run red
builds, which hides real failures. `go-e2e-test`'s quarantine policy
applies unchanged to the Playwright suite:

1. **Detect** — a spec that fails then passes on retry with no code
   change is flaky by definition; CI records it (test name, trace,
   failure output).
2. **Quarantine, don't delete** — move it to a tagged, still-run-but-
   non-blocking set (`test.skip(condition, reason)` or a separate
   quarantine project in `playwright.config.ts`) rather than deleting it;
   the journey's coverage gap stays explicit instead of silently
   vanishing.
3. **Time-box** — a quarantined spec carries an issue and a deadline.
   Fix the root cause using its trace (`trace: "on-first-retry"` in the
   config), or decide the journey belongs at a lower layer
   (`react-component-testing`) and remove it deliberately.
4. **Never retry-to-green as policy** — Playwright's `retries` config
   option is a diagnostic aid (retry once, report both outcomes in the
   trace), not a pass criterion. A spec that only passes on attempt two
   has a real bug — in the spec's waits or in the app — and retries are
   hiding it.

The quarantine list's steady state is **empty**; a growing list is the
suite telling you its waits, seeding, or remote-loading assumptions are
wrong, the same signal `go-e2e-test` reads it as on the backend side.

---

## Visual Regression: Narrow Scope, Deferred by Default

Visual regression is valuable — it catches a class of bug (broken layout,
a missing style import, a design-system version drift across
independently-deployed fragments — the "design/branding drift" cost
`microfrontend-architecture`'s `references/composition-and-communication.md`
names as a certainty to actively counter) that no role/label assertion
can see. It is also expensive to maintain and prone to false positives
from font-rendering and anti-aliasing differences across CI runners and
OS versions — a maintenance tax that scales with the number of pages
covered, not with the value each one adds.

**Default posture: deferred for the general suite, in scope only for a
small, explicit set of critical, visually-stable pages** — not adopted
wholesale, and not rejected outright. A page qualifies for visual-
regression coverage only if it is both:

- **High-consequence when visually broken** — e.g. the compliance
  gap-report view, whose exported PDF is the artifact an auditor
  receives; a broken layout here is a compliance-facing defect, not a
  cosmetic one.
- **Visually stable** — a page that changes rarely and deliberately, so
  a snapshot diff is almost always a real regression, not routine churn
  requiring a rubber-stamped re-baseline (the same failure mode
  `react-component-testing`'s snapshot-testing standard already warns
  against for DOM snapshots — a diff nobody actually reviews before
  re-recording is worse than no test).

Use Playwright's own built-in screenshot assertion — no separate paid
visual-regression service, applying CLAUDE.md § Budget and Frugality
(open-source over paid tooling; every added dependency must justify its
presence):

```ts
test("compliance gap-report view matches its baseline", async ({ page }) => {
  await page.goto("/compliance/gap-report");
  await expect(page.getByRole("heading", { name: /compliance gaps/i })).toBeVisible();
  await expect(page).toHaveScreenshot("gap-report.png", {
    maxDiffPixelRatio: 0.02, // tolerate minor anti-aliasing drift, not layout changes
  });
});
```

Run visual-regression specs in a single pinned browser/OS combination in
CI (not the full cross-browser matrix) — cross-browser font rendering is
exactly the false-positive source this standard exists to avoid, and the
cross-browser matrix is already covered by the functional journey specs.
