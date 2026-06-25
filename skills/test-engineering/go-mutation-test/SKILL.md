---
name: go-mutation-test
description: >
  Teaches mutation testing in Go — verifying the quality of the test suite by
  mutating production code and checking the tests catch it, the mutation-score
  metric, why mutation testing beats coverage as a quality signal, running it
  frugally (periodically, on critical packages, not every PR), interpreting
  survived mutants, and acting on the results. Mutation testing is the antidote to
  high-coverage-but-weak tests. Used by the test-strategist during Quality.
version: 1.0.0
phase: quality
owner: test-strategist
tags: [quality, go, mutation-testing, test-quality, mutation-score, gremlins]
---

# Go Mutation Test

## Purpose

Code coverage tells you which lines ran during tests — not whether the tests would *catch a bug* in those lines. A test that executes a line but asserts nothing meaningful gives 100% coverage and zero protection. Mutation testing closes that gap: it deliberately introduces small bugs ("mutants") into the production code and checks whether the test suite fails. If the tests still pass with broken code, the tests are weak — exactly where coverage lied.

Mutation testing is the real measure of test effectiveness. It is run by the test-strategist as a periodic quality gate, not on every commit (it is computationally expensive — see the frugality note).

---

## How It Works

A mutation tool makes one tiny change to the code, runs the tests, and records the outcome:

| Mutation example | Original | Mutant |
|---|---|---|
| Flip a comparison | `if a > b` | `if a >= b` |
| Negate a condition | `if valid` | `if !valid` |
| Change a boundary | `i < len(x)` | `i <= len(x)` |
| Swap an operator | `a + b` | `a - b` |
| Remove a statement | `x.Save()` | *(removed)* |

| Outcome | Meaning |
|---|---|
| **Killed** | A test failed → the suite caught the bug. Good. |
| **Survived** | All tests still passed → the suite missed the bug. A gap. |

**Mutation score = killed / total mutants.** A survived mutant is a concrete, actionable "write a test that catches this."

---

## Why It Beats Coverage

```
Coverage says:  "line 42 executed during the tests."
Mutation says:  "we broke line 42 and your tests didn't notice."
```

Coverage is necessary but not sufficient — it's gameable with assertion-free tests. Mutation score is hard to game: the only way to kill a mutant is to have a test that actually asserts the behaviour the mutant breaks. This is why the `test-pyramid` skill treats mutation testing as the true quality check behind the coverage gate.

---

## Tooling (Go)

| Tool | Notes |
|---|---|
| **Gremlins** (`go-gremlins/gremlins`) | Actively maintained, Go-native mutation tester — **default** |
| `go-mutesting` | Older alternative |

```bash
gremlins unleash ./internal/domain/...    # mutate the domain package, run tests per mutant
```

```toml
# .gremlins.yaml — keep runs scoped and bounded
unleash:
  tags: ""
  threshold:
    efficacy: 80     # fail if mutation score (killed/total) < 80% on targeted packages
```

---

## Frugal Execution — Periodic, Targeted

Mutation testing runs the whole suite once per mutant, so it is slow and costly. Running it on every PR would wreck the CI feedback loop. The frugal policy:

1. **Targeted** — run on the **critical packages** where correctness matters most: the domain (`internal/domain`), the application command handlers, security-adjacent logic. Not generated code, not transport glue.
2. **Periodic** — on a schedule (nightly or weekly) and before a release, **not** on every PR.
3. **Bounded** — set an efficacy threshold (e.g., 80%) on the targeted packages; a drop fails the scheduled job and is triaged.

This gets the signal where it counts without taxing the inner loop — measure-where-it-matters, like the performance discipline.

---

## Acting on Survived Mutants

A survived mutant is a to-do, triaged:

1. **Read the mutant** — what change went undetected? (e.g., `>` → `>=` survived in the sensitivity-rank comparison.)
2. **Decide:** is it a real test gap, or an *equivalent mutant* (a change that doesn't alter observable behaviour — a known false positive)?
3. **Real gap** → write the missing test (often a boundary case — ties straight back to `go-unit-test`'s boundary analysis). The new test kills the mutant.
4. **Equivalent mutant** → annotate/exclude it with a comment so it doesn't recur as noise.

Survived mutants in the **domain layer** are the highest priority — that's where a real bug is most expensive.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Quality measured | Mutation score tracked on critical packages | Relying on line coverage alone |
| Targeted | Runs on domain/application/security logic | Mutating generated/trivial code |
| Periodic, not per-PR | Scheduled + pre-release runs | Mutation on every PR, wrecking CI speed |
| Threshold gated | Efficacy threshold enforced on the scheduled run | Score computed but never acted on |
| Survivors actioned | Real survivors → new boundary tests | Survived mutants ignored |
| Equivalents handled | Known equivalents annotated/excluded | Equivalent-mutant noise re-triaged forever |

---

## Output Format

Produces the mutation-testing configuration, the scheduled job, and the tests written to kill survivors:

```
.gremlins.yaml                          (scope + efficacy threshold)
.github/workflows/mutation.yml           (scheduled run on critical packages)
internal/**/*_test.go                    (new boundary tests that kill survived mutants)
docs/quality/mutation-report.md          (score trend + triaged survivors)
```
