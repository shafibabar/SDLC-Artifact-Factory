# Chaos Mesh and Toxiproxy: install, privilege, safety switches, experiment kinds, client errors
**Authors:** The Chaos Mesh project (chaos-mesh.org documentation, chaos-mesh/chaos-mesh repository); Shopify (Shopify/toxiproxy repository and Go client)
**Domain:** Testing (chaos and fault injection)

Accessed 2026-11-28. Chaos Mesh docs pages show "Version: 2.8.8"; chart and templates read at tag `v2.8.8`; licence Apache License 2.0 (https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/master/LICENSE). Toxiproxy README, client and licence read at tag `v2.13.0` (released 14 October 2026, per `toxiproxy-official-docs.md`); licence MIT, "Copyright (c) 2014 Shopify" (https://raw.githubusercontent.com/Shopify/toxiproxy/v2.13.0/LICENSE). This note adds only what `chaos-mesh-official-docs.md` and `toxiproxy-official-docs.md` lack; Schedule versus the removed `scheduler` field, PodChaos and NetworkChaos are covered there.

## Core Concepts

**Chaos Mesh install on kind (containerd)**
- Helm: `helm install chaos-mesh chaos-mesh/chaos-mesh -n=chaos-mesh --version 2.8.8`; for containerd add `--set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock`. Other documented sockets: K3s `/run/k3s/containerd/containerd.sock`, MicroK8s `/var/snap/microk8s/common/run/containerd.sock`, CRI-O `/var/run/crio/crio.sock`. The Helm page does not mention kind. (https://chaos-mesh.org/docs/production-installation-using-helm/)
- kind is named only in the quick start, which offers `install.sh ... --local kind` (optionally `--kind-version`) but says the script is for "quick trials only and does not provide full functionality" and recommends Helm for "test or production environments". (https://chaos-mesh.org/docs/quick-start/)
- CRDs: "the latest CustomResourceDefinition (CRD) is not applied during the Helm upgrading"; apply `https://mirrors.chaos-mesh.org/v2.8.8/crd.yaml` with `kubectl apply --server-side`. (Helm page above)
- kind may hit the per-user inotify instance limit; the FAQ points to kind's troubleshooting guide. (https://chaos-mesh.org/docs/faqs/)

**What is cluster-scoped and what is privileged**
- `clusterScoped` defaults to `true` ("watches for experiments across the cluster"); `false` with `controllerManager.targetNamespace` (default `chaos-mesh`) limits experiments to one namespace. (Helm page; https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/v2.8.8/helm/chaos-mesh/values.yaml)
- Even with `clusterScoped: false`, the chart creates two ClusterRoles whenever `rbac.create` is true: `...-target-namespace` (pods, configmaps, secrets get/list/watch/delete/update/patch; pods create; events; `chaos-mesh.org` `*`) and `...-cluster-level` (nodes, persistentvolumes, persistentvolumeclaims read; subjectaccessreviews create; namespaces and services only when cluster-scoped). `clusterScoped` only switches the target binding from ClusterRoleBinding to RoleBinding. (https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/v2.8.8/helm/chaos-mesh/templates/controller-manager-rbac.yaml)
- chaos-daemon: "Chaos Daemon must run as a privileged DaemonSet" (FAQ). The DaemonSet sets `hostPID: true` unconditionally, `privileged: true` when `chaosDaemon.privileged` (default `true`; "essentially equivalent to root on the host"), and mounts host paths: the runtime socket, `/sys`, `/lib/modules`. (https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/v2.8.8/helm/chaos-mesh/templates/chaos-daemon-daemonset.yaml; values.yaml)
- With `chaosDaemon.privileged: false` the chart adds capabilities `SYS_PTRACE, NET_ADMIN, NET_RAW, MKNOD, SYS_CHROOT, SYS_ADMIN, KILL, IPC_LOCK` instead; hostPID and hostPath mounts remain. (values.yaml)
- Pod Security Standards: "label the chaos-mesh namespace with the privileged enforce level before installing" (FAQ). OpenShift: grant the privileged SCC to the `chaos-daemon` service account ("Host PID is not allowed to be used"). (FAQ)
- Experiment-user permissions: the documented Manager role needs `pods, namespaces` get/watch/list and `chaos-mesh.org` `*` with get/list/watch/create/delete/patch/update, namespace- or cluster-scoped; no minimum set is defined beyond this example. (https://chaos-mesh.org/docs/manage-user-permissions/)

**Safety switches**
- Namespace filter: `--set controllerManager.enableFilterNamespace=true` (default `false`), then annotate allowed namespaces `chaos-mesh.org/inject=enabled`; "Other namespaces without the annotation are protected against fault injection". (https://chaos-mesh.org/docs/configure-enabled-namespace/)
- Pause: `kubectl annotate <kind> <name> experiment.chaos-mesh.org/pause=true`; resume with `experiment.chaos-mesh.org/pause-`. Paused time still counts toward `duration`, since the deadline is creation time plus `duration`. (https://chaos-mesh.org/docs/run-a-chaos-experiment/)
- Delete recovers: "Once you delete the Chaos experiment, the injected fault will be restored immediately" (run page). A finalizer is removed only after all faults are recovered; if recovery fails the object stays with a `deletionTimestamp`. Force clean with annotation `chaos-mesh.chaos-mesh.org/cleanFinalizer=forced`, which "may leave lingering faults". (https://chaos-mesh.org/docs/clean-up-chaos-experiments/)
- Dashboard `securityMode` defaults to `true`; turning it off "should only be used for non-production deployments". (Helm page; values.yaml)

**Experiment kinds**
- StressChaos: CPU (`workers`, `load` 0–100 per worker) or memory (`workers`, `size` absolute or %, optional `oomScoreAdj`) stress inside containers; `duration`, `mode`, `selector` required. (https://chaos-mesh.org/docs/simulate-heavy-stress-on-kubernetes/)
- IOChaos: `latency`, `fault` (errno), `attrOverride`, `mistake` on file-system calls under `volumePath` (must be the mount's root; `path`, `percent` optional); "may damage your data". (https://chaos-mesh.org/docs/simulate-io-chaos-on-kubernetes/)
- TimeChaos: `timeOffset` on `clockIds` (default `CLOCK_REALTIME`); "only affects the PID 1 process in the PID namespace of the container" and its children, not `kubectl exec` processes. (https://chaos-mesh.org/docs/simulate-time-chaos-on-kubernetes/)
- HTTPChaos: `abort`, `delay`, `replace`, `patch` on `Request` or `Response` at a `port`; `mode`, `target`, `port`, `duration` required. HTTPS needs TLS mode with a user-supplied cert, key and CA in a Secret, "Chaos Mesh v2.8.5 or later". It "does not affect HTTP requests sent over a TCP connection that was established before fault injection" so clients must not reuse sockets. (https://chaos-mesh.org/docs/simulate-http-chaos-on-kubernetes/)
- DNSChaos: `error` or `random` IP for matching `patterns`; only `A` and `AAAA`; needs the Chaos DNS Server, deployed by default since v2.6 (`dnsServer.create=false` disables it). (https://chaos-mesh.org/docs/simulate-dns-chaos-on-kubernetes/)

**Observing status**
- `kubectl describe <kind> <name>` shows Status and Events. Conditions: `Selected`, `AllInjected`, `AllRecovered`, `Paused`; Paused true with Selected false means no target pods found. Container Records list `Id`, `Phase` (e.g. `Injected`), `Selector Key`; `Desired Phase: Run`. Events record Started, Paused, Applied. (https://chaos-mesh.org/docs/inspect-chaos-experiments/)

**Toxiproxy additions**
- Running next to a service: the README describes Docker (`ghcr.io/shopify/toxiproxy`, API 8474) and says it is "made specifically to work in testing, CI and development environments". A Kubernetes sidecar is not stated. (https://raw.githubusercontent.com/Shopify/toxiproxy/v2.13.0/README.md)
- Populate from JSON: an array of `{name, listen, upstream, enabled}` "can be passed to the server using the `-config` option, or loaded by the application to use with the `populate` function"; `POST /populate` is safe to repeat. (README)
- `toxicity`: "probability of the toxic being applied to a link (defaults to 1.0, 100%)"; FAQ: "the percentage of connections a toxic will affect". (README)
- Remove: `DELETE /proxies/{proxy}/toxics/{toxic}` or `toxiproxy-cli toxic remove -n <toxic> <proxy>`; reset: `POST /reset` "Enable all proxies and remove all active toxics". (README)
- Go client errors: `AddToxic` returns `(nil, fmt.Errorf("AddToxic: %w", err))`; non-2xx responses are decoded into an `ApiError` (Message, Status) and returned; transport failures wrap as `"fail to request: %w"`. `RemoveToxic(name) error` returns the delete error unwrapped. `Client.ResetState() error` exists; `PopulateFromFile` does not. (https://raw.githubusercontent.com/Shopify/toxiproxy/v2.13.0/client/proxy.go; .../client/client.go)

## Actionable Techniques

- On kind with containerd, set both `chaosDaemon.runtime` and `socketPath`; label the namespace `pod-security.kubernetes.io/enforce=privileged` first.
- Turn on `enableFilterNamespace` and annotate only the ephemeral test namespace; this protects every other namespace even though the ClusterRoles still exist.
- Assert injection via `AllInjected` and recovery via `AllRecovered` after delete; never force-clean the finalizer in a test, which can leave faults behind.
- For HTTPChaos, inject before the client opens connections or disable keep-alive.
- Set `duration` as an upper bound and do not extend a paused run: pause time is already spent from it (run page).
- For DNSChaos, check that the `chaos-dns-server` pod is Running before the experiment (DNSChaos page).
- Check every Toxiproxy client error; the README's own examples do not (README, client README).

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-chaos-test, python-chaos-test | Install "just works" on kind | containerd socket values; PSS label; inotify; CRDs not upgraded |
| go-chaos-test, python-chaos-test | Namespace-scoping presented as full isolation | ClusterRoles exist regardless; daemon is privileged with hostPID and host mounts |
| go-chaos-test, python-chaos-test | No proof the fault applied or recovered | Conditions, Container Records, events, finalizer behaviour |
| go-chaos-test | Toxic errors ignored | Exact error wrapping; `ResetState`; `/reset` |

## Caveats

- Nothing was run. No cluster, chart, experiment or proxy was started.
- Pages were read through a fetch tool that summarises and quotes in short segments, not end to end.
- Not stated: a kind-specific Chaos Mesh guide on the Helm page; a documented minimum permission set for the controller; whether TimeChaos affects Go binaries specifically (vDSO); `injectedCount`/`recoveredCount` fields; whether a Toxiproxy toxic affects already-open connections; any Kubernetes sidecar recipe for Toxiproxy.
- The Toxiproxy LICENSE and client sources were read at `v2.13.0`; the Chaos Mesh LICENSE at `master`.
