# Playwright Test Official Documentation
**Authors:** The Playwright project (Microsoft)
**Domain:** Testing (browser end to end, TypeScript)

Accessed 2026-11-25. `@playwright/test` 1.65.1, Node >=20 (https://registry.npmjs.org/@playwright/test/latest). Base P = https://playwright.dev/docs (unversioned). Read through a summarising fetch tool. Nothing was run.

## Core Concepts

### Retries and flaky (P/test-retries, P/api/class-testconfig)
- `retries` defaults to 0. Results are passed, flaky (failed, then passed on retry) or failed. A failure discards the worker; `beforeAll` runs again.
- `failOnFlakyTests` (CLI `--fail-on-flaky-tests`) makes flaky results exit with an error; `forbidOnly` does the same for `.only`.

### Config defaults (P/api/class-testconfig, P/api/class-testoptions)
`testMatch` `**/*.@(spec|test).?(c|m)[jt]s?(x)`; `testDir` the config folder; `workers` half the logical cores; `expect.timeout` 5000 ms; `trace`, `screenshot`, `video` `off`; `actionTimeout` 0; `baseURL` unset; `updateSnapshots` `default` (missing snapshots are written and the test fails).

### Traces (P/trace-viewer)
`on`, `off`, `on-first-retry` (only the first retry; documented with `retries: 1`), `on-all-retries`, `retain-on-failure` (works without retries).

### Authentication (P/auth, P/api/class-browsercontext)
- `storageState` holds cookies and localStorage; IndexedDB, OPFS and passkey credentials are opt-in. sessionStorage is not saved. In-memory JavaScript state is not among the listed contents.
- Recommended: a `setup` project (`*.setup.ts`) that signs in and saves state, listed in `dependencies`; one account per worker (`parallelIndex`) when tests change server state.
- Git-ignore `playwright/.auth`: it can hold sensitive cookies and headers.

### Global setup (P/test-global-setup-teardown)
Project dependencies are recommended (reported, traced, fixtures; `teardown` property). `globalSetup` has no fixtures, traces, report entry or retries and must launch its own browser.

### webServer (P/test-webserver)
`command`, `url` (`port` deprecated), `cwd`, `env`, `timeout` (60000), `reuseExistingServer` (suggested `!process.env.CI`; false throws if the port is taken). An array starts several servers.

### Assertions (P/test-assertions)
Web-first assertions retry up to 5 s. `expect.poll`: 5 s, intervals 100/250/500/1000 ms. `toPass`: timeout 0 (none), so set one.

### Annotations (P/test-annotations)
`skip` and `fixme` do not run the test; `fail` expects failure; `@` tags filter with `--grep` / `--grep-invert`.

### Select (P/input)
Native `<select>`: `locator.selectOption()`. Custom dropdowns are not covered there.

### Screenshots (P/test-snapshots)
Baselines live in `<test file>-snapshots/`, named with browser or project and platform; `snapshotPathTemplate` changes this. Rendering differs by OS, browser and hardware: compare in the generating environment, commit and review baselines. `--update-snapshots`; `maxDiffPixels` unset; `threshold` 0.2.

### Accessibility (P/accessibility-testing)
`AxeBuilder` from `@axe-core/playwright`; default runs WCAG and best-practice rules; `.withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa'])` limits to 2.1 A and AA. `analyze()` scans the current state, so wait for revealed UI first. `.include()`, `.exclude()` (drops descendants too), `.disableRules()`. Manual testing is still required.

## Actionable Techniques (design is this note's)

1. `retries: 1` only as policy dictates, `failOnFlakyTests` or a separate non-blocking tagged project, `forbidOnly` on CI, `trace` `retain-on-failure` or `on-first-retry` with a retry set.
2. Setup project for sign-in; seed unique data per worker; assert the starting state before the action.
3. Where a page needs a reload to see a projection, wrap reload and assertion in `toPass` with an explicit timeout (inference).
4. D048: Playwright results do not feed Vitest coverage; mutation testing here uses the Vitest runner.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-e2e-testing | W3D-5 to 8, 10, 17, 18, 32 | Config, auth, flaky, screenshots, scans |

## Candidate New Skills/Agents

None.

## Key Terminology

Flaky, Storage state, Setup project, Web-first assertion, Baseline.

## Caveats

- [unverified] Coverage collection from Playwright; network mocking; sharding and CI pages (not read); whether clicking a native `option` fails.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| W3D-5: default timeout short for a projection | 5 s for assertions and `expect.poll` | Confirmed; "short" depends on the app. DOM assertions do not refetch (inference) |
| W3D-6: `option` click on native select | Documented method is `selectOption` | Method confirmed; click failure [unverified] |
| W3D-7: zero retries, so `on-first-retry` records nothing | Retries 0; trace only on first retry | Confirmed |
| W3D-8: storage state cannot hold memory; global setup has no `page` | Memory not listed; sessionStorage excluded; no fixtures | Confirmed (memory by omission) |
| W3D-10: flaky does not fail by itself | Failing on flaky is a separate option; `skip` does not run | Confirmed (exit zero inferred; default not stated) |
| W3D-17: unscoped scan runs all rules | Yes; use tags | Confirmed |
| W3D-18: baseline location | `-snapshots` folder beside the spec | Confirmed |
| W3D-32: runner overlap | Playwright also matches `.test.` files in `testDir` | Confirmed; set `testDir` |
