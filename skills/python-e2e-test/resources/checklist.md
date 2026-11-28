# Python End-to-End Test Checklist

Copy and tick before hand-off.

## Journeys
- [ ] Each journey needs more than one deployed part; everything one part can prove alone is at a lower layer
- [ ] Each journey names its acceptance criteria (`AC-US-n.m`) in its docstring; every Must Have criterion is proven here or lower
- [ ] No product package is imported, no `ASGITransport` or `TestClient`; every request goes over the network to a deployed Pod
- [ ] Lean still has journeys, in the cluster
- [ ] Each new journey was seen to fail for the expected reason

## Environment
- [ ] A throwaway kind cluster created by the run; no Docker Compose; no shared, staging, production or tenant environment
- [ ] `tests/e2e/e2e.conf` lists every chart of the deployment plan, the web shell and dependencies, dependencies first
- [ ] The charts are the product's own; values files change only endpoint, sizing and test-only identities
- [ ] Node image pinned by digest; Helm 4, kind, kubectl and uv versions pinned where the suite runs
- [ ] The two scripts are copied unchanged
- [ ] A product with Go services too: one `e2e.conf`, one script run, one suite line per language and selection

## Safety
- [ ] Every `kind`, `helm` and `kubectl` command names the run's kubeconfig and context; no `use-context`; no clusters deleted by pattern
- [ ] Journeys take addresses only from the run marker; no address from the environment or an option
- [ ] Every client comes from `env.client`, `env.async_client` or the `smoke` fixture; no plain `httpx` client, no `requests`
- [ ] Guard self-checks are in the suite and pass
- [ ] Every test is in `tests/e2e/journeys/` or `tests/e2e/smoke/`; seeding code is in `journeys/`
- [ ] Smoke tests only read, through the `smoke` client; no smoke file imports journey code or a database driver
- [ ] Test data through the public API; any direct write is a plain `INSERT` to an address from the marker; no upsert
- [ ] Each test removes exactly what it created, in the fixture that created it, failures reported
- [ ] No cloud command, no stored credential

## Waiting and tracing
- [ ] No `time.sleep` or `asyncio.sleep` as a wait; every wait is `eventually` or `eventually_async` with a deadline
- [ ] `conftest.py` is unchanged: SDK tracer provider, W3C propagator, the `journey` span around every test
- [ ] A failed journey shows `trace_id=`; the id is valid (not all zeros)

## Flaky tests
- [ ] The verdict comes from `run-python-e2e-suite.sh`: one retry by exact node id, no third attempt
- [ ] No rerun plugin setting, no `--reruns`, no `flaky` marker anywhere in the product
- [ ] A test that passed only on the retry is reported as flaky
- [ ] No skip and no `xfail`; quarantined tests are in `quarantine-python.txt` with an issue and a deadline, and the report says what is unproven meanwhile

## Everyday run and pipeline
- [ ] `make test` passes with `--skip-suite e2e`; `make typecheck` passes with the end-to-end files included
- [ ] `make e2e` is the single entry point and is not part of `make ci`; no target or workflow calls `pytest tests/e2e`
- [ ] No pull-request trigger; nightly, by hand, and as a job the publishing job needs
- [ ] No `release:` trigger used as the gate
- [ ] `permissions: contents: read`; no `secrets.`; actions pinned to commits
- [ ] Evidence and results uploaded with `if: always()`; a last `always()` step deletes the run's cluster by name

## Run
- [ ] `validate-python-e2e-tests.sh` has no FAIL; each WARN judged
- [ ] `make e2e` passed; the cluster is gone afterwards (`kind get clusters`)
- [ ] A failing run was tried once: evidence collected, cluster deleted, exit non-zero
- [ ] Test report written from `e2e-evidence/`, states what the environment does not prove, put to the product owner
- [ ] Anything not run, including GitHub Actions behaviour, is called unverified
