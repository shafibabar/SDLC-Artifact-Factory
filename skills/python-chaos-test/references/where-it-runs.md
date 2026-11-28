# Where a Fault May Go

Self-contained. Read before deciding where a chaos experiment runs, when someone proposes staging, production, a tenant environment, a shared cluster or "just a testcontainers stack", when choosing between an in-process fault, Toxiproxy and Chaos Mesh, or when the schedule, credentials or cost come up. The product owner's decisions of 2026-11-28 (D048, chaos testing, with its #1496 addendum for Python) fix this page; each rule is enforced by `../scripts/run-chaos-experiment.sh`, the same program as `go-chaos-test`'s, whose refusals were each run with nothing injected. The sections "The danger", "The privileged injector", "When experiments run" and "Credentials, data and cost" are `go-chaos-test`'s, word for word (`tests/scripts/python-chaos-copies.test.sh`).

## Contents
The danger; the default: the run's own throwaway cluster; the guard; any other system: the signed chaos statement; which tool for which fault; the privileged injector; when experiments run; credentials, data and cost; what the old version did.

## The danger

A chaos experiment deliberately breaks something to see whether users notice. Aimed at a shared environment it breaks that environment for everyone on it, can cascade into systems nobody named, and can leave a fault behind when the test dies. The Principles of Chaos Engineering prefer production traffic, and Netflix's ChAP runs there with 1% experiment and control groups, a 5% cap per region, business hours only and an early stop on customer impact. Those are the guards of a platform built for it. This plugin's products have none of that by default, so the default is a cluster that exists only for the run.

## The default: the run's own throwaway cluster

Every experiment runs as a suite line of the end-to-end environment run that `go-e2e-test` owns for every stack (`python-e2e-test` keeps the same script): a kind cluster created for the run, used, and deleted, at every product size, lean included. Nothing in it is shared, so a cluster fault there (a killed pod, a cut network) harms nobody, and the cluster's deletion is the last backstop for any fault the runner could not remove. **Python experiments run there too, never in a per-test testcontainers stack** (product owner, 2026-11-28): the in-process pytest experiments are one suite line of the chaos run, the deployed ones reach the cluster through the run's loopback addresses.

## The guard

The runner takes no address from the caller. It needs `E2E_RUN_ID` and `E2E_KUBECONFIG`, which `run-e2e-environment.sh` sets for each suite, and reads the cluster's run marker through them, exactly as the load runner does.

| It refuses when (exit 3, nothing injected) | Message |
|---|---|
| Started by hand, outside the environment run, with no statement | `E2E_RUN_ID and E2E_KUBECONFIG are not set` (run for a `pytest` experiment too: pytest was never started) |
| The kubeconfig is the caller's own (`~/.kube/config` or one `KUBECONFIG` names) | `E2E_KUBECONFIG is the caller's own kubeconfig` |
| The kubeconfig has no context `kind-e2e-<run id>` (another cluster) | `the kubeconfig has no context kind-e2e-someone-else` |
| That context's API server is not on loopback | `... is not on this machine` |
| The cluster has no run marker, or another run's | `the cluster's run marker says run "someone-else", this run is "run-1"` |
| An endpoint in the marker is not `127.0.0.1:<port>` | `the run marker has no loopback address for endpoint "api"` |
| A Chaos Mesh manifest selects beyond its own namespace, uses `spec.scheduler`, or has no `duration` for a sustained fault | exit 2, `MANIFEST ERROR` |
| A `pytest` command without `-m chaos`, `-p no:cacheprovider`, `-p no:rerunfailures` or `-o addopts=""`, or with `--reruns`, `--lf`, `--ff`, `--sw`, `--count` | exit 2, `EXPERIMENT ERROR` |

Inside pytest, a second guard: `tests/chaos/conftest.py` refuses every test (`CHAOS-REFUSED`) that the runner did not start, and the Toxiproxy helper refuses an `E2E_ADDR_TOXIPROXY` that is not on loopback (`../templates/chaos-support.md`).

## Any other system: the signed chaos statement

A designated environment, staging, production, a tenant's environment or anything else gets a fault only when the product owner signs a **chaos statement** for it: `tests/chaos/statements/<id>.json` (`../templates/chaos-statement.md`), passed with `--statement`. It says exactly where (the product's address and the Toxiproxy API address), which faults (tool, proxy, toxic type and the largest value of each attribute), the blast radius, the abort conditions it was signed with, the impact (other users, other teams, dependent systems, third parties, data, cost), how to stop it and who watches, a time window, the sign-off and an expiry or a single run id. The system serves `/.well-known/chaos-statement` with the statement id, unless the statement says why it cannot.

The runner refuses, with nothing injected: no statement; unsigned; expired; never lapsing; for another run id; a missing impact field; a toxic type or proxy it does not list; an attribute larger than signed; abort conditions looser than signed; a run that does not fit the window; plain `http` to a host off this machine; a marker that is missing or names another statement; and **any Chaos Mesh, go test or pytest fault** (run for pytest: `an in-process test (go test or pytest) is not bounded by the statement`): on another system only a Toxiproxy fault the statement lists is allowed. Each case is in `tests/scripts/run-chaos-experiment.test.sh`, which also runs against this skill's copy.

The statement is its own record, not the load test's impact statement: the two share the sign-off, expiry, window, marker and impact fields, but a load statement limits a k6 profile and a chaos statement limits faults and abort conditions. A designated performance environment gets no exemption.

## Which tool for which fault

| Fault | Tool | Where | Why |
|---|---|---|---|
| A dependency answers late, with an error, or not at all, seen from the product's client | `FaultTransport` (an `httpx.AsyncBaseTransport`) or the stand-in `Dependency` in a pytest test (`../templates/chaos-support.md`) | In the pytest process, a suite line of the chaos run | Deterministic, fast, counts every call; first choice |
| A blocking call on the event loop | `stall_app`, the product's ASGI app wrapped under `tests/chaos/` only (`../templates/event-loop-stall.md`) | In worker processes the test starts | Only the product's own loop can show it; the shipped image carries no stall hook |
| The network between the deployed product and its dependency | Toxiproxy v2.13.0 (MIT) as a release in the throwaway cluster, driven through its HTTP API (never the `toxiproxy-python` client) | Cluster, or a system under a statement | The fault is on the wire; the deployed service is unchanged |
| A pod killed, a network cut below the product, a node under stress | Chaos Mesh 2.8.8 (Apache-2.0) | **Throwaway cluster only** | Nothing in the process can produce it |

Take the first row that can produce the fault. Cluster faults are allowed in the throwaway cluster at every product size.

## The privileged injector

Chaos Mesh's daemon "must run as a privileged DaemonSet"; the 2.8.8 chart sets `hostPID: true` always, `privileged: true` by default ("essentially equivalent to root on the host") and mounts the container runtime's socket, `/sys` and `/lib/modules` from the node. Seen in the throwaway cluster: `chaos-daemon hostPID=true privileged=true`. Even a namespaced install creates ClusterRoles (seen: `...-controller-manager-cluster-level`, `...-target-namespace`, and two for the dashboard), and `chaosDaemon.privileged: false` still keeps host PID and host mounts. Pod Security's Baseline level forbids all four, so its namespace must allow the privileged level. That is why it is installed only as a release of a cluster that is deleted with the run, and never into any other cluster, under a statement or not.

## When experiments run

- **Nightly and by hand**, in their own throwaway cluster (`make chaos`), never in `make ci` and never on a pull request (W3-D10). Pull requests stay fast; an experiment takes minutes.
- **No standing production chaos.** `disaster-recovery-plan`'s weekly production experiments are replaced by the scheduled run in the throwaway cluster; a production experiment needs a signed statement each time.
- **One run, one result**: no retry of an experiment, in the workflow or in a loop.

## Credentials, data and cost

- **Throwaway cluster:** no stored credential at all. The Toxiproxy API is published on loopback only, for the run. The workflow reads no secret.
- **Under a statement:** Toxiproxy v2.13.0's API is unauthenticated unless `TOXIPROXY_AUTH_TOKEN` is set; the runner sends that token when the variable is set, for the run only. A standing token is never stored.
- **Data:** test data only, inside the environment under test (`test-fixture-design`); a statement names any data the fault can touch (`impact.data`).
- **Cost:** everything here is open source and runs on the CI runner or a laptop. A paid chaos platform needs the product owner's approval.

## What the old version did

Version 1.2.0 ran its experiments in a per-test testcontainers stack, staged them into "a dedicated non-production namespace" and then "a wider non-production slice", published Toxiproxy's control port with no loopback binding, and killed a broker container with no check that the run had created it. Its breaker test made one call and its recovery poll passed even if the breaker never opened; its abort helper was used by no experiment; its `toxic.destroy()` could not work (`add_toxic` returns nothing); and it named physical tenant isolation as fact. Each is now refused by the runner, flagged by `../scripts/validate-python-chaos-tests.sh`, or replaced by an experiment above.
