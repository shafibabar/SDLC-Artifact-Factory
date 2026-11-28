# Workflows: Before a Release, on a Schedule, By Hand

Self-contained. Copy when wiring mutation testing into a Python product's pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines; this is the workflow this skill adds and the job the publishing workflow calls.

**Not run on GitHub Actions.** Both files were checked by this skill's validator and the make targets they call were run locally (2026-11-28). `actions/checkout` and `actions/upload-artifact` carry the commits `go-e2e-test` recorded on 2026-11-28 (v7.0.1, v7.0.2); `astral-sh/setup-uv` v10.3.3 (released 2026-10-28) carries the commit its tag pointed to on 2026-11-28.

### `.github/workflows/mutation.yml`

```yaml
# Mutation testing (python-mutation-test). The release workflow calls this one as a
# job its publish job needs, so a release waits for the full run and a failure stops it.
# Scheduled runs cover functions changed since the last release and report only.
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
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
      - name: Install the locked environment (pinned mutmut included)
        run: make install
      - name: Whole project, judged as a release run (blocks)
        if: ${{ inputs.scope == 'full' }}
        run: make mutation
      - name: Functions changed since the last release (report only)
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
| No `release:` trigger | `release: types: [published]` describes a release that already exists and cannot stop it (`go-e2e-test` established this; a release made with the default `GITHUB_TOKEN` does not start such workflows at all) |
| `workflow_call` with `scope: full` and `needs: [mutation]` | The full run finishes before publication, and anything but PASS (or a waived result) means no release |
| `schedule` monthly | The default cadence between releases. A product may set a more frequent one (`methodology_parameters.mutation_test_cadence` in `sdlc-config.json`, `sdlc-config-management`); only the `cron` line changes. Less often is refused by the validator |
| `scope != 'full'` for schedule and by hand | A scheduled run covers only functions changed since the last release tag, and reports only. GitHub runs a schedule only on the default branch's latest commit and may delay or drop it under load (GitHub's documentation) |
| `fetch-depth: 0` | `git describe` and the runner's `git diff` need the tags and history |
| `make install` | `uv sync --frozen`: the pinned mutmut comes from `uv.lock`, never `pip install mutmut` |
| `timeout-minutes: 350` | GitHub-hosted jobs stop at six hours. A project whose full run takes longer needs a larger self-hosted runner, or one release job per package root (see `../references/when-it-runs.md`); never a changed-code release run |
| No `secrets.`, `contents: read` | The run reads the checkout and nothing else |
| `upload-artifact` with `always()` | `mutation-out/` (results, recheck, diffs, `run.txt`) is the evidence the report is filled from |

## What is not verified

- Any of this on a GitHub-hosted runner: mutmut's `fork` start was observed on macOS only (it is the Linux default, and mutmut refuses native Windows).
- That `setup-uv` v10.3.3 needs no inputs for this project (documented: it installs uv; `uv sync` then installs the Python version the project asks for).
- Whether `inputs.scope` is empty for a scheduled event on every runner version (documented: inputs are empty for events that have none, so the step runs `mutation-changed`).
