# Quality Gate Targets: The Full Annotated Makefile

Self-contained reference for every target `go-makefile/SKILL.md` names. Each target below is
specified as a contract — exact command, what it consumes, what "pass" and "fail" mean
mechanically, and why it sits where it does in `make ci`'s order — not just a one-line
description. This is the file `go-makefile` actually emits into a generated Go service.

---

## The Complete Makefile

```makefile
# Makefile — standard Go service task interface. Every target here runs identically
# on a laptop and in CI (reusable-go-ci.yml / ci-pipeline) — no CI-only branch, no
# secret-gated target, no environment variable this Makefile requires that a local
# developer can't also set. That identity is the CI-Parity Principle; see SKILL.md.
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

GO        ?= go
PKG       := ./...
VERSION   ?= $(shell git describe --tags --always --dirty)
IMAGE     ?= $(SERVICE_NAME):$(VERSION)
COVER_MIN ?= 80

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---- Build ----
.PHONY: build
build: ## Build the server binary for local/dev use
	CGO_ENABLED=0 $(GO) build -trimpath -ldflags="-s -w -X main.version=$(VERSION)" -o bin/server ./cmd/server

.PHONY: generate
generate: ## Run code generation (oapi-codegen, mocks) — must precede vet/lint/arch
	$(GO) generate $(PKG)

## ---- Test & verify (the gates, in CI order) ----
.PHONY: tidy
tidy: ## Verify go.mod/go.sum are tidy — cheapest check, runs first
	$(GO) mod tidy -diff

.PHONY: vet
vet: ## go vet — compiler-adjacent correctness checks
	$(GO) vet $(PKG)

.PHONY: lint
lint: ## golangci-lint — style, bugs, complexity (see .golangci.yml)
	golangci-lint run

.PHONY: arch
arch: ## Enforce the Dependency Rule (fitness function; go-project-structure is authoritative)
	@./scripts/check-imports.sh

.PHONY: vuln
vuln: ## govulncheck — reachable-call-graph vulnerability scan (source only, not the image)
	govulncheck $(PKG)

.PHONY: test
test: ## Unit + integration tests, race detector always on
	$(GO) test -race -shuffle=on -timeout=120s $(PKG)

.PHONY: cover
cover: ## test, plus coverage measured and enforced against COVER_MIN
	$(GO) test -race -covermode=atomic -coverprofile=coverage.out $(PKG)
	@./scripts/check-coverage.sh coverage.out $(COVER_MIN)

.PHONY: bench
bench: ## Single-run benchmark with allocation reporting (dev-time; see references/coverage-and-benchmark-standard.md)
	$(GO) test -run=^$$ -bench=. -benchmem $(PKG)

## ---- Container (local convenience only — CI builds via docker/build-push-action, not this target) ----
.PHONY: docker
docker: ## Build the production image locally
	docker build --build-arg VERSION=$(VERSION) -t $(IMAGE) .

## ---- Aggregate ----
.PHONY: ci
ci: tidy generate vet lint arch vuln cover ## Everything CI runs — the one command that gates a merge
	@git diff --exit-code   # generated code / go.mod must be committed and current
```

`bench` and `docker` are deliberately **absent from `ci`**. `bench` is a single, unreplicated run —
useful for a developer iterating on a hot path (`go-performance-optimization`'s domain), but not
statistically valid evidence of a regression; the CI-gated, `benchstat`-compared version of this
same measurement is `go-performance-test`'s dedicated job, run separately from `make ci` because
a `-count=10` benchmark sweep is too slow for the PR-loop fast-feedback budget. `docker` is a
local convenience; the platform's CI image step (`ci-pipeline`) calls `docker/build-push-action`
directly for registry-aware layer caching and digest output, not this target — the two build the
same `Dockerfile` (`go-dockerfile`'s domain) through different front doors for different reasons
(local iteration speed vs. registry cache reuse).

---

## Per-Target Contract

### `tidy`

**Command:** `go mod tidy -diff` — the `-diff` flag makes this a **read-only check**: it prints
what `go mod tidy` would change and exits non-zero if anything would change, rather than
rewriting `go.mod`/`go.sum` in place. A target that mutates files during `make ci` is a defect —
CI must never produce a diff a developer has to pull down; it must only *detect* one.

**Fails when:** an import was added without `go mod tidy` having been run since; an unused
module still listed in `go.mod`; `go.sum` missing an entry.

**Why it runs first:** it is the cheapest possible check — no compilation, no test execution, a
few hundred milliseconds — and it catches the single most common "forgot a step" mistake before
anything more expensive runs. Fail-fast on the cheapest check is a direct CI-cost optimization:
a developer who forgot `go mod tidy` gets told in under a second, not after a two-minute test run.

### `generate`

**Command:** `go generate ./...` — runs every `//go:generate` directive in the module
(`oapi-codegen` for OpenAPI-derived types and server interfaces, `mockgen`/`moq` for test
doubles).

**Why it runs second, before `vet`/`lint`/`arch`:** those three targets analyze source as it
exists on disk. If generated code is stale, `vet` and `lint` are validating code nobody will
ship, and `arch`'s import-graph walk (`go list -deps`) can miss a dependency a *regenerated*
file would introduce. Running `generate` before the static-analysis targets, then checking for
an uncommitted diff at the very end of `ci`, is what turns "generated code drifted from its
source" into a caught CI failure instead of a silent runtime surprise.

**Freshness enforcement:** `ci`'s trailing `git diff --exit-code` is what actually fails the
build on drift — `generate` itself only regenerates; it never checks by itself. The two work
together: `generate` produces current output, `git diff --exit-code` proves nothing changed
(meaning what was committed was already current).

### `vet`

**Command:** `go vet ./...` — the standard library's own static analyzer: unreachable code,
suspicious `Printf` format-verb/argument mismatches, struct tags that don't parse, lock values
copied by value, and other errors the compiler intentionally does not treat as compile errors
because they're sometimes (rarely) intentional.

**Why third:** faster than `lint` (a small, fixed analyzer set vs. `golangci-lint`'s configurable
many), and any `vet` finding is close to unambiguously a bug — cheap and high-signal, so it runs
before the heavier, more opinionated lint pass.

### `lint`

**Command:** `golangci-lint run`, configured by `.golangci.yml` (committed at the module root,
version-pinned in CI — `ci-pipeline` installs a pinned `golangci-lint` release, never `@latest`,
so a linter upgrade can't silently fail an unrelated PR).

**Baseline enabled set** (on top of golangci-lint's own defaults —
`errcheck`, `govet`, `staticcheck`, `unused`, `gosimple`, `ineffassign` — already on by default
and never disabled):

```yaml
# .golangci.yml
run:
  timeout: 5m
linters:
  enable:
    - bodyclose      # HTTP response bodies must be closed — a goroutine/fd leak otherwise
    - sqlclosecheck   # *sql.Rows / *sql.Stmt must be closed
    - noctx           # HTTP requests built without a context — no way to cancel/time out
    - gosec           # security-pattern static analysis (hardcoded creds, weak crypto, etc.)
    - gocyclo         # cyclomatic complexity
    - misspell        # comments/strings — cheap, catches doc rot early
linters-settings:
  gocyclo:
    min-complexity: 15   # a function above this is a refactor candidate, not just a lint nag
```

**Fails when:** any enabled linter reports a finding — `golangci-lint run` exits non-zero on any
finding by default; there is no "warnings don't fail the build" mode in CI. A finding is either
fixed or explicitly suppressed with a `//nolint:<linter>` comment carrying a reason — a bare
`//nolint` with no linter name and no reason is itself a `nolintlint`-caught violation.

**Why fourth:** `golangci-lint` runs multiple analyzers (some of them, like `staticcheck`,
whole-program) and is measurably slower than `vet` alone, but still purely static — no test
execution, no network — so it precedes `arch` and `vuln` only because those two are each cheaper
individually; the four together (`vet`, `lint`, `arch`, `vuln`) are all "no test run needed"
checks and collectively front-load everything that doesn't require compiling and executing the
test suite, which is `cover`'s job and the most expensive step in the chain.

### `arch`

**Command:** `./scripts/check-imports.sh` — the Dependency Rule fitness function. This skill
emits the script; **`go-project-structure`'s `references/architecture-fitness-functions.md` is
the authoritative specification of what it must do** — the full three-layer `check_layer` walk
against `internal/domain`, `internal/application`, and `internal/infrastructure`, using
`go list -deps` to catch transitive violations, reporting every violation found (not just the
first) before exiting non-zero. Reproduced here verbatim as the file this target actually
invokes:

```bash
#!/usr/bin/env bash
# scripts/check-imports.sh — architecture fitness function for the Dependency Rule.
# Invoked by `make arch`, part of `make ci`. Exits 1 and prints every violation found.
set -euo pipefail
fail=0

check_layer() {
  local layer_dir="$1"; shift
  local -a forbidden=("$@")
  [ -d "$layer_dir" ] || return 0
  local deps
  deps="$(go list -deps "./${layer_dir}/..." 2>/dev/null || true)"
  for pattern in "${forbidden[@]}"; do
    local hits
    hits="$(echo "$deps" | grep -E "$pattern" || true)"
    if [ -n "$hits" ]; then
      echo "ERROR: ${layer_dir} imports forbidden dependency matching '${pattern}':"
      echo "$hits" | sed 's/^/  /'
      fail=1
    fi
  done
}

check_layer "internal/domain" \
  'jackc/pgx' 'go-chi/chi' 'go\.opentelemetry\.io' 'twmb/franz-go' \
  '/internal/application' '/internal/infrastructure' '/internal/handlers'
check_layer "internal/application" \
  'jackc/pgx' 'go-chi/chi' 'twmb/franz-go' \
  '/internal/handlers' '/internal/infrastructure'
check_layer "internal/infrastructure" \
  '/internal/handlers'

exit $fail
```

**Fails when:** any layer imports (directly or transitively) a package matching its forbidden
list. **What it does not catch** — stdlib I/O reaching into `domain` (`os`, `net`,
`database/sql` are not on any pattern list), interface-ownership violations, or same-layer
lateral coupling — is a deliberate, documented trade-off owned by
`go-project-structure/references/architecture-fitness-functions.md`; this skill does not
re-litigate that honesty, it inherits it.

**Why fifth:** requires a successful `go list -deps`, which itself requires the module to
compile — so it necessarily follows `vet`/`lint` in spirit (nothing enforces the ordering
mechanically, but a build that doesn't compile fails here anyway) and is cheaper than `vuln`
(no network/vulnerability-database lookup, pure local import-graph walk).

### `vuln`

**Command:** `govulncheck ./...` — scans the module's **reachable call graph** against the Go
vulnerability database and reports only vulnerabilities in functions your code can actually
reach, not every CVE in every transitive dependency (the low-false-positive property that makes
it usable as a hard CI gate rather than an ignored report).

**Scope, precisely — do not conflate with `go-dockerfile`'s Trivy gate:** `govulncheck` scans
**Go source** — the module's own code and its dependency call graph. It never inspects the built
container image, the base-image OS packages, or any non-Go file in the final layer. `trivy image`
(`go-dockerfile`'s `references/image-size-and-security-standard.md`) is the complementary,
non-overlapping check on the **built image's filesystem** — OS-package CVEs `govulncheck`
structurally cannot see because it never leaves the Go call graph. Both run; neither replaces the
other; `vuln` gates here in `make ci` on every commit, `trivy image` gates in `ci-pipeline`'s
platform-owned image stage after `make docker`/`docker/build-push-action` produces something to
scan.

**Why sixth, last among the no-test-run checks:** it is a network call (or a locally cached
vulnerability-database lookup) — the least deterministic and potentially slowest of the five
static checks, so it runs after every check that can fail without touching the network.

### `test` / `cover`

Full standard (race detector, coverage threshold and its exclusions, `-shuffle=on`) in
`references/coverage-and-benchmark-standard.md`. In brief: `-race` is never optional, coverage is
enforced (not just measured) against `COVER_MIN`, and this is the single most expensive step in
`ci` — compiling and executing the entire test suite with the race detector's instrumentation
overhead — which is exactly why it runs last: every cheaper check that could have failed the
build already had its chance to fail it for free.

### `bench`

Dev-time single-run benchmark; CI-gated statistical regression detection is
`go-performance-test`'s separate job. Full boundary and mechanics:
`references/coverage-and-benchmark-standard.md`.

### `docker`

Thin wrapper over `docker build`, tagging with `$(VERSION)` (from `git describe`). The Dockerfile
itself — multi-stage, distroless, non-root, exec-form `ENTRYPOINT` — is entirely
`go-dockerfile`'s domain; this target's only job is invoking it identically to how a developer
would by hand, so "it builds with `make docker`" and "it builds in CI" never diverge.

### `ci`

The aggregate. Order is fixed and is not alphabetical or incidental — it is the fail-fast cost
ordering derived target-by-target above: `tidy` (milliseconds, no compile) → `generate`
(must precede any check reading generated code) → `vet` (fast, high-signal) → `lint`
(slower, still static) → `arch` (needs a successful build, no network) → `vuln` (network/DB
lookup) → `cover` (compiles and executes the entire test suite under `-race`, the most
expensive step by a wide margin). The trailing `git diff --exit-code` is the freshness gate:
if `generate` or `tidy` would have changed a tracked file, the working tree is dirty at this
point and the build fails — uncommitted generated code or an untidy `go.mod` never merges.
