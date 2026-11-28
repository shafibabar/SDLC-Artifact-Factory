# Chaos Mesh 2.8.8 in the Throwaway kind Cluster

Self-contained. Read before installing Chaos Mesh, writing a manifest, or when an experiment is not injected or not removed. Sources: `research/testing/chaos-mesh-official-docs.md` and `chaos-mesh-and-toxiproxy-details-official-docs.md` (Chaos Mesh 2.8.8, Apache-2.0). Everything marked **seen** was observed on 2026-11-28 on macOS arm64 with Docker 29.9.3, kind v0.33.0 (node `kindest/node:v1.37.0`), Helm v4.3.2 and kubectl v1.36.1, in clusters created and deleted by `go-e2e-test`'s unmodified environment script.

## Install: one release line, this cluster only

- **Chart:** `chaos-mesh` 2.8.8 from `https://charts.chaos-mesh.org`, pulled once and checked: SHA-256 `35f3caded3d33428d0864eb6d6ece97a5d859a1c0a6e49020fb4d07dd3676bdf`, the digest the project's chart index lists for 2.8.8 (seen equal). The environment script's release lines take a chart path, not a version, so the pinned `.tgz` is what pins it.
- **Release line:** `chaos-mesh|tests/chaos/charts/chaos-mesh-2.8.8.tgz|tests/chaos/chaos-mesh-values.yaml`, last in `E2E_RELEASES`, installed into the product's namespace like every release. **Seen:** `deployment "chaos-controller-manager" successfully rolled out`, `daemon set "chaos-daemon" successfully rolled out`; the script's rollout check found both through `app.kubernetes.io/instance=chaos-mesh`.
- **containerd:** kind's nodes run containerd: `chaosDaemon.runtime: containerd`, `chaosDaemon.socketPath: /run/containerd/containerd.sock` (the chart's default is Docker's socket).
- **Images** (controller and daemon `v2.8.8`) are pulled by the kind node from `ghcr.io`, not preloaded. The dashboard and the DNS server are off (`dashboard.create: false`, `dnsServer.create: false`): nothing here uses them, and each is one more privileged or exposed component. DNSChaos therefore is not available in this setup.
- **CRDs** come with the chart into a fresh cluster. (`helm upgrade` does not update CRDs; that never arises in a cluster that lives for one run.)
- **Pod Security:** the daemon needs the privileged level. kind applies no Pod Security labels; **seen:** the namespace's labels were only `kubernetes.io/metadata.name` and `name`, and the daemon started. On a cluster that enforces Baseline it would be rejected.
- **Never** `install.sh` (the quick-start script is "for quick trials only"), never `helm install` by hand, never into any cluster but the run's own.

## Cluster-scoped, inside a cluster of one run

The chart's `clusterScoped: false` with `controllerManager.targetNamespace` is meant to confine it to one namespace. **Seen with 2.8.8 on kind:** the controller logged `remoteclusters.chaos-mesh.org is forbidden: User "system:serviceaccount:harbour:chaos-controller-manager" cannot list resource "remoteclusters" ... at the cluster scope`, then `failed to wait for ... caches to sync`, restarted, and never reconciled: a PodChaos and a NetworkChaos were accepted but never reported `AllInjected`, and a NetworkChaos create failed at the admission webhook. The runner gave INVALID for each ("never confirmed active") and removed the objects. With the chart's default (cluster-scoped) every experiment was injected.

So the values use the default scope, and the confinement comes from elsewhere: the cluster exists only for this run and holds nothing else; every manifest's selector names exactly its own namespace (the runner refuses anything wider); and the release is never installed anywhere else. Even namespaced, the chart creates ClusterRoles (**seen:** `chaos-mesh-chaos-controller-manager-cluster-level`, `...-target-namespace`, and two for the dashboard), and the daemon runs with host PID and privileged (**seen:** `chaos-daemon hostPID=true privileged=true`), so a namespaced install would not have made it safe for a shared cluster either.

## Experiments

| Kind | Used for | Notes |
|---|---|---|
| `PodChaos` `pod-kill` | One replica dies | One-shot: `duration` and pause do not apply. **Seen:** `AllInjected` True; with two replicas and a readiness probe the SLI held at 1.000 (146 requests) and recovered |
| `NetworkChaos` `loss` 100 % (to a dependency's pods) | A cut link | **Seen:** injected and removed; the product degraded to its last good answers and the SLI held |
| `NetworkChaos` `delay` (the product's own pods) | Slow network | **Seen:** with 1.2 s on every packet the SLI fell to 0.000; the runner aborted after 10 s, deleted the object and verified it gone |
| `Schedule` | A repeated fault inside one run | **Seen:** `@every 20s` created child PodChaos objects (owner `Schedule`, `AllInjected` True); deleting the Schedule removed every child |
| `HTTPChaos` | Abort, delay or patch at the HTTP layer | Not run. Needs Chaos Mesh 2.8.5+ for HTTPS, and does not touch connections opened before injection: disable keep-alive in the client under test |
| `StressChaos`, `IOChaos`, `TimeChaos` | CPU or memory pressure, file-system faults, clock skew | Not run. IOChaos "may damage your data"; TimeChaos affects only PID 1 of the container |

**Removed field:** `spec.scheduler` was removed in 2.0. **Seen:** `strict decoding error: unknown field "spec.scheduler"` (kubectl's default strict validation), so the old templates would not even apply.

**Duration and pause:** a sustained fault's `duration` counts from creation; pause time counts toward it. Set it no longer than the experiment's `abort.max_seconds`, as the in-cluster bound if the runner dies.

**Pod kill and the PodDisruptionBudget:** a pod kill is not an eviction, so a PodDisruptionBudget does not stop it; what keeps the SLI is replicas plus a readiness probe. Where the product has a PDB, the report may add `kube_poddisruptionbudget_status_current_healthy` for the window. **Litmus** (the other CNCF chaos platform) was not evaluated; 2.1.0's preference for Chaos Mesh rested on no source, and Chaos Mesh stays because its CRDs cover the faults needed and it was run here.

## Confirming and removing

- **Active:** the runner polls `status.conditions` for `AllInjected` = True, up to 60 s. `Selected` False means no pod matched. Not confirmed means INVALID, and the object is removed anyway.
- **Removed:** `kubectl delete <kind> <name> -n <ns> --wait=true`, then a `get` that answers NotFound. Chaos Mesh removes its finalizer only after it has recovered every injected fault, so a gone object means a recovered fault. Never use the `cleanFinalizer=forced` annotation in a test: it "may leave lingering faults". **Seen** on interruption: `SIGINT` while a NetworkChaos was active; the runner deleted it, verified it gone and exited 130; `get networkchaos` then found nothing.
- **Backstop:** the environment script deletes the whole cluster after the last suite, also on failure and interruption.
