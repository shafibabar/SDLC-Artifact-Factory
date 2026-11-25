# kind Official Documentation
**Authors:** Kubernetes SIGs (kind.sigs.k8s.io)
**Domain:** Testing (end-to-end environments)

Accessed 2026-11-25. Latest release v0.33.0, 2026-08-26 (https://api.github.com/repos/kubernetes-sigs/kind/releases/latest). Quick start: https://kind.sigs.k8s.io/docs/user/quick-start/. Configuration: https://kind.sigs.k8s.io/docs/user/configuration/.

## Core Concepts

- Install with `go install sigs.k8s.io/kind@v0.33.0` or a release binary (quick start).
- `kind create cluster [--name] [--image] [--config] [--wait 5m]`; `--wait` waits for the control plane only. Docker, Podman or nerdctl is auto-detected. (quick start)
- `kind load docker-image` / `image-archive`; avoid `:latest` or set `imagePullPolicy` to `IfNotPresent` or `Never`. (quick start)
- `kind delete cluster [--name]` succeeds even if absent. `kind export logs [dir]`. Kubeconfig defaults to `$KUBECONFIG` or `~/.kube/config`; context `kind-<name>`; `--kubeconfig` isolates it. (quick start)
- Nodes are containers; roles `control-plane` or `worker`; `extraPortMappings` exposes host ports; pin node images by digest; `disableDefaultCNI` has limited support. (configuration)

## Actionable Techniques

- Provision, test and tear down within one owning process or job step sequence, deleting in an always-run step (design inference).
- Pin the kind version and node digest; export logs on failure before deletion.
- After `--wait`, still wait for your own workloads to become ready.
- Use a dedicated `--kubeconfig` so tests cannot reach a real cluster (design inference).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-e2e-test, react-e2e-testing, go-chaos-test | W3B-1, 3, 4 | Lifecycle and image loading |

## Candidate New Skills/Agents

None.

## Key Terminology

Node Image, Cluster Config, Port Mapping.

## Caveats

- The quick start shows cluster creation only; ingress, mesh, database and broker are separate installs (inference).
- [unverified] CNI NetworkPolicy support, runner resource needs, startup times.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-4: a janitor on another hosted runner cannot see the cluster | Nodes are containers on the local runtime | Confirmed by inference |
| W3B-1: trap deletes cluster before tests | Shell behaviour, not a kind question | Unverified here |
