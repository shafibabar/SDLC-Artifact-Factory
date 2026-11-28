# Workflows for a Python Product: the Verdict Run and the Nightly Additions

Self-contained. Copy when wiring a Python product's load tests into its pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines and `python-e2e-test` owns the Python product's `.github/workflows/e2e.yml`; this page holds the one workflow this skill adds and the steps the end-to-end workflow needs for the indicative tier. `load-verdict.yml` is the same file `go-load-test` ships (a test keeps the two identical): it calls `make load-verdict` and needs no Python on the runner beyond the system `python3`, because the runner and the checks import nothing from the product. A product with Go and Python services has one such workflow.

**Not run on GitHub Actions.** `make load-verdict` was run locally for this skill (macOS arm64) against a lab FastAPI service; `make load-indicative` was not run for a Python product. The workflow file was only checked by this skill's validator. Versions recorded on 2026-11-28: `actions/checkout` v7.0.1, `actions/upload-artifact` v7.0.2, `actions/cache` v6.1.0, k6 v2.4.0 (the checksum is the published one for `k6-v2.4.0-linux-amd64.tar.gz`).

## The verdict run

### `.github/workflows/load-verdict.yml`

```yaml
# The load-test verdict against the stated targets, in the designated performance environment.
# Never on a pull request. It stores no credential: test tokens are issued for the run and deleted after it.
name: load-verdict
on:
  workflow_dispatch: # by hand
  workflow_call: # from the release workflow, before it publishes
permissions:
  contents: read
  id-token: write # only to exchange this run's identity for short-lived test tokens
concurrency:
  group: load-verdict
  cancel-in-progress: false
jobs:
  load-verdict:
    runs-on: ubuntu-26.04
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Install k6 (pinned, checksum verified)
        run: |
          curl -fsSL -o "$RUNNER_TEMP/k6.tar.gz" https://github.com/grafana/k6/releases/download/v2.4.0/k6-v2.4.0-linux-amd64.tar.gz
          echo "5a5ecf23529ccf93135bc7e5b0c1cd5126ecf5f2672e22eed1556a0ab74abb87  $RUNNER_TEMP/k6.tar.gz" > "$RUNNER_TEMP/k6.sha256"
          sha256sum --check "$RUNNER_TEMP/k6.sha256"
          tar -xzf "$RUNNER_TEMP/k6.tar.gz" -C "$RUNNER_TEMP"
          echo "$RUNNER_TEMP/k6-v2.4.0-linux-amd64" >> "$GITHUB_PATH"
      - name: Verdict (smoke, average load, overload)
        timeout-minutes: 45 # shorter than the job's, so the upload still runs
        env:
          LOAD_TOKEN_CMD: ./tests/load/token-for-subject.sh
          LOAD_RUNNER_CLASS: ubuntu-26.04
        run: make load-verdict
      - name: Upload results
        if: ${{ always() }}
        timeout-minutes: 5
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: load-verdict-${{ github.run_id }}-${{ github.run_attempt }}
          path: load-evidence/
          if-no-files-found: warn
          retention-days: 30
```

## Before a release

A `release:` trigger fires when the release already exists, so a run started by it cannot stop the release. The verdict runs inside the workflow that publishes, as a job the publishing job needs (the same rule as the end-to-end suite):

```text
jobs:
  load-verdict:
    uses: ./.github/workflows/load-verdict.yml
    permissions:
      contents: read
      id-token: write
  publish:
    needs: [e2e, load-verdict]   # a failed, invalid or cancelled verdict means no release
    ...
```

A product with no approved performance environment has no `load-verdict` job. Its release then rests on the indicative tier alone, and the release notes and the report say that no target was verified.

## Why each line is there

| Line | Reason |
|---|---|
| No `pull_request`, no `schedule` on a pull-request branch | Slow suites never run on a pull request (`test-pyramid`); the run loads a real environment |
| No `secrets.` | No standing credential. `token-for-subject.sh` is the product's command that exchanges the run's OpenID Connect identity for one short-lived token per test subject; a person running `make load-verdict` after signing in is the other usual way |
| `id-token: write` | Needed for that exchange only. Drop it where tokens come another way |
| k6 by version and checksum | Exit statuses and the summary format are version facts; the runner refuses any other version |
| No `continue-on-error`, no retry step | Exit 1 (a threshold crossed), 3 (target refused) and 4 (invalid run) must each stop the release. A second run is a new result, reported as such |
| `runs-on` | A GitHub-hosted Linux runner has 4 CPUs and 16 GB in a public repository and 2 CPUs and 8 GB in a private one; larger runners are billed and need the product owner's approval. The runner marks the run INVALID when the generator leaves less than 20% of its CPUs idle. Where the generator runs is part of the designation record |
| `timeout-minutes` | A soak or breakpoint run started with `make load-verdict-one` needs its own, longer limit; a hosted job ends at 6 hours |
| `if: ${{ always() }}` on the upload | Without an `if`, a step is skipped after any failure, and a failed verdict is the one whose results are needed |

## The indicative tier in the nightly end-to-end workflow

The indicative lines run inside `make e2e` (see `./make-targets.md`), so they need no workflow of their own, no trigger and no credential. `python-e2e-test`'s `.github/workflows/e2e.yml` needs three additions, in this order around its "End-to-end" step:

```text
      - name: Install k6 (pinned, checksum verified)
        run: |
          (the same five lines as in load-verdict.yml)
      - name: Previous indicative result
        uses: actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: load-baseline
          key: load-baseline-${{ runner.os }}-${{ runner.arch }}-${{ github.run_id }}
          restore-keys: load-baseline-${{ runner.os }}-${{ runner.arch }}-
      - name: End-to-end (create, install, test, tear down)
        env:
          LOAD_RUNNER_CLASS: ${{ github.repository_visibility }}-ubuntu-26.04
        run: make e2e
      - name: Keep this run's result for the next comparison
        run: mkdir -p load-baseline && cp e2e-evidence/results/load/average-load-result.json load-baseline/
      - uses: actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: load-baseline
          key: load-baseline-${{ runner.os }}-${{ runner.arch }}-${{ github.run_id }}
```

The last two steps have no `if`, so they run only after a passing night: a failed run never becomes the baseline. `LOAD_RUNNER_CLASS` goes into the result; the runner compares two results only when it, the CPU count and the architecture match, because a repository that changes visibility changes runner size.

## What is not verified

- Everything on this page that happens on GitHub Actions: the cache restoring the most recent earlier baseline, the OpenID Connect exchange, the behaviour of `always()` after a timeout.
- A scheduled verdict run. Add `schedule:` only where the designated environment is free at that hour; scheduled runs can start late or be dropped, and a missing run is not a pass.
