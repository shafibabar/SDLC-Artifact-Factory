# mutmut Configuration

Self-contained. Merge into the product's one `pyproject.toml` when setting up mutation testing; `python-makefile` owns that file. mutmut reads `[tool.mutmut]` from `pyproject.toml` in the folder it runs in (the project root) and falls back to `setup.cfg` only when the table is absent.

Run as written with mutmut 3.8.1, pytest 9.2.0 and pytest-cov 7.1.0 on Python 3.14.4 (macOS arm64, 2026-11-28), in the lab of `../examples/01-lean-cider-press.md`: every key below was read, and a run with coverage flags in `addopts` and no `--no-cov` failed before testing any mutant (`failed to collect stats. runner returned 1`, exit 1).

### `pyproject.toml`

```toml
[dependency-groups]
dev = [
    "pytest==9.2.0",
    "pytest-cov==7.1.0",
    "coverage==7.17.5",
    "mutmut==3.8.1",  # pinned; mutmut 3.9.0 (2026-11-28) is not yet proven here
]

[tool.mutmut]
# All product code: the whole package, as python-project-structure lays it out.
# Test support under tests/ is never listed here.
source_paths = ["src/<pkg>"]
# Coverage is the coverage gate's job (python-unit-test); with pytest-cov
# installed, --no-cov keeps any coverage flag out of mutmut's test runs.
pytest_add_cli_args = ["--no-cov"]
# Generated code only (it carries a "generated ... DO NOT EDIT" marker); any other
# entry is an exclusion the product owner approves in mutation/exclusions.txt.
do_not_mutate = ["src/<pkg>/adapters/<generated_client>.py"]
```

Replace `<pkg>` with the package under `src/`; delete `do_not_mutate` when the product has no generated code. The pytest settings (`strict`, `filterwarnings`, markers) stay as `python-unit-test` sets them: mutmut runs the suite with them (observed: an unregistered marker under `strict` stopped the run before any mutant, exit 1).

## What not to write

| Line | What happens | Instead |
|---|---|---|
| `paths_to_mutate = "src/<pkg>/domain/"` | Deprecated in mutmut 3 (a warning), and narrower than all product code | `source_paths = ["src/<pkg>"]`, the whole package |
| `tests_dir = "tests/unit/"` | Deprecated; mutmut does not convert values, and this string stopped the run: `TypeError: can only concatenate list (not "str") to list`, exit 1 (observed) | Nothing: pytest's `testpaths` decides |
| `runner = "python -m pytest -x"`, `backup = false` | Not mutmut 3 keys: ignored without a warning | Nothing: mutmut runs pytest itself (`-x -q -p no:randomly`) |
| `# pragma: no mutate` on an equivalent line | The mutant is never planted, so it is neither counted nor reviewed, and a reason after the pragma is not read | A record line in `mutation/mutant-record.txt` |
| `do_not_mutate_patterns`, `only_mutate`, a `do_not_mutate` entry for hand-written code, a `source_paths` that leaves part of `src/` out | Product code leaves the gate unseen | An approved entry in `mutation/exclusions.txt`; the validator and the verdict script both refuse it otherwise |
| `mutate_only_covered_lines = true` | Lines coverage leaves out (a `# pragma: no cover`) are never mutated | Leave it out |
| `type_check_command = [...]` | Allowed, but every mutant the type checker rejects becomes `caught by type check`, which counts only once recorded: in the lab, mypy took 15 of 27 mutants that the tests would have killed | Leave it out unless the product owner accepts the recording work |
| `timeout_multiplier` below 15 | More mutants time out and wait for the recheck | Leave the default |
| `--cov` in `[tool.pytest.ini_options] addopts` | `python-unit-test` forbids it; under mutmut it fails the stats run unless `--no-cov` is set | Coverage flags only on the coverage gate's command |
