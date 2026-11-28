# When It Runs: Before Each Release, and on a Schedule

Self-contained. Read when placing mutation testing in the pipelines, setting a product's cadence, or estimating run time. The decisions are the product owner's (2026-11-28, `go-mutation-test` first, `python-mutation-test` following the same decisions); the workflow is in `../templates/workflows.md` and the make targets in `../templates/make-targets.md`.

| Run | Covers | Effect | Started by |
|---|---|---|---|
| **Release run** | The whole project, every package under `src/` | **Blocks**: anything but PASS (or a waived result) stops the release, and it finishes before publication | The publishing workflow calls `mutation.yml` (`scope: full`) as a job its publish job `needs` |
| **Scheduled run** | Functions and methods changed since the last release tag | **Reports only**: blocks nothing; findings go into a report for triage | `schedule`, monthly by default |
| **By hand** | Changed (default) or full | As the scope says | `workflow_dispatch`, or `make mutation` / `make mutation-changed` locally |

Never on every pull request by default: every mutant reruns the tests that reach its function. A product may choose to run more often, pull requests included, but that never replaces the release run.

## Before a release means before

`release: types: [published]` describes a release that already exists: a workflow started by it cannot stop it, and the same goes for `created`, `released` and `prereleased`. The earlier text of this skill used that trigger as the "pre-release" run. What works: the workflow that publishes runs the mutation workflow as a job (`workflow_call`), and the publishing job declares `needs: [mutation]`. A failed, waiver-needed, invalid or cancelled run means no release. The release run is never a changed-code run: the verdict script refuses one (INVALID).

## Cadence

- Default: **monthly** scheduled runs plus the release run. The earlier weekly default is withdrawn as the default; weekly remains allowed.
- A product may run more often (weekly, nightly) by setting `methodology_parameters.mutation_test_cadence` in `sdlc-config.json` (`sdlc-config-management`); only the `cron` line changes. **Never less often**: the validator fails a cron that skips months.
- GitHub runs a schedule only on the default branch's latest commit, may delay it, and may drop queued runs under load (`research/testing/github-actions-official-docs.md`). A missing scheduled run is noticed by its absence; the release run does not depend on it.

## Scheduled runs on changed code only

The product owner allowed runs between releases to target changed code; the release run covers everything. The runner reads `git diff --unified=0 <last release tag>` over `source_paths`, maps each changed line to the function or method around it, and passes mutmut one name glob per changed function (`ciderpress.domain.slots.x_crates_allowed__mutmut_*`; a method's glob carries `xǁ<Class>ǁ`). mutmut then tests only those mutants (seen: 1 tested, 26 not checked, in about a second). Changes outside any function (module-level constants, imports) give no glob, because mutmut never mutates module-level code. Before the first tag the scheduled run covers the whole project.

A scheduled run starts from an empty `mutants/` too: mutmut's cache keeps a `survived` verdict after the test that kills it is added (seen), so a cached run would report gaps that are already closed.

## Size and time

Every product size runs the same gate (D048.2): lean, standard and enterprise all mutate all product code before each release. Size changes how long it takes:

- Each mutant reruns the tests that reach its function, with `-x`, across one worker per CPU (`--max-children` limits it). mutmut orders mutants by their tests' time, fastest first.
- Seen: the lean lab, 27 mutants, about 15 seconds of mutation plus a one-minute recheck for the two mutants that never finish (the recheck waits out the longer limit, about a minute each, run side by side). Endless mutants dominate a small project's time.
- Not measured: anything larger. A GitHub-hosted job stops at six hours (the workflow sets 350 minutes). A project whose full run does not fit needs a larger self-hosted runner; never a release run on changed code only, and never a lower bar.
- **Several projects in one repository** (several `pyproject.toml` roots): one full release job per project root, each with its own `[tool.mutmut]`, record and exclusions, and each `needs`ed by the publish job of what it ships. A root that cannot finish within six hours uses a self-hosted runner.

## Credentials and cost

None. The run reads the checkout, runs on the CI runner and writes `mutation-out/` and `mutants/`; mutmut is free and open source. A paid mutation service would need the product owner's approval (frugality rule).
