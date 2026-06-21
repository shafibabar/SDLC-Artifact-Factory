# Skill: quality/test-plan

## Purpose
Produce the Master Test Plan — the umbrella document that governs all testing for the product. Defines the test strategy, test layers, coverage targets, tooling, environments, and Definition of Done for the Quality phase. All other quality skills produce artifacts that trace back to this plan.

## Inputs
- `artifacts/design/bounded-contexts.md`
- `artifacts/ideate/requirements/nfrs.md`
- `artifacts/implement/standards/coding-standards.md`
- `sdlc-config.json` (compliance_frameworks, deployment targets)

## Output
**File:** `artifacts/quality/test-plan.md`
**Registers in manifest:** yes

## Test Plan Rules (enforced)
- Test Pyramid is explicit: unit (base) → integration → contract → component → E2E (apex).
- Coverage targets are numeric — not "comprehensive" or "adequate".
- Tooling is fully specified — versions matter.
- Every test type has a stated execution environment and trigger.
- Performance and security are first-class test types, not afterthoughts.

## Artifact Template

```markdown
# Master Test Plan

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Master Test Plan
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Test Strategy

### Guiding Principles

1. **Shift Left:** Defects are cheapest at the unit layer. TDD enforces this — tests are written before implementation.
2. **Test Pyramid:** We maintain the canonical pyramid shape. If integration or E2E tests outnumber unit tests, the suite is inverted and must be corrected.
3. **Real Infrastructure at Boundaries:** Integration tests use real PostgreSQL (via testcontainers-go), real Redpanda, and real Elasticsearch. No mocks at system boundaries.
4. **Consumer-Driven Contracts:** Contracts are defined by consumers. Producers run consumer tests in their own CI. A schema break blocks the merge.
5. **Compliance as Tests:** Compliance controls are tested programmatically — not asserted in documents.
6. **Security by Default:** Every PR runs SAST, secret scanning, and vulnerability checks. Security test plans run on a schedule.

---

## Test Layers

| Layer | Tool | Scope | Runs in | Trigger |
|-------|------|-------|---------|---------|
| Unit | `go test` + `testify` | Single package, no I/O | CI (fast path) | Every commit |
| Integration | `go test` + `testcontainers-go` | Real DB / broker / ES | CI (separate job) | Every commit |
| Contract | `gojsonschema` + consumer definitions | Event schemas, API schemas | CI (each consumer and provider repo) | Every commit |
| Component | `go test` + `testcontainers-go` | Full service, real deps, no external services | CI | Every commit on domain repos |
| E2E | `godog` + live environment | Full user journey across all services | Staging | Pre-deploy gate |
| Performance | `k6` | p99 latency, throughput | Staging | Weekly + pre-release |
| Load | `k6` | Sustained load, ramp-up | Staging | Pre-release |
| Security | `gosec`, `trivy`, `OWASP ZAP` | SAST, dependencies, DAST | CI + weekly | CI on every commit (SAST); weekly (DAST) |
| Chaos | `chaos-mesh` | Failure injection | Staging | Pre-release |
| Compliance | Custom + `open-policy-agent` | Policy-as-code assertions | CI | Every commit |

---

## Coverage Targets

| Package type | Minimum coverage | Tool |
|-------------|-----------------|------|
| `internal/domain/aggregates` | 90% | `go test -cover` |
| `internal/application/commands` | 80% | `go test -cover` |
| `internal/application/queries` | 70% | `go test -cover` |
| `internal/api/handlers` | 75% | `go test -cover` |
| `internal/infrastructure` | 60% | `go test -cover` |
| BDD feature files covered by godog steps | 100% | godog report |
| Event schemas with contract tests | 100% of domain events | manual audit |
| API endpoints with contract tests | 100% of public endpoints | manual audit |

Coverage below target **blocks merge** (enforced by CI gate).

---

## Tooling Stack

| Tool | Version | Purpose |
|------|---------|---------|
| `go test` | Go 1.23+ | Unit and integration test runner |
| `testify` | v1.9 | Assertions and mocking (test doubles only — never at integration boundaries) |
| `testcontainers-go` | v0.35 | Real PostgreSQL, Redpanda, Elasticsearch in CI |
| `godog` | v0.14 | BDD / Gherkin step execution |
| `gojsonschema` | v1.2 | JSON Schema validation for contract tests |
| `k6` | v0.55 | Performance and load testing |
| `golangci-lint` | v1.60 | Static analysis (CI gate) |
| `gosec` | v2.x | Go security static analysis (CI gate) |
| `govulncheck` | latest | Go vulnerability database check (CI gate) |
| `trivy` | v0.55 | Container image and dependency vulnerability scanning |
| `gitleaks` | v8.x | Secret scanning (CI hard gate — blocks merge) |
| `OWASP ZAP` | v2.15 | DAST (dynamic analysis against staging environment) |
| `chaos-mesh` | v2.x | Chaos engineering (Kubernetes fault injection) |
| `opa` (Open Policy Agent) | v0.65 | Compliance policy testing |

---

## Test Environments

| Environment | Purpose | Infrastructure | Data |
|-------------|---------|---------------|------|
| Local (developer) | Fast unit + integration cycle | Docker Compose (kind optional) | Synthetic generated data |
| CI | Automated gate — all layers except E2E | GitHub Actions runners + testcontainers | Ephemeral; created and destroyed per test run |
| Staging | E2E, performance, chaos, DAST | k3s cluster (dedicated per tenant model) | Synthetic data matching production shape |
| Production | Not used for testing | — | — |

---

## Definition of Done — Quality Phase

- [ ] Master test plan (this document) approved
- [ ] Unit test specs written for all modules (all bounded contexts)
- [ ] Integration test specs written for all domain boundaries
- [ ] Contract test specs written for all inter-service integrations
- [ ] E2E test specs written for all critical user journeys
- [ ] Performance test plan with acceptance thresholds approved
- [ ] Load test plan with acceptance thresholds approved
- [ ] Security test plan addressing OWASP Top 10 approved
- [ ] Chaos test plan covering at least 3 failure scenarios approved
- [ ] Compliance test specs for all configured frameworks approved
- [ ] All test specs reviewed and traced back to this master plan

---

## Traceability Matrix

Every test spec links to:
- The user story or acceptance criterion it verifies
- The test layer it belongs to (unit / integration / contract / E2E / etc.)
- The DoD item from the phase DoD it satisfies

The manifest tracks this linkage per artifact.
```

## Quality Checks
- [ ] Test Pyramid is explicit — not just listed, but enforced via coverage targets
- [ ] Every test layer has a runner tool, environment, and trigger specified
- [ ] Coverage targets are numeric per package type (not "high" or "comprehensive")
- [ ] All CI gates are named (blocks merge vs. warning)
- [ ] Environments are specified with real infrastructure details
- [ ] Tooling versions are specified
- [ ] DoD is a checklist — matches the phase DoD from CLAUDE.md
