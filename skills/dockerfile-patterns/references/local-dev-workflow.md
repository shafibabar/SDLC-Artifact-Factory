# Local Development Image Workflow (kind-local)

**Referenced from**: `dockerfile-patterns` Standard 10
**Self-contained**: yes — this document can be used without the parent SKILL.md in context.

---

## Problem Statement

The local iteration loop (change code → test in cluster) must be fast. The naive approach — build image, push to a registry, have the kind cluster pull it back — adds 60–90 seconds of network overhead per cycle. At 20 iterations per feature, that is 20–30 minutes of developer time wasted on network I/O.

The conforming workflow eliminates that round-trip entirely by injecting the locally-built image directly into the kind cluster's containerd daemon using `kind load docker-image`. No registry. No push. No pull. 5–15 seconds per cycle.

---

## The Canonical Iteration Loop

### Step 1: Build the image locally

```bash
docker build -t <service>:local .
# Example:
docker build -t estate-scanner:local .
```

The `:local` tag is conventional — it signals "this image exists only on this machine and is not backed by a registry". Any tag works, but `:local` makes the intent explicit.

### Step 2: Load into the kind cluster

```bash
kind load docker-image <service>:local --name <kind-cluster-name>
# Example:
kind load docker-image estate-scanner:local --name sdlc-local
```

`kind load docker-image` copies the image from the host's Docker daemon into the containerd daemon running inside the kind node containers. After this command, the image is available for pod scheduling in the cluster — no network I/O, no registry credential needed.

`--name <kind-cluster-name>` is required when you have more than one kind cluster running. Omit it only when you have a single cluster (kind uses `kind` as the default name).

### Step 3: Deploy with Helm referencing the local image

```bash
helm upgrade --install <release> <chart-path> \
  --set image.repository=<service> \
  --set image.tag=local \
  --set image.pullPolicy=Never
# Example (from the service's chart directory):
helm upgrade --install estate-scanner ./chart \
  --set image.repository=estate-scanner \
  --set image.tag=local \
  --set image.pullPolicy=Never
```

**`pullPolicy: Never` is the critical setting.** Without it, Kubernetes will attempt to pull the image from a registry (using `IfNotPresent` or `Always` semantics depending on the default), which fails because no registry serves `estate-scanner:local`. `pullPolicy: Never` tells the kubelet to use what is already in containerd — the image you just loaded.

---

## Makefile Target (Conformance Requirement)

Every service must expose a `make dev-image` or `make local-up` target that executes the full three-step sequence. Checklist row 11 in the conformance audit verifies this target exists and functions.

### Minimal `dev-image` target

```makefile
KIND_CLUSTER ?= sdlc-local
SERVICE      := estate-scanner
CHART_DIR    := ./chart

.PHONY: dev-image
dev-image: ## Build image, load into kind, upgrade Helm release
	docker build -t $(SERVICE):local .
	kind load docker-image $(SERVICE):local --name $(KIND_CLUSTER)
	helm upgrade --install $(SERVICE) $(CHART_DIR) \
	  --set image.repository=$(SERVICE) \
	  --set image.tag=local \
	  --set image.pullPolicy=Never
```

### Extended `local-up` target (first-time setup)

`local-up` is appropriate when the release does not yet exist in the cluster (first run after `make cluster-up`):

```makefile
.PHONY: local-up
local-up: dev-image ## Full local bootstrap: build + load + install (first-time)
	@echo "Waiting for rollout..."
	kubectl rollout status deployment/$(SERVICE) --timeout=60s
	@echo "$(SERVICE) is up in kind cluster $(KIND_CLUSTER)"
```

`dev-image` handles subsequent iterations; `local-up` is the entry point for a fresh cluster.

---

## Verifying the Loaded Image

After `kind load docker-image`, verify the image is available inside the cluster:

```bash
# Connect to the kind node's containerd and list images
docker exec -it <kind-node-name> crictl images | grep <service>
# Example:
docker exec -it sdlc-local-control-plane crictl images | grep estate-scanner
```

Expected output: a row showing `estate-scanner` with tag `local` and a non-zero size. If the image does not appear, `kind load` may have targeted the wrong cluster name.

---

## Decision Table: `kind load` vs Local Registry

| Situation | Use `kind load docker-image` | Use local registry |
|---|---|---|
| Iterating on code changes | Yes — fastest, no registry overhead | Overkill for a solo developer loop |
| Testing image pull secrets | No — no registry pull occurs | Yes — registry pull semantics are required |
| Multi-developer team sharing a dev image | No — loads to one machine's kind cluster only | Yes — push to `localhost:5001`, all devs pull |
| CI running tests against a local cluster (GitHub Actions + kind) | Yes — no registry credential needed in CI | Possible but requires configuring the registry in CI |
| Testing Helm chart `imagePullSecrets` behaviour | No | Yes — pull must fail without the secret |
| Default for this repo's kind-local environment | **Yes** | Only when a specific reason above applies |

---

## Local Registry Alternative (when required)

When registry pull semantics are genuinely needed (see decision table above), kind supports a local Docker registry via a `containerdConfigPatches` block in the kind cluster configuration.

### kind-config.yaml for local registry

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
      endpoint = ["http://localhost:5001"]
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

Create the cluster: `kind create cluster --name sdlc-local --config kind-config.yaml`

### Start the local registry

```bash
docker run -d -p 5001:5000 --restart=always --name local-registry registry:2
```

### Push and pull from the local registry

```bash
# Build and push
docker build -t localhost:5001/<service>:dev .
docker push localhost:5001/<service>:dev

# Deploy
helm upgrade --install <service> ./chart \
  --set image.repository=localhost:5001/<service> \
  --set image.tag=dev \
  --set image.pullPolicy=Always
```

`pullPolicy: Always` is correct here because the registry is local — a pull is fast and uses the registry's layer cache. The `:dev` tag is mutable and re-pushed on each iteration, so `Always` ensures the new layers are fetched.

**When to choose the local registry over `kind load`**: only when the decision table above indicates a registry-pull scenario. The default is `kind load docker-image` — it requires no infrastructure setup and is faster.

---

## Environment Variable Integration

Both approaches work with the environment configuration from `environment-config`. The kind-local environment's `values-local.yaml` should default to the `kind load` flow:

```yaml
# values-local.yaml (kind-local environment)
image:
  repository: estate-scanner    # or localhost:5001/estate-scanner for local registry
  tag: local                    # or dev for local registry
  pullPolicy: Never             # or Always for local registry
```

The `make dev-image` target overrides these via `--set` flags so developers do not need to edit `values-local.yaml` for every image rebuild. The override flags win over the values file.

---

## Troubleshooting

| Symptom | Root cause | Fix |
|---|---|---|
| `ImagePullBackOff` after `kind load` | `pullPolicy` is not `Never` | Add `--set image.pullPolicy=Never` to `helm upgrade` |
| Pod is `Pending` after `kind load` | Image loaded to wrong cluster | Re-run `kind load ... --name <correct-cluster-name>` |
| `crictl images` shows no match | `kind load` targeted a different node | Confirm `--name` matches `kind get clusters` output |
| Stale code running after `make dev-image` | Old pod not restarted (Deployment unchanged) | Add `--set podAnnotations.buildTime=$(date +%s)` to force a rollout |
| `helm upgrade` errors: no release found | First install on this cluster | Use `helm upgrade --install` (not `helm upgrade`) |
| Local registry push fails | Registry container not running | `docker start local-registry` |

### Forcing a rollout when nothing changed in the Helm values

If the image tag is static (`:local`) and no values changed, Kubernetes will not restart pods. Force a rollout via a dynamic annotation:

```bash
helm upgrade <release> <chart> \
  --set image.repository=<service> \
  --set image.tag=local \
  --set image.pullPolicy=Never \
  --set "podAnnotations.kubectl\.kubernetes\.io/restartedAt=$(date -u +%FT%TZ)"
```

Add this to the `make dev-image` target to ensure pods always pick up the new image on every `make dev-image` invocation.

---

## Time Benchmarks

Measured on a developer laptop (8 cores, 16 GB RAM, SSD, 100 Mbps upload):

| Step | `kind load` workflow | Remote registry workflow |
|---|---|---|
| `docker build` (warm cache) | 3–8 s | 3–8 s |
| Image transfer | 1–4 s (local IPC) | 15–45 s (push) + 15–45 s (pull) |
| `helm upgrade` + rollout | 5–10 s | 5–10 s |
| **Total per iteration** | **9–22 s** | **38–103 s** |

At 20 iterations per feature: `kind load` saves 10–27 minutes per feature. At 5 features per sprint, that is 50–135 minutes recovered per sprint per developer — from a single conformance requirement.
