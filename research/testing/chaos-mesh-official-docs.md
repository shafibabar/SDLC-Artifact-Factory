# Chaos Mesh Official Documentation
**Authors:** The Chaos Mesh project (chaos-mesh.org, chaos-mesh/chaos-mesh)
**Domain:** Testing (chaos)

Accessed 2026-11-25. Latest release v2.8.8, 2026-11-06 (https://api.github.com/repos/chaos-mesh/chaos-mesh/releases/latest); docs pages show 2.8.8.

## Core Concepts

- **One-time experiment:** apply the chaos resource. `duration` sets a deadline counted from object creation; without it the fault lasts until paused or deleted. Deleting restores the fault. Annotation `experiment.chaos-mesh.org/pause=true` pauses. `pod-kill` and `container-kill` ignore pause and duration. (https://chaos-mesh.org/docs/run-a-chaos-experiment/)
- **Scheduling:** a separate `Schedule` resource (`schedule`, `type`, `concurrencyPolicy` default `Forbid`, `historyLimit`, embedded spec such as `networkChaos`). (https://chaos-mesh.org/docs/define-scheduling-rules/)
- **Inline `scheduler` removed in 2.0:** maintainers state that `.spec.scheduler` stopped working and was replaced by `Schedule` (https://github.com/chaos-mesh/chaos-mesh/discussions/2065; https://github.com/chaos-mesh/chaos-mesh/issues/2523).
- **PodChaos:** `pod-failure`, `pod-kill`, `container-kill`; `action`, `mode`, `selector` required (https://raw.githubusercontent.com/chaos-mesh/website/master/docs/simulate-pod-chaos-on-kubernetes.md).
- **NetworkChaos:** delay, loss, duplicate, corrupt, rate, bandwidth, partition; `direction`, `target`, `externalTargets` (https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/).
- **Install:** Helm chart `chaos-mesh/chaos-mesh --version 2.8.8`; for containerd set `chaosDaemon.runtime=containerd`, socket `/run/containerd/containerd.sock`. `clusterScoped=false` with `controllerManager.targetNamespace` limits scope; install still needs cluster-scoped permissions. CRDs are not updated by `helm upgrade`. (https://chaos-mesh.org/docs/production-installation-using-helm/)
- **Privilege:** Chaos Daemon must be a privileged DaemonSet; the namespace must allow privileged pods. kind may need higher inotify limits. (https://chaos-mesh.org/docs/faqs/)

## Actionable Techniques

- Always set `duration` and delete in an unconditional cleanup; for one-shot kills, duration is no bound.
- Namespace-scope the install and default templates to the ephemeral namespace.
- State the privileged daemon as a security trade-off.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-chaos-test, python-chaos-test, disaster-recovery-plan | W3B-42 to 44, 49 | Schedule, duration, install, privilege |

## Candidate New Skills/Agents

None.

## Key Terminology

Chaos Experiment, Schedule, Chaos Daemon, Mode, Selector.

## Caveats

- [unverified] The Helm page does not mention kind; check the socket path there.
- [unverified] Supported Kubernetes versions; abort or status-check features in Chaos Mesh Workflow; Litmus comparison.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-42: `spec.scheduler` removed, replaced by `Schedule` | Yes | Confirmed |
| W3B-42 proposal: `duration` as hard bound | Works for sustained faults, not `pod-kill`/`container-kill` | Confirmed with limit |
| go-chaos-test: install needs privileged daemon | Yes | Confirmed |
