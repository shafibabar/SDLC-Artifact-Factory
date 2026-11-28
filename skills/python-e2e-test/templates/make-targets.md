# Make Targets for the Python End-to-End Suite

Self-contained. Add these to the product's `Makefile` when the suite is set up. `python-makefile` owns the Makefile and its rule that CI calls make targets and nothing else; it defines no `e2e` target today, so these are the lines to add. All four targets were run as written for this skill (GNU Make 3.81, uv 0.13.9, macOS), with lab Dockerfiles at the paths `e2e-images` names: `make e2e` passed; `make e2e-smoke` passed against a server running outside any cluster, which received reads only, and `make e2e-quarantine` with an empty list ran nothing and passed; with a smoke folder that holds no test the runner behind `e2e-smoke` exited 3.

None of these is a prerequisite of `ci` or `test`: the end-to-end suite never runs in `make ci`.

### `Makefile`

```makefile
.PHONY: e2e e2e-images e2e-smoke e2e-quarantine

e2e: ## Throwaway cluster, every chart, journeys and smoke, then teardown. Never part of `make ci`
	./tests/e2e/run-e2e-environment.sh

e2e-images: ## Build this commit's images for the end-to-end cluster (called by the script)
	docker build -t loans:e2e -f build/loans.Dockerfile .
	docker build -t couriers:e2e -f build/couriers.Dockerfile .
	docker build -t web-shell:e2e web-shell

e2e-smoke: ## Read-only smoke tests against the address in E2E_SMOKE_URL (promotion, restore check)
	uv run ./tests/e2e/run-python-e2e-suite.sh smoke

e2e-quarantine: ## The quarantined tests only; run inside `make e2e` through E2E_SUITES
	uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
```

| Target | Who calls it | Notes |
|---|---|---|
| `e2e` | The nightly, release and by-hand workflow; a developer | The single entry point. It needs Docker, kind, Helm 4, kubectl, uv and the product's locked dependencies on the machine |
| `e2e-images` | `E2E_BUILD` in `tests/e2e/e2e.conf` | Give each image a tag that is not `latest` |
| `e2e-smoke` | `cd-pipeline` after a deployment, `blue-green-deployment` before cut-over, `disaster-recovery-plan` after a restore | Set `E2E_SMOKE_URL`; to read as one tenant also set `E2E_SMOKE_TENANT` |
| `e2e-quarantine` | Listed in `E2E_SUITES` | Meaningful only inside the cluster of a run |

Never call `pytest tests/e2e ...` from a target or a workflow. Run and seen: pytest exits 0 when every selected test was skipped; a rerun plugin makes it exit 0 when a test passed on its rerun; and it knows nothing of the quarantine list. The runner gives the verdict.

In a product that also has Go journeys, `e2e` stays one target and one script run; `e2e-smoke` calls both runners (`./environment-config.md`).
