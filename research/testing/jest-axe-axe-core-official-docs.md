# jest-axe and axe-core Official Documentation
**Authors:** NickColley (jest-axe); Deque Systems (axe-core)
**Domain:** Testing (automated accessibility)

Accessed 2026-11-25. jest-axe 11.0.0 depends on axe-core 4.12.1, Node >=18 (https://registry.npmjs.org/jest-axe/latest); axe-core latest 4.14.1 (https://registry.npmjs.org/axe-core/latest). J = https://raw.githubusercontent.com/NickColley/jest-axe/main/README.md; A = https://raw.githubusercontent.com/dequelabs/axe-core/develop/README.md (development branch). Read through a summarising fetch tool. Nothing was run.

## Core Concepts

- jsdom support is limited; `color-contrast` is known not to work there (A). jest-axe turns contrast checks off (J).
- axe-core states it finds on average 57% of WCAG issues automatically; "incomplete" results need manual review (A).
- jest-axe warns automated checks miss many barriers (it cites a GDS figure of about 30%; exact framing [unverified]) and that assistive-technology and user testing are still needed (J).
- `configureAxe` sets shared defaults; options include `rules`, `globalOptions`, `impactLevels` (J).
- Disable `region` for isolated components (J).
- With fake timers axe often times out; switch to real timers around it (J).
- The README documents Jest only, not Vitest (J).

### Tags and results (https://raw.githubusercontent.com/dequelabs/axe-core/develop/doc/API.md)
Tags include `wcag2a`, `wcag2aa`, `wcag21aa`, `wcag22aa`, per-criterion tags and `best-practice`. `runOnly` by tag is not cumulative. By default all enabled rules run (experimental off). Results: `passes`, `violations`, `incomplete`, `inapplicable`.

## Actionable Techniques (design is this note's)

1. One shared `configureAxe` helper; disabled rules and any `impactLevels` filter listed with reasons.
2. Check contrast in a real browser scan, never in jsdom.
3. Report that a clean scan is partial coverage; keep keyboard assertions and a manual pass.
4. Pin both packages; the axe-core that jest-axe uses can differ from the browser scanner's.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-component-testing, react-accessibility | W3D-20, 25 | Contrast limit, automation share |
| react-e2e-testing | W3D-17 | Contrast belongs there |

## Candidate New Skills/Agents

None.

## Key Terminology

Violation, Incomplete, Rule, Impact level.

## Caveats

- [unverified] Vitest matcher registration for jest-axe 11.

## Answers to audit questions

| Claim | Answer | Status |
|---|---|---|
| W3D-20: jest-axe cannot check contrast in jsdom | Rule off; does not work | Confirmed |
| "30 to 40%" of issues (no source) | axe-core says 57% on average | Not supported by the pages read; axe-core gives a different figure |
| W3D-17: unscoped scan runs all rules; no 2.1 AA tags | All enabled rules run; limit by tags | Confirmed |
