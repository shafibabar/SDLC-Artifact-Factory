---
name: go-makefile
description: >
  Teaches the standard Makefile for a Go service — the canonical developer and CI
  task interface: build, test, the race detector, coverage, benchmarks, linting,
  vulnerability scanning, the architecture import-lint, code generation, and the
  container build. The Makefile encodes the blueprint's verification gates so the
  same commands run locally and in CI. Used by the backend-engineer during
  Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, makefile, ci, race-detector, lint, govulncheck, benchmark]
---

# Go Makefile

## Purpose

The Makefile is the single, memorable interface to every routine task on a service — the same targets a developer runs locally are the targets CI runs. It encodes the blueprint's verification gates (race detection, benchmarks, vetting) as first-class commands so "it passes on my machine" means "it passes in CI." No one needs to remember the exact `go test` incantation; they run `make test`.

This skill produces the Makefile. The CI pipeline that invokes these targets is the platform-engineer's domain (it calls `make ci`).

---

## The Standard Makefile

```makefile
# Makefile — standard Go service task interface
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

GO        ?= go
PKG       := ./...
VERSION   ?= $(shell git describe --tags --always --dirty)
IMAGE     ?= classification-service:$(VERSION)

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---- Build ----
.PHONY: build
build: ## Build the server binary
	CGO_ENABLED=0 $(GO) build -trimpath -ldflags="-s -w -X main.version=$(VERSION)" -o bin/server ./cmd/server

.PHONY: generate
generate: ## Run code generation (oapi-codegen, mocks)
	$(GO) generate $(PKG)

## ---- Test & verify (the gates) ----
.PHONY: test
test: ## Run unit + integration tests with the race detector
	$(GO) test -race -shuffle=on -timeout=120s $(PKG)

.PHONY: cover
cover: ## Run tests with coverage and enforce the threshold
	$(GO) test -race -covermode=atomic -coverprofile=coverage.out $(PKG)
	$(GO) tool cover -func=coverage.out | tail -1
	@./scripts/check-coverage.sh coverage.out 80   # fail under 80%

.PHONY: bench
bench: ## Run benchmarks with allocation reporting
	$(GO) test -run=^$$ -bench=. -benchmem $(PKG)

.PHONY: vet
vet: ## go vet
	$(GO) vet $(PKG)

.PHONY: lint
lint: ## golangci-lint (style, bugs, complexity)
	golangci-lint run

.PHONY: vuln
vuln: ## Scan for known vulnerabilities
	govulncheck $(PKG)

.PHONY: arch
arch: ## Enforce the dependency rule (domain imports no framework)
	@./scripts/check-imports.sh   # fails if internal/domain imports pgx/chi/otel/etc.

.PHONY: tidy
tidy: ## Verify go.mod is tidy
	$(GO) mod tidy -diff

## ---- Container ----
.PHONY: docker
docker: ## Build the production image
	docker build --build-arg VERSION=$(VERSION) -t $(IMAGE) .

## ---- Aggregate ----
.PHONY: ci
ci: tidy generate vet lint arch vuln cover ## Everything CI runs
	@git diff --exit-code   # generated code / go.mod must be committed and current
```

---

## Why Each Gate Exists

| Target | Gate it enforces | Blueprint tie-in |
|---|---|---|
| `test` with `-race` | **Zero data races** — mandatory | §5 Data Race Detection |
| `-shuffle=on` | Tests don't depend on execution order (hidden coupling) | Hermetic testing |
| `cover` (≥80%) | Test pyramid base is real, not theatre | §5 Verification |
| `bench` with `-benchmem` | Performance-critical paths are benchmarked with allocs | §5 Benchmark Testing |
| `vet` + `lint` | Idiomatic, bug-free, bounded-complexity code | §2 Idiomatic Go |
| `vuln` (`govulncheck`) | No known-vulnerable dependencies ship | Security supply chain |
| `arch` | The dependency rule (domain imports no framework) | Clean architecture (`go-project-structure`) |
| `tidy` + `git diff` | `go.mod` and generated code can't drift | Reproducibility |

`make ci` is the **one command** that gates a merge. If `make ci` is green, the change satisfies every standard this plugin holds for backend code.

---

## The Race Detector Is Non-Negotiable

`-race` is on for **every** test run, local and CI — not a separate occasional job. The blueprint requires zero data races; the only way to guarantee that is to never run tests without the detector. A race that only appears under `-race` in CI but not locally is the worst kind of flake; running `-race` everywhere eliminates the gap.

---

## The Architecture Lint

The `arch` target mechanically enforces the inward-only dependency rule from `go-project-structure` — so the Clean Architecture boundary is verified by tooling, not by reviewer vigilance:

```bash
# scripts/check-imports.sh (sketch)
# Fail if the domain layer imports any framework/infrastructure package.
if go list -deps ./internal/domain/... | grep -E 'jackc/pgx|go-chi/chi|opentelemetry'; then
  echo "ERROR: internal/domain must not import framework/infrastructure packages"; exit 1
fi
```

This pairs with the architecture governance hook — defence in depth on the dependency rule.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Race always on | `test`/`cover` always use `-race` | A test target without the race detector |
| Single CI entry | `make ci` runs the full gate set | CI re-listing ad-hoc `go` commands |
| Local == CI | Same targets run in both places | Different commands locally vs CI |
| Coverage enforced | Threshold checked and failing build | Coverage measured but not enforced |
| Bench available | `make bench` with `-benchmem` | No benchmark target |
| Arch enforced | `make arch` fails on a dependency-rule violation | Dependency rule unchecked |
| Freshness | `make ci` fails on uncommitted generated/tidy diffs | Drift allowed to merge |

---

## Anti-Patterns

- **A "fast" test target without `-race`** — the moment a race-free shortcut exists, it becomes the default, and races surface only in CI (or production). One test target, detector always on.
- **CI YAML re-listing raw `go` commands** — the pipeline drifting from the Makefile reintroduces "passes locally, fails in CI." CI calls `make ci`, nothing else.
- **Coverage measured but not enforced** — a number printed to a log gates nothing. The threshold check must fail the build.
- **Un-`.PHONY` targets** — a file or directory named `test`/`build` silently turns the target into a no-op.
- **Makefile as a programming language** — hundreds of lines of shell logic inline. Anything beyond a few lines belongs in `scripts/`, called by a thin target.
- **Skipping the freshness check** — letting stale generated code or an untidy `go.mod` merge guarantees the next `make generate` produces a surprise diff.

---

## Output Format

Produces the Makefile and its helper scripts:

```
Makefile
scripts/check-coverage.sh
scripts/check-imports.sh
.golangci.yml            (linter config)
```
