---
name: python-mutation-test
description: >
  Use when test-strategist or anyone sets up, runs, reviews or fixes mutation
  testing for Python code in the Quality phase: mutmut (mutmut run, mutmut
  results, mutmut show, [tool.mutmut] in pyproject.toml, source_paths,
  --no-cov, pinned version), killed, survived, timeout, no tests, caught by
  type check, suspicious and not checked mutants, surviving or equivalent
  mutants and triage, # pragma: no mutate, the mutant record, the D048 rule
  (every mutant killed or recorded, no percentage target), waivers above 90%,
  the release run that blocks publication, the scheduled run on changed code,
  cadence, scope and exclusions, make mutation, the mutation workflow, the
  python mutation report; or "100% coverage, are we done", "is 60% mutation
  score enough", "only mutate the domain", "run mutation on every pull
  request". Produces mutation-report.
version: 2.0.1
phase: quality
owner: test-strategist
created: 2026-07-31
tags: [quality, python, mutation-testing, mutmut, mutant-record, equivalent-mutant, survived-mutant, timeout, waiver, release-gate, coverage, pytest]
produces: mutation-report
domain: testing
status: stable
related: [test-pyramid, python-unit-test, python-makefile, python-project-structure, ci-pipeline, cd-pipeline, sdlc-config-management, go-mutation-test]
sources:
  - research/testing/mutmut-official-docs.md
  - research/testing/pytest-official-docs.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/github-actions-official-docs.md
  - research/testing/testing-vv-dictionary-quigley.md
---

# Python Mutation Test

## Purpose

This skill owns how a Python product proves its tests would notice a fault: mutmut plants small changes (mutants) in the code and reruns the tests that reach each one; a mutant the tests do not notice is a regression-protection gap (Khorikov), which coverage cannot show. `test-strategist` authors and runs it; `test-pyramid` owns the cross-stack rule, `python-unit-test` the coverage gate, `python-makefile` the Makefile and `pyproject.toml`, `ci-pipeline` and `cd-pipeline` the pipelines. It applies the triage method of `go-mutation-test` by name. mutmut's facts come from its 3.8.1 source and from runs made for this skill.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| P1 | **Every planted mutant is killed by a test, or recorded individually with the reason it cannot be** (the change does not alter behaviour). The target is 100%; 60%, or any lower target, is rejected | D048 B |
| P2 | **Result = (killed + individually recorded) / all planted**, from `mutmut results --all true`. mutmut's summary line, `export-cicd-stats` and badge are never the verdict | D048: tool scores are not used |
| P3 | **Timed-out and type-checker-rejected mutants count only once each is checked and recorded** with a one-line reason; never automatically. A timeout a test kills on the runner's longer recheck counts as killed | D048; 2026-11-28 |
| P4 | **100% passes. More than 90% may be waived only after the product owner reviews every uncaught mutant and records comments; 90% or below, no waiver.** A waiver covers one result, tied to a source id | D048 waivers |
| P5 | **`no tests` is never recorded**: a test, or an approved exclusion | Nothing was tested |
| P6 | **All product code, at every size**: `source_paths = ["src/<pkg>"]`, the whole package. Anything left out (a file, a folder, a pragma line, a `do_not_mutate*` or `only_mutate` setting) is an exclusion listed with a reason for the product owner's approval. Generated code and test support under `tests/` are left out and listed | 2026-11-28; D048 A; 2026-11-27 |
| P7 | **The full run before each release blocks and finishes before publication**: the publishing job `needs` it. Never `release: published` | 2026-11-28; that event fires after publication |
| P8 | **Scheduled runs between releases report only**, may cover changed functions only; monthly by default, more often allowed, never less | 2026-11-28 |
| P9 | **mutmut pinned to an exact version** (`mutmut==3.8.1` in the dev group and `uv.lock`), run only through `run-python-mutation.sh` | 2026-11-28; one tool, pinned |
| P10 | **No `# pragma: no mutate` for equivalents**: survivors go in `mutation/mutant-record.txt`, outside the code | A pragma hides the mutant and its reason is not read |
| P11 | **A mutation report per run**, approved by the product owner, listing every recorded mutant and any waiver | D048.5 |

Every product size follows all eleven; size changes how many mutants, never which rules. One tool only: mutmut (cosmic-ray is not used).

## What each status means

| mutmut says | After the runner's recheck | Counts once |
|---|---|---|
| killed | none | Killed |
| timeout | killed / survived / timeout again | Killed / killed by a new test or recorded `equivalent` / recorded `timeout` |
| survived | none | Killed by a new test, or recorded `equivalent` |
| caught by type check | none | Recorded `not-viable` |
| no tests | none | A test (never recorded) |
| not checked, skipped, suspicious, segfault, check was interrupted by user | none | No result: INVALID |

Verdicts: PASS (exit 0), WAIVER-NEEDED (3), FAIL (1), INVALID (2). Detail: `./references/verdict-and-record.md`.

## What every answer states

**Keep the answer as short as the question, within any length the user sets.** Answer the user's own points first, one by one, each with its rule in words; add a point below only where the question touches it, never a general tour of the method. Do not only follow a rule or point at a file.

1. **The rule:** the target is 100%: every planted mutant is killed by a test or recorded individually with the reason it cannot be; 60%, or any lower target, is rejected.
2. **The formula and who judges:** (killed + individually recorded) / all planted, as counts. Write the command out: the verdict reads `mutmut results --all true` (plain `--all` is refused by mutmut 3.8.1) plus each survivor's `mutmut show` diff, and fails on any uncaught mutant without a record line. `mutmut run` exits 0 with survivors, so its exit code is not the verdict, and neither are the summary line, `export-cicd-stats` or the badge (it counts timeouts as killed).
3. **Waiver, in these words:** "more than 90% (not 'between 90%'): the product owner may waive after reviewing each uncaught mutant, `no tests` ones included, and recording comments; the target stays 100%; at 90% or below, no waiver: the remaining mutants are killed or recorded before release." Given counts, work out the result now and the result once every checkable mutant is recorded, and say which side of 90% each falls.
4. **Timed-out and type-checker-rejected mutants** count only once each is checked and recorded with a one-line reason; never automatically.
5. **When it runs:** the full release run blocks and finishes before publication (the publish job needs it, never `release: published`); scheduled runs report only, may cover changed functions only, monthly or more often, never less.
6. **Scope:** all product code (`source_paths = ["src/<pkg>"]`); anything left out is listed with a reason for the product owner's approval; generated code and test support under `tests/` are left out and listed.
7. **Tool and its settings:** mutmut pinned to an exact version (`mutmut==3.8.1`, locked in `uv.lock`), never an unpinned `pip install mutmut`. Whenever coverage flags or a failing mutmut run come up, say both halves: the coverage flags come out of `addopts` (the coverage gate runs its own command, so the floor is never lowered), and `pytest_add_cli_args = ["--no-cov"]` turns coverage off for mutmut. Whenever `[tool.mutmut]` is shown, name the real keys: `source_paths` and `pytest_add_cli_args = ["--no-cov"]`; `paths_to_mutate` and `tests_dir` are deprecated (a string crashed the run), and `runner` and `backup` are silently ignored.
8. **The report** the product owner approves, with every recorded mutant and any waiver.
9. **For a survivor:** whether an input tells it apart (then the parametrize row), or the proof it cannot (then the record line, never a pragma).
10. **One line on what was run**; anything not run is called unverified.

## Procedure

1. Read the test strategy (exclusions, waivers), `sdlc-config.json` (`mutation_test_cadence`), `pyproject.toml`, `uv.lock`, the coverage gate's exceptions, and the existing record.
2. Set up once, from `./templates/mutmut-config.md`, `./templates/make-targets.md`, `./templates/workflows.md` and `./templates/mutant-record.md`; copy `./scripts/run-python-mutation.sh` and `./scripts/check-python-mutation.sh` into the product's `scripts/` unchanged. For where and when it runs, read `./references/when-it-runs.md`.
3. Run `./scripts/validate-python-mutation-setup.sh <project root>`; fix every FAIL, judge each WARN, run it again until clean.
4. Commit, then `make mutation` (release) or `make mutation-changed` (scheduled). Before reading any status, read `./references/mutmut-3.8.1.md`.
5. For each mutant not caught, follow `./references/triage-in-python.md`: write the row that kills it, or check it and copy the line the script printed into `mutation/mutant-record.txt` with its reason. Never record a `no tests` mutant.
6. Commit and run again. Repeat until PASS; above 90% put the uncaught mutants to the product owner; at 90% or below keep going.
7. Fill `./templates/mutation-report.md` into `artifacts/<product>/quality/test-reports/python-mutation-report.md` from the script's output; a waiver row goes in only after the product owner's review, naming the source id the script printed.
8. Tick `./resources/checklist.md`; after any change to code, tests, record or setup, go back to step 3.

Worked: `./examples/01-lean-cider-press.md` (the lab that was run: every status, a waiver, a stale record, a refused pragma, a scheduled run), `./examples/02-standard-instrument-hire.md` (routes and adapters in scope, integration tests, a pending exclusion, weekly cadence), `./examples/03-enterprise-tug-dispatch.md` (several projects, tenant code, the six-hour limit).

## Gotchas

- **"`mutmut run` passed, so the tests are fine."** *Reason:* seen: it exited 0 with 3 survivors, 2 timeouts and 4 `no tests`. *Instead:* the verdict script.
- **`mutmut results --all`.** *Reason:* refused (exit 2): the option needs a value; without it killed mutants are hidden. *Instead:* `--all true`, as the runner does.
- **Rerunning on an old `mutants/`.** *Reason:* seen: a new test killed a survivor and mutmut still said `survived`. *Instead:* the runner deletes `mutants/` before every run.
- **`--cov` in `addopts`, no `--no-cov`.** *Reason:* seen: the stats run failed, exit 1, nothing tested. *Instead:* `pytest_add_cli_args = ["--no-cov"]`.
- **`# pragma: no mutate  (reason ...)`.** *Reason:* the mutant is never planted, so nobody reviews it, and only the first word is read (`block` widens it). *Instead:* a record line.
- **`DEFAULT_PAGE_SIZE = 50` as an "equivalent" constant.** *Reason:* module-level code is never mutated, and 50 → 51 would change behaviour anyway. *Instead:* state the limit; assert the constant where it matters.
- **Trusting a timeout.** *Reason:* seen: a slow mutant timed out under a tight limit and was killed on the longer recheck. *Instead:* the runner's recheck, then read the code before recording.
- **`type_check_command` to save time.** *Reason:* seen: mypy took 15 of 27 mutants the tests would have killed, each then needing a record. *Instead:* leave it off unless the product owner accepts that work.
- **Recording a `no tests` or a "hard to test" mutant.** *Reason:* nothing was tested, or an input exists. *Instead:* the test.

## Output

| File | When to open it |
|---|---|
| `./references/verdict-and-record.md` | Judging a run, records, waivers, scope, the coverage gate |
| `./references/triage-in-python.md` | Every uncaught mutant |
| `./references/mutmut-3.8.1.md` | Reading mutmut's output or changing its setup |
| `./references/when-it-runs.md` | Release and scheduled runs, cadence, run time |
| `./templates/mutmut-config.md` | Writing `[tool.mutmut]` |
| `./templates/make-targets.md` | The Makefile lines |
| `./templates/workflows.md` | `mutation.yml` and the publishing job |
| `./templates/mutant-record.md` | The record, exclusions and the waiver row |
| `./templates/mutation-report.md` | Reporting a run |
| `./scripts/run-python-mutation.sh` | Copied to the product; the only way mutmut runs |
| `./scripts/check-python-mutation.sh` | Copied to the product; the verdict |
| `./scripts/validate-python-mutation-setup.sh` | Before hand-off, after every setup change |
| `./resources/checklist.md` | Before answering |

In the product: `[tool.mutmut]` and the pinned dev dependency in `pyproject.toml`, `mutation/mutant-record.txt`, `mutation/exclusions.txt`, `scripts/run-python-mutation.sh`, `scripts/check-python-mutation.sh`, the `mutation*` make targets, `.github/workflows/mutation.yml` and its job in the publishing workflow, new parametrize rows under `tests/`, and one report per run at `artifacts/<product>/quality/test-reports/python-mutation-report.md`.
