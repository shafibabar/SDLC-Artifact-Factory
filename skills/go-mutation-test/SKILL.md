---
name: go-mutation-test
description: >
  This plugin's mutation-testing standard for Go — the antidote to
  high-coverage-but-weak-assertion tests that neither go-unit-test's
  coverage-by-quadrant guidance nor go-makefile's 80%-line-coverage gate can
  detect on their own. Covers: the Gremlins tool configuration in exact form
  — .gremlins.yaml, CLI invocation, frugal open-source tool choice
  (references/tool-configuration-and-targeting.md); the package-glob
  targeting convention — which packages get mutated (internal/domain,
  internal/application) and which are excluded (internal/infrastructure,
  internal/handlers, generated code) and why, tied to go-unit-test's
  complexity-quadrant heuristic and Humble Object; the mutation-score
  threshold, set deliberately lower than and distinguished precisely from
  go-makefile's line-coverage threshold, with the equivalent-mutant reasoning
  behind the gap; the periodic budget/scheduling standard (monthly CI plus
  pre-release, tightenable per sdlc-config-management, never on every PR) and
  the cost-model reasoning that forces that choice; the survived-mutant
  triage workflow step by step, including how to recognize and annotate a
  behaviorally-equivalent mutant instead of chasing it; and a worked example
  of 100% line coverage with a survived mutant, proving coverage alone is
  insufficient (references/survived-mutant-triage-and-coverage-
  relationship.md). Authored and run by the test-strategist as a periodic
  Quality-phase gate.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, mutation-testing, test-quality, mutation-score, gremlins, survived-mutant, coverage]
related: [go-unit-test, go-makefile, test-pyramid, sdlc-config-management]
---

# Go Mutation Test

## Purpose

Code coverage tells you which lines *ran* during tests — never whether a test would *catch a bug* in those lines. A test that executes a line but asserts nothing meaningful gives 100% coverage and zero protection. Mutation testing closes that gap: it deliberately introduces small, syntactically-valid bugs ("mutants") into the production code and reruns the test suite. If the suite still passes against broken code, the tests are weak — exactly where coverage lied. This is run by the test-strategist as a periodic Quality-phase gate on the domain/application packages where correctness matters most, never on every PR (see Budget below).

---

## How It Works

| Mutation example | Original | Mutant |
|---|---|---|
| Flip a comparison | `if a > b` | `if a >= b` |
| Negate a condition | `if valid` | `if !valid` |
| Change a boundary | `i < len(x)` | `i <= len(x)` |
| Swap an operator | `a + b` | `a - b` |
| Remove a statement | `x.Save()` | *(removed)* |

| Outcome | Meaning |
|---|---|
| **Killed** | A test failed → the suite caught the bug. |
| **Survived** | Every test still passed → the suite missed the bug. A gap. |
| **Equivalent** | No input exists for which mutant and original produce different observable output → not a real gap, see Triage. |

**Mutation score = killed / (total − equivalent).** A survived (non-equivalent) mutant is a concrete, actionable "write a test that catches this."

Named precisely (Khorikov's four pillars — `go-unit-test`'s "Decoupled from Implementation"), a survived mutant is specifically a **Protection Against Regressions** gap: the suite covers the line but doesn't verify behaviour precisely enough to notice when that behaviour breaks. It says nothing about the other three pillars — a suite can be excellent on resistance-to-refactoring, speed, and maintainability and still leak survivors, which is exactly why mutation testing is a distinct signal layered on top of, not a replacement for, `go-unit-test`'s standards.

---

## Tool Configuration and Targeting

**Gremlins** (`go-gremlins/gremlins`) is this repo's mutation tool — actively maintained, Go-native, and open-source, satisfying the frugality constraint without evaluating a paid alternative. It is configured via `.gremlins.yaml` and invoked per targeted package. **Only `internal/domain/...` and `internal/application/...` are mutated** — the same quadrant-1 packages `go-unit-test`'s complexity heuristic already identifies as carrying real logic. `internal/infrastructure/...` (repositories, adapters — Humble Object per `go-repository-pattern`) and `internal/handlers/...` (thin chi handlers, Humble Object per `go-chi-handler`) are excluded: mutating them tests plumbing that `go-integration-test` already verifies against the real dependency, not logic, and would bury the domain-layer survivors that matter under wiring noise. Generated files (`_gen.go`, `.pb.go`, `_mock.go`) are excluded by the identical filename-pattern convention `go-makefile`'s coverage filter already uses — the same mechanical rule applied to a second tool, not a second policy to maintain. Exact `.gremlins.yaml`, CLI invocation, the full package-glob table, and how a newly-created domain package joins the target list: `references/tool-configuration-and-targeting.md`.

---

## Mutation-Score Threshold — Distinguished from Line Coverage

**60%**, enforced on the targeted domain/application packages only — deliberately lower than, and measuring a different axis than, `go-makefile`'s **80%** line-coverage gate. Line coverage answers "did this line execute"; mutation score answers "did a test notice when this line's behaviour changed" — a package can sit at 100% line coverage (every statement ran) and far below 60% mutation score (nothing asserted the value), which is expected, not a contradiction between the two gates (see the worked example in `references/survived-mutant-triage-and-coverage-relationship.md`). The threshold is set below line coverage's because a meaningful fraction of generated mutants in any nontrivial function are **equivalent** — different syntax producing identical behaviour for every reachable input — and chasing 100% means hunting unkillable mutants instead of writing tests that catch real bugs. 60% is a floor proven achievable by disciplined table-driven testing (`go-unit-test`), not a ceiling to stop at; a product handling compliance-critical logic may raise it per `sdlc-config-management`'s override pattern, the same mechanism that tightens the scheduling cadence below.

---

## Budget and Scheduling — Periodic, Never Per-PR

Mutation testing reruns the **entire targeted test suite once per surviving-candidate mutant** — a domain package with 40 generated mutants and a 3-second test run costs roughly two minutes per full pass; multiplied across every PR in a day, this would drown the fast-feedback inner loop `go-makefile`'s `make ci` protects. The frugal default: a **monthly** scheduled CI job plus a mandatory run before every tagged release, never on every PR. `sdlc-config-management` documents `mutation_test_cadence` as the override key — e.g. `"weekly"` for a bounded context with a compliance-critical rule engine, where the frugality trade-off is deliberately tightened for that context alone, not repo-wide. Full workflow YAML and the exact cost-model arithmetic: `references/tool-configuration-and-targeting.md`.

---

## Survived-Mutant Triage Workflow

1. **Read the exact diff** Gremlins reports — file, line, original operator, mutant operator.
2. **Find the covering test(s)** — coverage shows they executed the line; the report shows they didn't fail.
3. **Ask: does an input exist where the original and the mutant produce different observable output?**
   - **Yes → real gap.** Write the missing assertion — usually a boundary case the table is missing a row for. Rerun Gremlins to confirm the kill.
   - **No → equivalent mutant.** Annotate it explicitly (a `//gremlins:disable-next-line` comment naming why, not a silent exclude) so it doesn't resurface as noise on the next run.
4. **Prioritize domain-layer survivors first** — that's where an undetected bug is most expensive.
5. **Record the outcome** in the mutation report (`docs/quality/mutation-report.md`) — score trend, survivors triaged, equivalents annotated this run.

Two fully worked triage examples — a real gap traced to a missing boundary row, and a genuine equivalent mutant — plus the complete 100%-coverage-with-survived-mutant example: `references/survived-mutant-triage-and-coverage-relationship.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Tool configured correctly | `.gremlins.yaml` scoped to targeted packages, checked in | Ad hoc CLI flags, no committed config |
| Targeting correct | Domain/application only; infrastructure/handlers/generated excluded | Mutating Humble Object or generated code, burying real survivors |
| Threshold distinguished from coverage | 60% mutation score gate, stated as a different axis from the 80% line-coverage gate | Mutation score conflated with or substituted for line coverage |
| Threshold enforced, not just measured | Scheduled job fails below 60% on targeted packages | Score computed and logged but never gates anything |
| Periodic, not per-PR | Monthly + pre-release; `mutation_test_cadence` override documented for tightened contexts | Mutation on every PR, wrecking CI speed |
| Coverage vs. mutation understood | Both gates run, at different cadences, for different questions | Assuming 80% line coverage implies adequate mutation score |
| Survivors triaged, not just reported | Every survivor gets a step-3 disposition (real gap or equivalent) | Report generated, nobody converts it into tests or annotations |
| Equivalents annotated, not chased | Named, commented exclusion; never re-triaged from scratch | Same equivalent re-investigated every run |
| Domain-layer priority | Domain-package survivors triaged before application-layer ones | Survivors worked in file-listing order regardless of layer |

---

## Anti-Patterns

- **Mutation on every PR** — each mutant costs a full test run; the inner loop dies for a signal that changes slowly. Monthly and pre-release is the policy.
- **Chasing 100% mutation score** — the last mutants are usually equivalents; 60% is a floor proven by disciplined testing, not a purity contest.
- **Conflating mutation score with line coverage** — they gate different axes, at different cadences, via different mechanisms (`make cover` vs. the scheduled mutation job); treating one as a substitute for the other defeats the point of running both.
- **Mutating generated, transport, or Humble Object code** — infrastructure/handlers have no logic worth mutating; the noise buries the domain-layer survivors that matter.
- **Treating survivors as a metric, not a work item** — a survived mutant is a specific missing assertion; a report nobody converts into tests is theater.
- **Padding coverage to "prepare" for mutation testing** — assertion-free tests raise line coverage and kill nothing; this is precisely the gap mutation testing exists to expose.
- **Re-triaging known equivalent mutants every run** — annotate once with a named comment, or the report's signal-to-noise decays until it's ignored.
- **Silent exclusion with no comment** — an unexplained exclude list is indistinguishable from an unmaintained one; every equivalent-mutant exclusion states why.

---

## Output Format

- **`.gremlins.yaml`** — the committed tool configuration: package scope (`internal/domain/...`, `internal/application/...`), the 60% `threshold-efficacy`, and any named, commented mutant exclusions. Never edited ad hoc via CLI flags that bypass the committed scope. Exact shape: `references/tool-configuration-and-targeting.md`.
- **`.github/workflows/mutation.yml`** — the scheduled CI job: monthly cron plus a `release`-triggered run, posting the score and survivor list as a build artifact. Never triggered on `pull_request`. Exact shape: `references/tool-configuration-and-targeting.md`.
- **`internal/domain/**/*_test.go`, `internal/application/**/*_test.go`** — new boundary/assertion tests written specifically to kill a triaged real-gap survivor, added to the existing table (`go-unit-test`'s struct shape), never a new ad hoc test function bolted on beside it.
- **`docs/quality/mutation-report.md`** — one entry per scheduled run: date, score, killed/survived/equivalent counts, each survivor's triage disposition (real gap → test added, or equivalent → annotated), and the score trend versus the previous run. A run with no entry did not happen as far as the factory's audit trail is concerned.
