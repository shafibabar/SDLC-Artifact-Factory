# Go Mutation Testing Checklist

Copy into the working notes and tick each line before answering or handing off. A line that cannot be ticked is either fixed or named in the answer as open.

## Setup

- [ ] `.gremlins.yaml` from `../templates/gremlins-config.md`: thresholds 0, all eleven mutant types on, `timeout-coefficient` 10 or more, no `test-cpu`, `dry-run`, `diff`, flat `threshold-efficacy` or `excludes`
- [ ] Gremlins pinned to an exact version (`GREMLINS_VERSION := v0.6.0`), never `@latest`
- [ ] `scripts/run-go-mutation.sh` and `scripts/check-go-mutation.sh` copied unchanged; `mutation-out/` in `.gitignore`
- [ ] `mutation/mutant-record.txt` and `mutation/exclusions.txt` exist (headers at least)
- [ ] No `//gremlins:` or `//nomutant` comment anywhere in Go code
- [ ] Make targets `mutation-tools`, `mutation` (full, `--mode release`) and `mutation-changed` (`--diff` last tag, `--mode scheduled`); none in `make ci`
- [ ] `mutation.yml`: monthly or more often, `workflow_call`, `fetch-depth: 0`, no `release:` trigger, no `continue-on-error` or `|| true`
- [ ] The publishing workflow runs it as a job and its publish job `needs` it
- [ ] `MUTATION_TAGS` matches the build tags the coverage gate uses

## Scope

- [ ] All product code in scope at every size; handlers, repositories, adapters and `cmd/` included
- [ ] Each package left out has an `approved` line in `mutation/exclusions.txt`; pending ones listed as decisions for the product owner
- [ ] Generated code and `internal/test/` left out without entries, and listed in the report
- [ ] Coverage exceptions passed too (`coverage-exceptions.txt`)

## Each run

- [ ] Run from a clean, committed tree; `run.txt` exists (the run finished)
- [ ] The verdict from `check-go-mutation.sh`, never Gremlins' efficacy or mutant coverage
- [ ] Every LIVED mutant triaged (`../references/triage-method.md`): a test written, or proved equivalent
- [ ] Every NOT COVERED mutant given a test of its own package, or an exclusion proposed; never a record
- [ ] Every timed-out and non-compiling mutant checked, then recorded with a one-line reason; never counted automatically
- [ ] No stale record lines; moved ones updated
- [ ] Above 90% and under 100%: every uncaught mutant put to the product owner; the waiver row added only after their review, naming the source id and the exact counts
- [ ] 90% or below: no waiver asked for; the release waits for tests or records

## Report and answer

- [ ] Report from `../templates/mutation-report.md` under `artifacts/<product>/quality/test-reports/`, frontmatter complete, for the product owner's approval
- [ ] It lists every recorded mutant with its reason, everything left out, what Gremlins never plants, and any waiver
- [ ] `validate-go-mutation-setup.sh` run until 0 FAIL; each WARN judged
- [ ] The answer says what was run and calls anything not run unverified
