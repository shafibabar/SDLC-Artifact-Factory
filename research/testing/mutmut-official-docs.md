# mutmut 3 Official Documentation and Source
**Authors:** The mutmut project (boxed/mutmut)
**Domain:** Testing (mutation, Python); decision D048 follow-up B

Accessed 2026-11-25. Latest 3.8.1, uploaded 2026-10-28, Python >=3.10; depends on pytest, coverage, libcst (https://pypi.org/pypi/mutmut/json). Source base: S = https://raw.githubusercontent.com/boxed/mutmut/3.8.1/src/mutmut. README: R = https://raw.githubusercontent.com/boxed/mutmut/3.8.1/README.rst. Nothing was run.

## Core Concepts

### Commands and platform
- `run [mutant globs]`, `results [--all]`, `show`, `apply`, `browse`, `export-cicd-stats`, `badge`, `print-time-estimates`, `tests-for-mutant` (S/__main__.py; hyphen spelling of the last two is inferred from function names).
- Needs `fork`; on Windows use WSL (R).

### Configuration (`[tool.mutmut]` or `setup.cfg [mutmut]`; R, S/configuration.py)
- `source_paths`, `only_mutate`, `do_not_mutate`, `do_not_mutate_patterns` (line regexes), `also_copy`, `pytest_add_cli_args`, `pytest_add_cli_args_test_selection`, `mutate_only_covered_lines` (false), `type_check_command`, `max_stack_depth` (-1), `process_isolation` (`fork`/`forkserver`), `on_dependency_change` (`warn`/`rerun`/`ignore`), `cache_invalidation_files`, `timeout_multiplier` (15.0), `timeout_constant` (1.0; both "unstable"), `debug`.
- `paths_to_mutate` and `tests_dir` are deprecated. **Unknown keys are silently ignored** (so `runner` does nothing). In `pyproject.toml`, values are not coerced: a string `tests_dir` would raise `TypeError` (inference from source).

### Statuses (S/stats.py)

| Status | Exit codes |
|---|---|
| killed | 1, 3 (pytest internal error) |
| survived | 0 |
| no tests | 5, 33 |
| timeout | 36, -24, 24, 152, 255 |
| segfault | -11, -9 |
| suspicious | 35 and **any unlisted code** |
| skipped | 34 |
| caught by type check | 37 |
| check was interrupted by user | 2 |
| not checked | none recorded |

### Run behaviour
- Order: generate mutants, optional type filter, stats collection, clean test run, forced-fail check, mutants (S/__main__.py).
- **Survivors do not make `run` exit nonzero.** It exits 1 for a failed clean run, failed stats collection, failed forced-fail, or no test associated with any mutated function ("Stopping early"). A name filter matching nothing fails an assertion (S/__main__.py).
- Each test run uses `-x -q -p no:randomly -p no:random-order --rootdir=.` plus `pytest_add_cli_args`; pytest exit 4 raises (S/runners/harness.py).
- Timeouts: wall limit (estimated test time + constant) x multiplier, plus a CPU rlimit; `SIGXCPU`, with a hard limit one second later (S/workers/isolation.py, S/workers/timeout.py). Inference: a hard kill (-9) shows as segfault.
- Cache: stored verdicts stand unless the mutant is named; a changed function hash or result-affecting config resets them (S/__main__.py; R). Non-Python changes only warn by default. **Neither page says a changed test resets verdicts** [unverified]; treat as not reset.

### Suppression
`# pragma: no mutate`, `... no mutate block`, `... no mutate start` / `end`; unbalanced or nested raises `PragmaParseError` (R). **No reason field**: only the first word after `no mutate` (before any comma) is read, so trailing text is ignored, and a reason beginning `block`, `start` or `end` changes meaning (S/mutation/pragma_handling.py). With `mutate_only_covered_lines`, coverage exclusions are not mutated either (R).

### What is never mutated (S/mutation/file_mutation.py, mutators.py; R)
Module-level code; decorated functions (except a single `staticmethod`/`classmethod`); `__getattribute__`, `__setattr__`, `__new__`; some Enum methods; type annotations; `len` and `isinstance` calls; complex parameter defaults; triple-quoted strings. Operators cover numbers, strings, lambdas, call arguments, string-method swaps, unary removal, keywords, True/False, operators, assignments, `match` cases, ternaries.

### Machine-readable output
- `export-cicd-stats` writes `mutants/mutmut-cicd-stats.json`: killed, survived, total, no_tests, skipped, suspicious, timeout, check_was_interrupted_by_user, segfault. **No `not_checked` or `caught_by_type_check`**, though `total` counts every recorded mutant. With no data it prints a message and writes nothing (S/__main__.py, S/stats.py).
- `results --all` prints `name: status` per mutant; without `--all`, killed are hidden. `show <name>` prints status and diff.
- `mutants/<path>.meta` is JSON with `exit_code_by_key` (S/mutation/data.py); internal format.
- `badge` score is (killed + timeout)/(total - skipped); not suitable for this gate.

## Actionable Techniques (design is this note's, for D048 B)

1. Pin `mutmut==3.8.1`; commit a tested config; add `--no-cov` to `pytest_add_cli_args` and keep coverage flags out of `addopts`.
2. Delete `mutants/` before every gate run.
3. `mutmut run`; any nonzero exit fails. Then parse `mutmut results --all`.
4. A tested script fails on: empty or missing results; any status other than `killed` without a register entry; any `not checked`, `suspicious`, `segfault` or interrupted result (fix, do not record). `survived`, `timeout`, `no tests`, `skipped`, `caught by type check` need a reason; D048 B only accepts "behaviour unchanged" for survivors, so timeouts and type-check catches need a product-owner ruling.
5. Register outside the code, keyed by mutant name plus a hash of the `show` diff (inference: numbered names can shift when a function changes).
6. Scan for pragmas, `do_not_mutate*` and `only_mutate`; each needs a reason. Report the never-mutated constructs as a stated limit.
7. Zero mutants: treat as failure unless the module is approved as having nothing to mutate. Inference: with none at all, `run` hits "Stopping early" and exits 1.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-mutation-test | W3C-39 to 41; D048 B | Real keys, statuses, gate inputs, blind spots |

## Candidate New Skills/Agents

None.

## Key Terminology

Mutant, Survived, No Tests, Timeout, Suspicious.

## Caveats

- [unverified] Exact mutant-name format; behaviour on Python 3.14; how a collection error maps to a status.
- Source was read through a summarising fetch tool.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-39: string `tests_dir` crashes 3.x | Consistent with the reader | Confirmed (inference plus audit [Ran]) |
| W3C-39: `runner` unused, `paths_to_mutate` deprecated | Yes | Confirmed |
| W3C-39: `junitxml`, `html` gone | Not among CLI commands | Confirmed |
| W3C-40 [GK]: `export-cicd-stats` format | Keys above | Confirmed |
| W3C-40: gate must handle timeouts | Distinct status | Confirmed |
| C-7: pin 3.x | 3.8.1 current | Supported |
| Skill claim "run on every pull request" cost, cosmic-ray worker config | Not researched | [unverified] |
