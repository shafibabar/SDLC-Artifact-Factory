# When It Runs: Before Each Release, and on a Schedule

Self-contained. Read when placing mutation testing in the pipelines, setting a product's cadence, or estimating run time. The decisions are the product owner's (2026-11-28); the workflow is in `../templates/workflows.md` and the make targets in `../templates/make-targets.md`.

| Run | Covers | Effect | Started by |
|---|---|---|---|
| **Release run** | The whole module, every package | **Blocks**: anything but PASS (or a waived result) stops the release, and it finishes before publication | The publishing workflow calls `mutation.yml` (`scope: full`) as a job its publish job `needs` |
| **Scheduled run** | Code changed since the last release tag (`--diff`) | **Reports only**: blocks nothing; findings go into a report for triage | `schedule`, monthly by default |
| **By hand** | Changed (default) or full | As the scope says | `workflow_dispatch`, or `make mutation` / `make mutation-changed` locally |

Never on every pull request by default: a full run reruns a package's tests once per mutant. A product may choose to run more often, including on pull requests, but that never replaces the release run.

## Before a release means before

`release: types: [published]` describes a release that already exists: a workflow started by it cannot stop it. The same goes for `created`, `released` and `prereleased`. The earlier text of this skill used that trigger as "pre-release". What works, as `go-e2e-test` established for its suite: the workflow that publishes runs the mutation workflow as a job (`workflow_call`), and the publishing job declares `needs: [mutation]`. A failed, waiver-needed, invalid or cancelled run means no release.

The release run is never a `--diff` run: the verdict script refuses one (INVALID).

## Cadence

- Default: **monthly** scheduled runs plus the release run.
- A product may run more often (weekly, nightly) by setting `methodology_parameters.mutation_test_cadence` in `sdlc-config.json` (`sdlc-config-management`); only the `cron` line changes. **Never less often**: the validator fails a cron that skips months.
- GitHub runs a schedule only on the default branch's latest commit, may delay it, and may drop queued runs under load (GitHub's documentation). A missing scheduled run is noticed by its absence; the release run does not depend on it.

## Scheduled runs on changed code only

The product owner allowed runs between releases to target changed code; the release run covers everything. The runner passes `--diff <last release tag>` with Git told to produce diffs without context lines, because Gremlins v0.6.0 otherwise skips changed lines further down a hunk (observed). Before the first tag the diff is empty and the whole module runs. A module below the repository root cannot use `--diff` (every mutant would be SKIPPED); there the scheduled run is full.

## Size and time

Every product size runs the same gate (D048.2): lean, standard and enterprise all mutate all product code before each release. Size changes how long it takes:

- Each mutant reruns its package's tests: run time is roughly the number of mutants times the package test time (plus a compile), spread over the workers (one per CPU by default).
- Observed: the lean lab, 24 to 27 mutants over five small packages, took 40 to 150 seconds on an Apple-silicon laptop, the runner's recheck included.
- Not measured: anything larger. Gremlins' documentation warns that very large modules can take hours. A GitHub-hosted job stops at six hours (the workflow sets 350 minutes). An enterprise product whose full run does not fit needs a larger self-hosted runner, or splitting the module into several modules each run in full; never a release run on changed code only, and never a lower bar. Splitting by package with a path argument is not offered: Gremlins' file names and `exclude-files` patterns become relative to the path (observed), and the runner does not support it.
- Keep `timeout-coefficient` at 10 or more: the recheck of each TIMED OUT mutant costs up to `--recheck-timeout` seconds (default 120).

## Credentials and cost

None. The run reads the checkout, runs on the CI runner and writes `mutation-out/`; Gremlins is free and open source. A paid mutation service would need the product owner's approval (frugality rule).
