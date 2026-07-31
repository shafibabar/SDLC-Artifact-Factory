# Test Strategy Template

> **Self-contained reference.** This file is loadable independently of `skills/test-pyramid/SKILL.md`. It provides the complete fill-in template for a product's test strategy document — produced by the test-strategist at the start of the Implement phase and updated through Quality.
>
> The test-strategy document is the single source of truth for what the product tests, at which layer, with which tooling, and who owns each layer. Every CI gate and every coverage target flows from it.

---

## How to Fill This Template

**Pyramid Targets table** — Agree proportions per layer for this product's suite. The percentages are a directional guide: if e2e tests outnumber unit tests the pyramid is inverted and the suite will be slow and flaky. Use the owning-skill column to name which skill governs authoring at each layer.

**Shift-Left Plan** — One row per service or bounded context. Name which TDD/BDD disciplines apply, which unit-test scope to enforce, which contract boundaries to maintain, and the mutation-testing schedule.

**Shift-Right Plan** — Name the specific full-stack user journeys that must pass E2E, the p99 latency / error-rate targets that gate a performance run, the steady-state load target and SLO threshold, and the chaos experiments required before a production deploy.

**Coverage and Flaky Policy** — State the Branch Coverage percentage gate, where the mutation cadence runs (per-PR or scheduled), the quarantine process for flaky tests, and the retry policy. Assertions must be quotable by CI tooling.

**Delegated Testing** — Confirm which test layers belong to the security-engineer and which to the platform-engineer, with the exact skill each uses. The test-strategist ensures these layers exist and are gated; the delegated engineer authors them.

---

## Template

```markdown
---
name: test-strategy
product: [product name]
version: 1.0.0
phase: implement
created: [YYYY-MM-DD]
owner: test-strategist
---

# Test Strategy — [Product Name]

## Pyramid Targets

| Layer | Target proportion | Tooling | Owning skill | Owner / author |
|---|---|---|---|---|
| Unit | ~70% of total tests | `go test` + `testify`, table-driven + fuzz | `go-unit-test` | backend-engineer / frontend-engineer |
| Contract | small, stable set | `kin-openapi` schema validation; `pact-go` when multi-repo | `go-contract-test` | test-strategist |
| Integration | ~20% of total tests | `testcontainers-go` (Postgres + Redpanda) | `go-integration-test` | backend-engineer |
| E2E | ~10% of total tests | Playwright (headful/headless), `go-e2e-test` harness | `go-e2e-test` | test-strategist |

**Inverted-pyramid alert**: if e2e test count exceeds unit test count at any review, the test-strategist raises it as a defect in the next quality gate.

## Shift-Left Plan

The shift-left half prevents bugs before they ship.

| Service / Bounded Context | TDD/BDD discipline | Unit-test scope | Contract boundary | Mutation schedule |
|---|---|---|---|---|
| [Service A — e.g., FileProcessor] | TDD: test file precedes implementation file. BDD: Gherkin features authored with requirements-analyst before code. | All domain model methods, repository SQL logic, service-layer invariants. Excluded: generated code, `main()`, trivial getters. | OpenAPI schema validated at build via `kin-openapi`. | Gremlins-based, scheduled nightly on changed packages only. |
| [Service B — e.g., ComplianceEngine] | TDD: failing test written for every new rule. BDD: each compliance rule has a Gherkin scenario. | Aggregate invariants (e.g., cannot reclassify below SOC2 tier without audit entry), classification-rule logic. | Event-schema validated (Redpanda topic schemas registered in the schema registry). | Gremlins-based, scheduled nightly. |
| [Add rows for each bounded context] | | | | |

**TDD gate**: the `tdd-gate` pre-commit hook blocks any implementation file whose corresponding `_test.go` file has a modification timestamp later than the implementation file — the test must exist and be committed first.

**BDD gate**: every Must Have acceptance criterion maps to at least one passing Gherkin scenario. The test-strategist verifies this mapping before a story is marked Done.

**Mutation pass threshold**: ≥70% of introduced mutants must be caught. Survivors are triaged: trivial code is annotated to skip, real gaps become new test cases.

## Shift-Right Plan

The shift-right half validates resilience and real-world behaviour.

### E2E Journeys

| Journey ID | Description | Entry condition | Pass criterion |
|---|---|---|---|
| E2E-001 | [e.g., Scan a PDF from S3, extract entities, see the asset in the graph] | Deployed environment; test tenant seeded | Asset appears in graph with ≥1 entity within 30 s of upload trigger |
| E2E-002 | [e.g., Compliance officer classifies an asset and sees audit log] | E2E-001 passed | Audit log entry created; asset status updated within 5 s |
| [Add journeys for each critical user path] | | | |

**Smoke gate**: E2E-001 (the most critical path) runs on every merge to the integration branch. Full E2E suite runs nightly.

### Performance Gates

| Metric | Target | Measurement window | Tooling |
|---|---|---|---|
| p99 API response time | ≤ 200 ms under nominal load | 60 s steady-state run at [N] concurrent users | `go-performance-test` / `k6` |
| p99 file-processing latency | ≤ [X] s per MB | Single-file benchmark run | `go-performance-test` |
| Error rate | < 0.1% under nominal load | Same 60 s window | `go-performance-test` |

A performance gate failure blocks merge. Regressions of >20% from the prior baseline are automatically flagged.

### Load / SLO Verification

| Scenario | Concurrent users / RPS | Duration | SLO threshold | Tooling |
|---|---|---|---|---|
| Nominal load | [N] concurrent users | 10 min | p99 ≤ 200 ms; error rate < 0.5% | `go-load-test` / `k6` |
| Peak load | [2N] concurrent users | 5 min | p99 ≤ 500 ms; error rate < 1% | `go-load-test` / `k6` |

Load tests run nightly; results reported as a trend (rising p99 or error rate over successive runs is an alert).

### Chaos Experiments

| Experiment | Target | Steady-state hypothesis | Tooling |
|---|---|---|---|
| DB connection failure | FileProcessor → Postgres | Processing queue drains; no data loss (Transactional Outbox retries) | `go-chaos-test` / Toxiproxy |
| Broker partition | ComplianceEngine → Redpanda | Dead Letter Queue captures unprocessable events; alert fires within 60 s | `go-chaos-test` / Toxiproxy |
| Downstream API timeout | [Service] → external API | Circuit Breaker opens within [N] failed attempts; fallback response returned | `go-chaos-test` / Toxiproxy |

Chaos experiments run in the staging environment on a scheduled cadence (weekly minimum) and before every major release.

## Coverage and Flaky Policy

### Branch Coverage Gate

- **Target**: ≥ 80% Branch Coverage on all changed packages per CI run.
- **Enforcement**: `make ci` (backend) and `npm run ci` (frontend) fail the build if coverage falls below threshold.
- **Scope exclusions**: generated code (`*.pb.go`, mocked interfaces), `main()` functions, trivial one-liner getters. Exclusions are documented and reviewed quarterly.
- **Not targeted**: Statement Coverage (subsumed by branch; measuring it separately adds no information). Path Coverage is only applied to the highest-risk domain logic (e.g., sensitivity-classification rules with multiple interacting conditions) where branch coverage is demonstrably insufficient.

### Mutation Testing Cadence

- **Tool**: Gremlins (Go-native, frugal, no external service).
- **Cadence**: Scheduled nightly on changed packages (not per-PR — too slow for interactive CI).
- **Threshold**: ≥ 70% of introduced mutants killed. Survivors are triaged and either annotated (trivial code) or converted to new test cases within one sprint.
- **Interpretation**: a survived mutant indicates a **regression-protection gap** specifically — a real bug could be introduced in that location and go undetected. This is distinct from a Branch Coverage shortfall, which indicates untested paths.

### Flaky-Test Quarantine Process

1. **Trigger**: a test fails non-deterministically across two consecutive CI runs with identical inputs.
2. **Quarantine immediately**: move the test to the `TestFlaky_` prefix (skipped in blocking CI, included in a separate nightly flaky-suite run) and file a defect issue.
3. **Root-cause within one sprint**: investigate for timing assumptions, shared mutable state, or test-order dependence. See `test-fixture-design` (hermetic fixtures) and `go-e2e-test` (async polling discipline).
4. **Fix and restore**: once the root cause is resolved, the test is moved back to the blocking suite and the defect closed.
5. **No retry-to-green**: CI retries on flaky tests mask the symptom; they are never accepted as a fix.

**Flaky-count signal**: track flaky-test count as a trend metric. A rising count over three consecutive weeks is raised as a test-quality defect in the retrospective.

### Retry Policy

No test framework retries are configured by default. If a flaky test is quarantined and a retry is added temporarily as a diagnostic tool (to confirm frequency), the retry configuration is removed before the root-cause fix is merged — retries are diagnostics, not remedies.

## Delegated Testing

The following test layers are owned by other agents. The test-strategist ensures each layer exists and is gated but does not author the tests.

| Layer | Owner | Skill | Gate |
|---|---|---|---|
| Security control tests (authentication, ABAC authorization, SQL injection resistance, security header enforcement) | security-engineer | `security-implementation` | Pre-deploy security gate |
| Compliance verification (SOC 2 CC6.x, GDPR data-residency checks) | security-engineer | `compliance-verification` | Pre-deploy compliance gate |
| Vulnerability & dependency scanning (SAST, SCA) | security-engineer / platform-engineer | CI tooling (governed by `ci-pipeline`) | Merge gate — blocks on High/Critical findings |
| Observability health checks (telemetry pipeline, SLO breach alerting) | platform-engineer | `health-check-design`, `slo-definition` | Post-deploy validation |

Any gap in the above layers — a security test layer that does not exist, a compliance check with no CI gate — is reported by the test-strategist as a test-strategy defect, not silently omitted.
```
