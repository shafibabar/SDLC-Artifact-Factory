# Make Targets for Mutation Testing

Self-contained. Add these lines to the product's `Makefile`; `go-makefile` owns the file and the rule that CI calls make targets and nothing else. Copy `../scripts/run-go-mutation.sh` and `../scripts/check-go-mutation.sh` into the product's `scripts/` unchanged, and add `mutation-out/` to `.gitignore`.

Run as written with GNU Make 3.81 on macOS, Go 1.27.4 and Gremlins v0.6.0 (2026-11-28), on the module in `../examples/01-lean-rowing-boat-hire.md`: `make mutation` failed (`Error 1`) with survivors and no record, stopped (`Error 3`) at more than 90% without a waiver, passed once the product owner's waiver row was in the report, and passed outright with every mutant recorded; `make mutation-changed` ran on the code changed since the last tag and exited 0 whatever the verdict (report only).

None of these is a prerequisite of `ci`: mutation testing never runs in `make ci`.

### `Makefile`

```makefile
GREMLINS_VERSION := v0.6.0
MUTATION_TAGS ?=
MUTATION_REPORT ?= $(firstword $(wildcard artifacts/*/quality/test-reports/go-mutation-report.md))
MUTATION_EXCLUSIONS := --exclusions mutation/exclusions.txt $(if $(wildcard coverage-exceptions.txt),--exclusions coverage-exceptions.txt)

.PHONY: mutation mutation-changed mutation-tools

mutation-tools: ## Install the pinned Gremlins (pre-1.0, so never @latest)
	go install github.com/go-gremlins/gremlins/cmd/gremlins@$(GREMLINS_VERSION)

mutation: ## Before each release: the whole module, judged by D048; a failure blocks the release
	./scripts/run-go-mutation.sh --gremlins-version $(GREMLINS_VERSION) $(if $(MUTATION_TAGS),--tags $(MUTATION_TAGS)) .
	./scripts/check-go-mutation.sh --mode release --commit "$$(git rev-parse HEAD)" \
	  --record mutation/mutant-record.txt $(MUTATION_EXCLUSIONS) \
	  $(if $(MUTATION_REPORT),--waiver $(MUTATION_REPORT)) .

mutation-changed: ## Scheduled, between releases: code changed since the last release tag; report only
	./scripts/run-go-mutation.sh --gremlins-version $(GREMLINS_VERSION) $(if $(MUTATION_TAGS),--tags $(MUTATION_TAGS)) \
	  --diff "$$(git describe --tags --abbrev=0 2>/dev/null)" .
	./scripts/check-go-mutation.sh --mode scheduled --commit "$$(git rev-parse HEAD)" \
	  --record mutation/mutant-record.txt $(MUTATION_EXCLUSIONS) .
```

| Target | Who calls it | Notes |
|---|---|---|
| `mutation-tools` | The workflow; a developer once | Installs the exact version into `$(go env GOPATH)/bin` (or `GOBIN`) |
| `mutation` | The release workflow, through `mutation.yml`; a developer before tagging | Needs a clean working tree. The verdict script exits 0 PASS (or waived), 1 FAIL, 2 INVALID or no result, 3 WAIVER-NEEDED; `make` then exits 2 for any non-zero and prints the script's code (`make: *** [mutation] Error 3`). Anything but 0 stops the release |
| `mutation-changed` | The scheduled workflow | Before the first release tag `git describe` finds nothing, the diff is empty and the whole module runs. Exits 0 unless the run is INVALID |

Build tags: a production file behind a custom build tag is NOT COVERED unless its tests run; set `MUTATION_TAGS` to the tags the coverage gate uses (`make mutation MUTATION_TAGS=extra` planted and killed such a file in the lab).

`coverage-exceptions.txt` is the coverage gate's approved list (`go-unit-test`); a file excepted there cannot be tested, so the verdict leaves it out of mutation too and lists it. The waiver row is read from the run's report (`MUTATION_REPORT`), and only for `--mode release`.
