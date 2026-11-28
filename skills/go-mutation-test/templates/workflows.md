# Workflows: Before a Release, on a Schedule, By Hand

Self-contained. Copy when wiring mutation testing into a product's pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines; this is the workflow this skill adds and the job the publishing workflow calls.

**Not run on GitHub Actions.** Both files were checked by this skill's validator and the make targets they call were run locally (2026-11-28). Action versions and commits are the ones recorded by `go-e2e-test` on 2026-11-28 (`actions/checkout` v7.0.1, `actions/setup-go` v7.1.0, `actions/upload-artifact` v7.0.2).

### `.github/workflows/mutation.yml`

```yaml
# Mutation testing (go-mutation-test). The release workflow calls this one as a job
# its publish job needs, so a release waits for the full run and a failure stops it.
# Scheduled runs cover code changed since the last release and report only.
# Never triggered by `release:`: that event fires after the release is published.
name: mutation
on:
  schedule:
    - cron: "41 3 1 * *" # monthly, the default; a product may run more often, never less
  workflow_dispatch:
    inputs:
      scope:
        description: "changed (since the last release tag) or full"
        type: choice
        options: [changed, full]
        default: changed
  workflow_call:
    inputs:
      scope:
        description: "full: the release run"
        type: string
        default: full
permissions:
  contents: read
concurrency:
  group: mutation-${{ github.ref }}
  cancel-in-progress: false
jobs:
  mutation:
    runs-on: ubuntu-26.04
    timeout-minutes: 350 # under GitHub-hosted runners' 6-hour job limit
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0 # the scheduled run diffs against the last release tag
      - uses: actions/setup-go@d8cbb8045d7f43706b9177cceb36c1f91a6644d5 # v7.1.0
        with:
          go-version-file: go.mod
      - name: Install Gremlins (pinned)
        run: make mutation-tools
      - name: Whole module, judged as a release run (blocks)
        if: ${{ inputs.scope == 'full' }}
        run: make mutation
      - name: Code changed since the last release (report only)
        if: ${{ inputs.scope != 'full' }}
        run: make mutation-changed
      - name: Upload the run
        if: ${{ always() }}
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: mutation-${{ github.run_id }}-${{ github.run_attempt }}
          path: mutation-out/
          if-no-files-found: warn
          retention-days: 30
```

## In the publishing workflow

Add the job and the `needs` (the rest of the file belongs to `ci-pipeline` and `cd-pipeline`):

### `.github/workflows/release.yml`

```yaml
# The mutation lines of the publishing workflow (ci-pipeline and cd-pipeline own the rest).
name: release
on:
  push:
    tags: ["v*"]
permissions:
  contents: read
jobs:
  mutation:
    uses: ./.github/workflows/mutation.yml
    with:
      scope: full
    permissions:
      contents: read
  publish:
    needs: [mutation] # a failed, waiver-needed or cancelled mutation run means no release
    runs-on: ubuntu-26.04
    permissions:
      contents: write
    steps:
      - run: echo "publish here"
```

## Why each line is there

| Line | Reason |
|---|---|
| No `release:` trigger | `release: types: [published]` starts after the release is public and cannot stop it (`go-e2e-test` established this; a release made with the default `GITHUB_TOKEN` does not start such workflows at all) |
| `workflow_call` with `scope: full` and `needs: [mutation]` | The full run finishes before publication, and anything but PASS (or a waived result) means no release |
| `schedule` monthly | The default cadence between releases. A product may set a more frequent one (`methodology_parameters.mutation_test_cadence` in `sdlc-config.json`, `sdlc-config-management`); only the `cron` line changes. Less often is refused by the validator |
| `scope != 'full'` for schedule and by hand | A scheduled run covers only code changed since the last release tag, to save time, and reports only. A scheduled run also starts only on the default branch's latest commit and may be delayed or dropped under load (GitHub's documentation) |
| `fetch-depth: 0` | `git describe` and Gremlins' `git diff --merge-base` need the tags and history |
| `timeout-minutes: 350` | GitHub-hosted jobs stop at six hours. A module whose full run takes longer needs a larger self-hosted runner; never a `--diff` release run |
| No `secrets.`, `contents: read` | The run reads the checkout and nothing else |
| `upload-artifact` with `always()` | `mutation-out/` (Gremlins' JSON and log, the recheck, `run.txt`) is the evidence the report is filled from |

## What is not verified

- That `setup-go` puts `$(go env GOPATH)/bin` on the `PATH` for the step after `make mutation-tools` (not run here). If it does not, add `echo "$(go env GOPATH)/bin" >> "$GITHUB_PATH"`.
- How long a full run takes on a hosted runner: the lab module (27 mutants) took 40 to 130 seconds on an Apple-silicon laptop, depending on load.
- Whether `inputs.scope` is empty for a scheduled event on every runner version (documented: inputs are empty for events that have none, so the step runs `mutation-changed`).
