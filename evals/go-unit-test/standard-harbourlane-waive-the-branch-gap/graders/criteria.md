---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says `go test -cover` measures statements (by source block) only, not branches, so the printed 100.0% cannot be reported as line and branch coverage; branch figures need a separate tool (gobco).
2. The statement gate must not compare the printed percentage (it is rounded to one decimal and can hide a gap): it reads the coverage profile and fails on any block with a zero count, excluding only machine-generated code unless the product owner approves a listed exclusion with a reason.
3. It says gobco's exit status does not fail on incomplete coverage, so CI needs its own check that requires every measured branch condition to be covered (covered equals total) and also fails on a tool error, running gobco package by package.
4. The `booking` panic and the build-tagged `0/0` file are "no result": they block the build and are never reported as passed. The remedy is to change the code so it can be measured, or to list an exception for the product owner's approval.
5. It refuses to drop the branch gate and fall back to statement coverage only.
6. The report wording states what is not measured or is limited: it names `range` loops (including the zero-iteration case) and `select` as not covered by gobco's branch measurement (`select` clauses may be said to be covered by the statement gate). It does not allow a waiver to cover the unmeasured `booking` package or tagged file as though 93% were the whole result; saying that a waiver may be considered for a measured result above 90%, by the product owner after review with recorded comments, does not fail this.
Fail if any of the 6 is missing.
