# When the Python Suite Runs: Nightly, Before a Release, By Hand

Self-contained. Read when placing a Python product's end-to-end suite in the pipelines, reviewing its workflow, or deciding what a release waits for. The workflow is in `../templates/workflows.md`. `ci-pipeline` and `cd-pipeline` own the pipelines; `test-pyramid` owns the rule for when each suite runs. Local behaviour was run on 2026-11-28; **nothing here was run on GitHub Actions**.

## When

| Trigger | Runs | Why |
|---|---|---|
| Pull request | **Never** the end-to-end suite | It needs a cluster and about a minute or more per run, and it is the layer most likely to fail for reasons unrelated to the change. A required check that does that teaches people to re-run red builds. Unit, integration and contract tests guard the pull request |
| `make ci`, `make test`, the coverage gate | **Never**: the gate leaves `tests/e2e` out by path (`--skip-suite e2e`) | The journeys need the deployed product; they measure no line of the package |
| Nightly (`schedule`) | `make e2e` on the default branch | The steady signal. Scheduled runs use the latest commit of the default branch only, can start late and can be dropped under load: a missing night is not a pass |
| Before a release | `make e2e` as a job the publishing job `needs` | The release must rest on a run of the commit and images being released, finished **before** publication |
| By hand (`workflow_dispatch`) | `make e2e` | Checking one fix without waiting for the night |
| After a deployment, before a cut-over, after a restore | The **read-only smoke** tests only, against that environment | Owned by `cd-pipeline`, `blue-green-deployment` and `disaster-recovery-plan`; see below |

`make e2e` is the single entry point. CI calls it and nothing else of the suite (`python-makefile`: CI calls make targets). The workflow has one test step; the earlier text showed two different pytest commands for the same suite.

## Before a release means before

`release: types: [published]` describes something that has already happened: the workflow starts after the release is public and cannot stop it. `prereleased`, `created` and `released` are the same kind of event. The earlier text called that trigger "pre-release".

What works: the workflow that publishes calls the suite as a job (`workflow_call`) and the publishing job declares `needs: e2e`. A failed or cancelled suite then means no release. The suite tests the release candidate's own images, built once and not rebuilt for the test (Humble and Farley).

Also documented: a release created by a workflow using the default `GITHUB_TOKEN` does not start workflows triggered by `release`, so a suite hung on that trigger may never run at all.

## Least privilege

- `permissions: contents: read` at workflow level. Once any scope is named, all others are `none`.
- No stored credential: no `secrets.` reference, no kubeconfig, no cloud key. The suite needs none, because everything it touches is created inside the job's runner.
- Actions pinned to a commit; the runner image, Helm, kind and uv pinned to versions. The script refuses a Helm major version it was not proven on.
- A job that opens an issue on failure needs `issues: write` on that job only.

## Cancellation and teardown on GitHub

The script deletes its cluster by itself on failure and on SIGINT or SIGTERM (run locally with a Python journey in progress: about one second). The workflow adds an `always()` step that deletes the run's cluster by its exact name, and the cluster is a container inside a runner machine that is discarded with the job. No scheduled clean-up job exists or is needed, and nothing is deleted by name prefix or all at once. What GitHub does at a step or job time limit is not documented and was not run (`go-e2e-test` lists the documented facts).

Evidence and results are uploaded with `if: ${{ always() }}`, a name unique to the run, and a short retention.

## Cadence

Nightly is the default. A product that needs more sets `methodology_parameters.e2e_test_cadence` in `sdlc-config.json` (`sdlc-config-management`); only the `cron` line changes. Less often than nightly is not offered: the release run still has to pass, and a suite that runs rarely breaks unnoticed.

## Smoke tests on promotion

The pipelines call the read-only selection against the environment they just changed:

```bash
E2E_SMOKE_URL=https://<address of that environment> E2E_SMOKE_TENANT=<tenant id> make e2e-smoke
```

`E2E_SMOKE_TENANT` is optional. Run for this skill against a server outside any cluster: the tests passed, and the server received `GET` requests only, each with a `traceparent`.

Not `pytest tests/e2e -m smoke`. Run: that command exits 0 when every smoke test is skipped, where the runner exits 3. (Pointed at a deployed address by hand it still cannot write: journeys are deselected by the marker, and a journey that did run would be refused by the guard.)

What the caller must know: smoke tests only read; they refuse to write whatever they are pointed at; they prove the deployed product is alive and reaches its dependencies, and nothing about behaviour that needs a write. **The journeys never follow them there**: the earlier text ran a POST and a PUT "directly against the real dev/staging/tenant environment" under the name smoke.

## The report

After a run that is put forward as evidence, fill `../templates/test-report.md` from `e2e-evidence/` and write it to `artifacts/<product>/quality/test-reports/` for the product owner's approval. A chat message, a green workflow or a dashboard does not replace that approval.
