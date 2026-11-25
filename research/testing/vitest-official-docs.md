# Vitest and Vitest Coverage Official Documentation
**Authors:** The Vitest project (vitest-dev/vitest)
**Domain:** Testing (unit and component, TypeScript); decision D048 follow-up A

Accessed 2026-11-25. Latest 5.1.1; Node `^22.12.0 || ^24.0.0 || >=26.0.0`; Vite 6.4, 7 or 8 (R = https://registry.npmjs.org/vitest/latest). Pages: C = https://vitest.dev/config/coverage (v5.1.1), G = https://vitest.dev/guide/coverage, S = https://raw.githubusercontent.com/vitest-dev/vitest/v5.1.1/packages/vitest/src/node/coverage.ts. Pages were read through a summarising fetch tool. Nothing was run.

## Core Concepts

### Providers
- `v8` (default, `@vitest/coverage-v8`) or `istanbul` (`@vitest/coverage-istanbul`); coverage packages are pinned to the same version in peer dependencies (G, C, R).
- Since 3.2.0, AST-based remapping makes v8 reports match Istanbul's. v8 does not work on Firefox, Bun or Cloudflare Workers (G).

### Which files count
- By default only files imported during the run are reported; `coverage.include` is needed to count untested files (G, C). Source: with `include` unset, no untested files are added and only `exclude` filters (S).
- `coverage.exclude` defaults to `[]` (C). Whether test files are excluded automatically is [unverified].
- `coverage.excludeAfterRemap` (false) re-applies exclusions to original sources. `coverage.all` is not on the v5 page (C).

### Thresholds (C)
- `thresholds.lines`, `.branches` (also functions, statements): positive = minimum percent; negative = maximum uncovered items.
- `thresholds.100` (false) sets global thresholds to 100.
- `thresholds.perFile` (false): `true` checks each file instead of the aggregate; an object (`100`, `lines`, `branches`...) adds per-file limits while top-level aggregate limits still apply (C, S).
- Glob keys set thresholds for matching files; those files still count globally.
- `thresholds.autoUpdate` (false) updates thresholds when coverage improves.
- A violation does not throw: it logs an error and sets `process.exitCode = 1` (S).
- A glob matching no files with `perFile` reports nothing (S). The result for zero lines or branches, and for an empty non-per-file glob, is [unverified].

### Ignore comments (G)
- `/* v8 ignore ... */` or `/* istanbul ignore ... */`: `if`, `else`, `next`, `start`/`stop`, `file`, try/catch, switch/case.
- TypeScript is transformed by esbuild, which strips comments: add `-- @preserve`.
- `coverage.ignoreClassMethods` ignores named class methods (C).

### Test discovery
- Default test `include` is `**/*.{test,spec}.?(c|m)[jt]s?(x)` (https://vitest.dev/config/include), so Playwright `*.spec.ts` files match unless excluded.
- `passWithNoTests` defaults to false (https://vitest.dev/config/passwithnotests).

- Default test `exclude` is only `**/node_modules/**` and `**/.git/**`; setting it replaces the default, so spread `configDefaults.exclude` (https://vitest.dev/config/exclude).

## Actionable Techniques (design is this note's, for D048 A)

Enforcing 100% lines and branches:

```ts
test: { coverage: {
  provider: 'v8',
  include: ['src/**/*.{ts,tsx}'],
  exclude: [/* approved list only; test files; generated code */],
  thresholds: { lines: 100, branches: 100, perFile: true },
} }
```

1. Pin `vitest` and the coverage package to one version; run with coverage enabled in the gate command; fail on any nonzero exit.
2. `include` is mandatory, or untested files vanish and 100% is hollow.
3. At 100%, per-file mainly names the failing file; keep `autoUpdate` off and never use negative or glob thresholds to relax the gate.
4. A tested script compares `exclude`, `ignoreClassMethods` and every ignore comment with a register: machine-generated code is automatic, everything else needs a reason and product-owner approval. It also fails a narrowed `include`.
5. A script also checks that every source file appears in the JSON or lcov report, and that totals are not zero (reporter choice [unverified]).
6. Playwright runs do not feed these numbers unless coverage is separately collected and merged (not researched).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-component-testing | W3D-27, 32; no coverage setting | Config, thresholds, exclusions |
| test-pyramid, ci-pipeline | 80% branch floor is superseded by D048 | Front-end enforcement |

## Candidate New Skills/Agents

None.

## Key Terminology

Coverage provider, Threshold, Per-file threshold, Ignore hint.

## Caveats

- [unverified] `allowOnly`; setup-file and fake-timer APIs; branch counting for zero totals; Vite 8 comment handling (the esbuild wording is the page's).

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3D-32 [GK]: Vitest picks up `*.spec.ts` | Default include matches it; exclude the e2e folder | Confirmed |
| Component skill: no Vitest coverage setting | Settings above | Supported |
