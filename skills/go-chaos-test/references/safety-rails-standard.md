# Safety-Rail Standard

Full standard referenced from `SKILL.md`'s "Safety Rails" section. Self-contained — reads
without the parent body already in context. Two independent rails, both mandatory on every
experiment in `references/fault-injection-catalogue.md`: an environment restriction decided
before the experiment exists, and an abort condition that fires without a human watching.

---

## Rail 1: Environment Restriction — Non-Production or Canary-Scoped Only

No chaos experiment's **first run** targets unscoped production traffic. The permitted scopes,
in the order a new experiment graduates through them:

| Stage | Environment | Who/what is affected |
|---|---|---|
| 1 — First run, always | An ephemeral, isolated stack (`kind-local`/CI, `environment-config`'s kind-local kind) or a dedicated `chaos-experiments` namespace | Nothing real; synthetic tenant/data only |
| 2 — Confidence-building | A ​canary slice of a real environment, using `canary-deployment`'s existing canary-weighted `HTTPRoute` and the same SLO-burn-rate gates that already halt a bad canary rollout | One canary pod, one small traffic weight — the exact blast-radius scoping `references/experiment-design-standard.md` requires |
| 3 — Only after 1 and 2 both pass cleanly, repeatedly | A wider slice, still tenant-scoped (`multi-tenancy-design`'s physical isolation boundary) | One tenant, never the full fleet |
| Never, on a first run of any new experiment | Full, unscoped production traffic | — |

This is the same staged-exposure discipline `canary-deployment`'s stage table already applies to
*releases* — a chaos experiment against a canary slice is not a new mechanism, it is this
existing mechanism aimed at a deliberately injected fault instead of a new code version. An
experiment that has never passed at Stage 1 has no evidence-based reason to run at Stage 2.

---

## Rail 2: Automatic Abort Conditions — Wired to Fire Without a Human Watching

The rollback trigger `references/experiment-design-standard.md` requires every experiment to
state up front is not satisfied by a human agreeing to "keep an eye on the dashboard." It is
wired into the same observability stack that already pages on everything else in this plugin —
`alerting-rules-design`'s Prometheus/Alertmanager path, or the fault-injection tool's own
built-in monitor where one exists:

**For toxiproxy / app-level experiments (in-process):** the test goroutine itself polls the
steady-state signal on a fixed interval and calls the fault's own removal (`proxy.RemoveToxic`,
flipping the fault decorator's flag back) the instant the stated numeric trigger is crossed —
the abort *is* Go code in the test, no external system needed, since the whole experiment already
runs inside one process.

**For Chaos Mesh experiments (infrastructure-level):** a companion `PrometheusRule` alert fires
on the same threshold stated in the experiment's rollback-trigger line, and a small watcher
(a scheduled job or the CI runner orchestrating the experiment) polls Alertmanager and issues
`kubectl delete -f <experiment>.yaml` the moment the alert fires — deleting a Chaos Mesh CR halts
the fault immediately and Chaos Mesh reverts its effect (a killed pod is not un-killed, but a
`NetworkChaos` partition lifts, a scheduled recurring fault stops recurring):

```yaml
# chaos/abort-rule-pod-kill-canary.yaml
groups:
  - name: chaos-experiment-abort
    rules:
      - alert: ChaosExperimentAbort
        expr: |
          service:http_request_errors:ratio_rate5m{slot="canary"} > 0.05
          or
          service:http_request_duration_seconds:p99_5m{slot="canary"} > 0.8
        for: 60s
        labels: { severity: critical, source: chaos-experiment }
        annotations:
          summary: "Chaos experiment breached its stated rollback trigger — auto-aborting"
```

```bash
# watcher loop — run by the same CI job or operator script that started the experiment
until amtool alert query alertname=ChaosExperimentAbort --output json | jq -e 'length > 0'; do
  sleep 5
done
kubectl delete -f chaos/pod-kill-canary.yaml   # halts the fault immediately
```

The abort is never a person who happens to be looking at a Grafana panel — that is a Rail 2
violation even if it happens to work on the day someone was watching. The point of an automatic
abort is that it fires identically whether or not anyone is watching.

---

## Both Rails Apply Together, Not Either/Or

A canary-scoped experiment (Rail 1) with no wired abort condition (Rail 2 missing) can still burn
the canary's own error budget past recovery before a human notices — canary scoping bounds *who*
is affected, not *how long* a runaway experiment is allowed to affect them. Both rails are
required on every experiment in `references/fault-injection-catalogue.md`; neither substitutes
for the other.
