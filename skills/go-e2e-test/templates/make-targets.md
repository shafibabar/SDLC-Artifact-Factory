# Make Targets for the End-to-End Suite

Self-contained. Add these to the product's `Makefile` when the suite is set up. `go-makefile` owns the Makefile and its rule that CI calls make targets and nothing else; it defines no `e2e` target today, so these are the lines to add. All four targets were run as written for this skill (GNU Make 3.81 on macOS), with lab Dockerfiles at the paths `e2e-images` names: `make e2e` passed; `make e2e-smoke` passed against a service running outside any cluster and wrote nothing to it; with a selection that matched no test it failed (exit 3).

None of these is a prerequisite of `ci`: the end-to-end suite never runs in `make ci`.

### `Makefile`

```makefile
.PHONY: e2e e2e-images e2e-smoke e2e-quarantine

e2e: ## Throwaway cluster, every chart, journeys and smoke, then teardown. Never part of `make ci`
	./tests/e2e/run-e2e-environment.sh

e2e-images: ## Build this commit's images for the end-to-end cluster (called by the script)
	docker build -t bookings:e2e -f build/bookings.Dockerfile .
	docker build -t scheduler:e2e -f build/scheduler.Dockerfile .
	docker build -t web-shell:e2e web-shell

e2e-smoke: ## Read-only smoke tests against the address in E2E_SMOKE_URL (promotion, restore check)
	./tests/e2e/run-go-e2e-suite.sh smoke

e2e-quarantine: ## The quarantined tests only; run inside `make e2e` through E2E_SUITES
	./tests/e2e/run-go-e2e-suite.sh quarantine
```

| Target | Who calls it | Notes |
|---|---|---|
| `e2e` | The nightly, release and by-hand workflow; a developer | The single entry point. It needs Docker, kind, Helm 4, kubectl and Go on the machine |
| `e2e-images` | `E2E_BUILD` in `tests/e2e/e2e.conf` | Give each image a tag that is not `latest` |
| `e2e-smoke` | `cd-pipeline` after a deployment, `blue-green-deployment` before cut-over, `disaster-recovery-plan` after a restore | Set `E2E_SMOKE_URL`. To pass a tenant: `./tests/e2e/run-go-e2e-suite.sh smoke -- -tenant=<id>` |
| `e2e-quarantine` | Listed in `E2E_SUITES` | Meaningful only inside the cluster of a run |

The plain form `go test ./tests/e2e/... -tags smoke -tenant=<id>` also works (run for this skill) once `E2E_SMOKE_URL` is set, but it prints `ok` when the selection matches no test; the make target fails in that case.
