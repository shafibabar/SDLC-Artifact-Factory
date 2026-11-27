# Helm Official Documentation: install, upgrade, wait and teardown
**Authors:** The Helm Authors (helm.sh, helm/helm)
**Domain:** Testing (end-to-end environments)

Accessed 2026-11-28. Latest release Helm v4.3.2, 2026-11-13, a patch release (https://api.github.com/repos/helm/helm/releases/latest), Apache-2.0. Helm 4 is the current major line. The helm.sh pages read were labelled "Version: 4.3.1" (3.22.1 and 2.17.0 are selectable there); flag text was read from source at the `v4.3.2` tag.

Sources:
- [U] https://helm.sh/docs/intro/using_helm/
- [O] https://helm.sh/docs/overview/ (Helm 4 overview)
- [I] https://helm.sh/docs/helm/helm_install/
- [T] https://helm.sh/docs/topics/chart_tests/
- [fl] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/flags.go
- [in] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/install.go
- [up] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/upgrade.go
- [un] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/uninstall.go
- [rt] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/release_testing.go
- [st] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/status.go
- [ls] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/list.go
- [dp] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/dependency.go, `dependency_build.go`, `dependency_update.go` in the same folder
- [env] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cli/environment.go
- [root] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/cmd/root.go
- [kc] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/kube/client.go
- [rd] https://raw.githubusercontent.com/helm/helm/v4.3.2/pkg/kube/ready.go
- [main] https://raw.githubusercontent.com/helm/helm/v4.3.2/cmd/helm/helm.go

## Core Concepts

**What changed in Helm 4**
- `--atomic` is renamed `--rollback-on-failure` and `--force` is renamed `--force-replace`; the old names still work and print a deprecation warning [O] [in] [up].
- Install defaults to server-side apply (`--server-side`, default true). Upgrade defaults to `--server-side=auto`, which follows the method the previous release used; releases made by Helm 3 keep client-side apply [O] [in] [up].
- Waiting uses kstatus ("New kstatus integration") [O].

**`--wait` is not a boolean any more**
- `--wait` takes a strategy: `watcher`, `hookOnly` or `legacy`. **When the flag is omitted the default is `hookOnly`**; `--wait` with no value means `watcher`. `--wait=true` and `--wait=false` are deprecated spellings of `watcher` and `hookOnly` [fl] [I].
- `hookOnly`: "wait only for hook Pods/Jobs to complete; does not wait for general chart resources" [kc].
- `watcher`: event-driven waits using kstatus; "waits CRs and full reconciliation". Needs a reachable API server, list and watch RBAC on the deployed resources, and a non-zero timeout [kc].
- `legacy`: Helm 3 style periodic polling; needs only list RBAC [kc]. Its readiness check covers Pods, Deployments, PersistentVolumeClaims, Services, DaemonSets, CustomResourceDefinitions, StatefulSets, ReplicationControllers, ReplicaSets and (optionally) Jobs; "All other resource kinds are always considered ready" [rd].
- The guide's wording: `--wait` "Waits until all Pods are in a ready state, PVCs are bound, Deployments have minimum" ready Pods and Services "have an IP address (and Ingress if a `LoadBalancer`)" [U]. ExternalName Services are not checked [rd].
- "In scenarios where Deployment has `replicas` set to 1 and `maxUnavailable` is not set to 0, `--wait` will return as ready as it has satisfied the minimum Pod in ready condition" [U]. Read plainly: a single-replica Deployment can pass the wait before its Pod is ready (this note's reading).
- `--wait-for-jobs` (default false): "if set and --wait enabled, will wait until all Jobs have been completed" [in]. Without it, Jobs in the chart are not waited for.
- `--timeout` defaults to `5m0s` and is the "time to wait for any individual Kubernetes operation (like Jobs for hooks)" [in] [I]. It is per operation, not a total for the command.
- On timeout "the release will be marked as `FAILED`" [U]. Any command error exits with status 1 unless the command supplies its own exit code [main].

**Rollback on failure**
- Install: `--rollback-on-failure` "will rollback (uninstall) the installation upon failure", and sets `--wait` to `watcher` when given [in].
- Upgrade: it "will rollback the upgrade to previous success release upon failure" [up]. `--cleanup-on-fail` separately allows deletion of new resources created by a failed upgrade [up].

**Install and upgrade flags**
- `helm upgrade --install` (`-i`): "if a release by this name doesn't already exist, run an install" [up]. `--create-namespace` creates the release namespace if not present (on upgrade, only with `--install`) [in] [up].
- `-n, --namespace`: "namespace scope for this request"; `HELM_NAMESPACE` sets it from the environment [env] [root].
- Values: `-f/--values` may repeat and the right-most file wins; `--set` may repeat and the right-most wins; when both are used "`--set` values are merged into `--values` with higher precedence" [in] [U]. Also `--set-string`, `--set-file`, `--set-json` [up].
- `--dependency-update`: "update dependencies if they are missing before installing the chart" [in] [up]. `--dry-run` takes `none`, `client` or `server` [I].

**Targeting a cluster**
- `--kubeconfig` ("path to the kubeconfig file", default empty) and `--kube-context` ("name of the kubeconfig context to use") are global flags [env].
- `KUBECONFIG` supplies the kubeconfig path and `HELM_KUBECONTEXT` supplies the context name; `--kube-context` takes `HELM_KUBECONTEXT` as its default value, so the flag overrides the variable [env] [root].
- With neither flag nor variable, Helm uses the kubeconfig's current context: not stated in the official documentation in those words; [root] says only that `$KUBECONFIG` sets "an alternative Kubernetes configuration file (default \"~/.kube/config\")".

**Other commands**
- `helm test RELEASE` runs the chart's tests: resources annotated `helm.sh/hook: test` under `templates/`; a test passes when its container exits 0 [T] [rt]. Flags: `--timeout` (5m0s), `--logs` ("dump the logs from test pods ... after all tests are complete, but before any cleanup"), `--filter name=...` [rt].
- `helm status RELEASE` shows last deployment time, namespace, state (`unknown`, `deployed`, `uninstalled`, `superseded`, `failed`, `uninstalling`, `pending-install`, `pending-upgrade`, `pending-rollback`), revision, description, resources, last test run and notes [st].
- `helm uninstall RELEASE` removes the release's resources and history. Flags: `--wait` (same strategies), `--timeout` (5m0s), `--cascade background|orphan|foreground` (default background), `--ignore-not-found` ("Treat \"release not found\" as a successful uninstall"), `--keep-history`, `--no-hooks` [un]. "Use '--cascade foreground' with '--wait' to ensure resources with finalizers are fully deleted before the command returns" [un].
- `helm dependency build CHART` rebuilds `charts/` from `Chart.lock` without re-negotiating versions; with no lock file it behaves like `update`. `helm dependency update CHART` resolves `Chart.yaml`, downloads into `charts/` and writes the lock file. A dependency may be a local path, `repository: "file://../sub-chart"`, which needs no `helm repo add` [dp].
- `helm list`: `-A/--all-namespaces`, `--failed`, `--pending`, `--deployed`, `-q/--short`, `-l/--selector`, `-f/--filter` (regular expression), `-m/--max` (default 256) [ls].

## Actionable Techniques

- Pass `--kubeconfig <file>` and `--kube-context kind-<name>` on **every** Helm command in the provisioning script; never rely on the current context [env]. (Using a throwaway kubeconfig file is this note's design inference.)
- Write `--wait` explicitly (or `--wait=watcher`) with `--wait-for-jobs` and a `--timeout`; a bare `helm install` returns as soon as hooks finish [fl] [kc].
- After Helm returns, still assert readiness of what the suite needs (see the kubectl note); `--wait` can pass early for a single-replica Deployment [U].
- Umbrella chart for product plus web shell: `file://` dependencies, `helm dependency build` from the committed lock file, then one `helm upgrade --install` [dp] [up]. (Putting both in one chart is inference.)
- Teardown: `helm uninstall --ignore-not-found --wait --cascade foreground` is idempotent and waits for finalizers [un]. On a throwaway kind cluster, deleting the cluster is the stronger teardown (inference).
- On failure, capture `helm status` and `helm list -A --failed --pending` before teardown [st] [ls].

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-e2e-test, python-e2e-test | One script provisions product and web shell, waits, always tears down | Wait strategies and their default, `--wait-for-jobs`, per-operation timeout, idempotent uninstall, umbrella dependencies |
| go-e2e-test, python-e2e-test | Commands must not act on the caller's current context | `--kubeconfig`, `--kube-context`, `KUBECONFIG`, `HELM_KUBECONTEXT` |

## Candidate New Skills/Agents

None.

## Key Terminology

Release, Wait Strategy (`watcher`, `hookOnly`, `legacy`), Rollback on Failure, Chart Test, Umbrella Chart, Server-Side Apply.

## Caveats

- Nothing was run. No chart was installed and no flag was tried; everything is read from the pages and the tagged source.
- The helm.sh pages were at 4.3.1 while the release is 4.3.2; flag text was taken from the 4.3.2 source where the two could differ.
- Not stated in the official documentation: which resource kinds the `watcher` strategy treats as ready and how (it defers to kstatus; no list is given); whether `watcher` waits for Jobs without `--wait-for-jobs`.
- Not stated: a documented table of exit codes. "Exit 1 on error" is read from `cmd/helm/helm.go`, not from a documentation page.
- Not stated: whether `--timeout` bounds the whole command when several operations run in sequence.
- Not stated: whether `helm test` deletes its test Pods afterwards (the page says only that `helm.sh/hook-delete-policy` may be used).
- Not stated: precedence between `--kubeconfig` and `KUBECONFIG` in prose. The source shows the flag defaulting to empty and the variable read at start-up; the flag winning is the usual flag-parsing reading, not a quoted rule.
- Helm 3 was not researched; a runner image may still carry it (see the GitHub Actions e2e note).
