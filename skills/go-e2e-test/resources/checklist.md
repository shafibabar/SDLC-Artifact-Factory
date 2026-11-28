# Go End-to-End Test Checklist

Copy and tick before hand-off.

## Journeys
- [ ] Each journey needs more than one deployed part; everything one part can prove alone is at a lower layer
- [ ] Each journey names its acceptance criteria (`AC-US-n.m`); every Must Have criterion is proven here or lower
- [ ] No product package is imported; every request goes over the network to a deployed Pod
- [ ] Lean still has journeys, in the cluster
- [ ] Each new journey was seen to fail for the expected reason

## Environment
- [ ] A throwaway kind cluster created by the run; no Docker Compose; no shared, staging, production or tenant environment
- [ ] `tests/e2e/e2e.conf` lists every chart of the deployment plan, the web shell and dependencies, dependencies first
- [ ] The charts are the product's own; values files change only endpoint, sizing and test-only identities
- [ ] Node image pinned by digest; Helm 4, kind and kubectl versions pinned where the suite runs
- [ ] The two scripts are copied unchanged
- [ ] Helm installs say `--wait` and do not say `--rollback-on-failure`; each rollout is awaited; no `sleep`

## Safety
- [ ] Every `kind`, `helm` and `kubectl` command names the run's kubeconfig and context; no `use-context`
- [ ] Journeys take addresses only from the run marker; no address from the environment or a flag
- [ ] Guard self-checks are in the suite and pass
- [ ] Every file in `tests/e2e/` is a `_test.go` file with a build tag; journeys and seeding are `e2e && !smoke`
- [ ] Smoke tests only read; `-tags smoke` and `-tags e2e,smoke` list only `TestSmoke_` tests
- [ ] Test data through the public API; any direct write is a plain `INSERT` to an address from the marker; no upsert
- [ ] Each test removes exactly what it created, registered at creation, errors reported
- [ ] No cloud command, no stored credential, nothing deleted by name prefix

## Waiting and tracing
- [ ] No `time.Sleep`; every wait polls with a deadline and reports the last reason
- [ ] `setupTracing()` runs before any client is built; every request uses the journey's context
- [ ] A failed journey prints `trace_id=`; the id is valid (not all zeros)

## Flaky tests
- [ ] The verdict comes from `run-go-e2e-suite.sh`: one retry by exact name, no third attempt
- [ ] A test that passed only on the retry is reported as flaky
- [ ] No `t.Skip`; quarantined tests are in `quarantine.txt` with an issue and a deadline, and the report says what is unproven meanwhile

## Pipeline
- [ ] `make e2e` is the single entry point and is not part of `make ci`
- [ ] No pull-request trigger; nightly, by hand, and as a job the publishing job needs
- [ ] No `release:` trigger used as the gate
- [ ] `permissions: contents: read`; no `secrets.`; actions pinned to commits
- [ ] Evidence and results uploaded with `if: always()`; a last `always()` step deletes the run's cluster by name

## Run
- [ ] `validate-go-e2e-tests.sh` has no FAIL; each WARN judged
- [ ] `make e2e` passed; the cluster is gone afterwards (`kind get clusters`)
- [ ] A failing run was tried once: evidence collected, cluster deleted, exit non-zero
- [ ] Test report written from `e2e-evidence/`, states what the environment does not prove, put to the product owner
- [ ] Anything not run, including GitHub Actions behaviour, is called unverified
