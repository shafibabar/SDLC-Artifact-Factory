# Python Gherkin Tools Official Documentation
**Authors:** pytest-dev (pytest-bdd), behave project, pytest project, PyPI
**Domain:** Testing (behaviour-driven, Python)

Accessed 2026-11-26. Versions: pytest-bdd 9.0.1 (2026-10-31), behave 1.3.3 (2025-09-04), pytest 9.2.0, pytest-cov 7.1.0. Gherkin syntax is in `gherkin-official-reference.md`. Nothing was installed or run: "source" means read from the tagged code, "inferred" means reasoned from that code and still to be proved by a test.

## Core Concepts

### Candidates (PyPI JSON API)

| Tool | Latest release | Python | Licence | Note | Source |
|---|---|---|---|---|---|
| pytest-bdd 9.0.1 | 2026-10-31 | >=3.10 (classifiers 3.10 to 3.15) | MIT | pytest>=7.0.0; gherkin-official >=29.0.0, excluding 31.0.0 and 32.0.0 | https://pypi.org/pypi/pytest-bdd/json , https://pypi.org/pypi/pytest-bdd/9.0.1/json |
| behave 1.3.3 | 2025-09-04 | >=2.7 (classifiers up to 3.13) | BSD-2-Clause | Own runner; commits dated 2026-11-21 | https://pypi.org/pypi/behave/json , https://api.github.com/repos/behave/behave/commits?per_page=3 |
| radish-bdd 0.18.4 | 2026-02-24 | >=3 (classifiers 3.7 to 3.14) | MIT | README claims all Gherkin features, mentions no pytest integration | https://pypi.org/pypi/radish-bdd/json , https://raw.githubusercontent.com/radish-bdd/radish/main/README.md |
| pytest-bdd-ng 2.3.1 | 2024-11-26 | >=3.9 | MIT | Beta; no release for two years; gherkin-official <30 | https://pypi.org/pypi/pytest-bdd-ng/json |

### pytest-bdd 9.0.1

Sources, unless stated: `README.rst`, `CHANGES.rst` and `src/pytest_bdd/{parser,scenario,plugin,generation,cucumber_json,reporting}.py` under https://raw.githubusercontent.com/pytest-dev/pytest-bdd/9.0.1/

- The README says it "implements a subset of the Gherkin language"; parsing uses `gherkin-official` (PyPI requirement).
- `Rule` is supported since 8.0.0; a rule has its own background and tags. Steps run as feature background, rule background, scenario.
- Tags lose the leading `@`. Feature, rule and scenario tags each go to the `pytest_bdd_apply_tag` hook, whose default applies `getattr(pytest.mark, tag)`. Examples tags become marks on their rows.
- Scenario outlines become `pytest.mark.parametrize` cases. Data tables arrive as a `datatable` argument (list of lists); docstrings as a `docstring` string. Placeholders in both are substituted. Both argument names are reserved.
- Binding is explicit: `scenarios(path)` or `@scenario(file, name)` in a test module.

### Tag selection (pytest)

- The `-m` grammar allows identifiers made of word characters and `: + - . [ ] \ /`, so `-m "AC-US-12.1"` and `-m "AC-US-12.1 or AC-US-12.2"` tokenise (https://raw.githubusercontent.com/pytest-dev/pytest/main/src/_pytest/mark/expression.py, main branch).
- A `markers` ini line is split at the first `:`, then at `(`, so `AC-US-12.1: description` registers that name (https://raw.githubusercontent.com/pytest-dev/pytest/main/src/_pytest/config/__init__.py, main).
- With `strict_markers` (or `strict`), an unregistered mark is an error; otherwise a warning (https://docs.pytest.org/en/stable/reference/reference.html). Names starting with `_` are rejected (`mark/structures.py`, main). The pytest-bdd README says every Gherkin tag must then be listed in `markers`.
- Inferred: tags named `@skip`, `@skipif` or `@xfail` become the real pytest marks and change the outcome.

### Undefined, pending and zero scenarios (pytest-bdd)

- A missing step raises `StepDefinitionNotFoundError` when the scenario runs, after the `pytest_bdd_step_func_lookup_error` hook: the test fails. Lookup happens at run time, so collection alone is not shown to detect it (inferred).
- `--generate-missing --feature <path>` prints missing bindings and exits 100 when any exist.
- No pending status is documented in the README or hooks read. A step that calls `pytest.skip` or `pytest.xfail` follows pytest rules, so the run can exit 0 (inferred).
- `scenarios()` raises `NoScenariosFound` only if **all** given paths yield none. Inferred: one empty feature file among non-empty ones passes silently.
- **Duplicate scenario names in one feature file overwrite silently**, including across rules (`feature.scenarios[scenario.name] = scenario`).
- A feature file that no test module binds is never collected (inferred from explicit binding).
- Outlines with no example rows are not parametrized (`return parametrizations or None`), so pytest's empty-parameter-set handling does not apply; no parser check requires Examples. A headerless Examples block is dropped.
- A scenario with no steps executes zero steps; inferred to pass.
- pytest exits 5 when no tests are collected (https://docs.pytest.org/en/stable/reference/exit-codes.html). The count is taken after `pytest_collection_modifyitems`, so a `-m` expression that deselects everything exits 5 (https://raw.githubusercontent.com/pytest-dev/pytest/9.2.0/src/_pytest/main.py). Other tests matching or collected in the same run remove that protection.

### behave 1.3.3

- `Rule` is parsed, with rule tags; Examples tags work inside outlines. A tag is any word without whitespace after `@` (https://raw.githubusercontent.com/behave/behave/v1.3.3/behave/parser.py).
- Outlines and tables are documented (https://behave.readthedocs.io/en/latest/gherkin/); that page still says tags apply only to features, scenarios and outlines, which lags the parser.
- `--tags` takes tag expressions v2 (`and`, `or`, `not`, parentheses) with wildcards such as `@foo.*`; v1 is deprecated (https://behave.readthedocs.io/en/latest/tag_expressions/).
- Undefined and pending (`StepNotImplementedError`) steps become errors, **except** that pending steps in `@wip` scenarios get `pending_warn`, which is ignored, so the scenario can pass (https://raw.githubusercontent.com/behave/behave/v1.3.3/behave/model.py , https://behave.readthedocs.io/en/latest/new_and_noteworthy_v1.2.7/).
- The run fails on failures, abort, hook or cleanup errors, or new undefined steps; no scenario count is checked. No feature files raises `ConfigError` and exit 1 (https://raw.githubusercontent.com/behave/behave/v1.3.3/behave/runner.py , `__main__.py`). Inferred: a tag filter matching nothing exits 0.
- An outline with no rows, and a run scenario with no steps, compute as passed (`model.py`).
- `--dry-run` skips step code but still reports undefined steps (`model.py`).
- Runs as its own command, not through pytest. Coverage would be `coverage run --branch -m behave`, an inference from coverage.py's `-m` runner support (https://coverage.readthedocs.io/en/latest/commands/cmd_run.html); combining with pytest data needs a combine step.

### Report outputs

- pytest-bdd: `--cucumberjson=<path>` (outlines expanded), `--gherkin-terminal-reporter` with `-v`/`-vv`, plus pytest's own reports such as JUnit XML.
- behave: `--junit` and `--junit-directory`; built-in formatters include plain, pretty, json, json.pretty, progress, rerun, tags, steps.* and captured (https://raw.githubusercontent.com/behave/behave/v1.3.3/behave/formatter/_builtins.py , https://behave.readthedocs.io/en/stable/behave/).

**pytest-bdd Cucumber JSON can mislead** (source; effects inferred):

- A step that did not set `failed` is written as `passed` even if the report outcome is skipped.
- A missing definition never starts a step report: earlier steps show passed and the missing one is absent; if it is the first step, the scenario has no steps and is dropped.
- Only call-phase reports are written, so marker-skipped scenarios are absent; with nothing recorded the file is `[]`.
- Data tables are not serialised.

## Actionable Techniques

All are design inferences from the facts above.

- Set `strict = true`, or at least `--strict-markers`; register every criterion tag, or generate registrations from the feature files in `pytest_configure`.
- Set `empty_parameter_set_mark = fail_at_collect` (default `skip`) for ordinary parametrized tests.
- Add a guard test that parses every feature file and fails on: duplicate scenario names, files or rules with no scenarios, scenarios without steps, outlines without example rows, and scenarios not bound to a collected test.
- Forbid `@skip`, `@skipif`, `@xfail` and `@wip` tags, and skips inside steps; require the run's skipped and xfailed counts to be zero.
- Take pass/fail from the pytest exit code and JUnit XML, never from Cucumber JSON alone.
- Coverage: `pytest --cov=<package> --cov-branch --cov-fail-under=100` (https://pytest-cov.readthedocs.io/en/latest/config.html).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| bdd-feature-file | `references/binding-and-running.md` names no Python tool | A tool choice, silent-pass guards, report limits |

## Candidate New Skills/Agents

None.

## Recommendation

**pytest-bdd 9.x.** Scenarios are ordinary pytest tests, so one run gives one exit code, one coverage measurement for the 100% line and branch gate (D048), shared fixtures and `-m` selection by criterion tag. It had the most recent release of the candidates and supports `Rule`. behave has stricter built-in handling of pending steps but needs a second runner and a coverage combine step, and exits successfully on an empty selection (inferred). The cost of pytest-bdd is the guard test and tag rules above. It is a new dependency, so it needs the product owner's approval, and the guards should be proved by running them before the skill relies on them.

## Key Terminology

Step Definition, Datatable, Docstring, Marker, Tag Expression, Pending Step, Undefined Step.

## Caveats

- [unverified] Every "inferred" item above; nothing was run.
- [unverified] Ambiguous or overriding step definitions in either tool.
- [unverified] How pytest-bdd renders placeholders in an outline with no rows.
- [unverified] `-m`, marker registration and mark-name code was read from pytest's main branch, not the 9.2.0 tag.
- [unverified] pytest-bdd compatibility with `pytest-xdist` and the newest `gherkin-official`.
- [unverified] radish `Rule`, tag selection, undefined-step and empty-run behaviour; pytest-bdd-ng behaviour (metadata only).
- [unverified] The search for other maintained candidates was one web search, not exhaustive.
- Some behave pages are the "latest" documentation, which may describe unreleased behaviour.

## Answers to audit questions

- **Gherkin support:** both support `Rule`, outlines, data tables and tags. pytest-bdd calls itself a Gherkin subset.
- **Tags such as `@AC-US-12.1`:** pytest's `-m` grammar and marker registration accept the name (not run). behave accepts any non-whitespace tag.
- **Maintenance:** see the candidates table.
- **pytest and coverage:** pytest-bdd is a pytest plugin; behave is a separate runner.
- **Undefined or pending:** undefined fails in both. behave `@wip` pending steps can pass; pytest-bdd skips or xfails inside steps can pass (inferred).
- **Zero scenarios, silent pass:** pytest-bdd fails when all paths are empty (`NoScenariosFound`) or pytest collects nothing (exit 5), but can silently lose duplicates, empty files and unbound files. behave fails with no feature files, but an empty selection or an outline without rows can pass.
- **Reports:** see Report outputs; pytest-bdd Cucumber JSON is not a reliable gate.
