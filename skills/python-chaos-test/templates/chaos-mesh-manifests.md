# Chaos Mesh 2.8.8: Values and Manifests

Self-contained. Use for a fault no process can produce (a killed pod, a cut or slowed network, stress) and only in the run's throwaway cluster. Background, privilege and what was observed: `../references/chaos-mesh-on-kind.md`. Every file below was applied in a kind v0.33.0 cluster (node `kindest/node:v1.37.0`) on 2026-11-28 with chart 2.8.8, whose digest matched the project's chart index.

Every manifest: `metadata.namespace` is the throwaway cluster's product namespace; `spec.selector.namespaces` is exactly that one namespace with label selectors naming the pods the blast radius allows (the runner refuses anything else); a sustained fault has a `duration` no longer than the experiment's `abort.max_seconds`. `pod-kill` ignores `duration` and pause; it is one-shot. A repeated fault is a `Schedule`; `spec.scheduler` was removed in 2.0 and is rejected by the API server.

### `tests/chaos/chaos-mesh-values.yaml`

```yaml
# Chaos Mesh 2.8.8, installed only as a release of the run's throwaway kind cluster.
# Cluster-scoped (the chart's default): the namespace-scoped mode did not start on kind
# (its controller cannot list RemoteCluster at cluster scope and its caches never sync).
# The cluster holds nothing but this run; the runner still limits every selector to one namespace.
controllerManager:
  replicaCount: 1
chaosDaemon:
  runtime: containerd
  socketPath: /run/containerd/containerd.sock
dashboard:
  create: false
dnsServer:
  create: false
```

### `tests/chaos/mesh/pod-kill-harbour.yaml`

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-harbour
  namespace: harbour
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [harbour]
    labelSelectors: {app: harbour}
```

### `tests/chaos/mesh/network-partition-tides.yaml`

A 100 % loss on every packet to the dependency's pod, which is how `NetworkChaos` cuts a link from one side. The `partition` action needs a `target` selector as well.
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition-tides
  namespace: harbour
spec:
  action: loss
  mode: all
  selector:
    namespaces: [harbour]
    labelSelectors: {app: tides}
  loss:
    loss: "100"
    correlation: "100"
  direction: to
  duration: "60s"
```

### `tests/chaos/mesh/schedule-pod-kill-harbour.yaml`

A repeated pod kill during a longer experiment window. `concurrencyPolicy: Forbid` keeps one run at a time. The runner does not take a `Schedule` (it confirms one fault object); apply and delete it from a `pytest` experiment's test, or keep to one-shot experiments.
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Schedule
metadata:
  name: schedule-pod-kill-harbour
  namespace: harbour
spec:
  schedule: "@every 20s"
  type: PodChaos
  historyLimit: 2
  concurrencyPolicy: Forbid
  podChaos:
    action: pod-kill
    mode: one
    selector:
      namespaces: [harbour]
      labelSelectors: {app: harbour}
```
