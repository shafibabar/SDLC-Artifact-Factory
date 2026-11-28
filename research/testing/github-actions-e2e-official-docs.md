# GitHub Actions for End-to-End Suites: timeouts, conditions, permissions and setup actions
**Authors:** GitHub (docs.github.com, actions/*); The Helm Authors (helm/kind-action); Azure (Azure/setup-helm)
**Domain:** Testing and delivery (end-to-end pipelines)

Accessed 2026-11-28. GitHub Docs carry no product version. Action versions, all read at the tag from `action.yml`: `helm/kind-action` v1.15.2, 2026-11-04, commit `ea822c7bf1874f08e5a491df991c228edffc3376`; `Azure/setup-helm` v5.1.0, 2026-11-09, commit `2f5e7bc67f1f9972ab16657bb795f36d8f04de0e`; `actions/setup-go` v7.1.0, 2026-11-17, commit `d8cbb8045d7f43706b9177cceb36c1f91a6644d5`; `actions/upload-artifact` v7.0.2, 2026-10-07, commit `cf430e030ddbb5b0abf93d22962f4752f3646cd9` (https://api.github.com/repos/OWNER/REPO/releases/latest and `/git/ref/tags/TAG` for each). This note covers only what `github-actions-official-docs.md` lacks.

Sources:
- [S] https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- [X] https://docs.github.com/en/actions/reference/workflows-and-actions/expressions
- [C] https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation
- [Lm] https://docs.github.com/en/actions/reference/limits
- [E] https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- [Sec] https://docs.github.com/en/actions/reference/security/secure-use
- [Tok] https://docs.github.com/en/actions/concepts/security/github_token
- [ka] https://raw.githubusercontent.com/helm/kind-action/v1.15.2/action.yml, with `README.md` and `cleanup.sh` at the same tag
- [sh] https://raw.githubusercontent.com/Azure/setup-helm/v5.1.0/action.yml
- [sg] https://raw.githubusercontent.com/actions/setup-go/v7.1.0/action.yml, with `README.md` at the same tag
- [ua] https://raw.githubusercontent.com/actions/upload-artifact/v7.0.2/action.yml, with `README.md` at the same tag
- [RI] https://raw.githubusercontent.com/actions/runner-images/main/README.md
- [U26] https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/Ubuntu2604-Readme.md
- [U24] https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/Ubuntu2404-Readme.md

## Core Concepts

**Timeouts**
- `jobs.<id>.timeout-minutes`: "The maximum number of minutes to let a job run before GitHub automatically cancels it. Default: 360" [S].
- `jobs.<id>.steps[*].timeout-minutes`: "The maximum number of minutes to run the step before killing the process"; maximum 360 [S]. No default is stated.
- A job on a GitHub-hosted runner "can run for up to 6 hours"; at the limit "the job is terminated and fails" [Lm].

**Status check functions**
- "A default status check of `success()` is applied unless you include one of these functions" [X]. A plain cleanup step with no `if` is therefore skipped after any earlier failure.
- `success()`: all previous steps succeeded. `failure()`: "any previous step of a job fails" (for dependent jobs, any ancestor job failed). `cancelled()`: "the workflow was canceled". `always()`: "Causes the step to always execute, and returns `true`, even when canceled" [X].
- An `if` that adds its own condition after a failure "must still include `failure()`" (or another status function) to override the implicit `success()` [X].
- GitHub's warning: "Avoid using `always` for any task that could suffer from a critical failure ... otherwise the workflow may hang until it times out"; the recommended form for "regardless of its success or failure" is `if: ${{ !cancelled() }}` [X].

**What cancellation does** [C]
- The server re-evaluates `if` for running jobs; a job whose condition is true (for example `if: always()`) keeps running. For jobs that continue, the conditions of unfinished steps are re-evaluated the same way; `cancelled()` can be used there.
- So after a manual cancel: `always()` and `cancelled()` steps run; `!cancelled()`, `failure()` and default (`success()`) steps do not.
- The running step's process gets SIGINT, then SIGTERM after 7,500 ms, then the process tree is killed after a further 2,500 ms.
- "After the 5 minute cancellation timeout period, the server will forcibly terminate" whatever is still running. Cleanup under `always()` has at most five minutes after a cancel.

**Permissions**
- `permissions` may be set for the workflow and per job; each scope takes `read`, `write` or `none`. "If you specify the access for any of these permissions, all of those that are not specified are set to `none`" [S].
- `permissions: {}` disables all; `read-all` and `write-all` set every scope [S].
- With no `permissions` key the token gets "the default setting for the enterprise, organization, or repository" [S].
- Guidance: default the token "to read access only for repository contents", then increase "for individual jobs" [Sec].
- Events caused by `GITHUB_TOKEN` "will not create a new workflow run", except `workflow_dispatch` and `repository_dispatch` [Tok]. A release created by a workflow with that token does not start a `release` workflow.

**Concurrency**
- "at most one running job or workflow in a concurrency group at any time"; a newly queued run cancels "any existing `pending` job or workflow in the same concurrency group"; `cancel-in-progress: true` also cancels the running one [S].
- Group names are case-insensitive and may use the `github`, `inputs` and `vars` contexts; ordering "is not guaranteed". Documented fallback: `group: ${{ github.head_ref || github.run_id }}` [S].

**Triggers** (additions only)
- `release`: the page lists `published`, `unpublished`, `created`, `edited`, `deleted`, `prereleased`, `released`; `GITHUB_REF` is `refs/tags/<tag_name>` [E]. Each type names an activity that has already happened; no trigger runs before publication and none blocks it [E] (the last clause is this note's reading; the page does not discuss timing).
- `push` with `tags:` filters: "Events will not be created for tags when more than three tags are pushed at once" [E].
- `workflow_run` (`completed`, `requested`, `in_progress`): fires "regardless of the conclusion of the previous workflow", so check `github.event.workflow_run.conclusion`; the file must be on the default branch; no more than three levels of chaining; it "is able to access secrets and write tokens" [E].
- `workflow_dispatch` accepts a `ref` and `inputs` when triggered [E].

**Pinning actions**
- "Pin references to actions to a commit SHA"; a tag "can be moved or deleted if a bad actor gains access to the repository storing the action". The page now ranks a workflow dependency lockfile above pinning: "the strongest protection available, and supersedes SHA pinning for repositories that adopt it" [Sec].

**Actions**
- `helm/kind-action` inputs: `cluster_name` (default **`chart-testing`**, so the context is `kind-chart-testing`), `config`, `kubeconfig`, `node_image`, `version` (kind, default v0.33.0), `version_file`, `kubectl_version` (default v1.37.1), `wait` (control plane, default 60s), `registry` (default false), `cloud_provider` (default false), `install_only`, `ignore_failed_clean` [ka].
- It declares `post: cleanup.js`; `cleanup.sh` runs `kind delete cluster --name <cluster_name>` and removes the registry container. No `post-if` is declared [ka].
- `Azure/setup-helm` inputs: `version` (default **`latest`**), `version-file` (`.tool-versions`), `checksum-policy` (default `auto`), `latest-fallback` (default true: installs a built-in default that "can be a major version behind") [sh].
- `actions/setup-go` inputs: `go-version`, `go-version-file` (`go.mod`, `go.work`, `.go-version`, `.tool-versions`; `go-version` wins if both are set; a `toolchain` directive is preferred over `go`), `cache` (default true), `cache-dependency-path`. The cache key is based on `go.mod` by default. The cache is saved in a post step with `post-if: success()` [sg].
- `actions/upload-artifact` inputs: `name` (default `artifact`), `path` (required), `if-no-files-found` (`warn` default, `error`, `ignore`), `retention-days` (1 to 90, default 90), `overwrite` (default false: a duplicate name fails), `include-hidden-files` (default false). Artifacts are immutable; 500 per job [ua].

**Runner image**
- `ubuntu-latest` now maps to Ubuntu 26.04; label migration "is gradual and happens over 1-2 months" [RI].
- Ubuntu 26.04 image 20261122.9.1: Docker 29.4.2, Kind 0.33.0, Kubectl 1.37.2, **Helm 4.3.2**, Go 1.25.14, 1.26.11, 1.27.4 [U26]. Ubuntu 24.04 image 20261122.23.1: Docker 28.0.4, Kind 0.33.0, Kubectl 1.37.2, **Helm 3.22.1** [U24].

## Actionable Techniques

- Put `timeout-minutes` on the test **step**, shorter than the job's, so the step fails and later steps are still evaluated; put log collection and teardown under `if: ${{ always() }}` and give each its own `timeout-minutes` [S] [X] [C]. (That a step timeout counts as a failed step is inference; see Caveats.)
- Upload evidence with `if: ${{ failure() }}` or `!cancelled()`, `if-no-files-found: warn` or `error`, a short `retention-days`, and a unique `name` per job [X] [ua].
- Declare `permissions: contents: read` at workflow level and add scopes per job [S] [Sec].
- Gate a release on the suite before the release exists: run the suite in the workflow that creates the tag or release, as a `needs` dependency; `release: published` is too late to block [E] (design inference).
- Pin each action by the commit SHA recorded above; pin `ubuntu-26.04` rather than `ubuntu-latest`, and set tool versions explicitly [Sec] [RI] [sh].
- Set `cluster_name` explicitly and pass the matching `--context` everywhere [ka].

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-e2e-test, python-e2e-test | Teardown must run when the test step times out | Implicit `success()`, `always()` versus `!cancelled()`, the five-minute forced stop, kind-action's post step |
| go-e2e-test, python-e2e-test | Suite must finish before a release is published | `release` types describe completed activity; token-created releases start no workflow |
| go-e2e-test, python-e2e-test | Least privilege and logs on failure | `permissions` semantics, upload-artifact inputs, SHA pinning |

## Candidate New Skills/Agents

None.

## Key Terminology

Status Check Function, Cancellation Timeout, Concurrency Group, Post Step, Token Permissions, Activity Type.

## Caveats

- Nothing was run. No workflow was executed and no action was invoked.
- Not stated in the official documentation: whether a **step** that hits its `timeout-minutes` is treated as a failure (so that `failure()` and `always()` steps run) or as a cancellation.
- Not stated: whether a **job** that hits `timeout-minutes` follows the cancellation steps in [C] (the syntax page says GitHub "cancels it"; [C] describes cancelling a run). So whether `always()` steps and post steps run after a job timeout is not documented; this is why the step-level timeout is preferred above.
- Not stated: whether action `post` steps (kind-action's cluster delete) run after a failure, a cancel or a timeout; only that no `post-if` is declared.
- Not stated: the timing of `release` events relative to publication, and the default token permissions for a new repository.
- The 24.04 and 26.04 images differ by a Helm major version; a workflow moving labels changes Helm 3 to Helm 4.
