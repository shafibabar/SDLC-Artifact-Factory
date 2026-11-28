# kubectl Official Documentation: targeting, readiness and failure evidence (with kind)
**Authors:** The Kubernetes Authors (kubernetes.io); Kubernetes SIGs (kind.sigs.k8s.io)
**Domain:** Testing (end-to-end environments)

Accessed 2026-11-28. Latest Kubernetes and kubectl release v1.37.3, 2026-11-25 (https://api.github.com/repos/kubernetes/kubernetes/releases/latest; https://dl.k8s.io/release/stable.txt also returns v1.37.3), Apache-2.0. The releases page still listed 1.37.2 (2026-10-13) as the latest patch (https://kubernetes.io/releases/). The kubectl reference pages read are the v1.37 reference. kind facts are from the v0.33.0 tag (2026-08-26); this note adds only what `kind-official-docs.md` lacks.

Sources:
- [KC] https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
- [K] https://kubernetes.io/docs/reference/kubectl/generated/kubectl/
- [UC] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_use-context/
- [W] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/
- [R] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/
- [D] https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- [J] https://kubernetes.io/docs/concepts/workloads/controllers/job/
- [PF] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_port-forward/
- [PT] https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/
- [L] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
- [G] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/
- [E] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_events/
- [DS] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/
- [CD] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_cluster-info/kubectl_cluster-info_dump/
- [DEL] https://kubernetes.io/docs/reference/kubectl/generated/kubectl_delete/
- [NS] https://kubernetes.io/docs/tasks/administer-cluster/namespaces/
- [kq] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/quick-start.md
- [kcfg] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/configuration.md
- [ki] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/ingress.md
- [klb] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/loadbalancer.md
- [kr] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/local-registry.md
- [ksrc] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/pkg/cmd/kind/export/kubeconfig/kubeconfig.go and `get/kubeconfig/kubeconfig.go` under the same tree

## Core Concepts

**Targeting**
- "If the `--kubeconfig` flag is set, use only the specified file. Do not merge." Otherwise `KUBECONFIG` is a list of files (colon-delimited on Linux and macOS) that are merged; otherwise `$HOME/.kube/config` [KC].
- Merge rule: "The first file to set a particular value or map key wins", including `current-context` [KC].
- Context: "Use the `--context` command-line flag if it exists", else `current-context` from the merged files [KC]. Flags: `--context`, `--kubeconfig`, `-n/--namespace`, `--request-timeout` (default 0, no timeout) [K].
- `kubectl config use-context` does "Set the current-context in a kubeconfig file": it writes shared state that every later command, and every other terminal, then inherits [UC].
- "Only use kubeconfig files from trusted sources" [KC].
- kind: `kind create cluster --name X` gives context `kind-X` (`kubectl cluster-info --context kind-kind-2` for a cluster named `kind-2`) [kq]. With `--kubeconfig` at creation "only that file is loaded ... no merging takes place" [kq]. `kind get kubeconfig --name X` "Prints cluster kubeconfig"; `kind export kubeconfig --name X --kubeconfig FILE` "Exports cluster kubeconfig"; both accept `--internal` [ksrc].

**Readiness without sleeps**
- `kubectl wait` "waits until the specified condition is seen in the Status field of every given resource". `--for` accepts `create`, `delete`, `condition=NAME[=VALUE]` and `jsonpath='{...}'=VALUE`; several `--for` flags are ANDed and `--for=create` "is always waited first" [W].
- `--timeout` defaults to **30s**; "Zero means check once and don't wait, negative means wait for a week" [W]. Selection is by name, `-l`, `--all` or `-f` [W].
- Condition values compare case-insensitively (Unicode simple case folding), so `condition=complete` matches `Complete` [W].
- Deployment `Available` "means that your Deployment has minimum availability", which the strategy dictates; it is not "all replicas ready" [D]. Pods use `condition=Ready` [W]. A Job's terminal conditions are `Complete` (succeeded) and `Failed`, added only after all its Pods have terminated (v1.31 and later) [J].
- `kubectl rollout status TYPE/NAME` watches "until it's done"; `--timeout` (zero means never), `--watch` (default true) [R]. It "returns a zero exit code" on success and "a non-zero exit code if the Deployment has exceeded the progression deadline" (the page shows exit status 1); `.spec.progressDeadlineSeconds` defaults to 600 [D].

**Reaching services from the test process**
- `kubectl port-forward TYPE/NAME [LOCAL:]REMOTE` forwards to **one Pod**: "a pod will be selected automatically. The forwarding session ends when the selected pod terminates, and a rerun of the command is needed" [PF]. `:5000` picks a random local port; `--address` defaults to localhost; `--pod-running-timeout` defaults to 1m0s [PF].
- It "is implemented for TCP ports only" and "does not return" (it blocks its terminal) [PT].
- kind `extraPortMappings` (`containerPort` to `hostPort` on a node) "is a cross-platform option to get traffic into your kind cluster"; pair it with a NodePort Service whose `nodePort` equals the `containerPort` (the example uses 30950). On Linux without Docker Desktop the host can reach node IPs directly [kcfg].
- kind's ingress guide now relies on cloud-provider-kind v0.9.0+, which "natively supports Ingress. No third-party ingress controllers are required by default"; it is a separate binary that runs on the host and "requires privileges to open ports on the system and to connect to the container runtime" [ki] [klb].

**Images**
- `kind load docker-image IMG... --name X` (several images allowed) and `kind load image-archive FILE` [kq].
- A local registry is a script-created registry container on `localhost:5001`; Pod specs use `localhost:5001/...`, code inside a Pod uses `kind-registry:5000` [kr].

**Evidence on failure**
- `kubectl logs`: `--all-containers`, `--prefix` (pod and container name on each line), `--since 5m`, `--since-time`, `--timestamps`, `-p/--previous`, `-l`, `--all-pods`, `--max-log-requests` (default 5). `--tail` is -1 normally but **10 when a selector is used** [L].
- `kubectl get events --sort-by=<JSONPath>`: `--sort-by` takes a JSONPath (the page's example is `'{.metadata.name}'`) to an integer or string field [G]; which event field to sort on is not stated there. `kubectl events` has `--for TYPE/NAME`, `--types=Warning,Normal`, `-A` and no `--sort-by` [E].
- `kubectl describe` shows events for a single object by default (`--show-events`, false for multiple objects) [DS].
- `kubectl cluster-info dump --namespaces a,b --output-directory DIR` writes cluster state and "the logs of all of the pods"; by default it covers only the current namespace and `kube-system` [CD].
- `kind export logs [dir] --name X` exports node logs [kq].

**Namespaces and deletion**
- `kubectl create namespace NAME`. Deleting a namespace "deletes _everything_ under the namespace" and "is asynchronous", passing through `Terminating`, where it "cannot be used for new objects" [NS].
- `kubectl delete`: `--all` deletes all resources of the named types in the namespace; `-l` selects by label; `-A` spans all namespaces; `--wait` defaults to true and "waits for finalizers"; `--timeout`; `--ignore-not-found` (defaults to true with `--all`); `--cascade` defaults to background [DEL].

## Actionable Techniques

- Create the cluster with its own `--kubeconfig` file and pass `--kubeconfig FILE --context kind-<name>` on every kubectl call; never call `use-context` [KC] [UC] [kq]. A guard that refuses any context not starting with `kind-` is this note's design inference.
- Wait in this order: `kubectl rollout status deployment/X --timeout=...`, then `kubectl wait --for=condition=Ready pod -l ... --timeout=...`, then `--for=condition=complete job/...`; always set `--timeout` (the 30s default is short) [W] [R] [D].
- Prefer NodePort with `extraPortMappings` for a stable address; if `port-forward` is used, target a Service or Deployment and expect it to end when the selected Pod restarts [kcfg] [PF].
- On failure, before teardown: logs with `--all-containers --prefix --timestamps --tail=-1` (set the tail explicitly with a selector), events sorted by time, `cluster-info dump` to a directory, `kind export logs` [L] [G] [CD] [kq].
- Scope every delete with `-n` and a name or selector; on a throwaway cluster delete the cluster instead of namespaces [DEL] [NS] (inference).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-e2e-test, python-e2e-test | Guard that the suite reaches only its own throwaway cluster | `--kubeconfig` disables merging; `--context` beats `current-context`; kind context naming |
| go-e2e-test, python-e2e-test | Readiness without sleeps | `kubectl wait` forms and 30s default, `rollout status` exit status, what `Available` means |
| go-e2e-test, python-e2e-test | Logs and cluster state on failure | Log flags and the 10-line tail trap, events sorting, `cluster-info dump`, `kind export logs` |

## Candidate New Skills/Agents

None.

## Key Terminology

Kubeconfig, Context, Status Condition, Rollout, Port Forward, NodePort, Extra Port Mapping, Namespace.

## Caveats

- Nothing was run. No cluster was created and no command was tried.
- Not stated in the official documentation: what `kubectl wait` does when no resource matches a name or selector, and its exit status on timeout ([W] documents neither; use `--for=create` or check existence first).
- Not stated: the exit status of `kubectl rollout status` when its own `--timeout` expires ([D] covers only the progress deadline).
- Not stated: which Pod `port-forward` picks for a Service or Deployment beyond "selected automatically"; whether `kubectl events` output is sorted.
- Not stated: whether `kind create cluster` changes `current-context` in the kubeconfig it writes.
- Not stated: how long namespace deletion takes, or a command that waits for it other than `kubectl delete --wait` and `kubectl wait --for=delete`.
- The first 100,000 characters of each kubernetes.io page were read (the Deployment and Job pages were also read from 100,000 on); page tails of 400 to 6,000 characters were not.
