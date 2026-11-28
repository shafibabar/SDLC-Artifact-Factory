# Python Mutation Testing Checklist

Copy into the working notes and tick each line before answering or handing off. A line that cannot be ticked is either fixed or named in the answer as open.

## Setup

- [ ] `[tool.mutmut]` from `../templates/mutmut-config.md`: `source_paths = ["src/<pkg>"]` (the whole package), `pytest_add_cli_args = ["--no-cov"]`, no `paths_to_mutate`, `tests_dir`, `runner`, `backup` or `mutate_only_covered_lines`
- [ ] mutmut pinned exactly (`mutmut==3.8.1` in the dev group, the same version in `uv.lock`), installed by `uv sync --frozen`, never `pip install mutmut` or `uvx mutmut`
- [ ] No coverage flags in pytest's `addopts`; pytest settings as `python-unit-test` sets them
- [ ] `scripts/run-python-mutation.sh` and `scripts/check-python-mutation.sh` copied unchanged; `mutants/` and `mutation-out/` in `.gitignore`
- [ ] `mutation/mutant-record.txt` and `mutation/exclusions.txt` exist (headers at least)
- [ ] No `# pragma: no mutate`, `do_not_mutate_patterns`, `only_mutate` or hand-written `do_not_mutate` entry without an approved exclusion
- [ ] Make targets `mutation` (full, `--mode release`) and `mutation-changed` (`--changed-since` the last tag, `--mode scheduled`); neither in `make ci`
- [ ] `mutation.yml`: monthly or more often, `workflow_call`, `fetch-depth: 0`, no `release:` trigger, no `continue-on-error` or `|| true`
- [ ] The publishing workflow runs it as a job and its publish job `needs` it

## Scope

- [ ] All product code in scope at every size: `domain/`, `service_layer/`, `adapters/`, `entrypoints/`, `bootstrap.py`
- [ ] Each file or folder left out has an `approved` line in `mutation/exclusions.txt`; pending ones listed as decisions for the product owner
- [ ] Generated code (marker) and test support under `tests/` left out without entries, and listed in the report
- [ ] What mutmut never mutates (module-level code, decorated functions, ...) stated in the report

## Each run

- [ ] Run from a clean, committed tree; `mutants/` deleted by the runner; `run.txt` exists (the run finished)
- [ ] The verdict from `check-python-mutation.sh`, never mutmut's summary line, CI stats or badge
- [ ] Every survivor triaged (`../references/triage-in-python.md`): a test written, or proved equivalent
- [ ] Every `no tests` mutant given a test, or an exclusion proposed; never a record
- [ ] Every timed-out (after the recheck) and type-checker-rejected mutant checked, then recorded with a one-line reason; never counted automatically
- [ ] No stale record lines; renamed ones updated
- [ ] Above 90% and under 100%: every uncaught mutant put to the product owner; the waiver row added only after their review, naming the source id and the exact counts
- [ ] 90% or below: no waiver asked for; the release waits for tests or records

## Report and answer

- [ ] Report from `../templates/mutation-report.md` at `artifacts/<product>/quality/test-reports/python-mutation-report.md`, frontmatter complete, for the product owner's approval
- [ ] It lists every recorded mutant with its reason, everything left out, what mutmut never plants, and any waiver
- [ ] `validate-python-mutation-setup.sh` run until 0 FAIL; each WARN judged
- [ ] The answer says what was run and calls anything not run unverified
