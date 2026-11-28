# Workflows: Nightly, Before a Release, By Hand

Self-contained. Copy when wiring the Python end-to-end suite into a product's pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines; this is the workflow this skill adds and the job the release workflow calls. A product that already has the Go twin's workflow keeps that one file and adds the Python tool steps to it: one workflow, one `make e2e`.

**Not run on GitHub Actions.** `make e2e` and everything under it was run locally for this skill. The workflow file was only checked by this skill's validator. Action versions and commits are the ones recorded on 2026-11-28 (`actions/checkout` v7.0.1, `Azure/setup-helm` v5.1.0, `actions/upload-artifact` v7.0.2). The kind checksum is the one published for `kind-linux-amd64` v0.33.0, read on 2026-11-28; the same download-and-check was run for the macOS binary only. `pipx install uv==0.13.9` was not run.

## The workflow

### `.github/workflows/e2e.yml`

```yaml
# End-to-end journeys in a throwaway cluster inside this job's own runner.
# Never on a pull request. It stores and uses no credential.
name: e2e
on:
  schedule:
    - cron: "17 2 * * *" # nightly, off the top of the hour; default branch only
  workflow_dispatch: # by hand
  workflow_call: # from the release workflow, before it publishes
permissions:
  contents: read
concurrency:
  group: e2e-${{ github.ref }}
  cancel-in-progress: false
jobs:
  e2e:
    runs-on: ubuntu-26.04
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: Azure/setup-helm@2f5e7bc67f1f9972ab16657bb795f36d8f04de0e # v5.1.0
        with:
          version: v4.3.2 # runner images differ by a Helm major version
      - name: Install kind (pinned, checksum checked) and uv (pinned)
        run: |
          curl -fsSLo "$RUNNER_TEMP/kind" https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
          echo "aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d  $RUNNER_TEMP/kind" | sha256sum --check
          sudo install -m 0755 "$RUNNER_TEMP/kind" /usr/local/bin/kind
          pipx install uv==0.13.9
      - name: Install the locked dependencies
        run: make install
      - name: End-to-end (create, install, test, tear down)
        timeout-minutes: 45 # shorter than the job's, so the steps below still run
        run: make e2e
      - name: Upload evidence and results
        if: ${{ always() }}
        timeout-minutes: 5
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: e2e-evidence-${{ github.run_id }}-${{ github.run_attempt }}
          path: e2e-evidence/
          if-no-files-found: warn
          retention-days: 14
      - name: Delete the cluster if the script could not
        if: ${{ always() }}
        timeout-minutes: 5
        run: kind delete cluster --name "e2e-gh-${{ github.run_id }}-${{ github.run_attempt }}" --kubeconfig "$RUNNER_TEMP/e2e-backstop-kubeconfig"
```

## Before a release

A `release:` trigger fires when the release already exists, so a run started by it cannot stop the release. The suite runs inside the workflow that publishes, as a job the publishing job needs. Add to that workflow (owned by `ci-pipeline` and `cd-pipeline`):

```text
jobs:
  e2e:
    uses: ./.github/workflows/e2e.yml
    permissions:
      contents: read
  publish:
    needs: e2e          # a failed or cancelled suite means no release
    ...
```

## Why each line is there

| Line | Reason |
|---|---|
| No `pull_request` | Cost and trust: the suite takes a cluster and minutes, and a required check that fails for timing reasons teaches people to re-run red builds (`test-pyramid`) |
| `permissions: contents: read` | With any scope named, every other scope is `none`. Nothing in the job needs to write to the repository |
| No `secrets.` | Everything the suite touches is created inside the runner. A stored kubeconfig or cloud key would make another environment reachable |
| `runs-on: ubuntu-26.04`, Helm, kind and uv pinned | `ubuntu-latest` moves between images; the 24.04 image carried Helm 3 and the 26.04 image Helm 4 on 2026-11-28, and the script refuses Helm 3 |
| `make install`, then `make e2e` | CI calls make targets and nothing else (`python-makefile`). No `pytest` line: the runner inside `make e2e` gives the verdict |
| Step `timeout-minutes` below the job's | The script tears down by itself on failure and on interruption. If the step is cut off, the two `always()` steps are the second layer |
| `if: ${{ always() }}` on upload and delete | Without an `if`, a step is skipped after any failure. After a manual cancel `always()` steps still run and `!cancelled()` steps do not |
| The last step | It deletes this run's cluster by its exact name, never by a pattern and never every cluster. Deleting a cluster that is already gone succeeds. Its kubeconfig path is a new file, never the default one |

No output of the script is written to `$GITHUB_ENV`, and no address travels between steps: the script creates, tests and deletes inside one step.

## What is not verified

- Everything in this file on GitHub-hosted runners, including the tool installation step.
- Whether a **step** that reaches its `timeout-minutes` counts as a failure or a cancellation, and whether `always()` steps then run: not stated in GitHub's documentation and not run here.
- Whether `always()` steps run after the **job's** `timeout-minutes`: not stated, not run.
- After a cancel, GitHub sends the running step SIGINT, then SIGTERM 7.5 seconds later, then kills the process tree 2.5 seconds after that (documented; not run here). Locally the script deleted its cluster and exited about one second after either signal while a Python journey was running.

Teardown does not depend on any of this alone: the cluster is a container inside the job's own runner machine, which GitHub discards with the job. Nothing outlives the runner, because the suite creates nothing outside it.

A nightly failure is handled as `ci-pipeline` says for nightly suites (an issue, and promotion blocked). Opening the issue needs `issues: write` on that one job; add it there, not at workflow level.
