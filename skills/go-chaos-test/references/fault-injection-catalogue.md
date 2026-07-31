# Fault-Injection Catalogue — This Repo's Stack, Specifically

Full catalogue referenced from `SKILL.md`'s "Fault-Injection Catalogue" section. Self-contained
— reads without the parent body already in context. Every template below follows the four-part
header from `references/experiment-design-standard.md`; only the fault-injection mechanism and
the pattern-specific assertion differ per fault.

Two tool tiers, chosen for the narrowest thing that can produce the fault:

| Fault shape | Tool | Why |
|---|---|---|
| A dependency call itself misbehaves (latency, error, timeout) while the process stays up | **toxiproxy** or an app-level fault decorator (`SKILL.md`'s existing patterns) | The fault lives entirely inside the test binary's network path or process — no cluster-level tooling needed, deterministic, fast |
| The infrastructure underneath the process changes (a pod dies, a network link severs, a broker goes away) | **Chaos Mesh** (CNCF, open-source, Helm-installable) | These faults cannot be produced from inside a Go test process — they require acting on the Kubernetes/network layer itself |

**Why Chaos Mesh over Litmus, and why a chaos platform here despite `SKILL.md`'s frugal stance
against one for pattern-level testing:** pod kill and mesh-layer network partition are
structurally unreachable from toxiproxy — toxiproxy only intercepts a connection the app itself
dials *through* the proxy; it cannot terminate a pod or sever the network between two already-
meshed services. Chaos Mesh installs as a single Helm chart (matching this repo's IaC default),
exposes the fault types this catalogue needs as native CRDs (`PodChaos`, `NetworkChaos`), and its
`chaos-daemon` operates at the pod's network namespace — below Linkerd's proxy sidecar, so it
does not fight the mesh's own traffic management the way an application-layer fault-injection
tool would. Litmus's broader chaos-hub ecosystem (workflow engine, probes, a wider experiment
catalog) is more platform than a solo operator's four fault types need — the same "adopt only
what earns its keep" reasoning `SKILL.md`'s Frugality Note already applies to chaos platforms in
general. Record the Chaos Mesh adoption as an ADR when it's first installed.

---

## 1. Pod Kill

Proves the platform's own availability primitives (`kubernetes-manifest`'s PodDisruptionBudget,
readiness probe, and Linkerd's connection-level retry) actually mask a single pod's death from
callers — not just that a `Deployment` schedules a replacement.

```yaml
# chaos/pod-kill-canary.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-estate-scanner-canary
  namespace: chaos-experiments
spec:
  action: pod-kill
  mode: one                                    # blast radius: exactly one pod
  selector:
    namespaces: ["tenant-acme"]
    labelSelectors:
      app: estate-scanner
      slot: canary                             # never the stable slot on a first run
  scheduler:
    cron: "@once"                               # one-shot, not a recurring schedule
```

```
STEADY STATE:  p99 estate-scanner latency < 800ms, error rate < 0.1% (60s pre-fault window)
HYPOTHESIS:    the killed pod's in-flight requests fail over via Linkerd retry or client-side
               retry+backoff (integration-design); the PDB (minAvailable) keeps enough replicas
               serving that steady state never breaches; a replacement pod passes readinessProbe
               and rejoins the pool within the Deployment's normal reconcile window
BLAST RADIUS:  one canary pod, tenant=acme, no other pod touched
ROLLBACK:      abort if error_rate > 5% OR steady-state breach sustained > 60s
```

Assertion: steady-state metrics stay within bound throughout, and `kube_poddisruptionbudget_status_current_healthy`
never drops below the PDB's `minAvailable` floor — a pod-kill experiment that breaches the PDB
floor has found a PDB misconfiguration, not proven resilience.

---

## 2. Linkerd-Layer Network Partition / Latency

Linkerd itself has no fault-injection API — it is a Service Mesh for mTLS and observability
(`kubernetes-manifest`), not a chaos tool; `canary-deployment`'s `HTTPRoute`/`TrafficSplit`
resources shift traffic *weight*, they do not degrade a link. Producing a real network partition
or added latency between two already-meshed services requires acting beneath the mesh, at the
pod's network namespace — exactly what Chaos Mesh's `NetworkChaos` CRD does, safely alongside an
active Linkerd sidecar since neither operates in the other's layer.

```yaml
# chaos/network-partition-canary.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: partition-scanner-to-classifier
  namespace: chaos-experiments
spec:
  action: partition                             # or "delay" for latency instead of a full split
  mode: one
  selector:
    namespaces: ["tenant-acme"]
    labelSelectors: { app: estate-scanner, slot: canary }
  direction: to
  target:
    selector:
      namespaces: ["tenant-acme"]
      labelSelectors: { app: classification-service }
    mode: all
  duration: "2m"
```

```
STEADY STATE:  p99 classify latency < 800ms, error rate < 0.1%
HYPOTHESIS:    with classification-service unreachable, the Circuit Breaker (integration-design)
               opens within its configured failure-count threshold; estate-scanner's calls fail
               fast (ErrServiceUnavailable) rather than hanging until an mTLS handshake timeout;
               once the partition heals, the breaker's Half-Open probe closes the circuit and
               steady state recovers within 30s
BLAST RADIUS:  one canary pod's egress to one downstream service, tenant=acme
ROLLBACK:      abort if error_rate > 5% OR steady-state breach sustained > 60s
```

For pure added latency instead of a full partition, swap `action: partition` for `action: delay`
with a `delay: { latency: "5s" }` block — the same hypothesis shape, testing the breaker's
latency threshold rather than its unreachable-dependency path.

---

## 3. Postgres Connection-Pool Exhaustion

Deliberately holds every connection the pool will hand out, to verify the service degrades
gracefully (fails fast, does not deadlock or queue unbounded) rather than assuming the pool is
inexhaustible. This fault is producible entirely inside a Go test process — no Chaos Mesh needed,
the frugal toxiproxy-tier tool applies here.

```go
// EXPERIMENT: service degrades gracefully when its own Postgres pool is exhausted
// STEADY STATE:  p99 classify latency < 800ms, error rate < 0.1% (60s pre-fault window)
// HYPOTHESIS:    once db_pool_in_use / db_pool_max reaches 1.0, new acquisitions block up to
//                the pool's configured AcquireTimeout, then fail fast — never hang forever —
//                and the Circuit Breaker guarding the repository call opens on the resulting
//                error burst (integration-design)
// BLAST RADIUS:  this service's own pool only, tenant=chaos-test-tenant
// ROLLBACK:      abort if error_rate > 5% OR steady-state breach sustained > 60s
func TestGracefulDegradation_OnPoolExhaustion(t *testing.T) {
    stack := startStack(t)
    requireSteadyState(t, stack)

    // Hold every connection the pool will give out — deliberately never Release().
    held := make([]*pgxpool.Conn, 0, stack.pool.Config().MaxConns)
    for i := int32(0); i < stack.pool.Config().MaxConns; i++ {
        c, err := stack.pool.Acquire(context.Background())
        require.NoError(t, err)
        held = append(held, c)
    }
    t.Cleanup(func() { for _, c := range held { c.Release() } })

    start := time.Now()
    err := classify(t, stack, sampleCmd)
    require.Error(t, err)                                        // fails, does not hang
    require.Less(t, time.Since(start), stack.pool.Config().HealthCheckPeriod+2*time.Second)
    require.ErrorIs(t, err, ErrServiceUnavailable)                // breaker, not a bare pool timeout leaking out
}
```

Assertion beyond the test's own checks: `db_pool_in_use / db_pool_max` (`prometheus-metrics-design`)
reads 1.0 throughout the hold, confirming the fault actually engaged the exhaustion path rather
than the test racing ahead of real saturation.

---

## 4. Redpanda Broker Unavailability

Verifies the producer and consumer sides recover per their own, already-owned resilience
standards — this catalogue entry proves the fault reaches those standards' code paths, it does
not re-derive them:

```yaml
# chaos/broker-kill.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-redpanda-broker
  namespace: chaos-experiments
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: ["platform-messaging"]
    labelSelectors: { app: redpanda }
  scheduler:
    cron: "@once"
```

```
STEADY STATE:  outbox lag (unpublished-row count, go-event-publisher) near zero;
               pipeline_consumer_lag near zero (prometheus-metrics-design)
HYPOTHESIS:    producer side — the outbox relay's drainOnce returns early on the failed
               ProduceSync and leaves rows unpublished; nothing crashes, nothing is lost
               (go-event-publisher's backpressure standard, references/batching-backpressure-
               and-idempotency.md — cross-referenced, not restated here). Consumer side — the
               poll loop's fetch fails, retries with backoff, and resumes from its last committed
               offset once a surviving or replacement broker is reachable (go-event-consumer).
               Both recover to steady state without manual intervention once the broker returns.
BLAST RADIUS:  one broker in a multi-broker cluster — never the last broker standing on a first
               run; confirm cluster replication factor tolerates a one-broker loss before running
ROLLBACK:      abort if outbox unpublished-row count grows unbounded past a set ceiling, or
               pipeline_consumer_lag fails to drain within 5 minutes of broker recovery
```

Assertion: outbox row count returns to baseline and `pipeline_consumer_lag` drains within the
stated window after the killed broker (or its replacement) rejoins — recovery, not just
survival, is the pass condition, exactly as `SKILL.md`'s Quality Criteria require of every
experiment in this catalogue.
