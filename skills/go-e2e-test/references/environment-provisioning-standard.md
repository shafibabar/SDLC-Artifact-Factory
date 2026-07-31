# Environment-Provisioning Standard

The full e2e journey suite (`go-e2e-test`'s `SKILL.md`) needs the real, deployed system — not a simplified stand-in — because its entire purpose is catching the class of failure only the genuine deployment shape can surface: a NetworkPolicy that silently blocks a call, a Helm value that renders differently than expected, a Linkerd mTLS handshake that never completes, an ingress route that 404s. None of these exist in a test binary, and none of them exist in docker-compose either.

---

## The Decision: an Ephemeral `kind` Cluster, Not Docker-Compose

| Approach | What it proves | What it breaks | Verdict |
|---|---|---|---|
| **Ephemeral `kind` cluster** (chosen) | The real Helm charts, the real manifests `kubernetes-manifest` governs, real Kubernetes primitives (Services, NetworkPolicy, PDB) | Nothing — `kind` is a real (if single-node, lightweight) Kubernetes cluster | **Default for the full suite** |
| **docker-compose** | Containers can talk to each other over *some* network | Environment Parity (`environment-config`): a compose file is a second deployment description, hand-maintained separately from the Helm charts that actually ship, that decays the moment someone updates a chart and forgets the compose mirror | Rejected |
| **Shared, persistent `staging`** | The real production-shaped topology, continuously | Isolation — a bad e2e run seeds data into an environment other activities (`environment-config`'s SLO soak, `disaster-recovery-plan`'s DR drills) also rely on being clean; also unavailable to run more than one journey suite concurrently | Used for the `smoke` subset only, not the full suite (see `SKILL.md`'s CI-Placement Standard) |

`environment-config`'s Environment Parity law states every environment "runs the *same chart* at the *same version* pointing at the *same image digest*, and differs **only** in values." A docker-compose file cannot make that promise — it is not the chart at all, just an approximation of it, hand-written and hand-maintained in a second place. The `kind` cluster keeps the promise by construction: it installs the identical chart, at the identical digest, that every other environment runs.

---

## The Mechanism: Extending `helm-chart`'s Kind Gate

`helm-chart`'s own CI gate already creates a `kind` cluster and installs one chart into it as a chart-correctness check:

```bash
kind create cluster --wait 120s
helm install estate-scanner charts/estate-scanner \
  -f test/values-ci.yaml --wait --timeout 180s
kubectl rollout status deploy/estate-scanner
```

`environment-config` already names this cluster's lifecycle as `kind-local`: "Created and destroyed per run," used today for "Chart install tests in CI; engineer's laptop." This skill **extends the same tool and the same lifecycle** from a single-chart install check to every service a journey touches — no new provisioning technology, just a wider Helm install list against the same ephemeral cluster shape:

```bash
#!/usr/bin/env bash
# tests/e2e/provision-kind.sh — stand up the full journey environment
set -euo pipefail
RUN_ID="${GITHUB_RUN_ID:-local-$(date +%s)}"
TENANT="e2e-${RUN_ID}"

cleanup() { kind delete cluster --name "e2e-${RUN_ID}" || true; }
trap cleanup EXIT   # layer 1 of teardown — see test-data-seeding-and-teardown-standard.md

kind create cluster --name "e2e-${RUN_ID}" --wait 120s

for chart in estate-scanner entity-extractor compliance-engine; do
  helm install "$chart" "charts/${chart}" \
    -f test/values-ci.yaml \
    --set "tenant.id=${TENANT}" \
    --wait --timeout 180s
  kubectl rollout status "deploy/${chart}"
done
```

Every install pins the exact digest CI just built and signed (`ci-pipeline`) via `test/values-ci.yaml`'s image reference — the journey suite runs against the actual candidate artifact, not a rebuild of it. The `tenant.id` override is the one legitimate **identity** difference class `environment-config` already permits (not a build-time or code difference); it exists so seeded rows carry proper tenant attribution per `multi-tenancy-design`'s "Tenant ID in events and logs" criterion, without invoking that skill's full OpenTofu `create-tenant` module — that module's remaining seven steps (DNS, tenant registry, per-tenant cost tagging, standing Linkerd policy) are production-stamp concerns that do not apply to a cluster that will not exist an hour from now.

---

## Teardown

`kind delete cluster` is unconditional and destroys the entire cluster, not one namespace inside a shared one — there is no possibility of an orphaned namespace lingering inside a real, persistent cluster the way a partial `kubectl delete namespace` inside `staging` could leave one. The `trap cleanup EXIT` above is layer one of the three-layer defense; layers two and three (the workflow `if: always()` step and the scheduled orphan janitor) are covered in `test-data-seeding-and-teardown-standard.md`, because a bash trap alone does not survive every CI failure mode (a hard job timeout sends `SIGKILL`, which no trap catches).

---

## Cross-Reference to `go-integration-test`

The two skills provision ephemeral infrastructure at two different scopes, worth stating side by side: `go-integration-test`'s Testcontainers standard spins up **containers** inside a **test process**, shared per package via `TestMain`, torn down by the test binary exiting. This skill spins up a **cluster** outside any test process, for the **CI job's** lifetime, torn down by the job's own cleanup step. Neither is "more ephemeral" than the other — they operate one layer of the pyramid apart, and each layer's isolation unit matches what that layer is actually proving.
