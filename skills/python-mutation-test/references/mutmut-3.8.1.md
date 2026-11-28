# mutmut 3.8.1: What It Does, As Run

Self-contained. Read before reading any mutmut output or changing its setup. Facts marked **seen** were observed in runs made for this skill (mutmut 3.8.1, pytest 9.2.0, pytest-cov 7.1.0, mypy 2.4.1, Python 3.14.4, uv 0.13.9, macOS arm64, 2026-11-28); facts marked **source** were read in mutmut 3.8.1's installed code; the rest come from `research/testing/mutmut-official-docs.md`. mutmut 3.9.0 was published on 2026-11-28 and is not proven here: the pin stays 3.8.1 until a run proves a newer one.

## Statuses

`mutmut results --all true` prints one `    <mutant name>: <status>` line per planted mutant (**seen**). Plain `mutmut results --all` fails: `Error: Option '--all' requires an argument.`, exit 2 (**seen**); without `--all true` killed mutants are hidden.

| Status | Worker exit codes (**source**) | Seen in the lab | What the verdict does |
|---|---|---|---|
| `killed` | 1, 3 | Yes | Killed |
| `survived` | 0 | Yes | Kill it with a test, or record `equivalent` |
| `timeout` | 36, 24, -24, 152, 255 | Yes | The runner reruns it with a longer limit: killed counts killed; survived is a survivor; timed out again is recorded `timeout` after checking |
| `caught by type check` | 37 | Yes, with `type_check_command` set | Record `not-viable` after checking |
| `no tests` | 5, 33 | Yes | Never recordable: write the test, or an approved exclusion |
| `not checked` | none recorded | Yes (outside a changed-code run's names) | INVALID inside the scope |
| `suspicious` | 35 and any unlisted code | No | INVALID |
| `segfault` | -11, -9 | No | INVALID |
| `skipped` | 34 | No | INVALID |
| `check was interrupted by user` | 2 | No | INVALID |

## Names and diffs

- A mutant is named, not numbered: `<module>.x_<function>__mutmut_<n>`, or `<module>.xǁ<Class>ǁ<method>__mutmut_<n>` for a method (`ǁ` is U+01C1), with the leading `src.` dropped and `__init__` modules shortened (**seen**: `ciderpress.domain.slots.x_is_late__mutmut_1`, `ciderpress.service_layer.booking.xǁBookingDeskǁbook__mutmut_1`, `ciderpress.service_layer.booking.xǁBookingDeskǁ__init____mutmut_1`). `<n>` counts within one function, so adding a mutant earlier in a function renumbers the rest.
- `mutmut show <name>` prints `# <name>: <status>`, then a unified diff of that function alone, with hunk line numbers counted from the function's `def` line (**seen**). An unknown name ends in a `FileNotFoundError` traceback, exit 1 (**seen**). The verdict's fingerprint is a hash of the diff without its `@@` lines, so moving a function inside its file keeps the fingerprint; changing its code near the mutation does not.

## `mutmut run`

- Order: copy the source into `mutants/`, generate mutants, run the type checker if set, collect which tests reach which function, run the clean suite, a forced-fail check, then each mutant (**source**). Each test run adds `-x -q -p no:randomly -p no:random-order --rootdir=.` plus `pytest_add_cli_args`.
- **Survivors do not make it exit non-zero**: the first lab run had 3 survivors, 2 timeouts and 4 `no tests` and exited 0 (**seen**). It exits 1 when the clean suite fails, a test file does not collect (an import error, or an unregistered marker under pytest's `strict`), the stats run fails, or no test reaches any mutated function (**seen** for the first three).
- **Coverage flags**: with `--cov ... --cov-fail-under=100` in `addopts` and no `--no-cov`, the stats run failed: `failed to collect stats. runner returned 1`, exit 1 (**seen**). With `pytest_add_cli_args = ["--no-cov"]` the same project ran (**seen**). `--no-cov` needs pytest-cov installed, which `python-unit-test`'s settings already pin.
- **The cache**: verdicts live in `mutants/` and stand on the next run unless the mutant is named or its function's code changed. Adding a test that kills a survivor did **not** reset it: the next run still said `survived` until the mutant was named (**seen**). The runner therefore deletes `mutants/` before every run.
- **Naming mutants**: `mutmut run <name or glob>...` runs only matching mutants, always rerunning them; the rest stay `not checked` on a fresh `mutants/` (**seen**: one glob, 1 tested, 23 `not checked`). A filter matching nothing ends in `AssertionError: Filtered for specific mutants, but nothing matches`, exit 1, after every mutant was generated (**seen**). Globs use shell-style matching, quoted so the shell leaves `*` alone.
- **Timeouts**: a wall limit of (the tests' estimated time + `timeout_constant`, default 1.0) x `timeout_multiplier` (default 15), and a CPU limit of twice that (**source**). Changing `timeout_multiplier` resets every cached `timeout` verdict to `not checked` and keeps the rest (**seen**), which is why the runner rechecks in a copy. In the lab, a mutant that ran 0.77 s timed out under a multiplier of 1.0 and was killed on the recheck at 60; two endless loops timed out again at 60 (about a minute) (**seen**).
- **Process start**: workers are forked; `fork` worked on macOS (**seen**). mutmut refuses native Windows (WSL only).
- **Parallel**: `--max-children` (default: the CPU count).

## `[tool.mutmut]` keys

Read from `pyproject.toml` (or `setup.cfg [mutmut]` when the table is absent). Values are not converted (**source**). Unknown keys are ignored without a warning.

| Key | Default | This skill |
|---|---|---|
| `source_paths` | guessed (`lib`, `src`, the folder's name) | `["src/<pkg>"]`, required |
| `pytest_add_cli_args` | `[]` | `["--no-cov"]`, required |
| `pytest_add_cli_args_test_selection` | `[]` | Leave unset: pytest's `testpaths` decides |
| `do_not_mutate`, `only_mutate` (globs) | `[]` | Generated files only; anything else needs an approved exclusion |
| `do_not_mutate_patterns` (line regexes) | `[]` | Each matched line needs an approved exclusion |
| `mutate_only_covered_lines` | false | Refused: coverage exclusions would hide code |
| `type_check_command` | `[]` | Optional; every mutant it rejects needs a `not-viable` record |
| `timeout_multiplier`, `timeout_constant` | 15.0, 1.0 | Leave the defaults; the runner's recheck uses 60 |
| `also_copy`, `max_stack_depth`, `debug`, `process_isolation` (`fork`/`forkserver`), `forkserver_warmup`, `max_forkserver_restarts`, `preload_modules_file`, `use_setproctitle`, `track_dependencies`, `dependency_tracking_depth`, `cache_invalidation_files`, `cache_invalidation_exclude`, `on_dependency_change`, `use_git_change_detection`, `log_to_file`, `log_file_path` | (**source**) | Leave unset unless a run needs one |
| `paths_to_mutate`, `tests_dir` | deprecated | Refused: with `tests_dir = "tests/unit/"` as a string, mutmut stopped with `TypeError: can only concatenate list (not "str") to list`, exit 1 (**seen**) |
| `runner`, `backup`, `dict_synonyms` | not keys | Refused: ignored silently |

## Hidden from mutation

- `# pragma: no mutate` on a line, `# pragma: no mutate block` (the whole statement or function), `start`/`end` pairs. Only the first word after `no mutate` is read, so a reason written after it is ignored, and a reason starting with `block` changes the meaning (**source**; **seen**: both forms removed the clamp's mutant from the count).
- Never mutated whatever the settings (**source**): module-level code (so a constant such as `DEFAULT_PAGE_SIZE = 50` never gets a mutant), decorated functions except a lone `@staticmethod` or `@classmethod` (so FastAPI route handlers under `@app.get` are never mutated), `__getattribute__`, `__setattr__`, `__new__`, some Enum methods, annotations, calls to `len` and `isinstance`, non-simple parameter defaults, triple-quoted strings.
- Mutations made: numbers (`n` → `n + 1`), strings (`"x"` → `"XXxXX"`, upper and lower case), operators and comparisons (`+`/`-`, `*`/`/`, `//` → `/`, `>`/`>=`, ...), `+=` → `=` and `-=`, `x = ...` → `x = None`, each call argument → `None` or removed, string-method swaps, `True`/`False`, `break` → `return`, `continue` → `break`, unary removal, `match` cases, ternary arms (**source**).

## Output not used for the verdict

`mutmut export-cicd-stats` (no `not checked` or `caught by type check` counts), `mutmut badge` (counts timeouts as killed), the progress line, and `mutants/*.meta` (internal; the runner reads it only to copy the type checker's message).
