---
name: go-mutation-test
description: >
  Use when test-strategist or anyone sets up, runs, reviews or fixes mutation
  testing for Go code in the Quality phase: Gremlins (gremlins unleash,
  .gremlins.yaml, pinned version), killed, lived, not covered, timed out and
  not viable mutants, surviving or equivalent mutants and triage, the mutant
  record, the D048 rule (every mutant killed or recorded, no percentage
  target), waivers above 90%, the release run that blocks publication, the
  scheduled run on changed code (--diff), cadence, scope and exclusions,
  make mutation, the mutation workflow, the mutation report; or "100% coverage,
  are we done", "is 60% mutation score enough", "run mutation on every pull
  request", "Gremlins says 100% efficacy". Produces mutation-report.
version: 3.0.1
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, mutation-testing, gremlins, mutant-record, equivalent-mutant, survived-mutant, timed-out, waiver, release-gate, coverage]
produces: mutation-report
domain: testing
status: stable
related: [test-pyramid, go-unit-test, go-makefile, ci-pipeline, cd-pipeline, go-e2e-test, sdlc-config-management, python-mutation-test, mock-generation, glossary-management]
sources:
  - research/testing/gremlins-official-docs.md
  - research/testing/go-coverage-official-docs.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/github-actions-official-docs.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/testing/testing-vv-dictionary-quigley.md
---

# Go Mutation Test

## Purpose

This skill owns how a Go product proves its tests would notice a fault: Gremlins plants small operator changes (mutants) and reruns the tests; a mutant the tests do not notice is a regression-protection gap (Khorikov), which coverage cannot show. `test-strategist` authors and runs it; `test-pyramid` owns the cross-stack rule, `go-unit-test` the coverage gates, `go-makefile` the Makefile, `ci-pipeline` and `cd-pipeline` the pipelines. It also owns the mutation triage method for every language (`python-mutation-test` applies it by name). Gremlins' facts come from its v0.6.0 source and from runs made for this skill.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| M1 | **Every planted mutant is killed by a test, or recorded individually with the reason it cannot be** (the change does not alter behaviour). No percentage target: 60% is rejected, and so is any other | D048 B |
| M2 | **Result = (killed + individually recorded) / all planted**, from counts. Gremlins' efficacy and mutant coverage are never the verdict; its thresholds stay 0 | D048: tool scores are not used. Seen: efficacy 91.30% at 19/24 |
| M3 | **Timed-out and compiler-rejected mutants count only once each is checked and recorded** with a one-line reason; never automatically | D048. Gremlins calls a non-compiling mutant KILLED; the runner rechecks every KILLED and TIMED OUT one |
| M4 | **100% passes. More than 90% may be waived only after the product owner reviews every uncaught mutant and records comments; 90% or below, no waiver.** A waiver covers one result | D048 waivers |
| M5 | **NOT COVERED is never recorded**: a test of its own package, or an approved exclusion | Nothing was tested |
| M6 | **All product code, at every size.** A package left out is an exclusion listed with a reason for the product owner's approval. Generated code and `internal/test/` test support are left out as for coverage, and listed | 2026-11-28; D048 A; 2026-11-27 |
| M7 | **The full run before each release blocks and finishes before publication**: the publishing job `needs` it. Never `release: published` | 2026-11-28; that event fires after publication |
| M8 | **Scheduled runs between releases report only**, may cover changed code only (`--diff` against the last release tag); monthly by default, more often allowed, never less | 2026-11-28 |
| M9 | **Gremlins pinned to an exact version** (v0.6.0, pre-1.0 accepted), run only through `run-go-mutation.sh` | 2026-11-28; pre-1.0 settings change |
| M10 | **No suppression comment, no `excludes` key**: Gremlins has neither. Survivors go in `mutation/mutant-record.txt` | Seen: both ignored |
| M11 | **A mutation report per run**, approved by the product owner, listing every recorded mutant and any waiver | D048.5 |

Every product size follows all eleven; size changes how many mutants, never which rules.

## What each status means

| Gremlins says | After the runner's recheck | Counts once |
|---|---|---|
| KILLED | compiles | Killed |
| KILLED | does not compile | Recorded `not-viable` |
| TIMED OUT | killed / lived / timed out again | Killed / killed by a new test or recorded `equivalent` / recorded `timeout` |
| LIVED | none | Killed by a new test, or recorded `equivalent` |
| NOT VIABLE | none | Recorded `not-viable` |
| NOT COVERED | none | A test of its own package (never recorded) |
| SKIPPED | none | Not planted; a release run with any is INVALID |

Verdicts: PASS (exit 0), WAIVER-NEEDED (3), FAIL (1), INVALID (2). Detail: `./references/verdict-and-record.md`.

## What every answer states

**Keep the answer as short as the question, within any length the user sets.** Answer the user's own points first, one by one, each with its rule in words; add a point below only where the question touches it, never a general tour of the method. Do not only follow a rule or point at a file.

1. **The rule:** every planted mutant is killed by a test or recorded individually with the reason it cannot be; there is no percentage target, and 60% (or any other figure) is rejected.
2. **The formula and who judges:** (killed + individually recorded) / all planted mutants, as counts, read by the verdict script from the JSON report Gremlins writes with `--output`; neither Gremlins' efficacy, its thresholds nor its exit code is the verdict, because efficacy leaves timed-out mutants out and counts non-compiling ones as killed, and a threshold of 100 fails even a perfect run.
3. **Waiver:** only for a result above 90% and under 100%, after the product owner reviews each uncaught mutant and records comments; at 90% or below none.
4. **Timed-out and not-viable mutants** count only once each is checked and recorded with a one-line reason; never automatically.
5. **When it runs:** the full release run blocks and finishes before publication (the publish job needs it, never `release: published`); scheduled runs report only, may cover changed code only, monthly or more often, never less.
6. **Scope:** all product code; any package left out is listed with a reason for the product owner's approval; generated code and `internal/test/` are left out and listed.
7. **Tool and its settings:** Gremlins pinned to an exact version (`@v0.6.0`), pre-1.0 accepted once pinned; never `@latest`. Whenever a `.gremlins.yaml` or a Gremlins flag is shown, name the real keys: they are nested (`unleash.threshold.efficacy`, `unleash.exclude-files`), and the flat `threshold-efficacy`, an `excludes` list and any suppression comment are silently ignored.
8. **The report** the product owner approves, with every recorded mutant and any waiver.
9. **For a survivor:** whether an input tells it apart (then the test, with the row), or the proof it cannot (then the record line).
10. **One line on what was run**; anything not run is called unverified.

## Procedure

1. Read the test strategy (exclusions, waivers), `sdlc-config.json` (`mutation_test_cadence`), `go.mod`, the coverage gate's exceptions and build tags, and the existing record.
2. Set up once, from `./templates/gremlins-config.md`, `./templates/make-targets.md`, `./templates/workflows.md` and `./templates/mutant-record.md`; copy `./scripts/run-go-mutation.sh` and `./scripts/check-go-mutation.sh` into the product's `scripts/` unchanged. For where and when it runs, read `./references/when-it-runs.md`.
3. Run `./scripts/validate-go-mutation-setup.sh <module root>`; fix every FAIL, judge each WARN, run it again until clean.
4. Commit, then `make mutation` (release) or `make mutation-changed` (scheduled). Before reading any status, read `./references/gremlins-v0.6.0.md`.
5. For each mutant not caught, follow `./references/triage-method.md`: write the test that kills it, or check it and copy the line the script printed into `mutation/mutant-record.txt` with its reason. Never record a NOT COVERED mutant.
6. Commit and run again. Repeat until PASS; above 90% put the uncaught mutants to the product owner; at 90% or below keep going.
7. Fill `./templates/mutation-report.md` into `artifacts/<product>/quality/test-reports/go-mutation-report.md` from the script's output; a waiver row goes in only after the product owner's review, naming the source id the script printed.
8. Tick `./resources/checklist.md`; after any change to code, tests, record or setup, go back to step 3.

Worked: `./examples/01-lean-rowing-boat-hire.md` (the lab that was run: every status, a waiver, a scheduled run), `./examples/02-standard-darkroom-rentals.md` (handlers in scope, a build tag, an exclusion pending approval, weekly cadence), `./examples/03-enterprise-grain-elevator-settlements.md` (many modules, long runs, tenant code, the six-hour limit).

## Gotchas

- **"Gremlins says 100% efficacy."** *Reason:* seen: with its default timeout most mutants were TIMED OUT, real survivors included, and efficacy read 100.00%. *Instead:* the verdict script's counts.
- **Trusting KILLED.** *Reason:* `go test` exits 1 on a compile error, so `"MERE" - "-"` was KILLED. *Instead:* the runner compiles each one; record the rejected ones.
- **`threshold-efficacy: 60` or `--threshold-efficacy 60`.** *Reason:* the flat key and every CLI or environment threshold are ignored; the nested key works, and at 100 fails a perfect run. *Instead:* thresholds 0.
- **`//gremlins:disable-next-line`.** *Reason:* no such comment exists; the mutant was planted. *Instead:* a record line.
- **`--test-cpu`.** *Reason:* passed as one argument, every test run fails and every mutant reports KILLED. *Instead:* leave it out.
- **Two paths, or `./internal/domain/...`.** *Reason:* one path at most; with one, names and `exclude-files` become relative to it. *Instead:* the runner, whole module.
- **A user-level `~/.gremlins/.gremlins.yaml`.** *Reason:* seen to replace the module's file. *Instead:* `--config`, as the runner does.
- **`--diff` and trusting it.** *Reason:* it skipped a changed line further down a hunk, everything in a module below the repository root, and planted everything on an empty diff. *Instead:* the runner (zero-context diffs, refuses the subfolder case); release runs never use it.
- **Exit 0 means it ran.** *Reason:* an interrupted run and a run with no mutants both exit 0 with no JSON. *Instead:* the verdict script calls a missing report INVALID.
- **Recording a NOT COVERED or a "hard to test" mutant.** *Reason:* nothing was tested, or an input exists. *Instead:* the test.

## Output

| File | When to open it |
|---|---|
| `./references/verdict-and-record.md` | Judging a run, records, waivers, scope, the coverage gates |
| `./references/triage-method.md` | Every uncaught mutant |
| `./references/gremlins-v0.6.0.md` | Reading Gremlins' output or changing its setup |
| `./references/when-it-runs.md` | Release and scheduled runs, cadence, run time |
| `./templates/gremlins-config.md` | Writing `.gremlins.yaml` |
| `./templates/make-targets.md` | The Makefile lines |
| `./templates/workflows.md` | `mutation.yml` and the publishing job |
| `./templates/mutant-record.md` | The record, exclusions and the waiver row |
| `./templates/mutation-report.md` | Reporting a run |
| `./scripts/run-go-mutation.sh` | Copied to the product; the only way Gremlins runs |
| `./scripts/check-go-mutation.sh` | Copied to the product; the verdict |
| `./scripts/validate-go-mutation-setup.sh` | Before hand-off, after every setup change |
| `./resources/checklist.md` | Before answering |

In the product: `.gremlins.yaml`, `mutation/mutant-record.txt`, `mutation/exclusions.txt`, `scripts/run-go-mutation.sh`, `scripts/check-go-mutation.sh`, the `mutation*` make targets, `.github/workflows/mutation.yml` and its job in the publishing workflow, new rows in `*_test.go` beside the code, and one report per run under `artifacts/<product>/quality/test-reports/`.
