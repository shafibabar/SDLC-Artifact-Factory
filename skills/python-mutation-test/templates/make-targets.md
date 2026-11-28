# Make Targets for Mutation Testing

Self-contained. Add these lines to the product's `Makefile`; `python-makefile` owns the file and the rule that CI calls make targets and nothing else. Copy `../scripts/run-python-mutation.sh` and `../scripts/check-python-mutation.sh` into the product's `scripts/` unchanged, and add `mutants/` and `mutation-out/` to `.gitignore`.

Run as written with GNU Make 3.81 on macOS, uv 0.13.9, Python 3.14.4 and mutmut 3.8.1 (2026-11-28), on the project in `../examples/01-lean-cider-press.md`: `make mutation` stopped with survivors and no record (`Error 1`), stopped at more than 90% without a waiver (`Error 3`), passed once the product owner's waiver row was in the report, and passed outright with every mutant killed or recorded; `make mutation-changed` ran only the functions changed since the last tag and exited 0 whatever the verdict (report only).

None of these is a prerequisite of `ci`: mutation testing never runs in `make ci`.

### `Makefile`

```makefile
MUTMUT_VERSION := 3.8.1
MUTATION_REPORT ?= $(firstword $(wildcard artifacts/*/quality/test-reports/python-mutation-report.md))

.PHONY: mutation mutation-changed

mutation: ## Before each release: the whole project, judged by D048; a failure blocks the release
	uv run --frozen bash scripts/run-python-mutation.sh --mutmut-version $(MUTMUT_VERSION) .
	uv run --frozen bash scripts/check-python-mutation.sh --mode release --commit "$$(git rev-parse HEAD)" \
	  --record mutation/mutant-record.txt --exclusions mutation/exclusions.txt \
	  $(if $(MUTATION_REPORT),--waiver $(MUTATION_REPORT)) .

mutation-changed: ## Scheduled, between releases: functions changed since the last release tag; report only
	uv run --frozen bash scripts/run-python-mutation.sh --mutmut-version $(MUTMUT_VERSION) \
	  $(if $(shell git describe --tags --abbrev=0 2>/dev/null),--changed-since "$$(git describe --tags --abbrev=0)") .
	uv run --frozen bash scripts/check-python-mutation.sh --mode scheduled --commit "$$(git rev-parse HEAD)" \
	  --record mutation/mutant-record.txt --exclusions mutation/exclusions.txt .
```

| Target | Who calls it | Notes |
|---|---|---|
| `mutation` | The release workflow, through `mutation.yml`; a developer before tagging | Needs a clean working tree and `make install` (`uv sync --frozen`) first, so the pinned mutmut from `uv.lock` is on the path. The verdict script exits 0 PASS (or waived), 1 FAIL, 2 INVALID or no result, 3 WAIVER-NEEDED; `make` then prints the script's code (`make: *** [mutation] Error 3`). Anything but 0 stops the release |
| `mutation-changed` | The scheduled workflow | Before the first release tag there is no tag, so the whole project runs. Exits 0 unless the run is INVALID |

`MUTMUT_VERSION` must equal the pin in `pyproject.toml` (and so `uv.lock`); the runner refuses another installed version. The waiver row is read from the run's report (`MUTATION_REPORT`), and only for `--mode release`. Run time: the lab's full run (27 mutants, two that never finish) took about 80 seconds, most of it the one-minute recheck of the two timed-out mutants.
