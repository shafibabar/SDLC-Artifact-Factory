---
name: go-makefile
description: >
  Teaches the standard CI-parity Makefile that gates every Go service in this
  plugin: the exact fail-fast target order (tidy, generate, vet, lint, arch,
  vuln, cover) and the cost reasoning behind that order, the CI-Parity
  Principle (every target runs identically local and in CI, no CI-only
  branch), the race-detector-always-on standard, the enforced (not merely
  measured) coverage threshold and its generated-code/composition-root
  exclusions, the arch target as the Dependency Rule fitness function
  (authoritative script owned jointly with go-project-structure), the vuln
  target's govulncheck scope versus go-dockerfile's Trivy image scan, the
  golangci-lint configuration standard, and the boundary between a dev-time
  bench run here and go-performance-test's CI-gated benchstat regression
  gate. Full annotated Makefile and per-target contract in
  references/quality-gate-targets.md; coverage/benchmark mechanics in
  references/coverage-and-benchmark-standard.md. Used by the backend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, makefile, ci, ci-parity, race-detector, lint, govulncheck, coverage, benchmark, fitness-function]
related: [go-project-structure, go-dockerfile, ci-pipeline, go-performance-test, test-pyramid]
---

# Go Makefile

## Purpose

The Makefile is the single, memorable interface to every routine task on a service — the exact
commands a developer runs on a laptop are the exact commands CI runs, nothing translated,
nothing re-implemented in YAML. It encodes the blueprint's verification gates (race detection,
coverage, the architecture invariant, vulnerability scanning) as first-class targets so "it
passes on my machine" and "it passes in CI" are the same claim, not two claims that happen to
usually agree. `make ci` is the one command that gates a merge; if it is green, the change
satisfies every standard this plugin holds for backend code.

This skill produces the Makefile and the scripts it invokes (`check-coverage.sh`,
`check-imports.sh`) and the linter config (`.golangci.yml`). `docker` is a thin, local-only
wrapper over `docker build` — CI's own image stage (`ci-pipeline`) calls `docker/build-push-action`
directly for registry caching and digest output instead, building the same `Dockerfile`
(`go-dockerfile`'s domain). The Dependency Rule this Makefile enforces is defined by
`go-project-structure`.

---

## The CI-Parity Principle

Every target must be invocable identically on a developer's machine and inside CI — no target
that only works because a CI-only secret, a CI-only environment variable, or a CI-only network
path is present. `vuln` reads the public Go vulnerability database the same way in both places;
`cover` writes `coverage.out` to the same relative path in both places. The moment a target
diverges — a "fast" local variant, a CI-only extra flag — "passes locally" and "passes in CI"
stop being the same claim, and the gap is exactly where "worked on my machine" bugs live. If a
check genuinely cannot run without CI-only infrastructure (a live staging cluster, a paid
scanning service), it does not belong in this Makefile at all — it belongs in a separate,
explicitly-named pipeline stage that nobody mistakes for a local command.

---

## The Standard Makefile (excerpt)

Full annotated listing and the per-target contract (exact command, pass/fail semantics, why it
sits where it does): `references/quality-gate-targets.md`.

```makefile
.PHONY: ci
ci: tidy generate vet lint arch vuln cover ## Everything CI runs — the one command that gates a merge
	@git diff --exit-code   # generated code / go.mod must be committed and current
```

---

## The Gate Order Is a Fail-Fast Cost Ordering

`tidy → generate → vet → lint → arch → vuln → cover` is not alphabetical — each target runs only
after every *cheaper* check that could have failed the build already had its chance to, so a
developer never waits minutes for a race-enabled test run to learn about a typo `go vet` would
have caught in milliseconds:

| Order | Target | Relative cost | Why here |
|---|---|---|---|
| 1 | `tidy` | Milliseconds, no compile | Cheapest possible check; catches the most common "forgot a step" mistake first |
| 2 | `generate` | Fast | Must produce current generated code before anything downstream analyzes or imports it |
| 3 | `vet` | Fast, needs a compile | Small, fixed, high-signal analyzer set |
| 4 | `lint` | Moderate | `golangci-lint`'s larger, configurable analyzer set — still purely static |
| 5 | `arch` | Fast, no network | Local import-graph walk (`go list -deps`) |
| 6 | `vuln` | Network/DB lookup | Least deterministic of the static checks |
| 7 | `cover` | Slowest by far | Compiles and executes the entire suite under `-race` |

`bench` and `docker` are intentionally absent from `ci` — see "Benchmarks" and "Container Build"
below. Full reasoning per target: `references/quality-gate-targets.md`.

---

## The Race Detector Is Non-Negotiable

`-race` is on for **every** test run — `test` and `cover` both, local and CI, never a separate
"fast" path without it. The blueprint requires zero data races; the only way to guarantee that is
to never run tests without the detector. A race that appears only under `-race` in CI but not in
a developer's habitual un-raced local run is the worst kind of flake — universal `-race` closes
that gap by construction. Coverage is measured with `-covermode=atomic` specifically because
`-race` is active: atomic counters are the only coverage-counter mode safe to increment under
concurrent, race-detector-instrumented access.

---

## Coverage: Enforced, Not Merely Measured

**80%** (`COVER_MIN`), consistent with the number `test-pyramid` and `ci-pipeline` already
establish — this skill is the mechanism that enforces it, not a fourth source of truth.
`check-coverage.sh` fails the build below threshold; a number printed to a log gates nothing.
Excluded from the count: generated files and mocks (`_gen.go`, `.pb.go`, `_mock.go` — filtered
from the profile before the percentage is computed, since they compile into tested packages and
would otherwise inflate or deflate the number on churn nobody wrote). `cmd/**` composition roots
need no filter — they carry no `_test.go` files by design (`go-project-structure`: a composition
root that decides anything is "untestable without booting the process"), so `go test`'s default
profile never contains them in the first place. Full script and rationale:
`references/coverage-and-benchmark-standard.md`.

---

## `arch`: The Dependency Rule Fitness Function

`arch` runs `check-imports.sh`, a **fitness function** (Clean Architecture's term: an automated,
executable check guarding an architectural invariant, run on every build, rather than trusted to
reviewer vigilance). The script's authoritative specification is
`go-project-structure/references/architecture-fitness-functions.md` — the full three-layer walk
against `internal/domain`, `internal/application`, and `internal/infrastructure`, using
`go list -deps` to catch transitive violations and reporting every violation found, not just the
first. `go-makefile` emits and invokes that exact script; it does not define a second, different
mechanism. Full reproduction and per-layer breakdown: `references/quality-gate-targets.md`.

```bash
# scripts/check-imports.sh — see references/quality-gate-targets.md for the full script
check_layer "internal/domain" 'jackc/pgx' 'go-chi/chi' 'go\.opentelemetry\.io' ...
```

This pairs with the architecture governance hook — defence in depth on the Dependency Rule, not
a substitute for it: the hook can catch a design intent problem before code exists; this script
catches an actual import-graph violation once code does.

---

## `vuln`: `govulncheck`, Not the Image Scan

`vuln` runs `govulncheck ./...` — scans **reachable Go source** (the module's own call graph)
against the vulnerability database, reporting only vulnerabilities in functions the code can
actually reach. It never inspects the built container image or OS-layer packages. `go-dockerfile`
owns the complementary, non-overlapping check: `trivy image` scans the **built image's
filesystem** for OS-package CVEs `govulncheck` structurally cannot see. Both run; neither
replaces the other. `vuln` gates here in `make ci`, on every commit; `trivy image` gates in
`ci-pipeline`'s platform-owned image stage, after the image exists to scan.

---

## Benchmarks: Dev-Time Here, CI Gate Elsewhere

`bench` runs a single, unreplicated `go test -bench=. -benchmem` pass — never under `-race`
(instrumentation overhead makes timing/allocation numbers meaningless, and race-safety is already
verified by `test`/`cover`). A single run is directionally useful while actively optimizing
(`go-performance-optimization`'s use of it) and **never sufficient evidence to gate a merge** —
run-to-run variance exceeds most real regressions. The statistically valid, CI-gated version
(`benchstat` over `-count=10` against a committed baseline, its own dedicated CI job, deliberately
not part of `make ci`) is `go-performance-test`'s domain. `go-makefile` does not re-implement that
comparison; it emits only the single-run target `go-performance-test`'s job builds on top of.
Full boundary: `references/coverage-and-benchmark-standard.md`.

---

## `lint`: golangci-lint Configuration Standard

`.golangci.yml` is committed at the module root; CI installs a **version-pinned** release, never
`@latest` — an upstream linter upgrade must never be able to fail an unrelated PR. Beyond the
built-in defaults (`errcheck`, `govet`, `staticcheck`, `unused`, `gosimple`, `ineffassign`), this
plugin enables `bodyclose`/`sqlclosecheck` (an unclosed response body or `*sql.Rows` is a slow
leak, not a crash — needs a static check, not production discovery), `noctx` (every outbound HTTP
call carries a cancellable context), `gosec`, and `gocyclo` at `min-complexity: 15`. A finding is
fixed or suppressed with `//nolint:<linter>: <reason>` — a bare, reasonless `//nolint` is itself a
caught violation. Full config: `references/quality-gate-targets.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| CI-Parity | Every target runs identically local and in CI; no CI-only branch or secret-gated logic | A target that only works in CI, or a "fast local" variant of a gate |
| Race always on | `test`/`cover` always pass `-race`; `cover` uses `-covermode=atomic` | A test target without the race detector; `count`/`set` coverage mode under `-race` |
| Single CI entry, order preserved | `make ci` runs `tidy, generate, vet, lint, arch, vuln, cover` in that order | CI re-listing ad-hoc commands; gates reordered without cost justification |
| Coverage enforced and correctly scoped | `check-coverage.sh` fails the build below `COVER_MIN`; only `_gen.go`/`.pb.go`/`_mock.go` filtered, `cmd/**` naturally absent | Coverage measured but not gating; a hand-maintained exclude-list; a `main_test.go` added only to move the number |
| `arch` matches the authoritative script | Three-layer `check_layer` walk identical to `go-project-structure/references/architecture-fitness-functions.md` | A different or partial import-check mechanism |
| `vuln` scope stated correctly | Source/call-graph only, explicitly distinct from Trivy's image scan | `vuln` and image scanning conflated as redundant |
| Bench/CI-gate boundary respected | `bench` single-run only; `benchstat` regression gating lives in `go-performance-test` | `benchstat` comparison logic duplicated into this Makefile |
| Freshness enforced | `make ci` fails on any uncommitted `generate`/`tidy` diff | Drift allowed to merge |
| Lint pinned, `.PHONY` complete | `.golangci.yml` committed; CI pins a version, never `@latest`; every target `.PHONY` | Floating linter version; a file/directory silently shadowing a target |

---

## Anti-Patterns

- **A "fast" test target without `-race`** — the moment a race-free shortcut exists it becomes
  the default, and races surface only in CI or production. One test target, detector always on.
- **CI YAML re-listing raw commands** — the pipeline drifting from the Makefile reintroduces
  "passes locally, fails in CI." CI calls `make ci`, nothing else.
- **Coverage measured but not enforced** — a printed percentage gates nothing.
- **Inventing a second `arch` mechanism** — a different or partial import check that doesn't
  match `go-project-structure`'s authoritative three-layer script creates two competing sources
  of truth for the same invariant.
- **Conflating `vuln` with the image scan**, or **re-implementing `benchstat` comparison here** —
  both blur an ownership boundary this skill deliberately keeps with `go-dockerfile` and
  `go-performance-test` respectively; each check different surfaces or serves a different owner.
- **Skipping the freshness check** — stale generated code or an untidy `go.mod` merging
  guarantees the next `make generate` produces a surprise diff for whoever runs it next.

---

## Output Format

**`Makefile`** — `tidy`, `vet`, `lint`, `arch`, `vuln`, `test`, `cover`, `bench`, `build`,
`generate`, `docker`, and the aggregate `ci` composed exactly as `tidy generate vet lint arch vuln
cover` plus the trailing `git diff --exit-code` freshness check; every target `.PHONY`. Full
listing: `references/quality-gate-targets.md`.

**`scripts/check-coverage.sh`** and **`scripts/check-imports.sh`** — full scripts and rationale
in `references/coverage-and-benchmark-standard.md` and `references/quality-gate-targets.md`
respectively; the latter identical to `go-project-structure`'s fitness-function reference.

**`.golangci.yml`** — pinned-version linter config per the standard above, committed at the
module root.
