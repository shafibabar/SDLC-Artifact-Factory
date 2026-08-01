---
name: react-e2e-testing
description: >
  Teaches end-to-end testing of this plugin's composed shell + remotes
  microfrontend app with Playwright: the scope boundary against
  react-component-testing (one real browser exercising the full
  composition vs. one component rendered in isolation with a mocked
  network), the cross-remote user-journey standard (a journey that starts
  in the shell, acts inside one remote, and asserts the effect surfaces in
  a DIFFERENT remote — proving the composition itself, not each fragment
  alone), targeting the SAME ephemeral environment go-e2e-test already
  provisions rather than a separate frontend-only stack, condition-based
  flakiness hardening (Playwright auto-waiting and expect.poll, never a
  fixed sleep), and the narrow, explicitly-scoped case for visual
  regression. Realizes the journey-level acceptance criteria. Used by the
  frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, e2e, playwright, user-journey, microfrontend, cross-remote, flakiness, testing]
produces: react-e2e-test-suite
domain: testing
status: stable
related: [react-component-testing, react-routing, microfrontend-architecture, go-e2e-test, react-accessibility]
---

# React E2E Testing

## Purpose

E2E tests prove the **composed** app works as a user actually uses it —
real browser, real shell, real Module Federation remote loading. Only
this layer can prove a cross-fragment journey works: classifying a data
asset in one independently-deployed remote surfaces in a different
remote, through the real backend — invisible to single-fragment component
tests, which each render only one component tree in isolation
(`react-component-testing`'s scope, restated in Standard 1).

E2E sits at the **top** of the test pyramid (`test-pyramid`): few,
high-value, full-composition — never a second, slower copy of the
component suite. Full worked examples: `references/cross-remote-journey-
standard.md` and `references/flakiness-and-visual-regression-standard.md`.

---

## Standard 1 — Scope Boundary: E2E vs. Component Testing

`react-component-testing` renders "one component in isolation" via RTL +
jsdom, mocking only "the network... never a component's own hooks or
modules." E2E is everything that boundary cannot reach:

| | Component test | E2E test |
|---|---|---|
| Renders | One component, isolated, jsdom | Composed shell + remotes app, real browser |
| Routing | Not exercised | Real Module Federation loading + navigation |
| Network | MSW-mocked, always | Mocked-edge or real backend (Standard 2) |
| Proves | This component given props/mock | This journey across real fragment boundaries |
| Cannot prove | Anything crossing a fragment boundary | — |

A handful of cross-remote journeys plus the P1 single-fragment journeys
(`user-journey-mapping`) give most of the confidence; pushing
component-level permutations (`react-component-testing`'s "Cover Every
State and Interaction") into e2e inverts the pyramid for no new coverage.

---

## Standard 2 — Tool, Environment, and Network Strategy

**Tool: Playwright, retained.** Prior content already committed fully to
Playwright (config, `AxeBuilder`, role-based locators) with no Cypress
anywhere in this codebase — kept rather than reopened. Built-in
multi-page/multi-context support and auto-waiting suit a shell+remotes
journey that may cross separately-served origins during local/dev remote
loading. Tests live in `tests/e2e/`.

**Environment: the same stack `go-e2e-test` provisions.** Its strategy
spins up "API + Postgres + Redpanda **(+ UI)**" as one ephemeral stack
(Testcontainers/docker-compose) for CI/local, plus a small seeded-staging
smoke suite in CD. A frontend e2e test's real-backend tier targets **that
same environment** — never a separate frontend-only mock stack — since
Standard 3's cross-remote journey proves the real backend connects two
remotes.

**Network, split by mode:**

| Mode | How | Use for |
|---|---|---|
| **Mocked edge** | Playwright `route()`, contract-shaped fixtures | Fast, deterministic single-fragment journeys; runs standalone against a dev server |
| **Real backend** | The ephemeral stack above | The cross-remote smoke suite — mocking here hides the integration under test |

Fixtures use the OpenAPI-contract shapes (no drift). Full config and
fixture code: `references/cross-remote-journey-standard.md`.

---

## Standard 3 — Cross-Remote User-Journey Standard

The highest-value thing an e2e journey proves: an action in one
independently-deployed remote surfaces its effect in a **different**
remote, via the real backend (a Domain Event + projection — never a
cross-fragment client store, which `microfrontend-architecture` forbids).
Shape of every such journey:

1. Enter through the **shell** (`react-routing`'s Standard 1) — never a
   remote's dev URL directly.
2. Act inside the first remote using role/label locators.
3. Navigate via a **shell-owned link** — the real remote-load path, not a
   fresh `page.goto` that would skip it.
4. Assert the second remote reflects the action — **polling**, since the
   projection is eventually consistent, exactly as `go-e2e-test`'s own
   `awaitGapReportReflects` polls on the backend.

Full worked test (classify in data-assets, observe in
compliance-dashboard): `references/cross-remote-journey-standard.md`.

---

## Standard 4 — Authentication and Accessibility In-Flow

Authenticate **once**, reuse `storageState` — a remote never keeps
independent auth state (`react-routing`), so one shell sign-in covers a
journey crossing any number of remotes; real-backend runs mint a
test-only JWT, never a production credential (`secrets-management`). Run
an axe scan (`@axe-core/playwright`) at journey checkpoints, including
right after a cross-remote navigation — role/label locators throughout
double as an accessibility check. Setup code:
`references/cross-remote-journey-standard.md`.

---

## Standard 5 — Flakiness Hardening

Rely on Playwright's auto-waiting (`expect(locator).toBeVisible()`) and
`expect.poll()` for non-DOM conditions — never `page.waitForTimeout()`,
identical to `go-e2e-test`'s own rule ("wait for a condition, not a
duration"): one flakiness standard governs both surfaces of its "Two
Surfaces, One Journey" split. A flaky spec is quarantined with an issue
and a deadline, never buried under retry-to-green — `go-e2e-test`'s
quarantine policy applies unchanged. Full shapes:
`references/flakiness-and-visual-regression-standard.md`.

---

## Standard 6 — Visual Regression: Narrow, Deferred by Default

Deferred for the general suite — expensive to maintain, prone to false
positives from font-rendering drift across CI runners. In scope only for
pages that are both high-consequence when visually broken (the
compliance gap-report view, whose exported PDF an auditor receives) and
visually stable. Uses Playwright's built-in `toHaveScreenshot()` — no
paid visual-regression service, per CLAUDE.md § Budget and Frugality.
Full reasoning: `references/flakiness-and-visual-regression-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Pyramid-appropriate; scope respected | Few high-value journeys; permutations stay in component tests | E2E duplicating `react-component-testing`'s coverage |
| Cross-remote journeys covered | P1 journeys crossing a fragment boundary tested end to end | Fragments tested only in isolation; composition unverified |
| Journey shape correct | Shell entry; real remote-load navigation; poll for consistency | Direct remote URL; `page.goto` skipping shell nav; immediate assert |
| Role/label locators; fast auth | `getByRole`/`getByLabel`; reused storage state; test-only tokens | testid/CSS selectors; UI login per test; production creds |
| Environment reuse; a11y in-flow | Real-backend tier targets `go-e2e-test`'s stack; axe scans incl. post-cross-remote nav | Separate frontend-only mock backend; no in-flow a11y checks |
| No arbitrary sleeps; flakiness governed | Auto-waiting/`expect.poll`; quarantine with issue+deadline | `waitForTimeout`; retry-to-green as policy |
| Visual regression scoped | Only named critical, stable pages, pinned browser | Full-suite screenshot diffs across the matrix |

---

## Anti-Patterns

- **The inverted pyramid** — re-testing permutations `react-component-testing` already covers.
- **Direct remote URL entry / a fresh `page.goto` standing in for cross-remote navigation** — bypasses shell auth context and the real remote-load path the journey exists to prove.
- **Asserting immediately after a cross-remote action** — the second remote's data is an eventually-consistent projection; use `expect.poll`.
- **`page.waitForTimeout(3000)` / CSS/XPath/testid archaeology** — a sleep is a guess and a brittle selector breaks on any restyle; await a visible outcome via role/label locators instead.
- **UI login per test / retry-to-green** — reuse one `storageState`; quarantine a flaky spec, don't retry it to green.
- **Full-suite visual regression across the whole browser matrix** — the exact false-positive source this standard avoids.

---

## Output Format

Produces Playwright specs and e2e infrastructure:

```
tests/e2e/*.spec.ts                (single-fragment + cross-remote journey tests)
tests/e2e/global-setup.ts          (auth storage state)
playwright.config.ts
tests/e2e/fixtures/*.ts            (contract-aligned route fixtures)
tests/e2e/*.png                    (visual-regression baselines, narrowly scoped — Standard 6)
```
