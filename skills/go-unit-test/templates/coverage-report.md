---
name: go-coverage-report
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: statement and branch counts, verdict, and what is unmeasured or awaiting approval]
traces-to: [implement/test-strategy.md, [commit or run id]]
---

# Go Coverage Report for [Service]

<!-- Path: artifacts/<product>/quality/test-reports/go-coverage-[service].md. The product owner approves it.
     Fill from the full gate run (all suites in scope). A unit-only or filtered run gives no verdict.
     Copy counts exactly; never round; never combine the two measures. -->

- **Run:** [commit, date, Go version, gobco version]
- **Commands:** [the two gate commands as run, with flags]

## Results

| Measure | Covered | Total | Exit code | Verdict |
|---|---|---|---|---|
| Statement blocks | [statements] | [statements] | [0/1/2] | [pass / fail / no result] |
| Branches (gobco) | [outcomes] | [outcomes] | [0/1/2] | [pass / fail / no result] |

**Gaps:** [each file, line and condition or block not run, with the behaviour case that will cover it; or "none"]

**No result:** [each package or file without a measurement and the tool's message; or "none". These return to the product owner; nothing is waivable.]

## Not Measured

- `select` statements in the branch figure (their clause bodies are seen only by the statement gate).
- `range` loops and zero-iteration loops, by neither gate.
- Boolean expressions outside `if`/`for` conditions and switch cases (for example `ok := a || b`).
- Functions without conditions, in the branch figure.
- [Anything else this run could not see, for example nested modules]

## Exclusions

| Path | Kind | Reason | Approval |
|---|---|---|---|
| [path or "none"] | [generated / other] | [reason] | [automatic (generated) / pending / approved YYYY-MM-DD] |

## Waivers

| Measure | Counts | Product owner comments | Reviewed on |
|---|---|---|---|
| none | [none] | [none] | [none] |

<!-- Add a row only after the product owner reviewed this run's result above 90% and under 100%. -->

## Limits of This Report

Coverage shows that code ran and, for branches, which outcomes were taken. It does not show that any assertion would catch a fault. Checks confirm only what someone specified.

**For approval:** [the exclusions, waivers and no-result items the product owner is asked to decide]
