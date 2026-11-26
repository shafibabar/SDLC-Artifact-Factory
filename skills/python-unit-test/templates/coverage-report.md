---
name: python-coverage-report
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: line and branch counts, verdict, and what is unmeasured or awaiting approval]
traces-to: [implement/test-strategy.md, [commit or run id]]
---

# Python Coverage Report for [Service]

<!-- Path: artifacts/<product>/quality/test-reports/python-coverage-[service].md. The product owner approves it.
     Fill from the full gate run (all suites in scope). A unit-only or filtered run gives no verdict.
     Copy counts exactly; never round; never combine the two measures. -->

- **Run:** [commit, date, Python, pytest, pytest-cov and coverage versions]
- **Command:** [the gate command as run, with flags]
- **Suites not run:** [each --skip-suite value, or "none"]
- **Tests:** [ran] ran, [skipped] skipped or expected to fail

## Results

| Measure | Covered | Total | Verdict |
|---|---|---|---|
| Lines (statements) | [count] | [count] | [pass / fail / no result] |
| Branches | [count] | [count] | [pass / fail / no result] |

**Exit code:** [0 / 1 / 2]

**Gaps:** [each file, line or branch not taken, with the behaviour case that will cover it; or "none"]

**No result:** [the gate's message; or "none". It blocks the build; nothing is waivable. State the change that will make the run measurable, or the exception listed below as pending.]

## Not Measured

- Files under an approved exception: [each file, or "none"]. They are not part of any pass.
- Alternatives inside one line (`a and b`, `x if c else y`, comprehension filters).
- A loop or comprehension that runs zero times is not required separately.
- A function whose body is only a docstring counts as run even if never called.
- Code run in a child process, and anything outside the source folders.
- Tests a `conftest.py` hides from collection, and skipped tests.
- [Anything else this run could not see]

## Exclusions

| Path | Kind | Reason | Approval |
|---|---|---|---|
| [path or "none"] | [generated / file / lines and fingerprint] | [reason] | [automatic (generated) / pending / approved YYYY-MM-DD] |

## Waivers

| Measure | Counts | Product owner comments | Reviewed on |
|---|---|---|---|
| none | [none] | [none] | [none] |

<!-- Add a row only after the product owner reviewed this run's result above 90% and under 100%. -->

## Limits of This Report

Coverage shows that code ran and which line-to-line branches were taken. It does not show that any assertion would catch a fault. Checks confirm only what someone specified.

**For approval:** [the exclusions (including any behind a "no result") and waivers the product owner is asked to decide]
