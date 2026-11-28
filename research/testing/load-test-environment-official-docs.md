# Load-Test Environment from Official Documentation: Kubernetes limits, kind, GitHub-hosted runners and Prometheus queries
**Authors:** The Kubernetes Authors (kubernetes.io); Kubernetes SIGs (kind); Google (cAdvisor repository); GitHub (GitHub Docs); The Prometheus Authors
**Domain:** Testing (load and performance environments)

Accessed 2026-11-28. Kubernetes v1.37.3, 2026-11-25, Apache-2.0 (https://api.github.com/repos/kubernetes/kubernetes/releases/latest); the kubernetes.io pages read are the current (v1.37) documentation. kind v0.33.0, 2026-08-26, read at that tag. cAdvisor v0.61.1, 2026-11-18. Prometheus v3.16.0, 2026-11-05, read at that tag. GitHub Docs carry no version; read as served that day.

Sources:
- [RES] https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- [CPU] https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
- [QOS] https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/
- [RMP] https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/
- [CRI] https://kubernetes.io/docs/reference/instrumentation/cri-pod-container-metrics/
- [NP] https://kubernetes.io/docs/concepts/services-networking/network-policies/
- [NS] https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
- [CAD] https://raw.githubusercontent.com/google/cadvisor/v0.61.1/docs/storage/prometheus.md
- [KR] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/README.md
- [KCFG] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/configuration.md
- [KI] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/design/initial.md
- [KK] https://raw.githubusercontent.com/kubernetes-sigs/kind/v0.33.0/site/content/docs/user/known-issues.md
- [GH] https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- [GL] https://docs.github.com/en/actions/reference/limits
- [GLR] https://docs.github.com/en/actions/concepts/runners/larger-runners
- [GB] https://docs.github.com/en/billing/concepts/product-billing/github-actions
- [GS] https://docs.github.com/en/actions/reference/security/secure-use
- [PF] https://raw.githubusercontent.com/prometheus/prometheus/v3.16.0/docs/querying/functions.md
- [PB] https://raw.githubusercontent.com/prometheus/prometheus/v3.16.0/docs/querying/basics.md
- [PA] https://raw.githubusercontent.com/prometheus/prometheus/v3.16.0/docs/querying/api.md
- [PH] https://raw.githubusercontent.com/prometheus/docs/main/docs/practices/histograms.md

## Core Concepts

**CPU and memory limits**
- The scheduler places a Pod by its requests; "the kubelet also reserves at least the request amount of that system resource specifically for that container" [RES].
- "cpu limits are enforced by CPU throttling. When a container approaches its cpu limit, the kernel will restrict access to the CPU corresponding to the container's limit. Thus, a cpu limit is a hard limit the kernel enforces" [RES].
- Mechanism: "During each scheduling interval (time slice), the Linux kernel checks to see if this limit is exceeded; if so, the kernel waits before allowing that cgroup to resume execution" [RES]. A throttled container is not killed: "container runtimes don't terminate Pods or containers for excessive CPU usage" [RES].
- The CPU request "typically defines a weighting": on a contended node, containers with larger requests get more CPU time [RES].
- A container asked to use 2 CPUs with a limit of 1 uses about 1: "The container's CPU use is being throttled". Usage below the limit can also mean the node has no more CPU to give [CPU].
- With no CPU limit a container "could use all of the CPU resources available on the Node", unless the namespace sets a default limit [CPU].
- "memory limits are enforced by the kernel with out of memory (OOM) kills... memory limits are enforced reactively"; a container over its limit "may get killed", and is restarted if restartable [RES].
- Units: `100m` is "one hundred millicpu", 0.1 CPU [RES].

**Quality of Service classes**
- Guaranteed: every container has CPU and memory requests equal to its limits, all above zero. Burstable: not Guaranteed, and at least one container has a CPU or memory request or limit. BestEffort: no requests or limits at all [QOS].
- Under node pressure the kubelet evicts BestEffort first, then Burstable, then Guaranteed [QOS].
- A Burstable Pod "can try to use any amount of node resources"; a BestEffort Pod can use whatever is not assigned to others [QOS].

**Throttling and memory metrics**
- cAdvisor exposes `container_cpu_cfs_periods_total` (Counter, "Number of elapsed enforcement period intervals"), `container_cpu_cfs_throttled_periods_total` (Counter, "Number of throttled period intervals"), `container_cpu_cfs_throttled_seconds_total` (Counter, seconds) and `container_cpu_usage_seconds_total` (Counter) [CAD].
- `container_memory_working_set_bytes` is a **Gauge**, "Current working set"; `container_oom_events_total` is a Counter [CAD].
- Working set is "the amount of memory in-use that cannot be freed under memory pressure", an estimate that "typically also includes some cached (file-backed) memory" [RMP].
- The kubelet serves these at `/metrics/cadvisor`. "As of Kubernetes v1.37, cAdvisor-based pod and container metrics collection in the kubelet is deprecated"; with the `PodAndContainerStatsFromCRI` feature gate the runtime supplies them on the same endpoint, and older CRI-O releases omit the namespace, pod and container labels [CRI].

**kind**
- "kind is a tool for running local Kubernetes clusters using Docker container 'nodes'. kind was primarily designed for testing Kubernetes itself, but may be used for local development or CI" [KR]. "Each 'node' runs as a docker container" [KI].
- With no `nodes` list the cluster is "one node hosting a control plane"; workers are added in a config file [KCFG].
- On macOS and Windows the nodes live inside Docker's virtual machine, whose resource limits may need raising (the page shows 8 GB of memory) [KK].
- kind makes no statement on performance or load testing in the pages read: not stated.

**GitHub-hosted runners**
- Public repositories, standard labels: Linux x64 and arm64 (`ubuntu-latest`, `ubuntu-24.04`, `ubuntu-22.04`, `ubuntu-26.04`, and the `-arm` labels) **4 CPU, 16 GB RAM, 14 GB SSD**; macOS arm64 (`macos-latest`, `macos-15`, `macos-26`) 3 CPU (M1), 7 GB, 14 GB; macOS Intel (`macos-15-intel`, `macos-26-intel`) 4 CPU, 14 GB, 14 GB [GH].
- Private repositories, the same labels: Linux **2 CPU, 8 GB RAM, 14 GB SSD**; macOS arm64 3 CPU (M1), 7 GB; macOS Intel 4 CPU, 14 GB. These "draw from your GitHub account's included compute usage, and are then charged at the per-minute rates" [GH].
- `ubuntu-slim`: 1 CPU, 5 GB, "hosted in a container on a shared VM", unprivileged (no Docker-in-Docker), job timeout 15 minutes, "not suitable for typical heavyweight CI/CD builds" [GH].
- Otherwise "each GitHub-hosted runner is a new virtual machine (VM) hosted by GitHub" [GH]. Eligible Linux runners "use a multi-cloud compute pool" [GH].
- Job execution time: 6 hours on GitHub-hosted runners, 5 days on self-hosted; the job "is terminated and fails" at the limit [GL].
- Larger runners "are only available for organizations and enterprises using the GitHub Team or GitHub Enterprise Cloud plans" and are "billed at the per-minute rate", public repositories included [GLR] [GB].
- Self-hosted runners "should almost never be used for public repositories on GitHub, because any user can open pull requests against the repository and compromise the environment" [GS].
- Performance variability, noisy neighbours, or the CPU model behind a label: not stated in the pages read.

**Prometheus queries**
- "`rate` should only be used with counters"; it is the per-second average over the range, adjusts for counter resets and extrapolates to the ends of the range [PF].
- "`increase` should only be used with counters"; it is "syntactic sugar for `rate(v)` multiplied by the number of seconds under the specified time range window", so it can return a non-integer [PF].
- "`delta` should only be used with gauges"; it is the difference between the first and last value in the range, also extrapolated [PF].
- "Always take a `rate()` first, then aggregate. Otherwise `rate()` cannot detect counter resets when your target restarts" [PF].
- `histogram_quantile(φ, b)`: "Use the `rate()` function to specify the time window"; keep `le` in the `by` clause for classic histograms; it interpolates linearly inside a bucket; the highest bucket must be `+Inf`, and "if a quantile is located in the highest bucket, the upper bound of the second highest bucket is returned" [PF]. The error "is limited by the width of the bucket the quantile is located in" [PH].
- Precomputed quantiles cannot be combined: "you cannot aggregate quantiles (e.g. to calculate the total 90th percentile latency for a service backed by multiple replicated workers)" [PH].
- Pinning time: `GET /api/v1/query` takes `time=<rfc3339 | unix_timestamp>`; `/api/v1/query_range` takes `start`, `end` (both inclusive) and `step` [PA]. In an expression the `@` modifier fixes the evaluation time (`http_requests_total @ 1609746000`) and accepts `start()` and `end()` [PB].

**Keeping load inside one environment**
- A namespace is "a mechanism for isolating groups of resources within a single cluster" that scopes names and resource quota [NS]; the page does not describe it as a network boundary.
- "By default, a pod is non-isolated for egress; all outbound connections are allowed." A NetworkPolicy with `Egress` in `policyTypes` restricts a selected Pod to the listed destinations, which can be chosen by `namespaceSelector`, `podSelector` or `ipBlock` [NP].
- "Your cluster must use a network plugin that supports NetworkPolicy enforcement"; without one a policy "will have no effect" [NP].

## Actionable Techniques

- Report throttling as a ratio of counters over the run: `increase(container_cpu_cfs_throttled_periods_total[D]) / increase(container_cpu_cfs_periods_total[D])` (the metric names and types are from [CAD]; the ratio is this note's inference).
- Never apply `increase()` or `rate()` to `container_memory_working_set_bytes`; it is a gauge. Use `max_over_time()` for the peak or `delta()` for growth across the run [CAD] [PF].
- Evaluate every query at the run's end with a range equal to the run's duration (`time=<end>` and `[<duration>]`, or `@ <end>`), not a fixed window such as two hours [PA] [PB]. A fixed window also counts whatever else hit the service; filtering by a run label is inference.
- Give the system under test explicit requests and limits and record them with the result; a result is meaningful only for that allocation [RES] [QOS] (inference).
- Treat a single-node kind cluster on a hosted runner as a smoke-level check that the script and gate work: the generator, the service and the control plane share 2 or 4 CPUs, and the hardware differs by repository visibility [GH] [KCFG] (the conclusion is inference; neither source says it).
- Where load must not leave the environment, add an egress NetworkPolicy and confirm the cluster's network plugin enforces it [NP].

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-load-test, python-load-test | Where a load test may run and what a single-node cluster on a shared runner can prove | Runner CPU and memory by label and visibility, the 6-hour limit, kind's stated purpose and one-node default |
| go-load-test, python-load-test | A query that applied `increase()` to a gauge | Metric types from cAdvisor; "counters only" for `rate` and `increase`, "gauges only" for `delta` |
| go-load-test, python-load-test | A fixed two-hour window that also counts other traffic | `time`, `start`/`end` and the `@` modifier to pin a query to the run |
| go-load-test, python-load-test | Throttling not observed | What a CPU limit does, and the throttling counters |

## Caveats

- Nothing was run. No cluster, runner or Prometheus server was used; no query was evaluated.
- kubernetes.io and docs.github.com pages were fetched as HTML, reduced to text locally and read by section and keyword search, not end to end. kind, cAdvisor and Prometheus files were read as raw Markdown; the cAdvisor table was read on `master` and the two throttling names and the working-set name were confirmed present at tag v0.61.1.
- Not stated on the kubernetes.io pages read: the term "CFS", the length of the enforcement period, or the cAdvisor metric names; the link between the documented throttling and `container_cpu_cfs_*` rests on the cAdvisor descriptions.
- Not stated: whether kind's default network plugin enforces NetworkPolicy; any kind statement that nodes share the host's CPU and memory (only that nodes are containers); any kind guidance on performance testing.
- Not stated: GitHub-hosted runner performance variability, noisy neighbours or CPU model; which Linux runners are "eligible" for the multi-cloud pool.
- Not stated: a Prometheus rule for the smallest range that gives a stable `histogram_quantile`, or how many scrapes a run needs; the `histograms.md` practices page was read on an unpinned `main`.
- The Kubernetes releases API returned v1.37.3; the documentation pages do not print a patch version.
