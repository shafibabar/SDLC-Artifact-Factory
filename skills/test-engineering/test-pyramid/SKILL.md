---
name: test-pyramid
description: >
  Teaches the test strategy for a product — the Test Pyramid (many fast unit tests,
  fewer integration, fewest e2e), the shift-left vs shift-right split (prevent bugs
  early vs validate real-world resilience), what to test at which layer, coverage
  philosophy, the flaky-test quarantine policy, the every-bug-gets-a-regression-test
  rule, and how security/compliance testing is delegated to the security-engineer.
  This is the organizing knowledge the test-strategist reasons from. Used by the
  test-strategist during Implement and Quality.
version: 1.0.0
phase: implement
owner: test-strategist
tags: [implement, quality, testing, test-pyramid, shift-left, shift-right, strategy, coverage]
---

# Test Pyramid

## Purpose

A test suite is an investment portfolio: every test costs time to write, run, and maintain, and pays back in bugs prevented and confidence gained. The Test Pyramid is how that portfolio is balanced — many cheap, fast tests at the bottom; few expensive, slow tests at the top. Get the shape right and the suite is fast, reliable, and trustworthy. Get it wrong (an "ice-cream cone" of mostly e2e tests) and it is slow, flaky, and ignored.

This skill is the strategy the test-strategist reasons from when deciding what to test, where, and why. It frames everything around two complementary objectives: **shift-left** (catch defects before they ship, cutting rework cost) and **shift-right** (validate resilience and real behaviour in production-like conditions).

---

## The Pyramid

```
                /\
               /E2E\          few   — full user journeys, slow, brittle; smoke the critical paths
              /------\
             /  Integ \       some  — real DB/broker via Testcontainers; sub-system interop
            /----------\
           / Contract   \     some  — service boundaries verified against the shared schema
          /--------------\
         /     Unit       \   many  — fast, isolated, deterministic; the bulk of coverage
        /------------------\
```

| Layer | Proportion | Speed | What it proves | Owner / author |
|---|---|---|---|---|
| Unit | ~70% | ms | A function/Aggregate behaves correctly in isolation | Authored by feature engineers (backend/frontend) using `go-unit-test` |
| Contract | small | fast | Two services agree on the wire shape | test-strategist (`go-contract-test`) |
| Integration | ~20% | seconds | Modules + real DB/broker work together | Authored by backend-engineer using `go-integration-test` |
| E2E | ~10% | minutes | A whole user journey works end to end | test-strategist (`go-e2e-test`) |

The percentages are a guide, not a quota — but if e2e tests outnumber unit tests, the pyramid is upside-down and the suite will be slow and flaky.

---

## Shift-Left vs Shift-Right

The two halves of the strategy serve different goals; a healthy product does both.

### Shift-Left — prevent bugs early (cheapest place to fix)

The earlier a defect is caught, the cheaper it is. Shift-left pushes verification to the start of the lifecycle: tests are written **before** code (TDD), specs are executable (BDD), and the build gates on them.

| Practice | Skill |
|---|---|
| TDD Red-Green-Refactor | (methodology — practised by feature engineers; governed here) |
| Executable specs (Gherkin) | `bdd-feature-file` |
| Unit + boundary + fuzz | `go-unit-test` |
| Typed generated test doubles | `mock-generation` |
| Hermetic fixtures | `test-fixture-design` |
| Integration with real deps | `go-integration-test` |
| Contract verification at build | `go-contract-test` |
| Mutation testing (test the tests) | `go-mutation-test` |

### Shift-Right — validate real-world resilience & behaviour

Some properties only emerge under real load, real failure, and real usage. Shift-right validates the system in production-like conditions.

| Practice | Skill |
|---|---|
| Full-stack user journeys | `go-e2e-test` |
| Performance regression gating | `go-performance-test` |
| Load / SLO verification under stress | `go-load-test` |
| Resilience via fault injection | `go-chaos-test` |
| Test-trace correlation (observe tests in prod telemetry) | folded into `go-e2e-test` |

---

## What to Test at Each Layer

The rule: **test a behaviour at the lowest layer that can prove it.** Pushing a check down the pyramid makes it faster and less brittle.

| Behaviour | Test at | Not at |
|---|---|---|
| An Aggregate invariant (can't downgrade sensitivity) | Unit | E2E |
| A validation rule | Unit | Integration |
| A repository's SQL + optimistic concurrency | Integration | E2E |
| Two services agree on the event schema | Contract | E2E |
| "Compliance officer classifies an asset and sees it update" | E2E (one journey) | — |
| Latency under 1000 concurrent users | Load | Unit |

If a behaviour can be unit-tested, it should be — reserve integration and e2e for what genuinely needs real dependencies or the full stack.

---

## Coverage Philosophy

Coverage is a **signal, not a target**. 100% line coverage with weak assertions proves nothing; 80% with strong behaviour-focused tests and mutation verification proves a lot.

- **Gate**: ≥80% on changed packages (the backend's `make ci` / frontend's `npm run ci` enforce this).
- **Branch over line**: cover decision branches (error paths, edge cases), not just lines executed.
- **Mutation as the real quality check**: `go-mutation-test` verifies the tests actually catch broken code — the antidote to high-coverage-but-useless tests.
- Never chase the last few percent on trivial code (generated code, simple getters) — spend the effort where logic is complex.

---

## Flaky-Test Policy

A flaky test (passes/fails non-deterministically) is worse than no test — it trains the team to ignore red builds. The policy:

1. **A flaky test is a bug**, triaged like any defect.
2. **Quarantine immediately**: move it out of the blocking suite into a tracked quarantine so it stops poisoning CI — but it is *tracked*, never deleted.
3. **Root-cause and fix**: usually a timing assumption, shared state, or test-order dependence (see `test-fixture-design`, `go-e2e-test`).
4. **No retry-to-green as a fix**: retries mask flakiness; they are a diagnostic, not a remedy.

Track flaky history as a lightweight CI signal — a rising flaky count is a quality alarm.

---

## Every Bug Gets a Regression Test

When a production defect is found, **a failing test that reproduces it is written before the fix** — then the fix turns it green. This is TDD applied to bugs: the defect can never silently return, and the suite grows exactly where the system proved weak. Regression tests are not a separate layer; they are unit/integration/e2e tests that happen to pin a known failure.

---

## Security & Compliance Testing (Delegated)

Security and compliance testing are part of the pyramid but **owned by the `security-engineer`**, not duplicated here:

| Layer | Owner | Skill |
|---|---|---|
| Security control tests (auth, ABAC, SQL injection) | security-engineer | `security-implementation` |
| Compliance verification (SOC 2 CC6.x, GDPR) | security-engineer | `compliance-verification` |
| Vulnerability & dependency scanning | security-engineer / platform | (CI gates) |

The test-strategist ensures these layers exist and are gated, but the security-engineer authors them.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Pyramid shape | Many unit, fewer integration, fewest e2e | Inverted (mostly e2e) — slow, flaky |
| Right layer | Behaviours tested at the lowest capable layer | Logic verified only via e2e |
| Shift-left + right | Both halves present and intentional | All shift-left (fragile in prod) or all shift-right (slow feedback) |
| Coverage as signal | Branch coverage + mutation verification | Line-coverage target gamed with weak tests |
| Flaky policy | Flaky tests quarantined + fixed, never ignored | Retries-to-green; muted/deleted tests |
| Regression discipline | Every bug gets a failing test first | Bugs patched with no reproducing test |
| Security delegated | Security/compliance owned by security-engineer | Duplicated security test skills here |

---

## Output Format

Produces the test strategy document for a product:

```markdown
---
artifact: test-strategy
product: [product name]
version: 1.0.0
phase: implement
created: [date]
owner: test-strategist
---

# Test Strategy

## Pyramid Targets
| Layer | Target proportion | Tooling | Owner |
|---|---|---|---|

## Shift-Left Plan
[TDD/BDD, unit/contract/integration/mutation per service]

## Shift-Right Plan
[E2E journeys, performance gates, load/SLO targets, chaos experiments]

## Coverage & Flaky Policy
[Gates, branch focus, quarantine process]

## Delegated Testing
[Security/compliance layers → security-engineer]
```
