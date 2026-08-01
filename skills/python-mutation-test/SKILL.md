---
name: python-mutation-test
description: >
  Teaches the backend-engineer to run mutation testing on Python code with
  mutmut (or cosmic-ray) — mutating source and asserting the test suite kills
  the mutants, the mutation-score threshold as a PERIODIC gate (not per-PR,
  frugal), interpreting survivors to find weak tests, and scoping to the
  domain/service layer. The Python analog of go-mutation-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, mutation-testing, test-quality, mutation-score, mutmut, cosmic-ray, survived-mutant, coverage, pytest]
produces: mutation-report
domain: testing
status: stable
related: [go-mutation-test, python-unit-test, test-pyramid]
tools: [Bash]
---

# Python Mutation Test

## Purpose

Coverage tells you which lines *ran* during tests — never whether a test would *catch a bug* in those lines. A `pytest` test that executes a line but asserts nothing meaningful gives 100% `--cov` and zero protection. Mutation testing closes that gap: it deliberately introduces small, syntactically-valid bugs ("mutants") into the production source and reruns the suite. If the suite still passes against broken code, the tests are weak — exactly where coverage lied. This is the Python analog of `go-mutation-test`; the backend-engineer runs it as a **periodic** Quality-phase gate on the `domain`/`service_layer` packages where correctness matters most, never on every PR (see Budget below).

---

## How It Works

| Mutation example | Original | Mutant |
|---|---|---|
| Flip a comparison | `if a > b` | `if a >= b` |
| Negate a condition | `if valid` | `if not valid` |
| Change a boundary | `i < len(x)` | `i <= len(x)` |
| Swap an operator | `a + b` | `a - b` |
| Mutate a constant | `retries = 3` | `retries = 4` |

| Outcome | Meaning |
|---|---|
| **Killed** | A test failed → the suite caught the bug. |
| **Survived** | Every test still passed → the suite missed the bug. A gap. |
| **Equivalent** | No input exists for which mutant and original produce different observable output → not a real gap, see Triage. |

**Mutation score = killed / (total − equivalent).** A survived (non-equivalent) mutant is a concrete, actionable "write a test that catches this." Named precisely against `python-unit-test`'s four pillars (Khorikov), a survived mutant is a **Protection Against Regressions** gap: the suite covers the line but does not verify its behaviour precisely enough to notice when it breaks. It says nothing about the other three pillars — a fast, refactor-resistant, maintainable suite can still leak survivors, which is exactly why mutation testing is a distinct signal layered on top of `python-unit-test`, not a replacement for it.

---

## Tool Choice — mutmut, with cosmic-ray as the Alternative

**mutmut** is this repo's default Python mutation tool — open-source, pytest-native, and configured in `pyproject.toml`, satisfying the frugality constraint without evaluating a paid alternative. **cosmic-ray** is the sanctioned alternative for one specific reason: it distributes work across processes/machines and ships a metrics command that gates a build on the survival rate directly — which matters because of an honest divergence from Go below. Exact `[tool.mutmut]` config, run commands, the score computation, and the cosmic-ray equivalent: `references/mutmut-setup-and-score.md`.

**The honest divergence from `go-mutation-test`:** Gremlins bakes the pass/fail gate into `.gremlins.yaml` (`threshold-efficacy: 60`) and fails the run natively. mutmut has **no native score threshold** — `mutmut run` reports killed/survived/timeout/suspicious counts, and CI must *compute the score from those counts and gate on it in a wrapper step*. cosmic-ray's metrics command is the closest native gate in the Python ecosystem. This is a real ergonomic gap, not a paraphrase of the Go tool; the reference documents the exact wrapper.

---

## Mutation-Score Threshold — Distinguished from Coverage

**60%**, enforced on the targeted `domain`/`service_layer` packages only — deliberately lower than, and measuring a different axis than, `python-makefile`'s line-coverage gate. Coverage answers "did this line execute"; mutation score answers "did a test notice when this line's behaviour changed." A package can sit at 100% line coverage (every statement ran) and far below 60% mutation score (nothing asserted the value) — expected, not a contradiction. The threshold is set below coverage's because a meaningful fraction of generated mutants in any nontrivial function are **equivalent** — different syntax, identical behaviour for every reachable input — and chasing 100% means hunting unkillable mutants instead of writing tests that catch real bugs. 60% is a floor proven achievable by disciplined parametrized testing (`python-unit-test`), raisable per product for compliance-critical logic. Worked 100%-coverage-with-survivor proof: `references/interpreting-survivors.md`.

---

## Targeting — Domain and Service Layer Only

Mutation is expensive (see Budget), so it is spent where a survived mutant is actually informative:

| Path | Mutated? | Why |
|---|---|---|
| `src/<pkg>/domain/` | **Yes** | Value objects and Aggregates — the business rules a weak assertion most endangers. |
| `src/<pkg>/service_layer/` | **Yes** | Command/query handlers orchestrating domain logic — thin enough that mutation signal stays legible. |
| `src/<pkg>/adapters/` | **No** | `asyncpg`/`aiokafka` adapters are Humble Object (`python-repository-pattern`); their correctness is verified by `python-integration-test` against a real dependency, not by mutating plumbing. |
| `src/<pkg>/entrypoints/` | **No** | FastAPI handlers deserialize-and-delegate with no decision logic of their own — same reasoning as adapters. |

Mutating adapters or entrypoints tests wiring, not logic, and buries the domain-layer survivors that matter under plumbing noise. Scope is set with mutmut's `paths_to_mutate` key — the exact form is in `references/mutmut-setup-and-score.md`. Which specific modules to include as the domain grows: `references/interpreting-survivors.md`.

---

## Budget and Scheduling — Periodic, Never Per-PR

Mutation testing reruns the **entire targeted test suite once per surviving-candidate mutant** — a domain package with 40 mutants and a 3-second suite costs roughly two minutes per full pass; multiplied across every PR in a day, this would drown the fast-feedback inner loop `python-makefile` protects. Python compounds this: mutmut re-imports the interpreter per run and parallelizes less cleanly than Gremlins' workers, so wall-clock is typically *worse* than the Go sibling for the same mutant count (cosmic-ray's distributed mode is the mitigation). The frugal default: a **nightly-or-weekly** scheduled CI job plus a mandatory run before every tagged release, never on `pull_request`. The override key and full workflow YAML: `references/mutmut-setup-and-score.md`.

---

## Survived-Mutant Triage Workflow

1. **Read the exact mutant** the tool reports — `mutmut show <id>` prints the file, line, and the original-vs-mutant diff.
2. **Find the covering test(s)** — `--cov` shows they executed the line; the report shows they did not fail.
3. **Ask: does an input exist where the original and the mutant produce different observable output?**
   - **Yes → real gap.** Add the missing `@pytest.mark.parametrize` row — usually a boundary case the table is missing. Rerun to confirm the kill.
   - **No → equivalent mutant.** Annotate the source line with a `# pragma: no mutate` comment naming *why*, not a silent exclude, so it does not resurface as noise.
4. **Prioritize domain-layer survivors first** — that is where an undetected bug is most expensive.
5. **Record the outcome** in `docs/quality/mutation-report.md` — score trend, survivors triaged, equivalents annotated this run.

Two fully worked dispositions — a real gap traced to a missing boundary, and a genuine equivalent mutant with its `# pragma: no mutate` annotation — plus the complete 100%-coverage-with-survivor example: `references/interpreting-survivors.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Tool configured, not ad hoc | `[tool.mutmut]` scoped and committed in `pyproject.toml` | CLI flags with no committed config |
| Targeting correct | `domain`/`service_layer` only; adapters/entrypoints excluded | Mutating Humble Object code, burying real survivors |
| Score gated, not just measured | CI computes the score and fails below 60% (mutmut wrapper or cosmic-ray metrics) | Counts printed, nothing gates |
| Distinguished from coverage | 60% mutation score stated as a different axis from the coverage gate | Mutation score conflated with or substituted for coverage |
| Periodic, not per-PR | Nightly/weekly + pre-release; never on `pull_request` | Mutation on every PR, wrecking CI speed |
| Survivors triaged | Every survivor gets a step-3 disposition (real gap or equivalent) | Report generated, nobody converts it into tests |
| Equivalents annotated | `# pragma: no mutate` with a named reason; never re-chased | Same equivalent re-investigated every run |

---

## Anti-Patterns

- **Mutation on every PR** — each mutant costs a full suite run; the inner loop dies for a signal that changes slowly. Nightly/weekly and pre-release is the policy.
- **Chasing 100% mutation score** — the last mutants are usually equivalents; 60% is a floor proven by disciplined testing, not a purity contest.
- **Conflating mutation score with coverage** — they gate different axes, at different cadences; treating one as a substitute for the other defeats running both.
- **Measuring without gating** — mutmut prints counts and stops; a score nobody fails the build on is theater. Wrap it (or use cosmic-ray's metrics command).
- **Mutating adapters, entrypoints, or generated code** — no logic worth mutating; the noise buries the domain-layer survivors that matter.
- **Treating survivors as a metric, not a work item** — a survived mutant is a specific missing assertion; a report nobody converts into a parametrize row is theater.
- **Silent exclusion with no comment** — an unexplained `# pragma: no mutate` is indistinguishable from an unmaintained one; every equivalent-mutant exclusion states why.

---

## Output Format

- **`pyproject.toml` `[tool.mutmut]`** — committed tool configuration: `paths_to_mutate` scoped to `domain`/`service_layer`, the pytest `runner`, and the `tests_dir`. Never edited ad hoc via CLI flags that bypass the committed scope. Exact shape: `references/mutmut-setup-and-score.md`.
- **`.github/workflows/mutation.yml`** — the scheduled CI job: nightly/weekly cron plus a `release`-triggered run, computing the score and failing below 60%, posting the survivor list as a build artifact. Never triggered on `pull_request`. Exact shape: `references/mutmut-setup-and-score.md`.
- **`tests/unit/**/test_*.py`** — new boundary `@pytest.mark.parametrize` rows written specifically to kill a triaged real-gap survivor, added to the existing table (`python-unit-test`'s shape), never a new ad hoc test bolted on beside it.
- **`docs/quality/mutation-report.md`** — one entry per scheduled run: date, score, killed/survived/equivalent counts, each survivor's triage disposition, and the score trend versus the previous run.
