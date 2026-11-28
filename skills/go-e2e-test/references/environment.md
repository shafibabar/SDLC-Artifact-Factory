# The End-to-End Environment

Self-contained. Read when setting up, changing or reviewing the environment the end-to-end suites run in, or when a run fails before a test starts. Everything marked "run" was run on 2026-11-28 with kind v0.33.0, Kubernetes v1.37.0 (`kindest/node:v1.37.0`), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3 (Docker Desktop) and GNU Make 3.81 on macOS arm64. Linux was not run.

## Contents
What the environment is; what the script does; isolation from the caller's clusters; readiness; reaching the services; images; evidence; teardown; what it does not prove; product sizes.

## What the environment is

A **throwaway Kubernetes cluster (kind), created for one run and deleted at its end**, holding every chart the product's deployment plan names: each service, the web shell, and the dependencies they need. It is the same for every product size.

- **The product's real charts**, with a values file per release that changes only what `environment-config` lets environments differ in (endpoint, sizing, test-only identities). Environments are provisioned by the same automated path as production, never a hand-built approximation (Humble and Farley); a local cluster runs the same container image as production (Arundel and Domingus).
- **Never Docker Compose.** A Compose file is a second description of the deployment that nothing keeps in step with the charts, and `environment-config` forbids it. A chart error, a wrong Service name or a missing probe is exactly what this layer exists to catch.
- **Never a shared, staging, production or tenant environment.** Journeys create and delete data. Other work relies on those environments being clean, and a mistake there cannot be undone.

`go-e2e-test` owns this environment for every stack. `python-e2e-test` and `react-e2e-testing` run their suites inside it as extra lines of `E2E_SUITES`; they do not build another one.

## What the script does

`../scripts/run-e2e-environment.sh`, copied to `tests/e2e/` and started by `make e2e`, is the only thing that creates the cluster, and it is also what runs the tests and deletes the cluster. In order:

1. Reads `tests/e2e/e2e.conf`; refuses a node image that is not pinned by digest, a missing tool, and any Helm major version other than the one it was proven on (4).
2. Takes the run id: `gh-<run id>-<attempt>` on GitHub Actions (so it is the same on every step of that run), `local-<time>-<pid>` elsewhere, or `E2E_RUN_ID`. The cluster is `e2e-<run id>`.
3. Refuses to start if a cluster of that name exists: it did not create it, so it leaves it alone (run: exit 2, cluster untouched). Other `e2e-*` clusters are reported with the command to delete them and are never deleted automatically: one may belong to a run that is in progress.
4. Builds the images (`E2E_BUILD`), creates the cluster with a kubeconfig file in a new temporary folder, and loads the images.
5. Installs each release in order and waits for it (below).
6. Waits until every published port accepts a connection, then writes the **run marker**: a ConfigMap `e2e-run-marker` in `default` holding the run id and each endpoint's loopback address.
7. Runs each suite in `E2E_SUITES`. A failed suite does not stop the next one.
8. If anything failed, collects evidence. Then deletes the cluster, checks that it is gone, and exits 0 only if every suite passed and the cluster is gone.

Run: the whole flow for four releases (database, two services, web shell), eight journey tests and two smoke tests took about 50 seconds.

## Isolation from the caller's clusters

Every `kind`, `helm` and `kubectl` call in the script names the kubeconfig file created for the run (`--kubeconfig`) and its one context (`--context` / `--kube-context`). The script never calls `kubectl config use-context` and never exports `KUBECONFIG`.

| Question | What running showed |
|---|---|
| Does `kind create cluster --kubeconfig <file>` touch the default kubeconfig? | No. Only that file was written; `~/.kube/config` did not exist before or after |
| Does `kind create cluster` **without** `--kubeconfig` change the caller's current context? | **Yes.** It added the cluster to the caller's file and switched `current-context` to the new cluster. Every later `kubectl` or `helm` in any terminal then acts on it |
| What does `kubectl` do with no kubeconfig at all? | It tries `localhost:8080`. `helm list` does the same |
| Do `kubectl` and Helm write anything else under the home folder? | Yes: a discovery cache in `~/.kube/cache`, even with `--kubeconfig`. The script sets `KUBECACHEDIR` to its temporary folder; with that, nothing new appeared there |

`helm/kind-action` names its cluster `chart-testing` unless told otherwise (its documentation; not run). The workflow of this skill does not use it to create a cluster: the script does, so the cluster name, the kubeconfig file and the teardown are the same on a laptop and in CI.

## Readiness without sleeping

Helm 4 changed what a plain install waits for. Run with Helm v4.3.2 and a Deployment whose image cannot be pulled:

| Command | Result |
|---|---|
| `helm upgrade --install` with no `--wait` | **Exit 0 at once, status `deployed`, 0 of 1 Pods available.** Helm 4 then waits for hooks only |
| `... --wait --timeout 20s` | Exit 1 after 20 seconds, status `failed`, the release and its Pods left in place |
| `... --rollback-on-failure --timeout 20s` | Exit 1, and the release is **uninstalled**: its Pods and their logs are gone |
| `... --atomic` | Still accepted; behaves as `--rollback-on-failure` |
| `helm list -a` | Rejected (`unknown shorthand flag`). `helm list -A` lists failed releases too |

So the script installs with `--wait=watcher --wait-for-jobs --timeout <limit>` and **without** `--rollback-on-failure`, because the failed Pods are the evidence. `--timeout` bounds each Kubernetes operation, not the whole command (Helm's documentation; not measured here). After Helm returns, the script runs `kubectl rollout status --timeout` on every Deployment, StatefulSet and DaemonSet of the release: Helm's wait can return for a single-replica Deployment at minimum availability (documented; not reproduced here), and a Deployment's `Available` condition means minimum availability, not every replica ready.

`kubectl` exit statuses, run with client v1.36.1 against v1.37.0:

| Command | Exit | Message |
|---|---|---|
| `kubectl wait --for=condition=Available deployment/<missing>` | 1, at once | `NotFound` |
| `kubectl wait --for=condition=Ready pod -l <matches nothing>` | 1, **at once** | `no matching resources found` |
| `kubectl wait ...` on something that never gets there | 1 at the timeout | `timed out waiting for the condition` |
| `kubectl rollout status deployment/<missing>` | 1, at once | `NotFound` |
| `kubectl rollout status ... --timeout=5s`, never ready | 1 at the timeout | `timed out waiting for the condition` |
| `kubectl wait --for=create deployment/<missing> --timeout=3s` | 1 after 3 seconds | timed out |

A selector that matches nothing fails immediately, so `kubectl wait pod -l ...` straight after an install can fail before the Pods exist; wait for the rollout of the workload instead. `kubectl wait` defaults to 30 seconds: always pass `--timeout`. The script contains no `sleep`.

## Reaching the services

Each name in `E2E_ENDPOINTS` is a NodePort that kind publishes on a **free port of `127.0.0.1`** (`extraPortMappings` with `listenAddress: "127.0.0.1"`); the API server is bound to loopback too. Ports are chosen per run, so two runs on one machine do not collide. A port-forward is not used: it serves one Pod and ends when that Pod restarts.

The test process learns the addresses from the run marker, read through the run's kubeconfig. That is what ties "the address I am about to write to" to "the cluster this run created" (`./safety-guards.md`).

## Images

- Images built from the commit under test are loaded with `kind load docker-image`. Use a tag that is not `latest` and `imagePullPolicy: IfNotPresent`.
- Run: `kind load docker-image postgres:17.12-alpine` failed (`ctr: content digest ... not found`) because Docker's image store held one platform of a multi-platform image. Third-party images are therefore pulled by the node from their pinned reference. That needs registry access from the runner and is subject to the registry's pull limits; a product that cannot accept that mirrors the image.

## Evidence when something fails

Collected by the script before the cluster is deleted, only when a step or a suite failed, into `e2e-evidence/` (`E2E_EVIDENCE_DIR`):

| File | Content |
|---|---|
| `run.txt` | Run id, commit, tool versions, node image, each suite's result (always written) |
| `results/` | Raw `go test -json` output and a summary per selection (always written) |
| `logs/<pod>.log` | **Every** line of every container of every Pod in the namespace, with `--prefix --timestamps --tail=-1`, and the previous container's log where there is one |
| `events.txt`, `cluster-state.txt`, `describe-pods.txt`, `helm-releases.txt` | Events of all namespaces by time, resources, Pod descriptions, release statuses |
| `kind-nodes/` | `kind export logs`: kubelet and container runtime logs of the node |

Run: with a selector `kubectl logs` printed 10 lines where `--tail=-1` printed 153. Run: after a release with an image that cannot be pulled, the events and Pod description held the pull failure and `helm-releases.txt` showed the release as `failed`.

## Teardown

| Situation | What happens | Run |
|---|---|---|
| Every suite passes | Cluster deleted, exit 0 | Yes |
| A journey fails twice | The remaining suites run, evidence is collected, cluster deleted, exit 1 | Yes |
| A release never becomes ready | No suite runs, evidence, cluster deleted, exit 1 | Yes |
| SIGINT, SIGTERM or SIGHUP, during cluster creation, an install or a suite | The running command and everything it started is stopped, cluster deleted, exit 130, within about one second | Yes, each |
| The cluster cannot be deleted | Exit 1 with the cluster's name and the command to delete it | With a fake `kind` only |
| SIGKILL, power loss | Nothing runs. The cluster is a container on that machine; the next run reports it by name | Not run |

Teardown is a call the script makes after the suites, not a consequence of the shell exiting. The exit trap is only a backstop. The earlier design, a provisioning script whose exit trap deleted the cluster, deleted it before the next workflow step could run a test.

Two things running showed:

- Every long command is started in its own process group and the script waits on it. Without that, a signal is handled only when the running command returns, and a first version left a `helm` process running after an interrupt.
- A script started in the background by a non-interactive shell (`script &` inside another script) has SIGINT set to ignored, and an ignored signal cannot be trapped: the run carried on to its normal end. SIGTERM worked in the same situation.

## What this environment does not prove

State these in the test report, each with the layer or environment that does prove it or as an open question:

- One node: nothing about scheduling across nodes, zones or regions.
- No cloud load balancer, DNS or certificate; the tests enter through a NodePort, not through the production ingress, unless an ingress controller is one of the releases.
- No service mesh unless its chart is one of the releases. A mesh or ingress installed this way was **not run for this skill**.
- Test-only credentials, empty databases, no production data volumes: nothing about performance (`go-load-test`) or migration of real data.

## Product sizes

Every size uses the cluster. **Lean** means fewer releases (often one service, its database and the web shell) and fewer journeys, never a cheaper stand-in and never zero journeys. Standard and enterprise add releases and journeys; enterprise adds journeys that prove one tenant cannot read another's data. Whether a lean product may ever use something lighter than a cluster is a question that has been put to the product owner; until it is answered, the cluster is the rule.
