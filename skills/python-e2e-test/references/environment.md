# The End-to-End Environment, for a Python Suite

Self-contained. Read when setting up or reviewing the environment a Python end-to-end suite runs in, when a run fails before a test starts, or when a product has both Go and Python services. **`go-e2e-test` owns this environment and its script for every stack**; load it for how the cluster is created, how readiness is awaited under Helm 4, and why. This file holds what a Python suite needs to know and what was run with a Python suite on 2026-11-28: kind v0.33.0, Kubernetes v1.37.0 (`kindest/node:v1.37.0`), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, GNU Make 3.81, uv 0.13.9, Python 3.15.2 on macOS arm64. Linux was not run.

## What the environment is

A **throwaway Kubernetes cluster (kind), created for one run and deleted at its end**, holding every chart the product's deployment plan names: each service, the web shell, and the dependencies they need. It is the same for every product size, lean included.

- **The product's real charts**, with a values file per release that changes only what `environment-config` lets environments differ in. Environments are provisioned by the same automated path as production (Humble and Farley).
- **Never Docker Compose**, not for the suite and not "for authoring one journey": a Compose file is a second description of the deployment that nothing keeps in step with the charts. A chart error, a wrong Service name or a missing probe is exactly what this layer exists to catch.
- **Never a shared, staging, production or tenant environment.** Journeys create and delete data.

## One script, copied unchanged

`../scripts/run-e2e-environment.sh` is this skill's copy of the script `go-e2e-test` owns (the same program; a test fails when the copies differ). Copied to `tests/e2e/` and started by `make e2e`, it is the only thing that creates the cluster, and it also runs the suites and deletes the cluster:

1. Reads `tests/e2e/e2e.conf`; refuses a node image not pinned by digest, a missing tool, a Helm major version other than 4.
2. Takes the run id (`gh-<run id>-<attempt>` on GitHub Actions, `local-<time>-<pid>` elsewhere, or `E2E_RUN_ID`); the cluster is `e2e-<run id>`. A cluster of that name that already exists is left alone and the run stops (exit 2).
3. Builds the images, creates the cluster with a kubeconfig file in a new temporary folder, loads the images, installs each release with `--wait=watcher --wait-for-jobs --timeout` and then awaits every rollout. It contains no `sleep`.
4. Waits until every published port accepts a connection, then writes the **run marker**: a ConfigMap `e2e-run-marker` holding the run id and each endpoint's loopback address.
5. Runs each line of `E2E_SUITES`; a failed suite does not stop the next one. Each line receives `E2E_RUN_ID`, `E2E_KUBECONFIG`, `E2E_RESULTS_DIR`, `E2E_SMOKE_URL` and one `E2E_ADDR_<NAME>` per endpoint.
6. If anything failed, collects evidence into `e2e-evidence/`. Then deletes the cluster, checks that it is gone, and exits 0 only if every suite passed and the cluster is gone.

The provisioning script this skill used to show created the cluster, printed an address and ended; its exit trap deleted the cluster at that moment, before the next workflow step ran pytest. It also installed three charts, no database and no broker. One script that creates, tests and deletes replaces it.

Run with Python suites, images already built: four releases (database, two services, web shell), eight journey and self-check tests and three smoke tests took 54 seconds; the lean product (three releases, six and three tests) 49 seconds.

## Isolation from the caller's clusters

Every `kind`, `helm` and `kubectl` call names the kubeconfig file created for the run and its one context; the script never calls `kubectl config use-context` and never exports `KUBECONFIG`. The Python guard reads the marker the same way (`kubectl --kubeconfig <the run's file> --context kind-e2e-<run id> --cache-dir <beside it>`).

Run, on a machine whose `~/.kube/config` did not exist: after every run of this skill (passing, failing, interrupted, and the refusal cases) the file still did not exist and `~/.kube` had not been created. `kind create cluster` **without** `--kubeconfig` writes the caller's file and switches its current context (`go-e2e-test`, run there).

## Teardown

| Situation | What happens | Run with a Python suite |
|---|---|---|
| Every suite passes | Cluster deleted, exit 0 | Yes |
| A journey fails twice | The remaining suites run, evidence is collected, cluster deleted, exit 1 | Yes |
| SIGINT or SIGTERM while a journey is polling | pytest and the runner are stopped, cluster deleted, exit 130, about one second later | Yes, each |
| A release never becomes ready; the cluster cannot be deleted; SIGKILL | As `go-e2e-test` records | Not repeated here |

Teardown is a call the script makes after the suites, not a consequence of the shell exiting; the exit trap is only a backstop. Start the script in the foreground: a script started with `&` from another script has SIGINT ignored and cannot trap it.

## Evidence

Collected before the cluster is deleted, only when a step or a suite failed, into `e2e-evidence/`: `run.txt` (always), `results/` (always: per attempt the JUnit file and an outcome file, and `python-<selection>-summary.json`), `logs/<pod>.log` with every line of every container, `events.txt`, `cluster-state.txt`, `describe-pods.txt`, `helm-releases.txt`, `kind-nodes/`. Run: after a journey that failed twice all of these were there, with one log file per Pod.

## A product with Go and Python services

**One environment, one script run, one suite line per language.** `go-e2e-test` owns the cluster and the script; each language's skill owns its suite files and its runner. The Go files are in `tests/e2e/` (package `e2e`), the Python files in `tests/e2e/journeys/` and `tests/e2e/smoke/`; each runner reads the same run marker and writes its own files into the one results folder. Run for this skill: Go journeys and Python journeys in one cluster, one after the other (`../examples/03-enterprise-air-quality.md`). Configuration: `../templates/environment-config.md`.

## What this environment does not prove

State these in the test report, each with the layer or environment that does prove it or as an open question: one node (nothing about scheduling across nodes, zones or regions); no cloud load balancer, DNS or certificate, and entry through a NodePort unless an ingress controller is one of the releases; no service mesh unless its chart is one of the releases (not run for this skill); test-only credentials and empty databases, so nothing about performance (`python-load-test`) or migration of real data.

## Product sizes

Every size uses the cluster. **Lean** means fewer releases (often one service, its database and the web shell) and fewer journeys, never a cheaper stand-in and never zero journeys. Standard and enterprise add releases and journeys; enterprise adds journeys that prove one tenant cannot read another's data. The product owner decided on 2026-11-28 that there is no lighter variant for lean.
